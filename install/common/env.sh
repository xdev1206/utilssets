#!/usr/bin/env bash

# 获取脚本目录的兼容函数
function get_script_dir() {
    if [ -n "$BASH_VERSION" ]; then
        echo "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    elif [ -n "$ZSH_VERSION" ]; then
        echo "$(cd "$(dirname "${(%):-%x}")" && pwd)"
    else
        echo "$(cd "$(dirname "$0")" && pwd)"
    fi
}

# 获取脚本目录并切换
SCRIPT_DIR=$(get_script_dir)
source ${SCRIPT_DIR}/prerequisite.sh

# UTILSSETS_ROOT, BIN_DIR, CONFIG_DIR
function env_variable()
{
    if [[ ! -t 0 || -n "${CI-}" ]]; then
        NONINTERACTIVE=1
    fi

    UTILSSETS_ROOT=$(cd `dirname $BASH_SOURCE`/../.. && /bin/pwd)
    BIN_DIR=${UTILSSETS_ROOT}/bin
    TOOLS_BIN_DIR=${UTILSSETS_ROOT}/tools/bin
    CONFIG_DIR=${UTILSSETS_ROOT}/config
    CONFIG_PATH=${CONFIG_DIR}/shell
    SHELL_CONF=${CONFIG_PATH}/env.conf
    PATH_CONF=${CONFIG_PATH}/path.conf
    LIB_PYTHON=${UTILSSETS_ROOT}/lib/python

    [ ! -d "${BIN_DIR}" ] && mkdir -p "${BIN_DIR}"
    [ ! -d "${TOOLS_BIN_DIR}" ] && mkdir -p "${TOOLS_BIN_DIR}"
    [ ! -d "${CONFIG_PATH}" ] && mkdir -p "${CONFIG_PATH}"
    [ ! -d "${LIB_PYTHON}" ] && mkdir -p "${LIB_PYTHON}"

    # Create config.env if not exists
    if [ ! -f "${CONFIG_PATH}/config.env" ]; then
        cat > "${CONFIG_PATH}/config.env" << 'EOF'
# Detect UTILSSETS_ROOT if not set
if [ -z "${UTILSSETS_ROOT}" ]; then
    UTILSSETS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

CONFIG_PATH="${UTILSSETS_ROOT}/config/shell"

# Source all config files
for config in "${CONFIG_PATH}"/*.conf; do
    [ -f "$config" ] && source "$config"
done
EOF
    fi

    echo "UTILSSETS_ROOT: ${UTILSSETS_ROOT}"
    echo "BIN_DIR: ${BIN_DIR}"
    echo "CONFIG_DIR: ${CONFIG_DIR}"
    echo "LIB_PYTHON: ${LIB_PYTHON}"
}

function reach_github()
{
    # Skip if NETWORK already set
    if [ -n "${NETWORK:-}" ]; then
        echo "Network status already set: ${NETWORK}"
        return
    fi

    NETWORK=0

    if ! command -v curl >/dev/null 2>&1; then
        echo "curl not found, skip network check"
        return
    fi

    local url="https://github.com"
    local code=`curl --connect-timeout 10 -I -s ${url} -w %{http_code} | tail -n1`
    if [ "x${code}" == "x200" ]; then
        NETWORK=1
    fi
    printf_msg "connecting to github.com, status: ${NETWORK}, http_code: $code\n"
}

function escape_sed_replacement() {
    printf '%s\n' "$1" | sed 's/[&/\]/\\&/g'
}

function export_env()
{
    if [ $# -ne 2 ]; then
        echo "export_env: requires 2 parameters: <env_name> <env_value>" >&2
        return 1
    fi

    local env_name="$1"
    local env_param="$2"

    echo "env_name: ${env_name}"
    echo "env_param: ${env_param}"

    # 校验环境变量名合法性
    if ! [[ "$env_name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        echo "export_env: invalid environment variable name: $env_name" >&2
        return 1
    fi

    if [ -z "$SHELL_CONF" ]; then
        echo "export_env: SHELL_CONF: ${SHELL_CONF} is not set!" >&2
        return 1
    fi

    [ ! -f "$SHELL_CONF" ] && touch "$SHELL_CONF"

    local pattern="^export[[:space:]]+${env_name}="

    if grep -qE "$pattern" "$SHELL_CONF"; then
        local env_param_escape=$(escape_sed_replacement "$env_param")
        echo "env_param_escape: ${env_param_escape}"

        case "$(uname -s)" in
            Darwin)
                sed -i '' "s|^export[[:space:]]\+${env_name_escape}=.*$|export ${env_name_escape}=${env_param_escape}|" "$SHELL_CONF"
                ;;
            *)
                sed -i "s|^export[[:space:]]\+${env_name}=.*$|export ${env_name}=${env_param_escape}|" "$SHELL_CONF"
                ;;
        esac
    else
        echo "export ${env_name}=${env_param}" >> "$SHELL_CONF"
    fi
}

function complete_env_path()
{
    if [ $# -ne 2 ]; then
        echo "Usage: complete_env_path <env_name> <path>"
        return 1
    fi

    local envname="$1"
    local envpath="$2"

    [ ! -f "${PATH_CONF}" ] && touch "${PATH_CONF}"

    # Convert absolute path to use UTILSSETS_ROOT variable
    local relative_path="${envpath#${UTILSSETS_ROOT}/}"
    if [ "$relative_path" != "$envpath" ]; then
        envpath="\${UTILSSETS_ROOT}/${relative_path}"
    fi

    if grep -Fq "${relative_path}" "${PATH_CONF}"; then
        echo "env path: ${relative_path} already exists"
        return 0
    fi

    cat >> "${PATH_CONF}" << EOF

case ":\$${envname}:" in
    *:${envpath}:*) ;;
    *) export ${envname}="${envpath}:\$${envname}" ;;
esac
EOF

    echo "Added ${envpath} to ${PATH_CONF}"
}

function setup_bash_env()
{
    if ! grep -q "UTILSSETS_ROOT=" "${SHELL_RC}" 2>/dev/null; then
        echo "export UTILSSETS_ROOT=${UTILSSETS_ROOT}" >> "${SHELL_RC}"
    fi

    if ! grep -q "config/shell/config.env" "${SHELL_RC}" 2>/dev/null; then
        echo 'source ${UTILSSETS_ROOT}/config/shell/config.env' >> "${SHELL_RC}"
    fi

    env_variable
    reach_github
    complete_env_path PATH ${BIN_DIR}
    complete_env_path PATH ${TOOLS_BIN_DIR}
    complete_env_path PYTHONPATH ${LIB_PYTHON}

}

# Auto-detect and export TERM color depth
# Priority: 24bit truecolor > 256color > 16color > 8color
function setup_term_color()
{
    local term_val="xterm"
    local colorterm_val=""

    # Check truecolor support via COLORTERM (set by all modern truecolor terminals)
    if [[ "${COLORTERM:-}" == "truecolor" || "${COLORTERM:-}" == "24bit" ]]; then
        term_val="xterm-256color"
        colorterm_val="truecolor"
    elif infocmp xterm-256color &>/dev/null 2>&1; then
        term_val="xterm-256color"
    elif infocmp xterm-16color &>/dev/null 2>&1; then
        term_val="xterm-16color"
    fi

    export_env TERM "${term_val}"
    if [ -n "${colorterm_val}" ]; then
        export_env COLORTERM "${colorterm_val}"
    fi
}

setup_bash_env
setup_term_color
