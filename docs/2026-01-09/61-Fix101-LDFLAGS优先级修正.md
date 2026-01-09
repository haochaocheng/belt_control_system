# Fix 101：LDFLAGS 优先级修正 - 解决交叉编译链接器路径问题 ⚠️ 已废弃

**日期**: 2026-01-10 00:55
**问题**: PJSIP configure 失败 "C compiler cannot create executables"
**根本原因**: LDFLAGS 优先搜索容器宿主机库路径（x86_64），而不是目标 sysroot（aarch64）
**状态**: ❌ **已废弃** - 脚本 Line 460 已设置正确的 LDFLAGS，会覆盖 Dockerfile

---

## ⚠️ 废弃说明（2026-01-10 01:15）

**原因**:
- `build-ubuntu24-apt.ps1:460` 已经设置了正确的 LDFLAGS
- 脚本中的 `export` 会覆盖 Dockerfile 的 `ENV` 设置
- **修改 Dockerfile 是不必要的**，不需要重建 Docker 镜像

**脚本中的正确设置**（Line 460）:
```bash
export LDFLAGS="-L/opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu -L/opt/rk3588-sysroot/usr/lib -L/usr/lib/aarch64-linux-gnu"
```

**Dockerfile 已恢复**（2026-01-10 01:10）:
- 恢复到原始的 LDFLAGS 设置
- 不影响编译结果（因为会被脚本覆盖）

**完整说明**: 参见 [62-Fix98-99-100最终方案总结.md](62-Fix98-99-100最终方案总结.md)

---

---

## 🎯 修复目标

修正交叉编译环境中的链接器搜索路径优先级，确保优先使用目标设备的 sysroot 库，而不是容器宿主机的库。

---

## 📊 问题分析

### 错误现象

**前置条件**:
- ✅ Fix 100 已实施（符号链接已创建）
- ✅ 手动验证：容器中 libx264.so 存在
- ✅ 手动 configure 测试：成功

**但自动构建仍然失败**:
```bash
checking whether the C compiler works... no
aconfigure: error: C compiler cannot create executables
See `config.log' for more details

