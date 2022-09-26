#!/bin/bash

# env path
ENV_SCRIPT_DIR=$(cd `dirname $BASH_SOURCE` && /bin/pwd)

# BASH_RC
# OS_NAME
# OS_VERSION
# INSTALL_CMD
if [ "x${OS_NAME}" == "x" ]; then
  source ${ENV_SCRIPT_DIR}/os_type.sh
fi

# ENV_ROOT
# ENV_BIN
# ENV_CONF
if [ "x${ENV_ROOT}" == "x" ]; then
  source ${ENV_SCRIPT_DIR}/path.sh
fi

# reach_network
if [ "x${reach_network}" == "x" ]; then
  source ${ENV_SCRIPT_DIR}/reach_github.sh
fi

check_env()
{
    local found=$(cat "$BASH_RC" | grep -c "ENV_PATH=")
    if [ $found -eq 0 ]; then
        echo "export ENV_PATH=$ENV_ROOT" >> $BASH_RC
    fi

    found=$(cat "$BASH_RC" | grep -c "$ENV_PATH/config.env")
    if [ $found -eq 0 ]; then
        echo 'source $ENV_PATH/config.env' >> $BASH_RC
    fi
}

check_env
