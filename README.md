# SPEC CPU 2017 Harmony

Running SPEC INT 2017 benchmark on HUAWEI MateBook Pro:

![](./screenshot.jpg)

## Overview

Run SPEC CPU 2017 benchmark on OpenHarmony/HarmonyOS NEXT.

It currently supports running SPEC CPU 2017 int rate-1 and fp rate-1.

Uses GCC 12.4.0 for compilation since v1.4.0(previously Clang 14 and Flang 20 were used).

## Usage

How to build on Linux:

1. Copy the whole benchspec folder from SPEC CPU 2017 installation to the root folder of this project
2. Execute `perl generate.perl` under the root folder of this project
3. Clone <https://github.com/jiegec/musl-cross-make/> to $HOME/musl-cross-make
4. Execute `./build-musl.sh` under the root folder of this project (sudo is required to install musl toolchain to /opt/cross)
5. Copy code signing config (including build-profile.json5 and ~/.ohos/config) from macOS/Windows
6. Execute `./build-linux.sh` under the root folder of this project

To install the application to phone: copy the file from Linux to macOS and use `push.sh`.

## Result

If you want to find existing benchmark results, please refer to [results](./results/README.md) folder. Tested devices:

- Pura 70 Pro+
- MateBook Pro

## How does it work

Because HarmonyOS NEXT does not permit the execution of binaries in the data folder, each benchmark (including the input generator and output validator) is compiled into a shared library. To execute the benchmark, the shared library is loaded, and its main function is invoked with the appropriate arguments.

To prevent memory exhaustion caused by potential memory leaks, each benchmark is executed within a forked child process. Upon the child process's termination, the memory is automatically reclaimed. The execution time is measured from the parent process, which includes the minimal overhead of process startup and shutdown.

Certain benchmarks require an exceptionally large stack size (on the order of hundreds of megabytes). However, setting the stack size limit using `setrlimit` does not function as intended. To address this, a manual switch implemented in assembly is used to run the benchmark on a heap-allocated 1GB stack.

P.S. It seems that on MateBookPro, execve syscall is allowed, so it is possible to run statically linked SPEC CPU 2017 binaries. Investigation is pending.

## TODO

- copies>1 of rate tests
- speed tests
