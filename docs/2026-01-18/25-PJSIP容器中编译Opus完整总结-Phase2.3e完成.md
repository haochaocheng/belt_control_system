# PJSIP 容器中编译 Opus 完整总结 - Phase 2.3e 完成

**日期**: 2026-01-19 02:50
**状态**: ✅ Opus 在 PJSIP 容器中编译成功
**下一步**: 用户删除旧容器并重新构建，验证 PJSIP configure 检测 Opus 成功

---

## 🎯 问题背景

### 原始问题
PJSIP configure 检测 Opus 时：
```
checking for opus/opus.h... yes          ✅ 头文件检测成功
checking for opus_repacketizer_get_size in -lopus... no  ❌ 链接测试失败
OPUS library not found, OPUS support disabled
```

### 根本原因（经多次调试确定）
**容器版本不匹配导致编译器/glibc 版本冲突**：
- **Opus 编译环境**：Ubuntu 24.04 (gcc 13.3.0, glibc 2.39)
- **PJSIP 编译环境**：Ubuntu 20.04 (gcc 9.x, glibc 2.31)
- **后果**：autoconf 的 `AC_CHECK_LIB` 链接测试失败，即使库文件完全正确

### 验证证据
1. ✅ libopus.a 存在且正确：`-rwxr-xr-x 1 root root 701K`
2. ✅ 函数符号存在：`00000000000001a4 T opus_repacketizer_get_size`
3. ✅ 手动链接成功：`aarch64-linux-gnu-gcc test.c -L/opt/opus/lib -lopus -lm`
4. ❌ configure 链接测试失败（跨容器版本冲突）

---

## ✅ 解决方案：在 PJSIP 容器中重新编译 Opus

### 核心思路
**确保 Opus 和 PJSIP 在完全相同的编译环境中构建**

- ✅ 使用 PJSIP 的持久化容器（Ubuntu 20.04）
- ✅ 相同的 gcc 版本
- ✅ 相同的 glibc 版本
- ✅ 相同的交叉编译工具链（aarch64-linux-gnu-gcc）

---

## 📝 实施脚本：04-compile-opus-in-pjsip-container.ps1

### 脚本路径
[scripts/2026-01-18/04-compile-opus-in-pjsip-container.ps1](../../scripts/2026-01-18/04-compile-opus-in-pjsip-container.ps1)

### 脚本结构

#### Step 1: 安装编译依赖
```powershell
docker exec pjsip-builder-persistent bash -c 'apt-get update'
docker exec pjsip-builder-persistent bash -c 'apt-get install -y build-essential autoconf automake libtool m4 pkg-config wget ca-certificates'
```

**关键修复**：
- ✅ 2026-01-19 02:45 添加 `ca-certificates` 修复 SSL 证书验证失败

#### Step 2: 复制 Opus 源码到容器
```powershell
# 创建 tar 包
tar -cf opus-source.tar -C cross-compile\src opus-1.5.2

# 复制到容器
docker cp opus-source.tar pjsip-builder-persistent:/tmp/

# 解压
docker exec pjsip-builder-persistent bash -c "cd /tmp && tar -xf opus-source.tar"

# 修复脚本执行权限（关键！）
docker exec pjsip-builder-persistent bash -c "find /tmp/opus-1.5.2 -type f -name '*.sh' -exec chmod +x {} \;"
```

**关键修复**：
- ✅ 2026-01-19 02:40 修复 tar 不保留执行权限的问题
- 使用 `find` 给所有 `.sh` 文件添加执行权限

#### Step 3: 编译 Opus
```bash
#!/bin/bash
set -e
cd /tmp/opus-1.5.2

# 无条件运行 autogen.sh 生成完整的构建系统
./autogen.sh

# 配置交叉编译
./configure \
    --host=aarch64-linux-gnu \
    --prefix=/tmp/opus-install \
    --disable-shared \
    --enable-static \
    --disable-doc \
    --disable-extra-programs

# 编译
make -j$(nproc)

# 安装到临时目录
make install

# 验证编译产物
ls -lh /tmp/opus-install/lib/libopus.a
file /tmp/opus-install/lib/libopus.a
```

**关键修复**：
- ✅ 2026-01-19 02:30 修复 UTF-8 BOM 问题：改为在容器内直接创建脚本
- ✅ 2026-01-19 02:35 无条件运行 autogen.sh，确保辅助文件完整

