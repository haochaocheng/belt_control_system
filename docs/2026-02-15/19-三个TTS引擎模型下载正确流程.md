# 三个TTS引擎模型下载正确流程

**创建时间**: 2026-02-15 16:35
**重要**: 原始16、18、19脚本有问题，请使用本文档的方案
**问题**: 网络超时（与PaddleSpeech相同）
**解决方案**: 使用缓存Docker镜像

---

## ⚠️ 重要提示

**原始脚本的问题**：
- ❌ `16-download-melotts-models.ps1` - 每次都要安装PyTorch（500 MB），会超时
- ❌ `18-download-coqui-models.ps1` - 每次都要安装PyTorch（500 MB），会超时
- ❌ `19-download-all-tts-models.ps1` - 调用了有问题的脚本
- ✅ `17-download-piper-models.ps1` - 无问题，可以使用

**正确的方案**：
- 使用缓存Docker镜像（与PaddleSpeech的13脚本相同）
- 一次构建，多次使用
- 避免重复安装依赖

---

## 🚀 推荐流程

### 方案A：只下载Piper TTS（最简单）⭐⭐⭐

**如果您只需要一个额外的TTS引擎**，推荐使用Piper TTS：

```powershell
.\scripts\2026-02-15\17-download-piper-models.ps1
```

**优势**：
- ✅ 最快（5-10分钟）
- ✅ 无需Docker
- ✅ 无网络超时风险
- ✅ 模型最小（10-50 MB）
- ✅ C++实现，易于集成

**劣势**：
- ⚠️ 中文语音质量一般（不如MeloTTS和PaddleSpeech）

**适用场景**：
- 需要快速部署
- 对语音质量要求不高
- 资源受限环境

---

### 方案B：手动下载MeloTTS和Coqui TTS模型

**如果您需要MeloTTS或Coqui TTS**，建议手动下载：

#### MeloTTS手动下载

```powershell
# 1. 创建目录
New-Item -ItemType Directory -Path "E:\2025\3_gongkongji\belt_control_system\tts_models\melotts" -Force

# 2. 使用git clone下载
cd E:\2025\3_gongkongji\belt_control_system\tts_models\melotts
git clone https://huggingface.co/myshell-ai/MeloTTS

# 或使用huggingface-cli
pip install huggingface-cli
huggingface-cli download myshell-ai/MeloTTS --local-dir ./MeloTTS
```

#### Coqui TTS手动下载

```powershell
# 1. 安装Coqui TTS（本地）
pip install TTS

# 2. 下载模型（首次运行会自动下载）
tts --model_name tts_models/zh-CN/baker/tacotron2-DDC-GST --text "测试" --out_path test.wav

# 3. 模型会保存在：
# Windows: C:\Users\<用户名>\.local\share\tts\
# 复制到项目目录
Copy-Item -Recurse "C:\Users\54999\.local\share\tts\*" "E:\2025\3_gongkongji\belt_control_system\tts_models\coqui\"
```

---

### 方案C：等待新的缓存镜像脚本

**如果您需要自动化下载**，需要等待新脚本：

**需要创建的脚本**：
1. `20-build-melotts-image.ps1` - 构建MeloTTS Docker镜像
2. `21-download-melotts-with-cache.ps1` - 使用镜像下载MeloTTS模型
3. `22-build-coqui-image.ps1` - 构建Coqui TTS Docker镜像
4. `23-download-coqui-with-cache.ps1` - 使用镜像下载Coqui TTS模型
5. `24-download-all-tts-models-v2.ps1` - 统一下载脚本（新版本）

**预计时间**：创建脚本需要30-60分钟

---

## 📊 三种方案对比

| 方案 | 优势 | 劣势 | 适用场景 |
|------|------|------|---------|
| **A: 只用Piper TTS** | ✅ 最快<br>✅ 无风险<br>✅ 无需Docker | ⚠️ 质量一般 | 快速部署<br>资源受限 |
| **B: 手动下载** | ✅ 可控<br>✅ 无超时风险 | ⚠️ 需要手动操作<br>⚠️ 需要本地安装Python | 一次性下载<br>不需要自动化 |
| **C: 缓存镜像脚本** | ✅ 自动化<br>✅ 可重复使用<br>✅ 无超时风险 | ⚠️ 需要等待脚本创建<br>⚠️ 需要Docker | 需要自动化<br>多次使用 |

---

## 💡 我的建议

### 立即可用的方案

1. **下载Piper TTS**（5-10分钟）
   ```powershell
   .\scripts\2026-02-15\17-download-piper-models.ps1
   ```

2. **手动下载MeloTTS**（如果需要更好的质量）
   ```powershell
   cd E:\2025\3_gongkongji\belt_control_system\tts_models
   git clone https://huggingface.co/myshell-ai/MeloTTS melotts
   ```

### 长期方案

等待创建缓存镜像脚本（20-24脚本），实现自动化下载。

---

## 🔍 为什么原始脚本有问题

### 问题根源

**原始脚本每次都要安装PyTorch**：
```bash
# ❌ 这会导致超时
pip install torch torchaudio --index-url https://download.pytorch.org/whl/cpu -q
```

**PyTorch很大**：
- CPU版本：约500 MB
- 下载时间：5-10分钟（网络好的情况下）
- 网络不稳定：超时失败

### PaddleSpeech的教训

**12-export脚本**（原始版本）：
- ❌ 每次都要安装PaddleSpeech
- ❌ 网络超时失败

**13-export脚本**（缓存镜像版本）：
- ✅ 一次构建镜像
- ✅ 后续直接使用
- ✅ 避免超时

**同样的问题，同样的解决方案**。

---

## ✅ 总结

### 当前可用的方案

1. **Piper TTS**：直接使用17脚本 ✅
2. **MeloTTS**：手动下载或等待新脚本
3. **Coqui TTS**：手动下载或等待新脚本

### 推荐行动

1. **立即下载Piper TTS**（最快，无风险）
2. **决定是否需要MeloTTS/Coqui TTS**
3. **如果需要，选择手动下载或等待新脚本**

### 下一步

如果您需要自动化下载MeloTTS和Coqui TTS，我可以创建20-24这5个新脚本。

---

**相关文档**:
- [18-三个TTS引擎模型下载方案更正.md](./18-三个TTS引擎模型下载方案更正.md) - 问题分析
- [14-PaddleSpeech模型导出最终解决方案.md](./14-PaddleSpeech模型导出最终解决方案.md) - 缓存镜像方案参考
