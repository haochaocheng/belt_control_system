# Docker 离线安装依赖包方案

**创建时间**: 2026-02-24 19:30
**目的**: 预下载所有 Python 依赖包，避免构建时从网络下载
**效果**: 构建时间从 70-85 分钟降到 20-30 分钟

---

## 一、方案概述

### 1.1 核心思想

```
本地（Windows）                Docker 构建
    ↓                              ↓
下载所有 wheel 包    →    复制到镜像    →    离线安装
（一次性，10-20分钟）      （几秒）         （20-30分钟）
```

### 1.2 优势

| 对比项 | 在线安装 | 离线安装 |
|-------|---------|---------|
| **下载时间** | 20-25 分钟 | 0 分钟（已下载） |
| **编译时间** | 40-60 分钟 | 20-30 分钟 |
| **总时间** | 60-85 分钟 | **20-30 分钟** |
| **网络依赖** | 必须联网 | 不需要联网 |
| **可重复性** | 依赖网络 | 完全可控 |

---

## 二、实施步骤

### 步骤 1：在本地下载所有依赖包

**在 Windows PowerShell 中执行**：

```powershell
# 创建下载目录
mkdir -p docker/rk3588/pip-packages

# 下载所有依赖包（ARM64 架构）
python -m pip download `
    -r docker/rk3588/tts_engines/paddlespeech/requirements.txt `
    -d docker/rk3588/pip-packages `
    --platform manylinux2014_aarch64 `
    --python-version 312 `
    --only-binary=:all:
```

**参数说明**：
- `-r requirements.txt`: 从文件读取依赖列表
- `-d docker/rk3588/pip-packages`: 下载到指定目录
- `--platform manylinux2014_aarch64`: 指定 ARM64 架构
- `--python-version 312`: 指定 Python 3.12
- `--only-binary=:all:`: 只下载预编译的 wheel，不下载源码包

**预期输出**：
```
Collecting paddlepaddle>=2.4.0
  Downloading paddlepaddle-2.6.0-cp312-cp312-manylinux_2_17_aarch64.whl (200 MB)
Collecting paddlespeech>=1.4.1
  Downloading paddlespeech-1.4.1-py3-none-any.whl (5 MB)
...
Successfully downloaded 50 packages
```

**耗时**：10-20 分钟（取决于网络速度）

---

### 步骤 2：修改 Dockerfile 使用离线包

**修改 `Dockerfile.ubuntu24-base`**：

```dockerfile
# ✅ 2026-02-24 19:30 [Phase 7.46.51]: 使用离线安装
# 原因：避免构建时从网络下载，节省 20-25 分钟
# 效果：构建时间从 70-85 分钟降到 20-30 分钟
# 方案：预下载所有 wheel 包，离线安装

# 设置 Rust 环境变量（提前设置）
ENV PATH="/root/.cargo/bin:${PATH}"

# 复制预下载的 wheel 包
COPY docker/rk3588/pip-packages /tmp/pip-packages

# 离线安装依赖
RUN apt-get update && apt-get install -y curl \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && . $HOME/.cargo/env \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 install --no-cache-dir --break-system-packages "numpy<2.0.0" \
    && pip3 install --no-cache-dir --break-system-packages \
        --no-index \
        --find-links=/tmp/pip-packages \
        -r /tmp/pip-packages/requirements.txt \
    && rm -rf /tmp/pip-packages
```

**关键参数**：
- `--no-index`: 不使用 PyPI 索引
- `--find-links=/tmp/pip-packages`: 从本地目录查找包

---

### 步骤 3：重新构建镜像

```powershell
.\build-ubuntu24-apt.ps1 185
```

**预期效果**：
- ✅ 不需要从网络下载包
- ✅ 直接从本地安装
- ✅ 构建时间：20-30 分钟

---

## 三、处理需要编译的包

### 3.1 问题

有些包没有 ARM64 的预编译 wheel，必须从源码编译：
- `tokenizers`（需要 Rust）
- `pyworld`
- 其他 C/C++ 扩展

### 3.2 解决方案 A：混合安装（推荐）

```powershell
# 下载时允许源码包
python -m pip download `
    -r docker/rk3588/tts_engines/paddlespeech/requirements.txt `
    -d docker/rk3588/pip-packages `
    --platform manylinux2014_aarch64 `
    --python-version 312
    # 去掉 --only-binary=:all:
```

**Dockerfile 修改**：
```dockerfile
# 离线安装（包含源码包）
RUN apt-get update && apt-get install -y curl \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && . $HOME/.cargo/env \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 install --no-cache-dir --break-system-packages "numpy<2.0.0" \
    && pip3 install --no-cache-dir --break-system-packages \
        --no-index \
        --find-links=/tmp/pip-packages \
        -r /tmp/pip-packages/requirements.txt
