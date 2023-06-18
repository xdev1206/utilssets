# write vim env config to config.env
vim_env_to_config()
{
    sed '/^export.*VIM_PATH.*/d' -i $ENV_CONF
    echo "export VIM_PATH=$VIM_PATH" >> $ENV_CONF
}

vim_dependency()
{
    # need network
    if [ "x${reach_network}" == "x1" ]; then
        if [ "x$OS_NAME" == "xdebian" -o "x$OS_NAME" == "xubuntu" ]; then
            # install universal-ctags manuually
            ${SUDO} ${INSTALL_CMD} exuberant-ctags libxml2 libjansson-dev libyaml-dev
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
