#!/bin/sh
# build the project on Linux
# assume command-line-tools downloaded from:
# https://developer.huawei.com/consumer/cn/download/
# and extracted to $HOME/command-line-tools
export TOOL_HOME=$HOME/command-line-tools
export DEVECO_SDK_HOME=$TOOL_HOME/sdk
export PATH=$TOOL_HOME/ohpm/bin:$PATH
export PATH=$TOOL_HOME/hvigor/bin:$PATH
export PATH=$TOOL_HOME/node/bin:$PATH
# assume arkui-x directory to be saved at $HOME/arkui-x
export ARKUIX_SDK_HOME=$HOME/arkui-x
mkdir -p $ARKUIX_SDK_HOME/licenses
cp -r .ci/* $ARKUIX_SDK_HOME/licenses
hvigorw assembleHap
