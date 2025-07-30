#!/bin/bash

if [ $# -ne 1 ]; then
    echo "need 1 parameters: ${BASH_SOURCE[0]} example.apk"
    exit 1
fi

rm -rf tmp

APK=$1

BUILD_TOOLS_VERSION=34.0.0
ANDROID_SDK="/root/workspace/utilssets/env/android/sdk"
APKSIGNER="${ANDROID_SDK}/build-tools/${BUILD_TOOLS_VERSION}/apksigner"

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

unzip -q ${APK} -d tmp

pushd tmp

certfile=META-INF/CERT.RSA
if [ -e ${certfile} ]; then
    keytool -printcert -file ${certfile}
else
    echo "${certfile} doesn't exist!"
fi

popd
