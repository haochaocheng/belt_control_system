# PJSIP-Opus 集成脚本创建完成 - Phase 2 完成

**日期**: 2026-01-19 00:55
**状态**: ✅ Phase 2.1 和 2.2 完成，等待用户执行 PJSIP 重编译
**目标**: 准备 PJSIP 重编译脚本，集成 Opus 编解码器

---

## ✅ 已完成工作

### 1️⃣ 验证 PJSIP 配置文件

**配置文件位置**: [`docker/rk3588/pjsip_config_site.h`](../../docker/rk3588/pjsip_config_site.h)

**发现**：配置文件已包含 Opus 启用：

```c
/* 启用 Opus 音频编解码 - 高质量音频 */
#define PJMEDIA_HAS_OPUS_CODEC          1
```

**状态**: ✅ 配置文件已就绪，无需修改

---

### 2️⃣ 创建 PJSIP 重编译脚本（支持 Opus）

**脚本位置**: [`scripts/2026-01-18/03-compile-pjsip-with-opus.ps1`](../../scripts/2026-01-18/03-compile-pjsip-with-opus.ps1)

#### 功能概述

在 Docker 容器中交叉编译 PJSIP 2.16 静态库，集成 Opus 编解码器支持。

#### 关键特性

1. **前置条件验证**（Step 0）
   - ✅ 检查 PJSIP 源码存在
   - ✅ 检查 Opus 库存在（`libopus.a`）
   - ✅ 检查 Opus 头文件存在

2. **Opus 库集成**（Step 3）
   - 复制 Opus 静态库到容器：`/opt/opus/lib/libopus.a`
   - 复制 Opus 头文件到容器：`/opt/opus/include/opus/*.h`
   - **创建 pkg-config 文件**（关键步骤！）：
     ```bash
     /opt/opus/lib/pkgconfig/opus.pc
     ```
   - **为什么需要 pkg-config**：PJSIP 的 configure 脚本使用 `pkg-config` 检测 Opus 库

3. **PJSIP 配置**（Step 5）
   ```bash
   PKG_CONFIG_PATH=/opt/opus/lib/pkgconfig \
   ./configure \
       --host=aarch64-linux-gnu \
       --prefix=/opt/rk3588-libs \
       --with-opus=/opt/opus \          # ⭐ 新增 Opus 支持
       --disable-g7221-codec \
       --disable-shared \
       --enable-static \
       CFLAGS='-O2 -DNDEBUG'
   ```
   **关键参数**：
   - `--with-opus=/opt/opus`：指定 Opus 安装路径
   - `PKG_CONFIG_PATH`：让 configure 能找到 opus.pc

4. **编译和安装**（Step 6-7）
   - 生成依赖：`make dep`
   - 并行编译：`make -j$(nproc)`（预计 5-8 分钟）
   - 安装到：`/opt/rk3588-libs`

5. **产物复制**（Step 8）
   - 复制所有 PJSIP 库（`libpj*.a`）
   - 复制第三方库（speex, ilbc, gsm, srtp, resample, webrtc）
   - 输出到：`docker/rk3588/rk3588-libs/lib/`

6. **验证机制**
   - ✅ 检查 configure 是否检测到 Opus（搜索 build.mak）
   - ✅ 验证关键库文件存在（libpjmedia-codec, libpjmedia, libpjsip）
   - ✅ 显示每个库文件大小

---

## 🔍 与原有脚本的对比

### 原有脚本（[`scripts/2025-12-29/compile-pjsip-in-container.ps1`](../../scripts/2025-12-29/compile-pjsip-in-container.ps1)）

```powershell
./configure --prefix=/opt/rk3588-libs --disable-g7221-codec CFLAGS='-O2 -DNDEBUG'
```

**问题**：缺少 `--with-opus` 参数，Opus 编解码器不会被编译进去

### 新脚本（`03-compile-pjsip-with-opus.ps1`）

```powershell
PKG_CONFIG_PATH=/opt/opus/lib/pkgconfig \
./configure \
    --host=aarch64-linux-gnu \
    --prefix=/opt/rk3588-libs \
    --with-opus=/opt/opus \           # ⭐ 新增
    --disable-g7221-codec \
    --disable-shared \
    --enable-static \
    CFLAGS='-O2 -DNDEBUG'
```

