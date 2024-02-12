#!/bin/bash

set +x

uid=$(id -u)
if [ "x${uid}" == "x0" ]; then
    SUDO=''
else
    SUDO='sudo'
fi

PKG_M="apt"
PKG_INSTALL="install -y"
PKG_UPDATE="update"

func_installing_status()
{
    if [ $# -eq 0 ]; then
        echo -e "\nerror: requires package name to install it, exit..\n"
        exit 1
    fi

    echo "$@"

    for pkg in "$@";
    do
        $SUDO ${PKG_M} ${PKG_INSTALL} ${pkg}

        if [ $? -ne 0 ]; then
            echo -e "\nerror, failed to install: ${pkg}, exit...\n"
            exit 1
        fi
    done
}

${SUDO} ${PKG_M} ${PKG_UPDATE}

func_installing_status lsb-release git
