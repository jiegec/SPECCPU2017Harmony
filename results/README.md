# Benchmarking results

Record the results of running benchmarks using this application. All numbers provided are estimates.

Due to fluctuations in performance, we offer two types of benchmark runs:

1. [Full Run](./full/): Executes all benchmarks sequentially, resulting in less favorable thermal conditions.
2. [Best Run](./best/): Allows each benchmark to be run individually, ensuring optimal thermal conditions.

Tested on the following devices:

- HBN-AL80(HUAWEI Pura 70 Pro+): part id 0xd03 core #11, part id 0xd42 core #9
- HAD-W32(HUAWEI MateBook Pro): part id 0xd03 core #19, part id 0xd43 core #11, part id 0xd42 core #3

For integer benchmarks, the best run is slightly faster than the full run. For floating-point benchmarks, however, the best run is over 20% faster than the full run, likely due to the increased heat generation.

Note: Placing the device in a refrigerator is strictly prohibited.

The C/C++ code is compiled using GCC 12.4.0 with `-O3 -flto` via musl-cross-make.
