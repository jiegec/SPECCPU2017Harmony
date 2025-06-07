#include "napi/native_api.h"
#include <assert.h>
#include <cstdlib>
#include <dlfcn.h>
#include <sched.h>
#include <string>
#include <sys/time.h>
#include <sys/utsname.h>
#include <sys/wait.h>
#include <unistd.h>
#include <vector>
#include <fstream>

#include "hilog/log.h"
#undef LOG_TAG
#define LOG_TAG "mainTag"

extern "C" void switch_stack(int argc, const char **argv, const char **envp,
                             int (*callee)(int argc, const char **argv,
                                           const char **envp),
                             void *sp,
                             void *handle);

static std::string get_str(napi_env env, napi_value value) {
  size_t size = 0;
  assert(napi_get_value_string_utf8(env, value, NULL, 0, &size) == napi_ok);
  std::vector<char> buffer(size + 1);

  assert(napi_get_value_string_utf8(env, value, buffer.data(), buffer.size(),
                                    &size) == napi_ok);
  std::string s(buffer.data(), size);
  return s;
}

uint64_t get_time() {
  struct timeval tv = {};
  gettimeofday(&tv, nullptr);
  return (uint64_t)tv.tv_sec * 1000000000 + (uint64_t)tv.tv_usec * 1000;
}

// measure clock frequency
// parameter
// 1: core index
static napi_value Clock(napi_env env, napi_callback_info info) {
  // get args
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

  // set cpu affinity
  cpu_set_t cpuset;
  CPU_ZERO(&cpuset);
  int core;
  napi_get_value_int32(env, args[0], &core);
  CPU_SET(core, &cpuset);
  assert(sched_setaffinity(0, sizeof(cpuset), &cpuset) == 0);
  OH_LOG_INFO(LOG_APP, "Pin to cpu %{public}d", core);

  int n = 500000;
  uint64_t before = get_time();
  // learned from lmbench lat_mem_rd
#define FIVE(X) X X X X X
#define TEN(X) FIVE(X) FIVE(X)
#define FIFTY(X) TEN(X) TEN(X) TEN(X) TEN(X) TEN(X)
#define HUNDRED(X) FIFTY(X) FIFTY(X)
#define THOUSAND(X) HUNDRED(TEN(X))

  for (int i = 0; i < n; i++) {
    asm volatile(".align 4\n" THOUSAND("add x1, x1, x1\n") : : : "x1");
  }
  uint64_t after = get_time();

  double freq = (double)n * 1000 / (double)(after - before);
  OH_LOG_INFO(LOG_APP, "Clock frequency is %{public}f", freq);
  napi_value ret;
  napi_create_double(env, freq, &ret);
  return ret;
}

