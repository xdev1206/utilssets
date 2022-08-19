#!/bin/bash

if [ -z "${BASH_VERSION:-}" ]; then
  abort "Bash is required to interpret this script."
fi

# Check if script is run non-interactively (e.g. CI)
# If it is run non-interactively we should not prompt for passwords.
if [[ ! -t 0 || -n "${CI-}" ]]; then
  NONINTERACTIVE=1
fi

ENV_ROOT=$(cd `dirname $BASH_SOURCE`/../env && /bin/pwd)
ENV_BIN=${ENV_ROOT}/bin
ENV_CONF=$ENV_ROOT/config.env

found=$(cat "$BASH_RC" | grep -c "ENV_PATH=")
if [ $found -eq 0 ]; then
    echo "export ENV_PATH=$ENV_ROOT" >> $BASH_RC
fi

echo "ENV_ROOT: ${ENV_ROOT}"
echo "ENV_BIN: ${ENV_BIN}"
echo "ENV_CONF: ${ENV_CONF}"
