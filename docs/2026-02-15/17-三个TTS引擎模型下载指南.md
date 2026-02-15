# 三个TTS引擎模型下载指南

**创建时间**: 2026-02-15 16:00
**目的**: 下载MeloTTS、Piper TTS、Coqui TTS三个引擎的模型
**总大小**: 约160-350 MB
**预计时间**: 30-60分钟

---

## 📋 快速开始

### 方法1：一键下载所有模型（推荐）⭐

```powershell
.\scripts\2026-02-15\19-download-all-tts-models.ps1
```

**说明**:
- 自动按顺序下载三个引擎的模型
- 自动处理错误，继续下载其他模型
- 最后统计所有模型大小

### 方法2：分别下载

```powershell
# 1. 下载MeloTTS模型（首选引擎）
.\scripts\2026-02-15\16-download-melotts-models.ps1

# 2. 下载Piper TTS模型（性能引擎）
.\scripts\2026-02-15\17-download-piper-models.ps1

# 3. 下载Coqui TTS模型（功能引擎）
.\scripts\2026-02-15\18-download-coqui-models.ps1
```

---

## 📊 三个引擎对比

| 引擎 | 优先级 | 模型大小 | 下载时间 | 特点 |
|------|--------|---------|---------|------|
| **MeloTTS** | ⭐⭐⭐⭐⭐ | 50-100 MB | 10-20分钟 | 首选，语音质量接近商业级别 |
| **Piper TTS** | ⭐⭐⭐⭐ | 10-50 MB | 5-10分钟 | 性能最好，模型最小 |
| **Coqui TTS** | ⭐⭐⭐ | 100-200 MB | 15-30分钟 | 功能最全，支持语音克隆 |

---

## 🚀 详细说明

### 1. MeloTTS（首选引擎）

**脚本**: `16-download-melotts-models.ps1`

**下载内容**:
- 中文模型（约50-80 MB）
- 英文模型（约50-80 MB）
- 中英混合模型（约80-100 MB）

**下载方式**:
- 使用Docker容器
- 从GitHub或Hugging Face下载
- 自动安装MeloTTS和依赖

**输出位置**: `tts_models/melotts/`

**特点**:
- ✅ 语音质量接近商业级别
- ✅ 基于VITS架构
- ✅ 中英文混合效果好
- ✅ 模型大小适中

---

### 2. Piper TTS（性能引擎）

**脚本**: `17-download-piper-models.ps1`

**下载内容**:
- zh_CN-huayan-medium.onnx（约30 MB）
- zh_CN-huayan-medium.onnx.json（配置文件）

**下载方式**:
- 使用curl直接下载
- 从Hugging Face下载
- 无需Docker

**输出位置**: `tts_models/piper/`

**特点**:
- ✅ 性能极佳，专为嵌入式设计
- ✅ 模型最小（10-50 MB）
- ✅ C++实现，易于集成
- ✅ 部署简单，无Python依赖
- ⚠️ 中文语音质量一般

---

### 3. Coqui TTS（功能引擎）

**脚本**: `18-download-coqui-models.ps1`

**下载内容**:
- tts_models/zh-CN/baker/tacotron2-DDC-GST（约100-150 MB）
- 或 tts_models/zh-CN/baker/vits（约150-200 MB）

**下载方式**:
- 使用Docker容器
- 使用Coqui TTS CLI自动下载
- 自动安装Coqui TTS和依赖

**输出位置**: `tts_models/coqui/`

**特点**:
- ✅ 功能最全，支持语音克隆
- ✅ 社区活跃，模型选择多
- ✅ 支持多种TTS模型
- ⚠️ 依赖PyTorch，部署复杂
- ⚠️ ARM64优化不如Piper

---

## 📁 目录结构

下载完成后的目录结构：

```
tts_models/
├── paddlespeech_offline/     # PaddleSpeech模型（已完成，2.23 GB）
│   ├── conf/
│   └── models/
│       ├── fastspeech2_csmsc-zh/
│       ├── pwgan_csmsc-zh/
│       ├── vits_csmsc-zh/
│       └── ...
├── melotts/                  # MeloTTS模型（50-100 MB）
│   ├── models--myshell-ai--MeloTTS-Chinese/
│   └── models--myshell-ai--MeloTTS-English/
├── piper/                    # Piper TTS模型（10-50 MB）
│   ├── zh_CN-huayan-medium.onnx
│   └── zh_CN-huayan-medium.onnx.json
└── coqui/                    # Coqui TTS模型（100-200 MB）
    └── tts_models/
        └── zh-CN/
            └── baker/
                └── tacotron2-DDC-GST/
```

