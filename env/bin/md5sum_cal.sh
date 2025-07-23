#!/bin/bash

# MD5计算脚本
# 用法: ./md5_calculator.sh <文件或文件夹路径>

# 检查参数数量
if [ $# -ne 1 ]; then
    echo "用法: $0 <文件或文件夹路径>"
    echo "示例: $0 /path/to/file.txt"
    echo "示例: $0 /path/to/directory"
    exit 1
fi

# 获取输入参数
INPUT_PATH="$1"
OUTPUT_FILE="md5_sum.txt"

# 检查输入路径是否存在
if [ ! -e "$INPUT_PATH" ]; then
    echo "错误: 路径 '$INPUT_PATH' 不存在"
    exit 1
fi

# 清空或创建输出文件
> "$OUTPUT_FILE"

# 函数：计算单个文件的MD5值
calculate_file_md5() {
    local file_path="$1"
    if [ -f "$file_path" ]; then
        # 计算MD5值并格式化输出
        md5_value=$(md5sum "$file_path" 2>/dev/null | cut -d' ' -f1)
        if [ $? -eq 0 ]; then
            echo "$md5_value $file_path" >> "$OUTPUT_FILE"
            echo "已处理: $file_path"
        else
            echo "警告: 无法计算 '$file_path' 的MD5值"
        fi
    fi
}

# 主处理逻辑
if [ -f "$INPUT_PATH" ]; then
    # 如果是文件，直接计算MD5
    echo "正在计算文件的MD5值..."
    calculate_file_md5 "$INPUT_PATH"

elif [ -d "$INPUT_PATH" ]; then
    # 如果是文件夹，递归处理所有文件
    echo "正在计算文件夹及其子文件夹中所有文件的MD5值..."
    
    # 使用find命令递归查找所有文件
    find "$INPUT_PATH" -type f | while read -r file; do
        calculate_file_md5 "$file"
    done
else
    echo "错误: '$INPUT_PATH' 既不是文件也不是文件夹"
    exit 1
fi

# 显示结果统计
file_count=$(wc -l < "$OUTPUT_FILE" 2>/dev/null || echo "0")
echo ""
echo "处理完成！"
echo "共处理了 $file_count 个文件"
echo "MD5值已保存到: $OUTPUT_FILE"
echo ""
echo "结果文件内容预览:"
echo "===================="
head -15 "$OUTPUT_FILE" 2>/dev/null || echo "无内容"
if [ "$file_count" -gt 5 ]; then
    echo "... (还有 $((file_count - 5)) 行)"
fi
