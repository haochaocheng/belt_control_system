# TTS模型动态配置UI方案 - 技术决策

**日期**: 2026-01-23
**决策人**: 用户需求
**状态**: 待审核

---

## 📋 需求背景

### 当前问题
- TTS模型路径硬编码在代码中（`/app/tts_models/vits-zh-aishell3`）
- speaker_id固定为0，无法测试其他说话人
- 每次更换模型或参数都需要重新编译代码
- 无法灵活测试不同模型的效果

### 用户需求
1. 在网络参数设置界面新增"TTS模型设置"区域
2. 所有可设置参数都要列出来（模型、说话人、语速、音量等）
3. 所有可用模型都要列出来，用户可以灵活选择
4. 配置持久化，重启后保留设置
5. 无需重新编译，动态切换模型和参数

---

## 🎯 技术方案

### 方案概述
在参数设置页面新增"TTS语音设置"区域，提供以下配置项：
1. **模型选择**：下拉列表选择预装的TTS模型
2. **说话人ID**：数字输入框（0-最大说话人数）
3. **语速**：滑块控制（0.5-2.0）
4. **音量**：滑块控制（0.0-1.0）
5. **测试按钮**：立即测试当前配置

---

## 📊 可配置参数清单

### 1. 模型路径 (model_dir)
**类型**: 字符串（下拉选择）
**默认值**: `/app/tts_models/vits-zh-aishell3`
**可选值**: 见下方"可用模型列表"

### 2. 说话人ID (speaker_id)
**类型**: 整数
**范围**: 0 - (模型最大说话人数-1)
**默认值**: 0
**说明**:
- 单说话人模型：固定为0，禁用输入
- 多说话人模型：可输入0-173（aishell3）或其他范围

### 3. 语速 (rate)
**类型**: 浮点数
**范围**: 0.5 - 2.0
**默认值**: 1.0
**说明**:
- 0.5 = 慢速（50%）
- 1.0 = 正常速度（100%）
- 2.0 = 快速（200%）

### 4. 音量 (volume)
**类型**: 浮点数
**范围**: 0.0 - 1.0
**默认值**: 0.8
**说明**:
- 0.0 = 静音
- 0.5 = 50%音量
- 1.0 = 100%音量

### 5. 测试文本 (test_text)
**类型**: 字符串
**默认值**: "一号皮带准备启动，请注意"
**说明**: 用于测试TTS效果的文本

---

## 📦 可用模型列表

### 预装模型（容器内）

#### 模型1: vits-zh-aishell3（当前使用）
- **路径**: `/app/tts_models/vits-zh-aishell3`
- **说话人数**: 174
- **采样率**: 8000 Hz
- **大小**: 116 MB
- **特点**: 多说话人，中文，工业场景
- **speaker_id范围**: 0-173

#### 模型2: vits-zh-hf-fanchen-wnj（推荐男声）
- **路径**: `/app/tts_models/vits-zh-hf-fanchen-wnj`
- **说话人数**: 1（男声）
- **采样率**: 16000 Hz
- **大小**: 115 MB
- **特点**: 单一男声，音质更好
- **speaker_id范围**: 0（固定）
- **下载**: `https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-zh-hf-fanchen-wnj.tar.bz2`

#### 模型3: vits-zh-hf-fanchen-C
- **路径**: `/app/tts_models/vits-zh-hf-fanchen-C`
- **说话人数**: 187
- **采样率**: 16000 Hz
- **大小**: 116 MB
- **特点**: 多说话人，更多选择
- **speaker_id范围**: 0-186
- **下载**: `https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-zh-hf-fanchen-C.tar.bz2`

#### 模型4: vits-zh-hf-theresa
- **路径**: `/app/tts_models/vits-zh-hf-theresa`
- **说话人数**: 804
- **采样率**: 22050 Hz
- **大小**: 117 MB
- **特点**: 最多说话人，最高音质
- **speaker_id范围**: 0-803
- **下载**: `https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-zh-hf-theresa.tar.bz2`

#### 模型5: vits-zh-hf-eula
- **路径**: `/app/tts_models/vits-zh-hf-eula`
- **说话人数**: 804
- **采样率**: 22050 Hz
- **大小**: 117 MB
- **特点**: 最多说话人，最高音质
- **speaker_id范围**: 0-803
- **下载**: `https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-zh-hf-eula.tar.bz2`

#### 模型6: sherpa-onnx-vits-zh-ll
- **路径**: `/app/tts_models/sherpa-onnx-vits-zh-ll`
- **说话人数**: 5
- **采样率**: 16000 Hz
- **大小**: 115 MB
- **特点**: 少量说话人，快速切换
- **speaker_id范围**: 0-4
- **下载**: `https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/sherpa-onnx-vits-zh-ll.tar.bz2`

