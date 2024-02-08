#!/bin/bash

SCRIPT_PATH=$(cd `dirname $BASH_SOURCE[0]` && /bin/pwd)
source $SCRIPT_PATH/env.sh

git clone https://github.com/universal-ctags/ctags.git
cd ctags
./autogen.sh
./configure --prefix=${ENV_ROOT}
make
make install # may require extra privileges depending on where to install
