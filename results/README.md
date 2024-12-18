# Benchmarking results

Record the results of running benchmarks using this application. All numbers provided are estimates.

Due to fluctuations in performance, we offer two types of benchmark runs:

1. [Full Run](./full/): Executes all benchmarks sequentially, resulting in less favorable thermal conditions.
2. [Best Run](./best/): Allows each benchmark to be run individually, ensuring optimal thermal conditions.

For integer benchmarks, the best run is slightly faster than the full run. For floating-point benchmarks, however, the best run is over 20% faster than the full run, likely due to the increased heat generation.

Note: Placing the device in a refrigerator is strictly prohibited.

The C/C++ code is compiled using the current Clang version (15.0.4) from the HarmonyOS SDK. The Fortran code is compiled with the latest Flang-20 version from the LLVM APT repository. The following optimization flags are used:

- some benchmarks are built without -flto: -O3 -march=armv8.a+sve
	- 502.gcc_r: LTO leads to crashes
	- 507.cactuBSSN_r: LTO fails due to different Clang and Flang versions
	- 510.parest_r: internal exception in LTO
	- 521.wrf_r: LTO is quite slow
	- 526.blender_r: LTO is quite slow
	- 527.cam4_r: LTO is quite slow
- others: -O3 -flto -march=armv8.a+sve
