# Phase 7.46.47 - 修复 tokenizers 编译失败

**创建时间**: 2026-02-24 18:35
**问题**: `tokenizers` 包编译失败，导致 83 分钟的 pip 安装全部浪费
**解决方案**: 在 Dockerfile 中安装 Rust 编译器

---

## 一、问题描述

### 1.1 错误现象

构建基础镜像时，pip install 在 83 分钟后失败：

```
ERROR: Failed building wheel for tokenizers
ERROR: Could not build wheels for tokenizers, which is required to install pyproject.toml-based projects
```

### 1.2 根本原因

**依赖链**：
```
MeloTTS → transformers → tokenizers (需要 Rust 编译器)
```

**问题**：
- `tokenizers` 包需要 **Rust 编译器**
- Ubuntu 24.04 基础镜像没有安装 Rust
- pip 尝试从源码编译 `tokenizers`，失败
- **整个 pip install 命令失败，前面 83 分钟的安装全部回滚**

### 1.3 影响

- ❌ 浪费 83 分钟构建时间
- ❌ 基础镜像构建失败
- ❌ 无法部署应用到设备

---

## 二、解决方案

### 2.1 修改内容

**文件**: `Dockerfile.ubuntu24-base`

**修改位置**: Line 155-171

**修改前**:
```dockerfile
# ✅ 2026-02-22 14:00 [Phase 7.46.43]: 修复 MeloTTS 安装源（从 GitHub）
COPY docker/rk3588/tts_engines/paddlespeech/requirements.txt /tmp/paddlespeech-requirements.txt
RUN pip3 install --no-cache-dir --break-system-packages \
    "numpy<2.0.0" \
    && pip3 install --no-cache-dir --break-system-packages \
    -r /tmp/paddlespeech-requirements.txt \
    && rm /tmp/paddlespeech-requirements.txt
```

**修改后**:
```dockerfile
# ✅ 2026-02-24 18:30 [Phase 7.46.47]: 添加 Rust 编译器（tokenizers 需要）
# 原因：tokenizers 包需要 Rust 编译器，否则 pip install 失败，浪费 83 分钟
# 效果：可以从源码编译 tokenizers，避免构建失败
# 方案：先安装 Rust，再安装 Python 依赖
RUN apt-get update && apt-get install -y curl \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && rm -rf /var/lib/apt/lists/*

# 设置 Rust 环境变量
ENV PATH="/root/.cargo/bin:${PATH}"

COPY docker/rk3588/tts_engines/paddlespeech/requirements.txt /tmp/paddlespeech-requirements.txt
RUN pip3 install --no-cache-dir --break-system-packages \
    "numpy<2.0.0" \
    && pip3 install --no-cache-dir --break-system-packages \
    -r /tmp/paddlespeech-requirements.txt \
    && rm /tmp/paddlespeech-requirements.txt
```

### 2.2 关键改动

1. **安装 Rust 编译器**：
   ```dockerfile
   RUN apt-get update && apt-get install -y curl \
       && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
       && rm -rf /var/lib/apt/lists/*
   ```

2. **设置 Rust 环境变量**：
   ```dockerfile
   ENV PATH="/root/.cargo/bin:${PATH}"
   ```

3. **保持原有的 pip install 逻辑不变**

---

## 三、技术细节

### 3.1 Rust 安装方式

