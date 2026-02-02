import QtQuick

// ✅ 2026-01-27 [FIX 100.300.54]: 添加选中状态支持
// 使用 states 切换图片：IN_Data.png <-> IN_Data_OK.png
// ✅ 2026-02-02 [FIX 100.300.112.8.19.3]: 重新设计组件布局
// - 移除重复的装饰图片，改为显示实际参数值
// - 顶部：设备名称（大字体）
// - 中间：4个关键参数（参数名 + 值，两列布局）
// - 底部：状态指示器（运行状态、通讯状态）
// - 整体使用背景图片（IN_Data.png / IN_Data_OK.png）
Image {
    id: iN_Data
    source: "images/IN_Data.png"
    fillMode: Image.PreserveAspectFit

    // ========== 公开属性 ==========
    property bool selected: false

    // 设备信息属性
    property string deviceName: "设备 01"
    property string deviceStatus: "运行中"
    property string commStatus: "在线"
    property string operationMode: "自动"

    // 参数属性（示例）
    property string param1Name: "速度"
    property string param1Value: "1200 m/min"
    property string param2Name: "温度"
    property string param2Value: "45 °C"
    property string param3Name: "压力"
    property string param3Value: "2.5 MPa"
    property string param4Name: "电流"
    property string param4Value: "32 A"

    // ========== 主布局 ==========
    Column {
        anchors.fill: parent
        anchors.topMargin: 15
        anchors.bottomMargin: 15
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing: 8

        // ========== 顶部：设备名称 ==========
        Text {
            id: deviceNameText
            width: parent.width
            height: 50
            text: iN_Data.deviceName
            font.pixelSize: 36
            font.bold: true
            color: "#FFFFFF"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        // ========== 分隔线 ==========
        Rectangle {
            width: parent.width
            height: 2
            color: "#4A90E2"
            opacity: 0.5
        }

        // ========== 中间：参数网格（2列2行）==========
        Grid {
            width: parent.width
            height: 140
            columns: 2
            rowSpacing: 12
            columnSpacing: 10

            // 参数1
            Column {
                width: (parent.width - parent.columnSpacing) / 2
                spacing: 4

                Text {
                    text: iN_Data.param1Name
                    font.pixelSize: 20
                    color: "#9E9E9E"
                }
                Text {
                    text: iN_Data.param1Value
                    font.pixelSize: 28
                    font.bold: true
                    color: "#FFFFFF"
                }
            }

            // 参数2
            Column {
                width: (parent.width - parent.columnSpacing) / 2
                spacing: 4

                Text {
                    text: iN_Data.param2Name
                    font.pixelSize: 20
                    color: "#9E9E9E"
                }
                Text {
                    text: iN_Data.param2Value
                    font.pixelSize: 28
                    font.bold: true
                    color: "#FFFFFF"
                }
            }

            // 参数3
            Column {
                width: (parent.width - parent.columnSpacing) / 2
                spacing: 4

                Text {
                    text: iN_Data.param3Name
                    font.pixelSize: 20
                    color: "#9E9E9E"
                }
                Text {
                    text: iN_Data.param3Value
                    font.pixelSize: 28
                    font.bold: true
                    color: "#FFFFFF"
                }
            }

            // 参数4
            Column {
                width: (parent.width - parent.columnSpacing) / 2
                spacing: 4

                Text {
                    text: iN_Data.param4Name
                    font.pixelSize: 20
                    color: "#9E9E9E"
                }
                Text {
                    text: iN_Data.param4Value
                    font.pixelSize: 28
                    font.bold: true
                    color: "#FFFFFF"
                }
            }
        }

        // ========== 分隔线 ==========
        Rectangle {
            width: parent.width
            height: 2
            color: "#4A90E2"
            opacity: 0.5
        }

        // ========== 底部：状态指示器 ==========
        Row {
            width: parent.width
            height: 50
            spacing: 20

            // 运行状态
            Row {
                width: (parent.width - parent.spacing) / 2
                spacing: 8

                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    color: iN_Data.deviceStatus === "运行中" ? "#4CAF50" : "#F44336"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: iN_Data.deviceStatus
                    font.pixelSize: 22
                    color: "#FFFFFF"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // 通讯状态
            Row {
                width: (parent.width - parent.spacing) / 2
                spacing: 8

                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    color: iN_Data.commStatus === "在线" ? "#4CAF50" : "#F44336"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: iN_Data.commStatus
                    font.pixelSize: 22
                    color: "#FFFFFF"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    // ✅ 使用 states 切换背景图片
    states: [
        State {
            name: "normal"
            when: !iN_Data.selected
            PropertyChanges {
                target: iN_Data
                source: "images/IN_Data.png"
            }
        },
        State {
            name: "selected"
            when: iN_Data.selected
            PropertyChanges {
                target: iN_Data
                source: "images/IN_Data_OK.png"
            }
        }
    ]
}
