# Phase 7.48.53 修复张紧控制语音播放问题

## 修改文件
- `src/qml/components/device_info/pages/TensionControlConfigPanel.qml` — 修复语音播放逻辑（392行）

## 问题背景

用户测试张紧控制功能时发现两个问题：
1. **语音播放失败**：点击启动按钮，没有播放"一号皮带张紧准备启动，请注意安全"，运行失败时也没有播放"1号皮带张紧运行失败"
2. **PaddleSpeech NLTK 错误**：日志中出现 `[PaddleSpeech Error] "[nltk_data] Error loading cmudict:` 错误

## 问题分析

### 问题1：语音播放失败

**根因**（从 voip.md 日志分析）：
```
[DEBUG] ✅ [TensionControlConfigPanel] 启动张紧控制
[DEBUG] ✅ [TensionControlConfigPanel] 发送MQTT命令: start
```

- 启动按钮点击了，MQTT命令也发送了
- 但代码中使用的 `audioPlayer.play(path)` 对象不存在（`typeof audioPlayer !== "undefined"` 检查失败）
- 预警/失败语音文本字段默认为空，即使 `audioPlayer` 存在也不会播放
- 正确做法是使用全局的 `commonControl.testTTS()` 进行TTS合成播放，或使用 `commonControl.playAudio()` 播放音频文件

**错误代码**（line 251-254, 274-276）：
```qml
// 旧代码：使用不存在的 audioPlayer
var warnPath = buildAudioPath(warningVoiceField.text)
if (warnPath !== "" && typeof audioPlayer !== "undefined") {
    audioPlayer.play(warnPath)
}
```

**问题点**：
1. `audioPlayer` 对象不存在于 QML 上下文中
2. `warningVoiceField.text` 和 `failureVoiceField.text` 默认为空
3. 没有区分 TTS 模式和文件模式的播放逻辑

### 问题2：PaddleSpeech NLTK 错误

**根因**（从 voip.md 日志分析）：
```
[WARNING] [PaddleSpeech Error] "[nltk_data] Error loading cmudict: <urlopen error [Errno 111]
[nltk_data]     Connection refused>
[WARNING] [PaddleSpeech Error] "[nltk_data] Error loading averaged_perceptron_tagger: <urlopen error
[nltk_data]     [Errno -3] Temporary failure in name resolution>
```

- PaddleSpeech 启动时尝试从网络下载 NLTK 数据包（cmudict、averaged_perceptron_tagger）
- 容器内无法访问外网，导致下载失败
- **但这只是警告，不影响功能**：从日志 line 1264-1266 可以看到 PaddleSpeech 最终初始化成功

```
[DEBUG] 📥 [PaddleSpeech] 收到响应: "success"
[DEBUG] ✅ [PaddleSpeech] 初始化成功
[DEBUG] ✅ [CommonControl] TTS 模型切换成功: "fastspeech2_csmsc (中文女声)"
```

**结论**：NLTK 错误可以忽略，不影响 TTS 功能。

## 实施内容

### 1. 设置默认 TTS 文本

**预警语音默认值**：
```qml
text: "一号皮带张紧准备启动，请注意安全"
```

**失败语音默认值**：
```qml
text: "一号皮带张紧运行失败"
```

**placeholderText 动态提示**：
```qml
placeholderText: audioTtsRadio.checked ? "TTS文本" : "音频文件名"
```

### 2. 默认使用 TTS 模式

**原因**：容器内 `/app/audio/` 目录不存在，没有预录音频文件

```qml
RadioButton {
    id: audioTtsRadio; text: "TTS"; checked: true  // ✅ 默认选中TTS
    ButtonGroup.group: audioSourceGroup
    enabled: tensionEnabledSwitch.checked
    contentItem: Text { text: parent.text; font.pixelSize: 21; color: "#E0E0E0"; leftPadding: parent.indicator.width + 4 }
}
```

### 3. 新增 `playVoice()` 统一语音播放函数

**函数签名**：
```javascript
function playVoice(voiceText, label)
```

**功能**：
- TTS 模式：使用 `commonControl.testTTS(text, speakerId, rate, volume)` 合成并播放
- 默认模式：使用 `commonControl.playAudio(audioPath)` 播放音频文件