// parameters:
// 0: cwd
// 1: path to stdin
// 2: path to stdout
// 3: path to stderr
// 4: benchmark name
// 5: benchmark args
// 6: core index
// 7: stdout unbuffered
static napi_value Run(napi_env env, napi_callback_info info) {
  // get args
  size_t argc = 8;
  napi_value args[8] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

  // set cpu affinity
  cpu_set_t cpuset;
  CPU_ZERO(&cpuset);
  int core;
  napi_get_value_int32(env, args[6], &core);
  CPU_SET(core, &cpuset);
  assert(sched_setaffinity(0, sizeof(cpuset), &cpuset) == 0);
  OH_LOG_INFO(LOG_APP, "Pin to cpu %{public}d", core);

  // change workin directory
  std::string cwd = get_str(env, args[0]);
  OH_LOG_INFO(LOG_APP, "Change cwd to %{public}s", cwd.c_str());
  chdir(cwd.c_str());

  // https://developer.huawei.com/consumer/cn/doc/harmonyos-faqs/faqs-ndk-16-V5
  // redirect stdout/stderr to file
  std::string stdin_file = get_str(env, args[1]);
  std::string stdout_file = get_str(env, args[2]);
  std::string stderr_file = get_str(env, args[3]);
  if (stdin_file.size() > 0) {
    OH_LOG_INFO(LOG_APP, "Redirect stdin to %{public}s", stdin_file.c_str());
  }
  OH_LOG_INFO(LOG_APP, "Redirect stdout to %{public}s", stdout_file.c_str());
  OH_LOG_INFO(LOG_APP, "Redirect stderr to %{public}s", stderr_file.c_str());

  // must set GFORTRAN_UNBUFFERED_ALL=1 before dlopen libgfortran
  setenv("GFORTRAN_UNBUFFERED_ALL", "1", true);

  // load benchmark main from library
  int (*main)(int argc, const char **argv, const char **envp);
  std::string benchmark = get_str(env, args[4]);
  OH_LOG_INFO(LOG_APP, "Load benchmark %{public}s", benchmark.c_str());
  std::string library_name = "lib";
  library_name += benchmark;
  library_name += ".so";
  void *handle = dlopen(library_name.c_str(), RTLD_LAZY);
  if (!handle) {
    OH_LOG_INFO(LOG_APP, "Failed to load benchmark %{public}s",
                benchmark.c_str());
    // missing shared library
    // return -1.0
    napi_value ret;
    napi_create_double(env, -1.0, &ret);
    return ret;
  }

  main = (int (*)(int argc, const char **argv, const char **envp))dlsym(handle,
                                                                        "main");

  if (!handle) {
    OH_LOG_INFO(LOG_APP, "Failed to load benchmark %{public}s",
                benchmark.c_str());
    // missing shared library
    // return -1.0
    napi_value ret;
    napi_create_double(env, -1.0, &ret);
    return ret;
  }

  // construct argv
  std::vector<std::string> argv;
  argv.push_back(benchmark);
  uint32_t args_length;
  napi_get_array_length(env, args[5], &args_length);
  for (uint32_t i = 0; i < args_length; i++) {
    napi_value element;
    napi_get_element(env, args[5], i, &element);

    std::string arg = get_str(env, element);
    argv.push_back(arg);
  }

  std::vector<const char *> real_argv;
  for (auto &arg : argv) {
    real_argv.push_back(arg.c_str());
  }
  real_argv.push_back(NULL);
  const char *envp[1] = {NULL};

  // emulate ulimit -s unlimited
  // required for 527.cam4_r
  // setrlimit not working
  // let's create a stack manually
  // 1GB stack
  uint8_t *stack = NULL;
  size_t size = 0x40000000;
  posix_memalign((void **)&stack, 0x1000, size);
  uint8_t *stack_top = stack + size;
  OH_LOG_INFO(LOG_APP, "Allocated stack at %{public}lx-%{public}lx", stack,
              stack_top);

  OH_LOG_INFO(LOG_APP, "Start benchmark %{public}s", benchmark.c_str());

  // io redirection
  if (stdin_file.size() > 0) {
    freopen(stdin_file.c_str(), "r", stdin);
  }
  freopen(stdout_file.c_str(), "w+", stdout);
  freopen(stderr_file.c_str(), "w+", stderr);

  bool unbuffered = false;
  napi_get_value_bool(env, args[7], &unbuffered);
  if (unbuffered) {
    setvbuf(stdout, NULL, _IONBF, 0);
    setenv("GFORTRAN_UNBUFFERED_ALL", "1", true);
    OH_LOG_INFO(LOG_APP, "Stdout is unbuffered");
  }

  // use fork
  // 502.gcc_r does not free memory, leading to out of memory
  // large stack required for some benchmarks
  uint64_t before = get_time();
  uint64_t after;
  double res = -1;
  double time;
  pid_t pid = fork();
  if (pid == 0) {
    // equivalent to:
    // int status = main(1 + args_length, real_argv.data(), envp);
    // dlclose(handle);
    // fflush(NULL);
    // exit(status);
    // run main & exit on the new stack
    switch_stack(1 + args_length, real_argv.data(), envp, main, stack_top, handle);
  } else {
    // in parent process
    assert(pid != -1);
    int wstatus;
    waitpid(pid, &wstatus, 0);
    if (!WIFEXITED(wstatus) || WEXITSTATUS(wstatus) != 0) {
      // failed
      res = -1;
      goto cleanup;
    }
  }

  after = get_time();
  time = (double)(after - before) / 1000000000;
  OH_LOG_INFO(LOG_APP, "End benchmark %{public}s in %{public}fs",
              benchmark.c_str(), time);
  res = time;

cleanup:
  if (handle) {
    dlclose(handle);
  }
  if (stack) {
    free(stack);
  }

  napi_value ret;
  napi_create_double(env, res, &ret);
  return ret;
}

#define S(x) #x
#define STRINGIFY(x) S(x)
static napi_value Info(napi_env env, napi_callback_info info) {
  napi_value ret;
  std::string res;

  res += "Compiler Version: GCC ";
  res += STRINGIFY(COMPILER_VERSION);
  res += "\n";

  struct utsname tmp;
  assert(uname(&tmp) == 0);
  res += "Uname: ";
  res += tmp.sysname;
  res += " ";
  res += tmp.nodename;
  res += " ";
  res += tmp.release;
  res += " ";
  res += tmp.version;
  res += " ";
  res += tmp.machine;

  napi_create_string_utf8(env, res.c_str(), res.length(), &ret);
  return ret;
}

static napi_value CpuInfo(napi_env env, napi_callback_info info) {
  napi_value ret;
  // https://stackoverflow.com/questions/2602013/read-whole-ascii-file-into-c-stdstring
  std::ifstream t("/proc/cpuinfo");
  std::string res((std::istreambuf_iterator<char>(t)),
                  std::istreambuf_iterator<char>());

  napi_create_string_utf8(env, res.c_str(), res.length(), &ret);
  return ret;
}

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
  napi_property_descriptor desc[] = {
      {"run", nullptr, Run, nullptr, nullptr, nullptr, napi_default, nullptr},
      {"clock", nullptr, Clock, nullptr, nullptr, nullptr, napi_default,
       nullptr},
      {"info", nullptr, Info, nullptr, nullptr, nullptr, napi_default, nullptr},
      {"cpuInfo", nullptr, CpuInfo, nullptr, nullptr, nullptr, napi_default, nullptr},
  };
  napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
  return exports;
}
EXTERN_C_END

static napi_module demoModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "entry",
    .nm_priv = ((void *)0),
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterEntryModule(void) {
  napi_module_register(&demoModule);
}
