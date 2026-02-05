# PJSIP-Opus 集成完成 - Phase 2 总结（最终版）

**日期**: 2026-01-19 02:00
**状态**: ✅ Phase 2 完成（修复链接测试失败），等待用户执行构建测试
**目标**: 集成 Opus 编解码器到 PJSIP 编译流程

---

## ✅ 已完成工作

### 1️⃣ 检查旧版本 Opus 库

**检查结果**：
```
libopus.a           ← 新版本（2026-01-18 20:28，701 KB）✅ Opus 1.5.2
libopus.so.0.9.0    ← 旧版本（12月23日，368 KB）⚠️ 不影响静态链接
libopus.la          ← libtool 归档
```

**结论**：
- ✅ 静态库 `libopus.a` 是新编译的 1.5.2 版本
- ✅ 旧版本动态库不会影响 PJSIP 静态链接
- ✅ 无需删除旧文件

---

### 2️⃣ 修改 `build-ubuntu24-apt.ps1` 集成 Opus

#### 修改 1：复制 Opus 库到容器（Line 273-315）

在容器准备阶段（复制 RGA 头文件之后），添加：

```powershell
# ✅ 2026-01-19 01:10 添加 Opus 音频编解码器支持
Write-Host "    - 复制 Opus 库和头文件..." -ForegroundColor Gray
$opusLibFile = "$ProjectRoot\docker\rk3588\rk3588-libs\lib\libopus.a"
$opusIncludeDir = "$ProjectRoot\docker\rk3588\rk3588-libs\include\opus"

if (Test-Path $opusLibFile) {
    # 创建 Opus 目录
    docker exec $pjsipContainerName mkdir -p /opt/opus/lib | Out-Null
    docker exec $pjsipContainerName mkdir -p /opt/opus/include | Out-Null

    # 复制 Opus 静态库
    docker cp $opusLibFile "${pjsipContainerName}:/opt/opus/lib/" 2>&1 | Out-Null

    # 复制 Opus 头文件
    if (Test-Path $opusIncludeDir) {
        docker cp "$opusIncludeDir" "${pjsipContainerName}:/opt/opus/include/" 2>&1 | Out-Null
    }

    # 创建 opus.pc 文件（PJSIP configure 需要通过 pkg-config 检测 Opus）
    docker exec $pjsipContainerName mkdir -p /opt/opus/lib/pkgconfig | Out-Null
    $opusPkgConfig = @"
prefix=/opt/opus
exec_prefix=`${prefix}
libdir=`${exec_prefix}/lib
includedir=`${prefix}/include

