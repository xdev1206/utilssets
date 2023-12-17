#!/bin/bash

# sudo
uid=$(id -u)
if [ $uid -ne 0 ]; then
    SUDO=sudo
fi

os_variable()
{
    BASH_RC="$HOME/.bashrc"
    OS_TYPE=$(uname -s)
    if [ "x${OS_TYPE}" == "xLinux" ]; then
        BASH_RC="$HOME/.bashrc"

        if [ -f '/etc/centos-release' ]; then
            OS_NAME='centos'
            OS_VERSION=`cat /etc/centos-release | grep -oE "[0-9]+.[0-9]+.[0-9]+"`
            INSTALL_CMD='yum install -y'
        elif [ -f '/etc/redhat-release' ]; then
            OS_NAME='redhat'
            INSTALL_CMD='yum install -y'
        elif [ -f '/etc/oracle-release' ]; then
            OS_NAME='oracle'
        elif [ -f '/etc/lsb-release' ]; then
            OS_NAME='ubuntu'
            OS_VERSION=`cat /etc/lsb-release | grep DISTRIB_RELEASE | cut -d'=' -f 2`
            PKG_UPDATE_CMD='apt update'
            INSTALL_CMD='apt install -y'
        elif [ -f '/etc/debian_version' ]; then
            OS_NAME='debian'
            PKG_UPDATE_CMD='apt update'
            INSTALL_CMD='apt install -y'
            OS_VERSION=$(cat /etc/debian_version)
        else
            OS_NAME="unknown"
            OS_VERSION="unknown"
        fi
    elif [ "x${OS_TYPE}" == "xDarwin" ]; then
        BASH_RC="$HOME/.bash_profile"
        OS_NAME=`sw_vers -productName`
        OS_VERSION=`sw_vers -productVersion`

        #Running Homebrew as root is extremely dangerous and no longer supported
        SUDO=''
        INSTALL_CMD='brew install'
        if [ "${SHELL}" != "/bin/bash" ]; then
            echo "Please use bash as default interactive shell on ${OS_NAME}"
            exit 0
        fi
    fi

    echo "BASH_RC: ${BASH_RC}"
    echo "OS_TYPE: $OS_TYPE"
    echo "OS_NAME: $OS_NAME"
    echo "OS_VERSION: $OS_VERSION"
}

os_variable
