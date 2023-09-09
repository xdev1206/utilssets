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

function setup_bash_env()
{
    local found=0

    found=$(cat "$BASH_RC" | grep -c "ENV_PATH=")
    if [ $found -eq 0 ]; then
        echo "export ENV_PATH=$ENV_ROOT" >> $BASH_RC
    fi

    found=$(cat "$BASH_RC" | grep -c "ENV_PATH/config.env")
    if [ $found -eq 0 ]; then
        echo 'source $ENV_PATH/config.env' >> $BASH_RC
    fi
}

function setup_env_conf()
{
    local found=0
    # avoid add 'export PATH=${ENV_PATH}/bin:${PATH}' into env.conf repeatly
    found=$(cat "$ENV_CONF" | grep -c "ENV_PATH")

    if [ $found -eq 0 ]; then
        cat <<EOF >> $ENV_CONF
found=\$(echo "\$PATH" | grep -c "\$ENV_PATH")
if [ \$found -eq 0 ]; then
    export PATH=\${ENV_PATH}/bin:\${PATH}
fi
EOF
    fi
}

function complete_env_path()
{
    if [ $# -ne 1 ]; then
        echo "complete_env_path: only support 1 parameter, error!"
        exit 1
    fi

    envpath=$1
    found=$(cat ${ENV_CONF} | grep -c "${envpath}")
    if [ $found -eq 0 ]; then
        cat >> ${ENV_CONF} << EOF
found=\$(echo "\$PATH" | grep -c "${envpath}")
if [ \$found -eq 0 ]; then
  export PATH=${envpath}:\${PATH}
fi
EOF
    else
        echo "env path: ${envpath} already exists in ${ENV_CONF}"
    fi
}

setup_env_conf
setup_bash_env
