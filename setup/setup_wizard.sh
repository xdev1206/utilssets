#!/bin/bash

# make sure current process doesn't run in dash, or exit and show usage
count=`ps aux | grep -i $$ | grep -ciE "(/| |da)sh[ ]+$0"`
if [ $count -gt 0 ]; then
  echo "usage:"
  echo "  bash $0"
  exit 0
fi

# cur/bin/env path
CUR_DIR=$(cd `dirname $BASH_SOURCE` && /bin/pwd)

source ${CUR_DIR}/env/env.sh
# os related
source ${CUR_DIR}/${OS_TYPE}/wizard_${OS_TYPE}.sh

# non-os releated
source ${CUR_DIR}/setup_vim.sh
source ${CUR_DIR}/update_fzf.sh

download_repo_tool() {
    if [ "${NETWORK}" = "0" ]; then
        echo "Error: Network is unavailable. Please check your network connection."
        return 1
    fi

    if [ -f "${ENV_BIN}/repo" ]; then
        echo "repo tool already exists at ${ENV_BIN}/repo"
        return 0
    fi

    if command -v wget >/dev/null 2>&1; then
        wget https://storage.googleapis.com/git-repo-downloads/repo -O ${ENV_BIN}/repo
        chmod +x ${ENV_BIN}/repo
        echo "repo tool downloaded to ${ENV_BIN}/repo"
    else
        echo "Error: wget is not installed. Please install wget first."
        return 1
    fi
}


download_repo_tool
