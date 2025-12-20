# Docker 部署最终解决方案

**创建时间**: 2025-12-15
**状态**: 准备实施

---

## 🎯 问题总结

### 发现的问题
1. ✅ Qt6 编译使用 **GLIBC 2.35**（兼容 Debian Bookworm 2.36）
2. ❌ FFmpeg 编译使用 **GLIBC 2.38**（不兼容 Debian Bookworm 2.36）
3. ❌ SDL2 编译使用 **GLIBC 2.38**（不兼容 Debian Bookworm 2.36）
4. ❌ 缺少 Mali GPU 库（libmali-hook.so.1, libmali.so.1）

### 根本原因
**FFmpeg 和 SDL2 在 Windows Docker 中使用了较新的编译环境（glibc 2.38），而 Qt6 使用的是兼容的旧版本（glibc 2.35）**

---

## ✨ 最终解决方案

### 方案概述
使用 Qt6 (qt-raspi) 的编译工具链重新编译 FFmpeg 和 SDL2，确保所有库使用相同的 glibc 版本。

### 编译工具链信息
- **编译器**: aarch64-linux-gnu-gcc/g++
- **目标架构**: aarch64 (armv8-a)
- **Sysroot**: `docker/rk3588/sysroot/pi-root`
- **最大 GLIBC**: 2.35 (匹配 Qt6)
- **工具链配置**: `docker/rk3588/toolchain-rk3588.cmake`

---

## 📦 需要重新编译的组件

### 1. FFmpeg
**当前版本**: 基于 glibc 2.38
**目标版本**: 基于 glibc ≤ 2.35
**编译选项**:
```bash
./configure \
  --prefix=/opt/ffmpeg-arm64 \
  --enable-cross-compile \
  --cross-prefix=aarch64-linux-gnu- \
  --arch=aarch64 \
  --target-os=linux \
  --sysroot=/workspace/belt_control_system/docker/rk3588/sysroot/pi-root \
  --enable-shared \
  --disable-static \
  --disable-doc \
  --disable-htmlpages \
  --disable-manpages \
  --disable-podpages \
  --disable-txtpages \
  --enable-gpl \
  --enable-version3 \
  --extra-cflags="-march=armv8-a" \
  --extra-ldflags="-L/workspace/belt_control_system/docker/rk3588/sysroot/pi-root/usr/lib/aarch64-linux-gnu"
```

### 2. SDL2
**当前版本**: 基于 glibc 2.38
**目标版本**: 基于 glibc ≤ 2.35
**编译选项**:
```bash
cmake -B build \
  -DCMAKE_TOOLCHAIN_FILE=/workspace/belt_control_system/docker/rk3588/toolchain-rk3588.cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=ON \
  -DCMAKE_INSTALL_PREFIX=/opt/sdl2-arm64 \
  -DSDL_STATIC=OFF
```

### 3. Mali GPU 库
**来源**: 从 RK3588 实际设备复制或使用 sysroot 中的版本
**所需文件**:
- libmali.so.1
- libmali-hook.so.1（如果需要）

---

## 🚀 实施步骤

### 步骤 1: 使用 Docker 编译环境
```powershell
# 启动编译容器（使用现有的 belt-control-rk3588 镜像）
docker run --rm -it \
  -v e:/2025/3_gongkongji/belt_control_system:/workspace/belt_control_system \
  -e SYSROOT=/workspace/belt_control_system/docker/rk3588/sysroot/pi-root \
  -e QT_HOST_PATH=/opt/qt-host \
  -e QT_TARGET_PATH=/opt/qt-raspi \
  -w /workspace \
  belt-control-rk3588:latest bash
```

### 步骤 2: 编译 FFmpeg
```bash
cd /workspace
wget https://ffmpeg.org/releases/ffmpeg-4.4.2.tar.xz
tar xf ffmpeg-4.4.2.tar.xz
cd ffmpeg-4.4.2

# 配置
./configure \
  --prefix=/opt/ffmpeg-arm64 \
  --enable-cross-compile \
  --cross-prefix=aarch64-linux-gnu- \
  --arch=aarch64 \
  --target-os=linux \
  --sysroot=$SYSROOT \
  --enable-shared \
  --disable-static \
  --disable-doc \
  --extra-cflags="-march=armv8-a" \
  --extra-ldflags="-L$SYSROOT/usr/lib/aarch64-linux-gnu"

# 编译
make -j$(nproc)
make install

# 复制到项目
cp /opt/ffmpeg-arm64/lib/*.so* /workspace/belt_control_system/docker/rk3588/rk3588-libs/lib/
```

