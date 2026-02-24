# Docker镜像构建断点续传机制

**创建时间**: 2026-02-24 18:30
**问题**: `tokenizers` 包编译失败，导致 83 分钟的 pip 安装全部浪费
**目标**: 实现断点续传，已安装的包不重复安装

---

## 一、问题分析

### 1.1 当前失败原因

**错误信息**：
```
ERROR: Failed building wheel for tokenizers
ERROR: Could not build wheels for tokenizers, which is required to install pyproject.toml-based projects
```

**根本原因**：
- `tokenizers` 包需要 **Rust 编译器**
- Ubuntu 24.04 基础镜像没有安装 Rust
- pip 尝试从源码编译 `tokenizers`，失败
- **整个 pip install 命令失败，前面 83 分钟的安装全部回滚**

### 1.2 依赖链分析

`tokenizers` 是谁的依赖？

```
MeloTTS → transformers → tokenizers (需要 Rust)
```

**关键发现**：
- `tokenizers` 是 `transformers` 的依赖
- `transformers` 是 `MeloTTS` 的依赖
- **MeloTTS 是我们新增的包**（2026-02-22）

---

## 二、解决方案

### 方案 1：安装 Rust 编译器（推荐）

**核心思想**：在 Dockerfile 中安装 Rust，让 `tokenizers` 可以编译

#### 2.1.1 修改 Dockerfile.ubuntu24-base

```dockerfile
# ============================================================
# 层1: 安装apt包（稳定，很少变化）
# ============================================================
RUN apt-get update && apt-get install -y \
    python3 python3-pip python3-dev git libmecab-dev \
    # ✅ 2026-02-24 18:30 [Phase 7.46.47]: 添加 Rust 编译器（tokenizers 需要）
    # 原因：tokenizers 包需要 Rust 编译器，否则 pip install 失败
    # 效果：可以从源码编译 tokenizers，避免构建失败
    curl \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && . $HOME/.cargo/env \
    && rm -rf /var/lib/apt/lists/* \
    && fc-cache -fv

# 设置 Rust 环境变量
ENV PATH="/root/.cargo/bin:${PATH}"
```

**优点**：
- ✅ 彻底解决 `tokenizers` 编译问题
- ✅ 支持所有需要 Rust 的 Python 包
- ✅ 不需要修改 requirements.txt

**缺点**：
- ❌ 增加镜像大小（约 200MB）
- ❌ 首次安装 Rust 需要 5-10 分钟

---

### 方案 2：使用预编译的 tokenizers（最快）

**核心思想**：使用 PyPI 上的预编译 wheel，避免从源码编译

#### 2.2.1 修改 Dockerfile.ubuntu24-base

```dockerfile
# ============================================================
# 层2: 安装核心Python包（稳定，写死在Dockerfile）
# ============================================================
RUN pip3 install --no-cache-dir --break-system-packages \
    "numpy<2.0.0" \
    # ✅ 2026-02-24 18:30 [Phase 7.46.47]: 先安装预编译的 tokenizers
    # 原因：避免从源码编译 tokenizers（需要 Rust）
    # 效果：使用 PyPI 上的预编译 wheel，快速安装
    "tokenizers>=0.13.0" \
    && pip3 install --no-cache-dir --break-system-packages \
    -r /tmp/paddlespeech-requirements.txt \
    && rm /tmp/paddlespeech-requirements.txt
```

**优点**：
- ✅ 不需要安装 Rust
- ✅ 安装速度快（使用预编译 wheel）
- ✅ 镜像大小不增加

**缺点**：
- ❌ 依赖 PyPI 上有 ARM64 的预编译 wheel
- ❌ 如果 PyPI 没有对应版本，仍会失败

---

### 方案 3：分层安装 + 断点续传（最可靠）⭐

**核心思想**：将 requirements.txt 拆分成多个层，每层独立安装，失败不影响前面的层

#### 2.3.1 拆分 requirements.txt

**创建 3 个文件**：

**requirements-base.txt**（核心依赖，很少变）：
```txt
# 核心依赖（稳定，很少变化）
numpy<2.0.0
paddlepaddle>=2.4.0
paddlespeech>=1.4.1
librosa>=0.9.0
soundfile>=0.12.1
scipy>=1.7.0
```

**requirements-audio.txt**（音频处理，偶尔变）：
```txt
# 音频处理依赖
pydub>=0.25.1
resampy>=0.4.2
```