config.log:
/usr/lib/gcc-cross/aarch64-linux-gnu/13/../../../../aarch64-linux-gnu/bin/ld:
cannot find -lx264: No such file or directory
```

### 深入诊断

**检查环境变量**（容器内）:
```bash
echo $LDFLAGS
# 输出（错误的优先级）：
-L/usr/lib/aarch64-linux-gnu -L/usr/lib -L/opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu -L/opt/rk3588-sysroot/usr/lib
```

**问题分析**:
```
链接器搜索顺序（从左到右）：
1. /usr/lib/aarch64-linux-gnu     ← 容器宿主机库（x86_64 环境，不是真正的 aarch64）
2. /usr/lib                       ← 容器宿主机库
3. /opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu  ← ✅ 目标设备库（应该优先）
4. /opt/rk3588-sysroot/usr/lib    ← 目标设备库
```

**根本原因**:
1. **容器中的 `/usr/lib/aarch64-linux-gnu`**：
   - 这是 Ubuntu 的多架构支持目录
   - 在 x86_64 容器中，这个目录**不包含真正的 aarch64 库**
   - 只是一个命名约定，用于交叉编译工具链

2. **链接器优先搜索错误的路径**：
   - 链接器先搜索 `/usr/lib/aarch64-linux-gnu`（空目录或不完整）
   - 找不到 libx264.so → 报错
   - **根本没有搜索到 sysroot 路径**

3. **为什么手动测试成功**：
   - 手动测试时可能临时修改了环境变量
   - 或者使用了明确的 `-L` 参数覆盖默认路径

---

## 🔧 解决方案

### 修改位置

**文件**: `docker/rk3588/Dockerfile.pjsip-ubuntu20`
**行号**: Line 116-121
**作用**: Docker 镜像环境变量配置

### 修改内容

```dockerfile
# ⚠️ CRITICAL: 库文件优先搜索容器内的（OpenSSL），然后才是 sysroot（FFmpeg）
# ✅ 2026-01-10 00:55 [修复 101] 修正 LDFLAGS 优先级
# 原因：链接器优先搜索容器中的宿主机库（/usr/lib/aarch64-linux-gnu），而不是目标 sysroot
# 结果：configure 失败 "C compiler cannot create executables"
# 解决：优先搜索 sysroot 路径，将宿主机库路径放在最后
# 旧值（错误）：ENV LDFLAGS="-L/usr/lib/aarch64-linux-gnu -L/usr/lib -L/opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu -L/opt/rk3588-sysroot/usr/lib"
ENV LDFLAGS="-L/opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu -L/opt/rk3588-sysroot/usr/lib -L/usr/lib/aarch64-linux-gnu"
```

### 关键变化

**修改前**（错误）:
```bash
-L/usr/lib/aarch64-linux-gnu      # ❌ 优先（容器宿主机）
-L/usr/lib                        # ❌ 其次
-L/opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu  # 第三（目标设备）
-L/opt/rk3588-sysroot/usr/lib     # 最后
```

**修改后**（正确）:
```bash
-L/opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu  # ✅ 优先（目标设备）
-L/opt/rk3588-sysroot/usr/lib     # ✅ 其次
-L/usr/lib/aarch64-linux-gnu      # 最后（容器宿主机）
```

### 为什么保留容器宿主机路径？

**原因**: 某些库需要从容器宿主机获取

**具体例子**:
1. **OpenSSL 3.x**:
   - 目标设备（RK3588）只有 OpenSSL 1.1
   - PJSIP 需要 OpenSSL 3.x（容器中安装）
   - 必须从容器宿主机链接 OpenSSL 3.x

2. **ALSA 开发库**:
   - 容器中安装了完整的 ALSA 开发库
   - 目标设备可能只有运行时库

**策略**:
- ✅ 优先使用 sysroot 的库（编解码器、FFmpeg、硬件加速）
- ✅ Fallback 到容器宿主机的库（OpenSSL、ALSA）
- ✅ 避免混用不同架构的库

---

## 📋 实施过程

### 诊断步骤

1. **验证符号链接存在**:
   ```bash
   docker exec pjsip-builder-persistent ls -la /opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu/libx264.so
   # 输出：libx264.so -> libx264.so.164（符号链接存在）
   ```

2. **检查 LDFLAGS**:
   ```bash
   docker exec pjsip-builder-persistent bash -c 'echo $LDFLAGS'
   # 输出：-L/usr/lib/aarch64-linux-gnu -L/usr/lib -L/opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu ...
   # 问题：宿主机路径在前
   ```

3. **手动测试 configure**（修改后的 LDFLAGS）:
   ```bash
   docker exec pjsip-builder-persistent bash -c \
     'cd /src/pjproject && \
      LDFLAGS="-L/opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu -L/opt/rk3588-sysroot/usr/lib -L/usr/lib/aarch64-linux-gnu" \
      ./aconfigure --host=aarch64-linux-gnu ...'

   # 输出：checking whether the C compiler works... yes
   ```

4. **确认修复方案**:
   - 必须修改 Dockerfile ENV LDFLAGS（不是运行时覆盖）
   - 原因：PJSIP configure 脚本使用 ENV 中的 LDFLAGS

### 为什么需要重建镜像？

**Docker ENV 的作用域**:
```dockerfile
# ENV 在 Dockerfile 中定义
ENV LDFLAGS="-L/path/to/lib"

# 作用：
# 1. 所有后续 RUN 命令都继承这个环境变量
# 2. 容器启动时自动设置
# 3. 不能在运行时容器中永久修改（除非重启容器）
```

**为什么运行时覆盖不行**:
```bash
# 这个命令只对当前 shell 有效
docker exec container bash -c 'export LDFLAGS=...; ./configure'

# PJSIP configure 脚本会启动子进程（make, gcc）
# 子进程不继承临时环境变量
```

**解决方案**: 必须修改 Dockerfile，重建镜像

---

## 📖 技术细节

### 交叉编译中的库搜索路径

**概念**:
- **Target（目标架构）**: aarch64（ARM 64位）
- **Host（编译主机）**: x86_64（Intel/AMD 64位）
- **Sysroot**: 目标设备的完整文件系统镜像（用于交叉编译）

**正确的搜索顺序**:
```
1. Sysroot 的 /usr/lib/aarch64-linux-gnu  ← 目标设备的库（优先）
2. Sysroot 的 /usr/lib                    ← 目标设备的通用库
3. Host 的 /usr/lib/aarch64-linux-gnu     ← 容器宿主机的交叉编译工具链库（Fallback）
```

**为什么 Host 路径在最后**:
- Host 中的 `/usr/lib/aarch64-linux-gnu` 只包含基础工具链库
- 大部分库（FFmpeg、编解码器、硬件加速）只在 sysroot 中
- Host 路径用于 Fallback（OpenSSL 3.x、ALSA 等）

### GCC 链接器 `-L` 参数

**行为**:
```bash
gcc -L/path1 -L/path2 -L/path3 -lx264

