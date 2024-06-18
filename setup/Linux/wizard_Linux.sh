#!/bin/bash

func_installing_status()
{
    if [ $# -eq 0 ]; then
        echo -e "\nerror: requires package name to install it, exit..\n"
        exit 1
    fi

    echo "$@"

    local error_pkg
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
    alias_found=`cat $BASH_RC | grep -c "alias ll="`
    if [ $alias_found -eq 0 ]; then
        # alias
        echo -e "\nalias ll='ls -l --color=auto'" >> $BASH_RC
        echo -e "alias la='ls -la --color=auto'" >> $BASH_RC
    fi

    ps1_found=$(cat ${BASH_RC} | grep -c "PS1")
    if [ ${ps1_found} -eq 0 ]; then
        export PS1="\[\e]0;\u@\h: \w\a\]\[\e[33m\]\u@\h:\w\$\[\e[0m\] "
        echo 'export PS1="\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> ${BASH_RC}
    fi

    # force color prompt
    sed 's/\#force_color_prompt=yes/force_color_prompt=yes/g' -i ${BASH_RC}
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
        path_found=`$SUDO cat /etc/sudoers | grep -c $ENV_BIN`
        if [ $path_found -eq 0 ]; then
            ENV_BIN_ESCAPE=${ENV_BIN//\//\\\/}
            $SUDO sed -i "s/secure_path=\"/secure_path=\"$ENV_BIN_ESCAPE:/g" /etc/sudoers
        fi
    fi
}

func_sys_env() {
    SYS_PATH=$ENV_ROOT/sys

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
    $SUDO mv /etc/apt/sources.list /etc/apt/sources.list_bk
    local codename=$(lsb_release -cs)

    $SUDO cat >> /etc/apt/sources.list << EOF
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${codename} main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${codename}-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${codename}-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${codename}-security main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${codename}-proposed main restricted universe multiverse
deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${codename} main restricted universe multiverse
deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${codename}-updates main restricted universe multiverse
deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${codename}-backports main restricted universe multiverse
deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${codename}-security main restricted universe multiverse
deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${codename}-proposed main restricted universe multiverse

#deb http://mirrors.aliyun.com/ubuntu/ ${codename} main restricted universe multiverse
#deb http://mirrors.aliyun.com/ubuntu/ ${codename}-security main restricted universe multiverse
#deb http://mirrors.aliyun.com/ubuntu/ ${codename}-updates main restricted universe multiverse
#deb http://mirrors.aliyun.com/ubuntu/ ${codename}-proposed main restricted universe multiverse
#deb http://mirrors.aliyun.com/ubuntu/ ${codename}-backports main restricted universe multiverse
#deb-src http://mirrors.aliyun.com/ubuntu/ ${codename} main restricted universe multiverse
#deb-src http://mirrors.aliyun.com/ubuntu/ ${codename}-security main restricted universe multiverse
#deb-src http://mirrors.aliyun.com/ubuntu/ ${codename}-updates main restricted universe multiverse
#deb-src http://mirrors.aliyun.com/ubuntu/ ${codename}-proposed main restricted universe multiverse
#deb-src http://mirrors.aliyun.com/ubuntu/ ${codename}-backports main restricted universe multiverse
EOF

    $SUDO apt update
}

debian_sources()
{
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

    $SUDO apt update
}

func_linux_sources()
{
    if [ "x$OS_NAME" == "xubuntu" ]; then
        ubuntu_sources
    elif [ "x$OS_NAME" == "xdebian" ]; then
        debian_sources
    else
        echo "os type: $OS_TYPE, os name: $OS_NAME, skip changing package sources."
    fi

    #pip source
    $SUDO mv /etc/pip.conf /etc/pip.conf.bk
    echo "[global]
index-url = https://mirrors.aliyun.com/pypi/simple
extra-index-url = https://pypi.tuna.tsinghua.edu.cn/simple
timeout = 120" | $SUDO tee /etc/pip.conf
}

func_linux_sources
# install package
func_installing_status build-essential openjdk-17-jdk \
    make automake cmake cscope vim bash-completion pkg-config \
    openssh-server cifs-utils tree texinfo gettext flex bison \
    dos2unix libssl-dev libreadline-dev libsqlite3-dev gdb unzip autoconf \
    libyaml-dev libxml2-dev libseccomp-dev libjansson-dev python3-tk \
    python3-docutils python3-dev libbz2-dev liblzma-dev astyle zlib1g-dev \
    libffi-dev inetutils-ping net-tools iptables iproute2 libtool libncurses-dev libu2f-udev \
    fonts-liberation fonts-noto-cjk

func_bash_env
func_sudo_env
func_android_env
