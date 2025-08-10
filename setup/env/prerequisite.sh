#!/bin/bash

function printf_msg()
{
    if [ $# -ne 1 ]; then
        msg="message parameter error"
    fi

    msg="$1"
    printf "\e[31m%b%s\e[0m" "${msg}"
}

# Shell函数：检查shellrc中是否包含指定path_var字符串
check_path_in_shellrc()
{
    local path_var="$1"
    local shellrc="$2"

    # 使用grep的-F参数进行固定字符串搜索，防止正则误判
    # 使用-- "$path_var" 处理特殊字符和引号
    if grep -F -- "$path_var" ~/${shellrc} > /dev/null; then
        echo "$path_var: exists"
        return 0
    else
        echo "$path_var: not found"
        return 1
    fi
}

darwin_cmd()
{
    if command -v brew >/dev/null 2>&1; then
        echo "brew command exists!"
        return
    fi

    echo "install homebrew command"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    local found=$(check_path_in_shellrc HOMEBREW_NO_AUTO_UPDATE ${SHELL_RC})
    if [ "x${found}" = "x1" ]; then
        echo 'export HOMEBREW_NO_AUTO_UPDATE=1' >> ~/.zshrc
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
    fi
}

# SUDO
function sudo_variable()
{

    if [ ${UID} -ne 0 ]; then
        # 判断是macOS还是Linux
        if uname | grep -qi darwin; then
            GROUP="admin"
        else
            GROUP="sudo"
        fi

        sudo_found=$(groups | grep -ic ${GROUP})
        if [ ${sudo_found} -eq 0 ]; then
            printf_msg "user doesn't in sudo group, can't run as privilege!\n"
            SUDO='echo "can not run as privilege, skip!" >&2; false;'
        else
            SUDO=sudo
        fi
    fi
}

# SHELL_RC
# OS_NAME
# OS_VERSION
# INSTALL_CMD
# PKG_MANAGER
# PKG_INSTALL
# PKG_UPDATE
function os_variable()
{
    SHELL_RC="$HOME/.bashrc"
    OS_TYPE=$(uname -s)
    if [ "x${OS_TYPE}" == "xLinux" ]; then
        SHELL_RC="$HOME/.bashrc"

        if [ -f '/etc/centos-release' ]; then
            OS_NAME='centos'
            OS_VERSION=`cat /etc/centos-release | grep -oE "[0-9]+.[0-9]+.[0-9]+"`
            INSTALL_CMD='yum install -y'
            PKG_MANAGER="yum"
            PKG_INSTALL="install -y"
            PKG_UPDATE="update"
        elif [ -f '/etc/redhat-release' ]; then
            OS_NAME='redhat'
            INSTALL_CMD='yum install -y'
            PKG_MANAGER="yum"
            PKG_INSTALL="install -y"
            PKG_UPDATE="update"
        elif [ -f '/etc/lsb-release' ]; then
            OS_NAME='ubuntu'
            OS_VERSION=`cat /etc/lsb-release | grep DISTRIB_RELEASE | cut -d'=' -f 2`
            INSTALL_CMD='apt install -y'
            PKG_MANAGER="apt"
            PKG_INSTALL="install -y"
            PKG_UPDATE="update"
        elif [ -f '/etc/debian_version' ]; then
            OS_NAME='debian'
            OS_VERSION=$(cat /etc/debian_version)
            INSTALL_CMD='apt install -y'
            PKG_MANAGER="apt"
            PKG_INSTALL="install -y"
            PKG_UPDATE="update"
        else
            abort "Can't recognize os type, abort."
        fi
    elif [ "x${OS_TYPE}" == "xDarwin" ]; then
        OS_NAME=`sw_vers -productName`
        OS_VERSION=`sw_vers -productVersion`

        echo "use shell:${SHELL} on ${OS_NAME} ${OS_VERSION}"
        SHELL_RC="${HOME}/.zshrc"
        if [ "${SHELL}" = "/bin/bash" ]; then
            SHELL_RC="$HOME/.bash_profile"
        elif [ "${SHELL}" = "/bin/zsh" ]; then
            SHELL_RC="${HOME}/.zshrc"
        fi

        #Running Homebrew as root is extremely dangerous and no longer supported
        SUDO=''
        INSTALL_CMD='brew install'
        PKG_MANAGER="brew"
        PKG_INSTALL="install"
        PKG_UPDATE="update"

        echo "sudo is not necessary for brew command"
        SUDO=""
        darwin_cmd
    fi

    echo "SHELL_RC: ${SHELL_RC}"
    echo "OS_TYPE: $OS_TYPE"
    echo "OS_NAME: $OS_NAME"
    echo "OS_VERSION: $OS_VERSION"
}

func_installing_status()
{
    if [ $# -eq 0 ]; then
        printf_msg "\nerror: requires package name to install it, exit..\n"
        exit 1
    fi

    echo "$@"

    for cml in "$@";
    do
        if command -v ${cml} >/dev/null 2>&1; then
            echo "${cml} is alreay installed."
            continue
        fi

        eval $SUDO ${PKG_MANAGER} ${PKG_INSTALL} ${cml}
        if [ $? -ne 0 ]; then
            printf_msg "\nerror, failed to install: ${cml}, exit...\n"
            continue
        fi
    done
}

${SUDO} ${PKG_MANAGER} ${PKG_UPDATE}

sudo_variable
os_variable

func_installing_status git lsb-release curl
