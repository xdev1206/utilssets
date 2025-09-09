#!/usr/bin/env bash
# 简洁的bash/zsh兼容版本

# 获取脚本目录的兼容函数
function get_script_dir() {
    if [ -n "$BASH_VERSION" ]; then
        echo "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    elif [ -n "$ZSH_VERSION" ]; then
        echo "$(cd "$(dirname "${(%):-%x}")" && pwd)"
    else
        echo "$(cd "$(dirname "$0")" && pwd)"
    fi
}

# 获取脚本目录并切换
SCRIPT_DIR=$(get_script_dir)
echo "脚本目录: $SCRIPT_DIR"

# 使用pushd切换目录
pushd "$SCRIPT_DIR" > /dev/null || exit 1

# 在这里添加你的脚本逻辑
echo "当前工作目录: $(pwd)"
