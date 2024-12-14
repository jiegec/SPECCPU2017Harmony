#include "napi/native_api.h"
#include <dlfcn.h>
#include <unistd.h>
#include <string>
#include <vector>

#include "hilog/log.h" 
#define LOG_DOMAIN 0x0000
#define LOG_TAG "mainTag"

static std::string get_str(napi_env env, napi_value value) {
    size_t size = 0;
    napi_get_value_string_utf8(env, value, NULL, 0, &size);
    std::vector<char> buffer(size + 1);

    napi_get_value_string_utf8(env, value, buffer.data(), buffer.size(), &size);
    std::string s(buffer.data(), size);
    return s;
}

// parameters:
// 1: cwd
// 2: path to log file
// 3: benchmark name
// 4: benchmark args
static napi_value Run(napi_env env, napi_callback_info info) {
    // get args
    size_t argc = 4;
    napi_value args[4] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

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

    OH_LOG_INFO(LOG_APP, "Start benchmark %{public}s", benchmark.c_str());
    int res = main(1 + args_length, real_argv.data(), envp);
    OH_LOG_INFO(LOG_APP, "End benchmark %{public}s", benchmark.c_str());

    dlclose(handle);

    return 0;
}

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {{"run", nullptr, Run, nullptr, nullptr, nullptr, napi_default, nullptr}};
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
