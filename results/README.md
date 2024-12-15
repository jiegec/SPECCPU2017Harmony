# Benchmarking results

Record the results of running benchmarks using this application. All numbers are estimated.

Due to fluctuations, the best performance without putting the phone in a refrigerator is recorded. Different compilation configurations:

- -O3: all built with -O3
- -O3-flto: all (except 502.gcc_r due to miscompilation) built with -O3 -flto, gcc built with -O3

C/C++ code is compiled with current clang version from HarmonyOS SDK. Fortran code is compiled with latest flang-20 version from LLVM APT.
