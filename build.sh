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
# assume arkui-x directory created at $HOME/arkui-x
# LICENSE & LICENSE.sha256 copied from macOS ~/Library/ArkUI-X/Sdk/licenses
# to Linux $HOME/arkui-x/licenses
export ARKUIX_SDK_HOME=$HOME/arkui-x
hvigorw assembleHap
