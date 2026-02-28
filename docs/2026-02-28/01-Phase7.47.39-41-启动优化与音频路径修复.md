# Phase 7.47.39-41 - 启动优化与音频路径命名修复

## 修改日期
2026-02-28

## 修改概述

本次修改包含三个问题的修复：

### Phase 7.47.39 - TTS引擎异步初始化（启动优化）

**问题**：程序启动时，TTSConfigSection.qml 的 `Component.onCompleted` 同步调用 `switchTTSModel(0)` → `PaddleSpeechAdapter::initialize()` → `sendCommand()`，阻塞主线程 5-10 分钟，导致 UI 启动卡住。

**原因**：PaddleSpeech Python 服务首次加载模型需要较长时间（导入 Paddle 框架 + 加载模型权重 + ONNX Runtime 初始化），整个调用链都是同步的。

**修复方案**：
1. `CommonControl.h/.cpp` - 新增 `switchTTSModelAsync(int)` 方法，使用 `QThread::create()` 在后台线程执行初始化
2. `CommonControl.h` - 新增 `ttsModelSwitchCompleted(bool, int)` 信号，初始化完成后通知 QML
3. `TTSConfigSection.qml` - 添加 `_startupComplete` 标志，防止组件加载时触发同步初始化
4. `TTSConfigSection.qml` - `Component.onCompleted` 改为调用 `switchTTSModelAsync(0)`
5. `TTSConfigSection.qml` - `modelComboBox.onCurrentIndexChanged` 改为异步调用

**效果**：UI 立即加载可用，TTS 在后台线程初始化。

### Phase 7.47.40 - TTSConfigManager模型名修复

**问题**：AudioPathMapper 生成音频路径 `paddlespeech-vits-zh-aishell3-spk0/1#PD/急停保护.wav`，但实际 PaddleSpeech 模型是 `fastspeech2_csmsc`，文件夹名不匹配导致找不到文件。

**原因**：TTSConfigManager 的 MODEL_NAMES 仍是旧的 Sherpa ONNX VITS 引擎模型名（`vits-zh-aishell3` 等 7 个），而系统已切换为 PaddleSpeech 引擎。AudioPathMapper 从 TTSConfigManager 读取模型名生成路径，与批量生成的文件夹名不一致。

**修复**：
- `TTSConfigManager.cpp` - MODEL_NAMES 从 7 个旧 VITS 模型更新为 2 个 PaddleSpeech 模型
  - 索引 0: `fastspeech2_csmsc`（中文女声，单说话人）
  - 索引 1: `fastspeech2_aishell3`（中文多说话人，174 speakers）
- MODEL_PATHS 更新为 PaddleSpeech 实际路径
- MODEL_MAX_SPEAKER_IDS 更新为正确的说话人数量
- `loadConfig()` 添加索引越界保护（防止旧配置的索引 2-6 导致崩溃）

### Phase 7.47.41 - BatchAudioGenerator文件命名统一

**问题**：BatchAudioGenerator 生成的文件名与 AudioPathMapper 查找的文件名不一致。

| | AudioPathMapper（播放时查找） | BatchAudioGenerator（生成时创建） |
|---|---|---|
| 保护名来源 | VoiceFileList（33项） | 硬编码（8项） |
| 文件名 | `急停保护.wav` | `1号皮带沿线急停保护.wav` |
| 保护名称 | `急停保护` | `沿线急停保护` |

**修复**：
- BatchAudioGenerator 所有 generate 方法统一使用 VoiceFileList 作为保护名称数据源
- 文件名格式改为 `{保护名}.wav`，与 AudioPathMapper 一致
- TTS 合成文本保持完整（如 `1号皮带急停保护`），仅文件名去掉皮带号前缀

## 修改文件清单

| 文件 | 修改内容 |
|------|---------|
| `src/control/CommonControl.h` | 新增 `#include <QThread>`、`switchTTSModelAsync()`、`ttsModelSwitchCompleted` 信号 |
| `src/control/CommonControl.cpp` | 新增 `switchTTSModelAsync()` 实现（QThread后台执行） |
| `src/qml/components/voice_management/TTSConfigSection.qml` | 添加 `_startupComplete` 标志，异步初始化，信号回调 |
| `src/control/TTSConfigManager.cpp` | MODEL_NAMES/PATHS/MAX_SPEAKER_IDS 更新为 PaddleSpeech 模型，添加索引越界保护 |
| `src/control/BatchAudioGenerator.cpp` | 所有 generate 方法改用 VoiceFileList，统一文件命名格式 |

## 验证方法

1. 程序启动后 UI 应立即可用，不再卡住等待 TTS 初始化
2. TTS 初始化在后台完成后，进度条显示完成
3. MQTT 触发保护时，AudioPathMapper 生成的路径应为 `paddlespeech-fastspeech2_csmsc-spk0/1#PD/急停保护.wav`
4. 批量生成的文件名应与上述路径完全匹配
