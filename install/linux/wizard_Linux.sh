#!/bin/bash

# Source env.sh to get export_env function
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/env.sh"

func_installing_status()
{
    if [ $# -eq 0 ]; then
        echo -e "\nerror: requires package name to install it, exit..\n"
        exit 1
    fi

    echo "$@"

    local error_pkg=""
    for pkg in "$@";
    do
        $SUDO ${INSTALL_CMD} ${pkg}

        if [ $? -ne 0 ]; then
            echo -e "\nfailed to install: ${pkg}\n"
            error_pkg="${error_pkg} ${pkg}"
        fi
    done

    if [ "${error_pkg}xyzab" != "xyzab" ]; then
        echo -e "\n\nwarning:\nfailed to install: ${error_pkg}\n\n"
    fi
}

func_bash_env()
{
    alias_found=`cat $SHELL_RC | grep -c "alias ll="`
    if [ $alias_found -eq 0 ]; then
        # alias
        echo -e "\nalias ll='ls -l --color=auto'" >> $SHELL_RC
        echo -e "alias la='ls -la --color=auto'" >> $SHELL_RC
        echo -e "alias ls='ls --color=auto'" >> $SHELL_RC
    fi

    export_env PS1 '"\[\e]0;\u@\h: \w\a\]\[\e[33m\]\u@\h\[\e[0m\]:\[\033[01;34m\]\w\[\e[0m\]\$ "'
    # force color prompt
    sed 's/\#force_color_prompt=yes/force_color_prompt=yes/g' -i ${SHELL_RC}
}

func_sudo_env()
{
    # keep user env and add customized env path to sudo secure_path variable
    env_reset_found=`$SUDO cat /etc/sudoers | grep -c "env_reset"`
    if [ $env_reset_found -gt 0 ]; then
        $SUDO sed -E -i 's/\!*env_reset/!env_reset/g' /etc/sudoers
    else
        set +H
        $SUDO bash -c 'echo -e "Defaults\t!env_reset" >> /etc/sudoers'
        set -H
    fi

    secure_path_found=`$SUDO cat /etc/sudoers | grep -c secure_path`
    if [ $secure_path_found -gt 0 ]; then
        path_found=`$SUDO cat /etc/sudoers | grep -c ${BIN_DIR}`
        if [ $path_found -eq 0 ]; then
            ENV_BIN_ESCAPE=${BIN_DIR//\//\\\/}
            $SUDO sed -i "s/secure_path=\"/secure_path=\"$ENV_BIN_ESCAPE:/g" /etc/sudoers
        fi
    fi
}

func_sys_env() {
    SYS_PATH=${UTILSSETS_ROOT}/tools/sys

    if [ -d $HOME/.fonts/NotoSerifCJKsc-hinted ]; then
        echo "has already setup sys env, jump to next step..."
        return
    fi

    # must be the last step in func_sysenv
    if [ ! -d $HOME_PATH/.fonts ]; then
        mkdir -p $HOME/.fonts
        wget https://noto-website-2.storage.googleapis.com/pkgs/NotoSans-hinted.zip -O $HOME/.fonts/NotoSans-hinted.zip
        wget https://noto-website-2.storage.googleapis.com/pkgs/NotoSerif-hinted.zip -O $HOME/.fonts/NotoSerif-hinted.zip
        wget https://noto-website-2.storage.googleapis.com/pkgs/NotoSansCJKsc-hinted.zip -O $HOME/.fonts/NotoSansCJKsc-hinted.zip
        wget https://noto-website-2.storage.googleapis.com/pkgs/NotoSerifCJKsc-hinted.zip -O $HOME/.fonts/NotoSerifCJKsc-hinted.zip

        pushd $HOME/.fonts
        unzip NotoSans-hinted.zip -d NotoSans-hinted
        unzip NotoSerif-hinted.zip -d NotoSerif-hinted
        unzip NotoSansCJKsc-hinted.zip -d NotoSansCJKsc-hinted
        unzip NotoSerifCJKsc-hinted.zip -d NotoSerifCJKsc-hinted
        popd

        fc-cache
    fi
}

func_android_env() {
    # setup udev rules for example
    rules_example='/etc/udev/rules.d/51-android.rules.example'

    if [ -e $rules_example ]; then
        echo "has already created udev rule example, jump to next step..."
        return
    fi

    $SUDO mkdir -p /etc/udev/rules.d
    echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="22d9", ATTR{idProduct}=="276c", MODE="0660", GROUP="plugdev", SYMLINK+="android%n"' | $SUDO tee $rules_example
    # $SUDO service udev restart
}

ubuntu_sources()
{
    if ! command -v lsb_release >/dev/null 2>&1; then
        echo "lsb_release not found, skip this step"
        return
    fi

    $SUDO mv /etc/apt/sources.list /etc/apt/sources.list_bk
    local codename=$(lsb_release -cs)

    $SUDO tee -a /etc/apt/sources.list >/dev/null <<EOF
# deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${codename} main restricted universe multiverse
# deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${codename}-updates main restricted universe multiverse
# deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${codename}-backports main restricted universe multiverse
# deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${codename}-security main restricted universe multiverse
# deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${codename}-proposed main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${codename} main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${codename}-updates main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${codename}-backports main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${codename}-security main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${codename}-proposed main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ ${codename} main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ ${codename}-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ ${codename}-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ ${codename}-proposed main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ ${codename}-backports main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ ${codename} main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ ${codename}-security main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ ${codename}-updates main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ ${codename}-proposed main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ ${codename}-backports main restricted universe multiverse
EOF

    $SUDO apt-get update
}

debian_sources()
{
    if ! command -v lsb_release >/dev/null 2>&1; then
        echo "lsb_release not found, skip this step"
        return
    fi

    $SUDO mv /etc/apt/sources.list /etc/apt/sources.list_bk
    local codename=$(lsb_release -cs)
    if [ $? -ne 0 ]; then
        echo "run cmd: lsb_release -cs failed, return"
    fi

    echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian/ ${codename} main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ ${codename}-updates main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ ${codename}-backports main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security ${codename}-security main contrib non-free non-free-firmware

deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ ${codename} main contrib non-free non-free-firmware
deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ ${codename}-updates main contrib non-free non-free-firmware
deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ ${codename}-backports main contrib non-free non-free-firmware
deb-src https://mirrors.tuna.tsinghua.edu.cn/debian-security ${codename}-security main contrib non-free non-free-firmware" | $SUDO tee /etc/apt/sources.list

    $SUDO apt-get update
}

func_linux_sources()
{
    if [ "x$OS_NAME" == "xubuntu" ]; then
        ubuntu_sources
        $SUDO ${PKG_MANAGER} ${PKG_INSTALL} apt-utils
    elif [ "x$OS_NAME" == "xdebian" ]; then
        debian_sources
        $SUDO ${PKG_MANAGER} ${PKG_INSTALL} apt-utils
    else
        echo "os type: $OS_TYPE, os name: $OS_NAME, skip changing package sources."
    fi

}

func_linux_sources
# install package
func_installing_status build-essential git-lfs openjdk-17-jdk \
    make automake cmake cscope vim bash-completion pkg-config \
    openssh-server cifs-utils tree texinfo gettext flex bison \
    dos2unix libssl-dev libffi-dev libreadline-dev gdb unzip autoconf \
    libyaml-dev libxml2-dev libseccomp-dev libbz2-dev liblzma-dev \
    astyle zlib1g-dev inetutils-ping net-tools iptables iproute2 libtool \
    libncurses-dev sqlite3 libsqlite3-dev

func_bash_env
func_sudo_env
func_android_env
setup_bash_env

# Configure locale (default: C.UTF-8)
bash "${SCRIPT_DIR}/../common/setup_locale.sh"
bash "${SCRIPT_DIR}/../common/setup_pip.sh"
