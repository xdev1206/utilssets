#!/bin/bash

if [ $# -ne 2 ]; then
    echo "need 2 parameters(platform and project). example: build_scp.sh mt6835 op_l419"
    tree -L 2 project/RV55_A
    tree -L 2 project/RV33_A
    exit 1
fi

platform=$1
project=$2

pushd ../../../../../
source build/envsetup.sh && export OUT_DIR=out_odm && lunch odm_${project}-stable-userdebug
popd

scp_out="tinysys_out"
zip_file="scp_intermediate.zip"

rm -r ${scp_out} ${zip_file} buildscp.log 2>&1

processor_and_platform=$(find project -maxdepth 3 -type d -name ${platform} -printf '%P\n')

processor=$(echo "${processor_and_platform}" | cut -d"/" -f1)
platform=$(echo "${processor_and_platform}" | cut -d"/" -f2)
echo "processor_and_platform: ${processor_and_platform}, processor: ${processor}, platform: ${platform}"

# ex: PROJECT=op_l419 TARGET_BOARD_PLATFORM=mt6835 BUILD_TYPE=debug make -j1
PROJECT=${project} TARGET_BOARD_PLATFORM=${platform} BUILD_TYPE=release make -j2 2>&1 | tee buildscp.log

if [ $? -ne 0 ]; then
    printf "%s\n" "code compling error!"
    exit 1
fi


if test -e ${scp_out}/scp.img; then
    map_file="${scp_out}/${processor}/scp/tinysys-scp-${processor}.map"
    ini_file="project/${processor}/${platform}/platform/Setting.ini"
    memory_tools="../common/tools/memoryReport.py"

    ls -l ${map_file}
    ls -l ${ini_file}
    ls -l ${memory_tools}

    zip -D ${zip_file} ${map_file} ${ini_file} ${memory_tools}

    md5sum tinysys_out/scp.img

    pushd ../../../../../

    echo "origin scp image md5"
    md5sum out_odm/target/product/${project}/scp.img
    md5sum out_odm/target/product/${project}/scp-verified.img

    echo "delete old scp images"
    rm out_odm/target/product/${project}/scp.img
    rm out_odm/target/product/${project}/scp-verified.img
    rm out_odm/target/product/${project}/resign/cert/scp/tinysys-scp-RV55_A/cert2/intermediate/tmp_bin/scp-verified.img
    rm out_odm/target/product/${project}/resign/cert/scp/tinysys-scp-RV55_A_dram/cert2/intermediate/tmp_bin/scp-verified.img
    rm out_odm/target/product/${project}/resign/bin/scp-verified.img
    rm out_odm/target/product/${project}/resign/bin/multi_tmp/scp.img
    rm out_odm/target/product/${project}/obj/TINYSYS_OBJ/tinysys-scp_intermediates/scp.img
    rm out_odm/target/product/${project}/obj/PACKAGING/odm_target_files_intermediates/odm_x6879_h785-odm_target_files/RADIO/scp.img
    rm out_odm/target/product/${project}/obj/PACKAGING/mtk_signed_image_intermediates/scp.img

    echo "copy scp image"
    cp vendor/mediatek/proprietary/tinysys/scp/${scp_out}/scp.img out_odm/target/product/${project}/

    echo "signing image...."
    #./vendor/mediatek/proprietary/scripts/sign-image/sign_image.sh --images scp.img > sign.log 2>&1

    AVB_ENABLE=true
    sign_sbc_key_type=release
    sign_sbc_key_version=1
    sign_sbc_key_size=2048

    export PRODUCT_OUT=out_odm/target/product/${project}
    TRAN_IMG_PUBK_PATH=vendor/google/security/keys/sbc/${sign_sbc_key_type}/v${sign_sbc_key_version}/rsa${sign_sbc_key_size}/img_pubk.pem

    PYTHONDONTWRITEBYTECODE=True BOARD_AVB_ENABLE=${AVB_ENABLE} \
    vendor/mediatek/proprietary/scripts/sign-image_v2/sign_flow.py \
        -target scp.img \
        -env_cfg vendor/mediatek/proprietary/scripts/sign-image_v2/env.cfg \
        --cert2_pub_key_path ${TRAN_IMG_PUBK_PATH} ${platform} ${project} \
        --socid 0
        ${SECURITY_PLATFORM_DIR} ${SECURITY_PROJECT_NAME}

    md5sum out_odm/target/product/${project}/scp.img
    md5sum out_odm/target/product/${project}/scp-verified.img

    cp out_odm/target/product/${project}/scp-verified.img ~/scp.img
    popd
else
    echo " ${scp_out}/scp.img does't exist, exit..."
fi
