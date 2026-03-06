#!/bin/bash

install_package()
{
  # necessary package
  $SUDO ${INSTALL_CMD} curl wget tree ctags
}

#LSCOLORS 是22个字符11组 每组两个字符

#字母	含义	前景/背景色
#a	黑色	Fore/Back
#b	红色	Fore/Back
#c	绿色	Fore/Back
#d	棕色/黄色	Fore/Back
#e	蓝色	Fore/Back
#f	洋红色（紫色）	Fore/Back
#g	青色（浅蓝）	Fore/Back
#h	浅灰	Fore/Back
#x	默认终端颜色	Fore/Back

#文件类型	前景色字母	背景色字母	颜色效果
#目录	e	x	蓝色文字 / 默认背景
#符号链接	f	x	洋红文字 / 默认背景
#socket	c	x	绿色文字
#pipe	d	x	棕色文字
#可执行文件	b	x	红色文字
#块设备	e	g	蓝色文字 / 青色背景
#字符设备	e	d	蓝色文字 / 棕色背景
#可读 sticky 目录	a	b	黑色文字 / 红色背景
#可写 sticky 目录	a	g	黑色文字 / 青色背景
#可读可写目录	a	c	黑色文字 / 绿色背景
#其他文件	a	d	黑色文字 / 棕色背景

shell_env()
{
    export_env CLICOLOR 1
    export_env LSCOLORS exfxcxdxcxegedabagacad
    export_env HOMEBREW_NO_AUTO_UPDATE 1
    if [ "${SHELL}" = "/bin/bash" ]; then
        export_env PS1 "\"\[\e]0;\u@\h: \w\a\]\[\e[33m\]\u@\h:\w\$\[\e[0m\] \""
        echo 'export PS1="\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "'
    elif [ "${SHELL}" = "/bin/zsh" ]; then
        export_env PS1 "\"%F{green}%n@%f:%F{blue}%~%f%# \""
        echo 'export PS1="%F{green}%n@%f:%F{blue}%~%f%# "'
        echo 'autoload -Uz compinit' >> ${SHELL_RC}
        echo 'compinit' >> ${SHELL_RC}
    fi
}

install_package
shell_env

source keybindings.sh