# 链接器搜索顺序：
# 1. /path1/libx264.so（找到则停止）
# 2. /path2/libx264.so
# 3. /path3/libx264.so
# 4. 系统默认路径（/lib, /usr/lib）
```

**关键点**:
- `-L` 参数的顺序决定搜索优先级
- 找到第一个匹配的库就停止搜索
- 不会检查库的架构（x86_64 vs aarch64）→ 可能链接错误架构的库

### 多架构支持（multiarch）

**Ubuntu/Debian 的多架构目录约定**:
```bash
/usr/lib/x86_64-linux-gnu    # x86_64 架构库
/usr/lib/aarch64-linux-gnu   # aarch64 架构库
/usr/lib/i386-linux-gnu      # i386 架构库
```

**交叉编译容器中的陷阱**:
- 容器是 x86_64 架构
- `/usr/lib/aarch64-linux-gnu` 目录存在，但**不是真正的 aarch64 库**
- 只是交叉编译工具链的一部分（可能为空或不完整）
- **必须使用 sysroot 中的完整 aarch64 库**

---

## ✅ 修复总结

### 核心修改

**Dockerfile.pjsip-ubuntu20:116-121** - 修正 LDFLAGS 优先级

### 搜索路径变化

| 路径 | 修改前优先级 | 修改后优先级 | 包含内容 |
|------|--------------|--------------|----------|
| `/opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu` | 第 3 位 | **第 1 位** ✅ | 目标设备所有库 |
| `/opt/rk3588-sysroot/usr/lib` | 第 4 位 | **第 2 位** ✅ | 目标设备通用库 |
| `/usr/lib/aarch64-linux-gnu` | 第 1 位 ❌ | 第 3 位 | 容器工具链库 |

### 预期效果

- ✅ configure 成功（优先找到 sysroot 中的库）
- ✅ 编解码器库正确链接（libx264, libx265, libvpx, ...）
- ✅ OpenSSL 3.x 仍然从容器获取（Fallback 机制）
- ✅ 避免架构混淆（不会意外链接 x86_64 库）

### 影响范围

⚠️ **需要重建 Docker 镜像**

**原因**: Dockerfile ENV 变量在镜像构建时固化

**操作**:
```powershell
# 删除旧镜像和容器
docker rm -f pjsip-builder-persistent
docker rmi pjsip-builder-ubuntu20:latest

# 重新构建（自动触发）
.\build-ubuntu24-apt.ps1 192.168.10.188
```

**时间成本**:
- 完整镜像重建：约 10-20 分钟
- 但只需重建一次

---

## 🔗 相关文档

- [60-Fix100-编解码器库符号链接自动创建.md](60-Fix100-编解码器库符号链接自动创建.md) - 配合 Fix 101 的前置修复
- [59-Fix98-降低关键帧请求频率-解决高CPU负载.md](59-Fix98-降低关键帧请求频率-解决高CPU负载.md) - 核心问题修复
- [58-高CPU负载根本原因-PJSIP频繁请求关键帧.md](58-高CPU负载根本原因-PJSIP频繁请求关键帧.md) - 根本原因分析

### 技术参考

- [GCC Cross-Compilation Guide](https://gcc.gnu.org/onlinedocs/gcc/Cross-Compilation.html)
- [Debian MultiArch](https://wiki.debian.org/Multiarch)
- [LD.SO(8) - Dynamic Linker/Loader](https://man7.org/linux/man-pages/man8/ld.so.8.html)

---

**创建时间**: 2026-01-10 01:00
**修复 ID**: Fix 101
**核心问题**: LDFLAGS 优先级错误（宿主机库路径在前）
**解决方案**: 修正 Dockerfile ENV LDFLAGS，sysroot 优先
**影响范围**: 需要重建 Docker 镜像（一次性）
