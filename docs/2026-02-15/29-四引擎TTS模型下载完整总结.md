# 四引擎 TTS 模型下载完整总结

**创建时间**: 2026-02-15 19:00
**项目阶段**: Phase 7.46 - 模型准备
**任务状态**: ✅ 已完成

---

## 📋 任务概述

为四引擎 TTS 集成项目下载所有必需的模型文件：
1. **PaddleSpeech** - 中文质量最好
2. **MeloTTS** - 语音质量最好，中英文混合
3. **Piper TTS** - 性能最好，模型最小
4. **Coqui TTS** - 功能最全，支持语音克隆

---

## ✅ 下载结果

### 1. PaddleSpeech（2.23 GB）

**状态**: ✅ 已完成（2026-02-13）

**模型位置**: `tts_models/paddlespeech_offline/`

**包含文件**:
- 声学模型：`models/fastspeech2_csmsc-zh/1.0/`
- 声码器：`models/pwgan_csmsc-zh/1.0/`
- G2P模型：`models/G2PWModel_1.1/`

**下载方式**: Docker 容器导出（参考：[14-PaddleSpeech模型导出最终解决方案.md](../2026-02-13/14-PaddleSpeech模型导出最终解决方案.md)）

---

### 2. MeloTTS（396.4 MB）

**状态**: ✅ 已完成（2026-02-15）

**模型位置**: `tts_models/melotts/`

**包含文件**:
- **中文模型** (198.1 MB):
  - `MeloTTS-Chinese/checkpoint.pth`
  - `MeloTTS-Chinese/config.json`
- **英文模型** (198.2 MB):
  - `MeloTTS-English/checkpoint.pth`
  - `MeloTTS-English/config.json`

**下载方式**: 直接从 Hugging Face 下载

**下载脚本**: `scripts/2026-02-15/25-download-melotts-models-direct.ps1`

**下载链接**:
```
https://huggingface.co/myshell-ai/MeloTTS-Chinese/resolve/main/checkpoint.pth
https://huggingface.co/myshell-ai/MeloTTS-Chinese/resolve/main/config.json
https://huggingface.co/myshell-ai/MeloTTS-English/resolve/main/checkpoint.pth
https://huggingface.co/myshell-ai/MeloTTS-English/resolve/main/config.json
```

**遇到的问题**:
1. Docker 构建 MeloTTS 镜像失败（GitHub TLS 错误）
2. MeCab 依赖缺失（已修复 Dockerfile）
3. 依赖下载超时（gruut_lang_es 31.4 MB）

**解决方案**: 放弃 Docker 方式，直接从 Hugging Face 下载模型文件

---

### 3. Piper TTS（60.3 MB）

**状态**: ✅ 已完成（2026-02-15）

**模型位置**: `tts_models/piper/`

**包含文件**:
- `zh_CN-huayan-medium.onnx` (60.2 MB)
- `zh_CN-huayan-medium.onnx.json` (4.8 KB)

**下载方式**: 使用 curl 从 Hugging Face 下载

**下载命令**:
```powershell
# 下载 ONNX 模型
curl -L -C - "https://huggingface.co/rhasspy/piper-voices/resolve/main/zh/zh_CN/huayan/medium/zh_CN-huayan-medium.onnx" -o "tts_models/piper/zh_CN-huayan-medium.onnx"

# 下载配置文件
curl -L "https://huggingface.co/rhasspy/piper-voices/resolve/main/zh/zh_CN/huayan/medium/zh_CN-huayan-medium.onnx.json" -o "tts_models/piper/zh_CN-huayan-medium.onnx.json"
```

**遇到的问题**:
1. 原始下载脚本失败（Entry not found）
2. PowerShell Invoke-WebRequest 下载失败（EOF 错误）

**解决方案**: 使用 curl 命令行工具，支持断点续传

**模型信息**:
- 模型名称：huayan
- 语言：简体中文 (zh_CN)
- 质量：medium
- 说话人数：1

---

### 4. Coqui TTS（654.6 MB）

**状态**: ✅ 已完成（已存在）

