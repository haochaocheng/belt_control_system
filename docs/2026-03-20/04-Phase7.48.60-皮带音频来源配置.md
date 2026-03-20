# Phase 7.48.60 - 皮带音频来源配置

## 问题描述

CommonControl 在起车/停车时查找音频文件使用的是硬编码路径 `/app/AUDIO/1#PD/`，而批量合成生成的 TTS 文件输出到 `/home/linaro/belt-control-data/audio/paddlespeech-xxx/1#PD/`，两个路径不一致，导致起车预警语音始终找不到 TTS 合成的音频文件。

## 解决方案

在基本配置 → 基本参数设置中新增**音频来源**配置项：
- `0 = 默认（/app/AUDIO/）`：使用原有硬编码路径
- `1 = TTS合成`：使用当前TTS引擎/模型/说话人对应的路径

## 修改文件

### 1. `src/control/SystemConfig.h`
- 新增 `Q_PROPERTY(int beltAudioSource ...)`
- 新增 getter `beltAudioSource()`、setter 声明 `setBeltAudioSource()`
- 新增信号 `beltAudioSourceChanged()`
- 新增私有成员 `int m_beltAudioSource = 0`

### 2. `src/control/SystemConfig.cpp`
- 实现 `setBeltAudioSource(int source)`
- `saveConfig()`：在 `SystemSettings` 组保存 `beltAudioSource`
- `loadConfig()`：加载 `beltAudioSource`，发送 `beltAudioSourceChanged()`

### 3. `src/control/CommonControl.cpp`
- 新增 `#include "DataPathConfig.h"`
- 修改 `getAudioPath()`：
  - 若 `m_systemConfig->beltAudioSource() == 1`，先尝试 TTS 路径
  - TTS 路径格式：`{audioBase}/paddlespeech-{model}-spk{id}/{N}#PD/{fileName}`
  - 未找到则回退到默认 `/app/AUDIO/{N}#PD/` 路径

### 4. `src/qml/components/parameter_settings/BasicParametersSection.qml`
- 在"终端投入"后新增"音频来源"下拉框（绑定到 `systemConfig.beltAudioSource`）

### 5. `src/qml/components/device_info/pages/BasicConfigPage.qml`
- `basicParams` 新增 `beltAudioSource: 0`
- `saveBasicParams()`：保存到 SQLite + 同步到 C++ systemConfig + 调用 `systemConfig.saveConfig()`
- `loadBasicParams()`：从 SQLite 加载 + 同步到 C++ systemConfig

### 6. `src/control/BatchAudioGenerator.cpp`
- 修改 `generateBeltOperationTasks()`：
  - "皮带启动"操作的 TTS 文字改为自然语言格式："一号皮带准备启动，注意安全"
  - 使用中文数字（一/二/.../八）
  - 文件名保持不变（`1号皮带启动.wav`）

## 路径对应关系

| 来源 | 路径格式 | 示例 |
|------|----------|------|
| 默认 | `/app/AUDIO/{N}#PD/{file}` | `/app/AUDIO/1#PD/1号皮带启动.wav` |
| TTS合成 | `{audioBase}/paddlespeech-{model}-spk{id}/{N}#PD/{file}` | `/home/linaro/belt-control-data/audio/paddlespeech-fastspeech2_csmsc-spk0/1#PD/1号皮带启动.wav` |

## 批量合成TTS文字对比

| 操作 | 旧TTS文字 | 新TTS文字 |
|------|-----------|-----------|
| 皮带启动 | `1号皮带启动` | `一号皮带准备启动，注意安全` |
| 皮带停车 | `1号皮带停车` | `1号皮带停车`（不变） |
| 皮带运行失败 | `1号皮带运行失败` | `1号皮带运行失败`（不变） |
| 皮带通讯失败 | `1号皮带通讯失败` | `1号皮带通讯失败`（不变） |
| 皮带启动请注意 | `1号皮带启动请注意` | `1号皮带启动请注意`（不变） |
