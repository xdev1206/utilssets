#!/bin/sh

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

pyenv_to_conf()
{
    export_env PYENV_PATH $PYENV_PATH
    complete_env_path $PYENV_PATH/bin

    $PYENV_PATH/bin/pyenv init - >> $PYENV_CONF
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
