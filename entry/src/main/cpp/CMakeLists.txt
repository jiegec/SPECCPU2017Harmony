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
add_subdirectory(505.mcf_r)
add_subdirectory(520.omnetpp_r)
add_subdirectory(523.xalancbmk_r)
add_subdirectory(525.x264_r)
add_subdirectory(531.deepsjeng_r)
add_subdirectory(541.leela_r)
# need fortran
# add_subdirectory(548.exchange2_r)
add_subdirectory(557.xz_r)