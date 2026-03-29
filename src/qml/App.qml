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
        // ✅ 2026-03-25 [Phase 7.48.88.21]: 数字键1-8独立启停设备
        // 前提条件：界面必须在Input1Page（索引2），防止误触发
        // ❌ 2026-03-29 [Phase 7.48.88.53]: 索引从5更新为2
        // 交互模式：toggle - 未运行按下启动，已运行按下停止
        else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_8) {
            var keyNumber = event.key - Qt.Key_0  // 1-8

            // 前提条件：必须在 Input1Page（索引2）
            // ❌ 2026-03-29: 旧索引为5
            if (swipeView.currentIndex !== 2) {
                console.log("[Keyboard] 数字键" + keyNumber + "按下，不在Input1页面，忽略")
                event.accepted = true
                return
            }

            console.log("[Keyboard] 数字键" + keyNumber + "按下 - Input1页面，执行启停操作")

            // 检查故障状态 - 存在故障时不允许启动
            if (runtimeTracker && runtimeTracker.isFault) {
                console.log("⚠️ 检测到故障状态，请先按F键复位")
                faultWarningDialog.open()
                event.accepted = true
                return
            }

            // Toggle逻辑：按皮带号判断运行状态
            // ✅ 2026-03-27 [Phase 7.48.88.32]: 增加启动中状态检测
            // 安全修复：启动过程中（预警播放/设备序列执行中）按停止键必须能中断启动
            if (commonControl.isBeltRunning(keyNumber) || commonControl.isBeltStarting(keyNumber)) {
                // 该皮带正在运行或正在启动中 → 停止
                console.log("  ➡️ " + keyNumber + "号皮带" + (commonControl.isBeltRunning(keyNumber) ? "正在运行" : "正在启动中") + "，执行停止")
                commonControl.stopBelt(keyNumber)
            } else {
                // 该皮带未运行 → 启动（startBelt内部有防重入保护）
                console.log("  ➡️ 启动" + keyNumber + "号皮带")
                commonControl.startBelt(keyNumber)
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
        // ✅ 2026-03-29 [Phase 7.48.88.53]: 更新 Input1Page 索引（从 5 变成 2，移至原 ParameterSettings 位置）
        onCurrentIndexChanged: {
            console.log("[SwipeView] 页面切换到索引:", currentIndex)

            // 当切换到 Input1Page（索引2）时，将焦点转移到 Screen01
            // ❌ 2026-03-29: 旧索引为5，现更新为2
            if (currentIndex === 2) {
                console.log("[SwipeView] 切换到 Input1Page，恢复 Screen01 焦点")
                Qt.callLater(function() {
                    var input1Page = swipeView.itemAt(2)
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

        // ❌ 2026-03-29 [Phase 7.48.88.53]: ParameterSettings 已废弃，替换为 Input1Page
        // 旧代码：
        // // Page 3: Parameter Settings (unchanged)
        // ParameterSettings {
        // }
        // 原因：参数设置页面不再独立使用，12卡片界面（Input1Page）移至此位置

        // ✅ 2026-03-29 [Phase 7.48.88.53]: Input1Page 从索引5移至索引2
        // Page 3: Input1 Page - QDS 设计的12卡片监控界面
        Input1Page {
        }

        // Page 4: Alarm Page (unchanged)
        AlarmPage {
        }

        // Page 5: Device Operation Log - 设备运行信息
        DeviceOperationLog {
        }

        // ❌ 2026-03-29 [Phase 7.48.88.53]: Input1Page 已移至索引2（原 ParameterSettings 位置）
        // 旧代码：
        // // ✅ 2026-01-31 [FIX 100.300.112.8.9]: 添加 Input1Page（第6个页面）
        // // Page 6: Input1 Page - QDS 设计的输入界面
        // Input1Page {
        // }

        // ✅ 2026-02-11 [Phase 7.45.22]: 添加 VoiceManagement（第7个页面）
        // ✅ 2026-03-29 [Phase 7.48.88.53]: Input1Page移走后，VoiceManagement 从索引6降为索引5
        // Page 6: Voice Management - 语音管理
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

    // ✅ 2026-03-24 [Phase 7.48.87]: 故障警告弹窗 — 赛博朋克工业科技风重设计
    // 功能：R键按下时若有活跃故障，弹出此弹窗
    // 新增：键盘操作支持（Enter/Space确认，Escape关闭）+ 脉冲发光边框 + 扫描线效果 + 角标装饰
    Dialog {
        id: faultWarningDialog
        anchors.centerIn: parent
        width: 500
        height: 340
        modal: true
        padding: 0
        // 旧代码：standardButtons: Dialog.Ok
        // 修改原因：自定义footer按钮以支持键盘焦点

        // ✅ 脉冲发光动画属性
        property real glowOpacity: 0.6
        SequentialAnimation on glowOpacity {
            running: faultWarningDialog.visible
            loops: Animation.Infinite
            NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.4; duration: 800; easing.type: Easing.InOutSine }
        }

        // ✅ 扫描线动画属性
        property real scanLineY: 0
        NumberAnimation on scanLineY {
            running: faultWarningDialog.visible
            from: 0; to: 1.0
            duration: 3000
            loops: Animation.Infinite
        }

        background: Rectangle {
            color: "#0a0e14"
            radius: 4
            border.color: Qt.rgba(1.0, 0.28, 0.34, faultWarningDialog.glowOpacity)
            border.width: 2

            // ✅ 外层发光效果
            Rectangle {
                anchors.fill: parent
                anchors.margins: -4
                color: "transparent"
                radius: 6
                border.color: Qt.rgba(1.0, 0.28, 0.34, faultWarningDialog.glowOpacity * 0.3)
                border.width: 2
            }

            // ✅ 内层细线框
            Rectangle {
                anchors.fill: parent
                anchors.margins: 6
                color: "transparent"
                radius: 2
                border.color: Qt.rgba(1.0, 0.28, 0.34, 0.2)
                border.width: 1
            }

            // ✅ 角标装饰 — 左上
            Rectangle { x: 2; y: 2; width: 20; height: 2; color: "#ff4757" }
            Rectangle { x: 2; y: 2; width: 2; height: 20; color: "#ff4757" }
            // ✅ 角标装饰 — 右上
            Rectangle { x: parent.width - 22; y: 2; width: 20; height: 2; color: "#ff4757" }
            Rectangle { x: parent.width - 4; y: 2; width: 2; height: 20; color: "#ff4757" }
            // ✅ 角标装饰 — 左下
            Rectangle { x: 2; y: parent.height - 4; width: 20; height: 2; color: "#ff4757" }
            Rectangle { x: 2; y: parent.height - 22; width: 2; height: 20; color: "#ff4757" }
            // ✅ 角标装饰 — 右下
            Rectangle { x: parent.width - 22; y: parent.height - 4; width: 20; height: 2; color: "#ff4757" }
            Rectangle { x: parent.width - 4; y: parent.height - 22; width: 2; height: 20; color: "#ff4757" }

            // ✅ 扫描线效果
            Rectangle {
                width: parent.width - 12
                height: 1
                x: 6
                y: faultWarningDialog.scanLineY * parent.height
                color: Qt.rgba(1.0, 0.28, 0.34, 0.15)
            }
            Rectangle {
                width: parent.width - 12
                height: 3
                x: 6
                y: faultWarningDialog.scanLineY * parent.height - 1
                color: Qt.rgba(1.0, 0.28, 0.34, 0.05)
            }
        }

        header: Item {
            width: parent.width
            height: 52

            // ✅ 顶部渐变条
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1.0, 0.28, 0.34, 0.25) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // ✅ 底部分隔线
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Qt.rgba(1.0, 0.28, 0.34, 0.5)
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 12
                anchors.verticalCenter: parent.verticalCenter

                // ✅ 警告图标 — 脉冲三角
                Item {
                    width: 36; height: 36
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.centerIn: parent
                        width: 32; height: 32; radius: 4
                        color: "transparent"
                        border.color: Qt.rgba(1.0, 0.28, 0.34, faultWarningDialog.glowOpacity)
                        border.width: 2
                        rotation: 45

                        Rectangle {
                            anchors.centerIn: parent
                            width: 16; height: 16; radius: 2
                            color: "#ff4757"
                            opacity: faultWarningDialog.glowOpacity
                        }
                    }
                }

                // ✅ 标题文字
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: "FAULT WARNING"
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 3
                        color: Qt.rgba(1.0, 0.28, 0.34, 0.7)
                    }
                    Text {
                        text: "设备故障警告"
                        font.pixelSize: 17
                        font.bold: true
                        color: "#ff4757"
                    }
                }
            }
        }

        contentItem: ColumnLayout {
            spacing: 10

            Item { Layout.preferredHeight: 4 }

            // ✅ 提示文字
            Text {
                text: "// SYSTEM ALERT — 检测到以下设备故障"
                font.pixelSize: 12
                font.family: "Consolas"
                color: "#ff6b7a"
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
            }

            // ✅ 故障设备列表区域
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                color: "#060a10"
                radius: 4
                border.color: Qt.rgba(1.0, 0.28, 0.34, 0.3)
                border.width: 1

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 8
                    clip: true

                    ColumnLayout {
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: runtimeTracker ? runtimeTracker.faultDevices : []

                            Rectangle {
                                Layout.fillWidth: true
                                height: 36
                                radius: 3
                                color: Qt.rgba(1.0, 0.28, 0.34, 0.12)
                                border.color: Qt.rgba(1.0, 0.28, 0.34, 0.4)
                                border.width: 1

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10
                                    anchors.verticalCenter: parent.verticalCenter

                                    // ✅ 状态指示灯（脉冲红点）
                                    Rectangle {
                                        width: 8; height: 8; radius: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: "#ff4757"
                                        opacity: faultWarningDialog.glowOpacity
                                    }

                                    Text {
                                        // ✅ 2026-03-23 [Phase 7.48.86]: 直接显示保护名称
                                        text: modelData
                                        font.pixelSize: 13
                                        font.family: "Consolas"
                                        font.bold: true
                                        color: "#ff8a94"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ✅ 底部操作提示
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                height: 32
                color: Qt.rgba(1.0, 0.65, 0.01, 0.1)
                radius: 3
                border.color: Qt.rgba(1.0, 0.65, 0.01, 0.3)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    // ✅ 2026-03-24 [Phase 7.48.88]: 提示文字优化 — 先告知如何关闭弹窗，再提示F键复位
                    // 旧文字：">>> 请先按 F 键进行故障复位，然后再尝试启动 <<<"
                    text: ">>> 按 Enter / Space 关闭此弹窗，然后按 F 键复位 <<<"
                    font.pixelSize: 12
                    font.family: "Consolas"
                    font.bold: true
                    color: "#ffa502"
                }
            }

            Item { Layout.preferredHeight: 2 }
        }

        footer: Item {
            width: parent.width
            height: 56

            // ✅ 顶部分隔线
            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 1
                color: Qt.rgba(1.0, 0.28, 0.34, 0.3)
            }

            // ✅ 2026-03-24 [Phase 7.48.87]: 键盘可操作确认按钮
            Button {
                id: faultConfirmBtn
                anchors.centerIn: parent
                width: 140; height: 40
                text: "确  认"
                focus: true

                background: Rectangle {
                    radius: 4
                    color: faultConfirmBtn.activeFocus ? Qt.rgba(1.0, 0.28, 0.34, 0.3) :
                           (faultConfirmBtn.pressed ? Qt.rgba(1.0, 0.28, 0.34, 0.4) : "#12181f")
                    border.color: faultConfirmBtn.activeFocus ? "#ff4757" :
                                  Qt.rgba(1.0, 0.28, 0.34, 0.5)
                    border.width: faultConfirmBtn.activeFocus ? 2 : 1

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }

                contentItem: Text {
                    text: faultConfirmBtn.text
                    font.pixelSize: 14
                    font.bold: true
                    font.family: "Consolas"
                    font.letterSpacing: 2
                    color: faultConfirmBtn.activeFocus ? "#ff4757" : "#ff8a94"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: faultWarningDialog.close()

                // ✅ 2026-03-24 [Phase 7.48.88]: Keys.onPressed 移到 Button 上
                // 原因：QML Button 默认只响应 Space 键 click，不响应 Enter/Return
                //       Keys.onPressed 放在 Dialog 上时，焦点在 Button，事件不传播到 Dialog
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter ||
                        event.key === Qt.Key_Escape || event.key === Qt.Key_Space) {
                        faultWarningDialog.close()
                        event.accepted = true
                    }
                }

                // ✅ 键盘提示
                Text {
                    anchors.top: parent.bottom
                    anchors.topMargin: 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "[Enter / Space 关闭]"
                    font.pixelSize: 9
                    color: Qt.rgba(1.0, 1.0, 1.0, 0.3)
                    visible: faultConfirmBtn.activeFocus
                }
            }
        }

        // ✅ 2026-03-24 [Phase 7.48.87]: 键盘操作支持
        onOpened: {
            faultConfirmBtn.forceActiveFocus()
        }

        onClosed: {
            console.log("✅ 故障警告对话框已关闭")
        }
    }

    // ✅ 2026-03-24 [Phase 7.48.87]: 保护未恢复弹窗 — 赛博朋克工业科技风
    // 功能：F键复位时若有保护条件未恢复，弹出此弹窗
    // 新增：键盘操作支持 + 橙色主题脉冲发光 + 扫描线效果
    Dialog {
        id: protectionNotClearedDialog
        anchors.centerIn: parent
        width: 500
        height: 360
        modal: true
        padding: 0

        property var activeProtectionsList: []

        // ✅ 脉冲发光动画
        property real glowOpacity: 0.6
        SequentialAnimation on glowOpacity {
            running: protectionNotClearedDialog.visible
            loops: Animation.Infinite
            NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.4; duration: 1000; easing.type: Easing.InOutSine }
        }

        // ✅ 扫描线动画
        property real scanLineY: 0
        NumberAnimation on scanLineY {
            running: protectionNotClearedDialog.visible
            from: 0; to: 1.0
            duration: 4000
            loops: Animation.Infinite
        }

        background: Rectangle {
            color: "#0a0e14"
            radius: 4
            border.color: Qt.rgba(1.0, 0.65, 0.01, protectionNotClearedDialog.glowOpacity)
            border.width: 2

            // ✅ 外层发光
            Rectangle {
                anchors.fill: parent
                anchors.margins: -4
                color: "transparent"
                radius: 6
                border.color: Qt.rgba(1.0, 0.65, 0.01, protectionNotClearedDialog.glowOpacity * 0.3)
                border.width: 2
            }

            // ✅ 内层细线框
            Rectangle {
                anchors.fill: parent
                anchors.margins: 6
                color: "transparent"
                radius: 2
                border.color: Qt.rgba(1.0, 0.65, 0.01, 0.2)
                border.width: 1
            }

            // ✅ 角标装饰 — 左上
            Rectangle { x: 2; y: 2; width: 20; height: 2; color: "#ffa502" }
            Rectangle { x: 2; y: 2; width: 2; height: 20; color: "#ffa502" }
            // ✅ 角标装饰 — 右上
            Rectangle { x: parent.width - 22; y: 2; width: 20; height: 2; color: "#ffa502" }
            Rectangle { x: parent.width - 4; y: 2; width: 2; height: 20; color: "#ffa502" }
            // ✅ 角标装饰 — 左下
            Rectangle { x: 2; y: parent.height - 4; width: 20; height: 2; color: "#ffa502" }
            Rectangle { x: 2; y: parent.height - 22; width: 2; height: 20; color: "#ffa502" }
            // ✅ 角标装饰 — 右下
            Rectangle { x: parent.width - 22; y: parent.height - 4; width: 20; height: 2; color: "#ffa502" }
            Rectangle { x: parent.width - 4; y: parent.height - 22; width: 2; height: 20; color: "#ffa502" }

            // ✅ 扫描线
            Rectangle {
                width: parent.width - 12
                height: 1
                x: 6
                y: protectionNotClearedDialog.scanLineY * parent.height
                color: Qt.rgba(1.0, 0.65, 0.01, 0.15)
            }
            Rectangle {
                width: parent.width - 12
                height: 3
                x: 6
                y: protectionNotClearedDialog.scanLineY * parent.height - 1
                color: Qt.rgba(1.0, 0.65, 0.01, 0.05)
            }
        }

        header: Item {
            width: parent.width
            height: 52

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1.0, 0.65, 0.01, 0.2) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Qt.rgba(1.0, 0.65, 0.01, 0.5)
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 12
                anchors.verticalCenter: parent.verticalCenter

                // ✅ 警告图标 — 脉冲菱形
                Item {
                    width: 36; height: 36
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.centerIn: parent
                        width: 32; height: 32; radius: 4
                        color: "transparent"
                        border.color: Qt.rgba(1.0, 0.65, 0.01, protectionNotClearedDialog.glowOpacity)
                        border.width: 2
                        rotation: 45

                        Rectangle {
                            anchors.centerIn: parent
                            width: 16; height: 16; radius: 2
                            color: "#ffa502"
                            opacity: protectionNotClearedDialog.glowOpacity
                        }
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: "PROTECTION ACTIVE"
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 3
                        color: Qt.rgba(1.0, 0.65, 0.01, 0.7)
                    }
                    Text {
                        text: "保护未恢复 — 无法复位"
                        font.pixelSize: 17
                        font.bold: true
                        color: "#ffa502"
                    }
                }
            }
        }

        contentItem: ColumnLayout {
            spacing: 10

            Item { Layout.preferredHeight: 4 }

            Text {
                text: "// PROTECTION STATUS — 以下保护条件尚未恢复"
                font.pixelSize: 12
                font.family: "Consolas"
                color: "#ffbe76"
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
            }

            // ✅ 保护列表区域
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                color: "#060a10"
                radius: 4
                border.color: Qt.rgba(1.0, 0.65, 0.01, 0.3)
                border.width: 1

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 8
                    clip: true

                    ColumnLayout {
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: protectionNotClearedDialog.activeProtectionsList

                            Rectangle {
                                Layout.fillWidth: true
                                height: 36
                                radius: 3
                                color: Qt.rgba(1.0, 0.65, 0.01, 0.1)
                                border.color: Qt.rgba(1.0, 0.65, 0.01, 0.35)
                                border.width: 1

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10
                                    anchors.verticalCenter: parent.verticalCenter

                                    // ✅ 脉冲橙点
                                    Rectangle {
                                        width: 8; height: 8; radius: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: "#ffa502"
                                        opacity: protectionNotClearedDialog.glowOpacity
                                    }

                                    Text {
                                        text: modelData.protectionName + " [" + modelData.sourceName + "]"
                                        font.pixelSize: 13
                                        font.family: "Consolas"
                                        font.bold: true
                                        color: "#ffbe76"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ✅ 底部提示
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                height: 32
                color: Qt.rgba(1.0, 0.65, 0.01, 0.08)
                radius: 3
                border.color: Qt.rgba(1.0, 0.65, 0.01, 0.25)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    // ✅ 2026-03-24 [Phase 7.48.88]: 提示文字优化 — 先告知如何关闭弹窗
                    // 旧文字：">>> 请等待保护条件恢复后再按 F 键复位 <<<"
                    text: ">>> 按 Enter / Space 关闭此弹窗，等待保护恢复后再按 F 键 <<<"
                    font.pixelSize: 12
                    font.family: "Consolas"
                    font.bold: true
                    color: "#ffa502"
                }
            }

            Item { Layout.preferredHeight: 2 }
        }

        footer: Item {
            width: parent.width
            height: 56

            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 1
                color: Qt.rgba(1.0, 0.65, 0.01, 0.3)
            }

            // ✅ 2026-03-24 [Phase 7.48.87]: 键盘可操作确认按钮
            Button {
                id: protConfirmBtn
                anchors.centerIn: parent
                width: 140; height: 40
                text: "确  认"
                focus: true

                background: Rectangle {
                    radius: 4
                    color: protConfirmBtn.activeFocus ? Qt.rgba(1.0, 0.65, 0.01, 0.25) :
                           (protConfirmBtn.pressed ? Qt.rgba(1.0, 0.65, 0.01, 0.35) : "#12181f")
                    border.color: protConfirmBtn.activeFocus ? "#ffa502" :
                                  Qt.rgba(1.0, 0.65, 0.01, 0.5)
                    border.width: protConfirmBtn.activeFocus ? 2 : 1

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }

                contentItem: Text {
                    text: protConfirmBtn.text
                    font.pixelSize: 14
                    font.bold: true
                    font.family: "Consolas"
                    font.letterSpacing: 2
                    color: protConfirmBtn.activeFocus ? "#ffa502" : "#ffbe76"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: protectionNotClearedDialog.close()

                // ✅ 2026-03-24 [Phase 7.48.88]: Keys.onPressed 移到 Button 上（同 faultWarningDialog）
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter ||
                        event.key === Qt.Key_Escape || event.key === Qt.Key_Space) {
                        protectionNotClearedDialog.close()
                        event.accepted = true
                    }
                }

                Text {
                    anchors.top: parent.bottom
                    anchors.topMargin: 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "[Enter / Space 关闭]"
                    font.pixelSize: 9
                    color: Qt.rgba(1.0, 1.0, 1.0, 0.3)
                    visible: protConfirmBtn.activeFocus
                }
            }
        }

        // ✅ 2026-03-24 [Phase 7.48.87]: 键盘操作支持
        onOpened: {
            protConfirmBtn.forceActiveFocus()
        }

        onClosed: {
            console.log("✅ 保护未恢复弹窗已关闭")
        }
    }
}
