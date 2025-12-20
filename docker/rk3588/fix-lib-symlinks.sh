#!/bin/bash
# 为rk3588-libs中所有库创建符号链接

cd /opt/rk3588-libs/lib || exit 1

echo "Creating symlinks for all libraries..."

count=0
# 遍历所有.so.数字文件
for fullfile in *.so.*.*; do
    [ -f "$fullfile" ] || continue

    # 提取库的基础名称，例如 libfreetype.so.6.20.1 -> libfreetype
    basename=$(echo "$fullfile" | sed 's/\.so\..*//')

    # 提取主版本，例如 libfreetype.so.6.20.1 -> libfreetype.so.6
    major=$(echo "$fullfile" | sed 's/\(\.so\.[0-9]*\)\..*/\1/')

    # 创建 libxxx.so 符号链接
    if [ ! -e "$basename.so" ]; then
        ln -sf "$fullfile" "$basename.so" 2>/dev/null && ((count++))
    fi

    # 创建 libxxx.so.X 符号链接
    if [ ! -e "$major" ] && [ "$major" != "$fullfile" ]; then
        ln -sf "$fullfile" "$major" 2>/dev/null && ((count++))
    fi
done

# 特殊处理：只有主版本的文件（如libSDL2-2.0.so.0.14.0）
for fullfile in *.so.*.* *.so.*.*.*; do
    [ -f "$fullfile" ] || continue

    # 如果文件名包含连字符（如libSDL2-2.0），提取基础名
    if [[ "$fullfile" =~ ^([^.]+)-([0-9]+\.[0-9]+)\.so\.(.*)$ ]]; then
        basename="${BASH_REMATCH[1]}"
        version="${BASH_REMATCH[2]}"
        rest="${BASH_REMATCH[3]}"

        # 创建 libSDL2-2.0.so
        symlink="${basename}-${version}.so"
        if [ ! -e "$symlink" ]; then
            ln -sf "$fullfile" "$symlink" 2>/dev/null && ((count++))
        fi

        # 创建 libSDL2.so
        if [ ! -e "${basename}.so" ]; then
            ln -sf "$fullfile" "${basename}.so" 2>/dev/null && ((count++))
        fi
    fi
done

echo "Created $count symlinks"
echo "Total files in /opt/rk3588-libs/lib: $(ls | wc -l)"