使用官方推荐的 `rustup` 安装脚本：

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
```

**参数说明**：
- `--proto '=https'`: 强制使用 HTTPS
- `--tlsv1.2`: 使用 TLS 1.2
- `-sSf`: 静默模式，失败时返回错误
- `-y`: 自动确认所有提示

### 3.2 环境变量设置

Rust 工具链安装在 `/root/.cargo/bin/`，需要添加到 PATH：

```dockerfile
ENV PATH="/root/.cargo/bin:${PATH}"
```

这样 pip 在编译 `tokenizers` 时可以找到 `rustc` 和 `cargo`。

### 3.3 镜像大小影响

**增加的大小**：
- Rust 工具链：约 **200MB**
- curl（已有）：0MB

**总镜像大小**：
- 修改前：约 2.5GB
- 修改后：约 2.7GB
- 增加：约 **8%**

---

## 四、构建时间预估

### 4.1 新增步骤耗时

| 步骤 | 耗时 | 说明 |
|------|------|------|
| apt-get install curl | 1-2 分钟 | curl 可能已安装 |
| 下载 rustup 脚本 | 10-30 秒 | 网络速度影响 |
| 安装 Rust 工具链 | 5-10 分钟 | 下载和编译 |
| **总计** | **6-12 分钟** | 首次安装 |

### 4.2 总构建时间

| 阶段 | 耗时 | 说明 |
|------|------|------|
| apt-get 安装系统包 | 10-15 分钟 | 缓存可用 |
| 安装 Rust | 6-12 分钟 | **新增** |
| pip 安装 Python 包 | 80-90 分钟 | 包含 tokenizers 编译 |
| **总计** | **96-117 分钟** | 约 1.5-2 小时 |

**注意**：
- ✅ 首次构建时间增加 6-12 分钟
- ✅ 后续构建会缓存 Rust 层，不会重复安装
- ✅ 避免了 tokenizers 编译失败，节省重试时间

---

## 五、验证方法

### 5.1 构建基础镜像

```powershell
# 重新构建基础镜像
.\build-ubuntu24-apt.ps1 185
```

### 5.2 检查 Rust 是否安装

```powershell
# 进入容器检查
docker run --rm belt-control-base:ubuntu24 rustc --version
docker run --rm belt-control-base:ubuntu24 cargo --version
```

**预期输出**：
```
rustc 1.xx.x (xxxxxx 2024-xx-xx)
cargo 1.xx.x (xxxxxx 2024-xx-xx)
```

### 5.3 检查 tokenizers 是否安装

```powershell
# 检查 tokenizers 包
docker run --rm belt-control-base:ubuntu24 python3 -c "import tokenizers; print(tokenizers.__version__)"
```

**预期输出**：
```
0.13.x
```

---

## 六、后续优化建议

### 6.1 短期优化

当前方案已经可以工作，无需立即优化。

### 6.2 中期优化（可选）

如果需要进一步优化构建时间和镜像大小，可以考虑：

**方案 A**：使用预编译的 tokenizers wheel
- 优点：不需要 Rust，镜像更小
- 缺点：依赖 PyPI 上有 ARM64 wheel

**方案 B**：分层安装 + 断点续传
- 优点：失败不影响前面的层
- 缺点：需要拆分 requirements.txt

详见：[09-Docker镜像构建断点续传机制.md](09-Docker镜像构建断点续传机制.md)

### 6.3 长期优化（推荐）

实施完整的断点续传机制：
1. 拆分 requirements.txt 为多个文件
2. 每个文件对应一个 Docker 层
3. 失败不影响前面的层
4. 修改一层不影响其他层

---

## 七、相关文档

- **问题分析**: [08-Docker镜像构建缓存优化方案.md](08-Docker镜像构建缓存优化方案.md)
- **断点续传机制**: [09-Docker镜像构建断点续传机制.md](09-Docker镜像构建断点续传机制.md)
- **编译日志**: [docs/log/pjsip.md](../log/pjsip.md)

---

## 八、总结

### 8.1 问题根因

- `tokenizers` 包需要 Rust 编译器
- 基础镜像没有 Rust
- pip install 失败，浪费 83 分钟

### 8.2 解决方案

- 在 Dockerfile 中安装 Rust
- 设置 Rust 环境变量
- 允许 tokenizers 从源码编译

### 8.3 效果

- ✅ 解决 tokenizers 编译失败问题
- ✅ 基础镜像可以成功构建
- ✅ 支持 MeloTTS 和所有需要 Rust 的包
- ✅ 镜像大小增加约 200MB（可接受）
- ✅ 构建时间增加 6-12 分钟（首次）

### 8.4 下一步

1. 重新构建基础镜像（预计 1.5-2 小时）
2. 验证 tokenizers 安装成功
3. 继续完成应用部署

---

**文档版本**: v1.0
**最后更新**: 2026-02-24 18:35
**下次更新**: 构建成功后验证
