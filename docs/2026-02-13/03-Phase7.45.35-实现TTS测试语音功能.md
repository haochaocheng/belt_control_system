# Phase 7.45.35 - 实现 TTS 测试语音功能

**实现时间**: 2026-02-13 12:00
**功能类型**: 新功能实现
**严重程度**: 中（用户需要的功能）

## 1. 需求背景

### 用户需求

用户在语音管理界面需要测试 TTS 模型的语音效果：

1. **选择 TTS 模型**：从 7 个可用模型中选择
2. **选择说话人ID**：测试不同说话人的声音
3. **调整语速和音量**：找到最合适的参数
4. **测试文本**："一号皮带准备启动，请注意"
5. **试听效果**：播放生成的语音，选择最好听的作为报警语音

### 现有问题

- "生成测试语音" 按钮存在但功能未实现（TODO 注释）
- 点击按钮后没有反应
- 无法测试不同说话人的声音效果
- 处理中可以重复点击按钮

## 2. 实现方案

### 架构设计

```
QML 界面 (TTSConfigSection.qml)
    ↓ 调用
CommonControl.testTTS()
    ↓ 调用
SherpaOnnxTTS.testTTS()
    ↓ 播放
音频输出设备
```

### 关键设计决策

1. **通过 CommonControl 暴露 TTS**：
   - SherpaOnnxTTS 是 CommonControl 的私有成员
   - 添加 Q_INVOKABLE 方法 `testTTS()` 暴露给 QML
   - 避免直接暴露 TTS 对象，保持封装性

2. **按钮状态管理**：
   - 文本为空时禁用按钮
   - 点击后立即禁用，防止重复点击
   - 3秒后自动重新启用（假设 TTS 播放完成）

3. **参数传递**：
   - 说话人ID：从 SpinBox 获取
   - 语速：从 Slider 获取（0.5-2.0）
   - 音量：从 Slider 获取（0.0-1.0）
   - 测试文本：从 TextField 获取

## 3. 修改内容

### 文件 1: `src/control/CommonControl.h`

添加 TTS 测试方法声明：

```cpp
// ✅ 2026-02-13 [Phase 7.45.35]: 添加 TTS 测试方法
/**
 * @brief 测试 TTS 语音合成
 * @param text 要合成的文本
 * @param speakerId 说话人ID（默认：0）
 * @param rate 语速（默认：1.0，范围：0.5-2.0）
 * @param volume 音量（默认：0.8，范围：0.0-1.0）
 */
Q_INVOKABLE void testTTS(const QString &text, int speakerId = 0, double rate = 1.0, double volume = 0.8);
```

### 文件 2: `src/control/CommonControl.cpp`

实现 TTS 测试方法：

```cpp
// ✅ 2026-02-13 [Phase 7.45.35]: 实现 TTS 测试方法
void CommonControl::testTTS(const QString &text, int speakerId, double rate, double volume)
{
    if (!m_tts) {
        qWarning() << "⚠️ [CommonControl] TTS 未初始化";
        return;
    }

    qDebug() << "🎙️ [CommonControl] 测试 TTS - 文本:" << text
             << "说话人ID:" << speakerId
             << "语速:" << rate
             << "音量:" << volume;

    // 设置 TTS 参数
    m_tts->setSpeakerId(speakerId);
    m_tts->setRate(rate);
    m_tts->setVolume(volume);

    // 播放测试语音
    m_tts->testTTS(text);
}
```

### 文件 3: `src/qml/components/voice_management/TTSConfigSection.qml`

#### 修改 1：按钮添加 ID 和启用状态管理

```qml
Button {
    id: testButton
    text: "🎙️ 生成测试语音"
    Layout.fillWidth: true
    Layout.preferredHeight: 40
    enabled: testTextInput.text.length > 0  // ✅ 文本为空时禁用按钮

    background: Rectangle {
        color: parent.enabled ? (parent.pressed ? "#2980b9" : "#3498db") : "#7f8c8d"
        border.color: parent.enabled ? "#3498db" : "#95a5a6"
        border.width: 1
        radius: 5
    }

    contentItem: Text {
        text: parent.text
        font.pixelSize: 14
        color: parent.enabled ? "#ecf0f1" : "#bdc3c7"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
```

#### 修改 2：按钮点击事件实现

