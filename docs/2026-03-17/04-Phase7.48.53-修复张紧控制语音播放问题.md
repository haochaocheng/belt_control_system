# Phase 7.48.53 修复张紧控制语音播放问题（v2 修正）

## 修改文件
- `src/qml/components/device_info/pages/TensionControlConfigPanel.qml` — 修复语音播放逻辑（426行）

## 问题背景

用户测试张紧控制功能时发现两个问题：
1. **语音播放失败**：点击启动按钮，没有播放"一号皮带张紧准备启动，请注意安全"，运行失败时也没有播放"1号皮带张紧运行失败"
2. **PaddleSpeech NLTK 错误**：日志中出现 `[PaddleSpeech Error] "[nltk_data] Error loading cmudict:` 错误

## 问题分析

### 问题1：语音播放失败

**根因**：
- 旧代码使用 `audioPlayer.play(path)` 对象不存在（`typeof audioPlayer !== "undefined"` 检查失败）
- 预警/失败语音文本字段默认为空，即使 `audioPlayer` 存在也不会播放

**第一次修复（错误）**：使用 `commonControl.testTTS()` 实时合成 — 方法不对
- `commonControl.testTTS()` 是测试TTS功能用的，合成到 `/tmp/test_tts.wav`
- 不是正式的语音播放流程

**第二次修复（正确）**：参照 BasicConfigTab.qml，使用 `alarmPlayback.playAlarm()` + `buildAudioPath()` + 预合成音频文件
- 语音文件是通过"语音管理"界面的"张紧控制批量生成"分类预合成的
- 播放时使用音频文件路径，TTS文本作为回退（文件不存在时自动合成）

### 问题2：PaddleSpeech NLTK 错误

- PaddleSpeech 启动时尝试下载 NLTK 数据包，容器内无外网
- **只是警告，不影响功能**：PaddleSpeech 最终初始化成功

## 实施内容（v2 修正版）

### 1. 添加 TTSConfig 导入

```qml
import com.belt.control 1.0  // TTSConfig单例（用于音频路径构建）
```

### 2. 重写 buildAudioPath() — 参照 BasicConfigTab

**旧**（单参数，硬编码路径）：
```javascript
function buildAudioPath(filename) {
    return "/app/audio/" + filename
}
```

**新**（双参数，根据音频来源构建正确路径）：
```javascript
function buildAudioPath(beltNum, filename) {
    if (!filename || filename === "") return ""
    if (audioDefaultRadio.checked) {
        // 默认音频：{audioBaseDir}/{beltNum}#PD/{filename}.wav
        return audioBaseDir + "/" + beltNum + "#PD/" + filename + ".wav"
    } else {
        // TTS合成音频：{audioBaseDir}/paddlespeech-{model}-spk{id}/{beltNum}#PD/{filename}.wav
        var modelIdx = typeof TTSConfig !== "undefined" ? TTSConfig.modelIndex(TTSConfig.Test) : 0
        var modelName = typeof TTSConfig !== "undefined" ? TTSConfig.modelName(modelIdx) : "fastspeech2_csmsc"
        var spkId = typeof TTSConfig !== "undefined" ? TTSConfig.speakerId(TTSConfig.Test) : 0
        var engineFolder = "paddlespeech-" + modelName + "-spk" + spkId
        return audioBaseDir + "/" + engineFolder + "/" + beltNum + "#PD/" + filename + ".wav"
    }
}
```

### 3. 删除旧 playVoice() 函数

**旧**（使用 `commonControl.testTTS()` — 错误）：
```javascript
function playVoice(voiceText, label) {
    if (audioTtsRadio.checked) {
        commonControl.testTTS(voiceText, 0, 0.9, 1.0)  // ❌ 错误方法
    }
}
```

**新**：直接在定时器 onTriggered 中调用 `alarmPlayback.playAlarm()`（参照 BasicConfigTab）

### 4. 重写启动延时定时器（line 252-262）

