# 三个TTS引擎模型下载方案更正

**创建时间**: 2026-02-15 16:30
**问题**: 原始下载脚本会遇到与PaddleSpeech相同的网络超时问题
**解决方案**: 使用缓存Docker镜像

---

## 🔍 问题分析

### 原始方案的问题

**16-download-melotts-models.ps1**（MeloTTS）:
```bash
# ❌ 每次都要安装（会超时）
pip install torch torchaudio --index-url https://download.pytorch.org/whl/cpu -q
pip install numpy scipy librosa -q
pip install git+https://github.com/myshell-ai/MeloTTS.git -q
```

**18-download-coqui-models.ps1**（Coqui TTS）:
```bash
# ❌ 每次都要安装（会超时）
pip install torch torchaudio --index-url https://download.pytorch.org/whl/cpu -q
pip install TTS -q
```

**问题**：
- PyTorch很大（约500 MB）
- 每次运行都要重新安装
- 网络不稳定会超时
- 与PaddleSpeech遇到的问题完全相同

---

## ✅ 正确的解决方案

### 方案1：使用缓存Docker镜像（推荐）⭐

**原理**：
```
第一次运行：构建Docker镜像（包含所有依赖）
  ↓
后续运行：直接使用镜像下载模型
```

**优势**：
- ✅ 一次构建，多次使用
- ✅ 避免重复安装依赖
- ✅ 避免网络超时
- ✅ 节省时间

### 方案2：使用Piper TTS（无需Docker）

**Piper TTS不需要Python依赖**：
```powershell
# ✅ 直接下载ONNX模型
curl -L -o zh_CN-huayan-medium.onnx https://...
```

**优势**：
- ✅ 最快（5-10分钟）
- ✅ 无需Docker
- ✅ 无网络超时风险

---

## 🚀 推荐的下载顺序

### 第一步：下载Piper TTS（最快）⭐

```powershell
.\scripts\2026-02-15\17-download-piper-models.ps1
```

**理由**：
- 最快（5-10分钟）
- 无需Docker
- 成功率最高

### 第二步：构建MeloTTS Docker镜像

**需要创建新脚本**：`20-build-melotts-image.ps1`

```dockerfile
FROM python:3.11-slim

# 安装系统依赖
RUN apt-get update -qq && \
    apt-get install -y git build-essential -qq && \
    rm -rf /var/lib/apt/lists/*

# 安装Python依赖
RUN pip install --no-cache-dir \
    torch torchaudio --index-url https://download.pytorch.org/whl/cpu && \
    pip install --no-cache-dir numpy scipy librosa && \
    pip install --no-cache-dir git+https://github.com/myshell-ai/MeloTTS.git

WORKDIR /app
CMD ["/bin/bash"]
```

### 第三步：使用镜像下载MeloTTS模型

**需要创建新脚本**：`21-download-melotts-with-cache.ps1`

```powershell
# 检查镜像是否存在
$imageExists = docker images -q melotts-downloader:latest

if (-not $imageExists) {
    Write-Host "  ⚠️  未找到镜像，请先运行: 20-build-melotts-image.ps1"
    exit 1
}

# 使用镜像下载模型
docker run --rm -v "${ModelsDir}:/output" melotts-downloader:latest python3 download.py
```

### 第四步：构建Coqui TTS Docker镜像

**需要创建新脚本**：`22-build-coqui-image.ps1`

```dockerfile
FROM python:3.11-slim

# 安装系统依赖
RUN apt-get update -qq && \
    apt-get install -y git build-essential libsndfile1 -qq && \
    rm -rf /var/lib/apt/lists/*

# 安装Python依赖
RUN pip install --no-cache-dir \
    torch torchaudio --index-url https://download.pytorch.org/whl/cpu && \
    pip install --no-cache-dir TTS

WORKDIR /app
CMD ["/bin/bash"]
```

### 第五步：使用镜像下载Coqui TTS模型

**需要创建新脚本**：`23-download-coqui-with-cache.ps1`

---

## 📋 需要创建的新脚本

### 1. 20-build-melotts-image.ps1
- 构建MeloTTS Docker镜像
- 包含所有依赖
- 一次性操作

