# Phase 7.48.32 - 电机保护音频配置界面修复

## 日期
2026-03-10

## 问题描述
MotorProtectionTab.qml 的音频配置存在三个问题：
1. 音频文件输入框为空，没有联系到批量生成的文件
2. 音频来源按钮没有按照模拟量保护参数设置界面（AnalogInputPage）的格式和功能实现
3. TTS文字输入框还是黑色的

## 修复内容

### 1. 音频来源按钮组升级为 Cyberpunk 工业风格
- **旧样式**：简单的 `Row { Button "默认" / Button "TTS" }` + 蓝色高亮背景
- **新样式**：匹配 AnalogInputPage 的 Cyberpunk 工业风
  - [默认] 按钮：深蓝背景 `#0a1929` + 青色边框 `#00d4ff` + 顶部高亮线 + LED 指示点
  - [TTS] 按钮：深绿背景 `#0d2218` + 绿色边框 `#22C55E` + 顶部高亮线 + LED 指示点
  - 未选中状态：深灰背景 `#141920` + 板岩边框 `#334155` + 灰色 LED 点

### 2. TTS 文字输入框样式修复
- **旧样式**：`placeholderText: "输入TTS文字"`（无颜色设置，黑色文字）
- **新样式**：`placeholderText: "输入报警文字内容..."`（匹配 AnalogInputPage）
- 默认值改为 `保护名称 + "保护报警"`（如"电流保护保护报警"）

### 3. 音频文件输入框自动填充
- **旧行为**：输入框为空，无 placeholder
- **新行为**：
  - 新增 `placeholderText: "未配置音频文件"`
  - 新增 `placeholderTextColor: "#6E6E6E"`、`color: "#E0E0E0"`
  - 新增 `getAudioFileName()` 函数：默认模式生成 `.mp3`，TTS 模式生成 `.wav`
  - 切换音频来源时自动更新文件名（`onAudioSourceModeChanged`）
  - `applyConfig()` 加载时自动填充：`config.audio_file || getAudioFileName(protectionName)`
  - `resetToDefaults()` 重置时自动填充

## 修改文件
- `src/qml/components/device_info/pages/MotorProtectionTab.qml`

## 关键代码

### getAudioFileName 函数
```javascript
function getAudioFileName(protectionName) {
    if (root.audioSourceMode === "default") {
        return protectionName + ".mp3"
    } else {
        return protectionName + ".wav"
    }
}
```

### onAudioSourceModeChanged 自动更新
```javascript
onAudioSourceModeChanged: {
    if (audioFileField) {
        audioFileField.text = getAudioFileName(root.protectionName)
    }
}
```

## 验证方式
1. 进入电机控制页面，切换到任意保护Tab
2. 确认音频来源按钮显示为 Cyberpunk 工业风格（深蓝/深绿 + LED 点）
3. 确认 TTS 文字输入框显示浅色文字（非黑色）
4. 确认音频文件输入框自动显示文件名（如"电流保护.wav"）
5. 切换音频来源，确认文件名自动更新（.mp3 ↔ .wav）
