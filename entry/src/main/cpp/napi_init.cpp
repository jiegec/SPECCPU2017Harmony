#include "napi/native_api.h"
#include <dlfcn.h>
#include <unistd.h>
#include <string>

// parameters:
// 1: path to log file
// 2: benchmark name
// 3: benchmark args
static napi_value Run(napi_env env, napi_callback_info info) {
    // get args
    size_t argc = 3;
    napi_value args[3] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    // https://developer.huawei.com/consumer/cn/doc/harmonyos-faqs/faqs-ndk-16-V5
    // redirect stdout/stderr to file
    size_t log_file_size;
    char log_file_buffer[512];
    napi_get_value_string_utf8(env, args[0], log_file_buffer, sizeof(log_file_buffer), &log_file_size);
    std::string log_file(log_file_buffer, log_file_size);

    freopen(log_file.c_str(), "a", stdout);
    freopen(log_file.c_str(), "a", stderr);

    size_t benchmark_size;
    char benchmark_buffer[512];
    napi_get_value_string_utf8(env, args[1], benchmark_buffer, sizeof(benchmark_buffer), &benchmark_size);
    std::string benchmark(benchmark_buffer, benchmark_size);

    int (*main)(int argc, const char **argv, const char **envp);

    std::string library_name = "lib";
    library_name += benchmark;
    library_name += ".so";
    void *handle = dlopen(library_name.c_str(), RTLD_LAZY);

    main = (int (*)(int argc, const char **argv, const char **envp))dlsym(handle, "main");
    const char *argv[2] = {benchmark.c_str(), NULL};
    const char *envp[1] = {NULL};
    int res = main(1, argv, envp);

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