### 2. 21-download-melotts-with-cache.ps1
- 使用缓存镜像下载MeloTTS模型
- 快速（2-3分钟）
- 避免重复安装

### 3. 22-build-coqui-image.ps1
- 构建Coqui TTS Docker镜像
- 包含所有依赖
- 一次性操作

### 4. 23-download-coqui-with-cache.ps1
- 使用缓存镜像下载Coqui TTS模型
- 快速（2-3分钟）
- 避免重复安装

### 5. 24-download-all-tts-models-v2.ps1
- 统一下载脚本（新版本）
- 使用缓存镜像
- 自动检查镜像是否存在

---

## ⚠️ 原始脚本的问题

### 16-download-melotts-models.ps1
- ❌ 每次都要安装PyTorch（500 MB）
- ❌ 网络超时风险高
- ❌ 浪费时间
- **建议**：废弃，使用新的缓存镜像方案

### 18-download-coqui-models.ps1
- ❌ 每次都要安装PyTorch（500 MB）
- ❌ 网络超时风险高
- ❌ 浪费时间
- **建议**：废弃，使用新的缓存镜像方案

### 17-download-piper-models.ps1
- ✅ 无问题，可以继续使用
- ✅ 直接下载ONNX模型
- ✅ 无需Docker

### 19-download-all-tts-models.ps1
- ❌ 调用了有问题的脚本
- **建议**：废弃，创建新版本

---

## 💡 最佳实践

### 第一次使用（构建镜像）

```powershell
# 1. 构建MeloTTS镜像（5-10分钟，一次性）
.\scripts\2026-02-15\20-build-melotts-image.ps1

# 2. 构建Coqui TTS镜像（5-10分钟，一次性）
.\scripts\2026-02-15\22-build-coqui-image.ps1
```

### 后续使用（下载模型）

```powershell
# 使用统一脚本（推荐）
.\scripts\2026-02-15\24-download-all-tts-models-v2.ps1

# 或分别下载
.\scripts\2026-02-15\17-download-piper-models.ps1      # Piper TTS（5-10分钟）
.\scripts\2026-02-15\21-download-melotts-with-cache.ps1  # MeloTTS（2-3分钟）
.\scripts\2026-02-15\23-download-coqui-with-cache.ps1    # Coqui TTS（2-3分钟）
```

---

## 📊 时间对比

### 原始方案（有问题）

| 引擎 | 第一次 | 第二次 | 问题 |
|------|--------|--------|------|
| MeloTTS | 15-20分钟 | 15-20分钟 | ❌ 每次都要安装PyTorch |
| Piper TTS | 5-10分钟 | 5-10分钟 | ✅ 无问题 |
| Coqui TTS | 20-30分钟 | 20-30分钟 | ❌ 每次都要安装PyTorch |
| **总计** | **40-60分钟** | **40-60分钟** | ❌ 浪费时间 |

### 缓存镜像方案（推荐）

| 引擎 | 第一次（构建镜像） | 第二次（使用镜像） | 优势 |
|------|-------------------|-------------------|------|
| MeloTTS | 10-15分钟 | 2-3分钟 | ✅ 快速 |
| Piper TTS | 5-10分钟 | 5-10分钟 | ✅ 无问题 |
| Coqui TTS | 15-20分钟 | 2-3分钟 | ✅ 快速 |
| **总计** | **30-45分钟** | **9-16分钟** | ✅ 节省时间 |

---

## ✅ 总结

### 问题

原始的16、18、19脚本会遇到与PaddleSpeech相同的网络超时问题。

### 解决方案

1. **Piper TTS**：继续使用17脚本（无问题）
2. **MeloTTS**：创建缓存镜像方案（20、21脚本）
3. **Coqui TTS**：创建缓存镜像方案（22、23脚本）
4. **统一下载**：创建新版本（24脚本）

### 下一步

需要创建5个新脚本来替代原有的有问题的脚本。

---

**相关文档**:
- [14-PaddleSpeech模型导出最终解决方案.md](./14-PaddleSpeech模型导出最终解决方案.md) - PaddleSpeech的缓存镜像方案
- [17-三个TTS引擎模型下载指南.md](./17-三个TTS引擎模型下载指南.md) - 原始下载指南（需要更新）