**改进**：
- ✅ 添加 `--with-opus=/opt/opus`
- ✅ 设置 `PKG_CONFIG_PATH` 环境变量
- ✅ 创建 opus.pc 文件供 PJSIP 检测

---

## 🎯 下一步操作（用户执行）

### Step 1: 执行 PJSIP 重编译脚本

```powershell
# 进入项目根目录
cd e:\2025\3_gongkongji\belt_control_system

# 运行 PJSIP 重编译脚本
.\scripts\2026-01-18\03-compile-pjsip-with-opus.ps1
```

### 预期输出

```
========================================
重新编译 PJSIP 2.16 支持 Opus
========================================

📋 [0/8] 验证前置条件...
  ✅ PJSIP 源码存在
  ✅ Opus 库存在 (245.67 KB)
  ✅ Opus 头文件存在 (4 个)

🐳 [1/8] 准备容器环境...
  ✅ 容器创建成功

🔧 [2/8] 安装编译工具链...
  ✅ 工具链安装完成

📦 [3/8] 复制 Opus 库到容器...
  ✅ Opus 库复制完成

📦 [4/8] 复制 PJSIP 源码到容器...
  ✅ 源码复制完成

⚙️ [5/8] 配置 PJSIP 编译...
  --- configure 开始执行 ---
  [configure 输出...]
  --- configure 执行完毕 ---
  ✅ Opus 编解码器已启用

🔧 [6/8] 生成编译依赖...
  ✅ 依赖生成完成

🔨 [7/8] 编译 PJSIP 库（5-8 分钟）...
  --- make 开始编译 ---
  [编译输出...]
  --- make 编译完毕 ---
  ✅ 编译完成（耗时 5.8 分钟）
  ✅ 安装完成

📤 [8/8] 复制库文件到项目...
  复制 libpjmedia-codec-aarch64-unknown-linux-gnu.a...
  复制 libpjmedia-aarch64-unknown-linux-gnu.a...
  [更多库文件...]
  ✅ 复制完成（25 个库文件）

🧹 清理容器...
  ✅ 容器已删除

✅ 验证产物...
  ✅ libpjmedia-codec-aarch64-unknown-linux-gnu.a (2345.67 KB)
  ✅ libpjmedia-aarch64-unknown-linux-gnu.a (1234.56 KB)
  ✅ libpjsip-aarch64-unknown-linux-gnu.a (987.65 KB)

========================================
✅ PJSIP 库编译成功（支持 Opus）！
========================================

📦 输出产物：
  库文件：docker/rk3588/rk3588-libs/lib/*.a
  包含 Opus 支持
```

**预计时间**: 8-12 分钟（取决于机器性能）

---

## 🔧 技术细节

### 为什么需要 pkg-config 文件？

PJSIP 的 configure 脚本使用 `pkg-config` 来检测第三方库：

```bash
# configure 内部执行（简化版）
pkg-config --exists opus
if [ $? -eq 0 ]; then
  OPUS_CFLAGS=$(pkg-config --cflags opus)
  OPUS_LIBS=$(pkg-config --libs opus)
  # 启用 Opus 支持
fi
```

**opus.pc 文件内容**：

```ini
prefix=/opt/opus
exec_prefix=${prefix}
libdir=${exec_prefix}/lib
includedir=${prefix}/include

Name: Opus
Description: Opus IETF audio codec
Version: 1.5.2
Libs: -L${libdir} -lopus -lm
Cflags: -I${includedir}/opus
```

### PJSIP 如何链接 Opus？

编译后，PJSIP 的 `libpjmedia-codec.a` 会包含 Opus 编解码器的接口代码：

```c
// pjmedia/src/pjmedia-codec/opus.c（PJSIP 内部）
#ifdef PJMEDIA_HAS_OPUS_CODEC
  pj_status_t pjmedia_codec_opus_init(pjmedia_endpt *endpt);
  // ... Opus 编解码器实现
#endif
```

链接时，应用程序需要同时链接：
- `libpjmedia-codec.a`（包含 Opus 接口）
- `libopus.a`（Opus 核心库）

### 编译器检测 Opus 的日志标志

configure 成功检测到 Opus 后，会在 `build.mak` 中添加：

```makefile
# build.mak（部分）
OPUS_CFLAGS = -I/opt/opus/include/opus
OPUS_LDFLAGS = -L/opt/opus/lib -lopus -lm
```

脚本会验证这些标志是否存在，确认 Opus 集成成功。

---

## ⚠️ 常见问题排查