Name: Opus
Description: Opus IETF audio codec
Version: 1.5.2
Requires:
Conflicts:
Libs: -L`${libdir} -lopus -lm
Cflags: -I`${includedir}/opus
"@
    $opusPkgConfig | docker exec -i $pjsipContainerName bash -c "cat > /opt/opus/lib/pkgconfig/opus.pc"

    Write-Host "      ✓ Opus 1.5.2 (libopus.a + 头文件 + opus.pc)" -ForegroundColor Green
} else {
    Write-Host "      ⚠️ Opus 库未找到：$opusLibFile" -ForegroundColor Yellow
    Write-Host "      提示：运行 .\scripts\2026-01-18\02-compile-opus-in-container.ps1 编译 Opus" -ForegroundColor Gray
}
```

**功能**：
- ✅ 检查 Opus 库是否存在
- ✅ 复制 `libopus.a` 到容器 `/opt/opus/lib/`
- ✅ 复制 Opus 头文件到 `/opt/opus/include/opus/`
- ✅ 创建 `opus.pc` 文件供 pkg-config 使用
- ✅ 如果 Opus 库不存在，显示友好提示

---

#### 修改 2：添加 Opus pkgconfig 路径（Line 564）

```powershell
# ⚠️ PKG_CONFIG_PATH 必须包含 sysroot 的 pkgconfig 目录
# ✅ 2026-01-19 01:15 添加 Opus pkgconfig 路径
export PKG_CONFIG_PATH=/opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu/pkgconfig:/opt/rk3588-sysroot/usr/lib/pkgconfig:/opt/opus/lib/pkgconfig
```

**说明**：添加 `/opt/opus/lib/pkgconfig` 让 PJSIP configure 能找到 `opus.pc`

---

#### 修改 3：添加 Opus 路径到标准环境变量（Line 544, 550, 560）⭐ 关键修复

**问题**：PJSIP configure 的 AC_CHECK_LIB 宏不会使用 `OPUS_CFLAGS` 和 `OPUS_LIBS` 环境变量，只识别标准的 `CFLAGS`、`LDFLAGS`、`LIBS`

**解决**：将 Opus 路径添加到标准环境变量中

**修改 3.1：CFLAGS（Line 544）**
```bash
export CFLAGS="-fPIC -O2 -I/opt/rk3588-sysroot/usr/include -I/opt/rk3588-sysroot/usr/include/aarch64-linux-gnu -I$FFMPEG_INCLUDE_DIR -I/opt/opus/include/opus"
```

**修改 3.2：LDFLAGS（Line 550）**
```bash
export LDFLAGS="-L/opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu -L/opt/rk3588-sysroot/usr/lib -L/usr/lib/aarch64-linux-gnu -L/opt/opus/lib"
```

**修改 3.3：LIBS（Line 560）**
```bash
export LIBS="-lopus -lx264 -lx265 -lvpx -lcairo -lva -lva-drm -lva-x11 -ltwolame -lwebp -lcodec2 -ldav1d -laom -lwavpack -ltheora -ltheoraenc -ltheoradec -lxvidcore -lopenjp2 -lshine -lsnappy -lzvbi -lrsvg-2 -lvdpau -lrga -lrockchip_mpp -lpthread -lm -lrt"
```
⚠️ **注意**：`-lopus` 放在最前面，确保链接顺序正确

**技术原理**：详见 [24-FIX-Opus链接测试失败根本原因和解决方案.md](24-FIX-Opus链接测试失败根本原因和解决方案.md)

---

#### 修改 4：修改 configure 命令（Line 618）

```bash
./configure \
    --host=aarch64-linux-gnu \
    --prefix=/opt/pjsip \
    --disable-shared \
    --enable-static \
    --with-ssl=/usr \
    --with-sdl=/usr \
    --with-ffmpeg=/opt/rk3588-sysroot \
    --with-opus=/opt/opus 2>&1 | tee /tmp/configure.log
    # ✅ 2026-01-19 01:55 添加 Opus 路径到 CFLAGS/LDFLAGS/LIBS（修复链接测试失败）
    # ✅ 2026-01-19 01:15 添加 Opus 音频编解码器支持（16kHz 高质量音频）
```

**关键参数**：`--with-opus=/opt/opus`

---

### 3️⃣ 废弃独立的 PJSIP 编译脚本

**脚本位置**：[`scripts/2026-01-18/03-compile-pjsip-with-opus.ps1`](../../scripts/2026-01-18/03-compile-pjsip-with-opus.ps1)

**状态**：⚠️ 已标记为废弃

**原因**：PJSIP + Opus 编译已集成到主构建脚本 `build-ubuntu24-apt.ps1`

**脚本现在会显示**：
```
========================================
⚠️ 此脚本已废弃
========================================

PJSIP + Opus 编译已集成到主构建脚本中。

请使用：
  .\build-ubuntu24-apt.ps1 188
```

---

## 🎯 下一步操作（用户执行）

### Step 1: 执行完整构建（强制重新编译 PJSIP）

```powershell
# 进入项目根目录
cd e:\2025\3_gongkongji\belt_control_system

# 执行完整构建和部署
.\build-ubuntu24-apt.ps1 188
```

### 预期输出（关键部分）

```
========================================
Step -1: Checking PJSIP source code...
========================================
  [!] PJSIP 源码已更新 - 需要重新编译静态库

========================================================
  开始编译 PJSIP 静态库（混合优化方案）