```qml
onClicked: {
    // ✅ 2026-02-13 [Phase 7.45.35]: 调用 CommonControl.testTTS()
    console.log("生成测试语音:", testTextInput.text)
    console.log("  模型索引:", modelComboBox.currentIndex)
    console.log("  说话人ID:", speakerIdSpinBox.value)
    console.log("  语速:", rateSlider.value.toFixed(1))
    console.log("  音量:", volumeSlider.value.toFixed(1))

    // 禁用按钮，防止重复点击
    testButton.enabled = false

    // 调用后端 TTS 测试
    commonControl.testTTS(
        testTextInput.text,
        speakerIdSpinBox.value,
        rateSlider.value,
        volumeSlider.value
    )

    // 3秒后重新启用按钮（假设 TTS 播放需要时间）
    Qt.callLater(function() {
        testButtonTimer.start()
    })
}
```

#### 修改 3：添加定时器重新启用按钮

```qml
// ✅ 2026-02-13 [Phase 7.45.35]: 添加定时器，延迟重新启用按钮
Timer {
    id: testButtonTimer
    interval: 3000  // 3秒后重新启用
    repeat: false
    onTriggered: {
        testButton.enabled = testTextInput.text.length > 0
    }
}
```

## 4. 技术要点

### Q_INVOKABLE 方法

- 使用 `Q_INVOKABLE` 宏标记方法，使其可以从 QML 调用
- 方法必须是 public 的
- 参数类型必须是 Qt 元类型系统支持的类型

### 按钮状态管理策略

| 状态 | 条件 | 按钮外观 |
|------|------|----------|
| 禁用（灰色） | 文本为空 | 灰色背景，灰色文字 |
| 启用（蓝色） | 文本不为空 | 蓝色背景，白色文字 |
| 处理中（禁用） | 点击后 3 秒内 | 灰色背景，灰色文字 |

### TTS 参数范围

- **说话人ID**：0-173（根据模型不同）
- **语速**：0.5-2.0（1.0 为正常速度）
- **音量**：0.0-1.0（0.8 为默认音量）

## 5. 使用方法

### 用户操作流程

1. 打开语音管理界面
2. 选择 TTS 模型（如 "vits-zh-aishell3"）
3. 调整说话人ID（0-173）
4. 调整语速（0.5-2.0）
5. 调整音量（0.0-1.0）
6. 输入测试文本（默认："一号皮带准备启动，请注意"）
7. 点击 "🎙️ 生成测试语音" 按钮
8. 等待语音播放完成（约 3 秒）
9. 试听效果，选择最合适的参数

### 预期日志输出

```
[DEBUG] 生成测试语音: 一号皮带准备启动，请注意
[DEBUG]   模型索引: 0
[DEBUG]   说话人ID: 10
[DEBUG]   语速: 1.2
[DEBUG]   音量: 0.8
[DEBUG] 🎙️ [CommonControl] 测试 TTS - 文本: 一号皮带准备启动，请注意 说话人ID: 10 语速: 1.2 音量: 0.8
[DEBUG] 🔊 [TTS] 测试语音: 一号皮带准备启动，请注意
```

## 6. 验证步骤

1. 编译部署到设备
2. 打开语音管理界面
3. 验证以下场景：
   - 文本为空时按钮禁用
   - 输入文本后按钮启用
   - 点击按钮后立即禁用
   - 3秒后按钮重新启用
   - 调整说话人ID、语速、音量后再次测试
   - 确认语音正常播放

## 7. 后续优化

### 可能的改进

1. **动态定时器**：根据文本长度计算播放时间，动态设置定时器
2. **播放状态反馈**：监听 TTS 播放完成信号，立即重新启用按钮
3. **模型切换**：实现模型切换功能（当前只是显示，未实现）
4. **参数保存**：保存用户选择的参数到配置文件

### 已知限制

1. 定时器固定 3 秒，可能不够或过长
2. 模型切换功能未实现
3. 参数不会保存到配置文件

## 8. 相关功能

- SherpaOnnxTTS: TTS 语音合成引擎
- CommonControl: 公共控制类，管理 TTS 对象
- AlarmPlaybackService: 报警播放服务，使用 TTS 播放报警语音

## 9. 经验教训

1. **封装性**：通过 CommonControl 暴露 TTS，而不是直接暴露 TTS 对象
2. **用户体验**：按钮状态管理防止重复点击，提升用户体验
3. **参数传递**：QML 到 C++ 的参数传递需要使用 Qt 元类型系统支持的类型
