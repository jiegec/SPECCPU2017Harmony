#!/bin/sh
# build missing libraries for aarch64-linux-ohos target
# assume llvm-project is cloned at $HOME/llvm-project
set -x -e
mkdir -p flang
DST=$PWD/flang
cd $HOME/llvm-project
git checkout llvmorg-17.0.6

cd libunwind
rm -rf build
mkdir -p build
cd build
cmake .. -G Ninja \
	-DCMAKE_C_FLAGS="-target aarch64-linux-ohos -fuse-ld=lld" \
	-DCMAKE_C_COMPILER="clang" \
	-DCMAKE_CXX_FLAGS="-target aarch64-linux-ohos -fuse-ld=lld" \
	-DCMAKE_CXX_COMPILER="clang++"
ninja
cp lib/libunwind.a $DST/
cd ../../

cd flang/lib/Decimal
rm -rf build
mkdir -p build
cd build
cmake .. -G Ninja \
	-DCMAKE_C_FLAGS="-target aarch64-linux-ohos -fuse-ld=lld -fPIC" \
	-DCMAKE_C_COMPILER="clang" \
	-DCMAKE_CXX_FLAGS="-target aarch64-linux-ohos -fuse-ld=lld -fPIC" \
	-DCMAKE_CXX_COMPILER="clang++"
ninja
cp libFortranDecimal.a $DST/
cd ../../../../

cd flang/runtime
rm -rf build
mkdir -p build
cd build
cmake .. -G Ninja \
	-DCMAKE_C_FLAGS="-target aarch64-linux-ohos -fuse-ld=lld -fPIC" \
	-DCMAKE_C_COMPILER="clang" \
	-DCMAKE_CXX_FLAGS="-target aarch64-linux-ohos -fuse-ld=lld -fPIC" \
	-DCMAKE_CXX_COMPILER="clang++"
ninja
cp libFortranRuntime.a $DST/
cp FortranMain/libFortran_main.a $DST/
cd ../../../

ls -al $DST