#### Step 4: 复制编译产物到 Windows
```powershell
# 复制静态库
docker cp pjsip-builder-persistent:/tmp/opus-install/lib/libopus.a docker\rk3588\rk3588-libs\lib\

# 复制头文件
docker cp pjsip-builder-persistent:/tmp/opus-install/include/opus docker\rk3588\rk3588-libs\include\

# 复制 opus.pc
docker cp pjsip-builder-persistent:/tmp/opus-install/lib/pkgconfig/opus.pc docker\rk3588\rk3588-libs\lib\pkgconfig\

# 修正 opus.pc 路径（从 /tmp/opus-install 改为 /opt/opus）
(Get-Content opus.pc) -replace '/tmp/opus-install', '/opt/opus' | Set-Content opus.pc
```

---

## 🐛 遇到的问题及解决方案

### 问题 1：UTF-8 BOM 问题
**错误**：
```
bash: line 1: $'\357\273\277set': command not found
```

**原因**：PowerShell HERE-DOC 传递到 Docker stdin 时带入 BOM 字符

**解决**：
```powershell
# ❌ 错误方式（通过 stdin 传递脚本）
$script | docker exec -i container bash

# ✅ 正确方式（在容器内创建脚本文件）
docker exec container bash -c "cat > /tmp/script.sh << 'EOF'
#!/bin/bash
...
EOF
chmod +x /tmp/script.sh"
docker exec container bash -c '/tmp/script.sh'
```

### 问题 2：autogen.sh 生成的 configure 缺少辅助文件
**错误**：
```
configure: error: cannot find required auxiliary files: compile ltmain.sh config.guess config.sub missing install-sh
```

**原因**：脚本检查 `configure` 存在就跳过 `autogen.sh`，但 `configure` 不完整

**解决**：
```bash
# ❌ 错误方式（条件运行）
if [ ! -f configure ]; then
    ./autogen.sh
fi
./configure

# ✅ 正确方式（无条件运行）
./autogen.sh  # 始终运行，生成完整构建系统
./configure
```

### 问题 3：dnn/download_model.sh 权限被拒绝
**错误**：
```
./autogen.sh: 12: dnn/download_model.sh: Permission denied
```

**原因**：tar 打包没有保留执行权限

**解决**：
```powershell
# 解压后立即修复所有 .sh 文件权限
docker exec container bash -c "find /tmp/opus-1.5.2 -type f -name '*.sh' -exec chmod +x {} \;"
```

### 问题 4：SSL 证书验证失败
**错误**：
```
ERROR: cannot verify media.xiph.org's certificate
Unable to locally verify the issuer's authority.
```

**原因**：容器内缺少 CA 证书包

**解决**：
```bash
apt-get install -y ca-certificates
```

---

## 📊 编译结果

### 输出文件
```
✅ 静态库：docker/rk3588/rk3588-libs/lib/libopus.a
✅ 头文件：docker/rk3588/rk3588-libs/include/opus/
         - opus.h
         - opus_defines.h
         - opus_types.h
         - opus_multistream.h
         - opus_projection.h
         - opus_custom.h
✅ PKG配置：docker/rk3588/rk3588-libs/lib/pkgconfig/opus.pc
```

### 库文件信息
```bash
$ file libopus.a
libopus.a: current ar archive

$ aarch64-linux-gnu-nm libopus.a | grep opus_repacketizer_get_size
00000000000001a4 T opus_repacketizer_get_size

$ ls -lh libopus.a
-rwxr-xr-x 1 root root 701K Jan 19 02:47 libopus.a
```

---

## 🎯 下一步操作（Phase 2.3f）

### 用户手动执行

#### 1️⃣ 删除旧的 PJSIP 容器
```powershell
docker rm -f pjsip-builder-persistent
```

**原因**：旧容器中使用的是 Ubuntu 24.04 编译的 Opus，需要删除强制重新创建

#### 2️⃣ 重新构建 PJSIP 和应用程序
```powershell
.\build-ubuntu24-apt.ps1 188
```

**预期结果**：
```
Step -1: Checking PJSIP source code...
  [!] PJSIP 源码已更新 - 需要重新编译静态库

[2/6] 检查持久化容器...
  容器不存在 - 需要完整编译
  [创建新容器...]
  复制 Opus 库和头文件...
    ✓ Opus 1.5.2 (libopus.a + 头文件 + opus.pc)

[4/6] 首次编译（建立增量缓存）...
  配置 PJSIP...
  环境变量：
    CFLAGS=-fPIC -O2 ... -I/opt/opus/include/opus      ⭐
    LDFLAGS=... -L/opt/opus/lib      ⭐
    LIBS=-lm      ⭐ (configure 前使用最小 LIBS)

  ./configure \
    --host=aarch64-linux-gnu \
    --with-opus=/opt/opus      ⭐

  [configure 输出...]
  checking for OPUS installations..
  Using OPUS prefix... /opt/opus
  checking for opus/opus.h... yes      ⭐
  checking for opus_repacketizer_get_size in -lopus... yes      ⭐⭐⭐ 成功！

  恢复完整的 LIBS 环境变量...
    LIBS=-lopus -lx264 -lx265 ... -lm -lrt      ⭐ (make 时使用完整 LIBS)

  make dep...
  make...
  ✅ PJSIP 编译成功，包含 Opus 支持

Step 1-6: 应用程序编译和部署...
  ✅ 部署到设备 188
```

