#!/bin/bash

usage_error() {
    echo
    echo "Usage:"
    echo "$0  NEURON_SDK_PATH  SHARED_WEIGHT_NAME  DLA_PATH_1  DLA_PATH_2"
    echo
    echo "NOTE: A example of NEURON_SDK_PATH is as below"
    echo "    /path/to/neuropilot-sdk-basic-7.0.3-build20231129/neuron_sdk"
    echo
    exit 1
}

if [ $# -lt 4 ]; then
    usage_error
fi

NEURON_SDK_DIR="$1"
SHARED_WEIGHT_FILE="$2"

export LD_LIBRARY_PATH="${NEURON_SDK_DIR}/host/lib:$LD_LIBRARY_PATH"
export EXTRACT_SHARED="${NEURON_SDK_DIR}/host/bin/extract-shared"

if [ ! -f ${EXTRACT_SHARED} ]; then
    echo "Can't find extract-shared in ${NEURON_SDK_DIR}/host/bin"
    exit 1
fi

IN_DLA=""
OUT_DLA=""

shift
shift

for dlafile in "$@"; do
    NEW_FILE=""
    if [[ ${dlafile} == *.dla ]]; then
        NEW_FILE="${dlafile%.dla}_shared.dla"
    else
        echo "The file extension of $dlafile should be .dla"
    fi
    IN_DLA+="-i ${dlafile} "
    OUT_DLA+="-o ${NEW_FILE} "
done


${EXTRACT_SHARED}  $IN_DLA $OUT_DLA -s ./${SHARED_WEIGHT_FILE} 2>&1 | tee extract.log
