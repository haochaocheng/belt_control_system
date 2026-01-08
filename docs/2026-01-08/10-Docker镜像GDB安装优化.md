# Docker 镜像 GDB 安装优化

**日期**: 2026-01-08 17:50
**类型**: 编译效率优化

---

## 🎯 问题

每次全编译都要执行：
```
[ 9/10] RUN apt-get update && apt-get install -y gdb
```

**影响**：
- 每次应用重新编译都要重新安装 GDB
- 浪费时间：`apt-get update` (10-20秒) + `apt-get install gdb` (10-30秒)
- 总计每次编译浪费约 30-60 秒

---

## 🔍 根本原因

### Docker 镜像分层架构

项目使用两层 Docker 镜像：

1. **基础镜像** (`Dockerfile.ubuntu24-base`)
   - 包含系统依赖（Qt、FFmpeg 依赖、字体等）
   - **很少变化，Docker 会缓存**
   - 只在基础依赖变化时重新构建

2. **应用镜像** (`Dockerfile.ubuntu24-apt`)
   - 包含应用二进制文件（belt_control_system）
   - **频繁变化（每次代码修改）**
   - 每次应用重新编译都会重建

### 问题所在

**GDB 安装在应用镜像层**（`Dockerfile.ubuntu24-apt` Line 29）：
```dockerfile
RUN apt-get update && apt-get install -y gdb && rm -rf /var/lib/apt/lists/* && \
    chmod +x /app/belt_control_system /app/sherpa_tts_service && \
    ...
```

**后果**：
- 每次应用镜像重建 → 重新执行 `apt-get update` 和 `apt-get install gdb`
- 即使 GDB 版本完全相同，也要重新下载安装
- Docker 无法缓存这一层（因为应用文件变化导致后续层失效）

---

## ✅ 优化方案

### 核心思路

**将 GDB 移至基础镜像**

- 基础镜像只构建一次（除非系统依赖变化）
- GDB 随基础镜像一起安装
- 应用镜像重建时直接使用基础镜像中的 GDB

### 实施步骤

#### Step 1: 添加 GDB 到基础镜像

**文件**: `Dockerfile.ubuntu24-base`
**位置**: Line 90-93（在 ICU 依赖后）

```dockerfile
# ICU (internationalization)
libicu74 \
\
# ✅ 2026-01-08 17:50 [优化] GDB 调试工具（移至基础镜像，避免每次重新安装）
# 原因：应用层镜像频繁重建，基础镜像只构建一次
# 效果：节省每次编译时 apt-get update 和 GDB 安装时间
gdb \
```

#### Step 2: 从应用镜像移除 GDB 安装

**文件**: `Dockerfile.ubuntu24-apt`
**位置**: Line 26-30

**修改前**：
```dockerfile
# Setup application
# ✅ 2026-01-08 14:00 [修复 81] 安装 GDB 用于手动调试
RUN apt-get update && apt-get install -y gdb && rm -rf /var/lib/apt/lists/* && \
    chmod +x /app/belt_control_system /app/sherpa_tts_service && \
    ...
```

**修改后**：
```dockerfile
# Setup application
# ✅ 2026-01-08 17:50 [优化] GDB 已移至基础镜像，此处不再安装
# 原因：基础镜像只构建一次，应用层频繁重建
# 效果：每次编译节省 apt-get update 和 GDB 安装时间（约 30-60 秒）
RUN chmod +x /app/belt_control_system /app/sherpa_tts_service && \
    ...
```

---

## 📊 优化效果

### 构建时间对比

| 场景 | 优化前 | 优化后 | 节省时间 |
|------|--------|--------|----------|
| **首次构建**（基础镜像不存在） | - | - | **无影响** |
| **基础镜像缓存 + 应用重建**（最常见） | ~40秒 GDB 安装 | 0秒 | **30-60秒** |
| **PJSIP 修改 + 应用重建** | ~40秒 GDB 安装 | 0秒 | **30-60秒** |

