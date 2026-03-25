import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// Basic Parameters Section Component
Rectangle {
    id: root
    color: "#dd1a2332"
    radius: 10
    border.color: "#00d4ff"
    border.width: 2

    // External popup references (set by parent)
    property var dateTimePopup: null

    // ✅ 2026-03-25 [Phase 7.48.88.16]: Flickable 引用，用于虚拟键盘弹出时自动滚动
    property var flickableParent: null

    // ✅ 2026-02-06 [参数持久化]: 配置对象（由父组件传递）
    property var systemConfig: null

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Text {
            text: "基本参数设置"
            font.pixelSize: 20
            font.bold: true
            color: "#00d4ff"
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#00d4ff"
            opacity: 0.5
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            rowSpacing: 6
            columnSpacing: 8

            ParameterRow {
                label: "本机编号"
                value: systemConfig ? systemConfig.machineNumber.toString() : "1"
                unit: ""
                keyboardMode: "numeric"
                onFieldValueChanged: function(newValue) {
                    if (systemConfig && newValue !== "") {
                        var num = parseInt(newValue)
                        if (num >= 1 && num <= 8) {
                            systemConfig.machineNumber = num
                        }
                    }
                }
            }

            ParameterRow {
                label: "起车预警模式"
                isComboBox: true
                comboModel: ["按时间", "按次数"]
                comboCurrentIndex: systemConfig ? systemConfig.warningMode : 0
                onFieldComboChanged: function(newIndex) {
                    if (systemConfig) {
                        systemConfig.warningMode = newIndex
                    }
                }
            }

            ParameterRow {
                label: "起车预警时间"
                value: systemConfig ? systemConfig.warningTimeSeconds.toString() : "10"
                unit: "秒"
                keyboardMode: "numeric"
                onFieldValueChanged: function(newValue) {
                    if (systemConfig && newValue !== "") {
                        var seconds = parseInt(newValue)
                        if (seconds > 0) {
                            systemConfig.warningTimeSeconds = seconds
                        }
                    }
                }
            }

            ParameterRow {
                label: "起车预警次数"
                value: systemConfig ? systemConfig.warningPlayCount.toString() : "3"
                unit: "次"
                keyboardMode: "numeric"
                onFieldValueChanged: function(newValue) {
                    if (systemConfig && newValue !== "") {
                        var count = parseInt(newValue)
                        if (count > 0) {
                            systemConfig.warningPlayCount = count
                        }
                    }
                }
            }

            ParameterRow {
                label: "工作模式"
                isComboBox: true
                comboModel: ["检修", "就地", "点动", "集控"]
                comboCurrentIndex: systemConfig ? systemConfig.workMode : 0
                onFieldComboChanged: function(newIndex) {
                    if (systemConfig) {
                        systemConfig.workMode = newIndex
                    }
                }
            }

            ParameterRow {
                label: "本机名称"
                value: systemConfig ? systemConfig.localDeviceName : "1号皮带"
                unit: ""
                keyboardMode: "chinese"
                onFieldValueChanged: function(newValue) {
                    if (systemConfig) {
                        systemConfig.localDeviceName = newValue
                    }
                }
            }

            // 旧代码：comboCurrentIndex: 0  // 硬编码，不绑定systemConfig，修改后无法保存
            // ✅ 2026-03-25 [Phase 7.48.88.17]: 绑定systemConfig，支持保存和回显
            ParameterRow {
                label: "速度选择"
                isComboBox: true
                comboModel: ["模拟", "电平", "频率"]
                comboCurrentIndex: systemConfig ? (systemConfig.speedSelection || 0) : 0
                onFieldComboChanged: function(newIndex) {
                    if (systemConfig) {
                        systemConfig.speedSelection = newIndex
                    }
                }
            }

            ParameterRow {
                label: "时间设置"
                value: Qt.formatDateTime(new Date(), "yyyy-MM-dd hh:mm:ss")
                unit: ""
                isDateTime: true
                dateTimePickerPopup: root.dateTimePopup
            }

            // 旧代码：comboCurrentIndex: 0  // 硬编码，不绑定systemConfig
            // ✅ 2026-03-25 [Phase 7.48.88.17]: 绑定systemConfig，支持保存和回显
            ParameterRow {
                label: "前级连锁"
                isComboBox: true
                comboModel: ["连锁", "解除"]
                comboCurrentIndex: systemConfig ? (systemConfig.frontInterlock || 0) : 0
                onFieldComboChanged: function(newIndex) {
                    if (systemConfig) {
                        systemConfig.frontInterlock = newIndex
                    }
                }
            }

            // 旧代码：comboCurrentIndex: 0
            // ✅ 2026-03-25 [Phase 7.48.88.17]: 绑定systemConfig
            ParameterRow {
                label: "后继连锁"
                isComboBox: true
                comboModel: ["连锁", "解除"]
                comboCurrentIndex: systemConfig ? (systemConfig.rearInterlock || 0) : 0
                onFieldComboChanged: function(newIndex) {
                    if (systemConfig) {
                        systemConfig.rearInterlock = newIndex
                    }
                }
            }

            // 旧代码：comboCurrentIndex: 0
            // ✅ 2026-03-25 [Phase 7.48.88.17]: 绑定systemConfig
            ParameterRow {
                label: "终端类型"
                isComboBox: true
                comboModel: ["智能", "普通"]
                comboCurrentIndex: systemConfig ? (systemConfig.terminalType || 0) : 0
                onFieldComboChanged: function(newIndex) {
                    if (systemConfig) {
                        systemConfig.terminalType = newIndex
                    }
                }
            }

            // 旧代码：comboCurrentIndex: 0
            // ✅ 2026-03-25 [Phase 7.48.88.17]: 绑定systemConfig
            ParameterRow {
                label: "终端投入"
                isComboBox: true
                comboModel: ["投入", "取消"]
                comboCurrentIndex: systemConfig ? (systemConfig.terminalEnabled || 0) : 0
                onFieldComboChanged: function(newIndex) {
                    if (systemConfig) {
                        systemConfig.terminalEnabled = newIndex
                    }
                }
            }

            // ✅ 2026-03-20 [Phase 7.48.60]: 皮带音频来源配置
            ParameterRow {
                label: "音频来源"
                isComboBox: true
                comboModel: ["默认(/app/AUDIO/)", "TTS合成"]
                comboCurrentIndex: systemConfig ? (systemConfig.beltAudioSource || 0) : 0
                onFieldComboChanged: function(newIndex) {
                    if (systemConfig) {
                        systemConfig.beltAudioSource = newIndex
                    }
                }
            }
        }
    }

    // Component: Parameter Row
    component ParameterRow: RowLayout {
        property string label: ""
        property string value: ""
        property string unit: ""
        property bool isComboBox: false
        property bool isDateTime: false
        property string keyboardMode: "numeric"  // "numeric", "english", "chinese"
        property var comboModel: []
        property int comboCurrentIndex: 0
        property var dateTimePickerPopup: null

        // Signals for value changes (renamed to avoid conflicts with built-in signals)
        signal fieldValueChanged(string newValue)
        signal fieldComboChanged(int newIndex)

        // ✅ 2026-03-25 [Phase 7.48.88.16.1]: 延迟滚动定时器，等待键盘完全弹出
        Timer {
            id: scrollTimer
            interval: 300
            repeat: false
            property var targetItem: null
            onTriggered: {
                if (targetItem && root.flickableParent && root.flickableParent.ensureVisible) {
                    root.flickableParent.ensureVisible(targetItem)
                }
            }
        }

        Layout.fillWidth: true
        spacing: 10

        Text {
            text: label + "："
            font.pixelSize: 16
            color: "#95a5a6"
            Layout.preferredWidth: 130
        }

        TextField {
            id: inputField
            visible: !isComboBox
            text: value
            font.pixelSize: 16
            color: "#ecf0f1"
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            readOnly: isDateTime  // Only datetime fields use custom picker

            // Set input hints based on keyboard mode
            inputMethodHints: {
                if (isDateTime) return Qt.ImhNone
                if (keyboardMode === "numeric") return Qt.ImhDigitsOnly
                if (keyboardMode === "english") return Qt.ImhNoPredictiveText | Qt.ImhPreferLowercase
                if (keyboardMode === "chinese") return Qt.ImhNone
                return Qt.ImhNone
            }

            background: Rectangle {
                color: "#1a2332"
                border.color: parent.activeFocus ? "#00d4ff" : "#34495e"
                border.width: 1
                radius: 5
            }

            // Emit signal when text changes
            onTextChanged: {
                if (!isDateTime) {
                    fieldValueChanged(text)
                }
            }

            // ✅ 2026-03-25 [Phase 7.48.88.16]: 虚拟键盘弹出时自动滚动到输入框
            // ✅ 2026-03-25 [Phase 7.48.88.16.1]: 延迟200ms等待键盘完全弹出后再计算
            onActiveFocusChanged: {
                if (activeFocus && root.flickableParent && root.flickableParent.ensureVisible) {
                    scrollTimer.targetItem = inputField
                    scrollTimer.start()
                }
            }

            // Only datetime fields need custom handling
            MouseArea {
                anchors.fill: parent
                enabled: isDateTime
                onClicked: {
                    if (isDateTime && dateTimePickerPopup) {
                        dateTimePickerPopup.openForField(inputField)
                    }
                }
            }
        }

        ComboBox {
            id: comboBox
            visible: isComboBox
            model: comboModel
            currentIndex: comboCurrentIndex
            Layout.fillWidth: true
            Layout.preferredHeight: 36

            // Emit signal when index changes
            onCurrentIndexChanged: {
                fieldComboChanged(currentIndex)
            }

            background: Rectangle {
                color: "#1a2332"
                border.color: comboBox.down ? "#00d4ff" : "#34495e"
                border.width: 1
                radius: 5
            }

            contentItem: Text {
                text: comboBox.displayText
                font.pixelSize: 16
                color: "#ecf0f1"
                verticalAlignment: Text.AlignVCenter
                leftPadding: 10
            }

            delegate: ItemDelegate {
                width: comboBox.width
                height: 36
                highlighted: comboBox.highlightedIndex === index

                background: Rectangle {
                    color: highlighted ? "#2a3f54" : "#1a2332"
                    border.color: highlighted ? "#00d4ff" : "transparent"
                    border.width: 1
                }

                contentItem: Text {
                    text: modelData
                    font.pixelSize: 16
                    color: "#ecf0f1"
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 10
                }
            }

            popup: Popup {
                y: comboBox.height
                width: comboBox.width
                implicitHeight: contentItem.implicitHeight
                padding: 1

                background: Rectangle {
                    color: "#1a2332"
                    border.color: "#00d4ff"
                    border.width: 2
                    radius: 5
                }

                contentItem: ListView {
                    clip: true
                    implicitHeight: contentHeight
                    model: comboBox.delegateModel
                    currentIndex: comboBox.highlightedIndex
                    ScrollIndicator.vertical: ScrollIndicator { }
                }
            }
        }

        Text {
            visible: !isComboBox && unit !== ""
            text: unit
            font.pixelSize: 16
            color: "#7f8c8d"
            Layout.preferredWidth: 50
        }
    }
}
