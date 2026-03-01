# Phase 7.47.55-58 - pi设备TTS合成与音频来源切换修复

**日期**: 2026-03-01
**设备**: pi@192.168.10.186
**阶段**: Phase 7.47.55 ~ 7.47.58

---

## 一、问题概述

在 pi@186 设备上部署后，发现以下问题：
1. 批量语音合成失败（TTS引擎无法合成）
2. 切换"默认/TTS合成"音频来源后，触发保护时不按设置播放
3. 保存按钮点击后数据未写入数据库

---

## 二、Phase 7.47.55 - 修复pi设备TTS批量合成失败

**提交**: `79e87334`

### 问题1：QML outputBaseDir 路径错误

**现象**: 批量合成输出路径为 `/home/linaro/...`，pi 设备应为 `/home/pi/...`

**根因**: `BatchSynthesisContent.qml` 的 `getOutputBaseDir()` 使用 `process.env.BELT_CONTROL_USER`（Node.js API），QML 不支持该 API，永远回退到硬编码的 `"linaro"`。

**修复**:
- `main.cpp`: 新增 `setContextProperty("audioBaseDir", DataPathConfig::getAudioBaseDirectory())`
- `BatchSynthesisContent.qml`: `getOutputBaseDir()` 改为直接返回 C++ 注入的 `audioBaseDir`

### 问题2：PaddleSpeech vocoder 下载失败

**现象**: 合成时报错 `Download from https://paddlespeech.cdn.bcebos.com/.../hifigan_csmsc_ckpt_0.1.1.zip failed`

**根因**: PaddleSpeech 的 `download_and_decompress` 函数检查 zip 文件是否存在于 `/root/.paddlespeech/models/hifigan_csmsc-zh/1.0/` 目录下。pi 设备有解压后的模型文件但缺少 zip 文件，触发网络下载，但设备无网络（DNS 解析失败）。

**修复**: 在 `paddle_tts_service.py` 中新增 `VOC_PATH_MAP` 和 `AM_PATH_MAP`，直接传入 `voc_config`/`voc_ckpt`/`voc_stat` 和 `am_config`/`am_ckpt`/`am_stat` 本地路径参数，完全绕过 PaddleSpeech 的下载机制。

---

## 三、Phase 7.47.56 - 修复默认音频来源仍播放TTS

**提交**: `8b6c0224`

**现象**: 用户在 UI 点击"默认"并保存后，触发通道0仍播放 TTS 合成音频。

**根因**（通过查询 pi 设备 DB 验证）:
1. `schema_migrations` 表不存在 → Phase 7.47.52 的 `runMigrations()` 未部署，DB 中 96 条记录 `use_text_to_speech` 全部为 `1`
2. `MqttProtectionMonitor.cpp` Line 151: `protection.value("use_text_to_speech", 1)` 默认回退值为 `1`（TTS）

**修复**:
- 代码: 默认回退值从 `1` 改为 `0`
- pi 设备 DB: 通过 Python 直接将 96 条记录重置为 `0`，创建 `schema_migrations` 表

---

## 四、Phase 7.47.57 - 修复保存按钮未调用保存函数

**提交**: `8b16d423`

**现象**: 用户切换到"TTS合成"并点击保存，再次触发仍播放默认音频。

**根因**: `DeviceSettingsDialog.qml` 保存按钮的 `case 1`（开关量输入）是空的：
```javascript
case 1:  // 开关量输入
    // TODO: 调用开关量输入的保存函数
    break
```
从未调用保存函数，用户点保存后数据根本没写入 DB。

**修复**: `case 1` 中调用 `switchInputPageLoader.item.saveCurrentProtection()`

---

## 五、Phase 7.47.58 - 修正保存函数名

**提交**: `ef984e8f`

**现象**: Phase 7.47.57 部署后，保存仍然无效。

**根因**: Phase 7.47.57 调用的函数名 `saveCurrentProtection()` 在 `SwitchInputPage.qml` 中不存在，实际函数名是 `saveProtectionData()`。`typeof` 检查返回 `undefined`，条件不满足，静默跳过。

**修复**: `saveCurrentProtection()` → `saveProtectionData()`

---

## 六、修改文件清单

| 文件 | Phase | 修改说明 |
|------|-------|----------|
| `src/main/main.cpp` | 7.47.55 | 注入 `audioBaseDir` 到 QML context |
| `src/qml/pages/BatchSynthesisContent.qml` | 7.47.55 | `getOutputBaseDir()` 使用 C++ 注入值 |
| `docker/rk3588/tts_engines/paddlespeech/paddle_tts_service.py` | 7.47.55 | 本地模型路径映射，绕过下载 |
| `src/control/MqttProtectionMonitor.cpp` | 7.47.56 | `use_text_to_speech` 默认回退值 1→0 |
| `src/qml/components/device_info/DeviceSettingsDialog.qml` | 7.47.57/58 | 保存按钮调用 `saveProtectionData()` |

---

## 七、验证结果

✅ pi@186 设备测试通过：
- 批量语音合成：8条皮带×8个保护 = 64个音频文件全部合成成功
- 默认音频来源：播放 `{machineNumber}#PD/沿线急停.mp3`
- TTS合成来源：播放 `paddlespeech-fastspeech2_csmsc-spk0/{machineNumber}#PD/沿线急停.wav`
- 自由切换：保存后立即生效，可在默认和TTS之间自由切换
