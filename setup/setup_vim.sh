#!/bin/bash

SCRIPT_PATH=$(cd `dirname $BASH_SOURCE[0]` && /bin/pwd)

source ${SCRIPT_PATH}/env.sh

VIM_PATH=$ENV_ROOT/vim
VIM_TMP=$VIM_PATH/tmp

echo "VIM_PATH: ${VIM_PATH}"
echo "VIM_TMP: ${VIM_TMP}"

remove_tmp()
{
  pushd $VIM_PATH

  rm -rf $VIM_TMP
  find $VIM_PATH -iname ".git*" -exec rm -rf {} \;
  find $VIM_PATH -iname "*.md" -exec rm -rf {} \;
  find $VIM_PATH -iname "LICENSE*" -exec rm -rf {} \;
  find $VIM_PATH -iname ".Vimball*" -exec rm -rf {} \;

  popd
}

# downloading vim plugins
download_plugins()
{
  # need network
  if [ "x${reach_network}" == "x1" ]; then
    mkdir -p $VIM_TMP
    pushd $VIM_TMP

    # install plug to manager plug-ins
    # curl -fLo $VIM_PATH/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    git clone https://github.com/junegunn/vim-plug.git
    remove_tmp > /dev/null 2>&1
    cp ${VIM_TMP}/vim-plug/plug.vim ${VIM_PATH}/autoload

    echo "$VIM_PATH"
    vim -c "set runtimepath^=$VIM_PATH" -c 'PlugInstall' -c 'qall'

    popd
  fi
}

# setup vim plugin environment
vim_env()
{
  vimrc=`readlink $HOME/.vimrc`

  if [ "$vimrc" = "$VIM_PATH/.vimrc" ]; then
    echo "has already setup vim env, jump to next step..."
    return
  fi


  download_plugins
  source $SCRIPT_PATH/$OS_TYPE/vim_${OS_TYPE}.sh

  # each user should use himself vim config
  ln -sfv $VIM_PATH/.vimrc $HOME/.vimrc

  remove_tmp > /dev/null 2>&1
}

vim_env
