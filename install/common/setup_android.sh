#!/usr/bin/env bash

set -euo pipefail

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && /bin/pwd)"
source "${SCRIPT_PATH}/env.sh"

if [ "${NETWORK}x" == "0x" ]; then
    printf "%s\n" "no network connection, exit..."
    exit 0
fi

ANDROID_SDK_DIR="${UTILSSETS_ROOT}/tools/android/sdk"
NDK_VERSION=29.0.14206865
CMDLINE_TOOLS_VERSION=15859902
ANDROID_STUDIO_INSTALL_PAGE="https://developer.android.com/studio/install"

function get_cmdline_tools_platform() {
    if [ "x${OS_TYPE}" = "xDarwin" ]; then
        if [ "$(uname -m)" = "arm64" ]; then
            printf "%s\n" "mac_arm64"
        else
            printf "%s\n" "mac_x86_64"
        fi
    else
        printf "%s\n" "linux"
    fi
}

function build_cmdline_tools_url() {
    local platform="$1"
    local version="$2"

    printf "%s\n" "https://dl.google.com/android/repository/commandlinetools-${platform}-${version}_latest.zip"
}

function resolve_cmdline_tools_url() {
    local platform latest_url
    platform=$(get_cmdline_tools_platform)

    latest_url=$(curl -fsSL "${ANDROID_STUDIO_INSTALL_PAGE}" \
        | grep -oE "https://dl.google.com/android/repository/commandlinetools-${platform}-[0-9]+_latest\\.zip" \
        | head -n1 || true)

    if [ -n "${latest_url}" ]; then
        printf "%s\n" "${latest_url}"
        return 0
    fi

    printf "%s\n" "$(build_cmdline_tools_url "${platform}" "${CMDLINE_TOOLS_VERSION}")"
}

CMDLINE_TOOLS_URL="$(resolve_cmdline_tools_url)"

function ensure_unzip() {
    if command -v unzip >/dev/null 2>&1; then
        return 0
    fi

    func_installing_status unzip
}

function get_java_major_version() {
    local version_line major

    version_line=$(java -version 2>&1 | awk -F '"' '/version/ {print $2; exit}')
    major=$(printf "%s\n" "${version_line}" | awk -F. '{if ($1 == 1) print $2; else print $1}')
    printf "%s\n" "${major:-0}"
}

function install_jdk() {
    local java_major_version=0

    if command -v java >/dev/null 2>&1; then
        java_major_version=$(get_java_major_version)
    fi

    if [ "${java_major_version}" -ge 17 ]; then
        printf "%s\n" "Java ${java_major_version} already installed, skipping..."
        return 0
    fi

    if [ "x${OS_TYPE}" == "xDarwin" ]; then
        ${SUDO} ${PKG_MANAGER} ${PKG_INSTALL} openjdk@17
        ${SUDO} ln -sfn /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk
    else
        ${SUDO} ${PKG_MANAGER} ${PKG_UPDATE}
        ${SUDO} ${PKG_MANAGER} ${PKG_INSTALL} openjdk-17-jdk
    fi
}

function setup_cmdline_tools() {
    local zip_file="${CMDLINE_TOOLS_URL##*/}"
    local temp_dir
    local -a download_cmd

    mkdir -p "${ANDROID_SDK_DIR}"
    cd "${ANDROID_SDK_DIR}" || exit 1

    if [ -d "cmdline-tools/latest/bin" ]; then
        printf "%s\n" "cmdline-tools already installed, skipping..."
        return 0
    fi

    if command -v wget >/dev/null 2>&1; then
        download_cmd=(wget -q --show-progress -O "${zip_file}" "${CMDLINE_TOOLS_URL}")
    else
        download_cmd=(curl -fsSL -o "${zip_file}" "${CMDLINE_TOOLS_URL}")
    fi

    if [ ! -f "${zip_file}" ]; then
        printf "%s\n" "Downloading: ${zip_file}"
        "${download_cmd[@]}" || {
            printf "%s\n" "Failed to download cmdline-tools"
            exit 1
        }
    fi

    temp_dir=$(mktemp -d)
    unzip -q -o "${zip_file}" -d "${temp_dir}"
    mkdir -p cmdline-tools/latest
    mv "${temp_dir}/cmdline-tools/"* cmdline-tools/latest/
    rm -rf "${temp_dir}"
}

function accept_sdk_licenses() {
    local sdkmanager="./cmdline-tools/latest/bin/sdkmanager"

    printf "%s\n" "Accepting Android SDK licenses..."
    (
        set +o pipefail
        yes | "${sdkmanager}" --sdk_root=. --licenses >/dev/null
    )
}

function update_sdk_tools() {
    local sdkmanager="./cmdline-tools/latest/bin/sdkmanager"

    printf "%s\n" "Updating Android SDK tools..."
    "${sdkmanager}" --sdk_root=. --update
}

function install_sdk_components() {
    cd "${ANDROID_SDK_DIR}" || exit 1
    local sdkmanager="./cmdline-tools/latest/bin/sdkmanager"

    # Check if key components are already installed
    if [ -d "platform-tools" ] && [ -d "ndk/${NDK_VERSION}" ]; then
        printf "%s\n" "SDK components already installed, skipping..."
        return 0
    fi

    accept_sdk_licenses
    update_sdk_tools

    printf "%s\n" "Installing SDK components..."
    "${sdkmanager}" --sdk_root=. --install \
        "cmake;3.22.1" \
        "build-tools;34.0.0" \
        "platform-tools" \
        "cmdline-tools;latest" \
        "ndk;${NDK_VERSION}" \
        "platforms;android-34"
}

function setup_environment() {
    complete_env_path PATH "${ANDROID_SDK_DIR}/platform-tools"
    complete_env_path PATH "${ANDROID_SDK_DIR}/cmdline-tools/latest/bin"
    complete_env_path PATH "${ANDROID_SDK_DIR}/ndk/${NDK_VERSION}"

    export_env ANDROID_NDK "${ANDROID_SDK_DIR}/ndk/${NDK_VERSION}"
    export_env ANDROID_NDK_HOME "${ANDROID_SDK_DIR}/ndk/${NDK_VERSION}"
    export_env ANDROID_HOME "${ANDROID_SDK_DIR}"
    export_env ANDROID_SDK_ROOT "${ANDROID_SDK_DIR}"
}

ensure_unzip
install_jdk
setup_cmdline_tools
install_sdk_components
setup_environment

printf "%s\n" "Android SDK setup completed successfully!"
