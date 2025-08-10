#!/bin/bash

SCRIPT_PATH=$(cd `dirname $BASH_SOURCE[0]` && /bin/pwd)

if [ "x$OS_NAME" == "x" ]; then
    source ${SCRIPT_PATH}/env/env.sh
fi

PYENV_PATH=$ENV_ROOT/tool/pyenv
PYENV_PATH_VIRENV=$PYENV_PATH/plugins/pyenv-virtualenv
PYENV_CONF=$ENV_ROOT/config/pyenv.conf

remove_tmp()
{
    find $PYENV_PATH -iname ".git*" -exec rm -rf {} \;
    find $PYENV_PATH -iname "*.md" -exec rm -rf {} \;
    find $PYENV_PATH -iname "LICENSE*" -exec rm -rf {} \;
    find $PYENV_PATH -iname "*.png" -exec rm -rf {} \;
}

download_pyenv()
{
    if [ -d $PYENV_PATH ]; then
        echo "delete $PYENV_PATH"
        rm -rf $PYENV_CONF > /dev/null 2>&1
        rm -rf $PYENV_PATH > /dev/null 2>&1
    fi

    git clone --depth 1 https://github.com/pyenv/pyenv.git $PYENV_PATH
    git clone --depth 1 https://github.com/pyenv/pyenv-virtualenv.git $PYENV_PATH_VIRENV

    # remove system default virtualenv package
    rm -rf $HOME/.local/lib/python2.7/site-packages/virtualenv* 2>&1
}

replace_pyenv_complete() {
  local file="${1:-pyenv.bash}"
  if [[ ! -f $file ]]; then
    echo "$file does not exist, please confirm..."
    return 1
  fi

  sed -i '' 's/complete -F _pyenv pyenv/compdef _pyenv pyenv/g' "$file"
  echo "repleace \'complete\' with \'compdef\' in ${file}"
}

pyenv_to_conf()
{
    echo "export PYENV_PATH=$PYENV_PATH" > $PYENV_CONF
    echo -e 'export PATH="$PYENV_PATH/bin:$PATH"\n\n' >> $PYENV_CONF

    $PYENV_PATH/bin/pyenv init - >> $PYENV_CONF

    if [ "${OS_TYPE}x" = "Darwinx" ]; then
        replace_pyenv_complete ${PYENV_PATH}/completions/pyenv.bash
    fi

    cp $PYENV_CONF $HOME/

    # pip source config
    if [ ! -f $HOME/.pip/pip.conf ]; then
        mkdir -p $HOME/.pip
        echo -e "[global]\nindex-url = https://mirrors.aliyun.com/pypi/simple" >> $HOME/.pip/pip.conf
        echo -e "\nextra-index-url = https://pypi.tuna.tsinghua.edu.cn/simple" >> $HOME/.pip/pip.conf
        echo -e "\ntimeout = 120" >> $HOME/.pip/pip.conf
    fi
}

python_env()
{
    if [ -f $PYENV_CONF ]; then
        found=$(cat $PYENV_CONF | grep "PYENV_PATH" | grep -ic ${PYENV_PATH})
        if [ $found -gt 0 ]; then
            echo "has already setup python env, skip this step..."
            return 0
        else
            printf "%s" "delete antiquated conf: ${PYENV_CONF}.\n"
            rm -r ${PYENV_CONF}
        fi
    fi

    download_pyenv && pyenv_to_conf
    remove_tmp > /dev/null 2>&1

    OS_TYPE=$(uname -s)
    source $SCRIPT_PATH/$OS_TYPE/pyenv_${OS_TYPE}.sh
}

python_env
