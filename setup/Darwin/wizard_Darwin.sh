#!/bin/bash

install_package()
{
  # necessary package
  $SUDO ${INSTALL_CMD} curl wget tree
}

brew_found=$(echo "$PATH" | grep -ic homebrew)
if [ $brew_found -eq 0 ]; then
   export PATH="/opt/homebrew/bin:$PATH"
   echo "export PATH=\"/opt/homebrew/bin:$PATH\"" >> $BASH_RC
fi

bashrc_found=$(cat ${BASH_RC} | grep -ic 'source $HOME/.bashrc')
if [ $bashrc_found -eq 0 ]; then
   echo 'source $HOME/.bashrc' >> $BASH_RC
fi

install_package
