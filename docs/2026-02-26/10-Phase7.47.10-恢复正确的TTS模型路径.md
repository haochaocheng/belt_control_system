# Phase 7.47.10 - 恢复正确的 TTS 模型路径

**创建时间**: 2026-02-26 14:30
**问题类型**: Bug 修复
**优先级**: 高
**状态**: ✅ 已完成

---

## 📋 问题描述

Phase 7.47.8 修改后，TTS 合成仍然失败。经过设备实际路径检查，发现路径配置错误。

---

## 🔍 设备实际路径

通过 SSH 检查设备实际目录结构：

```
/home/linaro/belt-control-data/
├── appdata/
├── audio/
├── models/
│   ├── asr_models/
│   ├── melotts/
│   └── tts_models/          ← 实际位置
│       ├── paddlenlp/
│       │   └── bert-base-chinese/
│       ├── paddlespeech/
│       │   ├── conf/
│       │   ├── datasets/
│       │   └── models/      ← fastspeech2_aishell3 等模型
│       └── sherpa-onnx-vits-zh-ll/
└── tts_models/              ← 空目录（Phase 7.47.8 错误创建）
```

**正确路径**: `/home/linaro/belt-control-data/models/tts_models/paddlespeech/`

---

## 🔧 修复内容

### 1. app-entrypoint.sh

```bash
# 修复前（Phase 7.47.8 错误）
/home/linaro/belt-control-data/tts_models/paddlespeech/models

# 修复后（Phase 7.47.10 正确）
/home/linaro/belt-control-data/models/tts_models/paddlespeech/models
```

### 2. PaddleSpeechAdapter.cpp

```cpp
// 修复前
"/home/linaro/belt-control-data/tts_models/paddlespeech"

// 修复后
"/home/linaro/belt-control-data/models/tts_models/paddlespeech"
```

### 3. paddle_tts_service.py

```python
# 修复前
'/home/linaro/belt-control-data/tts_models/paddlespeech'

# 修复后
'/home/linaro/belt-control-data/models/tts_models/paddlespeech'
```

### 4. 02-sync-tts-models.ps1

```powershell
# 修复前
/home/linaro/belt-control-data/tts_models

# 修复后
/home/linaro/belt-control-data/models/tts_models
```

---

## 📁 修改文件清单

| 文件 | 修改内容 |
|------|----------|
| `docker/rk3588/app-entrypoint.sh` | 恢复 PaddleSpeech/PaddleNLP 正确路径 |
| `src/control/tts/PaddleSpeechAdapter.cpp` | 恢复 PADDLESPEECH_HOME 正确路径 |
| `docker/rk3588/tts_engines/paddlespeech/paddle_tts_service.py` | 恢复自动检测正确路径 |
| `scripts/2026-02-13/02-sync-tts-models.ps1` | 修复同步目标路径 |

---

## 📊 路径对照表

| 组件 | 正确路径 |
|------|----------|
| PaddleSpeech 模型 | `/home/linaro/belt-control-data/models/tts_models/paddlespeech/` |
| PaddleNLP 模型 | `/home/linaro/belt-control-data/models/tts_models/paddlenlp/` |
| PADDLESPEECH_HOME | `/home/linaro/belt-control-data/models/tts_models/paddlespeech` |
| 同步脚本目标 | `/home/linaro/belt-control-data/models/tts_models/` |

---

## 🧪 验证步骤

1. 重新编译部署
2. 检查启动日志，应显示：
   ```
   ✅ 检测到 linaro 用户模型路径
   📂 模型基础路径: /home/linaro/belt-control-data/models/tts_models/paddlespeech/models
   📂 PADDLESPEECH_HOME: /home/linaro/belt-control-data/models/tts_models/paddlespeech
   ```
3. 测试 TTS 合成功能

---

**文档版本**: v1.0
**最后更新**: 2026-02-26 14:35
