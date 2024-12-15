# SPEC CPU 2017 Harmony

Run SPEC CPU 2017 benchmark on OpenHarmony/HarmonyOS NEXT.

It currently supports running SPEC CPU 2017 integer rate-1 (528.exchange2_r requires flang, currently only working on Linux).

How to build on macOS (missing 528.exchange2_r support):

1. Copy the whole benchspec folder from SPEC CPU 2017 installation to the root folder of this project
2. Execute `perl generate.perl` under the root folder of this project
3. Use DevEco Studio to open this project
4. Setup code signing using DevEco Studio
5. Execute `./build-macos.sh` under the root folder of this project

How to build on Linux:

1. Copy the whole benchspec folder from SPEC CPU 2017 installation to the root folder of this project
2. Execute `perl generate.perl` under the root folder of this project
3. Clone llvm-project to $HOME/llvm-project
4. Execute `./build-flang.sh` under the root folder of this project
5. Copy code signing config (including build-profile.json5 and ~/.ohos/config) from macOS
6. Execute `./build-linux.sh` under the root folder of this project

To install the application to phone: either use DevEco Studio, or use `push.sh`.
