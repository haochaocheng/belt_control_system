// CentralRoleTab.qml
// 集控角色配置Tab
// ✅ 2026-04-11 [Phase 7.48.88.110]: 集控管理——本机角色配置
// ✅ 2026-04-14 [Phase 7.48.88.120]: 键盘导航焦点指示器
// ✅ 2026-04-14 [Phase 7.48.88.121]: 字体/尺寸统一 + 虚拟键盘调用修复

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../" as DeviceInfo

Rectangle {
    id: root
    color: "transparent"

    property int focusParamIndex: -1
    property int focusSubArea: 0
    property var virtualKeyboard: null
    property var parentDialog: null

    property int localDeviceId: typeof centralControlManager !== "undefined"
                                ? centralControlManager.localDeviceId : 1
    property int roleIndex: {
        if (typeof centralControlManager === "undefined") return 2
        switch(centralControlManager.stationRole) {
        case "master": return 0
        case "sub":    return 1
        default:       return 2
        }
    }
    property int stationId: typeof centralControlManager !== "undefined"
                            ? centralControlManager.stationId : 1
    property int masterDeviceId: 1

    function focusBorderColor(i) { return (focusSubArea === 2 && focusParamIndex === i) ? "#2196F3" : "transparent" }
    function focusBorderWidth(i) { return (focusSubArea === 2 && focusParamIndex === i) ? 2 : 0 }

    function getParamFieldCount() { return 4 }

    function triggerParamInput(index) {
        // ✅ 2026-04-14 [Phase 7.48.88.121]: 使用 activateVirtualKeyboard()，与其他Tab一致
        switch(index) {
        case 0:
            if (deviceIdField.activateVirtualKeyboard) deviceIdField.activateVirtualKeyboard()
            else deviceIdField.forceActiveFocus()
            break
        case 1:
            roleField.currentIndex = (roleField.currentIndex + 1) % roleField.count
            updateRole()
            break
        case 2:
            if (stationIdField.activateVirtualKeyboard) stationIdField.activateVirtualKeyboard()
            else stationIdField.forceActiveFocus()
            break
        case 3:
            if (masterIdField.activateVirtualKeyboard) masterIdField.activateVirtualKeyboard()
            else masterIdField.forceActiveFocus()
            break
        }
    }

    function updateRole() {
        if (typeof centralControlManager === "undefined") return
        centralControlManager.stationRole = ["master", "sub", "standalone"][roleField.currentIndex]
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: 10
        clip: true

        GridLayout {
            width: parent.width - 20
            columns: 4
            columnSpacing: 10
            rowSpacing: 12

            // ===== 参数0: 本机设备ID =====
            Text {
                text: "本机设备ID:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.fillWidth: true; Layout.maximumWidth: 300; Layout.preferredHeight: 48
                DeviceInfo.CustomSpinBox {
                    id: deviceIdField; anchors.fill: parent
                    from: 1; to: 8; value: root.localDeviceId
                    onValueChanged: {
                        if (typeof centralControlManager !== "undefined")
                            centralControlManager.localDeviceId = value
                    }
                }
                Rectangle { anchors.fill: parent; color: "transparent"
                    border.color: root.focusBorderColor(0); border.width: root.focusBorderWidth(0)
                    radius: 4; z: 1; enabled: false }
            }

            // ===== 参数1: 集控角色 =====
            Text {
                text: "集控角色:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.fillWidth: true; Layout.maximumWidth: 300; Layout.preferredHeight: 48
                DeviceInfo.CustomComboBox {
                    id: roleField; anchors.fill: parent
                    model: ["主站", "分站", "独立"]
                    currentIndex: root.roleIndex
                    parentDialog: root.parentDialog
                    onActivated: updateRole()
                }
                Rectangle { anchors.fill: parent; color: "transparent"
                    border.color: root.focusBorderColor(1); border.width: root.focusBorderWidth(1)
                    radius: 4; z: 1; enabled: false }
            }

            // ===== 参数2: 集控ID =====
            Text {
                text: "集控ID:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.fillWidth: true; Layout.maximumWidth: 300; Layout.preferredHeight: 48
                DeviceInfo.CustomSpinBox {
                    id: stationIdField; anchors.fill: parent
                    from: 1; to: 8; value: root.stationId
                    onValueChanged: {
                        if (typeof centralControlManager !== "undefined")
                            centralControlManager.stationId = value
                    }
                }
                Rectangle { anchors.fill: parent; color: "transparent"
                    border.color: root.focusBorderColor(2); border.width: root.focusBorderWidth(2)
                    radius: 4; z: 1; enabled: false }
            }

            // ===== 参数3: 主站设备ID =====
            Text {
                text: "主站设备ID:"
                font.pixelSize: 21
                color: roleField.currentIndex === 1 ? "#9E9E9E" : "#555"
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.fillWidth: true; Layout.maximumWidth: 300; Layout.preferredHeight: 48
                DeviceInfo.CustomSpinBox {
                    id: masterIdField; anchors.fill: parent
                    from: 1; to: 8; value: root.masterDeviceId
                    enabled: roleField.currentIndex === 1
                    onValueChanged: root.masterDeviceId = value
                }
                Rectangle { anchors.fill: parent; color: "transparent"
                    border.color: root.focusBorderColor(3); border.width: root.focusBorderWidth(3)
                    radius: 4; z: 1; enabled: false }
            }

            // ===== 角色说明 =====
            Rectangle {
                Layout.columnSpan: 4; Layout.fillWidth: true
                Layout.preferredHeight: 110; Layout.topMargin: 20
                color: "#1a2030"; radius: 4; border.color: "#3d4556"; border.width: 1
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 6
                    Text { text: "角色说明"; color: "#4FC3F7"; font.pixelSize: 16; font.weight: Font.Bold }
                    Text { text: "主站: 管理分站设备，发送控制指令，接收状态数据"; color: "#90A4AE"; font.pixelSize: 14 }
                    Text { text: "分站: 接收主站指令，上报本机状态";               color: "#90A4AE"; font.pixelSize: 14 }
                    Text { text: "独立: 不参与集控，各设备独立运行";               color: "#90A4AE"; font.pixelSize: 14 }
                }
            }
        }
    }
}