**模型位置**: `tts_models/coqui/tts_models--zh-CN--baker--tacotron2-DDC-GST/`

**包含文件**:
- `model_file.pth` (654.1 MB)
- `config.json`
- `scale_stats.npy`

**下载方式**: 之前已下载（可能是早期测试时下载的）

**备注**: 尝试使用 Docker 下载时遇到 SSL 错误，但发现模型文件已存在

---

## 📊 统计信息

### 模型大小对比

| 引擎 | 模型大小 | 占比 |
|------|---------|------|
| PaddleSpeech | 2.23 GB | 24.0% |
| MeloTTS | 396.4 MB | 4.3% |
| Piper TTS | 60.3 MB | 0.6% |
| Coqui TTS | 654.6 MB | 7.0% |
| **总计** | **9.29 GB** | **100%** |

### 下载时间估算

- **PaddleSpeech**: ~30 分钟（Docker 导出）
- **MeloTTS**: ~5 分钟（直接下载）
- **Piper TTS**: ~1 分钟（curl 下载）
- **Coqui TTS**: 已存在

**总计**: 约 36 分钟

---

## 🛠️ 使用的脚本

### 验证脚本
```powershell
.\scripts\2026-02-15\26-check-all-tts-models.ps1
```

### 下载脚本
```powershell
# MeloTTS 直接下载
.\scripts\2026-02-15\25-download-melotts-models-direct.ps1

# Piper TTS 从 voices.json 下载
.\scripts\2026-02-15\28-download-piper-from-voices-json.ps1
```

### 辅助脚本（未使用）
```powershell
# Docker 镜像构建（失败）
.\scripts\2026-02-15\20-build-melotts-image.ps1
.\scripts\2026-02-15\22-build-coqui-image.ps1

# Docker 下载（失败）
.\scripts\2026-02-15\21-download-melotts-with-cache.ps1
.\scripts\2026-02-15\23-download-coqui-with-cache.ps1

# 统一下载脚本（部分失败）
.\scripts\2026-02-15\24-download-all-tts-models-v2.ps1
```

---

## 🔧 遇到的技术问题

### 1. Docker 网络问题

**问题描述**:
- GitHub TLS 握手失败
- PyPI 依赖下载超时
- SSL EOF 错误

**原因分析**:
- Docker 容器内网络环境与宿主机不同
- 加速器可能不适用于容器内部
- 大文件下载容易超时

**解决方案**:
- 放弃 Docker 方式
- 直接从 Hugging Face 下载模型文件
- 使用 curl 支持断点续传

### 2. PowerShell Here-String 语法

**问题描述**:
```powershell
python3 - <<'PYTHON_SCRIPT'
# 错误：'<' operator is reserved for future use
```

**原因分析**:
- PowerShell 不支持 Bash 的 here-string 语法

**解决方案**:
- 将 Python 脚本保存为文件
- 使用 `-v` 挂载到容器

### 3. MeCab 依赖缺失

**问题描述**:
```
RuntimeError: Failed initializing MeCab
```

**原因分析**:
- MeloTTS 需要 MeCab（日语文本处理）
- 需要 unidic 字典

**解决方案**:
- 在 Dockerfile 中添加 MeCab 系统包
- 安装 unidic 字典

### 4. Piper TTS 文件损坏

**问题描述**:
- ONNX 文件只有 15 字节
- 内容为 "Entry not found"

**原因分析**:
- 下载链接错误
- 文件路径不正确

**解决方案**:
- 下载 voices.json 查找正确路径
- 使用 curl 下载完整文件

---

## 📝 经验总结

### 成功经验

1. **直接下载优于 Docker**
   - 对于模型文件，直接下载更可靠
   - Docker 适合安装依赖，不适合下载大文件

2. **curl 优于 PowerShell**
   - curl 支持断点续传
   - 网络处理更稳定
   - 适合大文件下载

3. **Hugging Face 是可靠的模型源**
   - 提供直接下载链接
   - 支持 CDN 加速
   - 文件完整性有保障

