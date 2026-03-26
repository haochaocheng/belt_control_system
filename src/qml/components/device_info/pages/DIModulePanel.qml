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

    // ✅ 2026-03-26 [Phase 7.48.88.27]: 保护锁存位数组（三态指示）
    // 保护触发时设置，保护物理恢复后保持，仅F键复位时清除
    property var latchedBitsData: [false,false,false,false,false,false,false,false]

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

                    // ✅ 2026-03-26 [Phase 7.48.88.27]: 三态保护指示
                    // bitOn: DI位=1（保护触发中）→ 红色
                    // bitLatched: DI位=0但曾触发未确认 → 琥珀色闪烁
                    // 正常: 绿色
                    property bool bitOn: getBitValue(index)
                    property bool bitLatched: !bitOn && getLatchedValue(index)
                    property color ledColor: bitOn ? "#FF3333"   // 红色（保护触发中）
                                           : bitLatched ? "#FF8C00"  // 琥珀色（待确认）
                                           : "#00ff00"               // 绿色（正常）
                    property string statusText: bitOn ? "报警"
                                              : bitLatched ? "待确认"
                                              : "正常"

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
                        // ✅ 2026-03-26 [Phase 7.48.88.27]: 边框颜色跟随三态
                        border.color: (bitOn || bitLatched) ? ledColor : "#2a3f5f"

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width + 8
                            height: parent.height + 8
                            radius: (parent.width + 8) / 2
                            color: "transparent"
                            border.width: 2
                            border.color: (bitOn || bitLatched) ? ledColor : "transparent"
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
                                    color: ledColor
                                }
                                GradientStop {
                                    position: 1.0
                                    // ✅ 2026-03-26 [Phase 7.48.88.27]: 深色版本跟随三态
                                    color: bitOn ? "#AA0000"
                                         : bitLatched ? "#B36200"
                                         : (getBitValue(index) ? "#00aa00" : "#1a2f4f")
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
                            opacity: (bitOn || bitLatched) ? 0.8 : 0.1
                        }

                        // ✅ 2026-03-26 [Phase 7.48.88.27]: 触发中快速闪烁
                        SequentialAnimation on opacity {
                            running: bitOn
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.5; duration: 400 }
                            NumberAnimation { from: 0.5; to: 1.0; duration: 400 }
                        }

                        // ✅ 2026-03-26 [Phase 7.48.88.27]: 待确认慢速闪烁
                        SequentialAnimation on opacity {
                            running: bitLatched && !bitOn
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.4; duration: 1000 }
                            NumberAnimation { from: 0.4; to: 1.0; duration: 1000 }
                        }
                    }

                    // ✅ 2026-03-26 [Phase 7.48.88.27]: 状态文字显示三态
                    Rectangle {
                        Layout.preferredWidth: 70  // ✅ 2026-02-09 [Phase 7.44.23]: 60 → 70，增加状态标签宽度
                        Layout.preferredHeight: 26  // ✅ 2026-02-09 [Phase 7.44.23]: 22 → 26，增加状态标签高度
                        Layout.alignment: Qt.AlignHCenter
                        color: "#0a0f1e"
                        radius: 3
                        border.width: 1
                        border.color: ledColor

                        Row {
                            anchors.centerIn: parent
                            spacing: 4

                            // 状态方块指示器
                            Rectangle {
                                width: 10
                                height: 10
                                radius: 2
                                color: ledColor
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: statusText
                                font.pixelSize: 12
                                font.family: "Microsoft YaHei"
                                color: ledColor
                                anchors.verticalCenter: parent.verticalCenter
                            }
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

    // ✅ 2026-03-26 [Phase 7.48.88.27]: 获取锁存位值（三态指示用）
    function getLatchedValue(index) {
        if (!latchedBitsData || index < 0 || index >= latchedBitsData.length) {
            return false
        }
        return latchedBitsData[index] === true
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
        // ✅ 2026-03-03 [Phase 7.47.78]: QDS 兼容 - QDS mock 无 onBitChanged 信号
        ignoreUnknownSignals: true
        function onBitChanged(modIndex, bitIndex, value) {
            if (modIndex === moduleIndex) {
                console.log("🔄 [DIModulePanel] 模块" + moduleIndex + "位" + bitIndex + "变化:" + value)
                // ✅ 2026-03-26 [Phase 7.48.88.27]: 保护触发时设置锁存位
                if (value && bitIndex >= 0 && bitIndex < 8) {
                    var newLatched = latchedBitsData.slice()
                    newLatched[bitIndex] = true
                    latchedBitsData = newLatched
                }
                // 注意：value=false时不清除锁存位，锁存位仅由F键复位清除
            }
        }
    }

    // ✅ 2026-03-26 [Phase 7.48.88.27]: F键复位清除锁存状态
    Connections {
        target: typeof protectionLogicController !== "undefined" ? protectionLogicController : null
        enabled: target !== null
        ignoreUnknownSignals: true
        function onAllProtectionsReset() {
            console.log("🔄 [DIModulePanel] F键复位：清除模块" + moduleIndex + "锁存状态")
            latchedBitsData = [false,false,false,false,false,false,false,false]
        }
    }
}
