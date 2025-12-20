# Docker 部署 GLIBC 版本问题分析与解决方案

## 问题发现 (2025-12-15)

### 当前状况

在 Ubuntu 20.04.6 LTS (192.168.10.155) 上部署 Docker 容器时，发现应用依赖的库 glibc 版本不匹配。

### GLIBC 版本检查结果

| 组件 | 最高 GLIBC 版本需求 | 状态 |
|------|-------------------|------|
| Qt6 (libQt6Core.so.6) | **GLIBC 2.35** | ✅ 可用 |
| FFmpeg (libavutil.so.56) | **GLIBC 2.38** | ❌ 不兼容 |
| SDL2 (libSDL2-2.0.so.0) | **GLIBC 2.38** | ❌ 不兼容 |
| Debian Bookworm 容器 | **GLIBC 2.36** | - |

### 问题根源

**FFmpeg 和 SDL2 库是在 Windows Docker 环境中编译的，使用了 glibc 2.38**，而：
- Debian Bookworm 官方镜像只有 glibc 2.36
- Qt6 (qt-raspi) 使用 glibc 2.35，可以在 Debian Bookworm 中正常运行
- 其他 RK3588 库也都兼容 glibc 2.36

**结论**: FFmpeg 和 SDL2 需要使用与 Qt6 相同的交叉编译工具链重新编译。

---

## 解决方案

### 方案A: 重新编译 FFmpeg 和 SDL2（推荐）

使用 qt-raspi 的交叉编译环境重新编译 FFmpeg 和 SDL2。

#### 1. 确定 Qt6 的编译环境

Qt6 (qt-raspi) 已经编译好，使用的工具链信息：
- 目标: aarch64-linux-gnu
- glibc: ≤ 2.35
- 编译器: 待确定（需要查看 qt-raspi/lib/cmake/Qt6/qt.toolchain.cmake）

#### 2. 设置相同的交叉编译环境

```bash
# 检查 Qt6 工具链配置
cat e:/2025/3_gongkongji/belt_control_system/docker/rk3588/qt-raspi/lib/cmake/Qt6/qt.toolchain.cmake
```

#### 3. 重新编译 FFmpeg

使用与 Qt6 相同的工具链和 sysroot：

```bash
# 配置 FFmpeg
./configure \
  --prefix=/path/to/output \
  --enable-cross-compile \
  --cross-prefix=aarch64-linux-gnu- \
  --arch=aarch64 \
  --target-os=linux \
  --sysroot=/path/to/sysroot \
  --enable-shared \
  --disable-static \
  --extra-cflags="-march=armv8-a" \
  --extra-ldflags="-L/path/to/sysroot/lib"

# 编译
make -j$(nproc)
make install
```

#### 4. 重新编译 SDL2

```bash
# 配置 SDL2
cmake -B build \
  -DCMAKE_TOOLCHAIN_FILE=/path/to/toolchain.cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=ON

# 编译
cmake --build build -j$(nproc)
cmake --install build --prefix /path/to/output
```

---

### 方案B: 使用预编译的兼容版本

从 sysroot 或 apt 源获取 aarch64 版本的 FFmpeg 和 SDL2：

```bash
# 在 aarch64 设备上安装
apt-get install -y libavcodec-dev libavformat-dev libsdl2-dev

# 复制库到 Windows
scp user@device:/usr/lib/aarch64-linux-gnu/libav*.so* /path/to/libs/
scp user@device:/usr/lib/aarch64-linux-gnu/libSDL2*.so* /path/to/libs/
```

---

### 方案C: 升级 Docker 基础镜像（不推荐）

使用 Debian Testing (Trixie) 或 Ubuntu 24.04，它们可能有 glibc 2.38+。

**问题**:
- 需要网络访问 Docker Hub
- 测试设备无法访问互联网
- 稳定性未经验证

---

## 推荐执行步骤

### 短期方案（1-2小时）

1. **使用方案B** - 从 Ubuntu 20.04 设备获取兼容的 FFmpeg/SDL2 库
2. 替换当前的 FFmpeg 和 SDL2 库
3. 重新构建 Docker 镜像
4. 测试运行

### 长期方案（1-2天）

1. **使用方案A** - 设置统一的交叉编译环境
2. 重新编译 FFmpeg、SDL2 和其他依赖
3. 确保所有库使用相同的 glibc 版本
4. 建立标准化的编译流程文档

---

## 下一步操作

### 立即行动

```bash
# 1. 在 Ubuntu 设备上检查系统库版本
ssh linaro@192.168.10.155 "dpkg -l | grep -E 'libav|libsdl2'"

# 2. 如果有兼容版本，复制到部署目录
scp linaro@192.168.10.155:/usr/lib/aarch64-linux-gnu/libav*.so* /path/to/build/libs/
scp linaro@192.168.10.155:/usr/lib/aarch64-linux-gnu/libSDL2*.so* /path/to/build/libs/

# 3. 重新构建 Docker 镜像
cd /home/linaro/belt-control-build
docker build -t belt-control:latest .

# 4. 启动测试
docker run -d --name belt_control --privileged --network host belt-control:latest
```

---

## 参考信息

### GLIBC 版本与 Debian 版本对应关系

| Debian 版本 | GLIBC 版本 | 状态 |
|------------|-----------|------|
| Debian 11 (Bullseye) | 2.31 | 旧 |
| Debian 12 (Bookworm) | 2.36 | 当前 |
| Debian 13 (Trixie) | 2.38+ | 测试版 |
| Ubuntu 20.04 | 2.31 | LTS |
| Ubuntu 22.04 | 2.35 | LTS |
| Ubuntu 24.04 | 2.39 | 最新 LTS |

### 检查库的 GLIBC 依赖

```bash
# 方法1: 使用 strings
strings /path/to/lib.so | grep GLIBC_ | sort -u

# 方法2: 使用 objdump
objdump -T /path/to/lib.so | grep GLIBC

# 方法3: 使用 readelf
readelf -V /path/to/lib.so
```

---

**创建时间**: 2025-12-15
**最后更新**: 2025-12-15
**状态**: 问题已确认，等待实施解决方案
