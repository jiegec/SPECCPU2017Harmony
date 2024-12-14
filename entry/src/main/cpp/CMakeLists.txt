# the minimum version of CMake.
cmake_minimum_required(VERSION 3.5.0)
project(SPECCPU2017Harmony)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

include_directories(${NATIVERENDER_ROOT_PATH}
                              ${NATIVERENDER_ROOT_PATH}/include)

add_library(entry SHARED napi_init.cpp)
target_link_libraries(entry PUBLIC libace_napi.z.so)
target_link_libraries(entry PUBLIC libhilog_ndk.z.so)

add_subdirectory(500.perlbench_r)
add_subdirectory(502.gcc_r)