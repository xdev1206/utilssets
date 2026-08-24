#!/bin/bash

SCRIPT_PATH=$(cd `dirname ${BASH_SOURCE[0]}` && /bin/pwd)
source ${SCRIPT_PATH}/env.sh

FZF_PATH=${UTILSSETS_ROOT}/tools/fzf

remove_tmp()
{
  find $FZF_PATH -iname ".git*" -exec rm -rf {} \; 2>/dev/null
  find $FZF_PATH -iname "*.md" -exec rm -rf {} \; 2>/dev/null
  find $FZF_PATH -iname "LICENSE*" -exec rm -rf {} \; 2>/dev/null
}

update_fzf()
{
    if [ "${NETWORK}" = "1" ]; then
        rm -rf $FZF_PATH > /dev/null 2>&1

        echo "Cloning fzf..."
        git clone --depth 1 https://github.com/junegunn/fzf.git $FZF_PATH
        remove_tmp > /dev/null 2>&1
    fi

    if [ -d ${FZF_PATH} ]; then
        echo "Installing fzf..."
        $FZF_PATH/install --all
    else
        echo "Error: fzf not found at ${FZF_PATH}"
        return 1
    fi
}

update_fzf
