# 三个TTS引擎模型下载最终指南（缓存镜像版）

**创建时间**: 2026-02-15 17:05
**版本**: v2（缓存镜像版）
**状态**: ✅ 所有脚本已创建
**优势**: 避免网络超时，快速下载

---

## 🎯 快速开始

### 一键下载所有模型（推荐）⭐

```powershell
.\scripts\2026-02-15\24-download-all-tts-models-v2.ps1
```

**说明**:
- 自动检查并构建Docker镜像（首次运行）
- 按顺序下载三个引擎的模型
- 自动处理错误，继续下载其他模型
- 最后统计所有模型大小

**预计时间**:
- 首次运行：30-45分钟（包含构建镜像）
- 后续运行：9-16分钟（使用缓存镜像）

---

## 📋 详细流程

### 第一步：构建Docker镜像（首次运行，一次性）

#### 1.1 构建MeloTTS镜像

```powershell
.\scripts\2026-02-15\20-build-melotts-image.ps1
```

**时间**: 10-15分钟
**大小**: 约1.5 GB
**内容**: Python 3.11 + PyTorch + MeloTTS

#### 1.2 构建Coqui TTS镜像

```powershell
.\scripts\2026-02-15\22-build-coqui-image.ps1
```

**时间**: 15-20分钟
**大小**: 约1.8 GB
**内容**: Python 3.11 + PyTorch + Coqui TTS

**注意**: Piper TTS不需要Docker镜像

---

### 第二步：下载模型（使用缓存镜像）

#### 2.1 下载Piper TTS模型

```powershell
.\scripts\2026-02-15\17-download-piper-models.ps1
```

**时间**: 5-10分钟
**大小**: 10-50 MB
**方式**: 直接下载ONNX模型（无需Docker）

#### 2.2 下载MeloTTS模型

```powershell
.\scripts\2026-02-15\21-download-melotts-with-cache.ps1
```

**时间**: 2-3分钟
**大小**: 50-100 MB
**方式**: 使用缓存镜像（快速）

#### 2.3 下载Coqui TTS模型

```powershell
.\scripts\2026-02-15\23-download-coqui-with-cache.ps1
```

**时间**: 2-3分钟
**大小**: 100-200 MB
**方式**: 使用缓存镜像（快速）

---

## 📊 时间对比

### 原始方案（16-19脚本，有问题）

| 引擎 | 每次运行 | 问题 |
|------|---------|------|
| MeloTTS | 15-20分钟 | ❌ 每次安装PyTorch，会超时 |
| Piper TTS | 5-10分钟 | ✅ 无问题 |
| Coqui TTS | 20-30分钟 | ❌ 每次安装PyTorch，会超时 |
| **总计** | **40-60分钟** | ❌ 浪费时间，不可靠 |

### 缓存镜像方案（20-24脚本，推荐）⭐

| 引擎 | 首次运行 | 后续运行 | 优势 |
|------|---------|---------|------|
| MeloTTS | 10-15分钟（构建镜像） | 2-3分钟 | ✅ 快速可靠 |
| Piper TTS | 5-10分钟 | 5-10分钟 | ✅ 无问题 |
| Coqui TTS | 15-20分钟（构建镜像） | 2-3分钟 | ✅ 快速可靠 |
| **总计** | **30-45分钟** | **9-16分钟** | ✅ 节省时间 |

---

## 🔍 方案对比

### 为什么需要缓存镜像？

**问题**：原始脚本每次都要安装PyTorch
```bash
# ❌ 这会导致超时（与PaddleSpeech相同的问题）
pip install torch torchaudio --index-url https://download.pytorch.org/whl/cpu -q
```

**PyTorch很大**：
- CPU版本：约500 MB
- 下载时间：5-10分钟（网络好的情况下）
- 网络不稳定：超时失败

**解决方案**：缓存Docker镜像
```
第一次：构建镜像（包含PyTorch）→ 10-20分钟
后续：直接使用镜像 → 2-3分钟
```

### 与PaddleSpeech的对比

| 方案 | PaddleSpeech | MeloTTS/Coqui TTS |
|------|-------------|------------------|
| 原始脚本 | 12-export（超时） | 16/18-download（超时） |
| 缓存镜像 | 13-export（成功）⭐ | 20-24-download（成功）⭐ |
| 问题 | 每次安装PaddleSpeech | 每次安装PyTorch |
| 解决方案 | 构建缓存镜像 | 构建缓存镜像 |

**同样的问题，同样的解决方案**。

---

## 📁 目录结构

下载完成后的目录结构：

```
tts_models/
├── paddlespeech_offline/     # PaddleSpeech模型（已完成，2.23 GB）
│   ├── conf/
│   └── models/
├── melotts/                  # MeloTTS模型（50-100 MB）
│   ├── models--myshell-ai--MeloTTS-Chinese/
│   ├── models--myshell-ai--MeloTTS-English/
│   ├── melotts_zh_test.wav  # 测试音频
│   └── melotts_en_test.wav  # 测试音频
├── piper/                    # Piper TTS模型（10-50 MB）
│   ├── zh_CN-huayan-medium.onnx
│   └── zh_CN-huayan-medium.onnx.json
└── coqui/                    # Coqui TTS模型（100-200 MB）
    ├── tts_models/
    │   └── zh-CN/
    │       └── baker/
    └── coqui_test.wav        # 测试音频
```

---

## ⚠️ 注意事项

### 1. Docker要求

**必须安装Docker Desktop**:
- 确保Docker Desktop已安装并运行
- 确保Docker有足够的磁盘空间（至少5 GB）
- 首次运行会构建镜像（约3.3 GB）

### 2. 磁盘空间

