#!/bin/bash

install_package()
{
  # necessary package
  $SUDO ${INSTALL_CMD} curl wget tree ctags
}

shell_env()
{
  ps1_found=$(cat ${BASH_RC} | grep -c "PS1")
  if [ ${ps1_found} -eq 0 ]; then
    export CLICOLOR=1
    export LSCOLORS=ExGxFxdaCxDaDahbadech
    export HOMEBREW_NO_AUTO_UPDATE=1
    export PS1="\[\e]0;\u@\h: \w\a\]\[\e[33m\]\u@\h:\w\$\[\e[0m\] "
    echo 'export PS1="\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> ${BASH_RC}
  fi

  brew_found=$(echo "$PATH" | grep -ic homebrew)
  if [ $brew_found -eq 0 ]; then
     echo "export PATH=\"/opt/homebrew/bin:$PATH\"" >> ${ENV_CONF}
  fi
}

install_package
shell_env
