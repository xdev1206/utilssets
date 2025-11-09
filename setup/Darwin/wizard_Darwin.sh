#!/bin/bash

install_package()
{
  # necessary package
  $SUDO ${INSTALL_CMD} curl wget tree ctags
}

shell_env()
{
  ps1_found=$(cat ${SHELL_RC} | grep -c "PS1")
  if [ ${ps1_found} -eq 0 ]; then
    export CLICOLOR=1
    export LSCOLORS=ExGxFxdaCxDaDahbadech
    echo "export HOMEBREW_NO_AUTO_UPDATE=1" >> ${SHELL_RC}
    if [ "${SHELL}" = "/bin/bash" ]; then
        export PS1="\[\e]0;\u@\h: \w\a\]\[\e[33m\]\u@\h:\w\$\[\e[0m\] "
        echo 'export PS1="\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> ${SHELL_RC}
    elif [ "${SHELL}" = "/bin/zsh" ]; then
        export PS1="%F{green}%n@%f:%F{blue}%~%f%# "
        echo 'export PS1="%F{green}%n@%f:%F{blue}%~%f%# "' >> ${SHELL_RC}
        echo 'autoload -Uz compinit' >> ${SHELL_RC}
        echo 'compinit' >> ${SHELL_RC}
    fi
  fi
}

install_package
shell_env