========================================================

  [1/6] 检查 PJSIP 编译镜像（Ubuntu 20.04）...
  [2/6] 检查持久化容器...
    创建持久化容器: pjsip-builder-persistent
    ✓ 容器已创建

    复制 FFmpeg + RKMPP 到容器...
    - 复制 FFmpeg 6.0 头文件...
    - 复制 RKMPP 头文件...
    - 复制 RGA 头文件...
    - 复制 Opus 库和头文件...          ⭐ 新增
      ✓ Opus 1.5.2 (libopus.a + 头文件 + opus.pc)  ⭐ 关键输出
    - 复制 FFmpeg + 编解码器依赖库...

  [3/6] 首次全量复制源码...
    ✓ 全量复制完成

  [4/6] 首次编译（建立增量缓存，约1-2分钟）...
    配置 PJSIP...
    环境变量：
      PKG_CONFIG_PATH=.../pkgconfig:/opt/opus/lib/pkgconfig  ⭐ 包含 Opus

    ./configure \
      --host=aarch64-linux-gnu \
      --with-ssl=/usr \
      --with-sdl=/usr \
      --with-ffmpeg=/opt/rk3588-sysroot \
      --with-opus=/opt/opus                  ⭐ 新增 Opus 参数

    [configure 输出...]
    checking for opus... yes                 ⭐ 关键输出：Opus 检测成功

    生成依赖文件（make dep）...
    ✓ make dep 完成

    编译 PJSIP 静态库（使用 N 线程）...
    [编译输出...]
    ✓ PJSIP 静态库编译完成

  [5/6] 增量编译（更新 .o 文件）...
  [6/6] 复制静态库到项目...
    ✓ 复制了 25 个库文件

========================================================
✓ PJSIP 静态库编译完成
========================================================

[继续应用程序编译和部署...]
```

**关键验证点**：
- ✅ "复制 Opus 库和头文件..."
- ✅ "✓ Opus 1.5.2 (libopus.a + 头文件 + opus.pc)"
- ✅ "CFLAGS=... -I/opt/opus/include/opus"
- ✅ "LDFLAGS=... -L/opt/opus/lib"
- ✅ "LIBS=-lopus ..."
- ✅ "PKG_CONFIG_PATH=.../opt/opus/lib/pkgconfig"
- ✅ "--with-opus=/opt/opus"
- ✅ "checking for opus/opus.h... yes"
- ✅ **"checking for opus_repacketizer_get_size in -lopus... yes"** ⭐ **最关键！**

**⚠️ 如果仍然显示 "no"**：
- 查看完整诊断：[24-FIX-Opus链接测试失败根本原因和解决方案.md](24-FIX-Opus链接测试失败根本原因和解决方案.md)
- 检查容器内 Opus 库：`docker exec pjsip-builder-persistent ls -lh /opt/opus/lib/libopus.a`
- 检查环境变量：`docker exec pjsip-builder-persistent bash -c "echo LIBS=\$LIBS"`

---

## 📊 编译流程图

```
用户执行: .\build-ubuntu24-apt.ps1 188
    ↓
Step -1: 检测 PJSIP 源码变化
    ├─ 检测到配置文件修改 → 强制完整重新编译
    ├─ 或：检测到源码更新 → 重新编译
    └─ 或：首次编译 → 完整编译
    ↓
创建/复用持久化容器（Ubuntu 20.04 + GCC 9）
    ├─ 复制 FFmpeg 6.0 头文件
    ├─ 复制 RKMPP 头文件
    ├─ 复制 RGA 头文件
    ├─ 复制 Opus 库（libopus.a）         ⭐ 新增
    ├─ 复制 Opus 头文件                  ⭐ 新增
    ├─ 创建 opus.pc                     ⭐ 新增
    └─ 复制 FFmpeg + 编解码器依赖库
    ↓
全量复制 PJSIP 源码到容器
    ↓
配置 PJSIP（./configure）
    ├─ 设置交叉编译工具链（aarch64-linux-gnu）
    ├─ PKG_CONFIG_PATH 包含 Opus         ⭐ 新增
    ├─ --with-opus=/opt/opus            ⭐ 新增
    ├─ --with-ffmpeg=/opt/rk3588-sysroot
    └─ --with-ssl=/usr
    ↓
生成依赖（make dep）
    ↓
