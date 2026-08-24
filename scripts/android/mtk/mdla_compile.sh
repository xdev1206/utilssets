#!/bin/bash

usage_error() {
    echo
    echo "Usage:"
    echo "$0 MODEL_PATH PLATFORM NEURON_SDK_PATH PROM(GEN or PROM) NCL_PATH(for mt6897)"
    echo
    echo "NOTE: A example of NEURON_SDK_PATH is as below"
    echo "  neuropilot-sdk-basic-8.0.0-build20240306/neuron_sdk"
    echo
    exit 1
}

if [ $# -lt 4 ]; then
    usage_error
fi

MODEL_PATH="$1"
PLATFORM="$2"
NEURON_SDK_DIR="$3"
TYPE="$4"

if [ ${PLATFORM} == "MT6897" ]; then
    if [ $# -ne 5 ]; then
        usage_error
        exit 1
    fi
    NCL_PATH=$5
fi

if [ ${PLATFORM} == "MT6897" ]; then
    MDLA_VER="mdla5.0"
    MDLA_NUM="2"
    L1_SIZE_KB="3072"
    NPU_VER="NPU 780"
elif [ ${PLATFORM} == "MT6899" ]; then
    MDLA_VER="mdla5.3"
    MDLA_NUM="2"
    L1_SIZE_KB="3072"
    NPU_VER="NPU 870"
elif [ ${PLATFORM} == "MT6989" ]; then
    MDLA_VER="mdla5.1"
    MDLA_NUM="4"
    L1_SIZE_KB="7168"
    NPU_VER="NPU 790"
elif [ ${PLATFORM} == "MT6993" ]; then
    BACKEND="mt6993"
    SUBSYS="npu"
    MDLA_VER="mdla6.0"
    MDLA_NUM="4"
    L1_SIZE_KB="7168"
    NPU_VER="NPU 990"
else
    echo "error"
fi

export LD_LIBRARY_PATH="${NEURON_SDK_DIR}/host/lib:$LD_LIBRARY_PATH"
export NCC_TFLITE="${NEURON_SDK_DIR}/host/bin/ncc-tflite"
if [ ! -f ${NCC_TFLITE} ]; then
    echo "Can't find ncc-tflite in ${NEURON_SDK_DIR}/host/bin"
    exit 1
fi

if [ "$TYPE" == "PROM" ]; then
    if [ ${PLATFORM} == "MT6899" ]; then
        ${NCC_TFLITE} \
            --arch=${MDLA_VER} \
            --l1-size-kb=${L1_SIZE_KB} \
            --num-mdla=${MDLA_NUM} \
            --opt=3 \
            --opt-footprint \
            --opt-aggressive \
            --stable-linearize \
            --gno=LTS,Inception \
            --gno-exp \
            --gno-non-4d-tiling \
            --mlo \
            --disable-apusys \
            --fc-to-conv \
            --broadcast-act-wgt \
            --broadcast-flow-distance=63 \
            --mdla-int16-lut \
            --suppress-input \
            --suppress-output \
            --show-memory-summary \
            --split-large-conv-ic=1536 \
            --mdla-conv-exp \
            --intval-color-legacy \
            ${MODEL_PATH} \
            2>&1 | tee compile_${TYPE}_${PLATFORM}.log
    elif [ ${PLATFORM} == "MT6897" ]; then
        ${NCC_TFLITE} \
            --arch=${MDLA_VER} \
            --opt=3 \
            --opt-footprint \
            --opt-aggressive \
            --stable-linearize \
            --gno=LTS \
            --gno-exp \
            --gno-non-4d-tiling \
            --fc-to-conv \
            --broadcast-act-wgt \
            --broadcast-flow-distance=63 \
            --ncl-patch=${NCL_PATH}/llm.ncl \
            --mdla-int16-lut \
            --l1-size-kb=${L1_SIZE_KB} \
            --num-mdla=${MDLA_NUM} \
            --suppress-input \
            --suppress-output \
            --show-memory-summary \
            --split-large-conv-ic=1536 \
            ${MODEL_PATH} \
            2>&1 | tee compile_${TYPE}_${PLATFORM}.log
    elif [ ${PLATFORM} == "MT6993" ]; then
       ${NCC_TFLITE} \
           --platform-config=${BACKEND} \
           --subsys=${SUBSYS} \
           --l1-size-kb=${L1_SIZE_KB} \
           --num-mdla=${MDLA_NUM} \
           --opt=3 \
           --opt-footprint \
           --opt-aggressive \
           --stable-linearize \
           --relax-fp32 \
           --gno=Inception \
           --gno-exp \
           --gno-non-4d-tiling \
           --mlo \
           --dla-opt=0 \
           --opt-static-sharing \
           --fc-to-conv \
           --broadcast-act-wgt \
           --broadcast-flow-distance=63 \
           --split-large-conv-ic=10 \
           --split-16a4w-conv-ic-xy=8000 \
           --suppress-input \
           --suppress-output \
           --show-memory-summary \
           --mdla-conv-exp \
           --intval-color-legacy \
           ${MODEL_PATH} \
           2>&1 | tee compile_${TYPE}_${PLATFORM}.log
    fi
else
   if [ ${PLATFORM} == "MT6899" ]; then
       ${NCC_TFLITE} \
           --arch=${MDLA_VER} \
           --l1-size-kb=${L1_SIZE_KB} \
           --num-mdla=${MDLA_NUM} \
           --opt=3 \
           --opt-footprint \
           --opt-aggressive \
           --stable-linearize \
           --gno=LTS,Inception \
           --gno-exp \
           --gno-non-4d-tiling \
           --mlo \
           --disable-apusys \
           --fc-to-conv \
           --split-16a4w-conv-oc \
           --mdla-int16-lut \
           --suppress-input \
           --suppress-output \
           --show-memory-summary \
           --mdla-conv-exp \
           --intval-color-legacy \
           ${MODEL_PATH} \
           2>&1 | tee compile_${TYPE}_${PLATFORM}.log
   elif [ ${PLATFORM} == "MT6897" ]; then
       ${NCC_TFLITE} \
           --arch=${MDLA_VER} \
           --opt=3 \
           --opt-footprint \
           --opt-aggressive \
           --stable-linearize \
           --gno=LTS \
           --gno-exp \
           --gno-non-4d-tiling \
           --fc-to-conv \
           --split-16a4w-conv-oc \
           --ncl-patch=${NCL_PATH}/llm.ncl \
           --mdla-int16-lut \
           --l1-size-kb=${L1_SIZE_KB} \
           --num-mdla=${MDLA_NUM} \
           --suppress-input \
           --suppress-output \
           --show-memory-summary \
           ${MODEL_PATH} \
           2>&1 | tee compile_${TYPE}_${PLATFORM}.log
    elif [ ${PLATFORM} == "MT6993" ]; then
        ${NCC_TFLITE} \
            --platform-config=${BACKEND} \
            --subsys=${SUBSYS} \
            --l1-size-kb=${L1_SIZE_KB} \
            --num-mdla=${NUM_MDLA} \
            --opt=3 \
            --opt-footprint \
            --opt-aggressive \
            --stable-linearize \
            --relax-fp32 \
            --gno=Inception \
            --gno-exp \
            --gno-non-4d-tiling \
            --mlo \
            --dla-opt=0 \
            --opt-static-sharing \
            --fc-to-conv \
            --broadcast-act-wgt \
            --broadcast-flow-distance=63 \
            --split-large-conv-ic=99999 \
            --split-16a4w-conv-ic-xy=8000 \
            --suppress-input \
            --suppress-output \
            --show-memory-summary \
            --mdla-conv-exp \
            --intval-color-legacy \
            ${MODEL_PATH} \
            2>&1 | tee compile_${TYPE}_${PLATFORM}.log
    fi
fi