### Docker 层缓存利用率

| 层 | 优化前 | 优化后 |
|---|--------|--------|
| **基础镜像层** | ✅ 缓存（除非系统依赖变化） | ✅ 缓存 + **GDB** |
| **应用镜像层** | ❌ 每次重建（包含 GDB 安装） | ✅ 每次重建（**无 GDB 安装**） |

---

## 🔄 使用影响

### 对开发流程的影响

**无任何负面影响**：
1. GDB 仍然在容器中可用（通过基础镜像安装）
2. 调试命令不变：
   ```bash
   docker exec -it belt-control-latest gdb /app/belt_control_system
   ```
3. GDB 自动化脚本仍然正常工作：
   ```powershell
   .\scripts\2026-01-08\02-gdb-remote-debug.ps1
   ```

**正面效果**：
- ✅ 每次编译快 30-60 秒
- ✅ 减少网络流量（不重复下载 GDB）
- ✅ 符合 Docker 最佳实践（不变依赖放基础层）

---

## ⚠️ 注意事项

### 基础镜像重建触发条件

**以下情况会触发基础镜像重建**（GDB 会重新安装一次）：
1. 修改 `Dockerfile.ubuntu24-base` 中的任何依赖
2. Ubuntu 24.04 基础镜像更新（`FROM ubuntu:24.04`）
3. 手动删除基础镜像：`docker rmi belt-control-base:ubuntu24`

**正常开发流程不会触发重建**：
- ✅ 修改 PJSIP 源码（只重建应用镜像）
- ✅ 修改应用源码（只重建应用镜像）
- ✅ 修改 `Dockerfile.ubuntu24-apt`（只重建应用镜像）

### 验证 GDB 可用性

**首次应用新基础镜像后验证**：
```bash
# 连接到设备
ssh linaro@192.168.10.188

# 检查容器中 GDB
docker exec belt-control-latest gdb --version

# 预期输出：
# GNU gdb (Ubuntu 13.1-2ubuntu2) 13.1
```

---

## 📁 相关文件

### 修改的文件
1. [Dockerfile.ubuntu24-base](../../Dockerfile.ubuntu24-base) - Line 90-93: 添加 GDB
2. [Dockerfile.ubuntu24-apt](../../Dockerfile.ubuntu24-apt) - Line 26-30: 移除 GDB 安装

### 相关文档
- [02-gdb-remote-debug.ps1](../../scripts/2026-01-08/02-gdb-remote-debug.ps1) - GDB 自动化调试脚本（无需修改）
- [07-快速调试方案-避免全量编译.md](07-快速调试方案-避免全量编译.md) - 其他编译优化方法
- [08-容器崩溃后保持运行-GDB调试方案.md](08-容器崩溃后保持运行-GDB调试方案.md) - GDB 使用方法

---

## 🎯 Docker 最佳实践

### 分层原则

```
┌─────────────────────────────────────┐
│  应用层 (频繁变化)                    │
│  - 应用二进制                        │
│  - 配置文件                          │
│  - 符号链接脚本                      │  ← 每次应用重建
├─────────────────────────────────────┤
│  基础层 (很少变化)                    │
│  - 系统库 (Qt, FFmpeg依赖)          │
│  - 字体                              │
│  - 调试工具 (GDB) ← 优化点           │  ← 只在依赖变化时重建
├─────────────────────────────────────┤
│  Ubuntu 24.04 基础镜像               │  ← 官方镜像，几乎不变
└─────────────────────────────────────┘
```

### 关键规则

1. **不变的东西放底层** → GDB 是调试工具，版本稳定，应该在基础层
2. **频繁变化的放顶层** → 应用二进制每次编译都变，应该在应用层
3. **利用 Docker 缓存** → 基础层缓存可以跨多次应用重建复用

---

**文档版本**: v1.0
**创建时间**: 2026-01-08 17:50
**优化效果**: 每次编译节省 30-60 秒
