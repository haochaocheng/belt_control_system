# 四引擎TTS模型完善状态分析

**创建时间**: 2026-02-15 15:30
**分析目的**: 检查MeloTTS、Piper TTS、Coqui TTS三个引擎的模型准备情况
**参考文档**: 05-开源TTS方案调研与对比.md, 06-四引擎TTS集成实施计划-总览.md

---

## 📊 当前模型状态总览

### ✅ PaddleSpeech（已完成）

**模型位置**: `tts_models/paddlespeech_offline/`

**已有模型**（2.23 GB）:
1. ✅ FastSpeech2-CSMSC + PWG（中文女声）
2. ✅ FastSpeech2-AISHELL3（中文多说话人，缺声码器）
3. ✅ VITS-CSMSC（中文女声，高质量，端到端）
4. ✅ VITS-AISHELL3（中文多说话人，高质量，端到端）
5. ✅ FastSpeech2-Canton + PWG（粤语）

**状态**: ✅ 模型完整，可以使用

---

### ⏳ MeloTTS（首选，待完善）

**项目信息**:
- GitHub: https://github.com/myshell-ai/MeloTTS
- 模型大小: 50-100 MB
- 技术: 基于VITS架构
- 优势: 语音质量接近商业级别，中英文混合效果好

**当前状态**: ❌ 无模型

**需要的模型**:
1. **中文模型**（必需）
   - 模型名称: `melo_tts_zh.onnx` 或 `melo_tts_zh.pth`
   - 大小: 约50-80 MB
   - 说话人: 单说话人或多说话人

2. **英文模型**（可选）
   - 模型名称: `melo_tts_en.onnx` 或 `melo_tts_en.pth`
   - 大小: 约50-80 MB

3. **中英混合模型**（推荐）
   - 模型名称: `melo_tts_mix.onnx` 或 `melo_tts_mix.pth`
   - 大小: 约80-100 MB
   - 优势: 一个模型支持中英文

**获取方式**:
1. **官方预训练模型**（推荐）
   ```bash
   # 从GitHub Releases下载
   wget https://github.com/myshell-ai/MeloTTS/releases/download/v0.1.0/melo_tts_zh.pth
   ```

2. **转换为ONNX**（用于ARM64优化）
   ```python
   # 使用官方脚本转换
   python export_onnx.py --model melo_tts_zh.pth --output melo_tts_zh.onnx
   ```

3. **Hugging Face模型库**
   ```bash
   # 从Hugging Face下载
   huggingface-cli download myshell-ai/MeloTTS --local-dir ./melo_models
   ```

**优先级**: ⭐⭐⭐⭐⭐（最高，首选引擎）

**预计下载时间**: 10-20分钟

---

### ⏳ Piper TTS（性能最好，待完善）

**项目信息**:
- GitHub: https://github.com/rhasspy/piper
- 模型大小: 10-50 MB
- 技术: C++实现，专为嵌入式设计
- 优势: 性能极佳，模型小，部署简单

**当前状态**: ❌ 无模型

**需要的模型**:
1. **中文模型**（必需）
   - 模型名称: `zh_CN-*.onnx`
   - 大小: 约20-40 MB
   - 说话人: 单说话人

2. **英文模型**（可选）
   - 模型名称: `en_US-*.onnx`
   - 大小: 约10-30 MB

**可用的中文模型**:
根据Piper官方模型库（https://github.com/rhasspy/piper/blob/master/VOICES.md）:

1. **zh_CN-huayan-medium**（推荐）
   - 质量: Medium
   - 大小: 约30 MB
   - 说话人: 女声
   - 下载: https://huggingface.co/rhasspy/piper-voices/tree/main/zh_CN/zh_CN-huayan-medium

2. **zh_CN-huayan-x_low**
   - 质量: Extra Low（质量较低，但模型最小）
   - 大小: 约10 MB
   - 说话人: 女声

