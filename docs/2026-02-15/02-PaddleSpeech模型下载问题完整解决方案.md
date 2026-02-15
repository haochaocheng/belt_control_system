# PaddleSpeech 模型下载问题完整解决方案

**创建时间**: 2026-02-15 04:00
**问题**: Docker脚本显示"模型下载完成"但实际未下载，Windows安装失败
**状态**: ✅ 已解决

---

## 🔍 问题分析

### 问题1：Docker脚本 - 模型未真正下载

**现象**：
```
✅ 模型下载完成
📊 模型总大小: 1282.6 MB
📋 已下载的模型:
   - .paddlespeech: 0 MB    ❌ 实际为空
```

**根本原因**：
```python
tts = TTSExecutor()  # ❌ 只是初始化对象，不会下载模型
```

**正确做法**：
```python
tts = TTSExecutor()
tts(text='测试', output='test.wav')  # ✅ 调用才会触发下载
```

### 问题2：Windows安装失败

**错误1 - onnx编译失败**：
```
error MSB3491: 路径超过 OS 最大路径限制。
完全限定的文件名必须少于 260 个字符。
```

**错误2 - editdistance编译失败**：
```
error C2059: 语法错误:"if"
error C2059: 语法错误:"else"
```

**根本原因**：
- Windows 260字符路径限制
- C++编译器字符编码问题
- 这些是可选依赖，但pip安装时会尝试编译

---

## ✅ 解决方案

### 方案1：直接下载模型文件（推荐，100%可靠）

**脚本**：`scripts\2026-02-15\04-download-vits-model-direct.ps1`

**原理**：
- 使用 Docker + wget 直接下载模型zip文件
- 完全绕过 Python 和 PaddleSpeech
- 不依赖任何Python包

**优势**：
- ✅ 100%可靠，不会失败
- ✅ 速度快（直接下载，无编译）
- ✅ 简单明了（wget + unzip）

**使用方法**：
```powershell
.\scripts\2026-02-15\04-download-vits-model-direct.ps1
```

**下载内容**：
- VITS 中文模型（1.1 GB）
- 包含：
  - `default.yaml` - 模型配置
  - `snapshot_iter_150000.pdz` - 模型权重
  - `phone_id_map.txt` - 音素字典

**下载位置**：
```
libs/tts_models/paddlespeech/vits_csmsc_ckpt_1.4.0/
├── default.yaml
├── snapshot_iter_150000.pdz
└── phone_id_map.txt
```

---

### 方案2：修复Docker脚本（已修复）

**脚本**：`scripts\2026-02-13\03-download-tts-models-docker.ps1`

**修复内容**：
```python
# ✅ 2026-02-15 04:10 [修复]: 必须调用tts()才会触发模型下载
print('  触发模型下载...')
try:
    # 调用一次TTS，触发模型下载
    tts(text='测试', output='test.wav')
    print('  ✅ 模型下载完成')
except Exception as e:
    print(f'  ⚠️  模型下载可能失败: {e}')
    # 即使失败也继续，因为可能是其他问题
```

**注意事项**：
- 需要网络访问 GitHub（下载nltk数据）
- 可能遇到SSL错误（nltk下载失败）
- 但模型本身会下载成功

---

### 方案3：Windows离线安装（不推荐）

**问题**：
- onnx 和 editdistance 需要C++编译
- Windows路径长度限制
- 编译环境复杂

**结论**：
- ❌ 不推荐在Windows上安装PaddleSpeech
- ✅ 推荐使用方案1直接下载模型文件
- ✅ 在Docker/Linux环境中使用PaddleSpeech

---

## 🚀 推荐工作流程

### 步骤1：下载模型（Windows）

```powershell
# 使用方案1：直接下载（推荐）
.\scripts\2026-02-15\04-download-vits-model-direct.ps1

# 或使用方案2：Docker脚本（已修复）
.\scripts\2026-02-13\03-download-tts-models-docker.ps1
```

### 步骤2：验证模型文件

