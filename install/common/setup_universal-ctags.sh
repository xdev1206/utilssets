#!/bin/bash

SCRIPT_PATH=$(cd `dirname ${BASH_SOURCE[0]}` && /bin/pwd)
source ${SCRIPT_PATH}/env.sh

PREFIX=${UTILSSETS_ROOT}/tools

if [ "${NETWORK}" = "1" ]; then
    CTAGS_BUILD_DIR="/tmp/ctags-build-$$"
    mkdir -p "$CTAGS_BUILD_DIR"
    cd "$CTAGS_BUILD_DIR"

    echo "Cloning universal-ctags..."
    git clone https://github.com/universal-ctags/ctags.git
    cd ctags

    echo "Building universal-ctags..."
    ./autogen.sh || { echo "autogen.sh failed, trying configure..."; }

    if [ -f "./configure" ]; then
        ./configure --prefix=${PREFIX}
        make
        make install
        echo "universal-ctags installed to ${PREFIX}"
    else
        echo "Error: configure script not generated"
        cd /
        rm -rf "$CTAGS_BUILD_DIR"
        exit 1
    fi

    cd /
    rm -rf "$CTAGS_BUILD_DIR"
else
    echo "Network unavailable, skipping universal-ctags installation"
fi
