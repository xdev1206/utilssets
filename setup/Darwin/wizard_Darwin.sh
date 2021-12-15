#!/bin/bash

install_package()
{
  # necessary package
  ${INSTALL_CMD} curl wget tree
}

shell_env()
{
  ps1_found=$(cat ${BASH_RC} | grep -c "PS1")
  if [ ${ps1_found} -eq 0 ]; then
    export PS1="%F{yellow}%n@%m %d%#%f "
    echo 'export PS1="%F{yellow}%n@%m %d%#%f "' >> ${BASH_RC}
  fi

  env_path_found=$(echo ${PATH} | grep -c "${ENV_PATH}")
  if [ ${env_path_found} -eq 0 ]; then
    export PATH=$ENV_PATH/bin:$PATH
    echo 'export PATH=$ENV_PATH/bin:$PATH' >> ${BASH_RC}
  fi
}

brew_found=$(echo "$PATH" | grep -ic homebrew)
if [ $brew_found -eq 0 ]; then
   export PATH="/opt/homebrew/bin:$PATH"
   echo "export PATH=\"/opt/homebrew/bin:$PATH\"" >> $BASH_RC
fi

install_package
shell_env
