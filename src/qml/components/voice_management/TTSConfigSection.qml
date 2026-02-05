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
                console.log("模型切换:", currentIndex)
                // TODO: 调用 TTSConfigManager.setModelIndex()
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
            text: "范围: 0-173 (根据模型不同)"
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
            text: "🎙️ 生成测试语音"
            Layout.fillWidth: true
            Layout.preferredHeight: 40

            background: Rectangle {
                color: parent.pressed ? "#2980b9" : "#3498db"
                border.color: "#3498db"
                border.width: 1
                radius: 5
            }

            contentItem: Text {
                text: parent.text
                font.pixelSize: 14
                color: "#ecf0f1"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: {
                console.log("生成测试语音:", testTextInput.text)
                // TODO: 调用 SherpaOnnxTTS.testTTS()
            }
        }
    }

    // 占位符，填充剩余空间
    Item {
        Layout.fillHeight: true
    }
}
