#!/bin/bash

set -e

SCRIPT_PATH=$(cd `dirname $BASH_SOURCE[0]` && /bin/pwd)
source $SCRIPT_PATH/env.sh

if [ "${NETWORK}x" == "0x" ]; then
    printf "%s\n" "no network connection, exit..."
    exit 0
fi

ANDROID_SDK_DIR=${UTILSSETS_ROOT}/tools/android/sdk
NDK_VERSION=29.0.14206865

toolsUrlContents=$(curl https://developer.android.com/studio)
if [ "x${OS_TYPE}" == "xDarwin" ]; then
    CMDLINE_TOOLS_URL=$(echo "${toolsUrlContents}" | grep -o "https:\/\/dl.google.com\/android\/repository\/commandlinetools\-mac\-[0-9]*_latest\.zip")
else
    CMDLINE_TOOLS_URL=$(echo "${toolsUrlContents}" | grep -o "https:\/\/dl.google.com\/android\/repository\/commandlinetools\-linux\-[0-9]*_latest\.zip")
fi

function install_jdk() {
    if java -version &> /dev/null; then
        printf "%s\n" "Java already installed, skipping..."
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

    mkdir -p "${ANDROID_SDK_DIR}"
    cd "${ANDROID_SDK_DIR}"

    if [ -d "cmdline-tools/latest/bin" ]; then
        printf "%s\n" "cmdline-tools already installed, skipping..."
        return 0
    fi

    if [ ! -f "${zip_file}" ]; then
        printf "%s\n" "Downloading: ${zip_file}"
        wget -q --show-progress "${CMDLINE_TOOLS_URL}" || {
            printf "%s\n" "Failed to download cmdline-tools"
            exit 1
        }
    fi

    unzip -q -o "${zip_file}"
    mkdir -p cmdline-tools/latest
    mv cmdline-tools/bin cmdline-tools/lib cmdline-tools/latest/ 2>/dev/null || true
}

function install_sdk_components() {
    cd "${ANDROID_SDK_DIR}"
    local sdkmanager="./cmdline-tools/latest/bin/sdkmanager"

    # Check if key components are already installed
    if [ -d "platform-tools" ] && [ -d "ndk/${NDK_VERSION}" ]; then
        printf "%s\n" "SDK components already installed, skipping..."
        return 0
    fi

    printf "%s\n" "Installing SDK components..."
    ${sdkmanager} --sdk_root=. --install \
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

install_jdk
setup_cmdline_tools
install_sdk_components
setup_environment

printf "%s\n" "Android SDK setup completed successfully!"
