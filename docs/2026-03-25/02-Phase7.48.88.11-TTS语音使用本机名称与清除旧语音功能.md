# Phase 7.48.88.11 - TTS语音使用本机名称与清除旧语音功能

## 日期
2026-03-25

## 问题描述

### 问题1：TTS语音使用硬编码"N号皮带"
- 所有TTS语音文字和文件名都硬编码为 `{N}号皮带`（如"2号皮带启车"）
- 但 `SystemConfig.localDeviceName` 支持自定义名称（如"大巷皮带"、"顺槽皮带"）
- 当用户将本机名称配置为非默认值时，TTS语音内容与实际设备名不匹配

### 问题2：皮带名称变更后旧语音文件阻碍重新生成
- 批量生成机制：`skipExisting=true` 时，如果文件已存在则跳过
- 皮带名称从"2号皮带"改为"大巷皮带"后：
  - 旧文件 `2号皮带启车.wav` 仍存在
  - 新文件 `大巷皮带启车.wav` 不存在但也不会生成（因为旧文件占位）
  - 需要手动删除旧文件才能重新生成

## 修改方案

### 1. TTSBatchConfig.h - 增加皮带名称映射
```cpp
QMap<int, QString> beltNames;  // {1: "大巷皮带", 2: "顺槽皮带"}
```

### 2. TTSBatchGenerator.cpp - 批量生成使用自定义名称
- `setConfig()`: 解析 `beltNames` 参数
- `buildBeltOperationList()`: 使用 `beltNames[belt]` 生成文件名和TTS文字
  - 文件名：`大巷皮带启车.wav`（而非 `1号皮带启车.wav`）
  - TTS文字：`大巷皮带准备启车，请注意安全`

### 3. CommonControl.cpp - 预警语音使用本机名称
- `playWarningOnce()`:
  - 当前皮带 == 本机皮带号 → 使用 `localDeviceName`
  - 远程控制其他皮带 → 使用默认 `{N}号皮带`
- `getAudioPath()`: 文件搜索优先匹配 `{localDeviceName}{action}.wav`

### 4. BatchSynthesisContent.qml - 传递名称 + 清除旧语音
- `getConfig()`: 构建 `beltNames` 映射传递给后端
- 新增"清除旧语音"GroupBox：
  - 可选分类：皮带操作状态、开关量输入保护、系统提示音
  - 点击清除按钮删除对应分类的旧文件
  - 删除后再批量生成即可产生新名称的文件

### 5. TTSBatchGenerator - 新增 clearCategoryFiles()
- `Q_INVOKABLE int clearCategoryFiles(const QStringList &categories)`
- 遍历引擎目录下的皮带文件夹，按分类匹配文件名删除
- 返回删除的文件数量

## 修改文件清单

| 文件 | 修改内容 |
|------|---------|
| `src/control/tts/TTSBatchConfig.h` | 增加 `QMap<int, QString> beltNames` |
| `src/control/tts/TTSBatchGenerator.h` | 声明 `clearCategoryFiles()` |
| `src/control/tts/TTSBatchGenerator.cpp` | 解析beltNames、使用自定义名称、实现clearCategoryFiles |
| `src/control/CommonControl.cpp` | playWarningOnce使用localDeviceName、getAudioPath优先匹配自定义名 |
| `src/qml/pages/BatchSynthesisContent.qml` | 传递beltNames、新增清除旧语音UI |

## 音频搜索优先级（getAudioPath）
1. `{localDeviceName}{action}.mp3/wav`（如 `大巷皮带启车.wav`）
2. `{N}号皮带{action}.mp3/wav`（如 `1号皮带启车.wav`，兼容旧文件）
3. `带{action}.mp3/wav`
4. `{action}.mp3/wav`

## 验证方法
1. 基本参数中设置本机名称为"大巷皮带"
2. 批量生成 → 皮带操作状态 → 文件名应为"大巷皮带启车.wav"
3. 按R键启动 → TTS语音应说"大巷皮带准备启车，请注意安全"
4. 改名为"顺槽皮带" → 清除旧语音 → 重新批量生成 → 文件名更新
