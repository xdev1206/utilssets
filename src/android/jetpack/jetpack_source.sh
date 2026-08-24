#!/bin/bash

repo init -u https://android.googlesource.com/platform/manifest -b androidx-main --partial-clone --clone-filter=blob:limit=10M
repo sync -j8 -c