#### 模型7: vits-melo-tts-zh_en
- **路径**: `/app/tts_models/vits-melo-tts-zh_en`
- **说话人数**: 1
- **采样率**: 44100 Hz
- **大小**: 163 MB
- **特点**: 中英文混合，高音质
- **speaker_id范围**: 0（固定）
- **下载**: `https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-melo-tts-zh_en.tar.bz2`

---

## 🎨 UI设计方案

### 界面布局

在 `NetworkParametersSection.qml` 中新增"TTS语音设置"区域：

```qml
// 网络参数设置（现有）
ParameterRow { label: "IP地址"; value: "192.168.1.100" }
ParameterRow { label: "子网掩码"; value: "255.255.255.0" }
ParameterRow { label: "网关"; value: "192.168.1.1" }

// ===== 新增：TTS语音设置 =====
Rectangle {
    Layout.fillWidth: true
    height: 2
    color: "#00d4ff"
    opacity: 0.3
}

Text {
    text: "TTS语音设置"
    font.pixelSize: 20
    font.bold: true
    color: "#00d4ff"
}

// 模型选择（下拉列表）
ParameterComboBox {
    label: "TTS模型"
    model: [
        "vits-zh-aishell3 (174说话人, 8kHz)",
        "vits-zh-hf-fanchen-wnj (男声, 16kHz) ⭐",
        "vits-zh-hf-fanchen-C (187说话人, 16kHz)",
        "vits-zh-hf-theresa (804说话人, 22kHz)",
        "vits-zh-hf-eula (804说话人, 22kHz)",
        "sherpa-onnx-vits-zh-ll (5说话人, 16kHz)",
        "vits-melo-tts-zh_en (中英文, 44kHz)"
    ]
    currentIndex: 0
    onCurrentIndexChanged: {
        // 更新说话人ID范围
        updateSpeakerIdRange(currentIndex)
    }
}

// 说话人ID（数字输入）
ParameterRow {
    label: "说话人ID"
    value: "0"
    unit: ""
    validator: IntValidator { bottom: 0; top: 173 }  // 动态更新
    enabled: true  // 单说话人模型时禁用
}

// 语速（滑块）
ParameterSlider {
    label: "语速"
    from: 0.5
    to: 2.0
    value: 1.0
    stepSize: 0.1
    unit: "x"
    displayValue: value.toFixed(1)
}

// 音量（滑块）
ParameterSlider {
    label: "音量"
    from: 0.0
    to: 1.0
    value: 0.8
    stepSize: 0.05
    unit: "%"
    displayValue: (value * 100).toFixed(0)
}

// 测试按钮
Button {
    text: "🔊 测试语音"
    Layout.fillWidth: true
    onClicked: {
        // 调用后端测试TTS
        ttsManager.testTTS("一号皮带准备启动，请注意")
    }
}
```

### 新增QML组件

#### ParameterComboBox.qml（下拉选择）
```qml
RowLayout {
    property string label: ""
    property var model: []
    property int currentIndex: 0

    Text {
        text: label + "："
        font.pixelSize: 16
        color: "#95a5a6"
        Layout.preferredWidth: 130
    }

    ComboBox {
        id: combo
        model: parent.model
        currentIndex: parent.currentIndex
        Layout.fillWidth: true

        background: Rectangle {
            color: "transparent"
            border.color: combo.activeFocus ? "#00d4ff" : "#34495e"
            border.width: 1
            radius: 5
        }

        contentItem: Text {
            text: combo.displayText
            font.pixelSize: 14
            color: "#ecf0f1"
            verticalAlignment: Text.AlignVCenter
        }
    }
}
```

#### ParameterSlider.qml（滑块控制）
```qml
RowLayout {
    property string label: ""
    property real from: 0
    property real to: 1
    property real value: 0.5
    property real stepSize: 0.1
    property string unit: ""
    property string displayValue: value.toFixed(2)

    Text {
        text: label + "："
        font.pixelSize: 16
        color: "#95a5a6"
        Layout.preferredWidth: 130
    }

    Slider {
        id: slider
        from: parent.from
        to: parent.to
        value: parent.value
        stepSize: parent.stepSize
        Layout.fillWidth: true

        background: Rectangle {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth
            height: 4
            radius: 2
            color: "#34495e"

            Rectangle {
                width: slider.visualPosition * parent.width
                height: parent.height
                color: "#00d4ff"
                radius: 2
            }
        }

        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: 20
            height: 20
            radius: 10
            color: slider.pressed ? "#00d4ff" : "#ecf0f1"
            border.color: "#00d4ff"
            border.width: 2
        }
    }

    Text {
        text: displayValue + unit
        font.pixelSize: 16
        color: "#00d4ff"
        Layout.preferredWidth: 80
    }
}
```

