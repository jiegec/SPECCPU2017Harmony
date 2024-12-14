#!/bin/sh
# build the project on macOS
# assume deveco studio  downloaded from:
# https://developer.huawei.com/consumer/cn/download/
# and extracted to /Applications/DevEco-Studio.app
export TOOL_HOME=/Applications/DevEco-Studio.app/Contents
export DEVECO_SDK_HOME=$TOOL_HOME/sdk
export PATH=$TOOL_HOME/tools/ohpm/bin:$PATH
export PATH=$TOOL_HOME/tools/hvigor/bin:$PATH
export PATH=$TOOL_HOME/tools/node/bin:$PATH
hvigorw assembleHap