### 验证要点

#### 关键日志 1：Opus 库复制成功
```
复制 Opus 库和头文件...
  ✓ Opus 1.5.2 (libopus.a + 头文件 + opus.pc)
```

#### 关键日志 2：PJSIP configure 检测 Opus 成功
```
checking for opus_repacketizer_get_size in -lopus... yes  ⭐⭐⭐
```

这是最关键的验证点！必须是 **yes**，不能是 **no**。

#### 关键日志 3：LIBS 环境变量正确切换
```
configure 前：LIBS=-lm
configure 后：LIBS=-lopus -lx264 -lx265 ... -lm -lrt
```

---

## 📚 技术原理总结

### 1. autoconf AC_CHECK_LIB 的工作原理

**autoconf 生成的测试代码**：
```c
char opus_repacketizer_get_size();
int main() {
    return opus_repacketizer_get_size();
}
```

**实际链接命令**：
```bash
$CC $CFLAGS $CPPFLAGS conftest.c $LDFLAGS -lopus $LIBS -o conftest
```

**关键点**：
- ❌ 不会使用 `$OPUS_CFLAGS`, `$OPUS_LIBS` 等自定义变量
- ✅ 只会使用 `$CPPFLAGS`, `$LDFLAGS`, `$LIBS` 标准变量

### 2. 跨容器编译的问题

**错误做法**：
```
容器 A (Ubuntu 24.04, gcc 13) → 编译 Opus
容器 B (Ubuntu 20.04, gcc 9)  → 编译 PJSIP，使用容器 A 的 Opus
❌ 结果：configure 链接测试失败（ABI 不兼容）
```

**正确做法**：
```
容器 B (Ubuntu 20.04, gcc 9)  → 编译 Opus
容器 B (Ubuntu 20.04, gcc 9)  → 编译 PJSIP，使用同容器的 Opus
✅ 结果：configure 链接测试成功（环境完全一致）
```

### 3. LIBS 环境变量的正确使用

**问题**：
```bash
export LIBS="-lopus -lx264 -lx265 -lvpx ... -lm"
./configure
```
- ❌ configure 的 AC_CHECK_LIB 测试会链接所有 LIBS
- ❌ 如果某些库不存在或版本不匹配，测试会失败
- ❌ 导致 Opus 被误判为不可用

**解决**：
```bash
# configure 前：使用最小 LIBS
export LIBS="-lm"
./configure --with-opus=/opt/opus

# configure 后：恢复完整 LIBS（供 make 使用）
export LIBS="-lopus -lx264 -lx265 -lvpx ... -lm"
make
```

---

## 🔗 相关文档

- [20-Opus编解码器支持完整实施计划.md](20-Opus编解码器支持完整实施计划.md) - 总体规划
- [21-Opus编译脚本创建完成-Phase1完成.md](21-Opus编译脚本创建完成-Phase1完成.md) - Phase 1 总结
- [23-PJSIP-Opus集成完成-Phase2最终总结.md](23-PJSIP-Opus集成完成-Phase2最终总结.md) - Phase 2 总结
- [24-FIX-Opus链接测试失败根本原因和解决方案.md](24-FIX-Opus链接测试失败根本原因和解决方案.md) - 根本原因分析

---

## 📋 阶段总结

### Phase 2.3 完成情况

- ✅ Phase 2.3a - 优化 Opus 编译脚本（避免重复下载）
- ✅ Phase 2.3b - 重新编译 Opus（恢复被删文件）
- ✅ Phase 2.3c - 修复 OPUS_CFLAGS/LIBS + 触发配置文件修改
- ✅ Phase 2.3d - 修复 configure 链接测试（添加到标准环境变量）
- ✅ **Phase 2.3e - 在 PJSIP 容器中重新编译 Opus** ⭐ 本文档
- ⏳ Phase 2.3f - 删除旧容器并重新构建（等待用户执行）

### 下一阶段

- ⏳ Phase 3 - 应用程序配置 Opus（代码中启用 Opus 编解码器）
- ⏳ Phase 4 - SIP 设置界面扩展（添加音频编码器选择 UI）

---

**创建时间**: 2026-01-19 02:50
**最后更新**: 2026-01-19 02:50
**状态**: ✅ Phase 2.3e 完成，等待 Phase 2.3f（用户操作）
