# Phase 7.47.7 - Python服务自动检测PADDLESPEECH_HOME

**创建时间**: 2026-02-26 11:00
**问题类型**: Bug 修复
**优先级**: 高
**状态**: ✅ 已完成

---

## 📋 问题描述

Phase 7.47.6 修复后，TTS 合成仍然失败，日志显示：
```
RuntimeError: Download from https://paddlespeech.cdn.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_nosil_aishell3_ckpt_0.4.zip failed. Retry limit reached
```

---

## 🔍 问题诊断

### 日志分析

```
[DEBUG] 🔍 current_model = 'fastspeech2_aishell3'
[DEBUG] 📝 使用原始模型名称: fastspeech2_aishell3
[WARNING] ⚠️ [PaddleSpeech] 命令超时
[WARNING] ❌ [PaddleSpeech] 合成命令失败
[WARNING] ❌ [CommonControl] TTS 合成失败
```

### 根本原因

1. **C++ 端已设置环境变量** - `PaddleSpeechAdapter.cpp` 中已添加 `PADDLESPEECH_HOME` 设置
2. **Python 服务未主动使用** - Python 服务没有检查或打印环境变量
3. **PaddleSpeech 库行为** - 即使设置了环境变量，PaddleSpeech 可能在某些情况下仍尝试下载

---

## 🔧 解决方案

在 Python 服务启动时主动检查并设置 `PADDLESPEECH_HOME` 环境变量。

**文件**: `docker/rk3588/tts_engines/paddlespeech/paddle_tts_service.py`

**修改内容**:

```python
# ✅ 2026-02-26 11:00 [Phase 7.47.7]: 检查并设置 PADDLESPEECH_HOME 环境变量
# 原因：确保 PaddleSpeech 使用本地模型，避免网络下载
paddlespeech_home = os.environ.get('PADDLESPEECH_HOME', '')
logger.info(f"📂 PADDLESPEECH_HOME 环境变量: '{paddlespeech_home}'")

if not paddlespeech_home:
    # 自动检测模型路径
    possible_paths = [
        '/home/linaro/belt-control-data/models/tts_models/paddlespeech',
        '/home/pi/belt-control-data/models/tts_models/paddlespeech',
        '/app/tts_models/paddlespeech'
    ]
    for path in possible_paths:
        if os.path.exists(os.path.join(path, 'models')):
            paddlespeech_home = path
            os.environ['PADDLESPEECH_HOME'] = paddlespeech_home
            logger.info(f"✅ 自动设置 PADDLESPEECH_HOME={paddlespeech_home}")
            break
    if not paddlespeech_home:
        logger.warning("⚠️ 未找到本地模型路径，PaddleSpeech 可能会尝试下载模型")
else:
    logger.info(f"✅ 使用环境变量 PADDLESPEECH_HOME={paddlespeech_home}")
```

---

## 📁 修改文件清单

| 文件 | 修改内容 |
|------|----------|
| `docker/rk3588/tts_engines/paddlespeech/paddle_tts_service.py` | 添加环境变量检查和自动设置 |

---

## 🧪 测试计划

### 测试步骤

1. **重新编译部署**
   ```powershell
   .\build-ubuntu24-apt.ps1 185
   ```

2. **查看日志**
   - 预期看到：`📂 PADDLESPEECH_HOME 环境变量: '/home/linaro/...'`
   - 或：`✅ 自动设置 PADDLESPEECH_HOME=...`

3. **TTS 合成测试**
   - 选择 `fastspeech2_aishell3` 模型
   - 输入测试文本
   - 点击"生成测试语音"

### 预期结果

- ✅ 日志显示正确的 PADDLESPEECH_HOME 路径
- ✅ 合成成功，不再尝试网络下载
- ✅ 生成的音频文件可正常播放

---

## 📊 技术说明

### 为什么需要在 Python 端也设置

1. **双重保险** - C++ 和 Python 两端都设置，确保万无一失
2. **调试便利** - Python 端打印日志，便于确认环境变量是否正确传递
3. **自动检测** - 如果 C++ 端传递失败，Python 端可以自动检测并设置

### 路径检测优先级

1. `/home/linaro/belt-control-data/models/tts_models/paddlespeech` - linaro 用户设备
2. `/home/pi/belt-control-data/models/tts_models/paddlespeech` - pi 用户设备
3. `/app/tts_models/paddlespeech` - 容器内路径（回退方案）

---

## 📝 Git 提交记录

```
commit b94bbd71
fix: Phase 7.47.7 - Python服务自动检测PADDLESPEECH_HOME

- 在Python服务启动时检查PADDLESPEECH_HOME环境变量
- 如果未设置，自动检测linaro/pi/容器内模型路径
- 添加详细日志输出，便于调试
```

---

**文档版本**: v1.0
**最后更新**: 2026-02-26 11:10
