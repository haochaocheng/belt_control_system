// CentralRoleTab.qml
// 集控角色配置Tab
// 创建日期: 2026-04-11
// ✅ 2026-04-11 [Phase 7.48.88.110]: 集控管理——本机角色配置

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

    // ========== 参数数据 ==========
    property int localDeviceId: typeof centralControlManager !== "undefined"
                                ? centralControlManager.localDeviceId : 1
    property int roleIndex: {
        if (typeof centralControlManager === "undefined") return 2  // 独立
        switch(centralControlManager.stationRole) {
        case "master": return 0
        case "sub": return 1
        default: return 2  // standalone
        }
    }
    property int stationId: typeof centralControlManager !== "undefined"
                            ? centralControlManager.stationId : 1
    property int masterDeviceId: 1  // 仅分站模式下使用

    // ========== 函数 ==========
    function getParamFieldCount() {
        return 4
    }

    function triggerParamInput(index) {
        console.log("✅ [CentralRoleTab] triggerParamInput:", index)

        switch(index) {
        case 0:  // 本机设备ID (SpinBox)
            if (root.virtualKeyboard && deviceIdField) {
                root.virtualKeyboard.targetInput = deviceIdField
                root.virtualKeyboard.show()
            }
            break
        case 1:  // 角色选择 (ComboBox切换)
            roleField.currentIndex = (roleField.currentIndex + 1) % roleField.model.length
            updateRole()
            break
        case 2:  // 集控ID (SpinBox)
            if (root.virtualKeyboard && stationIdField) {
                root.virtualKeyboard.targetInput = stationIdField
                root.virtualKeyboard.show()
            }
            break
        case 3:  // 主站设备ID (SpinBox, 仅分站模式)
            if (root.virtualKeyboard && masterIdField) {
                root.virtualKeyboard.targetInput = masterIdField
                root.virtualKeyboard.show()
            }
            break
        }
    }

    function updateRole() {
        if (typeof centralControlManager === "undefined") return
        var roles = ["master", "sub", "standalone"]
        centralControlManager.stationRole = roles[roleField.currentIndex]
    }

    // ========== 布局 ==========
    ScrollView {
        anchors.fill: parent
        anchors.margins: 10
        clip: true

        GridLayout {
            width: parent.width - 20
            columns: 4
            columnSpacing: 10
            rowSpacing: 8

            // ===== 参数0: 本机设备ID =====
            Text {
                text: "本机设备ID"
                color: "#B0BEC5"
                font.pixelSize: 13
                Layout.preferredWidth: 120
            }
            DeviceInfo.CustomSpinBox {
                id: deviceIdField
                Layout.preferredWidth: 120
                Layout.preferredHeight: 36
                from: 1
                to: 8
                value: root.localDeviceId
                highlighted: root.focusSubArea === 2 && root.focusParamIndex === 0
                onValueChanged: {
                    if (typeof centralControlManager !== "undefined") {
                        centralControlManager.localDeviceId = value
                    }
                }
            }

            // ===== 参数1: 角色选择 =====
            Text {
                text: "集控角色"
                color: "#B0BEC5"
                font.pixelSize: 13
                Layout.preferredWidth: 120
            }
            DeviceInfo.CustomComboBox {
                id: roleField
                Layout.preferredWidth: 120
                Layout.preferredHeight: 36
                model: ["主站", "分站", "独立"]
                currentIndex: root.roleIndex
                highlighted: root.focusSubArea === 2 && root.focusParamIndex === 1
                onCurrentIndexChanged: updateRole()
            }

            // ===== 参数2: 集控ID =====
            Text {
                text: "集控ID"
                color: "#B0BEC5"
                font.pixelSize: 13
                Layout.preferredWidth: 120
            }
            DeviceInfo.CustomSpinBox {
                id: stationIdField
                Layout.preferredWidth: 120
                Layout.preferredHeight: 36
                from: 1
                to: 8
                value: root.stationId
                highlighted: root.focusSubArea === 2 && root.focusParamIndex === 2
                onValueChanged: {
                    if (typeof centralControlManager !== "undefined") {
                        centralControlManager.stationId = value
                    }
                }
            }

            // ===== 参数3: 主站设备ID（仅分站模式可用）=====
            Text {
                text: "主站设备ID"
                color: roleField.currentIndex === 1 ? "#B0BEC5" : "#555"
                font.pixelSize: 13
                Layout.preferredWidth: 120
            }
            DeviceInfo.CustomSpinBox {
                id: masterIdField
                Layout.preferredWidth: 120
                Layout.preferredHeight: 36
                from: 1
                to: 8
                value: root.masterDeviceId
                enabled: roleField.currentIndex === 1  // 仅分站模式
                highlighted: root.focusSubArea === 2 && root.focusParamIndex === 3
                onValueChanged: root.masterDeviceId = value
            }

            // ===== 角色说明 =====
            Rectangle {
                Layout.columnSpan: 4
                Layout.fillWidth: true
                Layout.preferredHeight: 100
                Layout.topMargin: 20
                color: "#1a2030"
                radius: 4
                border.color: "#3d4556"
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    Text {
                        text: "角色说明"
                        color: "#4FC3F7"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                    }
                    Text {
                        text: "主站: 管理分站设备，发送控制指令，接收状态数据"
                        color: "#90A4AE"
                        font.pixelSize: 12
                    }
                    Text {
                        text: "分站: 接收主站指令，上报本机状态"
                        color: "#90A4AE"
                        font.pixelSize: 12
                    }
                    Text {
                        text: "独立: 不参与集控，各设备独立运行"
                        color: "#90A4AE"
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