编译 PJSIP 静态库（make -j$(nproc)）
    ├─ libpjmedia-codec.a（包含 Opus 接口）⭐
    ├─ libpjmedia.a
    ├─ libpjsip.a
    └─ 第三方库（speex, ilbc, gsm, etc.）
    ↓
复制静态库到项目（docker/rk3588/rk3588-libs/lib/）
    ↓
交叉编译应用程序（链接 PJSIP + Opus）
    ↓
构建 Docker 镜像
    ↓
部署到设备 192.168.10.188
```

---

## 🔍 技术细节

### PJSIP 如何检测 Opus？

1. **环境变量**：
   ```bash
   export PKG_CONFIG_PATH=/opt/opus/lib/pkgconfig
   ```

2. **opus.pc 文件**：
   ```ini
   prefix=/opt/opus
   libdir=${prefix}/lib
   includedir=${prefix}/include

   Libs: -L${libdir} -lopus -lm
   Cflags: -I${includedir}/opus
   ```

3. **configure 脚本**：
   ```bash
   ./configure --with-opus=/opt/opus

   # configure 内部执行：
   pkg-config --exists opus
   pkg-config --cflags opus   # 返回 -I/opt/opus/include/opus
   pkg-config --libs opus     # 返回 -L/opt/opus/lib -lopus -lm
   ```

4. **configure 输出**：
   ```
   checking for opus... yes   ⭐ 成功！
   ```

---

### PJSIP 如何编译 Opus 支持？

configure 检测成功后：

1. **build.mak 添加**：
   ```makefile
   OPUS_CFLAGS = -I/opt/opus/include/opus
   OPUS_LDFLAGS = -L/opt/opus/lib -lopus -lm
   ```

2. **编译 Opus 接口**：
   ```c
   // pjmedia/src/pjmedia-codec/opus.c（PJSIP 内部）
   #ifdef PJMEDIA_HAS_OPUS_CODEC
     pj_status_t pjmedia_codec_opus_init(pjmedia_endpt *endpt);
     // ... Opus 编解码器实现
   #endif
   ```

3. **链接到 libpjmedia-codec.a**：
   ```bash
   aarch64-linux-gnu-ar rcs libpjmedia-codec.a \
       opus.o \
       ... 其他编解码器
   ```

4. **应用程序链接时**：
   ```bash
   aarch64-linux-gnu-g++ \
       -o belt_control_system \
       -lpjmedia-codec \   # 包含 Opus 接口
       -lopus \            # Opus 核心库
       ...
   ```

---

## ⚠️ 常见问题排查

### 1. "⚠️ Opus 库未找到"

**原因**：未编译 Opus 库

**解决**：
```powershell
.\scripts\2026-01-18\02-compile-opus-in-container.ps1
```

### 2. "checking for opus... no"

**原因**：pkg-config 找不到 opus.pc

**排查**：
```bash
# 在容器中执行
docker exec pjsip-builder-persistent bash -c "PKG_CONFIG_PATH=/opt/opus/lib/pkgconfig pkg-config --exists opus && echo 'Found' || echo 'Not Found'"

# 检查 opus.pc 是否存在
docker exec pjsip-builder-persistent ls -la /opt/opus/lib/pkgconfig/opus.pc
```

**可能原因**：
- opus.pc 文件未创建
- PKG_CONFIG_PATH 环境变量未设置
- opus.pc 内容格式错误

### 3. "链接错误：undefined reference to `opus_encoder_create'"

**原因**：应用程序未链接 libopus.a

**解决**：检查 CMakeLists.txt 是否包含：
```cmake
target_link_libraries(belt_control_system
    ${PJSIP_LIBRARIES}
    opus              # ← 需要添加
    ...
)
```

### 4. PJSIP 容器被删除，Opus 配置丢失

**现象**：脚本检测到配置文件修改，删除旧容器重新创建

**解决**：无需手动操作，脚本会自动：
1. 删除旧容器
2. 创建新容器
3. 重新复制 Opus 库和头文件
4. 重新 configure

---

## 📊 进度追踪

### Phase 1: Opus 库编译（已完成）✅

