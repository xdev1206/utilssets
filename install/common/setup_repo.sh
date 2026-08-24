#!/bin/bash

SCRIPT_PATH=$(cd `dirname ${BASH_SOURCE[0]}` && /bin/pwd)

if [ -z "${OS_NAME}" ]; then
    source ${SCRIPT_PATH}/env.sh
fi

REPO_DIR="${BIN_DIR}"
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
    echo "repo download successfully: $REPO_PATH"
else
    echo "repo already installed: $(which repo)"
fi

# Setup repo workspace
REPO_WORKSPACE="${UTILSSETS_ROOT}/src/repo"

if [ "${NETWORK}" = "1" ]; then
    mkdir -p "$REPO_WORKSPACE"
    cd "$REPO_WORKSPACE"

    # Use full path to repo
    REPO_CMD="${REPO_PATH}"

    if [ ! -d ".repo" ]; then
        echo "P8Dhhzfnn7BWdbRzWhgRrCfoDeSeX44VEIxg"

        git config --global credential.helper store
        git ls-remote https://github.com/xdev1206/manifests.git

        echo "Initializing repo workspace..."
        "${REPO_CMD}" init -u https://github.com/xdev1206/manifests.git -b main
        echo "Syncing repositories..."
        #"${REPO_CMD}" sync
    else
        echo "Repo workspace already initialized at $REPO_WORKSPACE"
    fi
else
    echo "Network unavailable, skipping repo sync"
fi

# Add to .gitignore
GITIGNORE="${UTILSSETS_ROOT}/.gitignore"
if ! grep -q "^src/repo$" "$GITIGNORE" 2>/dev/null; then
    echo "src/repo" >> "$GITIGNORE"
    echo "Added src/repo to .gitignore"
fi
