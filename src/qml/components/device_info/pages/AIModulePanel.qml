// AIModulePanel.qml - 科技风格版本
// 模拟量模块显示面板 - 深色科技风格数值显示
// ✅ 2026-02-09 [Phase 7.44.22]: 重新设计为深色科技风格
// 使用方法：将此文件内容复制到 src/qml/components/device_info/pages/AIModulePanel.qml

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "#1a1f2e"
    radius: 8
    border.width: 2
    border.color: "#00d4ff"
    // ✅ 2026-02-09 [Phase 7.44.23]: 移除固定高度，让面板填充整个可用空间
    // height: 300  // 注释掉固定高度

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.width: 1
        border.color: "#00d4ff"
        opacity: 0.3
        z: -1
    }

    property int moduleIndex: 0
    property string moduleName: "模拟量输入"
    property var channelsData: []

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15  // ✅ 2026-02-09 [Phase 7.44.23]: 20 → 15，减少边距
        spacing: 12  // ✅ 2026-02-09 [Phase 7.44.23]: 15 → 12，减少间距

        // 标题行
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40  // ✅ 2026-02-09 [Phase 7.44.23]: 45 → 40，减少标题行高度
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

        // 通道数据显示
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true  // ✅ 填充剩余空间
            columns: 4
            rowSpacing: 10
            columnSpacing: 10

            Repeater {
                model: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 165  // ✅ 2026-02-09 [Phase 7.44.23]: 150 → 165，再次增加10%
                    color: "#0a0f1e"
                    radius: 6
                    border.width: 2
                    border.color: getChannelValid(index) ? "#00d4ff" : "#2a3f5f"

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 4
                        color: "transparent"
                        border.width: 1
                        border.color: "#00d4ff"
                        opacity: 0.1
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 15  // ✅ 2026-02-09 [Phase 7.44.23]: 12 → 15，再次增加内边距
                        spacing: 10  // ✅ 2026-02-09 [Phase 7.44.23]: 8 → 10，再次增加间距

                        // ✅ 2026-02-09 [Phase 7.44.23]: 调整字体大小和粗细
                        Text {
                            text: "通道 " + index
                            font.pixelSize: 18  // 15 → 18，增大通道标题字体
                            font.bold: false  // ✅ 移除粗体，提高可读性
                            font.family: "Microsoft YaHei"
                            color: "#00d4ff"
                            Layout.alignment: Qt.AlignHCenter
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            Text {
                                text: "AD:"
                                font.pixelSize: 16  // 14 → 16，增大标签字体
                                font.family: "Consolas"
                                color: "#5a6f8f"
                                verticalAlignment: Text.AlignVCenter  // ✅ 垂直居中对齐
                            }

                            Text {
                                text: getChannelADValue(index).toString()
                                font.pixelSize: 22  // 18 → 22，增大数值字体
                                font.bold: false  // ✅ 2026-02-09 [Phase 7.44.23]: 移除粗体，提高可读性
                                font.family: "Consolas"
                                color: "#00d4ff"
                                Layout.fillWidth: true
                                verticalAlignment: Text.AlignVCenter  // ✅ 垂直居中对齐
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            Text {
                                text: "电压:"
                                font.pixelSize: 16  // 14 → 16，增大标签字体
                                font.family: "Microsoft YaHei"
                                color: "#5a6f8f"
                                verticalAlignment: Text.AlignVCenter  // ✅ 垂直居中对齐
                            }

                            Text {
                                text: getChannelVoltage(index).toFixed(2) + " V"
                                font.pixelSize: 24  // 20 → 24，增大电压值字体
                                font.bold: false  // ✅ 2026-02-09 [Phase 7.44.23]: 移除粗体，提高可读性
                                font.family: "Consolas"
                                color: getVoltageColor(index)
                                style: Text.Outline
                                styleColor: getVoltageColor(index)
                                Layout.fillWidth: true
                                verticalAlignment: Text.AlignVCenter  // ✅ 垂直居中对齐
                            }
                        }

                        // 进度条
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 10
                            color: "#0a0f1e"
                            radius: 5
                            border.width: 1
                            border.color: "#2a3f5f"

                            Rectangle {
                                width: Math.max(parent.width * (getChannelADValue(index) / 65535.0), 2)
                                height: parent.height
                                radius: 5

                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: getVoltageColor(index) }
                                    GradientStop { position: 1.0; color: Qt.darker(getVoltageColor(index), 1.5) }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: flashRect
                        anchors.fill: parent
                        color: "#00d4ff"
                        opacity: 0
                        radius: 6

                        SequentialAnimation {
                            id: flashAnimation
                            NumberAnimation {
                                target: flashRect
                                property: "opacity"
                                from: 0.3
                                to: 0
                                duration: 300
                            }
                        }
                    }
                }
            }
        }

        // 统计信息
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 45  // ✅ 2026-02-09 [Phase 7.44.23]: 50 → 45，减少统计信息区域高度
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
                anchors.margins: 10
                spacing: 20

                // ✅ 2026-02-09 [Phase 7.44.23]: 调整统计信息字体大小和粗细
                RowLayout {
                    spacing: 5

                    Text {
                        text: "最小值:"
                        font.pixelSize: 18  // 15 → 18，增大标签字体
                        font.family: "Microsoft YaHei"
                        color: "#5a6f8f"
                    }

                    Text {
                        text: getMinValue().toFixed(2) + " V"
                        font.pixelSize: 22  // 17 → 22，增大数值字体
                        font.bold: false  // ✅ 2026-02-09 [Phase 7.44.23]: 移除粗体，提高可读性
                        font.family: "Consolas"
                        color: "#3498DB"
                    }
                }

                Rectangle {
                    width: 2
                    Layout.fillHeight: true
                    color: "#2a3f5f"
                }

                RowLayout {
                    spacing: 5

                    Text {
                        text: "最大值:"
                        font.pixelSize: 18  // 15 → 18，增大标签字体
                        font.family: "Microsoft YaHei"
                        color: "#5a6f8f"
                    }

                    Text {
                        text: getMaxValue().toFixed(2) + " V"
                        font.pixelSize: 22  // 17 → 22，增大数值字体
                        font.bold: false  // ✅ 2026-02-09 [Phase 7.44.23]: 移除粗体，提高可读性
                        font.family: "Consolas"
                        color: "#E74C3C"
                    }
                }

                Rectangle {
                    width: 2
                    Layout.fillHeight: true
                    color: "#2a3f5f"
                }

                RowLayout {
                    spacing: 5

                    Text {
                        text: "平均值:"
                        font.pixelSize: 18  // 15 → 18，增大标签字体
                        font.family: "Microsoft YaHei"
                        color: "#5a6f8f"
                    }

                    Text {
                        text: getAvgValue().toFixed(2) + " V"
                        font.pixelSize: 22  // 17 → 22，增大数值字体
                        font.bold: false  // ✅ 2026-02-09 [Phase 7.44.23]: 移除粗体，提高可读性
                        font.family: "Consolas"
                        color: "#27AE60"
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }
    }

    function getChannelData(index) {
        if (!channelsData || index < 0 || index >= channelsData.length) {
            return { adValue: 0, voltage: 0.0, valid: false }
        }
        return channelsData[index]
    }

    function getChannelADValue(index) {
        var data = getChannelData(index)
        return data.adValue || 0
    }

    function getChannelVoltage(index) {
        var data = getChannelData(index)
        return data.voltage || 0.0
    }

    function getChannelValid(index) {
        var data = getChannelData(index)
        return data.valid || false
    }

    function getVoltageColor(index) {
        var voltage = getChannelVoltage(index)
        if (voltage < 1.0) return "#3498DB"
        if (voltage < 3.0) return "#27AE60"
        if (voltage < 4.5) return "#F39C12"
        return "#E74C3C"
    }

    function getMinValue() {
        var min = 20.0
        for (var i = 0; i < 8; i++) {
            var v = getChannelVoltage(i)
            if (v < min) min = v
        }
        return min
    }

    function getMaxValue() {
        var max = 0.0
        for (var i = 0; i < 8; i++) {
            var v = getChannelVoltage(i)
            if (v > max) max = v
        }
        return max
    }

    function getAvgValue() {
        var sum = 0.0
        for (var i = 0; i < 8; i++) {
            sum += getChannelVoltage(i)
        }
        return sum / 8.0
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
        target: aiDataManager
        function onChannelChanged(modIndex, channelIndex, data) {
            if (modIndex === moduleIndex) {
                console.log("🔄 [AIModulePanel] 模块" + moduleIndex + "通道" + channelIndex +
                           "变化:" + data.voltage + "V")
            }
        }
    }
}
