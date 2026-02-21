import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5
import com.belt.control 1.0  // ✅ 2026-01-23 11:00 [FIX 100.299] 导入 TTSConfig 单例

/**
 * @brief TTS配置区域组件
 *
 * 功能：
 * 1. 模型选择
 * 2. 说话人ID设置
 * 3. 语速调整
 * 4. 音量调整
 * 5. 测试语音
 *
 * ✅ 2026-01-23 10:30 [FIX 100.299] TTS配置UI组件
 * ✅ 2026-01-23 11:00 [FIX 100.299] 后端集成
 */
ColumnLayout {
    id: root
    spacing: 15

    // ✅ 2026-02-13 [Phase 7.46.6]: 添加 TTS 引擎选择
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: "TTS 引擎:"
            font.pixelSize: 14
            font.bold: true
            font.family: "Microsoft YaHei"
            color: "#ecf0f1"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            ComboBox {
                id: engineComboBox
                Layout.fillWidth: true
                Layout.preferredHeight: 40

                model: [
                    "PaddleSpeech (中文最好)",
                    "MeloTTS (推荐)"
                ]

                currentIndex: 1  // 默认选择 MeloTTS

                background: Rectangle {
                    color: "transparent"
                    border.color: engineComboBox.activeFocus ? "#00d4ff" : "#34495e"
                    border.width: 2
                    radius: 5
                }

                contentItem: Text {
                    text: engineComboBox.displayText
                    font.pixelSize: 16
                    font.bold: true
                    font.family: "Microsoft YaHei"
                    color: "#00d4ff"
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 10
                }

                delegate: ItemDelegate {
                    width: engineComboBox.width
                    contentItem: Text {
                        text: modelData
                        color: "#ecf0f1"
                        font.pixelSize: 14
                        font.family: "Microsoft YaHei"
                        verticalAlignment: Text.AlignVCenter
                    }
                    highlighted: engineComboBox.highlightedIndex === index
                    background: Rectangle {
                        color: highlighted ? "#00d4ff" : "transparent"
                        opacity: highlighted ? 0.3 : 1.0
                    }
                }

                popup: Popup {
                    y: engineComboBox.height
                    width: engineComboBox.width
                    implicitHeight: contentItem.implicitHeight
                    padding: 1

                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: engineComboBox.popup.visible ? engineComboBox.delegateModel : null
                        currentIndex: engineComboBox.highlightedIndex

                        ScrollIndicator.vertical: ScrollIndicator { }
                    }

                    background: Rectangle {
                        color: "#2c3e50"
                        border.color: "#00d4ff"
                        border.width: 1
                        radius: 5
                    }
                }

                onCurrentIndexChanged: {
                    if (currentIndex >= 0) {
                        // 切换引擎
                        commonControl.switchTTSEngine(currentIndex)
                        // 更新模型列表
                        updateModelList()
                        // 更新引擎状态
                        updateEngineStatus()
                    }
                }
            }

            // 引擎状态指示器
            Rectangle {
                Layout.preferredWidth: 120
                Layout.preferredHeight: 40
                color: "transparent"
                border.color: engineStatusIndicator.isInitialized ? "#2ecc71" : "#e74c3c"
                border.width: 2
                radius: 5

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 5

                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: engineStatusIndicator.isInitialized ? "#2ecc71" : "#e74c3c"

                        // 闪烁动画（未初始化时）
                        SequentialAnimation on opacity {
                            running: !engineStatusIndicator.isInitialized
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 500 }
                            NumberAnimation { to: 1.0; duration: 500 }
                        }
                    }

                    Text {
                        id: engineStatusIndicator
                        property bool isInitialized: false

                        text: isInitialized ? "已初始化" : "未初始化"
                        font.pixelSize: 12
                        font.family: "Microsoft YaHei"
                        color: isInitialized ? "#2ecc71" : "#e74c3c"
                        Layout.fillWidth: true
                    }
                }
            }
        }

        // ✅ 2026-02-21 22:40: 添加初始化进度条
        // 原因：PaddleSpeech 初始化需要 5-10 分钟，用户需要看到进度
        // 效果：显示初始化进度百分比和消息
        ColumnLayout {
            id: initProgressContainer
            Layout.fillWidth: true
            spacing: 5
            visible: false  // 默认隐藏

            Text {
                id: initProgressText
                text: "正在初始化..."
                font.pixelSize: 12
                font.family: "Microsoft YaHei"
                color: "#00d4ff"
            }

            ProgressBar {
                id: initProgressBar
                Layout.fillWidth: true
                Layout.preferredHeight: 8
                from: 0
                to: 100
                value: 0

                background: Rectangle {
                    implicitWidth: 200
                    implicitHeight: 8
                    color: "#34495e"
                    radius: 4
                }

                contentItem: Item {
                    implicitWidth: 200
                    implicitHeight: 8

                    Rectangle {
                        width: initProgressBar.visualPosition * parent.width
                        height: parent.height
                        radius: 4
                        color: "#00d4ff"
                    }
                }
            }
        }
    }

    // 模型选择
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: "TTS模型："
            font.pixelSize: 14
            color: "#ecf0f1"
        }

        ComboBox {
            id: modelComboBox
            Layout.fillWidth: true
            Layout.preferredHeight: 36

            // ✅ 2026-02-13 [Phase 7.46.6]: 改为动态模型列表
            model: []

            background: Rectangle {
                color: "transparent"
                border.color: modelComboBox.activeFocus ? "#00d4ff" : "#34495e"
                border.width: 1
                radius: 5
            }

            contentItem: Text {
                text: modelComboBox.displayText
                font.pixelSize: 14
                color: "#ecf0f1"
                verticalAlignment: Text.AlignVCenter
                leftPadding: 10
            }

            delegate: ItemDelegate {
                width: modelComboBox.width
                contentItem: Text {
                    text: modelData
                    color: "#ecf0f1"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                }
                highlighted: modelComboBox.highlightedIndex === index
                background: Rectangle {
                    color: highlighted ? "#00d4ff" : "transparent"
                    opacity: highlighted ? 0.3 : 1.0
                }
            }

            popup: Popup {
                y: modelComboBox.height
                width: modelComboBox.width
                implicitHeight: contentItem.implicitHeight
                padding: 1

                contentItem: ListView {
                    clip: true
                    implicitHeight: contentHeight
                    model: modelComboBox.popup.visible ? modelComboBox.delegateModel : null
                    currentIndex: modelComboBox.highlightedIndex

                    ScrollIndicator.vertical: ScrollIndicator { }
                }

                background: Rectangle {
                    color: "#2c3e50"
                    border.color: "#00d4ff"
                    border.width: 1
                    radius: 5
                }
            }

            onCurrentIndexChanged: {
                // ✅ 2026-02-13 [Phase 7.46.6]: 简化为调用辅助函数
                console.log("模型切换:", currentIndex)
                if (currentIndex >= 0) {
                    var success = commonControl.switchTTSModel(currentIndex)
                    if (success) {
                        console.log("✅ 模型切换成功:", modelComboBox.displayText)
                        // 更新说话人ID范围
                        updateSpeakerIdRange()
                    } else {
                        console.log("❌ 模型切换失败:", modelComboBox.displayText)
                    }
                }
            }
        }
    }

    // 说话人ID
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: "说话人ID："
            font.pixelSize: 14
            color: "#ecf0f1"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            SpinBox {
                id: speakerIdSpinBox
                Layout.fillWidth: true
                from: 0
                to: 173
                value: 0

                background: Rectangle {
                    color: "transparent"
                    border.color: speakerIdSpinBox.activeFocus ? "#00d4ff" : "#34495e"
                    border.width: 1
                    radius: 5
                }

                contentItem: TextInput {
                    text: speakerIdSpinBox.textFromValue(speakerIdSpinBox.value, speakerIdSpinBox.locale)
                    font.pixelSize: 14
                    color: "#ecf0f1"
                    horizontalAlignment: Qt.AlignHCenter
                    verticalAlignment: Qt.AlignVCenter
                    readOnly: !speakerIdSpinBox.editable
                    validator: speakerIdSpinBox.validator
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                }

                onValueChanged: {
                    console.log("说话人ID:", value)
                    // TODO: 调用 TTSConfigManager.setSpeakerId()
                }
            }

            Button {
                text: "🔊 试听"
                Layout.preferredWidth: 80

                background: Rectangle {
                    color: parent.pressed ? "#27ae60" : "#2ecc71"
                    border.color: "#2ecc71"
                    border.width: 1
                    radius: 5
                }

                contentItem: Text {
                    text: parent.text
                    font.pixelSize: 14
                    color: "#1a1a1a"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    console.log("试听说话人:", speakerIdSpinBox.value)
                    // TODO: 调用 SherpaOnnxTTS.testTTS()
                }
            }
        }

        Text {
            id: speakerIdRangeText
            text: "范围: 0-" + speakerIdSpinBox.to + " (根据模型不同)"
            font.pixelSize: 12
            color: "#95a5a6"
        }
    }

    // 语速
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: "语速："
            font.pixelSize: 14
            color: "#ecf0f1"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Slider {
                id: rateSlider
                Layout.fillWidth: true
                from: 0.5
                to: 2.0
                value: 1.0
                stepSize: 0.1

                background: Rectangle {
                    x: rateSlider.leftPadding
                    y: rateSlider.topPadding + rateSlider.availableHeight / 2 - height / 2
                    width: rateSlider.availableWidth
                    height: 4
                    radius: 2
                    color: "#34495e"

                    Rectangle {
                        width: rateSlider.visualPosition * parent.width
                        height: parent.height
                        color: "#00d4ff"
                        radius: 2
                    }
                }

                handle: Rectangle {
                    x: rateSlider.leftPadding + rateSlider.visualPosition * (rateSlider.availableWidth - width)
                    y: rateSlider.topPadding + rateSlider.availableHeight / 2 - height / 2
                    width: 20
                    height: 20
                    radius: 10
                    color: rateSlider.pressed ? "#00d4ff" : "#ecf0f1"
                    border.color: "#00d4ff"
                    border.width: 2
                }

                onValueChanged: {
                    console.log("语速:", value.toFixed(1))
                    // TODO: 调用 TTSConfigManager.setRate()
                }
            }

            Text {
                text: rateSlider.value.toFixed(1) + "x"
                font.pixelSize: 14
                color: "#00d4ff"
                Layout.preferredWidth: 50
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    // 音量
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: "音量："
            font.pixelSize: 14
            color: "#ecf0f1"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Slider {
                id: volumeSlider
                Layout.fillWidth: true
                from: 0.0
                to: 1.0
                value: 0.8
                stepSize: 0.1

                background: Rectangle {
                    x: volumeSlider.leftPadding
                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                    width: volumeSlider.availableWidth
                    height: 4
                    radius: 2
                    color: "#34495e"

                    Rectangle {
                        width: volumeSlider.visualPosition * parent.width
                        height: parent.height
                        color: "#00d4ff"
                        radius: 2
                    }
                }

                handle: Rectangle {
                    x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                    width: 20
                    height: 20
                    radius: 10
                    color: volumeSlider.pressed ? "#00d4ff" : "#ecf0f1"
                    border.color: "#00d4ff"
                    border.width: 2
                }

                onValueChanged: {
                    console.log("音量:", (value * 100).toFixed(0) + "%")
                    // TODO: 调用 TTSConfigManager.setVolume()
                }
            }

            Text {
                text: (volumeSlider.value * 100).toFixed(0) + "%"
                font.pixelSize: 14
                color: "#00d4ff"
                Layout.preferredWidth: 50
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    // 测试文本
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: "测试文本："
            font.pixelSize: 14
            color: "#ecf0f1"
        }

        TextField {
            id: testTextInput
            Layout.fillWidth: true
            placeholderText: "输入测试文本..."
            text: "一号皮带准备启动，请注意"

            background: Rectangle {
                color: "transparent"
                border.color: testTextInput.activeFocus ? "#00d4ff" : "#34495e"
                border.width: 1
                radius: 5
            }

            color: "#ecf0f1"
            font.pixelSize: 14
        }

        Button {
            id: testButton
            text: "🎙️ 生成测试语音"
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            enabled: testTextInput.text.length > 0  // ✅ 2026-02-13 [Phase 7.45.35]: 文本为空时禁用按钮

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

            // ✅ 2026-02-13 [Phase 7.45.35]: 添加定时器，延迟重新启用按钮
            Timer {
                id: testButtonTimer
                interval: 3000  // 3秒后重新启用
                repeat: false
                onTriggered: {
                    testButton.enabled = testTextInput.text.length > 0
                }
            }
        }
    }

    // 占位符，填充剩余空间
    Item {
        Layout.fillHeight: true
    }

    // ✅ 2026-02-13 [Phase 7.46.6]: 添加辅助函数

    /**
     * @brief 更新模型列表
     *
     * 根据当前选择的引擎,从后端获取模型列表并更新 ComboBox
     */
    function updateModelList() {
        console.log("🔄 更新模型列表...")
        var models = commonControl.getTTSModelList()
        modelComboBox.model = models
        console.log("✅ 模型列表已更新:", models.length, "个模型")

        // 默认选择第一个模型
        if (models.length > 0) {
            modelComboBox.currentIndex = 0
        }
    }

    /**
     * @brief 更新说话人ID范围
     *
     * 根据当前选择的模型,从后端获取最大说话人ID并更新 SpinBox 范围
     */
    function updateSpeakerIdRange() {
        console.log("🔄 更新说话人ID范围...")
        var maxSpeakerId = commonControl.getMaxSpeakerId(modelComboBox.currentIndex)
        speakerIdSpinBox.to = maxSpeakerId
        console.log("✅ 说话人ID范围已更新: 0 -", maxSpeakerId)

        // 如果当前说话人ID超出新范围，重置为0
        if (speakerIdSpinBox.value > maxSpeakerId) {
            speakerIdSpinBox.value = 0
            console.log("⚠️ 说话人ID超出范围，已重置为 0")
        }
    }

    /**
     * @brief 更新引擎状态
     *
     * 从后端获取当前引擎的初始化状态并更新状态指示器
     */
    function updateEngineStatus() {
        console.log("🔄 更新引擎状态...")
        var engineName = commonControl.getCurrentTTSEngine()
        console.log("📊 当前引擎:", engineName)

        // 简单判断：如果引擎名称不为空，认为已初始化
        engineStatusIndicator.isInitialized = (engineName.length > 0)
        console.log("✅ 引擎状态已更新:", engineStatusIndicator.isInitialized ? "已初始化" : "未初始化")
    }

    /**
     * @brief 组件加载完成时初始化
     */
    Component.onCompleted: {
        console.log("🚀 TTSConfigSection 组件加载完成")
        // 初始化模型列表
        updateModelList()
        // 初始化引擎状态
        updateEngineStatus()
    }

    // ✅ 2026-02-21 22:55: 连接 TTS 初始化进度信号
    // 原因：PaddleSpeech 初始化需要 5-10 分钟，显示进度给用户
    Connections {
        target: commonControl

        function onTtsInitializationProgress(message) {
            console.log("📊 TTS 初始化进度:", message)

            // 显示进度条
            initProgressContainer.visible = true

            // 更新进度文本
            initProgressText.text = message

            // 解析进度百分比（如果消息包含百分比）
            // 格式："正在加载 PaddleSpeech 模型... 3% (20/600 秒)"
            var percentMatch = message.match(/(\d+)%/)
            if (percentMatch) {
                var percent = parseInt(percentMatch[1])
                initProgressBar.value = percent
            }

            // 如果初始化完成，隐藏进度条
            if (message.includes("初始化完成") || message.includes("初始化成功")) {
                // 延迟 2 秒后隐藏进度条
                hideProgressTimer.start()
            }
        }
    }

    // 隐藏进度条的定时器
    Timer {
        id: hideProgressTimer
        interval: 2000
        repeat: false
        onTriggered: {
            initProgressContainer.visible = false
            initProgressBar.value = 0
        }
    }
}
