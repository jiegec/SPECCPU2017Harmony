# the minimum version of CMake.
cmake_minimum_required(VERSION 3.5.0)
project(SPECCPU2017Harmony)

# need fortran for 548.exchange2_r
if (CMAKE_HOST_SYSTEM_NAME MATCHES "Linux")
        set(CMAKE_Fortran_COMPILER_FORCED TRUE)
        set(CMAKE_Fortran_COMPILER "flang-new-20")
        set(CMAKE_Fortran_FLAGS "-target aarch64-linux-ohos -fuse-ld=lld -L ${CMAKE_CURRENT_SOURCE_DIR}/../../../../flang -nostdlib -L ${CMAKE_CURRENT_SOURCE_DIR}/../../../../../command-line-tools/sdk/default/openharmony/native/sysroot/usr/lib/aarch64-linux-ohos -lc -lm -L ${CMAKE_CURRENT_SOURCE_DIR}/../../../../../command-line-tools/sdk/default/openharmony/native/llvm/lib/clang/15.0.4/lib/aarch64-linux-ohos/ -lclang_rt.builtins -lFortranRuntime -lFortranDecimal")
        enable_language(Fortran)
endif()

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

include_directories(${NATIVERENDER_ROOT_PATH}
                              ${NATIVERENDER_ROOT_PATH}/include)

add_library(entry SHARED napi_init.cpp)
target_compile_definitions(entry PRIVATE "-DCXX_COMPILER_VERSION=${CMAKE_CXX_COMPILER_VERSION}")
target_compile_definitions(entry PRIVATE "-DFORTRAN_COMPILER_VERSION=${CMAKE_Fortran_COMPILER_VERSION}")
target_link_libraries(entry PUBLIC libace_napi.z.so)
target_link_libraries(entry PUBLIC libhilog_ndk.z.so)

add_subdirectory(500.perlbench_r)
add_subdirectory(502.gcc_r)
add_subdirectory(505.mcf_r)
add_subdirectory(520.omnetpp_r)
add_subdirectory(523.xalancbmk_r)
add_subdirectory(525.x264_r)
add_subdirectory(531.deepsjeng_r)
add_subdirectory(541.leela_r)
# need fortran for 548.exchange2_r
if (CMAKE_HOST_SYSTEM_NAME MATCHES "Linux")
        add_subdirectory(548.exchange2_r)
endif()
add_subdirectory(557.xz_r)
