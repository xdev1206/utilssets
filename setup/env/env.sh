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
    ENV_PATH_CONF=$ENV_ROOT/config/path.conf

    echo "ENV_ROOT: ${ENV_ROOT}"
    echo "ENV_BIN: ${ENV_BIN}"
    echo "ENV_CONF: ${ENV_CONF}"
}

# NETWORK
function reach_github()
{
  NETWORK=0
  reach_network=0

  if ! command -v curl >/dev/null 2>&1; then
      echo "lsb_release not found, skip this step"
      return
  fi

  local url="https://github.com"
  local code=`curl --connect-timeout 10 -I -s ${url} -w %{http_code} | tail -n1`
  if [ "x${code}" == "x200" ]; then
    NETWORK=1
    reach_network=1
  fi
  printf_msg "connecting to github.com, status: $reach_network, http_code: $code\n"
  printf_msg "NETWORK: ${reach_network}\n"
}

function setup_bash_env()
{
    local found=0

    found=$(cat "$SHELL_RC" | grep -c "ENV_PATH=")
    if [ $found -eq 0 ]; then
        echo "export ENV_PATH=$ENV_ROOT" >> $SHELL_RC
    fi

    found=$(cat "$SHELL_RC" | grep -c "ENV_PATH/config.env")
    if [ $found -eq 0 ]; then
        echo 'source $ENV_PATH/config.env' >> $SHELL_RC
    fi
}

function export_env()
{
    # 1. 参数数量检查
    if [ $# -ne 2 ]; then
        echo "export_env: only support 2 parameters: <env_name> <env_value>" >&2
        return 1
    fi

    local env_name="$1"
    local env_param="$2"

    # 2. 确保 ENV_CONF 变量已定义
    if [ -z "$ENV_CONF" ]; then
        echo "export_env: ENV_CONF is not set!" >&2
        return 1
    fi

    # 3. 如果文件不存在就创建
    if [ ! -f "$ENV_CONF" ]; then
        echo "export_env: creating config file $ENV_CONF"
        touch "$ENV_CONF"
    fi

    # 4. 精确匹配环境变量名（避免 MY_JAVA_HOME 匹配到 JAVA_HOME）
    local pattern="^export[[:space:]]+${env_name}="

    if grep -qE "$pattern" "$ENV_CONF"; then
        echo "overwrite export env: ${env_name}=${env_param}"

        # 转义斜杠以保证 sed 替换安全
        local env_name_escape=${env_name//\//\\\/}
        local env_param_escape=${env_param//\//\\\/}

        # 检测操作系统类型（macOS 与 Linux 处理 sed 不同）
        case "$(uname -s)" in
            Darwin)
                sed -i '' "s|^export[[:space:]]\+${env_name_escape}=.*$|export ${env_name_escape}=${env_param_escape}|" "$ENV_CONF"
                ;;
            *)
                sed -i "s|^export[[:space:]]\+${env_name_escape}=.*$|export ${env_name_escape}=${env_param_escape}|" "$ENV_CONF"
                ;;
        esac
    else
        echo "export env: ${env_name}=${env_param}"
        echo "export ${env_name}=${env_param}" >> "$ENV_CONF"
    fi
}

function complete_env_path()
{
    if [ $# -ne 1 ]; then
        echo "Usage: complete_env_path <path>"
        return 1
    fi

    local envpath="$1"

    if [ -z "${ENV_PATH_CONF}" ]; then
        echo "Error: ENV_PATH_CONF is not set or does not exist"
        return 1
    fi

    if [ ! -f "${ENV_PATH_CONF}" ]; then
        echo "complete_env_path: creating path config file $ENV_PATH_CONF"
        touch "$ENV_PATH_CONF"
    fi

    # 检查配置文件中是否已经有这个路径
    if grep -Fq "${envpath}" "${ENV_PATH_CONF}"; then
        echo "env path: ${envpath} already exists in ${ENV_PATH_CONF}"
        return 0
    fi

    {
        echo ""
        echo "# Add ${envpath} to PATH if not already in"
        echo "case \":\$PATH:\" in"
        echo "    *:${envpath}:*) ;;"
        echo "    *) export PATH=\"${envpath}:\$PATH\" ;;"
        echo "esac"
    } >> "${ENV_PATH_CONF}"

    echo "Added ${envpath} to ${ENV_PATH_CONF}"
}

env_variable
reach_github
complete_env_path ${ENV_PATH}/bin
setup_bash_env
