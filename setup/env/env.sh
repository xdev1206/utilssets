#!/bin/bash

if [ -z "${BASH_VERSION:-}" ]; then
    abort "Bash is required to interpret this script."
fi

# env path
SCRIPT_DIR=$(cd `dirname $BASH_SOURCE` && /bin/pwd)
source ${SCRIPT_DIR}/prerequisite.sh

# ENV_ROOT
# ENV_BIN
# ENV_CONF
function env_variable()
{
    # Check if script is run non-interactively (e.g. CI)
    # If it is run non-interactively we should not prompt for passwords.
    if [[ ! -t 0 || -n "${CI-}" ]]; then
        NONINTERACTIVE=1
    fi

    ENV_ROOT=$(cd `dirname $BASH_SOURCE`/../../env && /bin/pwd)
    ENV_BIN=${ENV_ROOT}/bin
    ENV_CONF=$ENV_ROOT/config/env.conf

    echo "ENV_ROOT: ${ENV_ROOT}"
    echo "ENV_BIN: ${ENV_BIN}"
    echo "ENV_CONF: ${ENV_CONF}"
}

# NETWORK
function reach_github()
{
  local url="https://github.com"
  local code=`curl -I -s ${url} -w %{http_code} | tail -n1`
  if [ "x${code}" == "x200" ]; then
    NETWORK=1
    reach_network=1
  else
    NETWORK=0
    reach_network=0
  fi
  echo "connecting to github.com, status: $reach_network, http_code: $code"
  echo "NETWORK: ${reach_network}"
}

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

env_variable
reach_github
setup_env_conf
setup_bash_env
