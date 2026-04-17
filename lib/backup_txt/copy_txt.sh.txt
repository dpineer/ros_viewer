#!/bin/bash

# ==============================================================================
# 脚本名称: copy_to_txt.sh
# 功能描述: 将脚本所在目录下的所有文件复制一份，添加 .txt 后缀，不保持目录结构保存到目标文件夹
# 适用环境: Linux (Debian/Ubuntu 等)
# ==============================================================================

# --- 自动获取脚本所在目录 ---
# 获取脚本的绝对路径，然后提取所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR"

# 目标目录 (在脚本所在目录下创建 backup_txt 文件夹)
TARGET_DIR="${SOURCE_DIR}/backup_txt"

# --- 逻辑开始 ---

echo "📍 脚本位置: $SCRIPT_DIR"

# 1. 检查源目录是否存在
if [ ! -d "$SOURCE_DIR" ]; then
    echo "❌ 错误: 源目录不存在 -> $SOURCE_DIR"
    exit 1
fi

echo "✅ 源目录确认: $SOURCE_DIR"

# 2. 创建目标目录 (如果不存在)
if [ ! -d "$TARGET_DIR" ]; then
    mkdir -p "$TARGET_DIR"
    echo "📁 已创建目标目录: $TARGET_DIR"
else
    echo "ℹ️  目标目录已存在: $TARGET_DIR"
fi

# 3. 遍历源目录中的所有文件
# 使用 find 命令查找所有普通文件 (-type f)
# -print0 和 read -d '' 用于正确处理包含空格或特殊字符的文件名
echo "🚀 开始复制并生成 .txt 副本..."

count=0

while IFS= read -r -d '' file; do
    # 跳过脚本自身，避免重复处理
    if [ "$file" = "${BASH_SOURCE[0]}" ]; then
        continue
    fi

    # 跳过目标目录中的文件（如果目标目录在源目录内）
    if [[ "$file" == "$TARGET_DIR"* ]]; then
        continue
    fi

    # 获取文件名（不含路径）
    filename=$(basename "$file")

    # 如果文件名已经有 .txt 后缀，则不重复添加
    if [[ "$filename" == *.txt ]]; then
        target_file="$TARGET_DIR/$filename"
    else
        target_file="$TARGET_DIR/${filename}.txt"
    fi

    # 复制文件内容 (使用 cat 重定向，确保是纯文本副本)
    # 如果原文件就是二进制或不想改变权限，也可以用 cp "$file" "$target_file"
    cat "$file" > "$target_file"

    echo "   📄 已生成: $target_file"
    ((count++))

done < <(find "$SOURCE_DIR" -type f -print0)

echo "=============================================================================="
echo "✨ 完成! 共处理了 $count 个文件。"
echo "📂 副本存储位置: $TARGET_DIR"
echo "=============================================================================="