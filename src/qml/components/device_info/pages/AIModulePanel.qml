// AIModulePanel.qml
// 模拟量模块显示面板 - 数值显示8通道模拟量数据
// 创建日期: 2026-02-09
// ✅ 2026-02-09 [Phase 7.44.7]: 模拟量显示组件

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "#ECF0F1"
    radius: 8
    border.width: 2
    border.color: "#BDC3C7"
    height: 250

    // ========== 公开属性 ==========
    property int moduleIndex: 0
    property string moduleName: "模拟量输入"
    property var channelsData: []  // 8通道数据数组

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

        // 通道数据显示
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 4
            rowSpacing: 10
            columnSpacing: 10

            Repeater {
                model: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    color: "white"
                    radius: 6
                    border.width: 2
                    border.color: getChannelValid(index) ? "#3498DB" : "#BDC3C7"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 5

                        // 通道编号
                        Text {
                            text: "通道 " + index
                            font.pixelSize: 14
                            font.bold: true
                            color: "#7F8C8D"
                            Layout.alignment: Qt.AlignHCenter
                        }

                        // AD值
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            Text {
                                text: "AD:"
                                font.pixelSize: 12
                                color: "#95A5A6"
                            }

                            Text {
                                text: getChannelADValue(index).toString()
                                font.pixelSize: 16
                                font.bold: true
                                font.family: "Courier New"
                                color: "#2C3E50"
                                Layout.fillWidth: true
                            }
                        }

                        // 电压值
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            Text {
                                text: "电压:"
                                font.pixelSize: 12
                                color: "#95A5A6"
                            }

                            Text {
                                text: getChannelVoltage(index).toFixed(2) + " V"
                                font.pixelSize: 18
                                font.bold: true
                                font.family: "Courier New"
                                color: getVoltageColor(index)
                                Layout.fillWidth: true
                            }
                        }

                        // 进度条
                        ProgressBar {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 8
                            from: 0
                            to: 65535
                            value: getChannelADValue(index)

                            background: Rectangle {
                                implicitWidth: 200
                                implicitHeight: 8
                                color: "#E0E0E0"
                                radius: 4
                            }

                            contentItem: Item {
                                implicitWidth: 200
                                implicitHeight: 8

                                Rectangle {
                                    width: parent.width * (parent.parent.value / parent.parent.to)
                                    height: parent.height
                                    radius: 4
                                    color: getVoltageColor(index)
                                }
                            }
                        }
                    }

                    // 数据变化闪烁效果
                    Rectangle {
                        anchors.fill: parent
                        color: "#3498DB"
                        opacity: 0
                        radius: 6

                        id: flashRect

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
        RowLayout {
            Layout.fillWidth: true
            spacing: 20

            Text {
                text: "最小值: " + getMinValue().toFixed(2) + " V"
                font.pixelSize: 14
                color: "#7F8C8D"
            }

            Text {
                text: "最大值: " + getMaxValue().toFixed(2) + " V"
                font.pixelSize: 14
                color: "#7F8C8D"
            }

            Text {
                text: "平均值: " + getAvgValue().toFixed(2) + " V"
                font.pixelSize: 14
                color: "#7F8C8D"
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "变化阈值: " + (aiDataManager ? aiDataManager.changeThreshold : 10)
                font.pixelSize: 14
                color: "#7F8C8D"
            }
        }
    }

    // ========== 辅助函数 ==========
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
        if (voltage < 5.0) return "#3498DB"      // 蓝色：低电压
        if (voltage < 10.0) return "#27AE60"     // 绿色：中电压
        if (voltage < 15.0) return "#F39C12"     // 橙色：高电压
        return "#E74C3C"                         // 红色：很高电压
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

    // ========== 数据变化监听 ==========
    Connections {
        target: aiDataManager
        function onChannelChanged(modIndex, channelIndex, data) {
            if (modIndex === moduleIndex) {
                console.log("🔄 [AIModulePanel] 模块" + moduleIndex + "通道" + channelIndex +
                           "变化:" + data.voltage + "V")

                // 触发闪烁效果
                // flashAnimation.start()  // 暂时注释，避免过于频繁
            }
        }
    }
}