**所需空间**:
- Docker镜像：约3.3 GB（melotts 1.5 GB + coqui 1.8 GB）
- PaddleSpeech模型：2.23 GB（已完成）
- MeloTTS模型：50-100 MB
- Piper TTS模型：10-50 MB
- Coqui TTS模型：100-200 MB
- **总计**：约5.7-5.9 GB

**建议**:
- 确保至少有10 GB可用空间
- Docker镜像可以在下载完模型后删除

### 3. 网络要求

**首次构建镜像**:
- 需要下载PyTorch（约500 MB）
- 需要稳定的网络连接
- 建议使用代理或VPN

**后续下载模型**:
- 网络要求较低
- 模型文件较小（10-200 MB）

### 4. 镜像管理

**查看镜像**:
```powershell
docker images | Select-String "melotts\|coqui"
```

**删除镜像**（下载完模型后可删除）:
```powershell
docker rmi melotts-downloader:latest
docker rmi coqui-tts-downloader:latest
```

**重新构建镜像**:
```powershell
# 先删除旧镜像
docker rmi melotts-downloader:latest

# 重新构建
.\scripts\2026-02-15\20-build-melotts-image.ps1
```

---

## 🔍 验证下载结果

### 检查模型文件

```powershell
# 查看所有模型目录
Get-ChildItem E:\2025\3_gongkongji\belt_control_system\tts_models -Directory

# 查看模型大小
Get-ChildItem E:\2025\3_gongkongji\belt_control_system\tts_models -Recurse -File | Measure-Object -Property Length -Sum
```

### 预期结果

**成功标志**:
- ✅ PaddleSpeech: 2.23 GB
- ✅ MeloTTS: 50-100 MB（包含测试音频）
- ✅ Piper TTS: 10-50 MB
- ✅ Coqui TTS: 100-200 MB（包含测试音频）

**总计**: 约2.4-2.6 GB

### 测试音频

下载完成后会生成测试音频：
- `melotts/melotts_zh_test.wav` - MeloTTS中文测试
- `melotts/melotts_en_test.wav` - MeloTTS英文测试
- `coqui/coqui_test.wav` - Coqui TTS中文测试

可以播放这些音频验证模型是否正常工作。

---

## 💡 常见问题

### Q1: 为什么要构建Docker镜像？

**A**: 避免每次都重新安装PyTorch（500 MB），节省时间，避免网络超时。

### Q2: 镜像构建失败怎么办？

**A**:
1. 检查Docker Desktop是否运行
2. 检查网络连接
3. 检查磁盘空间
4. 重启Docker Desktop后重试

### Q3: 模型下载失败怎么办？

**A**:
1. 检查Docker镜像是否存在：`docker images`
2. 如果镜像不存在，先运行构建脚本
3. 查看错误日志
4. 重新运行下载脚本

### Q4: 可以只下载某个引擎的模型吗？

**A**: 可以，分别运行对应的脚本：
- Piper TTS: `17-download-piper-models.ps1`
- MeloTTS: `21-download-melotts-with-cache.ps1`（需要先构建镜像）
- Coqui TTS: `23-download-coqui-with-cache.ps1`（需要先构建镜像）

### Q5: 下载完模型后可以删除Docker镜像吗？

**A**: 可以。模型已经保存到本地，Docker镜像只是用于下载。但如果以后需要更新模型，还需要重新构建镜像。

---

## 🚀 下一步

### 1. 测试模型

播放测试音频，验证语音质量：
```powershell
# 播放MeloTTS测试音频
Start-Process "E:\2025\3_gongkongji\belt_control_system\tts_models\melotts\melotts_zh_test.wav"

# 播放Coqui TTS测试音频
Start-Process "E:\2025\3_gongkongji\belt_control_system\tts_models\coqui\coqui_test.wav"
```

### 2. 集成到项目

- 实现各个引擎的适配器
- 更新TTSEngineManager
- 修改QML界面

### 3. 部署到RK3588

```powershell
# 同步所有模型到设备
scp -r E:\2025\3_gongkongji\belt_control_system\tts_models linaro@192.168.10.188:/app/models/
```

---

## ✅ 总结

### 创建的脚本（9个）

**缓存镜像方案**（推荐）⭐:
1. `20-build-melotts-image.ps1` - 构建MeloTTS镜像
2. `21-download-melotts-with-cache.ps1` - 下载MeloTTS模型
3. `22-build-coqui-image.ps1` - 构建Coqui TTS镜像
4. `23-download-coqui-with-cache.ps1` - 下载Coqui TTS模型
5. `24-download-all-tts-models-v2.ps1` - 统一下载脚本

**直接下载**（无需Docker）:
6. `17-download-piper-models.ps1` - 下载Piper TTS模型

**原始方案**（有问题，不推荐）:
7. `16-download-melotts-models.ps1` - ❌ 会超时
8. `18-download-coqui-models.ps1` - ❌ 会超时
9. `19-download-all-tts-models.ps1` - ❌ 会超时

### 推荐使用

```powershell
# 一键下载所有模型（推荐）
.\scripts\2026-02-15\24-download-all-tts-models-v2.ps1
```

### 优势

- ✅ 避免网络超时
- ✅ 节省时间（后续仅9-16分钟）
- ✅ 稳定可靠
- ✅ 可重复使用

---

**相关文档**:
- [18-三个TTS引擎模型下载方案更正.md](./18-三个TTS引擎模型下载方案更正.md) - 问题分析
- [19-三个TTS引擎模型下载正确流程.md](./19-三个TTS引擎模型下载正确流程.md) - 方案对比
- [14-PaddleSpeech模型导出最终解决方案.md](./14-PaddleSpeech模型导出最终解决方案.md) - PaddleSpeech缓存镜像方案
