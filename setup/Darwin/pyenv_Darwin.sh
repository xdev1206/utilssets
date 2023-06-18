pyenv_os_specific()
{
    if [ "x$OS_NAME" == "xdebian" -o "x$OS_NAME" == "xubuntu" ]; then
        $SUDO ${INSTALL_CMD} libsqlite3-dev libssl-dev libreadline-dev libbz2-dev curl zlib1g-dev
    fi
}

echo "pyenv: ${OS_NAME} specific setting up"
pyenv_os_specific