- [x] Phase 1.1 - 创建下载脚本 ✅
- [x] Phase 1.2 - 创建编译脚本 ✅
- [x] Phase 1.3 - 用户执行编译 ✅
- [x] Phase 1.4 - 优化脚本（缓存 configure，避免重复下载）✅

### Phase 2: PJSIP 集成 Opus（已完成）✅

- [x] Phase 2.1 - 检查旧版本 Opus 库 ✅
- [x] Phase 2.2 - 修改 build-ubuntu24-apt.ps1（添加 Opus 复制逻辑）✅
- [x] Phase 2.3a - 修复配置文件时间戳触发检测 ✅
- [x] Phase 2.3b - 重新编译 Opus（用户删除所有 .a 文件）✅
- [x] Phase 2.3c - 添加 OPUS_CFLAGS/OPUS_LIBS 环境变量 ✅
- [x] Phase 2.3d - **修复链接测试失败（添加到标准环境变量）✅**
- [ ] Phase 2.3e - **用户执行完整构建测试** ⏸️ 等待中

### Phase 3: 应用程序配置（待执行）

- [ ] Phase 3.1 - 验证 Opus 编解码器可用性
- [ ] Phase 3.2 - 配置 Opus 16kHz
- [ ] Phase 3.3 - 测试验证

### Phase 4: SIP 设置界面（待执行）

- [ ] Phase 4.1 - 数据模型扩展
- [ ] Phase 4.2 - 实现编解码器切换
- [ ] Phase 4.3 - QML 界面修改
- [ ] Phase 4.4 - 配置持久化

---

## 📄 相关文档

### 已创建文档

- [20-Opus编解码器支持完整实施计划.md](20-Opus编解码器支持完整实施计划.md) - 总体规划
- [21-Opus编译脚本创建完成-Phase1完成.md](21-Opus编译脚本创建完成-Phase1完成.md) - Phase 1 总结
- **本文档** - Phase 2 最终总结

### 参考文档

- [15-Opus16kHz配置方案.md](15-Opus16kHz配置方案.md) - Opus 16kHz 配置详情
- [17-FIX100.248-实施完成总结.md](17-FIX100.248-实施完成总结.md) - plughw 设备支持
- [CLAUDE.md](../../CLAUDE.md) - 项目工作指南

### 待创建文档

- `23-Opus编解码器配置完成.md` - Phase 3 完成后
- `24-SIP设置界面扩展完成.md` - Phase 4 完成后

---

## 🔧 修改的文件清单

### 主要修改

1. **`build-ubuntu24-apt.ps1`** ✅
   - Line 273-315：添加 Opus 库复制逻辑
   - Line 564：添加 Opus pkgconfig 路径
   - Line 605：添加 --with-opus=/opt/opus 参数

2. **`scripts/2026-01-18/03-compile-pjsip-with-opus.ps1`** ⚠️
   - 标记为废弃
   - 添加废弃警告和使用指南

---

## 🚀 执行检查清单

在运行 `build-ubuntu24-apt.ps1` 前，请确认：

- [ ] ✅ Docker Desktop 已启动
- [ ] ✅ Opus 库已编译（`docker/rk3588/rk3588-libs/lib/libopus.a` 存在）
- [ ] ✅ Opus 头文件存在（`docker/rk3588/rk3588-libs/include/opus/*.h`）
- [ ] ✅ PJSIP 源码存在（`cross-compile/src/pjproject-2.16/`）
- [ ] ✅ 磁盘空间充足（至少 10GB 可用）
- [ ] ✅ 内存充足（至少 8GB 可用）

---

**下一步操作**：请用户执行完整构建，完成后告诉我：**"构建完成，查看日志"**

**重点验证**：在构建输出中搜索 **"checking for opus... yes"**

**预计时间**：
- PJSIP 编译：5-10 分钟（首次或配置文件修改）
- 应用程序编译：2-5 分钟
- Docker 镜像构建：1-2 分钟
- 部署：1-2 分钟
- **总计**：10-20 分钟

**创建时间**: 2026-01-19 01:25
**最后更新**: 2026-01-19 01:25
