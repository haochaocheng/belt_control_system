import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5
import "../components/common"
import "../components/control_panel"

// Control Panel Page - Belt Control System Main Interface
// Complete system monitoring and control
Item {
    id: root

    // Public properties
    property bool motorRunning: false
    property real currentSpeed: 2.5

    // 3D Scene Background - Full screen
    BeltScene3D {
        anchors.fill: parent
        isRunning: root.motorRunning
        beltSpeed: root.currentSpeed
    }

    // Header at top
    Header {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 80
    }

    // Left side - Device Status Panel
    DeviceStatusPanel {
        id: deviceStatusPanel
        anchors.left: parent.left
        anchors.top: header.bottom
        anchors.margins: 10
        width: 300
        height: 320

        operationMode: "集控"
        deviceName: "1号皮带"
        deviceStatus: root.motorRunning ? "运行" : "停止"
        mainStationConnected: true
    }

    // Left side - Protection Panel (below device status)
    ProtectionPanel {
        id: protectionPanel
        anchors.left: parent.left
        anchors.top: deviceStatusPanel.bottom
        anchors.margins: 10
        width: 300
        height: 350

        onProtectionClicked: function(protectionName, sourceItem) {
            console.log("Protection clicked:", protectionName)
            operationLogPanel.addLog("打开保护设置: " + protectionName, "info")

            // Find protection type from the model
            var protectionType = "analog"
            for (var i = 0; i < protectionPanel.getProtectionCount(); i++) {
                var item = protectionPanel.getProtectionAt(i)
                if (item && item.name === protectionName) {
                    protectionType = item.type
                    break
                }
            }

            settingsPopup.openForEdit(protectionName, protectionType, sourceItem)
        }

        onAddProtectionClicked: function(sourceItem) {
            console.log("Add protection clicked")
            operationLogPanel.addLog("打开新增保护对话框", "info")
            settingsPopup.openForNew(sourceItem)
        }
    }

    // Left side - Output Device Panel (below protection panel, extends to bottom)
    OutputDevicePanel {
        id: outputDevicePanel
        anchors.left: parent.left
        anchors.top: protectionPanel.bottom
        anchors.bottom: parent.bottom
        anchors.margins: 10
        width: 300

        onDeviceClicked: function(deviceName, sourceItem) {
            console.log("Device clicked:", deviceName)
            operationLogPanel.addLog("打开设备设置: " + deviceName, "info")
            deviceSettingsPopup.openForDevice(deviceName, sourceItem)
        }

        onAddDeviceClicked: function(sourceItem) {
            console.log("Add device clicked")
            operationLogPanel.addLog("打开新增设备对话框", "info")
            deviceSettingsPopup.openForNew(sourceItem)
        }
    }

    // Right side - Module Connection Panel
    ModuleConnectionPanel {
        id: moduleConnectionPanel
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.margins: 10
        width: 300
        height: 200

        mainModuleConnected: true
        inputModuleConnected: true
        outputModuleConnected: true
    }

    // Right side - Operation Log Panel
    OperationLogPanel {
        id: operationLogPanel
        anchors.right: parent.right
        anchors.top: moduleConnectionPanel.bottom
        anchors.margins: 10
        width: 300
        height: 280
    }

    // Right side - Analog Chart (extends to bottom)
    AnalogChart {
        id: analogChart
        anchors.right: parent.right
        anchors.top: operationLogPanel.bottom
        anchors.bottom: parent.bottom
        anchors.margins: 10
        width: 300

        chartTitle: "速度曲线"
        yAxisTitle: "速度 (m/s)"
        maxYValue: 5.0
    }

    // Bottom center - Device Status Bar (32 devices)
    // Positioned between OutputDevicePanel and AnalogChart
    DeviceStatusBar {
        id: deviceStatusBar
        anchors.bottom: parent.bottom
        anchors.left: outputDevicePanel.right
        anchors.right: analogChart.left
        anchors.margins: 10
    }

    // Protection Settings Popup - Using Popup instead of Dialog
    ProtectionSettingsPopup {
        id: settingsPopup

        onAccepted: {
            if (settingsPopup.isNewProtection) {
                protectionPanel.addProtection(
                    settingsPopup.protectionName,
                    settingsPopup.protectionType
                )
                operationLogPanel.addLog(
                    "新增保护: " + settingsPopup.protectionName +
                    " [模块:" + settingsPopup.moduleType +
                    " 通道:" + settingsPopup.channelNumber + "]",
                    "info"
                )
            } else {
                operationLogPanel.addLog(
                    "修改保护参数: " + settingsPopup.protectionName +
                    " [延时:" + settingsPopup.protectionDelay + "s" +
                    " 播放:" + settingsPopup.playCount + "次]",
                    "success"
                )
            }
        }

        onRejected: {
            operationLogPanel.addLog("取消操作", "warning")
        }

        onDeleteRequested: {
            protectionPanel.removeProtection(settingsPopup.protectionName)
            operationLogPanel.addLog("删除保护: " + settingsPopup.protectionName, "error")
        }
    }

    // Output Device Settings Popup
    OutputDeviceSettingsPopup {
        id: deviceSettingsPopup

        onAccepted: {
            if (deviceSettingsPopup.isNewDevice) {
                outputDevicePanel.addDevice(deviceSettingsPopup.deviceName)
                operationLogPanel.addLog(
                    "新增设备: " + deviceSettingsPopup.deviceName +
                    " [输出:" + deviceSettingsPopup.outputModule +
                    " 通道:" + deviceSettingsPopup.channelNumber + "]",
                    "info"
                )
            } else {
                operationLogPanel.addLog(
                    "修改设备参数: " + deviceSettingsPopup.deviceName +
                    " [输出:" + deviceSettingsPopup.outputModule +
                    " 通道:" + deviceSettingsPopup.channelNumber +
                    " 继电器:" + deviceSettingsPopup.relayType + "]",
                    "success"
                )
            }
        }

        onRejected: {
            operationLogPanel.addLog("取消操作", "warning")
        }

        onDeleteRequested: {
            outputDevicePanel.removeDevice(deviceSettingsPopup.deviceName)
            operationLogPanel.addLog("删除设备: " + deviceSettingsPopup.deviceName, "error")
        }
    }

    // Monitor speed changes
    onCurrentSpeedChanged: {
        analogChart.addDataPoint(currentSpeed)
    }

    onMotorRunningChanged: {
        if (motorRunning) {
            operationLogPanel.addLog("电机启动", "success")
        } else {
            operationLogPanel.addLog("电机停止", "info")
        }
    }
}
