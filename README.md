# SPEC CPU 2017 Harmony

Run SPEC CPU 2017 benchmark on OpenHarmony/HarmonyOS NEXT.

It currently supports running SPEC CPU 2017 integer rate-1 (548.exchange2_r requires flang, currently only working on Linux).

## Usage

How to build on macOS (missing 548.exchange2_r support):

1. Copy the whole benchspec folder from SPEC CPU 2017 installation to the root folder of this project
2. Execute `perl generate.perl` under the root folder of this project
3. Use DevEco Studio to open this project
4. Setup code signing using DevEco Studio
5. Execute `./build-macos.sh` under the root folder of this project

How to build on Linux:

1. Install lld-20 and flang-20 from [LLVM APT](https://apt.llvm.org/)
2. Copy the whole benchspec folder from SPEC CPU 2017 installation to the root folder of this project
3. Execute `perl generate.perl` under the root folder of this project
4. Clone llvm-project to $HOME/llvm-project
5. Execute `./build-flang.sh` under the root folder of this project
6. Copy code signing config (including build-profile.json5 and ~/.ohos/config) from macOS/Windows
7. Execute `./build-linux.sh` under the root folder of this project

To install the application to phone: either use DevEco Studio, or use `push.sh`.

## Result

If you want to find existing benchmark results, please refer to [results](./results/README.md) folder.
