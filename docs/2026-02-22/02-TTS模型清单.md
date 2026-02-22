# TTS 模型清单

**时间**: 2026-02-22 04:10
**目录**: `tts_models/`
**总大小**: 约 6.1 GB

## 模型总览

| 引擎 | 目录 | 大小 | 状态 |
|------|------|------|------|
| MeloTTS | `melotts/` | 397 MB | ✅ 可用 |
| PaddleSpeech | `paddlespeech/` | 2.3 GB | ⚠️ 部分可用 |
| Piper | `piper/` | 61 MB | ✅ 可用 |
| Coqui | `coqui/` | 655 MB | ❓ 未测试 |
| PaddleNLP | `paddlenlp/` | 108 KB | ✅ 辅助文件 |

---

## 1. MeloTTS 模型

| 模型 | 目录 | 语言 | 说明 |
|------|------|------|------|
| MeloTTS-Chinese | `melotts/MeloTTS-Chinese/` | 中文 | 中文语音合成 |
| MeloTTS-English | `melotts/MeloTTS-English/` | 英文 | 英文语音合成 |

**总大小**: 397 MB

---

## 2. PaddleSpeech 模型

### 已部署模型

| 模型 | 目录 | 大小 | 语言 | 说明 |
|------|------|------|------|------|
| fastspeech2_csmsc | `paddlespeech/models/fastspeech2_csmsc-zh/` | 1.1 GB | 中文 | 单说话人女声（官方默认） |
| pwgan_csmsc | `paddlespeech/models/pwgan_csmsc-zh/` | 32 MB | 中文 | 声码器（配合 csmsc 使用） |
| G2PWModel_1.1 | `paddlespeech/models/G2PWModel_1.1/` | 608 MB | 中文 | 中文文本转拼音模型 |

### 未部署模型（QML 界面显示但无法使用）

| 模型 | 需要下载 | 大小（估计） | 语言 | 说明 |
|------|----------|--------------|------|------|
| fastspeech2_aishell3 | ❌ 未下载 | ~200 MB | 中文 | 多说话人（218人） |
| pwgan_aishell3 | ❌ 未下载 | ~50 MB | 中文 | 声码器（配合 aishell3 使用） |
| fastspeech2_ljspeech | ❌ 未下载 | ~200 MB | 英文 | 单说话人 |
| hifigan_ljspeech | ❌ 未下载 | ~50 MB | 英文 | 声码器（配合 ljspeech 使用） |
| fastspeech2_vctk | ❌ 未下载 | ~200 MB | 英文 | 多说话人（109人） |

**总大小**: 2.3 GB（已部署）

---

## 3. Piper 模型

| 模型 | 文件 | 大小 | 语言 | 说明 |
|------|------|------|------|------|
| zh_CN-huayan-medium | `piper/zh_CN-huayan-medium.onnx` | 61 MB | 中文 | ONNX 格式 |

**总大小**: 61 MB

---

## 4. Coqui 模型

| 模型 | 目录 | 大小 | 语言 | 说明 |
|------|------|------|------|------|
| tacotron2-DDC-GST | `coqui/tts_models--zh-CN--baker--tacotron2-DDC-GST/` | 655 MB | 中文 | Baker 数据集训练 |

**总大小**: 655 MB

---

## 5. PaddleNLP 辅助文件

| 文件 | 目录 | 大小 | 用途 |
|------|------|------|------|
| vocab.txt | `paddlenlp/bert-base-chinese/` | 108 KB | G2PW BertTokenizer 词表 |

---

## 6. 其他目录

| 目录 | 大小 | 说明 |
|------|------|------|
| `fastspeech2_vctk_ckpt_1.2.0/` | 429 MB | VCTK 模型（独立目录，未集成） |
| `paddlespeech_all/` | 0 | 空目录 |
| `paddlespeech_offline/` | 2.3 GB | paddlespeech 的备份/副本 |

---

## 当前可用模型

### PaddleSpeech 引擎
- ✅ fastspeech2_csmsc（中文女声）- 可正常合成
- ❌ fastspeech2_aishell3（中文多说话人）- 模型未下载
- ❌ fastspeech2_ljspeech（英文）- 模型未下载
- ❌ fastspeech2_vctk（英文多说话人）- 模型未下载

### MeloTTS 引擎
- ✅ MeloTTS-Chinese（中文）
- ✅ MeloTTS-English（英文）

### Piper 引擎
- ✅ zh_CN-huayan-medium（中文）

---

## 下一步

如需使用 aishell3 等其他 PaddleSpeech 模型，需要：
1. 下载对应的声学模型和声码器
2. 部署到设备的 `/home/pi/belt-control-data/models/tts_models/paddlespeech/models/`
3. 在 `app-entrypoint.sh` 中添加符号链接
