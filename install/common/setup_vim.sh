#!/bin/bash

SCRIPT_PATH=$(cd `dirname $BASH_SOURCE[0]` && /bin/pwd)

source ${SCRIPT_PATH}/env.sh

VIM_PATH=${UTILSSETS_ROOT}/config/vim
VIM_TMP=$VIM_PATH/tmp

echo "VIM_PATH: ${VIM_PATH}"
echo "VIM_TMP: ${VIM_TMP}"

remove_tmp()
{
  pushd $VIM_PATH > /dev/null

  rm -rf $VIM_TMP
  find $VIM_PATH -iname ".git*" -exec rm -rf {} \; 2>/dev/null
  find $VIM_PATH -iname "*.md" -exec rm -rf {} \; 2>/dev/null
  find $VIM_PATH -iname "LICENSE*" -exec rm -rf {} \; 2>/dev/null
  find $VIM_PATH -iname ".Vimball*" -exec rm -rf {} \; 2>/dev/null

  popd > /dev/null
}

# downloading vim plugins
download_plugins()
{
  # need network
  if [ "${NETWORK}" = "1" ]; then
    mkdir -p $VIM_TMP
    pushd $VIM_TMP > /dev/null

    # install plug to manager plug-ins
    if [ ! -f "${VIM_PATH}/autoload/plug.vim" ]; then
      git clone https://github.com/junegunn/vim-plug.git
      cp ${VIM_TMP}/vim-plug/plug.vim ${VIM_PATH}/autoload

      echo "$VIM_PATH"
      vim -c "set runtimepath^=$VIM_PATH" -c 'PlugInstall' -c 'qall'
    fi

    popd > /dev/null
  fi
}

# setup vim plugin environment
vim_env()
{
  vimrc=`readlink $HOME/.vimrc 2>/dev/null`

  if [ "$vimrc" = "$VIM_PATH/.vimrc" ]; then
    echo "has already setup vim env, jump to next step..."
    return
  fi

  download_plugins

  # Export VIM_PATH to environment
  export_env VIM_PATH "${VIM_PATH}"

  # Source platform-specific vim setup if exists
  if [ -f "${SCRIPT_PATH}/../${OS_TYPE}/vim_${OS_TYPE}.sh" ]; then
    source "${SCRIPT_PATH}/../${OS_TYPE}/vim_${OS_TYPE}.sh"
  fi

  # each user should use himself vim config
  ln -sfv $VIM_PATH/.vimrc $HOME/.vimrc

  remove_tmp > /dev/null 2>&1
}

vim_env
