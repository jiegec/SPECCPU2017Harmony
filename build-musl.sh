#!/bin/sh
set -e -x
cd $HOME/musl-cross-make
git reset 8d37efb01952deedd57cbdd84ecbb0a481226f0e --hard
git clean -fdx .
cat <<EOF > config.mak
TARGET = aarch64-linux-musl
GCC_CONFIG += --enable-languages=c,c++,fortran
GCC_VER = 12.4.0
BINUTILS_VER = 2.40
EOF
make -j $(nproc)
make install -j $(nproc)
sudo rm -rf /opt/cross
sudo cp -r output /opt/cross
# avoid name clash
sudo sed -i 's/__unused/__unused1/g' /opt/cross/aarch64-linux-musl/include/bits/stat.h
/opt/cross/bin/aarch64-linux-musl-gcc --version