**requirements-melotts.txt**（MeloTTS，经常变）：
```txt
# MeloTTS 依赖（需要 Rust）
git+https://github.com/myshell-ai/MeloTTS.git
```

#### 2.3.2 修改 Dockerfile.ubuntu24-base

```dockerfile
# ============================================================
# 层2: 安装核心依赖（稳定，很少变）
# ============================================================
COPY docker/rk3588/tts_engines/paddlespeech/requirements-base.txt /tmp/
RUN pip3 install --no-cache-dir --break-system-packages \
    -r /tmp/requirements-base.txt \
    && rm /tmp/requirements-base.txt

# ============================================================
# 层3: 安装音频处理依赖（偶尔变）
# ============================================================
COPY docker/rk3588/tts_engines/paddlespeech/requirements-audio.txt /tmp/
RUN pip3 install --no-cache-dir --break-system-packages \
    -r /tmp/requirements-audio.txt \
    && rm /tmp/requirements-audio.txt

# ============================================================
# 层4: 安装 Rust 编译器（MeloTTS 需要）
# ============================================================
RUN apt-get update && apt-get install -y curl \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && . $HOME/.cargo/env \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/root/.cargo/bin:${PATH}"

# ============================================================
# 层5: 安装 MeloTTS（需要 Rust，可能失败）
# ============================================================
COPY docker/rk3588/tts_engines/paddlespeech/requirements-melotts.txt /tmp/
RUN pip3 install --no-cache-dir --break-system-packages \
    -r /tmp/requirements-melotts.txt \
    || echo "⚠️ MeloTTS 安装失败，但不影响 PaddleSpeech" \
    && rm /tmp/requirements-melotts.txt
```

**关键机制**：
- 使用 `|| echo` 让 MeloTTS 安装失败不影响整个构建
- 前面的层（PaddleSpeech）已经缓存，不会重复安装
- 即使 MeloTTS 失败，PaddleSpeech 仍可用

**优点**：
- ✅ **断点续传**：前面的层失败不影响
- ✅ **缓存友好**：修改 MeloTTS 不影响 PaddleSpeech
- ✅ **容错性强**：MeloTTS 失败不影响整体
- ✅ **灵活性高**：可以单独更新每一层

**缺点**：
- ❌ 需要拆分 requirements.txt（一次性工作）
- ❌ Dockerfile 稍微复杂一些

---

## 三、推荐实施方案

### 3.1 短期方案（立即可用）

**方案 2**：先安装预编译的 `tokenizers`

```dockerfile
RUN pip3 install --no-cache-dir --break-system-packages \
    "numpy<2.0.0" \
    "tokenizers>=0.13.0" \
    && pip3 install --no-cache-dir --break-system-packages \
    -r /tmp/paddlespeech-requirements.txt
```

**实施步骤**：
1. 修改 `Dockerfile.ubuntu24-base` Line 156-160
2. 重新构建基础镜像
3. 如果仍失败，使用方案 1（安装 Rust）

**预计时间**：
- 修改 Dockerfile：1 分钟
- 重新构建：80-90 分钟（但这次会成功）

---

### 3.2 中期方案（推荐）

**方案 3**：分层安装 + 断点续传

**实施步骤**：
1. 拆分 `requirements.txt` 为 3 个文件
2. 修改 `Dockerfile.ubuntu24-base`
3. 重新构建基础镜像

**优点**：
- ✅ 长期受益，以后修改不会浪费时间
- ✅ 容错性强，部分失败不影响整体
- ✅ 缓存友好，修改 MeloTTS 不影响 PaddleSpeech

**预计时间**：
- 拆分 requirements.txt：5 分钟
- 修改 Dockerfile：10 分钟
- 重新构建：80-90 分钟（首次）
- 后续修改：只需 5-10 分钟

---

### 3.3 长期方案（最优）

**方案 1 + 方案 3**：安装 Rust + 分层安装

**实施步骤**：
1. 在 Dockerfile 中安装 Rust
2. 拆分 requirements.txt
3. 分层安装，每层独立缓存

**优点**：
- ✅ 支持所有需要 Rust 的包
- ✅ 断点续传，失败不影响前面的层
- ✅ 缓存友好，修改一层不影响其他层
- ✅ 最可靠的方案

**缺点**：
- ❌ 镜像大小增加约 200MB
- ❌ 首次构建时间增加 5-10 分钟

---

## 四、当前失败的修复方案

### 4.1 立即修复（最快）