---

## 💾 配置持久化方案

### 使用QSettings存储配置

**配置文件路径**:
- Linux: `/root/.config/BeltControlSystem/settings.conf`
- Windows: 注册表或INI文件

**配置项**:
```ini
[TTS]
model_index=0                    # 模型索引（0-6）
model_path=/app/tts_models/vits-zh-aishell3
speaker_id=0
rate=1.0
volume=0.8
```

### 后端实现（C++）

#### SherpaOnnxTTS.h 新增方法
```cpp
class SherpaOnnxTTS : public QObject
{
    Q_OBJECT

public:
    // 新增：设置说话人ID
    void setSpeakerId(int speakerId);
    int speakerId() const { return m_speakerId; }

    // 新增：动态切换模型
    bool switchModel(const QString &modelDir);

    // 新增：获取当前模型信息
    QString currentModel() const { return m_modelDir; }
    int maxSpeakerId() const { return m_maxSpeakerId; }

    // 新增：测试TTS
    void testTTS(const QString &text);

private:
    int m_speakerId;        // 说话人ID
    int m_maxSpeakerId;     // 当前模型最大说话人ID
};
```

#### SherpaOnnxTTS.cpp 实现
```cpp
void SherpaOnnxTTS::setSpeakerId(int speakerId)
{
    m_speakerId = qBound(0, speakerId, m_maxSpeakerId);
    qDebug() << "🎤 设置说话人ID:" << m_speakerId;
}

bool SherpaOnnxTTS::switchModel(const QString &modelDir)
{
    qDebug() << "🔄 切换TTS模型:" << modelDir;

    // 停止当前TTS服务
    if (m_ttsProcess->state() != QProcess::NotRunning) {
        stop();
    }

    // 重新初始化
    return initialize(modelDir);
}

void SherpaOnnxTTS::testTTS(const QString &text)
{
    qDebug() << "🔊 测试TTS:" << text;
    say(text);
}

// 修改 synthesize() 方法，使用 m_speakerId
bool SherpaOnnxTTS::synthesize(const QString &text, const QString &outputPath)
{
    // ...
    synthCmd["speaker_id"] = m_speakerId;  // 使用可配置的ID
    // ...
}
```

#### TTSConfigManager.h（新建配置管理类）
```cpp
class TTSConfigManager : public QObject
{
    Q_OBJECT

public:
    static TTSConfigManager* instance();

    // 加载配置
    void loadConfig();

    // 保存配置
    void saveConfig();

    // 获取/设置配置
    int modelIndex() const { return m_modelIndex; }
    void setModelIndex(int index);

    QString modelPath() const { return m_modelPath; }
    void setModelPath(const QString &path);

    int speakerId() const { return m_speakerId; }
    void setSpeakerId(int id);

    double rate() const { return m_rate; }
    void setRate(double rate);

    double volume() const { return m_volume; }
    void setVolume(double volume);

signals:
    void configChanged();

private:
    TTSConfigManager(QObject *parent = nullptr);

    QSettings *m_settings;
    int m_modelIndex;
    QString m_modelPath;
    int m_speakerId;
    double m_rate;
    double m_volume;
};
```

---

## 🔧 实施步骤

### Phase 1: 后端支持（C++）
1. ✅ 修改 `SherpaOnnxTTS.h`：添加 `setSpeakerId()` 方法
2. ✅ 修改 `SherpaOnnxTTS.cpp`：实现 speaker_id 配置
3. ✅ 创建 `TTSConfigManager` 类：管理配置持久化
4. ✅ 修改 `synthesize()` 方法：使用 `m_speakerId` 而非硬编码0

### Phase 2: 模型部署
1. ✅ 下载推荐的TTS模型（至少包含男声模型）
2. ✅ 部署到容器 `/app/tts_models/` 目录
3. ✅ 更新 Dockerfile，复制所有模型文件
4. ✅ 验证模型文件完整性

### Phase 3: UI实现（QML）
1. ✅ 创建 `ParameterComboBox.qml` 组件
2. ✅ 创建 `ParameterSlider.qml` 组件
3. ✅ 修改 `NetworkParametersSection.qml`：新增TTS设置区域
4. ✅ 连接QML信号到C++槽函数

### Phase 4: 配置持久化
1. ✅ 实现 `TTSConfigManager::loadConfig()`
2. ✅ 实现 `TTSConfigManager::saveConfig()`
3. ✅ 在应用启动时加载配置
4. ✅ 在配置变更时自动保存