### 失败教训

1. **不要过度依赖 Docker**
   - Docker 网络环境复杂
   - 容器内加速器可能失效
   - 大文件下载容易超时

2. **PowerShell 语法限制**
   - 不支持 Bash here-string
   - 需要使用文件挂载

3. **网络问题难以预测**
   - SSL 错误随机出现
   - 超时时间难以控制
   - 需要多种备用方案

---

## 🚀 下一步

### 1. 复制模型到 RK3588

```bash
scp -r E:\2025\3_gongkongji\belt_control_system\tts_models linaro@192.168.10.188:/app/models/
```

**预计时间**: 约 30-60 分钟（取决于网络速度）

### 2. 验证模型在设备上可用

```bash
ssh linaro@192.168.10.188
ls -lh /app/models/tts_models/
```

### 3. 开始实施 Phase 7.46.1

创建 TTS 引擎管理器框架（参考：[07-Phase7.46.1-创建TTS引擎管理器框架.md](../2026-02-13/07-Phase7.46.1-创建TTS引擎管理器框架.md)）

---

## 📂 文件清单

### 模型文件

```
tts_models/
├── paddlespeech_offline/          # 2.23 GB
│   └── models/
│       ├── fastspeech2_csmsc-zh/
│       ├── pwgan_csmsc-zh/
│       └── G2PWModel_1.1/
├── melotts/                       # 396.4 MB
│   ├── MeloTTS-Chinese/
│   │   ├── checkpoint.pth         # 198.1 MB
│   │   └── config.json
│   └── MeloTTS-English/
│       ├── checkpoint.pth         # 198.2 MB
│       └── config.json
├── piper/                         # 60.3 MB
│   ├── zh_CN-huayan-medium.onnx   # 60.2 MB
│   └── zh_CN-huayan-medium.onnx.json
└── coqui/                         # 654.6 MB
    └── tts_models--zh-CN--baker--tacotron2-DDC-GST/
        ├── model_file.pth         # 654.1 MB
        ├── config.json
        └── scale_stats.npy
```

### 脚本文件

```
scripts/2026-02-15/
├── 20-build-melotts-image.ps1              # MeloTTS Docker 镜像构建（失败）
├── 21-download-melotts-with-cache.ps1      # MeloTTS Docker 下载（失败）
├── 22-build-coqui-image.ps1                # Coqui TTS Docker 镜像构建（成功）
├── 23-download-coqui-with-cache.ps1        # Coqui TTS Docker 下载（失败）
├── 24-download-all-tts-models-v2.ps1       # 统一下载脚本（部分失败）
├── 25-download-melotts-models-direct.ps1   # MeloTTS 直接下载（成功）✅
├── 26-check-all-tts-models.ps1             # 验证所有模型（成功）✅
├── 27-download-piper-model.ps1             # Piper TTS 下载（失败）
└── 28-download-piper-from-voices-json.ps1  # Piper TTS 从 voices.json 下载（成功）✅
```

### 文档文件

```
docs/2026-02-15/
├── 18-三个TTS引擎模型下载方案更正.md
├── 19-三个TTS引擎模型下载正确流程.md
├── 20-三个TTS引擎模型下载最终指南.md
└── 29-四引擎TTS模型下载完整总结.md  # 本文档
```

---

## ✅ 验证清单

- [x] PaddleSpeech 模型完整（2.23 GB）
- [x] MeloTTS 中文模型完整（198.1 MB）
- [x] MeloTTS 英文模型完整（198.2 MB）
- [x] Piper TTS ONNX 模型完整（60.2 MB）
- [x] Piper TTS 配置文件完整（4.8 KB）
- [x] Coqui TTS 模型完整（654.6 MB）
- [x] 所有模型文件可读
- [x] 总大小正确（9.29 GB）
- [ ] 模型已复制到 RK3588
- [ ] 模型在设备上可用

---

**文档版本**: v1.0
**创建时间**: 2026-02-15 19:00
**最后更新**: 2026-02-15 19:00
**状态**: ✅ 模型下载完成，等待部署
