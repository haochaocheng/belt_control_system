# PaddleSpeech TTS 模型详细分析

**创建时间**: 2026-02-15 06:00
**目的**: 分析PaddleSpeech可用的TTS模型，特别是男声/女声选项

---

## 📊 当前使用的模型

### 我们测试使用的模型组合

**声学模型 (AM)**: `fastspeech2_csmsc`
- **大小**: 489 MB
- **类型**: FastSpeech2
- **数据集**: CSMSC (Chinese Standard Mandarin Speech Corpus)
- **说话人**: **女声**（标贝科技女声数据集）
- **特点**: 单说话人，标准普通话

**声码器 (Vocoder)**: `pwgan_csmsc`
- **大小**: 15.8 MB
- **类型**: Parallel WaveGAN
- **数据集**: CSMSC
- **特点**: 与FastSpeech2配套使用

**总大小**: 约 505 MB

---

## 🎤 PaddleSpeech 官方支持的模型

### 1. FastSpeech2 系列

#### FastSpeech2-CSMSC（女声）⭐ **当前使用**
```python
am='fastspeech2_csmsc'
voc='pwgan_csmsc'
```
- **说话人**: 女声（标贝科技）
- **语言**: 中文普通话
- **质量**: ⭐⭐⭐⭐
- **下载链接**:
  - AM: https://paddlespeech.bj.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_csmsc_ckpt_1.4.0.zip
  - VOC: https://paddlespeech.bj.bcebos.com/Parakeet/released_models/pwgan/pwgan_csmsc_ckpt_0.5.zip

#### FastSpeech2-AISHELL3（多说话人）
```python
am='fastspeech2_aishell3'
voc='pwgan_aishell3'
```
- **说话人**: 多说话人（218个说话人，男女混合）
- **语言**: 中文普通话
- **质量**: ⭐⭐⭐⭐
- **特点**: 可选择不同说话人ID
- **下载链接**:
  - AM: https://paddlespeech.bj.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_aishell3_ckpt_1.1.0.zip
  - VOC: https://paddlespeech.bj.bcebos.com/Parakeet/released_models/pwgan/pwgan_aishell3_ckpt_0.5.zip

#### FastSpeech2-LJSpeech（英文女声）
```python
am='fastspeech2_ljspeech'
voc='pwgan_ljspeech'
```
- **说话人**: 女声
- **语言**: 英文
- **质量**: ⭐⭐⭐⭐

#### FastSpeech2-VCTK（英文多说话人）
```python
am='fastspeech2_vctk'
voc='pwgan_vctk'
```
- **说话人**: 多说话人（109个说话人，男女混合）
- **语言**: 英文
- **质量**: ⭐⭐⭐⭐

---

### 2. SpeedySpeech 系列

#### SpeedySpeech-CSMSC（女声，快速）
```python
am='speedyspeech_csmsc'
voc='pwgan_csmsc'
```
- **说话人**: 女声（标贝科技）
- **语言**: 中文普通话
- **质量**: ⭐⭐⭐
- **特点**: 推理速度更快，质量略低于FastSpeech2
- **下载链接**:
  - AM: https://paddlespeech.bj.bcebos.com/Parakeet/released_models/speedyspeech/speedyspeech_csmsc_ckpt_0.5.0.zip

---

### 3. VITS 系列（端到端）

#### VITS-CSMSC（女声）
```python
am='vits_csmsc'
```
- **说话人**: 女声（标贝科技）
- **语言**: 中文普通话
- **质量**: ⭐⭐⭐⭐⭐
- **特点**: 端到端模型，不需要单独的声码器
- **大小**: 约 400 MB
- **下载链接**: https://paddlespeech.bj.bcebos.com/Parakeet/released_models/vits/vits_csmsc_ckpt_1.4.0.zip

#### VITS-AISHELL3（多说话人）
```python
am='vits_aishell3'
```
- **说话人**: 多说话人（218个说话人，男女混合）
- **语言**: 中文普通话
- **质量**: ⭐⭐⭐⭐⭐
- **特点**: 端到端，支持多说话人
- **下载链接**: https://paddlespeech.bj.bcebos.com/Parakeet/released_models/vits/vits_aishell3_ckpt_1.1.0.zip

---

### 4. Tacotron2 系列

#### Tacotron2-CSMSC（女声）
```python
am='tacotron2_csmsc'
voc='pwgan_csmsc'
```
- **说话人**: 女声（标贝科技）
- **语言**: 中文普通话
- **质量**: ⭐⭐⭐
- **特点**: 经典模型，质量稳定但推理较慢

---

## 🎭 男声模型选项

### ❌ 官方没有专门的男声单说话人模型

**PaddleSpeech官方模型现状**：
- ✅ 女声单说话人：CSMSC数据集（标贝科技女声）
- ✅ 多说话人（男女混合）：AISHELL3数据集（218个说话人）
- ❌ 男声单说话人：**官方未提供**

### ✅ 获取男声的方法

#### 方法1：使用AISHELL3多说话人模型（推荐）

```python
from paddlespeech.cli.tts import TTSExecutor

tts = TTSExecutor()

# 使用男性说话人ID
tts(
    text='你好，欢迎使用飞桨语音合成系统',
    output='output_male.wav',
    am='fastspeech2_aishell3',
    voc='pwgan_aishell3',
    spk_id=174,  # 男性说话人ID（需要查询AISHELL3数据集）
    lang='zh'
)
```

**AISHELL3说话人信息**：
- 总共218个说话人
- 男女比例约1:1
- 需要查询具体的说话人ID对应的性别

