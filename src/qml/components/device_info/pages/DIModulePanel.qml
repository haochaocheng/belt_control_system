// DIModulePanel.qml - 科技风格版本
// 开关量模块显示面板 - 深色科技风格LED指示灯显示
// ✅ 2026-02-09 [Phase 7.44.22]: 重新设计为深色科技风格
// 使用方法：将此文件内容复制到 src/qml/components/device_info/pages/DIModulePanel.qml

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "#1a1f2e"  // 深色背景
    radius: 8
    border.width: 2
    border.color: "#00d4ff"  // 青色发光边框
    // ✅ 2026-02-09 [Phase 7.44.23]: 移除固定高度，让面板填充整个可用空间
    // height: 220  // 注释掉固定高度

    // 外层发光效果
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.width: 1
        border.color: "#00d4ff"
        opacity: 0.3
        z: -1
    }

    // ========== 公开属性 ==========
    property int moduleIndex: 0
    property string moduleName: "开关量输入"
    property var bitsData: []

    // ========== 布局 ==========
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15  // ✅ 2026-02-09 [Phase 7.44.23]: 20 → 15，减少边距
        spacing: 12  // ✅ 2026-02-09 [Phase 7.44.23]: 15 → 12，减少间距

        // 标题行
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40  // ✅ 2026-02-09 [Phase 7.44.23]: 35 → 40，增加标题行高度
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                radius: 4
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#2a3f5f" }
                    GradientStop { position: 1.0; color: "#1a2f4f" }
                }
                opacity: 0.5
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 10

                Rectangle {
                    width: 4
                    Layout.fillHeight: true
                    color: "#00d4ff"
                    radius: 2
                }

                Text {
                    text: moduleName
                    font.pixelSize: 24  // ✅ 2026-02-09 [Phase 7.44.23]: 18 → 24，增大标题字体
                    font.bold: true
                    font.family: "Microsoft YaHei"
                    color: "#00d4ff"
                    style: Text.Outline
                    styleColor: "#00d4ff"
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 12
                    height: 12
                    radius: 6
                    color: "#00ff00"

                    SequentialAnimation on opacity {
                        running: true
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.3; duration: 1000 }
                        NumberAnimation { from: 0.3; to: 1.0; duration: 1000 }
                    }
                }
            }
        }

        // LED指示灯行
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 8
            rowSpacing: 10  // ✅ 2026-02-09 [Phase 7.44.23]: 8 → 10，增加行间距
            columnSpacing: 15  // ✅ 2026-02-09 [Phase 7.44.23]: 12 → 15，增加列间距

            Repeater {
                model: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10  // ✅ 2026-02-09 [Phase 7.44.23]: 8 → 10，增加内部间距

                    Rectangle {
                        Layout.preferredWidth: 70  // ✅ 2026-02-09 [Phase 7.44.23]: 60 → 70，增加标签宽度
                        Layout.preferredHeight: 26  // ✅ 2026-02-09 [Phase 7.44.23]: 22 → 26，增加标签高度
                        Layout.alignment: Qt.AlignHCenter
                        color: "#0a0f1e"
                        radius: 3
                        border.width: 1
                        border.color: "#00d4ff"

                        Text {
                            anchors.centerIn: parent
                            text: "BIT " + index
                            font.pixelSize: 14  // ✅ 2026-02-09 [Phase 7.44.23]: 11 → 14，增大BIT标签字体
                            font.bold: true
                            font.family: "Consolas"
                            color: "#00d4ff"
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 80  // ✅ 2026-02-09 [Phase 7.44.23]: 60 → 80，增加LED尺寸
                        Layout.preferredHeight: 80  // ✅ 2026-02-09 [Phase 7.44.23]: 60 → 80，增加LED尺寸
                        Layout.alignment: Qt.AlignHCenter
                        color: "#0a0f1e"
                        radius: 40  // ✅ 2026-02-09 [Phase 7.44.23]: 30 → 40，调整圆角
                        border.width: 2
                        border.color: getBitValue(index) ? "#00ff00" : "#2a3f5f"

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width + 8
                            height: parent.height + 8
                            radius: (parent.width + 8) / 2
                            color: "transparent"
                            border.width: 2
                            border.color: getBitValue(index) ? "#00ff00" : "transparent"
                            opacity: 0.3
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * 0.7
                            height: parent.height * 0.7
                            radius: width / 2

                            gradient: Gradient {
                                GradientStop {
                                    position: 0.0
                                    color: getBitValue(index) ? "#00ff00" : "#2a3f5f"
                                }
                                GradientStop {
                                    position: 1.0
                                    color: getBitValue(index) ? "#00aa00" : "#1a2f4f"
                                }
                            }
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -8
                            width: parent.width * 0.4
                            height: parent.height * 0.4
                            radius: width / 2
                            color: "white"
                            opacity: getBitValue(index) ? 0.8 : 0.1
                        }

                        SequentialAnimation on opacity {
                            running: getBitValue(index)
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.6; duration: 600 }
                            NumberAnimation { from: 0.6; to: 1.0; duration: 600 }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 70  // ✅ 2026-02-09 [Phase 7.44.23]: 60 → 70，增加状态标签宽度
                        Layout.preferredHeight: 26  // ✅ 2026-02-09 [Phase 7.44.23]: 22 → 26，增加状态标签高度
                        Layout.alignment: Qt.AlignHCenter
                        color: "#0a0f1e"
                        radius: 3
                        border.width: 1
                        border.color: getBitValue(index) ? "#00ff00" : "#2a3f5f"

                        Text {
                            anchors.centerIn: parent
                            text: getBitValue(index) ? "ON" : "OFF"
                            font.pixelSize: 14  // ✅ 2026-02-09 [Phase 7.44.23]: 12 → 14，增大状态字体
                            font.bold: false  // ✅ 2026-02-09 [Phase 7.44.23]: 移除粗体，提高可读性
                            font.family: "Consolas"
                            color: getBitValue(index) ? "#00ff00" : "#5a6f8f"
                        }
                    }
                }
            }
        }

        // 字节值显示
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50  // ✅ 2026-02-09 [Phase 7.44.23]: 45 → 50，增加字节值显示区域高度
            color: "#0a0f1e"
            radius: 6
            border.width: 2
            border.color: "#00d4ff"

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: 4
                color: "transparent"
                border.width: 1
                border.color: "#00d4ff"
                opacity: 0.2
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 20

                RowLayout {
                    spacing: 10  // ✅ 2026-02-09 [Phase 7.44.23]: 8 → 10，增加间距

                    Text {
                        text: "HEX:"
                        font.pixelSize: 16  // ✅ 2026-02-09 [Phase 7.44.23]: 14 → 16，增大标签字体
                        font.bold: true
                        font.family: "Consolas"
                        color: "#5a6f8f"
                    }

                    Text {
                        text: "0x" + getByteValue().toString(16).toUpperCase().padStart(2, '0')
                        font.pixelSize: 24  // ✅ 2026-02-09 [Phase 7.44.23]: 20 → 24，增大数值字体
                        font.bold: false  // ✅ 2026-02-09 [Phase 7.44.23]: 移除粗体，提高可读性
                        font.family: "Consolas"
                        color: "#00d4ff"
                        style: Text.Outline
                        styleColor: "#00d4ff"
                    }
                }

                Rectangle {
                    width: 2
                    Layout.fillHeight: true
                    color: "#2a3f5f"
                }

                RowLayout {
                    spacing: 10  // ✅ 2026-02-09 [Phase 7.44.23]: 8 → 10，增加间距

                    Text {
                        text: "DEC:"
                        font.pixelSize: 16  // ✅ 2026-02-09 [Phase 7.44.23]: 14 → 16，增大标签字体
                        font.bold: true
                        font.family: "Consolas"
                        color: "#5a6f8f"
                    }

                    Text {
                        text: getByteValue().toString().padStart(3, '0')
                        font.pixelSize: 24  // ✅ 2026-02-09 [Phase 7.44.23]: 20 → 24，增大数值字体
                        font.bold: false  // ✅ 2026-02-09 [Phase 7.44.23]: 移除粗体，提高可读性
                        font.family: "Consolas"
                        color: "#00d4ff"
                        style: Text.Outline
                        styleColor: "#00d4ff"
                    }
                }

                Item { Layout.fillWidth: true }

                RowLayout {
                    spacing: 10  // ✅ 2026-02-09 [Phase 7.44.23]: 8 → 10，增加间距

                    Text {
                        text: "BIN:"
                        font.pixelSize: 16  // ✅ 2026-02-09 [Phase 7.44.23]: 14 → 16，增大标签字体
                        font.bold: true
                        font.family: "Consolas"
                        color: "#5a6f8f"
                    }

                    Text {
                        text: getBinaryString()
                        font.pixelSize: 22  // ✅ 2026-02-09 [Phase 7.44.23]: 18 → 22，增大二进制字体
                        font.bold: false  // ✅ 2026-02-09 [Phase 7.44.23]: 移除粗体，提高可读性
                        font.family: "Consolas"
                        font.letterSpacing: 2
                        color: "#00ff00"
                        style: Text.Outline
                        styleColor: "#00ff00"
                    }
                }
            }
        }
    }

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
            if (i === 4) str += " "
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

    Connections {
        target: diDataManager
        function onBitChanged(modIndex, bitIndex, value) {
            if (modIndex === moduleIndex) {
                console.log("🔄 [DIModulePanel] 模块" + moduleIndex + "位" + bitIndex + "变化:" + value)
            }
        }
    }
}