```

**效果**：
- ✅ 不需要下载（源码包已在本地）
- ⚠️ 仍需编译（20-30 分钟）
- ✅ 总时间：20-30 分钟

### 3.3 解决方案 B：预编译 wheel（最优）

**在本地编译 ARM64 wheel**（需要 ARM64 环境）：

```bash
# 在 ARM64 设备上（如 RK3588）
pip3 wheel -r requirements.txt -w /tmp/wheels
```

然后复制到 Windows：
```powershell
scp linaro@192.168.10.185:/tmp/wheels/* docker/rk3588/pip-packages/
```

**效果**：
- ✅ 不需要下载
- ✅ 不需要编译
- ✅ 总时间：5-10 分钟

---

## 四、完整实施方案

### 4.1 方案 A：简单离线安装（推荐）

**步骤**：
1. 下载所有包（包括源码包）
2. 修改 Dockerfile 使用离线安装
3. 构建时从本地安装

**耗时**：
- 下载：10-20 分钟（一次性）
- 构建：20-30 分钟

**总节省时间**：40-55 分钟

### 4.2 方案 B：完全离线安装（最优）

**步骤**：
1. 在 ARM64 设备上预编译所有 wheel
2. 复制到 Windows
3. 修改 Dockerfile 使用离线安装
4. 构建时直接安装预编译 wheel

**耗时**：
- 预编译：30-40 分钟（一次性，在设备上）
- 构建：5-10 分钟

**总节省时间**：60-75 分钟

---

## 五、目录结构

```
belt_control_system/
├── docker/
│   └── rk3588/
│       ├── pip-packages/          # 新增：预下载的包
│       │   ├── paddlepaddle-2.6.0-...whl
│       │   ├── paddlespeech-1.4.1-...whl
│       │   ├── tokenizers-0.13.0.tar.gz  # 源码包
│       │   └── ...（50+ 个包）
│       └── tts_engines/
│           └── paddlespeech/
│               └── requirements.txt
└── Dockerfile.ubuntu24-base
```

---

## 六、注意事项

### 6.1 .gitignore

**添加到 `.gitignore`**：
```
docker/rk3588/pip-packages/
```

**原因**：
- wheel 包很大（500+ MB）
- 不应该提交到 Git
- 每个开发者自己下载

### 6.2 更新依赖

**当 `requirements.txt` 变化时**：
```powershell
# 重新下载
rm -rf docker/rk3588/pip-packages
python -m pip download -r docker/rk3588/tts_engines/paddlespeech/requirements.txt -d docker/rk3588/pip-packages
```

### 6.3 缓存键

**修改 `build-ubuntu24-apt.ps1`**，将 `pip-packages` 目录纳入缓存键：

```powershell
# 计算联合哈希：Dockerfile + requirements.txt + pip-packages
$dockerfileHash = (Get-FileHash -Path $baseDockerfilePath -Algorithm MD5).Hash
$requirementsHash = (Get-FileHash -Path $requirementsPath -Algorithm MD5).Hash
$packagesHash = (Get-ChildItem docker/rk3588/pip-packages -File |
    Get-FileHash -Algorithm MD5 |
    Select-Object -ExpandProperty Hash |
    Measure-Object -Sum).Sum
$currentBaseHash = "$dockerfileHash-$requirementsHash-$packagesHash"
```

---

## 七、实施建议

### 7.1 立即可用（方案 A）

1. **下载所有包**（10-20 分钟）：
   ```powershell
   mkdir docker/rk3588/pip-packages
   python -m pip download -r docker/rk3588/tts_engines/paddlespeech/requirements.txt -d docker/rk3588/pip-packages
   ```

2. **修改 Dockerfile**（见步骤 2）

3. **重新构建**：
   ```powershell
   .\build-ubuntu24-apt.ps1 185
   ```

**效果**：构建时间从 70-85 分钟降到 **20-30 分钟**

### 7.2 长期优化（方案 B）

1. 在设备上预编译所有 wheel
2. 复制到 Windows
3. 构建时直接安装

**效果**：构建时间降到 **5-10 分钟**

---

## 八、对比总结

| 方案 | 下载时间 | 编译时间 | 总时间 | 复杂度 |
|------|---------|---------|--------|--------|
| **在线安装** | 20-25 分钟 | 40-60 分钟 | 60-85 分钟 | 简单 |
| **离线安装（A）** | 0 分钟 | 20-30 分钟 | 20-30 分钟 | 中等 |
| **完全离线（B）** | 0 分钟 | 0 分钟 | 5-10 分钟 | 复杂 |

**推荐**：先实施方案 A，节省 40-55 分钟，后续有需要再优化到方案 B。

---

**文档版本**: v1.0
**最后更新**: 2026-02-24 19:30
**下次更新**: 实施后验证效果
