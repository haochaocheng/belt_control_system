import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// DateTime Picker Popup Component
Popup {
    id: root
    width: 450
    height: 380
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape
    anchors.centerIn: Overlay.overlay

    property var targetTextField: null
    property date selectedDate: new Date()

    function openForField(textField) {
        targetTextField = textField
        selectedDate = new Date()
        root.open()
    }

    background: Rectangle {
        color: "#1a2332"
        radius: 10
        border.color: "#00d4ff"
        border.width: 2
    }

    contentItem: ColumnLayout {
        spacing: 15

        Text {
            text: "时间日期设置"
            font.pixelSize: 20
            font.bold: true
            color: "#00d4ff"
            Layout.alignment: Qt.AlignHCenter
        }

        Rectangle {
            Layout.fillWidth: true
            height: 2
            color: "#00d4ff"
            opacity: 0.5
        }

        // Date Selection
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "日期"
                font.pixelSize: 16
                color: "#95a5a6"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                SpinBox {
                    id: yearSpinBox
                    from: 2000
                    to: 2100
                    value: root.selectedDate.getFullYear()
                    editable: true
                    Layout.preferredWidth: 110

                    contentItem: TextInput {
                        text: parent.textFromValue(parent.value, parent.locale)
                        font.pixelSize: 16
                        color: "#ecf0f1"
                        horizontalAlignment: Qt.AlignHCenter
                        verticalAlignment: Qt.AlignVCenter
                        readOnly: !parent.editable
                        validator: parent.validator
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                    }

                    background: Rectangle {
                        color: "#0a1628"
                        border.color: "#00d4ff"
                        radius: 5
                    }
                }

                Text { text: "年"; color: "#95a5a6"; font.pixelSize: 16 }

                SpinBox {
                    id: monthSpinBox
                    from: 1
                    to: 12
                    value: root.selectedDate.getMonth() + 1
                    editable: true
                    Layout.preferredWidth: 90

                    contentItem: TextInput {
                        text: parent.textFromValue(parent.value, parent.locale)
                        font.pixelSize: 16
                        color: "#ecf0f1"
                        horizontalAlignment: Qt.AlignHCenter
                        verticalAlignment: Qt.AlignVCenter
                        readOnly: !parent.editable
                        validator: parent.validator
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                    }

                    background: Rectangle {
                        color: "#0a1628"
                        border.color: "#00d4ff"
                        radius: 5
                    }
                }

                Text { text: "月"; color: "#95a5a6"; font.pixelSize: 16 }

                SpinBox {
                    id: daySpinBox
                    from: 1
                    to: 31
                    value: root.selectedDate.getDate()
                    editable: true
                    Layout.preferredWidth: 90

                    contentItem: TextInput {
                        text: parent.textFromValue(parent.value, parent.locale)
                        font.pixelSize: 16
                        color: "#ecf0f1"
                        horizontalAlignment: Qt.AlignHCenter
                        verticalAlignment: Qt.AlignVCenter
                        readOnly: !parent.editable
                        validator: parent.validator
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                    }

                    background: Rectangle {
                        color: "#0a1628"
                        border.color: "#00d4ff"
                        radius: 5
                    }
                }

                Text { text: "日"; color: "#95a5a6"; font.pixelSize: 16 }
            }
        }

        // Time Selection
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "时间"
                font.pixelSize: 16
                color: "#95a5a6"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                SpinBox {
                    id: hourSpinBox
                    from: 0
                    to: 23
                    value: root.selectedDate.getHours()
                    editable: true
                    Layout.preferredWidth: 90

                    contentItem: TextInput {
                        text: parent.textFromValue(parent.value, parent.locale)
                        font.pixelSize: 16
                        color: "#ecf0f1"
                        horizontalAlignment: Qt.AlignHCenter
                        verticalAlignment: Qt.AlignVCenter
                        readOnly: !parent.editable
                        validator: parent.validator
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                    }

                    background: Rectangle {
                        color: "#0a1628"
                        border.color: "#00d4ff"
                        radius: 5
                    }
                }

                Text { text: "时"; color: "#95a5a6"; font.pixelSize: 16 }

                SpinBox {
                    id: minuteSpinBox
                    from: 0
                    to: 59
                    value: root.selectedDate.getMinutes()
                    editable: true
                    Layout.preferredWidth: 90

                    contentItem: TextInput {
                        text: parent.textFromValue(parent.value, parent.locale)
                        font.pixelSize: 16
                        color: "#ecf0f1"
                        horizontalAlignment: Qt.AlignHCenter
                        verticalAlignment: Qt.AlignVCenter
                        readOnly: !parent.editable
                        validator: parent.validator
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                    }

                    background: Rectangle {
                        color: "#0a1628"
                        border.color: "#00d4ff"
                        radius: 5
                    }
                }

                Text { text: "分"; color: "#95a5a6"; font.pixelSize: 16 }

                SpinBox {
                    id: secondSpinBox
                    from: 0
                    to: 59
                    value: root.selectedDate.getSeconds()
                    editable: true
                    Layout.preferredWidth: 90

                    contentItem: TextInput {
                        text: parent.textFromValue(parent.value, parent.locale)
                        font.pixelSize: 16
                        color: "#ecf0f1"
                        horizontalAlignment: Qt.AlignHCenter
                        verticalAlignment: Qt.AlignVCenter
                        readOnly: !parent.editable
                        validator: parent.validator
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                    }

                    background: Rectangle {
                        color: "#0a1628"
                        border.color: "#00d4ff"
                        radius: 5
                    }
                }

                Text { text: "秒"; color: "#95a5a6"; font.pixelSize: 16 }
            }
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 45
                text: "确定"
                background: Rectangle {
                    color: parent.pressed ? "#27ae60" : "#2ecc71"
                    radius: 5
                    border.color: "#00d4ff"
                    border.width: 2
                }
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    var newDate = new Date(
                        yearSpinBox.value,
                        monthSpinBox.value - 1,
                        daySpinBox.value,
                        hourSpinBox.value,
                        minuteSpinBox.value,
                        secondSpinBox.value
                    )
                    if (root.targetTextField) {
                        root.targetTextField.text = Qt.formatDateTime(newDate, "yyyy-MM-dd hh:mm:ss")
                    }
                    root.close()
                }
            }

            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 45
                text: "取消"
                background: Rectangle {
                    color: parent.pressed ? "#7f8c8d" : "#95a5a6"
                    radius: 5
                    border.color: "#00d4ff"
                    border.width: 2
                }
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: root.close()
            }
        }
    }
}
