#!/usr/bin/env bash

get_script_dir() {
    if [ -n "${BASH_VERSION:-}" ]; then
        echo "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    elif [ -n "${ZSH_VERSION:-}" ]; then
        echo "$(cd "$(dirname "${(%):-%x}")" && pwd)"
    else
        echo "$(cd "$(dirname "$0")" && pwd)"
    fi
}

SCRIPT_DIR="$(get_script_dir)"
UTILSSETS_ROOT="${UTILSSETS_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
TOOLS_BIN_DIR="${TOOLS_BIN_DIR:-${UTILSSETS_ROOT}/tools/bin}"
CONFIG_DIR="${CONFIG_DIR:-${UTILSSETS_ROOT}/config}"
CONFIG_PATH="${CONFIG_PATH:-${CONFIG_DIR}/shell}"
SHELL_CONF="${SHELL_CONF:-${CONFIG_PATH}/env.conf}"
PATH_CONF="${PATH_CONF:-${CONFIG_PATH}/path.conf}"
TOOLS_DIR="${TOOLS_BIN_DIR}"
LOCAL_BAZELISK="${TOOLS_DIR}/bazelisk"
LOCAL_BAZEL="${TOOLS_DIR}/bazel"
DEFAULT_BAZELISK_BASE_URL="https://github.com/bazelbuild/bazel/releases/download"

detect_shell_rc() {
    if [ -n "${SHELL_RC:-}" ]; then
        return 0
    fi

    case "$(uname -s)" in
        Darwin)
            if [ "${SHELL:-}" = "/bin/bash" ]; then
                SHELL_RC="${HOME}/.bash_profile"
            else
                SHELL_RC="${HOME}/.zshrc"
            fi
            ;;
        *)
            SHELL_RC="${HOME}/.bashrc"
            ;;
    esac
}

ensure_utilssets_layout() {
    mkdir -p "${TOOLS_BIN_DIR}" "${CONFIG_PATH}"
    [ -f "${SHELL_CONF}" ] || touch "${SHELL_CONF}"
    [ -f "${PATH_CONF}" ] || touch "${PATH_CONF}"
}