#### 方法2：自己训练男声模型

**步骤**：
1. 收集男声数据集（至少10小时）
2. 使用PaddleSpeech训练工具
3. 训练FastSpeech2或VITS模型
4. 导出模型用于推理

**难度**：⭐⭐⭐⭐⭐（需要专业知识和计算资源）

#### 方法3：使用第三方男声模型

**可能的来源**：
- 社区贡献的模型
- 其他开源项目的模型
- 商业模型（需要授权）

---

## 📋 模型对比表

| 模型 | 说话人 | 语言 | 质量 | 速度 | 大小 | 推荐场景 |
|------|--------|------|------|------|------|----------|
| FastSpeech2-CSMSC | 女声 | 中文 | ⭐⭐⭐⭐ | 快 | 505MB | **当前使用，推荐** |
| VITS-CSMSC | 女声 | 中文 | ⭐⭐⭐⭐⭐ | 中 | 400MB | 高质量需求 |
| FastSpeech2-AISHELL3 | 多人 | 中文 | ⭐⭐⭐⭐ | 快 | 600MB | **需要男声** |
| VITS-AISHELL3 | 多人 | 中文 | ⭐⭐⭐⭐⭐ | 中 | 500MB | 高质量+多说话人 |
| SpeedySpeech-CSMSC | 女声 | 中文 | ⭐⭐⭐ | 很快 | 300MB | 速度优先 |

---

## 🚀 如何切换模型

### 当前使用的模型（女声）

```python
tts(
    text='你好',
    output='output.wav',
    am='fastspeech2_csmsc',  # 女声
    voc='pwgan_csmsc',
    lang='zh'
)
```

### 切换到多说话人模型（可选男声）

```python
tts(
    text='你好',
    output='output.wav',
    am='fastspeech2_aishell3',  # 多说话人
    voc='pwgan_aishell3',
    spk_id=174,  # 指定说话人ID（需要测试找到男声ID）
    lang='zh'
)
```

### 切换到VITS高质量模型（女声）

```python
tts(
    text='你好',
    output='output.wav',
    am='vits_csmsc',  # VITS端到端，无需声码器
    lang='zh'
)
```

---

## 📥 下载其他模型

### 使用Docker脚本下载

修改 `scripts/2026-02-13/03-download-tts-models-docker.ps1`：

```python
# 下载AISHELL3多说话人模型（包含男声）
tts(
    text='测试',
    output='test.wav',
    am='fastspeech2_aishell3',  # 会自动下载
    voc='pwgan_aishell3',
    lang='zh'
)
```

### 手动下载模型

```powershell
# AISHELL3多说话人模型
wget https://paddlespeech.bj.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_aishell3_ckpt_1.1.0.zip
wget https://paddlespeech.bj.bcebos.com/Parakeet/released_models/pwgan/pwgan_aishell3_ckpt_0.5.zip

# VITS-CSMSC高质量模型
wget https://paddlespeech.bj.bcebos.com/Parakeet/released_models/vits/vits_csmsc_ckpt_1.4.0.zip

# VITS-AISHELL3多说话人模型
wget https://paddlespeech.bj.bcebos.com/Parakeet/released_models/vits/vits_aishell3_ckpt_1.1.0.zip
```

---

## 🎯 推荐方案

### 方案1：只使用女声（当前方案）
**模型**: FastSpeech2-CSMSC + PWG-CSMSC
- ✅ 已下载并测试成功
- ✅ 质量好，速度快
- ✅ 部署简单

### 方案2：支持男声和女声
**模型**: FastSpeech2-AISHELL3 + PWG-AISHELL3
- ✅ 218个说话人可选
- ✅ 包含男声和女声
- ⚠️ 需要额外下载（约600MB）
- ⚠️ 需要测试找到合适的男声ID

### 方案3：高质量女声
**模型**: VITS-CSMSC
- ✅ 质量最好（⭐⭐⭐⭐⭐）
- ✅ 端到端，无需声码器
- ⚠️ 推理速度略慢
- ⚠️ 只有女声

### 方案4：高质量+多说话人
**模型**: VITS-AISHELL3
- ✅ 质量最好+多说话人
- ✅ 包含男声和女声
- ⚠️ 模型较大（约500MB）
- ⚠️ 推理速度略慢

---

## 💡 最终建议

### 如果只需要女声
**保持当前方案**：FastSpeech2-CSMSC + PWG-CSMSC
- 已测试成功
- 质量和速度平衡好
- 部署简单

### 如果需要男声
**下载AISHELL3模型**：FastSpeech2-AISHELL3 + PWG-AISHELL3
- 支持多说话人
- 可以选择男声ID
- 需要测试找到合适的男声

### 如果追求最高质量
**使用VITS模型**：VITS-CSMSC（女声）或 VITS-AISHELL3（多说话人）
- 语音质量最好
- 端到端模型
- 推理速度可接受

---

## 📝 下一步行动

1. **确认需求**：是否需要男声？
2. **如果需要男声**：
   - 下载AISHELL3模型
   - 测试不同的说话人ID
   - 找到合适的男声ID
3. **如果只需女声**：
   - 保持当前方案
   - 或升级到VITS-CSMSC获得更高质量

---

**Sources**:
- [PaddleSpeech GitHub](https://github.com/PaddlePaddle/PaddleSpeech)
- [PaddleSpeech Model Zoo](https://github.com/PaddlePaddle/PaddleSpeech/blob/develop/docs/source/released_model.md)
