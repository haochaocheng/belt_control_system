#!/bin/bash
cd /opt/sysroot/nanopi-sysroot/usr/lib/aarch64-linux-gnu

# Qt依赖库列表 + 传递依赖
for libname in png16 harfbuzz graphite2 pcre2-16 pcre2-8 dbus-1 fontconfig xkbcommon icuuc icudata icui18n pulse pulse-simple GLESv2 glib-2.0 gobject-2.0 uuid gcrypt vorbis vorbisenc ogg FLAC lzma zstd expat gpg-error v4l2 v4l1 v4l2rds v4lconvert
do
    # 查找版本化的库文件
    versioned_file=$(ls lib${libname}.so.* 2>/dev/null | head -1)

    if [ -n "$versioned_file" ]; then
        # 创建无版本号的符号链接
        ln -sf $(basename "$versioned_file") lib${libname}.so
        echo "✅ Created: lib${libname}.so -> $(basename $versioned_file)"
    else
        echo "⚠️  Not found: lib${libname}.so.*"
    fi
done

# SDL2 特殊处理 (文件名为 libSDL2-2.0.so.*)
if [ -f libSDL2.so ]; then
    echo "✅ Found: libSDL2.so (already exists)"
elif ls libSDL2-2.0.so.* 2>/dev/null | head -1; then
    versioned=$(ls libSDL2-2.0.so.* 2>/dev/null | head -1)
    ln -sf $(basename "$versioned") libSDL2-2.0.so.0
    ln -sf libSDL2-2.0.so.0 libSDL2.so
    echo "✅ Created: libSDL2.so -> libSDL2-2.0.so.0 -> $(basename $versioned)"
else
    echo "⚠️  Not found: libSDL2-2.0.so.*"
fi

# 检查 rknn_api 库
if [ -f /opt/rk3588-libs/lib/librknn_api.so ]; then
    echo "✅ Found: librknn_api.so in RK3588 libs"
elif ls /opt/rk3588-libs/lib/librknn_api.so.* 2>/dev/null | head -1; then
    cd /opt/rk3588-libs/lib
    versioned=$(ls librknn_api.so.* 2>/dev/null | head -1)
    ln -sf $(basename "$versioned") librknn_api.so
    echo "✅ Created: librknn_api.so -> $(basename $versioned)"
else
    echo "⚠️  Not found: librknn_api.so"
fi

echo ""
echo "✅ 符号链接创建完成"