ensure_shell_bootstrap() {
    detect_shell_rc
    [ -n "${SHELL_RC:-}" ] || return 0

    if ! grep -Fq "UTILSSETS_ROOT=" "${SHELL_RC}" 2>/dev/null; then
        echo "export UTILSSETS_ROOT=${UTILSSETS_ROOT}" >> "${SHELL_RC}"
    fi

    if ! grep -Fq "config/shell/config.env" "${SHELL_RC}" 2>/dev/null; then
        cat >> "${SHELL_RC}" <<'EOF'
source "${UTILSSETS_ROOT}/config/shell/config.env"
EOF
    fi

    if [ ! -f "${CONFIG_PATH}/config.env" ]; then
        cat > "${CONFIG_PATH}/config.env" <<'EOF'
# Detect UTILSSETS_ROOT if not set
if [ -z "${UTILSSETS_ROOT}" ]; then
    UTILSSETS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

CONFIG_PATH="${UTILSSETS_ROOT}/config/shell"

for config in "${CONFIG_PATH}"/*.conf; do
    [ -f "$config" ] && source "$config"
done
EOF
    fi
}

append_env_path_once() {
    local envname="$1"
    local envpath="$2"
    local rendered="${envpath}"
    local relative_path="${envpath#${UTILSSETS_ROOT}/}"

    if [ "${relative_path}" != "${envpath}" ]; then
        rendered="\${UTILSSETS_ROOT}/${relative_path}"
    fi

    if grep -Fq "${rendered}" "${PATH_CONF}" 2>/dev/null; then
        return 0
    fi

    cat >> "${PATH_CONF}" <<EOF

case ":\$${envname}:" in
    *:${rendered}:*) ;;
    *) export ${envname}="${rendered}:\$${envname}" ;;
esac
EOF
}

print_help() {
    cat <<'EOF'
Usage:
  setup_bazel.sh
  source setup_bazel.sh
  setup_bazel.sh [<config-dir>|<path-to-.bazelrc>]
  source setup_bazel.sh [<config-dir>|<path-to-.bazelrc>]

Examples:
  setup_bazel.sh
  source setup_bazel.sh
  source setup_bazel.sh /path/to/workspace
  source setup_bazel.sh /path/to/workspace/.bazelrc
  bazel ${EXTRA_STARTUP} version

Behavior:
  - Reads Bazel config from the specified directory/file, or from the current directory and its parents.
  - If .bazelversion is found, exports USE_BAZEL_VERSION.
  - If .bazeliskrc defines BAZELISK_BASE_URL, exports it.
  - Checks whether the current bazel command is usable.
  - If bazel is missing or unusable, installs a shared bazelisk under ${UTILSSETS_ROOT}/tools/bin.
  - Ensures ${UTILSSETS_ROOT}/tools/bin is on PATH via utilssets shell config.
  - Exports EXTRA_STARTUP for proxy-aware Bazel downloads.
EOF
}

parse_proxy() {
    local url="${1:-}"
    [ -z "${url}" ] && return 1
    local stripped="${url#*://}"
    stripped="${stripped%%/*}"
    stripped="${stripped##*@}"
    local host="${stripped%%:*}"
    local port="${stripped##*:}"
    [ -n "${host}" ] && [ -n "${port}" ] && [ "${host}" != "${port}" ] || return 1
    printf '%s %s\n' "${host}" "${port}"
}

detect_platform_suffix() {
    local os arch
    os="$(uname -s)"
    arch="$(uname -m)"

    case "${os}" in
        Linux) os="linux" ;;
        Darwin) os="darwin" ;;
        *)
            echo "Unsupported OS for automatic bazelisk setup: ${os}" >&2
            return 1
            ;;
    esac

    case "${arch}" in
        x86_64|amd64) arch="amd64" ;;
        arm64|aarch64) arch="arm64" ;;
        *)
            echo "Unsupported architecture for automatic bazelisk setup: ${arch}" >&2
            return 1
            ;;
    esac

    printf '%s-%s\n' "${os}" "${arch}"
}

download_local_bazelisk() {
    mkdir -p "${TOOLS_DIR}"
    local suffix url tmp
    suffix="$(detect_platform_suffix)" || return 1
    url="https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-${suffix}"
    tmp="${LOCAL_BAZELISK}.tmp"

    if [ "${NETWORK:-1}" = "0" ]; then
        echo "No network connection, cannot download bazelisk: ${url}" >&2
        return 1
    fi

    echo "Downloading bazelisk to ${LOCAL_BAZELISK}" >&2
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "${url}" -o "${tmp}"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "${tmp}" "${url}"
    else
        echo "Neither curl nor wget is available; cannot download bazelisk." >&2
        return 1
    fi

    chmod +x "${tmp}"
    mv "${tmp}" "${LOCAL_BAZELISK}"
    ln -sf "bazelisk" "${LOCAL_BAZEL}"
}

read_config_value() {
    local file="$1"
    local key="$2"
    [ -f "${file}" ] || return 1

    while IFS= read -r line; do
        line="${line#"${line%%[![:space:]]*}"}"
        [ -z "${line}" ] && continue
        [ "${line#\#}" != "${line}" ] && continue
        if [[ "${line}" == "${key}="* ]]; then
            printf '%s\n' "${line#*=}"
            return 0
        fi
    done < "${file}"

    return 1
}

find_nearest_config_dir() {
    local dir
    dir="$(pwd)"
    while :; do
        if [ -f "${dir}/.bazelversion" ] || [ -f "${dir}/.bazeliskrc" ] || \
           [ -f "${dir}/WORKSPACE" ] || [ -f "${dir}/WORKSPACE.bazel" ] || \
           [ -f "${dir}/MODULE.bazel" ]; then
            printf '%s\n' "${dir}"
            return 0
        fi
        [ "${dir}" = "/" ] && break
        dir="$(dirname "${dir}")"
    done
    return 1
}

resolve_config_dir() {
    local input="${1:-}"

    if [ -z "${input}" ]; then
        find_nearest_config_dir || pwd
        return 0
    fi

    if [ -d "${input}" ]; then
        (
            cd "${input}" >/dev/null 2>&1 && pwd
        )
        return $?
    fi

    if [ -f "${input}" ]; then
        (
            cd "$(dirname "${input}")" >/dev/null 2>&1 && pwd
        )
        return $?
    fi

    echo "Config path does not exist: ${input}" >&2
    return 1
}

validate_bazel_cmd() {
    local cmd="$1"
    [ -n "${cmd}" ] && [ -x "${cmd}" ] || return 1
    "${cmd}" --version >/dev/null 2>&1
}

select_existing_bazel_cmd() {
    local cmd

    if command -v bazel >/dev/null 2>&1; then
        cmd="$(command -v bazel)"
        if validate_bazel_cmd "${cmd}"; then
            printf '%s\n' "${cmd}"
            return 0
        fi
        echo "Found bazel at ${cmd}, but it is not usable. Falling back." >&2
    fi

    if command -v bazelisk >/dev/null 2>&1; then
        cmd="$(command -v bazelisk)"
        if validate_bazel_cmd "${cmd}"; then
            printf '%s\n' "${cmd}"
            return 0
        fi
        echo "Found bazelisk at ${cmd}, but it is not usable. Falling back." >&2
    fi

    return 1
}

ensure_bazel_cmd() {
    local existing_cmd
    if existing_cmd="$(select_existing_bazel_cmd)"; then
        BAZEL_CMD="${existing_cmd}"
        return 0
    fi

    if [ ! -x "${LOCAL_BAZELISK}" ]; then
        download_local_bazelisk || return 1
    fi

    if ! validate_bazel_cmd "${LOCAL_BAZELISK}"; then
        echo "Local bazelisk is present but not usable: ${LOCAL_BAZELISK}" >&2
        return 1
    fi

    BAZEL_CMD="${LOCAL_BAZEL}"
}

_setup_bazel_is_sourced=0
if [ "${BASH_SOURCE[0]}" != "$0" ]; then
    _setup_bazel_is_sourced=1
fi

main() {
    local config_input=""
    local bazelisk_base_url=""
    local host=""
    local port=""
    local arch=""

    if [ "$#" -gt 1 ]; then
        echo "Too many arguments." >&2
        print_help >&2
        return 1
    fi

    if [ "$#" -eq 1 ]; then
        case "$1" in
            --help|-h)
                print_help
                return 0
                ;;
            *)
                config_input="$1"
                ;;
        esac
    fi

    ensure_utilssets_layout
    ensure_shell_bootstrap

    CONFIG_DIR="$(resolve_config_dir "${config_input}")" || return 1

    if [ -f "${CONFIG_DIR}/.bazelversion" ]; then
        USE_BAZEL_VERSION="$(tr -d '[:space:]' < "${CONFIG_DIR}/.bazelversion")"
        export USE_BAZEL_VERSION
    fi

    if [ -f "${CONFIG_DIR}/.bazeliskrc" ]; then
        bazelisk_base_url="$(read_config_value "${CONFIG_DIR}/.bazeliskrc" "BAZELISK_BASE_URL" || true)"
        if [ -n "${bazelisk_base_url}" ]; then
            export BAZELISK_BASE_URL="${bazelisk_base_url}"
        fi
    fi

    export BAZELISK_BASE_URL="${BAZELISK_BASE_URL:-${DEFAULT_BAZELISK_BASE_URL}}"

    EXTRA_STARTUP_ARGS=()
    if [ -n "${https_proxy:-}" ]; then
        if read -r host port < <(parse_proxy "${https_proxy}"); then
            EXTRA_STARTUP_ARGS+=("--host_jvm_args=-Dhttps.proxyHost=${host}")
            EXTRA_STARTUP_ARGS+=("--host_jvm_args=-Dhttps.proxyPort=${port}")
        fi
    fi
    if [ -n "${http_proxy:-}" ]; then
        if read -r host port < <(parse_proxy "${http_proxy}"); then
            EXTRA_STARTUP_ARGS+=("--host_jvm_args=-Dhttp.proxyHost=${host}")
            EXTRA_STARTUP_ARGS+=("--host_jvm_args=-Dhttp.proxyPort=${port}")
        fi
    fi

    arch="$(uname -m || echo unknown)"
    if [ "${DISABLE_SVE_FOR_BAZEL:-}" = "1" ] && [ "${arch}" = "aarch64" -o "${arch}" = "arm64" ]; then
        EXTRA_STARTUP_ARGS+=("--host_jvm_args=-XX:UseSVE=0")
    fi

    ensure_bazel_cmd || return 1

    mkdir -p "${TOOLS_DIR}"
    if [ "${BAZEL_CMD}" != "${LOCAL_BAZEL}" ] && [ "${BAZEL_CMD}" != "${LOCAL_BAZELISK}" ]; then
        ln -sf "${BAZEL_CMD}" "${LOCAL_BAZELISK}" || true
        ln -sf "${LOCAL_BAZELISK}" "${LOCAL_BAZEL}" || true
    fi

    append_env_path_once PATH "${TOOLS_DIR}"

    export PATH="${TOOLS_DIR}:${PATH}"
    export EXTRA_STARTUP="${EXTRA_STARTUP_ARGS[*]:-}"

    if [ "${_setup_bazel_is_sourced}" = "1" ]; then
        echo "Bazel environment ready." >&2
        echo "  config dir: ${CONFIG_DIR}" >&2
        echo "  bazel: ${BAZEL_CMD}" >&2
        if [ -n "${USE_BAZEL_VERSION:-}" ]; then
            echo "  USE_BAZEL_VERSION: ${USE_BAZEL_VERSION}" >&2
        fi
        if [ -n "${EXTRA_STARTUP:-}" ]; then
            echo "  extra startup flags: ${EXTRA_STARTUP}" >&2
        fi
        return 0
    fi

    cat <<EOF
Bazel environment configured.
  config dir: ${CONFIG_DIR}
  bazel: ${BAZEL_CMD}
  USE_BAZEL_VERSION: ${USE_BAZEL_VERSION:-<unset>}
  BAZELISK_BASE_URL: ${BAZELISK_BASE_URL}
  EXTRA_STARTUP: ${EXTRA_STARTUP:-}

To apply the environment in the current shell:
  source ${UTILSSETS_ROOT}/install/common/setup_bazel.sh ${config_input:-}
EOF
}

if [ "${_setup_bazel_is_sourced}" = "1" ]; then
    main "$@"
    return $?
fi

main "$@"
