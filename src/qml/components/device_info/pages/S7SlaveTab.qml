// S7SlaveTab.qml
// S7 从站（服务器）配置Tab
// 创建日期: 2026-02-08
// ✅ 2026-02-08 [Phase 7.42]: TCP控制功能实现
// 使用 Snap7 库实现西门子 S7 协议

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "transparent"

    // ========== 公开属性 ==========
    property var currentPort: null
    property int focusParamIndex: -1
    property var virtualKeyboard: null

    // ========== 参数数据 ==========
    property int portNumber: 102  // S7 标准端口
    property bool isEnabled: false
    property string bindIP: "0.0.0.0"
    property int maxConnections: 8
    property int dbCount: 10
    property int dbSize: 1024
    property int merkerSize: 256
    property int inputSize: 128
    property int outputSize: 128

    // ========== 函数 ==========
    function getParamFieldCount() {
        return 9
    }

    function triggerParamInput(index) {
        console.log("✅ [S7SlaveTab] triggerParamInput:", index)
    }

    function handleEnterKey() {
        console.log("✅ [S7SlaveTab] handleEnterKey - focusParamIndex:", focusParamIndex)
        return true
    }

    // ========== 主布局 ==========
    ScrollView {
        anchors.fill: parent
        anchors.margins: 10
        clip: true

        GridLayout {
            width: parent.width - 20
            columns: 2
            columnSpacing: 20
            rowSpacing: 15

            // 端口号
            Label {
                text: "端口号:"
                color: "#E0E0E0"
                font.pixelSize: 14
            }
            Rectangle {
                Layout.fillWidth: true
                height: 35
                color: "#2a3142"
                border.color: focusParamIndex === 0 ? "#2196F3" : "#3d4556"
                border.width: focusParamIndex === 0 ? 2 : 1
                radius: 4

                TextInput {
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.portNumber
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    onTextChanged: root.portNumber = parseInt(text) || 102
                }
            }

            // 状态
            Label {
                text: "状态:"
                color: "#E0E0E0"
                font.pixelSize: 14
            }
            ComboBox {
                Layout.fillWidth: true
                model: ["关闭", "打开"]
                currentIndex: root.isEnabled ? 1 : 0
                onCurrentIndexChanged: root.isEnabled = (currentIndex === 1)

                background: Rectangle {
                    color: "#2a3142"
                    border.color: focusParamIndex === 1 ? "#2196F3" : "#3d4556"
                    border.width: focusParamIndex === 1 ? 2 : 1
                    radius: 4
                }
            }

            // 绑定IP
            Label {
                text: "绑定IP:"
                color: "#E0E0E0"
                font.pixelSize: 14
            }
            Rectangle {
                Layout.fillWidth: true
                height: 35
                color: "#2a3142"
                border.color: focusParamIndex === 2 ? "#2196F3" : "#3d4556"
                border.width: focusParamIndex === 2 ? 2 : 1
                radius: 4

                TextInput {
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.bindIP
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    onTextChanged: root.bindIP = text
                }
            }

            // 最大连接数
            Label {
                text: "最大连接数:"
                color: "#E0E0E0"
                font.pixelSize: 14
            }
            Rectangle {
                Layout.fillWidth: true
                height: 35
                color: "#2a3142"
                border.color: focusParamIndex === 3 ? "#2196F3" : "#3d4556"
                border.width: focusParamIndex === 3 ? 2 : 1
                radius: 4

                TextInput {
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.maxConnections
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    onTextChanged: root.maxConnections = parseInt(text) || 8
                }
            }

            // DB数量
            Label {
                text: "DB数量:"
                color: "#E0E0E0"
                font.pixelSize: 14
            }
            Rectangle {
                Layout.fillWidth: true
                height: 35
                color: "#2a3142"
                border.color: focusParamIndex === 4 ? "#2196F3" : "#3d4556"
                border.width: focusParamIndex === 4 ? 2 : 1
                radius: 4

                TextInput {
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.dbCount
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    onTextChanged: root.dbCount = parseInt(text) || 10
                }
            }

            // DB大小
            Label {
                text: "DB大小(字节):"
                color: "#E0E0E0"
                font.pixelSize: 14
            }
            Rectangle {
                Layout.fillWidth: true
                height: 35
                color: "#2a3142"
                border.color: focusParamIndex === 5 ? "#2196F3" : "#3d4556"
                border.width: focusParamIndex === 5 ? 2 : 1
                radius: 4

                TextInput {
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.dbSize
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    onTextChanged: root.dbSize = parseInt(text) || 1024
                }
            }

            // Merker大小
            Label {
                text: "M区大小(字节):"
                color: "#E0E0E0"
                font.pixelSize: 14
            }
            Rectangle {
                Layout.fillWidth: true
                height: 35
                color: "#2a3142"
                border.color: focusParamIndex === 6 ? "#2196F3" : "#3d4556"
                border.width: focusParamIndex === 6 ? 2 : 1
                radius: 4

                TextInput {
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.merkerSize
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    onTextChanged: root.merkerSize = parseInt(text) || 256
                }
            }

            // 输入大小
            Label {
                text: "I区大小(字节):"
                color: "#E0E0E0"
                font.pixelSize: 14
            }
            Rectangle {
                Layout.fillWidth: true
                height: 35
                color: "#2a3142"
                border.color: focusParamIndex === 7 ? "#2196F3" : "#3d4556"
                border.width: focusParamIndex === 7 ? 2 : 1
                radius: 4

                TextInput {
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.inputSize
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    onTextChanged: root.inputSize = parseInt(text) || 128
                }
            }

            // 输出大小
            Label {
                text: "Q区大小(字节):"
                color: "#E0E0E0"
                font.pixelSize: 14
            }
            Rectangle {
                Layout.fillWidth: true
                height: 35
                color: "#2a3142"
                border.color: focusParamIndex === 8 ? "#2196F3" : "#3d4556"
                border.width: focusParamIndex === 8 ? 2 : 1
                radius: 4

                TextInput {
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.outputSize
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    onTextChanged: root.outputSize = parseInt(text) || 128
                }
            }
        }
    }
}
