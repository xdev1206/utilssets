#!/bin/bash

if [ $# -ne 1 ]; then
    echo "need 1 parameters: ${BASH_SOURCE[0]} example.apk"
    exit 1
fi

rm -rf tmp

APK=$1

unzip ${APK} -d tmp

pushd tmp

certfile=META-INF/CERT.RSA
if [ -e ${certfile} ]; then
    keytool -printcert -file ${certfile}
else
    echo "${certfile} doesn't exist!"
fi

popd
