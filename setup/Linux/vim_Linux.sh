# write vim env config to config.env
vim_env_to_config()
{
    local shell_rc="$HOME/.bashrc"

    sed '/^export.*VIM_PATH.*/d' -i $ENV_CONF
    echo "export VIM_PATH=$VIM_PATH" >> $ENV_CONF

    found=$(cat "$shell_rc" | grep -c "$ENV_CONF")
    if [ $found -eq 0 ]; then
        echo "export ENV_PATH=$ENV_ROOT" >> $shell_rc
        echo "source $ENV_CONF" >> $shell_rc
    fi
}

vim_dependency()
{
    # need network
    if [ "x${reach_network}" == "x1" ]; then
        if [ "x$OS_NAME" == "xdebian" -o "x$OS_NAME" == "xubuntu" ]; then
            ${SUDO} ${INSTALL_CMD} universal-ctags libxml2 libjansson-dev libyaml-dev
        fi
    else
	echo "can't connect to network, ignore this action."
    fi
}

vim_os_specific()
{
    vim_env_to_config
    vim_dependency
}

echo "do vim os specific setting up"
vim_os_specific