**获取方式**:
1. **官方模型库**（推荐）
   ```bash
   # 下载中文模型
   wget https://huggingface.co/rhasspy/piper-voices/resolve/main/zh_CN/zh_CN-huayan-medium/zh_CN-huayan-medium.onnx
   wget https://huggingface.co/rhasspy/piper-voices/resolve/main/zh_CN/zh_CN-huayan-medium/zh_CN-huayan-medium.onnx.json
   ```

2. **使用Piper CLI下载**
   ```bash
   # 安装Piper
   pip install piper-tts

   # 下载模型
   piper --model zh_CN-huayan-medium --download-dir ./piper_models
   ```

**优先级**: ⭐⭐⭐⭐（高，性能引擎）

**预计下载时间**: 5-10分钟

**注意事项**:
- ⚠️ Piper的中文语音质量一般（不如PaddleSpeech和MeloTTS）
- ✅ 但性能极佳，适合资源受限场景
- ✅ C++实现，易于集成到现有项目

---

### ⏳ Coqui TTS（功能最全，待完善）

**项目信息**:
- GitHub: https://github.com/coqui-ai/TTS
- 模型大小: 100-200 MB
- 技术: 基于PyTorch，支持多种TTS模型
- 优势: 支持语音克隆，功能最全

**当前状态**: ❌ 无模型

**需要的模型**:
1. **中文VITS模型**（推荐）
   - 模型名称: `tts_models/zh-CN/baker/vits`
   - 大小: 约150 MB
   - 说话人: 女声（Baker数据集）

2. **多语言模型**（可选）
   - 模型名称: `tts_models/multilingual/multi-dataset/your_tts`
   - 大小: 约200 MB
   - 支持: 多语言，语音克隆

**可用的中文模型**:
根据Coqui TTS官方模型库:

1. **tts_models/zh-CN/baker/tacotron2-DDC**
   - 架构: Tacotron2
   - 质量: 中等
   - 大小: 约100 MB

2. **tts_models/zh-CN/baker/vits**（推荐）
   - 架构: VITS
   - 质量: 高
   - 大小: 约150 MB

**获取方式**:
1. **使用Coqui TTS CLI下载**（推荐）
   ```bash
   # 安装Coqui TTS
   pip install TTS

   # 列出可用模型
   tts --list_models

   # 下载中文模型
   tts --model_name tts_models/zh-CN/baker/vits --text "测试" --out_path test.wav
   # 首次运行会自动下载模型
   ```

2. **从Hugging Face下载**
   ```bash
   # 下载预训练模型
   huggingface-cli download coqui/XTTS-v2 --local-dir ./coqui_models
   ```

**优先级**: ⭐⭐⭐（中，功能引擎）

**预计下载时间**: 15-30分钟

**注意事项**:
- ⚠️ 依赖PyTorch，部署复杂
- ⚠️ ARM64优化不如Piper
- ✅ 支持语音克隆（高级功能）
- ✅ 社区活跃，模型选择多

---

## 📋 模型下载优先级建议

### 第一优先级：MeloTTS（首选引擎）⭐⭐⭐⭐⭐

**理由**:
- 语音质量接近商业级别
- 模型小（50-100 MB）
- 中英文混合效果好
- 根据调研，这是首选方案

**下载任务**:
1. ✅ 下载中文模型（必需）
2. ✅ 下载中英混合模型（推荐）
3. ⏳ 转换为ONNX（可选，用于ARM64优化）

**预计时间**: 10-20分钟

---

### 第二优先级：Piper TTS（性能引擎）⭐⭐⭐⭐

**理由**:
- 性能极佳，模型最小
- C++实现，易于集成
- 部署简单，无Python依赖

**下载任务**:
1. ✅ 下载中文模型（zh_CN-huayan-medium）
2. ⏳ 下载英文模型（可选）

**预计时间**: 5-10分钟

---

### 第三优先级：Coqui TTS（功能引擎）⭐⭐⭐

**理由**:
- 功能最全，支持语音克隆
- 社区活跃，模型选择多
- 但部署复杂，优先级较低

