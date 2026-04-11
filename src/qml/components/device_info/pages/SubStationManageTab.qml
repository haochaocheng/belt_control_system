// SubStationManageTab.qml
// 分站管理Tab - 8个预设槽位，每个可配置不同协议
// 创建日期: 2026-04-11
// ✅ 2026-04-11 [Phase 7.48.88.110]: 集控管理——分站管理

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../" as DeviceInfo

Rectangle {
    id: root
    color: "transparent"

    // ========== 公开属性 ==========
    property int focusParamIndex: -1
    property int focusSubArea: 0
    property var virtualKeyboard: null
    property int currentSlotIndex: 0  // 当前选中的槽位 (0-7)

    // ========== 参数数据（动态，根据协议变化）==========
    // 通用参数: 0=启用, 1=协议类型
    // MQTT: 2=目标设备ID, 3=Topic前缀
    // S7:   2=目标IP, 3=端口, 4=机架, 5=插槽, 6=连接类型
    // Modbus: 2=目标IP, 3=端口, 4=从站地址, 5=起始寄存器, 6=寄存器数量

    // ========== 函数 ==========
    function getParamFieldCount() {
        var protocol = getCurrentSlotProtocol()
        switch(protocol) {
        case "mqtt": return 4
        case "s7": return 7
        case "modbus": return 7
        default: return 2  // 只有启用和协议类型
        }
    }

    function getCurrentSlotProtocol() {
        if (typeof centralControlManager === "undefined") return ""
        return centralControlManager.getSlotProtocol(currentSlotIndex)
    }

    function triggerParamInput(index) {
        console.log("✅ [SubStationManageTab] triggerParamInput:", index, "slot:", currentSlotIndex)
        var protocol = getCurrentSlotProtocol()

        switch(index) {
        case 0:  // 启用/禁用 (ComboBox切换)
            var isEnabled = typeof centralControlManager !== "undefined"
                            ? centralControlManager.isSlotEnabled(currentSlotIndex) : false
            if (typeof centralControlManager !== "undefined") {
                centralControlManager.setSlotEnabled(currentSlotIndex, !isEnabled)
            }
            break
        case 1:  // 协议类型 (ComboBox切换)
            var protocols = ["mqtt", "s7", "modbus"]
            var currentProto = getCurrentSlotProtocol()
            var idx = protocols.indexOf(currentProto)
            idx = (idx + 1) % protocols.length
            if (typeof centralControlManager !== "undefined") {
                centralControlManager.setSlotProtocol(currentSlotIndex, protocols[idx])
            }
            break
        default:
            // 协议特定参数
            triggerProtocolParam(index, protocol)
            break
        }
    }

    function triggerProtocolParam(index, protocol) {
        if (protocol === "mqtt") {
            switch(index) {
            case 2:  // 目标设备ID
                if (root.virtualKeyboard && mqttTargetIdField.visible) {
                    root.virtualKeyboard.targetInput = mqttTargetIdField
                    root.virtualKeyboard.show()
                }
                break
            case 3:  // Topic前缀 (只读, 自动生成)
                break
            }
        } else if (protocol === "s7") {
            switch(index) {
            case 2:  // 目标IP
                if (root.virtualKeyboard && s7TargetIPField.visible) {
                    root.virtualKeyboard.targetInput = s7TargetIPField
                    root.virtualKeyboard.show()
                }
                break
            case 3:  // 端口
                if (root.virtualKeyboard && s7PortField.visible) {
                    root.virtualKeyboard.targetInput = s7PortField
                    root.virtualKeyboard.show()
                }
                break
            case 4:  // 机架
                if (root.virtualKeyboard && s7RackField.visible) {
                    root.virtualKeyboard.targetInput = s7RackField
                    root.virtualKeyboard.show()
                }
                break
            case 5:  // 插槽
                if (root.virtualKeyboard && s7SlotField.visible) {
                    root.virtualKeyboard.targetInput = s7SlotField
                    root.virtualKeyboard.show()
                }
                break
            case 6:  // 连接类型 (ComboBox切换)
                s7ConnTypeField.currentIndex = (s7ConnTypeField.currentIndex + 1) % s7ConnTypeField.model.length
                if (typeof centralControlManager !== "undefined") {
                    centralControlManager.setSlotParam(currentSlotIndex, "connectionType",
                        s7ConnTypeField.model[s7ConnTypeField.currentIndex])
                }
                break
            }
        } else if (protocol === "modbus") {
            switch(index) {
            case 2:  // 目标IP
                if (root.virtualKeyboard && modbusTargetIPField.visible) {
                    root.virtualKeyboard.targetInput = modbusTargetIPField
                    root.virtualKeyboard.show()
                }
                break
            case 3:  // 端口
                if (root.virtualKeyboard && modbusPortField.visible) {
                    root.virtualKeyboard.targetInput = modbusPortField
                    root.virtualKeyboard.show()
                }
                break
            case 4:  // 从站地址
                if (root.virtualKeyboard && modbusSlaveAddrField.visible) {
                    root.virtualKeyboard.targetInput = modbusSlaveAddrField
                    root.virtualKeyboard.show()
                }
                break
            case 5:  // 起始寄存器
                if (root.virtualKeyboard && modbusStartRegField.visible) {
                    root.virtualKeyboard.targetInput = modbusStartRegField
                    root.virtualKeyboard.show()
                }
                break
            case 6:  // 寄存器数量
                if (root.virtualKeyboard && modbusRegCountField.visible) {
                    root.virtualKeyboard.targetInput = modbusRegCountField
                    root.virtualKeyboard.show()
                }
                break
            }
        }
    }

    // ========== 布局 ==========
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // 左侧: 槽位列表
        Rectangle {
            Layout.preferredWidth: 160
            Layout.fillHeight: true
            color: "#1a2030"
            border.color: "#3d4556"
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 5
                spacing: 2

                Text {
                    text: "分站列表"
                    color: "#4FC3F7"
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 5
                }

                Repeater {
                    model: 8

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        color: root.currentSlotIndex === index ? "#2d3a5c" : "transparent"
                        border.color: root.currentSlotIndex === index ? "#4FC3F7" : "#3d4556"
                        border.width: root.currentSlotIndex === index ? 2 : 1
                        radius: 4

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 5
                            spacing: 5

                            // 状态指示灯
                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: {
                                    if (typeof centralControlManager === "undefined") return "#555"
                                    if (centralControlManager.isSlotConnected(index)) return "#4CAF50"
                                    if (centralControlManager.isSlotEnabled(index)) return "#FFA726"
                                    return "#555"
                                }
                            }

                            Text {
                                text: "分站 " + (index + 1)
                                color: "#B0BEC5"
                                font.pixelSize: 12
                                Layout.fillWidth: true
                            }

                            Text {
                                text: {
                                    if (typeof centralControlManager === "undefined") return ""
                                    var proto = centralControlManager.getSlotProtocol(index)
                                    if (!proto) return ""
                                    return proto.toUpperCase()
                                }
                                color: "#78909C"
                                font.pixelSize: 10
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.currentSlotIndex = index
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        // 右侧: 槽位配置面板
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"

            ScrollView {
                anchors.fill: parent
                anchors.margins: 10
                clip: true

                GridLayout {
                    width: parent.width - 20
                    columns: 4
                    columnSpacing: 10
                    rowSpacing: 8

                    // ===== 参数0: 启用/禁用 =====
                    Text {
                        text: "启用"
                        color: "#B0BEC5"
                        font.pixelSize: 13
                        Layout.preferredWidth: 100
                    }
                    DeviceInfo.CustomComboBox {
                        id: enabledField
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 36
                        model: ["关闭", "打开"]
                        currentIndex: (typeof centralControlManager !== "undefined" &&
                                       centralControlManager.isSlotEnabled(root.currentSlotIndex)) ? 1 : 0
                        highlighted: root.focusSubArea === 2 && root.focusParamIndex === 0
                        onCurrentIndexChanged: {
                            if (typeof centralControlManager !== "undefined") {
                                centralControlManager.setSlotEnabled(root.currentSlotIndex, currentIndex === 1)
                            }
                        }
                    }

                    // ===== 参数1: 协议类型 =====
                    Text {
                        text: "协议类型"
                        color: "#B0BEC5"
                        font.pixelSize: 13
                        Layout.preferredWidth: 100
                    }
                    DeviceInfo.CustomComboBox {
                        id: protocolField
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 36
                        model: ["MQTT", "S7", "Modbus TCP"]
                        currentIndex: {
                            var proto = getCurrentSlotProtocol()
                            switch(proto) {
                            case "mqtt": return 0
                            case "s7": return 1
                            case "modbus": return 2
                            default: return 0
                            }
                        }
                        highlighted: root.focusSubArea === 2 && root.focusParamIndex === 1
                        onCurrentIndexChanged: {
                            var protocols = ["mqtt", "s7", "modbus"]
                            if (typeof centralControlManager !== "undefined") {
                                centralControlManager.setSlotProtocol(root.currentSlotIndex, protocols[currentIndex])
                            }
                        }
                    }

                    // ===== MQTT协议参数 =====
                    // 参数2: 目标设备ID
                    Text {
                        text: "目标设备ID"
                        color: "#B0BEC5"
                        font.pixelSize: 13
                        Layout.preferredWidth: 100
                        visible: getCurrentSlotProtocol() === "mqtt"
                    }
                    DeviceInfo.CustomSpinBox {
                        id: mqttTargetIdField
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 36
                        from: 1
                        to: 8
                        value: (typeof centralControlManager !== "undefined")
                               ? centralControlManager.getSlotParam(root.currentSlotIndex, "targetDeviceId") || 1 : 1
                        visible: getCurrentSlotProtocol() === "mqtt"
                        highlighted: root.focusSubArea === 2 && root.focusParamIndex === 2 && visible
                        onValueChanged: {
                            if (typeof centralControlManager !== "undefined") {
                                centralControlManager.setSlotParam(root.currentSlotIndex, "targetDeviceId", value)
                            }
                        }
                    }

                    // 参数3: Topic前缀
                    Text {
                        text: "Topic前缀"
                        color: "#B0BEC5"
                        font.pixelSize: 13
                        Layout.preferredWidth: 100
                        visible: getCurrentSlotProtocol() === "mqtt"
                    }
                    Text {
                        text: "belt/" + mqttTargetIdField.value + "/control"
                        color: "#78909C"
                        font.pixelSize: 13
                        Layout.preferredWidth: 120
                        visible: getCurrentSlotProtocol() === "mqtt"
                    }

                    // ===== S7协议参数 =====
                    // 参数2: 目标IP
                    Text {
                        text: "目标IP"
                        color: "#B0BEC5"
                        font.pixelSize: 13
                        Layout.preferredWidth: 100
                        visible: getCurrentSlotProtocol() === "s7"
                    }
                    DeviceInfo.CustomTextField {
                        id: s7TargetIPField
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 36
                        text: (typeof centralControlManager !== "undefined")
                              ? centralControlManager.getSlotTargetIP(root.currentSlotIndex) : "192.168.0.1"
                        visible: getCurrentSlotProtocol() === "s7"
                        highlighted: root.focusSubArea === 2 && root.focusParamIndex === 2 && visible
                        onTextChanged: {
                            if (typeof centralControlManager !== "undefined") {
                                centralControlManager.setSlotTargetIP(root.currentSlotIndex, text)
                            }
                        }
                    }

                    // 参数3: 端口
                    Text {
                        text: "端口"
                        color: "#B0BEC5"
                        font.pixelSize: 13
                        Layout.preferredWidth: 100
                        visible: getCurrentSlotProtocol() === "s7"
                    }
                    DeviceInfo.CustomSpinBox {
                        id: s7PortField
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 36
                        from: 1
                        to: 65535
                        value: (typeof centralControlManager !== "undefined")
                               ? centralControlManager.getSlotPort(root.currentSlotIndex) : 102
                        visible: getCurrentSlotProtocol() === "s7"
                        highlighted: root.focusSubArea === 2 && root.focusParamIndex === 3 && visible
                        onValueChanged: {
                            if (typeof centralControlManager !== "undefined") {
                                centralControlManager.setSlotPort(root.currentSlotIndex, value)
                            }
                        }
                    }

                    // 参数4: 机架
                    Text {
                        text: "机架"
                        color: "#B0BEC5"
                        font.pixelSize: 13
                        Layout.preferredWidth: 100
                        visible: getCurrentSlotProtocol() === "s7"
                    }
                    DeviceInfo.CustomSpinBox {
                        id: s7RackField
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 36
                        from: 0
                        to: 7
                        value: (typeof centralControlManager !== "undefined")
                               ? centralControlManager.getSlotParam(root.currentSlotIndex, "rack") || 0 : 0
                        visible: getCurrentSlotProtocol() === "s7"
                        highlighted: root.focusSubArea === 2 && root.focusParamIndex === 4 && visible
                        onValueChanged: {
                            if (typeof centralControlManager !== "undefined") {
                                centralControlManager.setSlotParam(root.currentSlotIndex, "rack", value)
                            }
                        }
                    }

                    // 参数5: 插槽
                    Text {
                        text: "插槽"
                        color: "#B0BEC5"
                        font.pixelSize: 13
                        Layout.preferredWidth: 100
                        visible: getCurrentSlotProtocol() === "s7"
                    }
                    DeviceInfo.CustomSpinBox {
                        id: s7SlotField
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 36
                        from: 0
                        to: 31
                        value: (typeof centralControlManager !== "undefined")
                               ? centralControlManager.getSlotParam(root.currentSlotIndex, "slot") || 2 : 2
                        visible: getCurrentSlotProtocol() === "s7"
                        highlighted: root.focusSubArea === 2 && root.focusParamIndex === 5 && visible
                        onValueChanged: {
                            if (typeof centralControlManager !== "undefined") {
                                centralControlManager.setSlotParam(root.currentSlotIndex, "slot", value)
                            }
                        }
                    }

                    // 参数6: 连接类型
                    Text {
                        text: "连接类型"
                        color: "#B0BEC5"
                        font.pixelSize: 13
                        Layout.preferredWidth: 100
                        visible: getCurrentSlotProtocol() === "s7"
                    }
                    DeviceInfo.CustomComboBox {
                        id: s7ConnTypeField
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 36
                        model: ["PG", "OP", "Basic"]
                        currentIndex: {
                            var ct = (typeof centralControlManager !== "undefined")
                                     ? centralControlManager.getSlotParam(root.currentSlotIndex, "connectionType") : "PG"
                            switch(ct) {
                            case "OP": return 1
                            case "Basic": return 2
                            default: return 0
                            }
                        }
                        visible: getCurrentSlotProtocol() === "s7"
                        highlighted: root.focusSubArea === 2 && root.focusParamIndex === 6 && visible
                    }

                    // ===== Modbus TCP协议参数 =====
                    // 参数2: 目标IP
                    Text {
                        text: "目标IP"
                        color: "#B0BEC5"
                        font.pixelSize: 13
                        Layout.preferredWidth: 100
                        visible: getCurrentSlotProtocol() === "modbus"
                    }
                    DeviceInfo.CustomTextField {
                        id: modbusTargetIPField
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 36
                        text: (typeof centralControlManager !== "undefined")
                              ? centralControlManager.getSlotTargetIP(root.currentSlotIndex) : "192.168.1.1"
                        visible: getCurrentSlotProtocol() === "modbus"
                        highlighted: root.focusSubArea === 2 && root.focusParamIndex === 2 && visible
                        onTextChanged: {
                            if (typeof centralControlManager !== "undefined") {
                                centralControlManager.setSlotTargetIP(root.currentSlotIndex, text)
                            }
                        }
                    }

                    // 参数3: 端口
                    Text {
                        text: "端口"
                        color: "#B0BEC5"
                        font.pixelSize: 13
                        Layout.preferredWidth: 100
                        visible: getCurrentSlotProtocol() === "modbus"
                    }
                    DeviceInfo.CustomSpinBox {
                        id: modbusPortField
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 36
                        from: 1
                        to: 65535
                        value: (typeof centralControlManager !== "undefined")
                               ? centralControlManager.getSlotPort(root.currentSlotIndex) : 502
                        visible: getCurrentSlotProtocol() === "modbus"
                        highlighted: root.focusSubArea === 2 && root.focusParamIndex === 3 && visible
                        onValueChanged: {
                            if (typeof centralControlManager !== "undefined") {
                                centralControlManager.setSlotPort(root.currentSlotIndex, value)
                            }
                        }
                    }

                    // 参数4: 从站地址
                    Text {
                        text: "从站地址"
                        color: "#B0BEC5"
                        font.pixelSize: 13
                        Layout.preferredWidth: 100
                        visible: getCurrentSlotProtocol() === "modbus"
                    }
                    DeviceInfo.CustomSpinBox {
                        id: modbusSlaveAddrField
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 36
                        from: 1
                        to: 247
                        value: (typeof centralControlManager !== "undefined")
                               ? centralControlManager.getSlotParam(root.currentSlotIndex, "slaveAddress") || 1 : 1
                        visible: getCurrentSlotProtocol() === "modbus"
                        highlighted: root.focusSubArea === 2 && root.focusParamIndex === 4 && visible
                        onValueChanged: {
                            if (typeof centralControlManager !== "undefined") {
                                centralControlManager.setSlotParam(root.currentSlotIndex, "slaveAddress", value)
                            }
                        }
                    }

                    // 参数5: 起始寄存器
                    Text {
                        text: "起始寄存器"
                        color: "#B0BEC5"
                        font.pixelSize: 13
                        Layout.preferredWidth: 100
                        visible: getCurrentSlotProtocol() === "modbus"
                    }
                    DeviceInfo.CustomSpinBox {
                        id: modbusStartRegField
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 36
                        from: 0
                        to: 65535
                        value: (typeof centralControlManager !== "undefined")
                               ? centralControlManager.getSlotParam(root.currentSlotIndex, "startRegister") || 0 : 0
                        visible: getCurrentSlotProtocol() === "modbus"
                        highlighted: root.focusSubArea === 2 && root.focusParamIndex === 5 && visible
                        onValueChanged: {
                            if (typeof centralControlManager !== "undefined") {
                                centralControlManager.setSlotParam(root.currentSlotIndex, "startRegister", value)
                            }
                        }
                    }

                    // 参数6: 寄存器数量
                    Text {
                        text: "寄存器数量"
                        color: "#B0BEC5"
                        font.pixelSize: 13
                        Layout.preferredWidth: 100
                        visible: getCurrentSlotProtocol() === "modbus"
                    }
                    DeviceInfo.CustomSpinBox {
                        id: modbusRegCountField
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 36
                        from: 1
                        to: 125
                        value: (typeof centralControlManager !== "undefined")
                               ? centralControlManager.getSlotParam(root.currentSlotIndex, "registerCount") || 10 : 10
                        visible: getCurrentSlotProtocol() === "modbus"
                        highlighted: root.focusSubArea === 2 && root.focusParamIndex === 6 && visible
                        onValueChanged: {
                            if (typeof centralControlManager !== "undefined") {
                                centralControlManager.setSlotParam(root.currentSlotIndex, "registerCount", value)
                            }
                        }
                    }

                    // ===== 连接状态 =====
                    Rectangle {
                        Layout.columnSpan: 4
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        Layout.topMargin: 10
                        color: "#1a2030"
                        radius: 4
                        border.color: "#3d4556"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            Text {
                                text: "状态:"
                                color: "#78909C"
                                font.pixelSize: 13
                            }

                            Rectangle {
                                width: 10
                                height: 10
                                radius: 5
                                color: {
                                    if (typeof centralControlManager === "undefined") return "#555"
                                    return centralControlManager.isSlotConnected(root.currentSlotIndex)
                                           ? "#4CAF50" : "#555"
                                }
                            }

                            Text {
                                text: (typeof centralControlManager !== "undefined")
                                      ? centralControlManager.getSlotStatusText(root.currentSlotIndex) : "未配置"
                                color: "#B0BEC5"
                                font.pixelSize: 13
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }
    }
}