**实现**：
```javascript
function playVoice(voiceText, label) {
    if (!voiceText || voiceText === "") {
        console.log("⚠️ [TensionControlConfigPanel]", label, "语音文本为空，跳过播放")
        return
    }

    if (audioTtsRadio.checked) {
        // TTS模式：使用 commonControl.testTTS 合成并播放
        console.log("🗣️ [TensionControlConfigPanel] TTS播放" + label + "语音:", voiceText)
        if (typeof commonControl !== "undefined") {
            commonControl.testTTS(voiceText, 0, 0.9, 1.0)
        } else {
            console.log("⚠️ [TensionControlConfigPanel] commonControl 未定义")
        }
    } else {
        // 默认模式：播放音频文件
        var audioPath = buildAudioPath(voiceText)
        console.log("🔊 [TensionControlConfigPanel] 播放" + label + "音频文件:", audioPath)
        if (audioPath !== "" && typeof commonControl !== "undefined") {
            commonControl.playAudio(audioPath)
        }
    }
}
```

**参数说明**：
- `voiceText`：TTS 文本或音频文件名
- `label`：日志标签（"预警" 或 "失败"）
- TTS 参数：`speakerId=0`（默认说话人），`rate=0.9`（语速），`volume=1.0`（音量）

### 4. 修改定时器触发逻辑

**启动延时定时器**（line 249-263）：
```javascript
onTriggered: {
    // ✅ 2026-03-17 [Phase 7.48.53]: 修复语音播放逻辑
    // 延时结束，播放预警语音
    playVoice(warningVoiceField.text, "预警")

    // 发送MQTT启动命令
    sendMqttCommand("start")

    // 如果使用反馈，启动反馈超时定时器
    if (useFeedbackSwitch.checked) {
        feedbackTimeoutTimer.start()
    } else {
        root.tensionOpened = true
    }
}
```

**反馈超时定时器**（line 267-282）：
```javascript
onTriggered: {
    console.log("✅ [TensionControlConfigPanel] 反馈超时")
    // ✅ 2026-03-17 [Phase 7.48.53]: 修复语音播放逻辑
    // 播放失败语音
    playVoice(failureVoiceField.text, "失败")

    // 停止张紧控制
    sendMqttCommand("stop")
    root.tensionOpened = false
}
```

## 技术细节

### commonControl 上下文注册

**位置**：`src/main/main.cpp:448`
```cpp
engine.rootContext()->setContextProperty("commonControl", &commonControl);
```

**可用方法**：
- `commonControl.testTTS(text, speakerId, rate, volume)` — TTS 合成并播放
- `commonControl.playAudio(audioPath)` — 播放音频文件

### TTS 播放流程

1. `commonControl.testTTS()` 调用 `TTSEngineManager::synthesize()`
2. 合成到临时文件 `/tmp/test_tts.wav`
3. 清除 Opus 缓存（避免播放旧音频）
4. 调用 `playAudio()` 播放合成的音频文件
5. 通过 `AudioNetworkTcpSender` 发送到网络（VoIP 通话）

**参考代码**：`src/control/CommonControl.cpp:1578-1618`

### 音频文件播放流程

1. `commonControl.playAudio()` 检查文件是否存在
2. 如果文件不存在，回退到实时 TTS 合成
3. 通过 `AudioNetworkTcpSender` 发送到网络（VoIP 通话）

**参考代码**：`src/control/AlarmPlaybackService.cpp:366-373`

## 验证方案

1. 编译并部署到设备
2. 打开设备设置对话框 → 张紧控制
3. 点击"张紧控制"（index 1）
4. 点击"启动"按钮
5. 验证：
   - 应该听到"一号皮带张紧准备启动，请注意安全"
   - 如果反馈超时，应该听到"一号皮带张紧运行失败"
6. 检查日志：
   - 应该看到 `🗣️ [TensionControlConfigPanel] TTS播放预警语音: 一号皮带张紧准备启动，请注意安全`
   - 应该看到 `🎙️ [CommonControl] 测试 TTS - 文本: 一号皮带张紧准备启动，请注意安全`

## Git 提交

```
fix: Phase 7.48.53 修复张紧控制语音播放问题

- 修复语音播放逻辑：使用 commonControl.testTTS() 替代不存在的 audioPlayer
- 设置预警/失败语音默认文本："一号皮带张紧准备启动，请注意安全" / "一号皮带张紧运行失败"
- 默认使用 TTS 模式（因为容器内无预录音频文件）
- 新增 playVoice() 统一语音播放函数，支持 TTS 和文件两种模式
- 修改启动延时定时器和反馈超时定时器的语音播放调用

问题分析：
- 问题1：audioPlayer 对象不存在，导致语音播放失败
- 问题2：PaddleSpeech NLTK 错误只是警告，不影响功能（容器内无法访问外网下载 NLTK 数据）

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

## 下一步

等待用户测试验证。
