// SubStationManageTab.qml
// 分站管理Tab - 8个预设槽位，每个可配置不同协议
// ✅ 2026-04-11 [Phase 7.48.88.110]: 集控管理——分站管理
// ✅ 2026-04-14 [Phase 7.48.88.120]: 键盘导航（分站列表 + 参数区焦点指示器）
// ✅ 2026-04-14 [Phase 7.48.88.121]: 字体/尺寸统一 + 虚拟键盘调用修复

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
    property int focusListIndex: -1     // ✅ 分站列表焦点（来自 NavigationManager.motorListIndex）
    property var virtualKeyboard: null
    property var parentDialog: null     // ✅ 供 CustomComboBox.parentDialog 使用
    property int currentSlotIndex: 0

    // ========== 辅助：焦点边框 ==========
    function focusBorderColor(paramIdx) {
        return (focusSubArea === 2 && focusParamIndex === paramIdx) ? "#2196F3" : "transparent"
    }
    function focusBorderWidth(paramIdx) {
        return (focusSubArea === 2 && focusParamIndex === paramIdx) ? 2 : 0
    }

    // ========== 参数数量（依协议动态变化）==========
    function getParamFieldCount() {
        switch(getCurrentSlotProtocol()) {
        case "mqtt":   return 4
        case "s7":     return 7
        case "modbus": return 7
        default:       return 2
        }
    }

    function getCurrentSlotProtocol() {
        if (typeof centralControlManager === "undefined") return ""
        return centralControlManager.getSlotProtocol(currentSlotIndex)
    }

    function triggerParamInput(index) {
        // ✅ 2026-04-14 [Phase 7.48.88.121]: 使用 activateVirtualKeyboard()
        function activate(field) {
            if (field && field.visible) {
                if (field.activateVirtualKeyboard) field.activateVirtualKeyboard()
                else field.forceActiveFocus()
            }
        }
        var protocol = getCurrentSlotProtocol()
        switch(index) {
        case 0:
            var isEnabled = typeof centralControlManager !== "undefined"
                            && centralControlManager.isSlotEnabled(currentSlotIndex)
            if (typeof centralControlManager !== "undefined")
                centralControlManager.setSlotEnabled(currentSlotIndex, !isEnabled)
            break
        case 1:
            var protocols = ["mqtt", "s7", "modbus"]
            var idx = protocols.indexOf(getCurrentSlotProtocol())
            idx = (idx + 1) % protocols.length
            if (typeof centralControlManager !== "undefined")
                centralControlManager.setSlotProtocol(currentSlotIndex, protocols[idx])
            break
        default:
            if (protocol === "mqtt") {
                if (index === 2) activate(mqttTargetIdField)
            } else if (protocol === "s7") {
                switch(index) {
                case 2: activate(s7TargetIPField);   break
                case 3: activate(s7PortField);       break
                case 4: activate(s7RackField);       break
                case 5: activate(s7SlotField);       break
                case 6:
                    s7ConnTypeField.currentIndex = (s7ConnTypeField.currentIndex + 1) % s7ConnTypeField.count
                    if (typeof centralControlManager !== "undefined")
                        centralControlManager.setSlotParam(currentSlotIndex, "connectionType",
                            s7ConnTypeField.model[s7ConnTypeField.currentIndex])
                    break
                }
            } else if (protocol === "modbus") {
                switch(index) {
                case 2: activate(modbusTargetIPField);   break
                case 3: activate(modbusPortField);       break
                case 4: activate(modbusSlaveAddrField);  break
                case 5: activate(modbusStartRegField);   break
                case 6: activate(modbusRegCountField);   break
                }
            }
        }
    }

    // ========== 主布局 ==========
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ===== 左侧：分站列表 =====
        Rectangle {
            Layout.preferredWidth: 160
            Layout.fillHeight: true
            color: "#1a2030"
            // ✅ 2026-04-14 [Phase 7.48.88.125]: 去掉整体蓝框，改为用标题颜色提示焦点区域
            border.color: "#3d4556"
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 5
                spacing: 2

                Text {
                    text: "分站列表"
                    // ✅ 标题颜色：列表有焦点时变亮
                    color: focusSubArea === 0 ? "#FFFFFF" : "#4FC3F7"
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
                        radius: 4

                        // ✅ 2026-04-14 [Phase 7.48.88.125]: 单项高亮——只高亮当前选中项
                        // 列表模式(focusSubArea===0): 橙色高亮表示键盘焦点
                        // 非列表模式: 蓝色高亮表示当前配置目标
                        color: root.currentSlotIndex === index
                               ? (root.focusSubArea === 0 ? "#3a4a6c" : "#2d3a5c")
                               : "transparent"

                        border.color: {
                            if (root.currentSlotIndex === index && root.focusSubArea === 0)
                                return "#FFB300"   // 橙色 = 列表键盘焦点
                            if (root.currentSlotIndex === index)
                                return "#4FC3F7"   // 蓝色 = 当前配置项
                            return "#3d4556"
                        }
                        border.width: root.currentSlotIndex === index ? 2 : 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 5
                            spacing: 5

                            // 在线状态 LED
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                color: {
                                    if (typeof centralControlManager === "undefined") return "#555"
                                    if (centralControlManager.isSlotConnected(index)) return "#4CAF50"
                                    if (centralControlManager.isSlotEnabled(index))   return "#FFA726"
                                    return "#555"
                                }
                            }

                            Text {
                                text: typeof centralControlManager !== "undefined"
                                      ? centralControlManager.getSlotName(index)
                                      : "分站 " + (index + 1)
                                color: "#B0BEC5"
                                font.pixelSize: 12
                                Layout.fillWidth: true
                            }

                            Text {
                                text: {
                                    if (typeof centralControlManager === "undefined") return ""
                                    var p = centralControlManager.getSlotProtocol(index)
                                    return p ? p.toUpperCase() : ""
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

        // ===== 右侧：槽位配置面板 =====
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
                    rowSpacing: 10

                    // ----- 参数0: 启用/禁用 -----
                    Text { text: "启用:"; font.pixelSize: 21; color: "#9E9E9E"
                           Layout.preferredWidth: 160; horizontalAlignment: Text.AlignRight }
                    Item {
                        Layout.preferredWidth: 200; Layout.preferredHeight: 48
                        DeviceInfo.CustomComboBox {
                            id: enabledField
                            anchors.fill: parent
                            model: ["关闭", "打开"]
                            parentDialog: root.parentDialog
                            currentIndex: (typeof centralControlManager !== "undefined" &&
                                           centralControlManager.isSlotEnabled(root.currentSlotIndex)) ? 1 : 0
                            onActivated: {
                                if (typeof centralControlManager !== "undefined")
                                    centralControlManager.setSlotEnabled(root.currentSlotIndex, currentIndex === 1)
                            }
                        }
                        Rectangle { anchors.fill: parent; color: "transparent"
                            border.color: root.focusBorderColor(0); border.width: root.focusBorderWidth(0)
                            radius: 4; z: 1; enabled: false }
                    }

                    // ----- 参数1: 协议类型 -----
                    Text { text: "协议类型:"; font.pixelSize: 21; color: "#9E9E9E"
                           Layout.preferredWidth: 160; horizontalAlignment: Text.AlignRight }
                    Item {
                        Layout.preferredWidth: 200; Layout.preferredHeight: 48
                        DeviceInfo.CustomComboBox {
                            id: protocolField
                            anchors.fill: parent
                            model: ["MQTT", "S7", "Modbus TCP"]
                            parentDialog: root.parentDialog
                            currentIndex: {
                                switch(getCurrentSlotProtocol()) {
                                case "s7":     return 1
                                case "modbus": return 2
                                default:       return 0
                                }
                            }
                            onActivated: {
                                var protocols = ["mqtt", "s7", "modbus"]
                                if (typeof centralControlManager !== "undefined")
                                    centralControlManager.setSlotProtocol(root.currentSlotIndex, protocols[currentIndex])
                            }
                        }
                        Rectangle { anchors.fill: parent; color: "transparent"
                            border.color: root.focusBorderColor(1); border.width: root.focusBorderWidth(1)
                            radius: 4; z: 1; enabled: false }
                    }

                    // ----- MQTT: 参数2 目标设备ID -----
                    Text { text: "目标设备ID"; font.pixelSize: 21; color: "#9E9E9E"
                           Layout.preferredWidth: 160; horizontalAlignment: Text.AlignRight
                           visible: getCurrentSlotProtocol() === "mqtt" }
                    Item {
                        Layout.preferredWidth: 200; Layout.preferredHeight: 48
                        visible: getCurrentSlotProtocol() === "mqtt"
                        DeviceInfo.CustomSpinBox {
                            id: mqttTargetIdField
                            anchors.fill: parent
                            from: 1; to: 8
                            value: (typeof centralControlManager !== "undefined")
                                   ? centralControlManager.getSlotParam(root.currentSlotIndex, "targetDeviceId") || 1 : 1
                            onValueChanged: {
                                if (typeof centralControlManager !== "undefined")
                                    centralControlManager.setSlotParam(root.currentSlotIndex, "targetDeviceId", value)
                            }
                        }
                        Rectangle { anchors.fill: parent; color: "transparent"
                            border.color: root.focusBorderColor(2); border.width: root.focusBorderWidth(2)
                            radius: 4; z: 1; enabled: false }
                    }

                    // ----- MQTT: 参数3 Topic前缀 -----
                    Text { text: "Topic前缀"; font.pixelSize: 21; color: "#9E9E9E"
                           Layout.preferredWidth: 160; horizontalAlignment: Text.AlignRight
                           visible: getCurrentSlotProtocol() === "mqtt" }
                    Text {
                        text: "belt/" + mqttTargetIdField.value + "/ctrl"
                        color: "#78909C"; font.pixelSize: 13; Layout.preferredWidth: 120
                        visible: getCurrentSlotProtocol() === "mqtt"
                    }

                    // ----- S7: 参数2 目标IP -----
                    Text { text: "目标IP"; font.pixelSize: 21; color: "#9E9E9E"
                           Layout.preferredWidth: 160; horizontalAlignment: Text.AlignRight
                           visible: getCurrentSlotProtocol() === "s7" }
                    Item {
                        Layout.preferredWidth: 200; Layout.preferredHeight: 48
                        visible: getCurrentSlotProtocol() === "s7"
                        DeviceInfo.CustomTextField {
                            id: s7TargetIPField
                            anchors.fill: parent
                            text: (typeof centralControlManager !== "undefined")
                                  ? centralControlManager.getSlotTargetIP(root.currentSlotIndex) : "192.168.0.1"
                            onTextChanged: {
                                if (typeof centralControlManager !== "undefined")
                                    centralControlManager.setSlotTargetIP(root.currentSlotIndex, text)
                            }
                        }
                        Rectangle { anchors.fill: parent; color: "transparent"
                            border.color: root.focusBorderColor(2); border.width: root.focusBorderWidth(2)
                            radius: 4; z: 1; enabled: false }
                    }

                    // ----- S7: 参数3 端口 -----
                    Text { text: "端口"; font.pixelSize: 21; color: "#9E9E9E"
                           Layout.preferredWidth: 160; horizontalAlignment: Text.AlignRight
                           visible: getCurrentSlotProtocol() === "s7" }
                    Item {
                        Layout.preferredWidth: 200; Layout.preferredHeight: 48
                        visible: getCurrentSlotProtocol() === "s7"
                        DeviceInfo.CustomSpinBox {
                            id: s7PortField; anchors.fill: parent
                            from: 1; to: 65535
                            value: (typeof centralControlManager !== "undefined")
                                   ? centralControlManager.getSlotPort(root.currentSlotIndex) : 102
                            onValueChanged: {
                                if (typeof centralControlManager !== "undefined")
                                    centralControlManager.setSlotPort(root.currentSlotIndex, value)
                            }
                        }
                        Rectangle { anchors.fill: parent; color: "transparent"
                            border.color: root.focusBorderColor(3); border.width: root.focusBorderWidth(3)
                            radius: 4; z: 1; enabled: false }
                    }

                    // ----- S7: 参数4 机架 -----
                    Text { text: "机架"; font.pixelSize: 21; color: "#9E9E9E"
                           Layout.preferredWidth: 160; horizontalAlignment: Text.AlignRight
                           visible: getCurrentSlotProtocol() === "s7" }
                    Item {
                        Layout.preferredWidth: 200; Layout.preferredHeight: 48
                        visible: getCurrentSlotProtocol() === "s7"
                        DeviceInfo.CustomSpinBox {
                            id: s7RackField; anchors.fill: parent
                            from: 0; to: 7
                            value: (typeof centralControlManager !== "undefined")
                                   ? centralControlManager.getSlotParam(root.currentSlotIndex, "rack") || 0 : 0
                            onValueChanged: {
                                if (typeof centralControlManager !== "undefined")
                                    centralControlManager.setSlotParam(root.currentSlotIndex, "rack", value)
                            }
                        }
                        Rectangle { anchors.fill: parent; color: "transparent"
                            border.color: root.focusBorderColor(4); border.width: root.focusBorderWidth(4)
                            radius: 4; z: 1; enabled: false }
                    }

                    // ----- S7: 参数5 插槽 -----
                    Text { text: "插槽"; font.pixelSize: 21; color: "#9E9E9E"
                           Layout.preferredWidth: 160; horizontalAlignment: Text.AlignRight
                           visible: getCurrentSlotProtocol() === "s7" }
                    Item {
                        Layout.preferredWidth: 200; Layout.preferredHeight: 48
                        visible: getCurrentSlotProtocol() === "s7"
                        DeviceInfo.CustomSpinBox {
                            id: s7SlotField; anchors.fill: parent
                            from: 0; to: 31
                            value: (typeof centralControlManager !== "undefined")
                                   ? centralControlManager.getSlotParam(root.currentSlotIndex, "slot") || 2 : 2
                            onValueChanged: {
                                if (typeof centralControlManager !== "undefined")
                                    centralControlManager.setSlotParam(root.currentSlotIndex, "slot", value)
                            }
                        }
                        Rectangle { anchors.fill: parent; color: "transparent"
                            border.color: root.focusBorderColor(5); border.width: root.focusBorderWidth(5)
                            radius: 4; z: 1; enabled: false }
                    }

                    // ----- S7: 参数6 连接类型 -----
                    Text { text: "连接类型"; font.pixelSize: 21; color: "#9E9E9E"
                           Layout.preferredWidth: 160; horizontalAlignment: Text.AlignRight
                           visible: getCurrentSlotProtocol() === "s7" }
                    Item {
                        Layout.preferredWidth: 200; Layout.preferredHeight: 48
                        visible: getCurrentSlotProtocol() === "s7"
                        DeviceInfo.CustomComboBox {
                            id: s7ConnTypeField; anchors.fill: parent
                            model: ["PG", "OP", "Basic"]
                            parentDialog: root.parentDialog
                            currentIndex: {
                                var ct = (typeof centralControlManager !== "undefined")
                                         ? centralControlManager.getSlotParam(root.currentSlotIndex, "connectionType") : "PG"
                                switch(ct) { case "OP": return 1; case "Basic": return 2; default: return 0 }
                            }
                            onActivated: {
                                if (typeof centralControlManager !== "undefined")
                                    centralControlManager.setSlotParam(root.currentSlotIndex, "connectionType",
                                        s7ConnTypeField.model[currentIndex])
                            }
                        }
                        Rectangle { anchors.fill: parent; color: "transparent"
                            border.color: root.focusBorderColor(6); border.width: root.focusBorderWidth(6)
                            radius: 4; z: 1; enabled: false }
                    }

                    // ----- Modbus: 参数2 目标IP -----
                    Text { text: "目标IP"; font.pixelSize: 21; color: "#9E9E9E"
                           Layout.preferredWidth: 160; horizontalAlignment: Text.AlignRight
                           visible: getCurrentSlotProtocol() === "modbus" }
                    Item {
                        Layout.preferredWidth: 200; Layout.preferredHeight: 48
                        visible: getCurrentSlotProtocol() === "modbus"
                        DeviceInfo.CustomTextField {
                            id: modbusTargetIPField; anchors.fill: parent
                            text: (typeof centralControlManager !== "undefined")
                                  ? centralControlManager.getSlotTargetIP(root.currentSlotIndex) : "192.168.1.1"
                            onTextChanged: {
                                if (typeof centralControlManager !== "undefined")
                                    centralControlManager.setSlotTargetIP(root.currentSlotIndex, text)
                            }
                        }
                        Rectangle { anchors.fill: parent; color: "transparent"
                            border.color: root.focusBorderColor(2); border.width: root.focusBorderWidth(2)
                            radius: 4; z: 1; enabled: false }
                    }

                    // ----- Modbus: 参数3 端口 -----
                    Text { text: "端口"; font.pixelSize: 21; color: "#9E9E9E"
                           Layout.preferredWidth: 160; horizontalAlignment: Text.AlignRight
                           visible: getCurrentSlotProtocol() === "modbus" }
                    Item {
                        Layout.preferredWidth: 200; Layout.preferredHeight: 48
                        visible: getCurrentSlotProtocol() === "modbus"
                        DeviceInfo.CustomSpinBox {
                            id: modbusPortField; anchors.fill: parent
                            from: 1; to: 65535
                            value: (typeof centralControlManager !== "undefined")
                                   ? centralControlManager.getSlotPort(root.currentSlotIndex) : 502
                            onValueChanged: {
                                if (typeof centralControlManager !== "undefined")
                                    centralControlManager.setSlotPort(root.currentSlotIndex, value)
                            }
                        }
                        Rectangle { anchors.fill: parent; color: "transparent"
                            border.color: root.focusBorderColor(3); border.width: root.focusBorderWidth(3)
                            radius: 4; z: 1; enabled: false }
                    }

                    // ----- Modbus: 参数4 从站地址 -----
                    Text { text: "从站地址"; font.pixelSize: 21; color: "#9E9E9E"
                           Layout.preferredWidth: 160; horizontalAlignment: Text.AlignRight
                           visible: getCurrentSlotProtocol() === "modbus" }
                    Item {
                        Layout.preferredWidth: 200; Layout.preferredHeight: 48
                        visible: getCurrentSlotProtocol() === "modbus"
                        DeviceInfo.CustomSpinBox {
                            id: modbusSlaveAddrField; anchors.fill: parent
                            from: 1; to: 247
                            value: (typeof centralControlManager !== "undefined")
                                   ? centralControlManager.getSlotParam(root.currentSlotIndex, "slaveAddress") || 1 : 1
                            onValueChanged: {
                                if (typeof centralControlManager !== "undefined")
                                    centralControlManager.setSlotParam(root.currentSlotIndex, "slaveAddress", value)
                            }
                        }
                        Rectangle { anchors.fill: parent; color: "transparent"
                            border.color: root.focusBorderColor(4); border.width: root.focusBorderWidth(4)
                            radius: 4; z: 1; enabled: false }
                    }

                    // ----- Modbus: 参数5 起始寄存器 -----
                    Text { text: "起始寄存器"; font.pixelSize: 21; color: "#9E9E9E"
                           Layout.preferredWidth: 160; horizontalAlignment: Text.AlignRight
                           visible: getCurrentSlotProtocol() === "modbus" }
                    Item {
                        Layout.preferredWidth: 200; Layout.preferredHeight: 48
                        visible: getCurrentSlotProtocol() === "modbus"
                        DeviceInfo.CustomSpinBox {
                            id: modbusStartRegField; anchors.fill: parent
                            from: 0; to: 65535
                            value: (typeof centralControlManager !== "undefined")
                                   ? centralControlManager.getSlotParam(root.currentSlotIndex, "startRegister") || 0 : 0
                            onValueChanged: {
                                if (typeof centralControlManager !== "undefined")
                                    centralControlManager.setSlotParam(root.currentSlotIndex, "startRegister", value)
                            }
                        }
                        Rectangle { anchors.fill: parent; color: "transparent"
                            border.color: root.focusBorderColor(5); border.width: root.focusBorderWidth(5)
                            radius: 4; z: 1; enabled: false }
                    }

                    // ----- Modbus: 参数6 寄存器数量 -----
                    Text { text: "寄存器数量"; font.pixelSize: 21; color: "#9E9E9E"
                           Layout.preferredWidth: 160; horizontalAlignment: Text.AlignRight
                           visible: getCurrentSlotProtocol() === "modbus" }
                    Item {
                        Layout.preferredWidth: 200; Layout.preferredHeight: 48
                        visible: getCurrentSlotProtocol() === "modbus"
                        DeviceInfo.CustomSpinBox {
                            id: modbusRegCountField; anchors.fill: parent
                            from: 1; to: 125
                            value: (typeof centralControlManager !== "undefined")
                                   ? centralControlManager.getSlotParam(root.currentSlotIndex, "registerCount") || 10 : 10
                            onValueChanged: {
                                if (typeof centralControlManager !== "undefined")
                                    centralControlManager.setSlotParam(root.currentSlotIndex, "registerCount", value)
                            }
                        }
                        Rectangle { anchors.fill: parent; color: "transparent"
                            border.color: root.focusBorderColor(6); border.width: root.focusBorderWidth(6)
                            radius: 4; z: 1; enabled: false }
                    }

                    // ----- 连接状态行 -----
                    Rectangle {
                        Layout.columnSpan: 4
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        Layout.topMargin: 10
                        color: "#1a2030"; radius: 4
                        border.color: "#3d4556"; border.width: 1

                        RowLayout {
                            anchors.fill: parent; anchors.margins: 10; spacing: 10
                            Text { text: "状态:"; color: "#78909C"; font.pixelSize: 13 }
                            Rectangle {
                                width: 10; height: 10; radius: 5
                                color: {
                                    if (typeof centralControlManager === "undefined") return "#555"
                                    return centralControlManager.isSlotConnected(root.currentSlotIndex)
                                           ? "#4CAF50" : "#555"
                                }
                            }
                            Text {
                                text: (typeof centralControlManager !== "undefined")
                                      ? centralControlManager.getSlotStatusText(root.currentSlotIndex) : "未配置"
                                color: "#B0BEC5"; font.pixelSize: 13
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }
    }
}