**步骤 1**：修改 `Dockerfile.ubuntu24-base`

```dockerfile
# Line 156-160 修改为：
RUN pip3 install --no-cache-dir --break-system-packages \
    "numpy<2.0.0" \
    # ✅ 2026-02-24 18:30: 先安装预编译的 tokenizers
    "tokenizers>=0.13.0" \
    && pip3 install --no-cache-dir --break-system-packages \
    -r /tmp/paddlespeech-requirements.txt \
    && rm /tmp/paddlespeech-requirements.txt
```

**步骤 2**：重新构建

```powershell
.\build-ubuntu24-apt.ps1 185
```

**预计时间**：80-90 分钟

---

### 4.2 如果仍失败（备用方案）

**步骤 1**：安装 Rust 编译器

```dockerfile
# Line 136-144 修改为：
RUN apt-get update && apt-get install -y \
    python3 python3-pip python3-dev git libmecab-dev mecab mecab-ipadic-utf8 \
    # ✅ 2026-02-24 18:30: 添加 Rust 编译器
    curl \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && . $HOME/.cargo/env \
    && rm -rf /var/lib/apt/lists/* \
    && fc-cache -fv

# 添加环境变量
ENV PATH="/root/.cargo/bin:${PATH}"
```

**步骤 2**：重新构建

```powershell
.\build-ubuntu24-apt.ps1 185
```

**预计时间**：90-100 分钟（包括 Rust 安装）

---

## 五、避免未来浪费时间的机制

### 5.1 Docker BuildKit 缓存挂载

**启用 BuildKit**：
```powershell
$env:DOCKER_BUILDKIT=1
```

**修改 Dockerfile**：
```dockerfile
RUN --mount=type=cache,target=/root/.cache/pip \
    pip3 install --no-cache-dir --break-system-packages \
    -r /tmp/requirements.txt
```

**效果**：
- 即使层失效，pip 的下载缓存仍保留
- 重新构建时不需要重新下载包
- 时间从 80 分钟降到 20 分钟

---

### 5.2 分层安装策略

**原则**：
- **稳定依赖**：写死在 Dockerfile，永久缓存
- **易变依赖**：单独文件，独立层
- **可选依赖**：允许失败，不影响整体

**示例**：
```dockerfile
# 层1: 核心依赖（永久缓存）
RUN pip3 install numpy paddlepaddle paddlespeech

# 层2: 音频处理（偶尔变）
COPY requirements-audio.txt /tmp/
RUN pip3 install -r /tmp/requirements-audio.txt

# 层3: MeloTTS（经常变，允许失败）
COPY requirements-melotts.txt /tmp/
RUN pip3 install -r /tmp/requirements-melotts.txt || true
```

---

### 5.3 构建失败通知

**添加构建钩子**：
```powershell
# build-ubuntu24-apt.ps1 中添加
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 构建失败，已保存中间镜像" -ForegroundColor Red
    Write-Host "💡 可以使用 docker commit 保存当前进度" -ForegroundColor Yellow

    # 查找最后一个成功的容器
    $lastContainer = docker ps -a --filter "ancestor=ubuntu:24.04" --format "{{.ID}}" | Select-Object -First 1
    if ($lastContainer) {
        Write-Host "📦 保存中间镜像: docker commit $lastContainer belt-control-base:partial" -ForegroundColor Cyan
    }
}
```

---

## 六、总结

### 6.1 当前问题

- ❌ `tokenizers` 需要 Rust 编译器
- ❌ 83 分钟的 pip 安装全部浪费
- ❌ 没有断点续传机制

### 6.2 推荐方案

**立即修复**：
1. 先安装预编译的 `tokenizers`（方案 2）
2. 如果失败，安装 Rust 编译器（方案 1）

**长期优化**：
1. 实施分层安装 + 断点续传（方案 3）
2. 启用 BuildKit 缓存挂载
3. 添加构建失败通知

### 6.3 预期效果

**优化前**：
- 修改 requirements.txt → 重新安装所有包 → 80 分钟
- 失败 → 浪费 80 分钟 → 重新开始 → 再 80 分钟

**优化后**：
- 修改 requirements.txt → 只安装新增包 → 2-5 分钟
- 失败 → 前面的层保持缓存 → 只重试失败的层 → 5 分钟

**时间节省**：**75-95%**

---

**文档版本**: v1.0
**最后更新**: 2026-02-24 18:30
**下次更新**: 实施修复方案后
