import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5
import Qt5Compat.GraphicalEffects
import BeltControl.SipPhone 1.0
import "pages"
import "components"

Item {
    id: app
    anchors.fill: parent
    focus: true

    // Shared properties
    property bool motorRunning: false
    property real currentSpeed: 2.5

    // Keyboard event handling - Route to appropriate mode controller
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Left) {
            // 左键：切换到上一页，如果在第一页则循环到最后一页
            console.log("[Keyboard] Left键按下 - 切换到上一页")
            if (swipeView.currentIndex > 0) {
                swipeView.currentIndex--
            } else {
                swipeView.currentIndex = swipeView.count - 1
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            // 右键：切换到下一页，如果在最后一页则循环到第一页
            console.log("[Keyboard] Right键按下 - 切换到下一页")
            if (swipeView.currentIndex < swipeView.count - 1) {
                swipeView.currentIndex++
            } else {
                swipeView.currentIndex = 0
            }
            event.accepted = true
        } else if (event.key === Qt.Key_R) {
            console.log("[Keyboard] R键按下 - 根据工作模式路由")
            if (!systemConfig) {
                console.warn("⚠️ SystemConfig未初始化")
                event.accepted = true
                return
            }

            // 检查是否存在故障 - 如果存在故障，弹出故障提示对话框
            if (runtimeTracker && runtimeTracker.isFault) {
                console.log("⚠️ 检测到故障状态，弹出故障提示对话框")
                faultWarningDialog.open()
                event.accepted = true
                return
            }

            // 根据工作模式路由到对应的控制器
            var workMode = systemConfig.workMode
            console.log("  当前工作模式:", workMode,
                       "(0=检修, 1=就地, 2=点动, 3=集控)")

            if (workMode === 0) {
                // 检修模式 - 无连锁
                console.log("  ➡️ 调用 maintenanceControl.handleStart()")
                if (maintenanceControl) {
                    maintenanceControl.handleStart()
                }
            } else if (workMode === 1) {
                // 就地模式 - 有连锁
                console.log("  ➡️ 调用 localControl.handleStart()")
                if (localControl) {
                    localControl.handleStart()
                }
            } else if (workMode === 2) {
                // 点动模式 - 待实现
                console.log("  ⚠️ 点动模式尚未实现")
            } else if (workMode === 3) {
                // 集控模式 - 待实现
                console.log("  ⚠️ 集控模式尚未实现")
            }
            event.accepted = true
        } else if (event.key === Qt.Key_S) {
            console.log("[Keyboard] S键按下 - 根据工作模式路由")
            if (!systemConfig) {
                console.warn("⚠️ SystemConfig未初始化")
                event.accepted = true
                return
            }

            // 根据工作模式路由到对应的控制器
            var workMode = systemConfig.workMode
            console.log("  当前工作模式:", workMode,
                       "(0=检修, 1=就地, 2=点动, 3=集控)")

            if (workMode === 0) {
                // 检修模式 - 无连锁
                console.log("  ➡️ 调用 maintenanceControl.handleStop()")
                if (maintenanceControl) {
                    maintenanceControl.handleStop()
                }
            } else if (workMode === 1) {
                // 就地模式 - 有连锁
                console.log("  ➡️ 调用 localControl.handleStop()")
                if (localControl) {
                    localControl.handleStop()
                }
            } else if (workMode === 2) {
                // 点动模式 - 待实现
                console.log("  ⚠️ 点动模式尚未实现")
            } else if (workMode === 3) {
                // 集控模式 - 待实现
                console.log("  ⚠️ 集控模式尚未实现")
            }
            event.accepted = true
        } else if (event.key === Qt.Key_F) {
            console.log("[Keyboard] F键按下 - 故障复位")

            // ✅ 2026-03-23 [Phase 7.48.86]: 检查保护条件是否已恢复
            // 原因：保护停车后必须先确认保护条件恢复，再按F键复位
            if (protectionLogicController) {
                var activeList = protectionLogicController.activeProtections()
                if (activeList.length > 0) {
                    console.log("⚠️ 还有", activeList.length, "个保护未恢复，不允许复位")
                    // 更新未恢复保护列表供弹窗显示
                    protectionNotClearedDialog.activeProtectionsList = activeList
                    protectionNotClearedDialog.open()
                    event.accepted = true
                    return
                }
                // 所有保护已恢复，清除 ProtectionLogicController 状态
                protectionLogicController.resetAllProtections()
                console.log("✅ 保护逻辑控制器已复位")
            }

            if (runtimeTracker) {
                runtimeTracker.resetFault()
                console.log("✅ 运行故障已复位")
            } else {
                console.warn("⚠️ RuntimeTracker未初始化")
            }
            if (protectionMonitor) {
                protectionMonitor.manualReset()
                console.log("✅ 保护故障已复位（已检查外部信号）")
            } else {
                console.warn("⚠️ ProtectionMonitor未初始化")
            }
            event.accepted = true
        }
    }

    // Tech blue gradient background
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0a1628" }
            GradientStop { position: 0.5; color: "#0d2137" }
            GradientStop { position: 1.0; color: "#0a1628" }
        }
    }

    // Tech grid overlay effect
    Canvas {
        id: gridCanvas
        anchors.fill: parent
        opacity: 0.1
        onPaint: {
            // ✅ 2026-02-12 [Phase 7.45.27]: 检查Canvas尺寸
            // ✅ 2026-02-12 11:51:51 +08:00: 先检查 available，避免 QPainter not active
            if (!available) return
            if (width <= 0 || height <= 0) return
            var ctx = getContext("2d")
            if (!ctx) return

            ctx.strokeStyle = "#00d4ff"
            ctx.lineWidth = 0.5
            var gridSize = 40
            for (var x = 0; x < width; x += gridSize) {
                ctx.beginPath()
                ctx.moveTo(x, 0)
                ctx.lineTo(x, height)
                ctx.stroke()
            }
            for (var y = 0; y < height; y += gridSize) {
                ctx.beginPath()
                ctx.moveTo(0, y)
                ctx.lineTo(width, y)
                ctx.stroke()
            }
        }

        // ✅ 2026-02-12 [Phase 7.45.29]: 使用Timer延迟绘制，确保Canvas引擎已初始化
        Timer {
            interval: 1
            running: true
            repeat: false
            onTriggered: gridCanvas.requestPaint()
        }
    }

    // SwipeView for pages (full screen)
    SwipeView {
        id: swipeView
        anchors.fill: parent
        currentIndex: 0

        // ✅ 2026-01-31 [FIX 100.300.112.8.17]: 监听页面切换，恢复焦点
        // ✅ 2026-02-10 [Phase 7.45.12]: 更新 Input1Page 索引（从 4 变成 5）
        onCurrentIndexChanged: {
            console.log("[SwipeView] 页面切换到索引:", currentIndex)

            // 当切换到 Input1Page（索引5）时，将焦点转移到 Screen01
            if (currentIndex === 5) {
                console.log("[SwipeView] 切换到 Input1Page，恢复 Screen01 焦点")
                Qt.callLater(function() {
                    var input1Page = swipeView.itemAt(5)
                    if (input1Page && input1Page.children[0]) {
                        var screenLoader = input1Page.children[0]
                        if (screenLoader && screenLoader.item) {
                            console.log("[SwipeView] 找到 Screen01，强制获取焦点")
                            screenLoader.item.forceActiveFocus()
                        } else {
                            console.warn("[SwipeView] ⚠️ Screen01 未加载")
                        }
                    } else {
                        console.warn("[SwipeView] ⚠️ Input1Page 未找到")
                    }
                })
            }
        }

        // Page 1: Control Panel - New Belt Control System Interface
        ControlPanel {
            motorRunning: app.motorRunning
            currentSpeed: app.currentSpeed

            onMotorRunningChanged: app.motorRunning = motorRunning
            onCurrentSpeedChanged: app.currentSpeed = currentSpeed
        }

        // ✅ 2026-02-10 [Phase 7.45.12]: Page 2: Device Monitor - 设备监控（数字孪生）
        DeviceMonitorPage {
        }

        // Page 3: Parameter Settings (unchanged)
        ParameterSettings {
        }

        // Page 4: Alarm Page (unchanged)
        AlarmPage {
        }

        // Page 5: Device Operation Log - 设备运行信息
        DeviceOperationLog {
        }

        // ✅ 2026-01-31 [FIX 100.300.112.8.9]: 添加 Input1Page（第6个页面）
        // Page 6: Input1 Page - QDS 设计的输入界面
        Input1Page {
        }

        // ✅ 2026-02-11 [Phase 7.45.22]: 添加 VoiceManagement（第7个页面）
        // Page 7: Voice Management - 语音管理
        VoiceManagement {
        }
    }

    // Page indicator - Floating at bottom
    PageIndicator {
        id: indicator
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 20
        count: swipeView.count
        currentIndex: swipeView.currentIndex
        interactive: true

        delegate: Rectangle {
            implicitWidth: 12
            implicitHeight: 12
            radius: 6
            color: index === indicator.currentIndex ? "#3498db" : "#95a5a6"

            Behavior on color {
                ColorAnimation { duration: 200 }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: swipeView.currentIndex = index
            }
        }
    }

    // Fault Warning Dialog - Shows when R key is pressed with active faults
    Dialog {
        id: faultWarningDialog
        anchors.centerIn: parent
        width: 450
        height: 300
        modal: true
        title: "设备故障警告"
        standardButtons: Dialog.Ok

        background: Rectangle {
            color: "#1a2332"
            radius: 10
            border.color: "#ff4757"
            border.width: 3

            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                color: "transparent"
                radius: 8
                border.color: "#ff6677"
                border.width: 1
            }
        }

        header: Rectangle {
            width: parent.width
            height: 50
            color: "#ff4757"
            radius: 10

            RowLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10

                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    color: "#ffffff"

                    Text {
                        anchors.centerIn: parent
                        text: "⚠"
                        font.pixelSize: 20
                        font.bold: true
                        color: "#ff4757"
                    }
                }

                Text {
                    text: "设备故障警告"
                    font.pixelSize: 18
                    font.bold: true
                    color: "#ffffff"
                    Layout.fillWidth: true
                }
            }
        }

        contentItem: ColumnLayout {
            spacing: 15

            Text {
                text: "系统检测到以下设备存在故障："
                font.pixelSize: 14
                color: "#ecf0f1"
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#0d1926"
                radius: 8
                border.color: "#ff4757"
                border.width: 1

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 10
                    clip: true

                    ColumnLayout {
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: runtimeTracker ? runtimeTracker.faultDevices : []

                            Rectangle {
                                Layout.fillWidth: true
                                height: 35
                                radius: 5
                                color: "#ff4757"
                                border.color: "#ff6677"
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 10

                                    Rectangle {
                                        width: 20
                                        height: 20
                                        radius: 10
                                        color: "#ffffff"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "✕"
                                            font.pixelSize: 14
                                            font.bold: true
                                            color: "#ff4757"
                                        }
                                    }

                                    Text {
                                        // ✅ 2026-03-23 [Phase 7.48.86]: 直接显示保护名称（如"1号皮带 速度超上限"）
                                        // 旧代码：text: modelData + " - 运行失败"
                                        text: modelData
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: "#ffffff"
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Text {
                text: "请先按 F 键进行故障复位，然后再尝试启动设备。"
                font.pixelSize: 13
                color: "#ffa502"
                font.bold: true
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
        }

        footer: DialogButtonBox {
            background: Rectangle {
                color: "transparent"
            }

            Button {
                text: "确认"
                DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole

                background: Rectangle {
                    implicitWidth: 100
                    implicitHeight: 40
                    radius: 5
                    color: parent.pressed ? "#2980b9" : (parent.hovered ? "#3498db" : "#2c3e50")
                    border.color: "#00d4ff"
                    border.width: 2

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }

                contentItem: Text {
                    text: parent.text
                    font.pixelSize: 14
                    font.bold: true
                    color: "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        onAccepted: {
            console.log("✅ 故障警告对话框已确认")
        }
    }

    // ✅ 2026-03-23 [Phase 7.48.86]: 保护未恢复弹窗
    // 原因：按F键复位时，如果还有保护条件未恢复，弹窗提示
    Dialog {
        id: protectionNotClearedDialog
        anchors.centerIn: parent
        width: 450
        height: 320
        modal: true
        title: "保护未恢复"
        standardButtons: Dialog.Ok

        property var activeProtectionsList: []

        background: Rectangle {
            color: "#1a2332"
            radius: 10
            border.color: "#ffa502"
            border.width: 3

            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                color: "transparent"
                radius: 8
                border.color: "#ffbe76"
                border.width: 1
            }
        }

        header: Rectangle {
            width: parent.width
            height: 50
            color: "#ffa502"
            radius: 10

            RowLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10

                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    color: "#ffffff"

                    Text {
                        anchors.centerIn: parent
                        text: "⚠"
                        font.pixelSize: 20
                        font.bold: true
                        color: "#ffa502"
                    }
                }

                Text {
                    text: "保护未恢复 - 无法复位"
                    font.pixelSize: 18
                    font.bold: true
                    color: "#ffffff"
                    Layout.fillWidth: true
                }
            }
        }

        contentItem: ColumnLayout {
            spacing: 15

            Text {
                text: "以下保护条件尚未恢复，无法复位："
                font.pixelSize: 14
                color: "#ecf0f1"
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#0d1926"
                radius: 8
                border.color: "#ffa502"
                border.width: 1

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 10
                    clip: true

                    ColumnLayout {
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: protectionNotClearedDialog.activeProtectionsList

                            Rectangle {
                                Layout.fillWidth: true
                                height: 35
                                radius: 5
                                color: "#e17055"
                                border.color: "#fab1a0"
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 10

                                    Rectangle {
                                        width: 20
                                        height: 20
                                        radius: 10
                                        color: "#ffffff"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "!"
                                            font.pixelSize: 14
                                            font.bold: true
                                            color: "#e17055"
                                        }
                                    }

                                    Text {
                                        text: modelData.protectionName + "（" + modelData.sourceName + "）"
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: "#ffffff"
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Text {
                text: "请等待保护条件恢复后再按 F 键复位。"
                font.pixelSize: 13
                color: "#ffa502"
                font.bold: true
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
        }

        footer: DialogButtonBox {
            background: Rectangle {
                color: "transparent"
            }

            Button {
                text: "确认"
                DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole

                background: Rectangle {
                    implicitWidth: 100
                    implicitHeight: 40
                    radius: 5
                    color: parent.pressed ? "#2980b9" : (parent.hovered ? "#3498db" : "#2c3e50")
                    border.color: "#00d4ff"
                    border.width: 2

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }

                contentItem: Text {
                    text: parent.text
                    font.pixelSize: 14
                    font.bold: true
                    color: "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        onAccepted: {
            console.log("✅ 保护未恢复弹窗已确认")
        }
    }
}
