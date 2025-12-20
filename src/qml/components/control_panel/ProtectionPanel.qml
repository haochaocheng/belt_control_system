import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// Protection Panel - Shows protection sensors status
// Click to configure parameters
Rectangle {
    id: root
    width: 280
    height: 400
    color: "#dd1a2332"
    radius: 10
    border.color: "#00d4ff"
    border.width: 2

    // Signals
    signal protectionClicked(string protectionName, var sourceItem)
    signal addProtectionClicked(var sourceItem)

    // 开关量保护模型
    ListModel {
        id: digitalProtectionModel
        ListElement { name: "急停"; active: false }
        ListElement { name: "跑偏"; active: false }
        ListElement { name: "撕裂"; active: false }
        ListElement { name: "烟雾"; active: false }
        ListElement { name: "温度"; active: false }
        ListElement { name: "护网"; active: false }
        ListElement { name: "堆煤"; active: false }
        ListElement { name: "主机急停"; active: false }
    }

    // 模拟量保护模型 - 重要的保护项放前面
    ListModel {
        id: analogProtectionModel
        // 主要保护项（默认可见）
        ListElement { name: "速度"; value: 0.0; unit: "m/s"; active: false }
        ListElement { name: "张力"; value: 0.0; unit: "T"; active: false }
        ListElement { name: "红外温度一"; value: 0.0; unit: "℃"; active: false }
        ListElement { name: "红外温度二"; value: 0.0; unit: "℃"; active: false }
        ListElement { name: "电流一"; value: 0.0; unit: "A"; active: false }
        ListElement { name: "电流二"; value: 0.0; unit: "A"; active: false }
        ListElement { name: "电压"; value: 0.0; unit: "V"; active: false }

        // 次要保护项（需要滚动查看）
        ListElement { name: "1号电机温度"; value: 0.0; unit: "℃"; active: false }
        ListElement { name: "2号电机温度"; value: 0.0; unit: "℃"; active: false }
        ListElement { name: "1号电机X振动"; value: 0.0; unit: "mm/s"; active: false }
        ListElement { name: "1号电机Y振动"; value: 0.0; unit: "mm/s"; active: false }
        ListElement { name: "2号电机X振动"; value: 0.0; unit: "mm/s"; active: false }
        ListElement { name: "2号电机Y振动"; value: 0.0; unit: "mm/s"; active: false }
        ListElement { name: "1号电机第一项绕组"; value: 0.0; unit: "℃"; active: false }
        ListElement { name: "1号电机第二项绕组"; value: 0.0; unit: "℃"; active: false }
        ListElement { name: "1号电机第三项绕组"; value: 0.0; unit: "℃"; active: false }
        ListElement { name: "2号电机第一项绕组"; value: 0.0; unit: "℃"; active: false }
        ListElement { name: "2号电机第二项绕组"; value: 0.0; unit: "℃"; active: false }
        ListElement { name: "2号电机第三项绕组"; value: 0.0; unit: "℃"; active: false }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // Title
        Text {
            text: "保护信息"
            font.pixelSize: 16
            font.bold: true
            color: "#00d4ff"
            Layout.alignment: Qt.AlignHCenter
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#00d4ff"
            opacity: 0.5
        }

        // 两列布局：左边开关量，右边模拟量
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8
            Layout.alignment: Qt.AlignTop  // 确保顶部对齐

            // 左列：开关量保护 - 单列显示8个
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: parent.width * 0.38  // 减少宽度
                Layout.alignment: Qt.AlignTop  // 顶部对齐
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        text: "开关量"
                        font.pixelSize: 13
                        font.bold: true
                        color: "#00ff88"
                        Layout.fillWidth: true
                    }

                    // + 按钮
                    Rectangle {
                        width: 22
                        height: 22
                        radius: 3
                        color: "#34495e"
                        border.color: "#00ff88"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            font.pixelSize: 16
                            font.bold: true
                            color: "#00ff88"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.addProtectionClicked(parent)
                            hoverEnabled: true
                            onEntered: parent.scale = 1.1
                            onExited: parent.scale = 1.0
                        }

                        Behavior on scale {
                            NumberAnimation { duration: 150 }
                        }
                    }
                }

                // 开关量保护单列显示
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Repeater {
                        model: digitalProtectionModel

                        Rectangle {
                            id: digitalItem
                            Layout.fillWidth: true
                            height: 42
                            radius: 5
                            color: model.active ? "#ff4757" : "#2c3e50"
                            border.color: model.active ? "#ff6b7a" : "#00d4ff"
                            border.width: 1.5

                            // Blinking animation when active
                            SequentialAnimation on opacity {
                                running: model.active
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.5; duration: 500 }
                                NumberAnimation { to: 1.0; duration: 500 }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: model.name
                                font.pixelSize: 12
                                font.bold: true
                                color: model.active ? "white" : "#00d4ff"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.protectionClicked(model.name, digitalItem)

                                hoverEnabled: true
                                onEntered: parent.scale = 1.05
                                onExited: parent.scale = 1.0
                            }

                            Behavior on scale {
                                NumberAnimation { duration: 150 }
                            }
                        }
                    }
                }
            }

            // 中间分隔线
            Rectangle {
                Layout.fillHeight: true
                width: 1
                color: "#00d4ff"
                opacity: 0.3
            }

            // 右列：模拟量保护 - 显示前8个，其他滚动查看
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: parent.width * 0.58  // 增加宽度
                Layout.alignment: Qt.AlignTop  // 顶部对齐
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        text: "模拟量"
                        font.pixelSize: 13
                        font.bold: true
                        color: "#00ff88"
                        Layout.fillWidth: true
                    }

                    // + 按钮
                    Rectangle {
                        width: 22
                        height: 22
                        radius: 3
                        color: "#34495e"
                        border.color: "#00ff88"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            font.pixelSize: 16
                            font.bold: true
                            color: "#00ff88"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.addProtectionClicked(parent)
                            hoverEnabled: true
                            onEntered: parent.scale = 1.1
                            onExited: parent.scale = 1.0
                        }

                        Behavior on scale {
                            NumberAnimation { duration: 150 }
                        }
                    }
                }

                // 模拟量保护列表 - 带滚动条
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    contentWidth: availableWidth

                    ColumnLayout {
                        width: parent.width
                        spacing: 5

                        Repeater {
                            model: analogProtectionModel

                            Rectangle {
                                id: analogItem
                                Layout.fillWidth: true
                                height: 42
                                radius: 4
                                color: model.active ? "#ff4757" : "#2c3e50"
                                border.color: model.active ? "#ff6b7a" : "#00d4ff"
                                border.width: model.active ? 1.5 : 1

                                // Blinking animation when active
                                SequentialAnimation on opacity {
                                    running: model.active
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.5; duration: 500 }
                                    NumberAnimation { to: 1.0; duration: 500 }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 6

                                    Text {
                                        text: model.name + ":"
                                        font.pixelSize: 12
                                        color: model.active ? "white" : "#00d4ff"
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: model.value.toFixed(1) + model.unit
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: model.active ? "white" : "#00ff88"
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.protectionClicked(model.name, analogItem)

                                    hoverEnabled: true
                                    onEntered: parent.scale = 1.03
                                    onExited: parent.scale = 1.0
                                }

                                Behavior on scale {
                                    NumberAnimation { duration: 150 }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Public functions
    function setDigitalProtectionActive(protectionName, active) {
        for (var i = 0; i < digitalProtectionModel.count; i++) {
            if (digitalProtectionModel.get(i).name === protectionName) {
                digitalProtectionModel.setProperty(i, "active", active)
                break
            }
        }
    }

    function setAnalogProtectionValue(protectionName, value) {
        for (var i = 0; i < analogProtectionModel.count; i++) {
            if (analogProtectionModel.get(i).name === protectionName) {
                analogProtectionModel.setProperty(i, "value", value)
                break
            }
        }
    }

    function setAnalogProtectionActive(protectionName, active) {
        for (var i = 0; i < analogProtectionModel.count; i++) {
            if (analogProtectionModel.get(i).name === protectionName) {
                analogProtectionModel.setProperty(i, "active", active)
                break
            }
        }
    }

    function getProtectionCount() {
        return digitalProtectionModel.count + analogProtectionModel.count
    }

    function getProtectionAt(index) {
        if (index < digitalProtectionModel.count) {
            var item = digitalProtectionModel.get(index)
            return {
                name: item.name,
                active: item.active,
                type: "digital"
            }
        } else {
            var analogIndex = index - digitalProtectionModel.count
            if (analogIndex >= 0 && analogIndex < analogProtectionModel.count) {
                var item = analogProtectionModel.get(analogIndex)
                return {
                    name: item.name,
                    value: item.value,
                    unit: item.unit,
                    type: "analog"
                }
            }
        }
        return null
    }
}
