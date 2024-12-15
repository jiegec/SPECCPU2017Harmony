#include "napi/native_api.h"
#include <dlfcn.h>
#include <unistd.h>
#include <string>
#include <vector>
#include <sched.h>
#include <assert.h>
#include <sys/time.h>
#include <sys/wait.h>

#include "hilog/log.h"
#undef LOG_TAG
#define LOG_TAG "mainTag"

static std::string get_str(napi_env env, napi_value value) {
    size_t size = 0;
    assert(napi_get_value_string_utf8(env, value, NULL, 0, &size) == napi_ok);
    std::vector<char> buffer(size + 1);

    assert(napi_get_value_string_utf8(env, value, buffer.data(), buffer.size(), &size) == napi_ok);
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

    int n = 100000;
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
// 1: cwd
// 2: path to log file
// 3: benchmark name
// 4: benchmark args
// 5: core index
static napi_value Run(napi_env env, napi_callback_info info) {
    // get args
    size_t argc = 5;
    napi_value args[5] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    // set cpu affinity
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    int core;
    napi_get_value_int32(env, args[4], &core);
    CPU_SET(core, &cpuset);
    assert(sched_setaffinity(0, sizeof(cpuset), &cpuset) == 0);
    OH_LOG_INFO(LOG_APP, "Pin to cpu %{public}d", core);

    std::string cwd = get_str(env, args[0]);
    OH_LOG_INFO(LOG_APP, "Change cwd to %{public}s", cwd.c_str());
    chdir(cwd.c_str());

    // https://developer.huawei.com/consumer/cn/doc/harmonyos-faqs/faqs-ndk-16-V5
    // redirect stdout/stderr to file
    std::string log_file = get_str(env, args[1]);

    OH_LOG_INFO(LOG_APP, "Redirect stdout/stderr to %{public}s", log_file.c_str());
    freopen(log_file.c_str(), "w+", stdout);
    freopen(log_file.c_str(), "w+", stderr);

    std::string benchmark = get_str(env, args[2]);

    // load benchmark main from library
    int (*main)(int argc, const char **argv, const char **envp);

    OH_LOG_INFO(LOG_APP, "Load benchmark %{public}s", benchmark.c_str());
    std::string library_name = "lib";
    library_name += benchmark;
    library_name += ".so";
    void *handle = dlopen(library_name.c_str(), RTLD_LAZY);
    if (!handle) {
        // missing shared library
        // return -1.0
        napi_value ret;
        napi_create_double(env, -1.0, &ret);
        return ret;
    }

    main = (int (*)(int argc, const char **argv, const char **envp))dlsym(handle, "main");
    std::vector<std::string> argv;
    argv.push_back(benchmark);
    uint32_t args_length;
    napi_get_array_length(env, args[3], &args_length);
    for (uint32_t i = 0; i < args_length; i++) {
        napi_value element;
        napi_get_element(env, args[3], i, &element);

        std::string arg = get_str(env, element);
        argv.push_back(arg);
    }

    std::vector<const char *> real_argv;
    for (auto &arg : argv) {
        real_argv.push_back(arg.c_str());
    }
    real_argv.push_back(NULL);
    const char *envp[1] = {NULL};

    // use fork
    // 502.gcc_r does not free memory, leading to out of memory
    OH_LOG_INFO(LOG_APP, "Start benchmark %{public}s", benchmark.c_str());
    uint64_t before = get_time();
    pid_t pid = fork();
    if (pid == 0) {
        main(1 + args_length, real_argv.data(), envp);
        exit(0);
    } else {
        assert(pid != -1);
        int wstatus;
        waitpid(pid, &wstatus, 0);
    }
    uint64_t after = get_time();
    double time = (double)(after - before) / 1000000000;
    OH_LOG_INFO(LOG_APP, "End benchmark %{public}s in %{public}fs", benchmark.c_str(), time);

    dlclose(handle);

    napi_value ret;
    napi_create_double(env, time, &ret);
    return ret;
}

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {{"run", nullptr, Run, nullptr, nullptr, nullptr, napi_default, nullptr},
                                       {"clock", nullptr, Clock, nullptr, nullptr, nullptr, napi_default, nullptr}};
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

extern "C" __attribute__((constructor)) void RegisterEntryModule(void) { napi_module_register(&demoModule); }