---

## ⚠️ 注意事项

### 1. 网络要求

**可能的问题**:
- GitHub下载可能较慢（国内网络）
- Hugging Face可能需要代理
- Docker拉取镜像可能较慢

**解决方案**:
- 使用代理或VPN
- 使用国内镜像源
- 分批下载，避免超时

### 2. Docker要求

**MeloTTS和Coqui TTS需要Docker**:
- 确保Docker Desktop已安装并运行
- 确保Docker有足够的磁盘空间（至少5 GB）
- 首次运行会拉取python:3.11-slim镜像（约150 MB）

**Piper TTS不需要Docker**:
- 直接使用curl下载
- 速度最快

### 3. 磁盘空间

**所需空间**:
- PaddleSpeech: 2.23 GB（已完成）
- MeloTTS: 50-100 MB
- Piper TTS: 10-50 MB
- Coqui TTS: 100-200 MB
- **总计**: 约2.4-2.6 GB

**建议**:
- 确保至少有5 GB可用空间
- 下载完成后可以删除临时文件

### 4. 下载失败处理

**如果某个模型下载失败**:
1. 检查网络连接
2. 检查Docker是否运行
3. 查看错误日志
4. 重新运行对应的脚本

**脚本会自动处理错误**:
- 某个模型失败不影响其他模型
- 统一脚本会继续下载其他模型

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
- ✅ MeloTTS: 50-100 MB
- ✅ Piper TTS: 10-50 MB
- ✅ Coqui TTS: 100-200 MB

**总计**: 约2.4-2.6 GB

---

## 🚀 下一步

### 1. 测试模型

下载完成后，测试每个引擎的语音合成：

```powershell
# 测试MeloTTS
# （需要创建测试脚本）

# 测试Piper TTS
# （需要创建测试脚本）

# 测试Coqui TTS
# （需要创建测试脚本）
```

### 2. 集成到项目

- 更新TTSEngineManager
- 实现各个引擎的适配器
- 修改QML界面

### 3. 部署到RK3588

```powershell
# 同步所有模型到设备
scp -r E:\2025\3_gongkongji\belt_control_system\tts_models linaro@192.168.10.188:/app/models/
```

---

## 💡 常见问题

### Q1: 下载速度很慢怎么办？

**A**:
- 使用代理或VPN
- 分别下载，不要一次性下载所有模型
- Piper TTS最快，可以先下载

### Q2: Docker容器启动失败？

**A**:
- 检查Docker Desktop是否运行
- 检查Docker磁盘空间
- 重启Docker Desktop

### Q3: 模型下载失败？

**A**:
- 检查网络连接
- 查看错误日志
- 重新运行对应的脚本
- 尝试手动下载

### Q4: 如何手动下载？

**A**:

**MeloTTS**:
```bash
# 从Hugging Face手动下载
git clone https://huggingface.co/myshell-ai/MeloTTS
```

**Piper TTS**:
```bash
# 直接下载ONNX模型
curl -L -o zh_CN-huayan-medium.onnx https://huggingface.co/rhasspy/piper-voices/resolve/main/zh_CN/zh_CN-huayan-medium/zh_CN-huayan-medium.onnx
```

**Coqui TTS**:
```bash
# 使用pip安装后自动下载
pip install TTS
tts --model_name tts_models/zh-CN/baker/tacotron2-DDC-GST --text "测试" --out_path test.wav
```

---

## ✅ 总结

### 推荐流程

1. **运行统一脚本**（最简单）
   ```powershell
   .\scripts\2026-02-15\19-download-all-tts-models.ps1
   ```

2. **等待下载完成**（30-60分钟）

3. **验证模型文件**
   - 检查目录结构
   - 检查文件大小

4. **测试语音合成**
   - 每个引擎生成测试音频
   - 对比语音质量

5. **集成到项目**
   - 实现适配器
   - 更新界面

---

**相关文档**:
- [16-四引擎TTS模型完善状态分析.md](./16-四引擎TTS模型完善状态分析.md) - 模型状态分析
- [06-四引擎TTS集成实施计划-总览.md](../2026-02-13/06-四引擎TTS集成实施计划-总览.md) - 完整实施计划
- [05-开源TTS方案调研与对比.md](../2026-02-13/05-开源TTS方案调研与对比.md) - TTS方案调研
