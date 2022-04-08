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
