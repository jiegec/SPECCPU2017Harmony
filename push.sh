#!/bin/sh
# push and install the hap
# assume deveco studio is downloaded from:
# https://developer.huawei.com/consumer/cn/download/
# and extracted to /Applications/DevEco-Studio.app
set -x -e
export TOOL_HOME=/Applications/DevEco-Studio.app/Contents
export PATH=$TOOL_HOME/sdk/default/openharmony/toolchains:$PATH
hdc file send $1 /data/local/tmp
hdc shell bm install -p /data/local/tmp/$1