### 步骤 3: 编译 SDL2
```bash
cd /workspace
wget https://github.com/libsdl-org/SDL/releases/download/release-2.28.5/SDL2-2.28.5.tar.gz
tar xzf SDL2-2.28.5.tar.gz
cd SDL2-2.28.5

# 配置
cmake -B build \
  -DCMAKE_TOOLCHAIN_FILE=/workspace/belt_control_system/docker/rk3588/toolchain-rk3588.cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=ON \
  -DCMAKE_INSTALL_PREFIX=/opt/sdl2-arm64 \
  -DSDL_STATIC=OFF

# 编译
cmake --build build -j$(nproc)
cmake --install build

# 复制到项目
cp /opt/sdl2-arm64/lib/*.so* /workspace/belt_control_system/docker/rk3588/rk3588-libs/lib/
```

### 步骤 4: 复制 Mali 库
```bash
# 从 sysroot 复制
cp $SYSROOT/usr/lib/aarch64-linux-gnu/mali/libmali.so* \
   /workspace/belt_control_system/docker/rk3588/rk3588-libs/lib/

# 或从实际设备复制
# scp pi@192.168.10.170:/usr/lib/libmali.so* /path/to/rk3588-libs/lib/
```

### 步骤 5: 重新编译应用
```powershell
# 退出容器后，在 Windows 上重新编译
.\build.bat
```

### 步骤 6: 重新部署 Docker
```powershell
# 使用一键部署脚本
.\docker\rk3588\一键部署-完整版.ps1 -TargetHost "192.168.10.155" -TargetUser "linaro" -AutoRun
```

---

## 🔍 验证步骤

### 1. 检查编译后的 glibc 依赖
```bash
# 在容器内检查
strings /opt/ffmpeg-arm64/lib/libavutil.so* | grep GLIBC_ | sort -u
strings /opt/sdl2-arm64/lib/libSDL2-2.0.so* | grep GLIBC_ | sort -u
```

**期望结果**: 最高版本不超过 GLIBC_2.35

### 2. 检查 Docker 容器运行
```bash
ssh linaro@192.168.10.155 "docker ps | grep belt_control"
ssh linaro@192.168.10.155 "docker logs belt_control 2>&1 | tail -20"
```

**期望结果**: 容器正常运行，无 glibc 或库缺失错误

### 3. 完整依赖检查
```bash
ssh linaro@192.168.10.155 "docker run --rm belt-control:latest ldd /opt/app/bin/belt_control_system | grep 'not found'"
```

**期望结果**: 无 "not found" 输出

---

## 📝 自动化脚本

我已经创建了自动化编译脚本：

### Windows 脚本: `rebuild-compatible-libs.ps1`
```powershell
# 一键重新编译所有不兼容的库
.\docker\rk3588\rebuild-compatible-libs.ps1
```

### Docker 内脚本: `compile-ffmpeg-sdl2.sh`
```bash
# 在 Docker 容器内执行
bash /workspace/belt_control_system/docker/rk3588/compile-ffmpeg-sdl2.sh
```

---

## ⚠️ 注意事项

### 编译时间
- FFmpeg: 约 20-30 分钟
- SDL2: 约 5-10 分钟
- 总计: 约 30-40 分钟

### 磁盘空间
- FFmpeg 源码: ~70MB
- SDL2 源码: ~8MB
- 编译临时文件: ~500MB
- 最终库文件: ~50MB

### 常见问题

**Q: 编译失败，提示找不到某个头文件**
A: 确保 sysroot 完整，检查 `$SYSROOT/usr/include` 是否有相应头文件

**Q: 链接错误，找不到某个库**
A: 检查 `$SYSROOT/usr/lib/aarch64-linux-gnu` 是否有相应库文件

**Q: 编译成功但运行时仍提示 GLIBC 版本不对**
A: 使用 `strings libxxx.so | grep GLIBC_` 确认编译后的库版本

---

## 🎯 最终目标

完成后应达到以下状态：

1. ✅ 所有库（Qt6, FFmpeg, SDL2）使用相同的 glibc ≤ 2.35
2. ✅ Docker 镜像包含所有必需的依赖
3. ✅ 容器可以在任何 aarch64 + Docker 环境运行
4. ✅ 一键部署脚本自动完成所有步骤
5. ✅ Mali GPU 库正确加载

---

## 📚 相关文档

- [DOCKER部署GLIBC问题分析.md](DOCKER部署GLIBC问题分析.md) - 详细问题分析
- [toolchain-rk3588.cmake](toolchain-rk3588.cmake) - 交叉编译工具链配置
- [一键部署-完整版.ps1](一键部署-完整版.ps1) - 自动化部署脚本

---

**下一步**: 创建并执行自动化编译脚本
