#!/bin/bash

if [ $# -ne 1 ]; then
    echo "need 1 parameters: ${BASH_SOURCE[0]} example.apk"
    exit 1
fi

rm -rf tmp

APK=$1

BUILD_TOOLS_VERSION=34.0.0
APKSIGNER=${ANDROID_SDK}/build-tools/${BUILD_TOOLS_VERSION}/apksigner

# support v2
${APKSIGNER} verify -v ${APK}
${APKSIGNER} verify --print-certs ${APK}
${APKSIGNER} verify --print-certs-pem ${APK}

# only v1/v1+v2, doesn't suport v2 version
keytool -printcert -jarfile ${APK}
jarsigner -verify -verbose -certs ${APK}

unzip ${APK} -d tmp

pushd tmp

certfile=META-INF/CERT.RSA
if [ -e ${certfile} ]; then
    keytool -printcert -file ${certfile}
else
    echo "${certfile} doesn't exist!"
fi

popd