**下载任务**:
1. ✅ 下载中文VITS模型（tts_models/zh-CN/baker/vits）
2. ⏳ 下载多语言模型（可选）

**预计时间**: 15-30分钟

---

## 🚀 下一步行动计划

### 立即执行（今天）

1. **下载MeloTTS模型**（首选引擎）
   - 中文模型
   - 中英混合模型
   - 测试语音合成

2. **下载Piper TTS模型**（性能引擎）
   - 中文模型（zh_CN-huayan-medium）
   - 测试语音合成

### 后续执行（明天或下周）

3. **下载Coqui TTS模型**（功能引擎）
   - 中文VITS模型
   - 测试语音合成

4. **集成测试**
   - 四引擎切换测试
   - 语音质量对比
   - 性能测试

---

## 📝 模型下载脚本规划

### 脚本1：下载MeloTTS模型

**脚本名称**: `scripts/2026-02-15/16-download-melotts-models.ps1`

**功能**:
- 从GitHub Releases下载MeloTTS预训练模型
- 从Hugging Face下载（备用）
- 验证模型完整性

### 脚本2：下载Piper TTS模型

**脚本名称**: `scripts/2026-02-15/17-download-piper-models.ps1`

**功能**:
- 从Hugging Face下载Piper中文模型
- 下载配置文件（.onnx.json）
- 验证模型完整性

### 脚本3：下载Coqui TTS模型

**脚本名称**: `scripts/2026-02-15/18-download-coqui-models.ps1`

**功能**:
- 使用Coqui TTS CLI自动下载
- 从Hugging Face下载（备用）
- 验证模型完整性

---

## 💡 关键注意事项

### 1. 模型存储位置

**建议目录结构**:
```
tts_models/
├── paddlespeech_offline/     # PaddleSpeech模型（已完成，2.23 GB）
├── melotts/                  # MeloTTS模型（待下载，50-100 MB）
│   ├── zh/                   # 中文模型
│   ├── en/                   # 英文模型
│   └── mix/                  # 中英混合模型
├── piper/                    # Piper TTS模型（待下载，10-50 MB）
│   ├── zh_CN-huayan-medium.onnx
│   └── zh_CN-huayan-medium.onnx.json
└── coqui/                    # Coqui TTS模型（待下载，100-200 MB）
    └── tts_models/
        └── zh-CN/
            └── baker/
                └── vits/
```

### 2. 网络下载注意事项

**可能的问题**:
- GitHub下载可能较慢（国内网络）
- Hugging Face可能需要代理
- 模型文件较大，需要稳定网络

**解决方案**:
- 使用国内镜像源（如清华镜像）
- 使用代理或VPN
- 分批下载，避免超时

### 3. 模型验证

**验证方法**:
1. 检查文件大小
2. 计算MD5/SHA256哈希
3. 尝试加载模型
4. 生成测试音频

---

## ✅ 总结

### 当前状态

| 引擎 | 模型状态 | 优先级 | 预计下载时间 | 模型大小 |
|------|---------|--------|-------------|---------|
| PaddleSpeech | ✅ 已完成 | - | - | 2.23 GB |
| MeloTTS | ❌ 无模型 | ⭐⭐⭐⭐⭐ | 10-20分钟 | 50-100 MB |
| Piper TTS | ❌ 无模型 | ⭐⭐⭐⭐ | 5-10分钟 | 10-50 MB |
| Coqui TTS | ❌ 无模型 | ⭐⭐⭐ | 15-30分钟 | 100-200 MB |

### 下一步

1. ✅ 创建MeloTTS模型下载脚本
2. ✅ 创建Piper TTS模型下载脚本
3. ✅ 创建Coqui TTS模型下载脚本
4. ✅ 按优先级依次下载模型
5. ✅ 测试每个引擎的语音合成

---

**文档版本**: v1.0
**创建时间**: 2026-02-15 15:30
**作者**: Claude Code
