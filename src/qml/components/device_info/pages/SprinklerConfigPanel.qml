import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as DeviceInfo

// ✅ 2026-03-09 [洒水控制-右侧面板] 洒水配置面板
// 基本配置：洒水名称、启用状态、模块类型、通道号、MQTT主题
// 设计风格与张紧控制配置面板一致
Rectangle {
    id: root
    implicitWidth: 1400
    implicitHeight: 600
    color: "transparent"

    // ========== 公开属性 ==========
    property int deviceId: 1
    property int sprinklerIndex: 0  // 0-7（对应洒水1-洒水8）
    property var keyboardManager: null
    property int focusSubArea: 0
    property int focusParamIndex: 0
    property int focusButtonIndex: 0
    property var virtualKeyboard: null

    // 参数数量
    readonly property int paramCount: 10  // 5行×2列

    // ========== 标题栏 ==========
    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 50
        color: "transparent"
        border.color: "transparent"
        border.width: 0

        Image {
            id: headerBackground
            anchors.fill: parent
            source: "../images/059.png"
            fillMode: Image.Stretch
            z: -1
        }

        Text {
            anchors.centerIn: parent
            text: "洒水" + (root.sprinklerIndex + 1) + " 配置"
            font.pixelSize: 16
            font.weight: Font.Bold
            color: "#E0E0E0"
        }
    }

    // ========== 内容区域 ==========
    Rectangle {
        id: contentArea
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: buttonBar.top
        color: "transparent"

        ScrollView {
            id: paramScrollView
            anchors.fill: parent
            anchors.margins: 15
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            contentWidth: Math.max(width, 1200)

            ColumnLayout {
                width: parent.width
                implicitWidth: 1200
                implicitHeight: childrenRect.height
                spacing: 15

                // ========== 参数编辑区（GridLayout 4列布局）==========
                GridLayout {
                    id: paramGrid
                    Layout.fillWidth: true
                    columns: 4  // Label-Value-Label-Value
                    columnSpacing: 20
                    rowSpacing: 15

                    // ===== Row 0: 洒水名称 + 启用状态 =====

                    // 参数0: 洒水名称（左列）
                    Text {
                        text: "洒水名称:"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 300
                        implicitHeight: sprinklerNameField.implicitHeight

                        // 焦点边框
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: (root.focusSubArea === 1 && root.focusParamIndex === 0) ? "#2196F3" : "transparent"
                            border.width: 2
                            radius: 4
                            z: 10
                        }

                        TextField {
                            id: sprinklerNameField
                            anchors.fill: parent
                            text: "洒水" + (root.sprinklerIndex + 1)
                            font.pixelSize: 18
                            color: "#E0E0E0"
                            placeholderText: "输入洒水名称"
                            background: Rectangle {
                                color: "#2A2A2A"
                                border.color: "#555555"
                                border.width: 1
                                radius: 4
                            }
                        }
                    }

                    // 参数1: 启用状态（右列）
                    Text {
                        text: "启用状态:"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 300
                        implicitHeight: enabledSwitch.implicitHeight

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: (root.focusSubArea === 1 && root.focusParamIndex === 1) ? "#2196F3" : "transparent"
                            border.width: 2
                            radius: 4
                            z: 10
                        }

                        Switch {
                            id: enabledSwitch
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            checked: true

                            indicator: Rectangle {
                                implicitWidth: 48
                                implicitHeight: 26
                                x: enabledSwitch.leftPadding
                                y: parent.height / 2 - height / 2
                                radius: 13
                                color: enabledSwitch.checked ? "#27ae60" : "#7f8c8d"

                                Rectangle {
                                    x: enabledSwitch.checked ? parent.width - width - 2 : 2
                                    y: 2
                                    width: 22
                                    height: 22
                                    radius: 11
                                    color: "white"

                                    Behavior on x {
                                        NumberAnimation { duration: 150 }
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.left: enabledSwitch.right
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: enabledSwitch.checked ? "已启用" : "已禁用"
                            font.pixelSize: 16
                            color: enabledSwitch.checked ? "#27ae60" : "#e74c3c"
                        }
                    }

                    // ===== Row 1: 模块类型 + 通道号 =====

                    // 参数2: 模块类型（左列）
                    Text {
                        text: "模块类型:"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 300
                        implicitHeight: moduleTypeCombo.implicitHeight

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: (root.focusSubArea === 1 && root.focusParamIndex === 2) ? "#2196F3" : "transparent"
                            border.width: 2
                            radius: 4
                            z: 10
                        }

                        ComboBox {
                            id: moduleTypeCombo
                            anchors.fill: parent
                            model: ["继电器模块"]
                            currentIndex: 0
                            font.pixelSize: 18
                        }
                    }

                    // 参数3: 通道号（右列）
                    Text {
                        text: "通道号:"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 300
                        implicitHeight: channelSpin.implicitHeight

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: (root.focusSubArea === 1 && root.focusParamIndex === 3) ? "#2196F3" : "transparent"
                            border.width: 2
                            radius: 4
                            z: 10
                        }

                        SpinBox {
                            id: channelSpin
                            anchors.fill: parent
                            from: 0
                            to: 7
                            value: root.sprinklerIndex
                            font.pixelSize: 18
                        }
                    }

                    // ===== Row 2: MQTT主题（跨整行）=====

                    // 参数4: MQTT主题标签
                    Text {
                        text: "MQTT主题:"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.columnSpan: 3
                        implicitHeight: mqttTopicField.implicitHeight

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: (root.focusSubArea === 1 && root.focusParamIndex === 4) ? "#2196F3" : "transparent"
                            border.width: 2
                            radius: 4
                            z: 10
                        }

                        TextField {
                            id: mqttTopicField
                            anchors.fill: parent
                            text: "belt_control/relay/module1/control"
                            font.pixelSize: 18
                            color: "#E0E0E0"
                            placeholderText: "MQTT控制主题"
                            background: Rectangle {
                                color: "#2A2A2A"
                                border.color: "#555555"
                                border.width: 1
                                radius: 4
                            }
                        }
                    }
                }
            }
        }
    }

    // ========== 底部按钮栏 ==========
    Rectangle {
        id: buttonBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 60
        color: "transparent"

        RowLayout {
            anchors.centerIn: parent
            spacing: 30

            // 保存按钮
            Button {
                id: saveButton
                text: "保存"
                Layout.preferredWidth: 120
                Layout.preferredHeight: 40

                // 焦点边框
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusSubArea === 2 && root.focusButtonIndex === 0) ? "#FFFFFF" : "transparent"
                    border.width: 3
                    radius: 6
                    z: 10
                }

                background: Rectangle {
                    color: saveButton.pressed ? "#1e8449" : "#27ae60"
                    radius: 4
                }

                contentItem: Text {
                    text: saveButton.text
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: saveSprinklerConfig()
            }

            // 重置按钮
            Button {
                id: resetButton
                text: "重置"
                Layout.preferredWidth: 120
                Layout.preferredHeight: 40

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusSubArea === 2 && root.focusButtonIndex === 1) ? "#FFFFFF" : "transparent"
                    border.width: 3
                    radius: 6
                    z: 10
                }

                background: Rectangle {
                    color: resetButton.pressed ? "#5d6d7e" : "#7f8c8d"
                    radius: 4
                }

                contentItem: Text {
                    text: resetButton.text
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: loadSprinklerConfig()
            }
        }
    }

    // ========== 数据加载 ==========
    function loadSprinklerConfig() {
        if (typeof deviceConfigMgr === "undefined") {
            console.log("⚠️ [SprinklerConfigPanel] deviceConfigMgr 未定义")
            return
        }

        var config = deviceConfigMgr.loadSprinklerConfig(root.sprinklerIndex + 1)  // sprinklerIndex 1-8
        console.log("✅ [SprinklerConfigPanel] 加载洒水" + (root.sprinklerIndex + 1) + "配置:", JSON.stringify(config))

        sprinklerNameField.text = config.sprinkler_name || ("洒水" + (root.sprinklerIndex + 1))
        enabledSwitch.checked = (config.enabled === 1 || config.enabled === true)
        channelSpin.value = (config.channel !== undefined) ? config.channel : root.sprinklerIndex
        mqttTopicField.text = config.mqtt_topic || "belt_control/relay/module1/control"
    }

    // ========== 数据保存 ==========
    function saveSprinklerConfig() {
        if (typeof deviceConfigMgr === "undefined") {
            console.log("⚠️ [SprinklerConfigPanel] deviceConfigMgr 未定义")
            return
        }

        var config = {
            "sprinkler_name": sprinklerNameField.text,
            "enabled": enabledSwitch.checked ? 1 : 0,
            "module_type": moduleTypeCombo.currentText,
            "channel": channelSpin.value,
            "mqtt_topic": mqttTopicField.text
        }

        var success = deviceConfigMgr.saveSprinklerConfig(root.sprinklerIndex + 1, config)
        if (success) {
            console.log("✅ [SprinklerConfigPanel] 洒水" + (root.sprinklerIndex + 1) + "配置已保存")
        } else {
            console.log("❌ [SprinklerConfigPanel] 洒水" + (root.sprinklerIndex + 1) + "配置保存失败")
        }
    }

    // ========== 触发参数输入（供键盘导航回车使用）==========
    function triggerParamInput(paramIndex) {
        console.log("✅ [SprinklerConfigPanel] triggerParamInput:", paramIndex)
        switch(paramIndex) {
        case 0: sprinklerNameField.forceActiveFocus(); break
        case 1: enabledSwitch.toggle(); break
        case 2: moduleTypeCombo.popup.open(); break
        case 3: channelSpin.forceActiveFocus(); break
        case 4: mqttTopicField.forceActiveFocus(); break
        }
    }

    // ========== 触发按钮（供键盘导航回车使用）==========
    function triggerButton(buttonIndex) {
        console.log("✅ [SprinklerConfigPanel] triggerButton:", buttonIndex)
        switch(buttonIndex) {
        case 0: saveSprinklerConfig(); break
        case 1: loadSprinklerConfig(); break
        }
    }

    // ========== 洒水索引变化时重新加载 ==========
    onSprinklerIndexChanged: {
        loadSprinklerConfig()
    }

    Component.onCompleted: {
        loadSprinklerConfig()
    }
}
