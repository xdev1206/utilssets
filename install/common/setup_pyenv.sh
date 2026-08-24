#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.sh"

PYENV_PATH="${UTILSSETS_ROOT}/tools/pyenv"

install_dependencies()
{
    if [ "${OS_TYPE}" = "Linux" ]; then
        if [ "${OS_NAME}" = "debian" ] || [ "${OS_NAME}" = "ubuntu" ]; then
            echo "Installing pyenv dependencies for ${OS_NAME}..."
            ${SUDO} ${INSTALL_CMD} libsqlite3-dev libssl-dev libreadline-dev libbz2-dev curl zlib1g-dev
        fi
    fi
}

setup_pyenv()
{
    if [ -d "${PYENV_PATH}" ]; then
        echo "pyenv already installed at ${PYENV_PATH}"
        return 0
    fi

    install_dependencies

    echo "Installing pyenv..."
    git clone --depth 1 https://github.com/pyenv/pyenv.git "${PYENV_PATH}" || {
        echo "Failed to install pyenv"
        return 1
    }

    git clone --depth 1 https://github.com/pyenv/pyenv-virtualenv.git "${PYENV_PATH}/plugins/pyenv-virtualenv" || {
        echo "Failed to install pyenv-virtualenv"
        return 1
    }

    export_env PYENV_ROOT "${PYENV_PATH}"
    export PYENV_ROOT="${PYENV_PATH}"
    complete_env_path PATH "${PYENV_PATH}/bin"
    complete_env_path PATH "${PYENV_PATH}/shims"

    ${PYENV_PATH}/bin/pyenv init - > ${UTILSSETS_ROOT}/tools/bin/pyenv_init 2>&1
    chmod +x ${UTILSSETS_ROOT}/tools/bin/pyenv_init

    echo "pyenv installed successfully"
}

setup_pyenv
