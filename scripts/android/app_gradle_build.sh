#!/bin/bash

rm -rf .cxx
find -iname build -exec rm -r {} \;

bash ./gradlew clean
bash ./gradlew assembleRelease
#zip -r build/symbolLibs.zip build/intermediates/merged_jni_libs build/intermediates/merged_native_libs
