# Benchmarking results

Record the results of running benchmarks using this application. All numbers are estimated.

Due to fluctuations, the best performance without putting the phone in a refrigerator is recorded.

C/C++ code is compiled with current clang version from HarmonyOS SDK. Fortran code is compiled with latest flang-20 version from LLVM APT. Optimization flags:

- all (except 502.gcc_r due to miscompilation): -O3 -flto -march=armv8.a+sve
- 502.gcc_r: -O3 -march=armv8.a+sve