```javascript
onTriggered: {
    // 使用alarmPlayback.playAlarm()播放预合成音频文件
    if (warningVoiceField.text.length > 0 && typeof alarmPlayback !== "undefined") {
        var beltNum = typeof systemConfig !== "undefined" ? systemConfig.machineNumber : 1
        var audioPath = buildAudioPath(beltNum, warningVoiceField.text)
        var ttsText = beltNum + "号皮带张紧准备启动，请注意安全"
        alarmPlayback.playAlarm(warningVoiceField.text, ttsText, audioPath, true, "count", 1, 5)
    }
    sendMqttCommand("start")
    ...
}
```

### 5. 重写反馈超时定时器（line 281-292）

```javascript
onTriggered: {
    // 使用alarmPlayback.playAlarm()播放预合成音频文件
    if (failureVoiceField.text.length > 0 && typeof alarmPlayback !== "undefined") {
        var beltNum = typeof systemConfig !== "undefined" ? systemConfig.machineNumber : 1
        var audioPath = buildAudioPath(beltNum, failureVoiceField.text)
        var ttsText = beltNum + "号皮带张紧运行失败"
        alarmPlayback.playAlarm(failureVoiceField.text, ttsText, audioPath, true, "count", 3, 5)
    }
    sendMqttCommand("stop")
    root.tensionOpened = false
}
```

## 关键技术对比

| 方面 | 旧方法（错误） | 新方法（正确） |
|------|---------------|---------------|
| 播放API | `commonControl.testTTS()` | `alarmPlayback.playAlarm()` |
| 音频来源 | 实时TTS合成到 `/tmp/test_tts.wav` | 预合成音频文件 + TTS回退 |
| 路径构建 | `"/app/audio/" + filename` | `buildAudioPath(beltNum, filename)` + audioBaseDir |
| TTSConfig | 不需要 | 需要（`import com.belt.control 1.0`） |
| 皮带编号 | 硬编码 | `systemConfig.machineNumber` |
| 参考文件 | 无 | BasicConfigTab.qml |

## alarmPlayback.playAlarm() 参数说明

```javascript
alarmPlayback.playAlarm(name, ttsText, audioPath, useTextToSpeech, playMode, playCount, playDuration)
```

| 参数 | 预警语音 | 失败语音 |
|------|---------|---------|
| name | warningVoiceField.text | failureVoiceField.text |
| ttsText | "{beltNum}号皮带张紧准备启动，请注意安全" | "{beltNum}号皮带张紧运行失败" |
| audioPath | buildAudioPath(beltNum, filename) | buildAudioPath(beltNum, filename) |
| useTextToSpeech | true | true |
| playMode | "count" | "count" |
| playCount | 1 | 3 |
| playDuration | 5 | 5 |

## 验证方案

1. 编译并部署到设备
2. 先在"语音管理"界面，确认"张紧控制"分类已批量生成音频文件
3. 打开设备设置对话框 → 张紧控制
4. 点击"启动"按钮
5. 验证：
   - 应该听到"一号皮带张紧准备启动，请注意安全"
   - 如果反馈超时，应该听到"一号皮带张紧运行失败"
6. 检查日志：
   - 应该看到 `🗣️ [TensionControlConfigPanel] 播放预警语音: {audioPath}`

## Git 提交

```
fix: Phase 7.48.53 修复张紧控制语音播放-改用alarmPlayback.playAlarm

- 修复语音播放方法：从commonControl.testTTS()改为alarmPlayback.playAlarm()（参照BasicConfigTab）
- 重写buildAudioPath为双参数版本：buildAudioPath(beltNum, filename)，使用audioBaseDir全局属性
- 添加 import com.belt.control 1.0 导入TTSConfig单例（用于TTS音频路径构建）
- 删除旧playVoice()函数，改为在定时器onTriggered中直接调用alarmPlayback.playAlarm()
- 预警语音：playCount=1（播放1次），失败语音：playCount=3（播放3次）
- 使用systemConfig.machineNumber动态获取皮带编号

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

## 下一步

等待用户测试验证。