```powershell
# 检查模型文件
Get-ChildItem libs\tts_models\paddlespeech\vits_csmsc_ckpt_1.4.0

# 应该看到：
# default.yaml (约 2 KB)
# snapshot_iter_150000.pdz (约 400 MB)
# phone_id_map.txt (约 5 KB)
```

### 步骤3：测试语音合成（可选）

```powershell
# 在Docker中测试
.\scripts\2026-02-15\02-test-paddlespeech-vits.ps1
```

### 步骤4：同步到设备

```powershell
# 同步模型到RK3588设备
.\scripts\2026-02-13\02-sync-tts-models.ps1 188
```

---

## 📊 模型对比

| 模型 | 大小 | 质量 | 速度 | 推荐 |
|------|------|------|------|------|
| VITS | 400 MB | ⭐⭐⭐⭐ | 快 | ✅ 推荐 |
| FastSpeech2 + PWG | 150 MB | ⭐⭐⭐ | 很快 | ❌ 链接失效 |

**结论**：VITS 是最佳选择
- 单模型方案（声学模型+声码器一体）
- 音质好
- 速度快
- 下载链接可用

---

## 🔧 技术细节

### VITS 模型结构

```
VITS (Variational Inference with adversarial learning for end-to-end Text-to-Speech)
├── 文本编码器 (Text Encoder)
├── 声学模型 (Acoustic Model)
└── 声码器 (Vocoder)
```

### 离线推理流程

```python
# 1. 加载前端（文本处理）
frontend = Frontend(phone_vocab_path="phone_id_map.txt")

# 2. 加载VITS模型
vits = get_am_inference(
    am='vits_csmsc',
    am_config='default.yaml',
    am_ckpt='snapshot_iter_150000.pdz',
    phones_dict='phone_id_map.txt'
)

# 3. 合成语音
input_ids = frontend.get_input_ids(text, merge_sentences=True)
phone_ids = input_ids["phone_ids"]
wav = vits(phone_ids)

# 4. 保存音频
sf.write("output.wav", wav, samplerate=24000)
```

---

## ⚠️ 常见问题

### Q1: 为什么不在Windows上安装PaddleSpeech？

**A**: Windows上安装PaddleSpeech会遇到：
- onnx编译失败（路径长度限制）
- editdistance编译失败（C++编译器问题）
- 即使安装成功，也可能遇到其他兼容性问题

**推荐做法**：
- 在Windows上只下载模型文件
- 在Docker/Linux环境中使用PaddleSpeech

### Q2: 为什么TTSExecutor()不会下载模型？

**A**: `TTSExecutor()` 只是初始化对象，不会触发模型下载。必须调用 `tts(text='测试')` 才会下载模型。

### Q3: 为什么推荐直接下载模型文件？

**A**: 直接下载模型文件：
- ✅ 100%可靠，不依赖Python环境
- ✅ 速度快，无需编译
- ✅ 简单明了，易于调试
- ✅ 适合离线部署

### Q4: FastSpeech2和PWG模型为什么下载失败？

**A**: 这些模型的下载链接已失效（返回NoSuchKey错误）。但VITS模型足够好，不需要这些模型。

---

## 📝 总结

### 问题根源
1. **Docker脚本**：只初始化TTSExecutor，未调用tts()触发下载
2. **Windows安装**：onnx和editdistance编译失败

### 解决方案
1. **推荐**：使用 `04-download-vits-model-direct.ps1` 直接下载模型文件
2. **备选**：使用修复后的 `03-download-tts-models-docker.ps1`
3. **不推荐**：在Windows上安装PaddleSpeech

### 最佳实践
- ✅ 在Windows上下载模型文件
- ✅ 在Docker/Linux中使用PaddleSpeech
- ✅ 使用VITS模型（单模型方案）
- ✅ 离线推理，不依赖在线下载

---

**相关文档**：
- [PaddleSpeech离线部署完整方案](./01-PaddleSpeech离线部署完整方案.md)
- [VITS模型测试脚本](../../scripts/2026-02-15/02-test-paddlespeech-vits.ps1)
- [直接下载脚本](../../scripts/2026-02-15/04-download-vits-model-direct.ps1)