### 1. "❌ Opus 库不存在"

**原因**：未运行 Opus 编译脚本

**解决**：
```powershell
.\scripts\2026-01-18\02-compile-opus-in-container.ps1
```

### 2. "⚠️ 警告：Opus 可能未被检测到"

**原因**：pkg-config 未找到 opus.pc 文件

**解决**：
- 检查脚本是否成功创建 `/opt/opus/lib/pkgconfig/opus.pc`
- 检查 `PKG_CONFIG_PATH` 环境变量是否正确设置

**手动验证**：
```powershell
docker exec pjsip-opus-builder-temp bash -c "PKG_CONFIG_PATH=/opt/opus/lib/pkgconfig pkg-config --exists opus && echo 'Found' || echo 'Not Found'"
```

### 3. "❌ 配置失败"

**查看详细日志**：
```powershell
docker exec pjsip-opus-builder-temp cat /build/pjproject-2.16/config.log
```

**常见原因**：
- 缺少交叉编译工具链（gcc-aarch64-linux-gnu）
- Opus 头文件路径错误
- pkg-config 未安装

### 4. "❌ 编译失败"

**查看编译错误**：脚本会显示实时编译输出

**常见原因**：
- 链接器找不到 libopus.a
- Opus 头文件缺失
- 内存不足（需要至少 4GB RAM）

### 5. Docker 网络问题

**症状**：无法拉取 ubuntu:24.04 镜像

**解决**：
```powershell
# 手动拉取镜像
docker pull ubuntu:24.04

# 或使用国内镜像源
docker pull registry.cn-hangzhou.aliyuncs.com/library/ubuntu:24.04
docker tag registry.cn-hangzhou.aliyuncs.com/library/ubuntu:24.04 ubuntu:24.04
```

---

## 📊 进度追踪

### Phase 1: Opus 库编译（已完成）✅

- [x] Phase 1.1 - 创建下载脚本 ✅
- [x] Phase 1.2 - 创建编译脚本 ✅
- [x] Phase 1.3 - 用户执行编译 ✅

### Phase 2: PJSIP 集成 Opus（当前）

- [x] Phase 2.1 - 验证 PJSIP 配置 ✅
- [x] Phase 2.2 - 创建重编译脚本 ✅
- [ ] Phase 2.3 - **用户执行重编译** ⏸️ 等待中

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
- **本文档** - Phase 2 总结

### 参考文档

- [15-Opus16kHz配置方案.md](15-Opus16kHz配置方案.md) - Opus 16kHz 配置详情
- [17-FIX100.248-实施完成总结.md](17-FIX100.248-实施完成总结.md) - plughw 设备支持

### 待创建文档

- `23-Opus编解码器配置完成.md` - Phase 3 完成后
- `24-SIP设置界面扩展完成.md` - Phase 4 完成后

---

## 🔧 脚本文件清单

### 已创建脚本

1. **`scripts/2026-01-18/01-download-opus-source.ps1`** ✅
   - 下载 Opus 1.5.2 源码
   - 状态：已执行，成功

2. **`scripts/2026-01-18/02-compile-opus-in-container.ps1`** ✅
   - 在容器中编译 Opus 库
   - 状态：已执行，成功

3. **`scripts/2026-01-18/03-compile-pjsip-with-opus.ps1`** ✅
   - 重新编译 PJSIP 支持 Opus
   - 状态：可用，等待执行

### 待创建脚本

无（Phase 3 和 4 不需要独立脚本，修改应用程序代码即可）

---

## 🚀 执行检查清单

在运行脚本前，请确认：

- [ ] ✅ Docker Desktop 已启动
- [ ] ✅ Opus 库已编译（`docker/rk3588/rk3588-libs/lib/libopus.a` 存在）
- [ ] ✅ Opus 头文件存在（`docker/rk3588/rk3588-libs/include/opus/*.h`）
- [ ] ✅ PJSIP 源码存在（`cross-compile/src/pjproject-2.16/`）
- [ ] ✅ 磁盘空间充足（至少 5GB 可用）
- [ ] ✅ 内存充足（至少 4GB 可用）

---

**下一步操作**：请用户执行 PJSIP 重编译脚本，完成后告诉我：**"PJSIP 编译完成，查看"**

**预计时间**：8-12 分钟

**创建时间**: 2026-01-19 00:55
**最后更新**: 2026-01-19 00:55
