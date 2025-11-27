import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5
import QtQuick.Dialogs

// Protection Settings Dialog
// Configure protection parameters
Dialog {
    id: root
    width: 500
    height: 600
    modal: true
    title: protectionName ? ("设置保护参数 - " + protectionName) : "新增保护"
    anchors.centerIn: parent

    property string protectionName: ""
    property string protectionType: "analog"  // analog or digital
    property bool isNewProtection: false

    // Parameters
    property real upperLimit: 5.0
    property real lowerLimit: 0.0
    property real range: 10.0
    property real ratedValue: 2.5
    property bool enabled: true
    property string audioFile: ""
    property string alarmColor: "#ff4757"

    background: Rectangle {
        color: "#1a2332"
        radius: 10
        border.color: "#00d4ff"
        border.width: 2
    }

    contentItem: ScrollView {
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 15

            // New protection specific fields
            ColumnLayout {
                visible: root.isNewProtection
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "保护名称"
                    font.pixelSize: 14
                    color: "#00d4ff"
                }

                TextField {
                    id: nameField
                    Layout.fillWidth: true
                    placeholderText: "输入保护名称"
                    color: "#00d4ff"
                    background: Rectangle {
                        color: "#2c3e50"
                        radius: 5
                        border.color: "#00d4ff"
                        border.width: 1
                    }
                }

                Text {
                    text: "保护类型"
                    font.pixelSize: 14
                    color: "#00d4ff"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 20

                    RadioButton {
                        id: analogRadio
                        text: "模拟量"
                        checked: root.protectionType === "analog"
                        onCheckedChanged: if (checked) root.protectionType = "analog"

                        contentItem: Text {
                            text: analogRadio.text
                            font.pixelSize: 13
                            color: "#00d4ff"
                            leftPadding: analogRadio.indicator.width + analogRadio.spacing
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    RadioButton {
                        id: digitalRadio
                        text: "开关量"
                        checked: root.protectionType === "digital"
                        onCheckedChanged: if (checked) root.protectionType = "digital"

                        contentItem: Text {
                            text: digitalRadio.text
                            font.pixelSize: 13
                            color: "#00d4ff"
                            leftPadding: digitalRadio.indicator.width + digitalRadio.spacing
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#34495e"
                }
            }

            // Analog quantity settings
            ColumnLayout {
                visible: root.protectionType === "analog"
                Layout.fillWidth: true
                spacing: 15

                // Upper Limit
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        text: "上限值"
                        font.pixelSize: 14
                        color: "#00d4ff"
                    }

                    SpinBox {
                        id: upperLimitSpin
                        Layout.fillWidth: true
                        from: 0
                        to: 1000
                        value: root.upperLimit * 10
                        stepSize: 1
                        editable: true

                        property int decimals: 1
                        property real realValue: value / 10

                        validator: DoubleValidator {
                            bottom: Math.min(upperLimitSpin.from, upperLimitSpin.to)
                            top: Math.max(upperLimitSpin.from, upperLimitSpin.to)
                        }

                        textFromValue: function(value, locale) {
                            return Number(value / 10).toLocaleString(locale, 'f', decimals)
                        }

                        valueFromText: function(text, locale) {
                            return Number.fromLocaleString(locale, text) * 10
                        }

                        background: Rectangle {
                            color: "#2c3e50"
                            radius: 5
                            border.color: "#00d4ff"
                            border.width: 1
                        }

                        contentItem: TextInput {
                            text: upperLimitSpin.textFromValue(upperLimitSpin.value, upperLimitSpin.locale)
                            font.pixelSize: 13
                            color: "#00d4ff"
                            horizontalAlignment: Qt.AlignHCenter
                            verticalAlignment: Qt.AlignVCenter
                            readOnly: !upperLimitSpin.editable
                            validator: upperLimitSpin.validator
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }
                    }
                }

                // Lower Limit
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        text: "下限值"
                        font.pixelSize: 14
                        color: "#00d4ff"
                    }

                    SpinBox {
                        id: lowerLimitSpin
                        Layout.fillWidth: true
                        from: 0
                        to: 1000
                        value: root.lowerLimit * 10
                        stepSize: 1
                        editable: true

                        property int decimals: 1
                        property real realValue: value / 10

                        textFromValue: function(value, locale) {
                            return Number(value / 10).toLocaleString(locale, 'f', decimals)
                        }

                        valueFromText: function(text, locale) {
                            return Number.fromLocaleString(locale, text) * 10
                        }

                        background: Rectangle {
                            color: "#2c3e50"
                            radius: 5
                            border.color: "#00d4ff"
                            border.width: 1
                        }

                        contentItem: TextInput {
                            text: lowerLimitSpin.textFromValue(lowerLimitSpin.value, lowerLimitSpin.locale)
                            font.pixelSize: 13
                            color: "#00d4ff"
                            horizontalAlignment: Qt.AlignHCenter
                            verticalAlignment: Qt.AlignVCenter
                            readOnly: !lowerLimitSpin.editable
                            validator: lowerLimitSpin.validator
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }
                    }
                }

                // Range
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        text: "量程"
                        font.pixelSize: 14
                        color: "#00d4ff"
                    }

                    SpinBox {
                        id: rangeSpin
                        Layout.fillWidth: true
                        from: 1
                        to: 10000
                        value: root.range * 10
                        stepSize: 10

                        property int decimals: 1
                        property real realValue: value / 10

                        textFromValue: function(value, locale) {
                            return Number(value / 10).toLocaleString(locale, 'f', decimals)
                        }

                        background: Rectangle {
                            color: "#2c3e50"
                            radius: 5
                            border.color: "#00d4ff"
                            border.width: 1
                        }

                        contentItem: TextInput {
                            text: rangeSpin.textFromValue(rangeSpin.value, rangeSpin.locale)
                            font.pixelSize: 13
                            color: "#00d4ff"
                            horizontalAlignment: Qt.AlignHCenter
                            verticalAlignment: Qt.AlignVCenter
                        }
                    }
                }

                // Rated Value
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        text: "额定值"
                        font.pixelSize: 14
                        color: "#00d4ff"
                    }

                    SpinBox {
                        id: ratedValueSpin
                        Layout.fillWidth: true
                        from: 0
                        to: 1000
                        value: root.ratedValue * 10
                        stepSize: 1
                        editable: true

                        property int decimals: 1
                        property real realValue: value / 10

                        textFromValue: function(value, locale) {
                            return Number(value / 10).toLocaleString(locale, 'f', decimals)
                        }

                        valueFromText: function(text, locale) {
                            return Number.fromLocaleString(locale, text) * 10
                        }

                        background: Rectangle {
                            color: "#2c3e50"
                            radius: 5
                            border.color: "#00d4ff"
                            border.width: 1
                        }

                        contentItem: TextInput {
                            text: ratedValueSpin.textFromValue(ratedValueSpin.value, ratedValueSpin.locale)
                            font.pixelSize: 13
                            color: "#00d4ff"
                            horizontalAlignment: Qt.AlignHCenter
                            verticalAlignment: Qt.AlignVCenter
                            readOnly: !ratedValueSpin.editable
                            validator: ratedValueSpin.validator
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }
                    }
                }
            }

            // Common settings
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#34495e"
            }

            // Enable toggle
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "投入运行"
                    font.pixelSize: 14
                    color: "#00d4ff"
                }

                Switch {
                    id: enabledSwitch
                    checked: root.enabled

                    indicator: Rectangle {
                        implicitWidth: 48
                        implicitHeight: 24
                        radius: 12
                        color: enabledSwitch.checked ? "#00ff88" : "#95a5a6"
                        border.color: enabledSwitch.checked ? "#00ff88" : "#7f8c8d"

                        Rectangle {
                            x: enabledSwitch.checked ? parent.width - width - 2 : 2
                            y: 2
                            width: 20
                            height: 20
                            radius: 10
                            color: "white"

                            Behavior on x {
                                NumberAnimation { duration: 200 }
                            }
                        }
                    }
                }
            }

            // Audio file
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5

                Text {
                    text: "报警音频文件"
                    font.pixelSize: 14
                    color: "#00d4ff"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    TextField {
                        id: audioFileField
                        Layout.fillWidth: true
                        text: root.audioFile
                        placeholderText: "选择音频文件..."
                        readOnly: true
                        color: "#00d4ff"

                        background: Rectangle {
                            color: "#2c3e50"
                            radius: 5
                            border.color: "#00d4ff"
                            border.width: 1
                        }
                    }

                    Button {
                        text: "浏览"
                        onClicked: fileDialog.open()

                        background: Rectangle {
                            color: "#3498db"
                            radius: 5
                        }

                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 12
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }

            // Alarm color picker
            ColumnLayout {
                visible: root.isNewProtection
                Layout.fillWidth: true
                spacing: 5

                Text {
                    text: "报警颜色"
                    font.pixelSize: 14
                    color: "#00d4ff"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        width: 40
                        height: 40
                        radius: 5
                        color: root.alarmColor
                        border.color: "#00d4ff"
                        border.width: 2

                        MouseArea {
                            anchors.fill: parent
                            onClicked: colorDialog.open()
                            cursorShape: Qt.PointingHandCursor
                        }
                    }

                    Text {
                        text: root.alarmColor
                        font.pixelSize: 13
                        color: "#95a5a6"
                    }
                }
            }
        }
    }

    footer: DialogButtonBox {
        Button {
            text: "确定"
            DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole

            background: Rectangle {
                color: "#00ff88"
                radius: 5
            }

            contentItem: Text {
                text: parent.text
                font.pixelSize: 13
                font.bold: true
                color: "#1a2332"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        Button {
            text: "取消"
            DialogButtonBox.buttonRole: DialogButtonBox.RejectRole

            background: Rectangle {
                color: "#95a5a6"
                radius: 5
            }

            contentItem: Text {
                text: parent.text
                font.pixelSize: 13
                color: "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        background: Rectangle {
            color: "#2c3e50"
        }
    }

    onAccepted: {
        root.upperLimit = upperLimitSpin.realValue
        root.lowerLimit = lowerLimitSpin.realValue
        root.range = rangeSpin.realValue
        root.ratedValue = ratedValueSpin.realValue
        root.enabled = enabledSwitch.checked
        root.audioFile = audioFileField.text

        if (root.isNewProtection) {
            root.protectionName = nameField.text
        }
    }

    // File dialog for audio file selection
    FileDialog {
        id: fileDialog
        title: "选择音频文件"
        nameFilters: ["音频文件 (*.wav *.mp3 *.ogg)"]
        onAccepted: {
            audioFileField.text = fileDialog.selectedFile
        }
    }

    // Color dialog
    ColorDialog {
        id: colorDialog
        title: "选择报警颜色"
        onAccepted: {
            root.alarmColor = colorDialog.selectedColor
        }
    }
}