### Phase 5: 测试验证
1. ✅ 测试模型切换功能
2. ✅ 测试说话人ID切换
3. ✅ 测试语速和音量调整
4. ✅ 测试配置持久化
5. ✅ 测试"测试语音"按钮

---

## ❓ 待确认问题

### 问题1: 模型预装策略
**选项A**: 预装所有7个模型（总大小约800 MB）
- 优点：用户可以立即测试所有模型
- 缺点：Docker镜像体积增大

**选项B**: 仅预装2-3个常用模型（约350 MB）
- 优点：镜像体积较小
- 缺点：用户需要手动下载其他模型

**选项C**: 按需下载（UI提供下载按钮）
- 优点：镜像最小
- 缺点：需要实现下载功能，依赖网络

**请问您希望使用哪种策略？**

---

### 问题2: 说话人ID的UI展示
**选项A**: 简单数字输入框（0-173）
- 优点：实现简单
- 缺点：用户不知道每个ID对应什么声音

**选项B**: 下拉列表（"说话人0"、"说话人1"...）
- 优点：更直观
- 缺点：列表太长（174项）

**选项C**: 数字输入框 + 试听按钮
- 优点：平衡简洁和易用性
- 缺点：需要实现试听功能

**请问您希望使用哪种方式？**

---

### 问题3: 模型切换时机
**选项A**: 立即切换（选择后立即加载新模型）
- 优点：实时反馈
- 缺点：频繁切换可能影响性能

**选项B**: 点击"应用"按钮后切换
- 优点：避免频繁切换
- 缺点：需要额外按钮

**选项C**: 重启应用后生效
- 优点：最稳定
- 缺点：不够灵活

**请问您希望使用哪种方式？**

---

### 问题4: 测试文本
**选项A**: 固定测试文本（"一号皮带准备启动，请注意"）
- 优点：简单
- 缺点：不够灵活

**选项B**: 可编辑测试文本（提供输入框）
- 优点：灵活测试不同文本
- 缺点：UI更复杂

**请问您希望使用哪种方式？**

---

### 问题5: 配置作用域
**选项A**: 全局配置（所有TTS使用相同配置）
- 优点：简单统一
- 缺点：无法为不同场景配置不同声音

**选项B**: 场景配置（起车预警、故障报警使用不同配置）
- 优点：更灵活
- 缺点：配置更复杂

**请问您希望使用哪种方式？**

---

## 📝 补充说明

### 模型文件结构
每个模型需要以下文件：
```
/app/tts_models/
├── vits-zh-aishell3/
│   ├── model.onnx          # 主模型文件
│   ├── lexicon.txt         # 词典
│   ├── tokens.txt          # 标记
│   ├── *.fst               # 文本规范化规则（可选）
│   └── dict/               # 词典目录（可选）
├── vits-zh-hf-fanchen-wnj/
│   └── ...
└── ...
```

### 性能考虑
- 模型切换需要重新加载（约1-2秒）
- 建议在非工作时间测试模型
- 可以添加"正在加载模型..."提示

### 兼容性
- 所有模型都支持Sherpa-ONNX框架
- 采样率不同不影响使用（自动重采样到8kHz）
- 模型文件格式统一（ONNX）

---

## ✅ 决策总结

**用户确认结果**（2026-01-23）：
1. ✅ **模型预装策略**：**A** - 预装所有7个模型（总大小约800 MB）
   - 用户可以立即测试所有模型，无需额外下载

2. ✅ **说话人ID的UI展示**：**C** - 数字输入框 + 试听按钮
   - 平衡简洁性和易用性
   - 用户可以输入ID后立即试听效果

3. ✅ **模型切换时机**：**A** - 立即切换（选择后立即加载新模型）
   - 实时反馈，方便快速测试
   - 需要添加"正在加载模型..."提示

4. ✅ **测试文本**：**B** - 可编辑测试文本（提供输入框）
   - 灵活测试不同文本效果
   - 默认文本："一号皮带准备启动，请注意"

5. ✅ **配置作用域**：**B** - 场景配置（起车预警、故障报警使用不同配置）
   - 更灵活，不同场景可以使用不同声音
   - 配置项：
     - 起车预警TTS配置（模型、说话人、语速、音量）
     - 故障报警TTS配置（模型、说话人、语速、音量）
     - 测试TTS配置（用于参数设置界面测试）

**决策已确认，开始实施**。

---

**参考文档**：
- [TTS模型改进方案](../2026-01-23/01-TTS模型改进方案-音质优化和模型选择.md)
- [Sherpa-ONNX官方文档](https://k2-fsa.github.io/sherpa/onnx/tts/index.html)
