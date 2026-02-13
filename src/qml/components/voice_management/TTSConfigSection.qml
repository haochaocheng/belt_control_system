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

            model: [
                "vits-zh-aishell3 (174说话人)",
                "vits-zh-hf-fanchen-wnj (1说话人)",
                "vits-zh-hf-fanchen-C (187说话人)",
                "vits-zh-hf-theresa (804说话人)",
                "vits-zh-hf-eula (804说话人)",
                "sherpa-onnx-vits-zh-ll (5说话人)",
                "vits-melo-tts-zh_en (1说话人)"
            ]

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
                // ✅ 2026-02-13 [Phase 7.45.36]: 调用 CommonControl.switchTTSModel()
                console.log("模型切换:", currentIndex)
                if (currentIndex >= 0) {
                    var success = commonControl.switchTTSModel(currentIndex)
                    if (success) {
                        console.log("✅ 模型切换成功:", modelComboBox.displayText)

                        // ✅ 2026-02-13 [Phase 7.45.37]: 动态更新说话人ID范围
                        var maxSpeakerId = commonControl.getMaxSpeakerId(currentIndex)
                        speakerIdSpinBox.to = maxSpeakerId
                        console.log("📊 更新说话人ID范围: 0 -", maxSpeakerId)

                        // 如果当前说话人ID超出新范围，重置为0
                        if (speakerIdSpinBox.value > maxSpeakerId) {
                            speakerIdSpinBox.value = 0
                            console.log("⚠️ 说话人ID超出范围，已重置为 0")
                        }
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
}
