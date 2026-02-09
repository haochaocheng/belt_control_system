// DIModulePanel.qml
// 开关量模块显示面板 - LED指示灯显示8位开关量状态
// 创建日期: 2026-02-09
// ✅ 2026-02-09 [Phase 7.44.7]: 开关量显示组件

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "#ECF0F1"
    radius: 8
    border.width: 2
    border.color: "#BDC3C7"
    height: 150

    // ========== 公开属性 ==========
    property int moduleIndex: 0
    property string moduleName: "开关量输入"
    property var bitsData: []  // 8位布尔值数组

    // ========== 布局 ==========
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10

        // 标题行
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: moduleName
                font.pixelSize: 18
                font.bold: true
                color: "#2C3E50"
            }

            Item { Layout.fillWidth: true }

            // 连接状态指示
            Rectangle {
                width: 20
                height: 20
                radius: 10
                color: getConnectionStatus() ? "#27AE60" : "#E74C3C"

                SequentialAnimation on opacity {
                    running: getConnectionStatus()
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 0.3; duration: 800 }
                    NumberAnimation { from: 0.3; to: 1.0; duration: 800 }
                }
            }

            Text {
                text: getConnectionStatus() ? "已连接" : "未连接"
                font.pixelSize: 14
                color: getConnectionStatus() ? "#27AE60" : "#E74C3C"
            }
        }

        // LED指示灯行
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 8
            rowSpacing: 5
            columnSpacing: 10

            Repeater {
                model: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 5

                    // 位编号
                    Text {
                        text: "位" + index
                        font.pixelSize: 14
                        color: "#7F8C8D"
                        Layout.alignment: Qt.AlignHCenter
                    }

                    // LED指示灯
                    Rectangle {
                        Layout.preferredWidth: 50
                        Layout.preferredHeight: 50
                        Layout.alignment: Qt.AlignHCenter
                        radius: 25
                        color: getBitValue(index) ? "#27AE60" : "#95A5A6"
                        border.width: 3
                        border.color: getBitValue(index) ? "#229954" : "#7F8C8D"

                        // 发光效果
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * 0.6
                            height: parent.height * 0.6
                            radius: width / 2
                            color: "white"
                            opacity: getBitValue(index) ? 0.6 : 0.2
                        }

                        // 闪烁动画（仅在状态为1时）
                        SequentialAnimation on opacity {
                            running: getBitValue(index)
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.7; duration: 500 }
                            NumberAnimation { from: 0.7; to: 1.0; duration: 500 }
                        }
                    }

                    // 状态文本
                    Text {
                        text: getBitValue(index) ? "ON" : "OFF"
                        font.pixelSize: 14
                        font.bold: true
                        color: getBitValue(index) ? "#27AE60" : "#7F8C8D"
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }

        // 字节值显示
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "字节值:"
                font.pixelSize: 14
                color: "#7F8C8D"
            }

            Text {
                text: getByteValue().toString(16).toUpperCase().padStart(2, '0') + "h (" + getByteValue() + ")"
                font.pixelSize: 16
                font.bold: true
                font.family: "Courier New"
                color: "#2C3E50"
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "二进制:"
                font.pixelSize: 14
                color: "#7F8C8D"
            }

            Text {
                text: getBinaryString()
                font.pixelSize: 16
                font.bold: true
                font.family: "Courier New"
                color: "#2C3E50"
            }
        }
    }

    // ========== 辅助函数 ==========
    function getBitValue(index) {
        if (!bitsData || index < 0 || index >= bitsData.length) {
            return false
        }
        return bitsData[index] === true || bitsData[index] === 1
    }

    function getByteValue() {
        var value = 0
        for (var i = 0; i < 8; i++) {
            if (getBitValue(i)) {
                value |= (1 << i)
            }
        }
        return value
    }

    function getBinaryString() {
        var str = ""
        for (var i = 7; i >= 0; i--) {
            str += getBitValue(i) ? "1" : "0"
            if (i === 4) str += " "  // 中间加空格
        }
        return str
    }

    function getConnectionStatus() {
        if (!mqttAutoManager || !mqttAutoManager.healthStatus) {
            return false
        }
        var healthStatus = mqttAutoManager.healthStatus
        if (moduleIndex >= 0 && moduleIndex < healthStatus.length) {
            return healthStatus[moduleIndex].connected
        }
        return false
    }

    // ========== 数据变化监听 ==========
    Connections {
        target: diDataManager
        function onBitChanged(modIndex, bitIndex, value) {
            if (modIndex === moduleIndex) {
                console.log("🔄 [DIModulePanel] 模块" + moduleIndex + "位" + bitIndex + "变化:" + value)
            }
        }
    }
}
