#!/bin/sh

# 检查参数
if [ $# -ne 1 ]; then
    echo "Usage: $0 <script_to_run>"
    exit 1
fi

TARGET_SCRIPT="$1"

# 检查脚本是否存在
if [ ! -f "$TARGET_SCRIPT" ]; then
    echo "Error: script not found: $TARGET_SCRIPT"
    exit 1
fi

SH_REAL=$(readlink /bin/sh)

case "$SH_REAL" in
    *dash*)
        echo "sh -> dash"
        echo "Using bash to run $TARGET_SCRIPT"
        exec bash "$TARGET_SCRIPT"
        ;;
    *)
        echo "sh -> $SH_REAL"
        echo "Detected shell: $SH_REAL"
        echo "Using detected shell to run $TARGET_SCRIPT"
        exec "$SH_REAL" "$TARGET_SCRIPT"
        ;;
esac
