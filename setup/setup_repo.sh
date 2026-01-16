#!/bin/sh

SCRIPT_PATH=$(cd `dirname $BASH_SOURCE[0]` && /bin/pwd)

if [ "x$OS_NAME" == "x" ]; then
    source ${SCRIPT_PATH}/env/env.sh
fi

REPO_DIR="${ENV_PATH}/bin"
REPO_PATH="$REPO_DIR/repo"
REPO_URL="https://storage.googleapis.com/git-repo-downloads/repo"

if ! command -v repo >/dev/null 2>&1; then
    mkdir -p "$REPO_DIR"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$REPO_URL" -o "$REPO_PATH"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$REPO_URL" -O "$REPO_PATH"
    else
        echo "error: can't find curl or wget!"
        exit 1
    fi

    chmod a+x "$REPO_PATH"
    echo "repo download successfully：$REPO_PATH"
fi

repo init -u https://github.com/xdev1206/manifests.git -b main
repo sync -j4
