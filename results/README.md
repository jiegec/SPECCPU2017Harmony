# Benchmarking results

Record the results of running benchmarks using this application. All numbers are estimated.

Due to fluctuations, the best performance without putting the phone in a refrigerator is recorded.

C/C++ code is compiled with current clang version (15.0.4) from HarmonyOS SDK. Fortran code is compiled with latest flang-20 version from LLVM APT. Optimization flags:

- some benchmarks are built without -flto: -O3 -march=armv8.a+sve
	- 502.gcc_r
	- 503.bwaves_r
	- 507.cactuBSSN_r
	- 510.parest_r
	- 521.wrf_r
	- 526.blender_r
	- 527.cam4_r
- others: -O3 -flto -march=armv8.a+sve
