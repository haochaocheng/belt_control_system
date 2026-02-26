# Phase 7.47.8 - 修复 TTS 模型路径不一致问题

**创建时间**: 2026-02-26 12:30
**问题类型**: Bug 修复
**优先级**: 高
**状态**: ✅ 已完成

---

## 📋 问题描述

PaddleSpeech TTS 合成失败，日志显示：
```
⚠️ 使用容器内模型路径（回退方案）
RuntimeError: Download from https://paddlespeech.cdn.bcebos.com/.../fastspeech2_nosil_aishell3_ckpt_0.4.zip failed
```

---

## 🔍 问题诊断

### 日志分析

1. **启动日志**（第 56-59 行）：
```
⚠️ 使用容器内模型路径（回退方案）
📂 PADDLESPEECH_HOME: /app/tts_models/paddlespeech
```

2. **合成失败**（第 964 行）：
```
Download from https://paddlespeech.cdn.bcebos.com/...fastspeech2_nosil_aishell3_ckpt_0.4.zip failed
```

### 根本原因

**路径不一致！**

| 组件 | 错误路径 | 正确路径 |
|------|----------|----------|
| app-entrypoint.sh | `/home/linaro/belt-control-data/models/tts_models/paddlespeech` | `/home/linaro/belt-control-data/tts_models/paddlespeech` |
| PaddleSpeechAdapter.cpp | `/home/linaro/belt-control-data/models/tts_models/paddlespeech` | `/home/linaro/belt-control-data/tts_models/paddlespeech` |
| paddle_tts_service.py | `/home/linaro/belt-control-data/models/tts_models/paddlespeech` | `/home/linaro/belt-control-data/tts_models/paddlespeech` |
| 同步脚本 | - | `/home/linaro/belt-control-data/tts_models` |

**问题**：代码中多了一层 `models` 目录，与同步脚本的目标路径不匹配。

---

## 🔧 解决方案

移除路径中多余的 `models` 层级。

### 修改 1：app-entrypoint.sh

```bash
# 错误
/home/linaro/belt-control-data/models/tts_models/paddlespeech/models

# 正确
/home/linaro/belt-control-data/tts_models/paddlespeech/models
```

### 修改 2：PaddleSpeechAdapter.cpp

```cpp
// 错误
if (QDir("/home/linaro/belt-control-data/models/tts_models/paddlespeech").exists())

// 正确
if (QDir("/home/linaro/belt-control-data/tts_models/paddlespeech").exists())
```

### 修改 3：paddle_tts_service.py

```python
# 错误
'/home/linaro/belt-control-data/models/tts_models/paddlespeech'

# 正确
'/home/linaro/belt-control-data/tts_models/paddlespeech'
```

---

## 📁 修改文件清单

| 文件 | 修改内容 |
|------|----------|
| `docker/rk3588/app-entrypoint.sh` | 修复 PaddleSpeech 和 PaddleNLP 路径检测 |
| `src/control/tts/PaddleSpeechAdapter.cpp` | 修复 PADDLESPEECH_HOME 路径检测 |
| `docker/rk3588/tts_engines/paddlespeech/paddle_tts_service.py` | 修复自动检测路径 |

---

## 🧪 测试计划

### 测试步骤

1. **重新编译部署**
   ```powershell
   .\build-ubuntu24-apt.ps1 185
   ```

2. **查看启动日志**
   - 预期看到：`✅ 检测到 linaro 用户模型路径`
   - 而不是：`⚠️ 使用容器内模型路径（回退方案）`

3. **TTS 合成测试**
   - 选择 `fastspeech2_aishell3` 模型
   - 输入测试文本
   - 点击"生成测试语音"

### 预期结果

- ✅ 启动时检测到正确的模型路径
- ✅ 合成成功，不再尝试网络下载
- ✅ 生成的音频文件可正常播放

---

## 📊 路径对照表

### 正确的路径结构

```
/home/linaro/belt-control-data/
├── tts_models/
│   ├── paddlespeech/
│   │   └── models/
│   │       ├── fastspeech2_csmsc-zh/
│   │       ├── fastspeech2_aishell3-zh/
│   │       ├── hifigan_csmsc-zh/
│   │       ├── hifigan_aishell3-zh/
│   │       └── G2PWModel_1.1/
│   └── paddlenlp/
│       └── bert-base-chinese/
└── audio/
    └── ...
```

### 同步脚本路径

```powershell
# 源目录
libs/tts_models/

# 目标目录
/home/linaro/belt-control-data/tts_models/
```

---

**文档版本**: v1.0
**最后更新**: 2026-02-26 12:35
