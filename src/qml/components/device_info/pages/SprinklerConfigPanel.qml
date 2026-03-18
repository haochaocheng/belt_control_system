import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as DeviceInfo

// ✅ 2026-03-09 [洒水控制-右侧面板] 洒水配置面板
// ✅ 2026-03-18 [Phase 7.48.54]: 重构布局-单列排列(启用/名称/通道号)+删除MQTT主题+统一自定义组件
// 旧：GridLayout 4列布局，5个参数(名称/启用/模块类型/通道号/MQTT主题)，使用标准TextField/SpinBox
Rectangle {
    id: root
    color: "transparent"
    clip: true

    // ========== 公开属性 ==========
    property int deviceId: 1
    property int sprinklerIndex: 0  // 0-7（对应洒水1-洒水8）
    property var keyboardManager: null
    property int focusSubArea: 0
    property int focusParamIndex: 0
    property int focusButtonIndex: 0
    property var virtualKeyboard: null

    // ========== 布局常量（参照TensionControlConfigPanel） ==========
    readonly property int lblFs: 21
    readonly property string lblC: "#9E9E9E"
    readonly property int lblW: 160

    // ========== 标题栏 ==========
    Rectangle {
        id: headerBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 40
        color: "#2a3142"
        border.color: "#3d4556"
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: "洒水" + (root.sprinklerIndex + 1) + " 配置"
            font.pixelSize: 18
            font.weight: Font.Bold
            color: "#E0E0E0"
        }
    }

    // ========== 内容区域 ==========
    ColumnLayout {
        anchors.top: headerBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 15
        spacing: 12

        // ========== Row 0: 启用状态 ==========
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            Text { text: "启用状态:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: enabledSwitch.implicitHeight
                Switch { id: enabledSwitch; checked: true; anchors.verticalCenter: parent.verticalCenter }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 0 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 10 }
            }
        }

        // ========== Row 1: 洒水名称 ==========
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            Text { text: "洒水名称:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            DeviceInfo.CustomTextField {
                id: sprinklerNameField
                text: "洒水" + (root.sprinklerIndex + 1)
                Layout.fillWidth: true; Layout.maximumWidth: 300
                placeholderText: "洒水" + (root.sprinklerIndex + 1)
                keyboardManager: root.keyboardManager
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 1 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 10 }
            }
        }

        // ========== Row 2: 通道号 ==========
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            Text { text: "通道号:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            DeviceInfo.CustomSpinBox {
                id: channelSpin
                from: 0; to: 7; value: root.sprinklerIndex
                Layout.fillWidth: true; Layout.maximumWidth: 300
                keyboardManager: root.keyboardManager
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 2 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 10 }
            }
        }

        // ========== 弹性空间 ==========
        Item { Layout.fillHeight: true }
    }

    // ========== 函数 ==========
    function getParamFieldCount() { return 3 }  // 参数索引 0-2

    function loadSprinklerConfig() {
        if (typeof deviceConfigMgr === "undefined") {
            console.log("⚠️ [SprinklerConfigPanel] deviceConfigMgr 未定义")
            return
        }

        var config = deviceConfigMgr.loadSprinklerConfig(root.sprinklerIndex + 1)
        console.log("✅ [SprinklerConfigPanel] 加载洒水" + (root.sprinklerIndex + 1) + "配置:", JSON.stringify(config))

        enabledSwitch.checked = (config.enabled === 1 || config.enabled === true)
        sprinklerNameField.text = config.sprinkler_name || ("洒水" + (root.sprinklerIndex + 1))
        channelSpin.value = (config.channel !== undefined) ? config.channel : root.sprinklerIndex
    }

    function saveSprinklerConfig() {
        if (typeof deviceConfigMgr === "undefined") {
            console.log("⚠️ [SprinklerConfigPanel] deviceConfigMgr 未定义")
            return
        }

        var config = {
            "sprinkler_name": sprinklerNameField.text,
            "enabled": enabledSwitch.checked ? 1 : 0,
            // 旧："module_type": moduleTypeCombo.currentText,  // 2026-03-18 删除模块类型（固定为继电器模块）
            "channel": channelSpin.value
            // 旧："mqtt_topic": mqttTopicField.text  // 2026-03-18 删除MQTT主题（使用全局配置）
        }

        var success = deviceConfigMgr.saveSprinklerConfig(root.sprinklerIndex + 1, config)
        if (success) {
            console.log("✅ [SprinklerConfigPanel] 洒水" + (root.sprinklerIndex + 1) + "配置已保存")
        } else {
            console.log("❌ [SprinklerConfigPanel] 洒水" + (root.sprinklerIndex + 1) + "配置保存失败")
        }
    }

    function triggerParamInput(paramIndex) {
        console.log("✅ [SprinklerConfigPanel] triggerParamInput:", paramIndex)
        switch(paramIndex) {
        case 0: enabledSwitch.toggle(); break
        case 1: sprinklerNameField.forceActiveFocus(); break
        case 2: channelSpin.forceActiveFocus(); break
        }
    }

    function triggerButton(buttonIndex) {
        console.log("✅ [SprinklerConfigPanel] triggerButton:", buttonIndex)
        switch(buttonIndex) {
        case 0: saveSprinklerConfig(); break
        case 1: loadSprinklerConfig(); break
        }
    }

    onSprinklerIndexChanged: {
        loadSprinklerConfig()
    }

    Component.onCompleted: {
        loadSprinklerConfig()
    }
}
