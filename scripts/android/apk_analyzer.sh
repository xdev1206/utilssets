#!/bin/bash

if [ $# -ne 1 ]; then
    echo "need 1 parameters: ${BASH_SOURCE[0]} example.apk"
    exit 1
fi

rm -rf tmp

set -e

APK=$1

SDK_BUILD_TOOLS_VERSION=$(find ${ANDROID_SDK_ROOT}/build-tools -mindepth 1 -maxdepth 1 -type d | head -n 1 | xargs basename)
SDK_CMD_TOOLS=${ANDROID_SDK_ROOT}/cmdline-tools

AAPT2="${ANDROID_SDK_ROOT}/build-tools/${SDK_BUILD_TOOLS_VERSION}/aapt2"
APKSIGNER="${ANDROID_SDK_ROOT}/build-tools/${SDK_BUILD_TOOLS_VERSION}/apksigner"
APKANALYZER="${SDK_CMD_TOOLS}/latest/bin/apkanalyzer"

echo "apk aapt2 dump versionCode versionName"
${AAPT2} dump badging ${APK} | grep -E "(versionCode|versionName)"

echo "apk aapt2 dump targetSdkVersion"
${AAPT2} dump badging ${APK} | grep -i targetSdkVersion

echo "apk apkanalyzer targetSdkVersion"
${APKANALYZER} manifest target-sdk ${APK}

# support v2
echo "apksigner verify"
${APKSIGNER} verify -v ${APK}
${APKSIGNER} verify --print-certs ${APK}
${APKSIGNER} verify --print-certs-pem ${APK}

# only v1/v1+v2, doesn't suport v2 version
echo "keytool -printcert -jarfile"
keytool -printcert -jarfile ${APK}

echo "jarsigner -verify -certs"
jarsigner -verify -certs ${APK}

unzip -qo ${APK} -d tmp

pushd tmp

certfile=META-INF/CERT.RSA
if [ -e ${certfile} ]; then
    keytool -printcert -file ${certfile}
else
    echo "${certfile} doesn't exist!"
fi

popd
