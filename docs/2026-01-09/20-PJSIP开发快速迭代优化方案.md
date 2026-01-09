# PJSIP 开发快速迭代优化方案

**日期**：2026-01-09 09:30
**问题**：修改 PJSIP 源码后，从编译到部署需要 10 分钟，太慢
**目标**：缩短到 2-3 分钟

---

## 当前流程分析（~10 分钟）

| 步骤 | 操作 | 耗时 | 瓶颈 |
|------|------|------|------|
| 1 | PJSIP 静态库编译 | 1-2 分钟 | ✅ 必需 |
| 2 | 应用程序链接 | 30 秒 | ✅ 必需 |
| 3 | Docker 镜像构建 | 1-2 分钟 | ❌ 可跳过 |
| 4 | 镜像导出为 .tar | 1-2 分钟 | ❌ 可跳过 |
| 5 | 上传 .tar 到设备（~300MB） | 2-3 分钟 | ❌ 可优化 |
| 6 | 设备加载镜像 | 1 分钟 | ❌ 可跳过 |
| 7 | 启动容器 | 30 秒 | ✅ 必需 |

---

## 优化方案 1：快速增量脚本（推荐）

### 原理
跳过 Docker 镜像构建和打包，直接替换容器内的二进制文件。

### 流程（~2-3 分钟）

```
修改源码
  ↓
检测源码变化（5秒）
  ↓
增量编译 PJSIP（1分钟，仅修改的文件）
  ↓
重新链接应用（30秒）
  ↓
直接上传二进制（~10MB，30秒）
  ↓
SSH 替换容器内文件并重启（30秒）
  ↓
测试
```

### 使用方法

```powershell
# 第一次需要完整编译（建立缓存）
.\build-ubuntu24-apt.ps1 188

# 后续修改源码后，使用快速脚本
.\quick-rebuild.ps1 188
```

### 时间对比

| 场景 | 完整编译 | 快速脚本 | 节省时间 |
|------|---------|---------|---------|
| 修改 PJSIP 源码 | 10 分钟 | 2-3 分钟 | **70%** |
| 只修改应用代码 | 8 分钟 | 1-2 分钟 | **80%** |

---

## 优化方案 2：设备上直接编译（最快）

### 原理
在设备上安装编译工具链，直接编译和运行，跳过交叉编译和传输。

### 优点
- ✅ 最快：1 分钟内完成
- ✅ 无需传输文件
- ✅ 实时测试

### 缺点
- ❌ 设备磁盘空间需求大（~2GB）
- ❌ 首次安装编译环境耗时
- ❌ 设备性能影响编译速度

### 适用场景
- RK3588 设备（8核 ARM Cortex-A76/A55）
- 磁盘空间充足（> 5GB）
- 频繁修改代码测试

### 实施步骤

```bash
# SSH 登录设备
ssh pi@192.168.10.188

# 安装编译工具（仅需一次）
sudo apt update
sudo apt install -y build-essential cmake git

# 挂载源码目录（Windows 共享或 NFS）
# 或者直接在设备上 git clone

# 本地编译
cd /path/to/belt_control_system
mkdir build_local && cd build_local
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j8  # 利用 8 核心并行编译

# 直接运行
./bin_arm64/belt_control_system
```

---

## 优化方案 3：Docker 缓存优化

### 原理
优化 Dockerfile 层级结构，最大化利用 Docker 缓存。

### 修改 Dockerfile

```dockerfile
# 基础层（很少变化）
FROM ubuntu:24.04 AS base
RUN apt update && apt install -y ...

# 依赖层（偶尔变化）
COPY docker/rk3588/lib/*.so /app/lib/
ENV LD_LIBRARY_PATH=/app/lib

# 应用层（频繁变化）
COPY build_rk3588/bin_arm64/belt_control_system /app/
CMD ["/app/belt_control_system"]
```

### 效果
- 基础层缓存命中：镜像构建 10 秒
- 依赖层缓存命中：镜像构建 20 秒
- 只有应用层重新构建

---

## 优化方案 4：并行编译

### PJSIP 编译优化

当前：
```bash
make lib
```

优化：
```bash
make -j$(nproc) lib  # 使用所有 CPU 核心
```

### 效果
- 8 核 CPU：编译时间缩短 50-70%
- PJSIP 21 个静态库并行编译

### 修改位置

`build-ubuntu24-apt.ps1` Line 604：
```powershell
make lib 2>&1 | tee /tmp/make.log

# 改为
make -j$(nproc) lib 2>&1 | tee /tmp/make.log
```

---

## 推荐的开发流程

### 初次设置（10 分钟）
```powershell
.\build-ubuntu24-apt.ps1 188
```

### 日常开发（2-3 分钟）
```powershell
# 1. 修改源码
vim cross-compile/src/pjproject-2.16/pjmedia/src/pjmedia-codec/ffmpeg_vid_codecs.c

# 2. 快速编译和部署
.\quick-rebuild.ps1 188

# 3. 查看日志
ssh pi@192.168.10.188 "docker logs -f belt-control-latest | grep 'CODE-VERSION\|FIX 91'"
```

### 重大变更（10 分钟）
- 修改 CMakeLists.txt
- 添加新的依赖库
- 修改 Dockerfile

使用完整编译：
```powershell
.\build-ubuntu24-apt.ps1 188
```

---

## 性能对比

| 方案 | 首次 | 增量 | 传输 | 总耗时 | 节省 |
|------|------|------|------|--------|------|
| **当前（完整）** | 10分钟 | 10分钟 | 2-3分钟 | **10分钟** | - |
| **快速脚本** | 10分钟 | 1.5分钟 | 30秒 | **2-3分钟** | **70%** |
| **设备编译** | 1小时 | 1分钟 | 0 | **1分钟** | **90%** |
| **缓存优化** | 10分钟 | 5分钟 | 2分钟 | **5分钟** | **50%** |

---

## 立即可用的优化

### 1. 使用快速脚本（已创建）
```powershell
.\quick-rebuild.ps1 188
```

### 2. 启用并行编译（5分钟修改）

修改 `build-ubuntu24-apt.ps1` Line 604：
```powershell
# 当前
make lib 2>&1 | tee /tmp/make.log

# 修改为
make -j8 lib 2>&1 | tee /tmp/make.log
```

### 3. 只编译修改的库（自动检测）

脚本已支持，会自动检测：
- PJSIP 源码是否修改
- 应用代码是否修改
- 只编译必要的部分

---

## 下一步行动

### 立即执行（0 成本）
1. ✅ 使用 `quick-rebuild.ps1` 快速脚本
2. ✅ 启用 `make -j8` 并行编译

### 短期优化（1 小时）
3. 优化 Dockerfile 层级结构
4. 添加更细粒度的源码变更检测

### 长期优化（1 天）
5. 设备上安装编译环境
6. 设置远程开发环境（VS Code Remote SSH）

---

## 相关文件

- **快速脚本**：`quick-rebuild.ps1`
- **完整脚本**：`build-ubuntu24-apt.ps1`
- **源码**：`cross-compile/src/pjproject-2.16/pjmedia/src/pjmedia-codec/ffmpeg_vid_codecs.c`
