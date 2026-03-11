# Phase 7.48.37 - 电机基本配置新增参数与语音修复

## 修改日期
2026-03-11

## 修改概述
电机基本配置Tab新增4个参数（启动延时、预警语音、失败语音、启动键），修复运行失败报警不播放问题，修复TTS引擎选择错误，完善批量语音生成。

## 修改内容

### 1. BasicConfigTab 新增4个参数
**文件**: `src/qml/components/device_info/pages/BasicConfigTab.qml`

| 参数 | 控件类型 | 默认值 | 说明 |
|------|---------|--------|------|
| 启动延时 | CustomSpinBox (0-60秒) | 5秒 | 电机启动前的延时等待 |
| 预警语音 | TextField | 电机X启动 | 音频文件名（不含.wav） |
| 失败��音 | TextField | 电机X失败 | 音频文件名（不含.wav） |
| 启动键 | ComboBox | 无 | 键盘按键选择（F1-F12/数字/字母） |

- 焦点索引从10扩展到14（新增索引7-10）
- 状态指示区域行号从 row 4/5/6 调整为 row 6/7/8
- 测试操作区域行号从 row 7/8/9 调整为 row 9/10/11
- collectConfig/applyConfig 同步扩展

### 2. 修复运行失败报警不播放
**问题**: `TypeError: Property 'playAlarmByName' of object CommonControl is not a function`
**原因**: CommonControl 没有 `playAlarmByName` 方法
**修复**: 改用已注册到 QML context 的 `alarmPlayback.playAlarm()`

### 3. 音频文件名与TTS文字分离
**旧逻辑**: 预警/失败语音字段存TTS文字，直接用TTS合成播放
**新逻辑**: 字段存音频文件名，播放时先查找 `{audioBaseDir}/{皮带号}#PD/{文件名}.wav`，找不到回退TTS合成

| 语音类型 | 音频文件名 | TTS回退文字 |
|---------|-----------|------------|
| 预警语音 | 电机1启动.wav | X号皮带X号电机准备启动，请注意安全 |
| 失败语音 | 电机1失败.wav | X号皮带X号电机运行失败 |

### 4. 修复AlarmPlaybackService TTS引擎选择
**问题**: AlarmPlaybackService 内部硬编码使用 SherpaOnnxTTS，应使用 PaddleSpeech
**修复**:
- `AlarmPlaybackService.h` 新增 `setTTSEngineManager()` 方法和 `m_ttsEngineManager` 成员
- `AlarmPlaybackService.cpp` 的 `playTtsText()` 优先使用 TTSEngineManager（PaddleSpeech）合成到临时文件再播放，失败回退 SherpaOnnxTTS
- `main.cpp` 注入 `commonControl.getTTSEngineManager()`

### 5. 批量语音生成扩展
**文件**: `src/control/BatchAudioGenerator.cpp`
- 电机保护 DEFS 从14项扩展到15项（新增"启动预警"）
- 文件名格式: `电机X启动.wav`、`电机X失败.wav`
- TTS文字: "X号皮带X号电机准备启动，请注意安全"、"X号皮带X号电机运行失败"

**文件**: `src/qml/pages/BatchSynthesisContent.qml`
- 统计计数从14更新为15

**文件**: `src/control/tts/VoiceFileList.h`
- MotorVoice::PROTECTION_ITEMS 从12项扩展到14项

### 6. 数据库迁移016
**文件**: `src/control/DeviceConfigManager.cpp`
- 新增4列: `startup_delay`, `warning_voice`, `failure_voice`, `startup_key`
- saveMotorConfig 从31列扩展到35列
- initDefaultMotorConfigs 从19列扩展到23列
- 迁移自动为 Tab 0 设置默认音频文件名

## 修改文件清单
| 文件 | 修改类型 |
|------|---------|
| BasicConfigTab.qml | 新增4参数 + 报警修复 + 音频文件名分离 |
| DeviceConfigManager.cpp | 迁移016 + saveMotorConfig 35列 + initDefault 23列 |
| AlarmPlaybackService.h | 新增 TTSEngineManager 注入 |
| AlarmPlaybackService.cpp | playTtsText 优先 PaddleSpeech |
| main.cpp | 注入 TTSEngineManager |
| VoiceFileList.h | 电机语音14项 |
| BatchAudioGenerator.cpp | 批量生成15项 |
| BatchSynthesisContent.qml | 统计15项 |
