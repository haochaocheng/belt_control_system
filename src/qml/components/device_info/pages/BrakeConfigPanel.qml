import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as DeviceInfo

// 2026-03-14 [Phase 7.48.45]: v4 完整重写-统一字号21px匹配开关量输入页面
Rectangle {
    id: root
    implicitWidth: 1400; implicitHeight: 600; color: "transparent"

    property int deviceId: 1
    property int brakeIndex: 0
    property var keyboardManager: null
    property var virtualKeyboard: null
    property int focusSubArea: 0
    property int focusUsageStatusIndex: 0
    property int focusParamIndex: 0
    property int focusButtonIndex: 0
    property bool waitingForRelease: false
    property bool waitingForBrake: false

    // 统一尺寸常量（匹配SwitchInputPage样式）
    readonly property int lblFs: 21       // 标签字号（与开关量输入一致）
    readonly property string lblC: "#9E9E9E"  // 标签颜色
    readonly property int fldW: 120       // 输入框统一宽度
    readonly property int lblW: 130       // 标签统一宽度

    focus: true; activeFocusOnTab: true

    signal requestFocusParamIndex(int paramIndex)

    // ========== 标题栏 ==========
    Rectangle {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 40; color: "transparent"
        Image { anchors.fill: parent; source: "../images/059.png"; fillMode: Image.Stretch; z: -1 }
        Text {
            anchors.centerIn: parent
            text: (root.brakeIndex + 1) + "号制动器配置"
            font.pixelSize: 16; font.weight: Font.Bold; color: "#E0E0E0"
        }
    }

    // ========== 内容区域 ==========
    // ✅ 2026-03-22 [Phase 7.48.74.2]: 新增Flickable包裹，解决虚拟键盘遮挡输入框问题
    // 旧：ColumnLayout直接anchors到parent.bottom，无滚动能力
    // ✅ 2026-03-22 [Phase 7.48.74.2 fix]: 改用Flickable替代ScrollView，参照OutputDeviceSettingsPopup
    Flickable {
        id: paramScrollView
        anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; margins: 10 }
        clip: true
        contentWidth: width
        // ✅ 2026-03-22 [Phase 7.48.74.2 fix2]: 简化contentHeight计算
        // 旧：遍历children手动累加 + 700缓冲（过大导致滚动过多）
        // 新：使用implicitHeight + 合理缓冲（仅需覆盖键盘遮挡区域，约300px）
        contentHeight: contentArea.implicitHeight + 300
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        // 监控虚拟键盘隐藏时自动滚回顶部
        Connections {
            target: Qt.inputMethod
            function onVisibleChanged() {
                if (!Qt.inputMethod.visible) {
                    scrollAnimation.to = 0
                    scrollAnimation.start()
                }
            }
        }

        // 平滑滚动动画
        NumberAnimation {
            id: scrollAnimation
            target: paramScrollView
            property: "contentY"
            duration: 300
            easing.type: Easing.OutQuad
        }

        // ✅ 2026-03-22 [Phase 7.48.74.2 fix2]: 重写ensureVisible，精确计算滚动量
        // 旧：使用root.parent.height作为屏幕高度（错误，实际是Loader高度~600px）
        // 新：使用Qt.inputMethod.keyboardRectangle.y获取键盘顶部的窗口坐标
        function ensureVisible(item) {
            if (!item) return
            Qt.callLater(function() {
                var kbRect = Qt.inputMethod.keyboardRectangle
                if (kbRect.height <= 0) return  // 键盘未显示

                // 输入框的全局底部坐标（窗口坐标系）
                var itemGlobal = item.mapToItem(null, 0, 0)
                var itemGlobalBottom = itemGlobal.y + item.height

                // 键盘顶部的窗口坐标
                // Qt.inputMethod.keyboardRectangle 在窗口坐标系中
                var kbTop
                if (kbRect.y > 100) {
                    // keyboardRectangle.y 有效值（键盘从屏幕中间某处开始）
                    kbTop = kbRect.y
                } else {
                    // 备用：1080p全屏应用，键盘在底部
                    kbTop = 1080 - kbRect.height
                }

                // 安全底部 = 键盘顶部 - 候选词栏(50px) - 间距(10px)
                var safeBottom = kbTop - 60

                console.log("[BrakeConfigPanel] ensureVisible: itemBottom=" + itemGlobalBottom +
                            " kbRect.y=" + kbRect.y + " kbRect.h=" + kbRect.height +
                            " kbTop=" + kbTop + " safeBottom=" + safeBottom +
                            " contentY=" + paramScrollView.contentY)

                // 输入框已在安全区域内，不需要滚动
                if (itemGlobalBottom <= safeBottom) {
                    console.log("[BrakeConfigPanel] 输入框已可见，无需滚动")
                    return
                }

                // 精确计算需要滚动的距离 = 输入框底部超出安全区域的量
                var scrollNeeded = itemGlobalBottom - safeBottom
                var targetY = paramScrollView.contentY + scrollNeeded
                var maxScroll = Math.max(0, paramScrollView.contentHeight - paramScrollView.height)
                targetY = Math.min(targetY, maxScroll)

                console.log("[BrakeConfigPanel] 滚动: needed=" + scrollNeeded +
                            " targetY=" + targetY + " maxScroll=" + maxScroll)

                scrollAnimation.to = targetY
                scrollAnimation.start()
            })
        }

        ColumnLayout {
            id: contentArea
            width: paramScrollView.width
            spacing: 6

        // ========== 统一8列GridLayout：行0-5全部对齐 ==========
        GridLayout {
            Layout.fillWidth: true
            columns: 8
            columnSpacing: 8
            rowSpacing: 8

            // ---- 行0：使用状态(Switch) + 输出通道（与行1反馈通道对齐） ----
            Text { text: "制动器启用:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            Switch { id: enabledSwitch; checked: true }
            Text { text: "松闸输出通道:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight
                opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            DeviceInfo.CustomSpinBox { id: releaseOutputChannelSpin; Layout.preferredWidth: root.fldW; from: 0; to: 15; value: 0
                enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            Text { text: "抱闸输出通道:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight
                opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            DeviceInfo.CustomSpinBox { id: brakeOutputChannelSpin; Layout.preferredWidth: root.fldW; from: -1; to: 15; value: 0
                enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            Item { Layout.columnSpan: 2; Layout.fillWidth: true }

            // ---- 分隔线 ----
            Rectangle { Layout.columnSpan: 8; Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#334155" }

            // ---- 行1：松闸反馈 ----
            Text { text: "使用松闸反馈:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight
                opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            Switch { id: useReleaseFeedbackSwitch; checked: false; enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            Text { text: "反馈通道:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight
                opacity: (enabledSwitch.checked && useReleaseFeedbackSwitch.checked) ? 1.0 : 0.4 }
            DeviceInfo.CustomSpinBox { id: releasePositionChannelSpin; Layout.preferredWidth: root.fldW; from: 0; to: 15; value: 0
                enabled: enabledSwitch.checked && useReleaseFeedbackSwitch.checked; opacity: (enabledSwitch.checked && useReleaseFeedbackSwitch.checked) ? 1.0 : 0.4 }
            Text { text: "超时(秒):"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight
                opacity: (enabledSwitch.checked && useReleaseFeedbackSwitch.checked) ? 1.0 : 0.4 }
            DeviceInfo.CustomSpinBox { id: releaseTimeoutSpin; Layout.preferredWidth: root.fldW; from: 1; to: 60; value: 10
                enabled: enabledSwitch.checked && useReleaseFeedbackSwitch.checked; opacity: (enabledSwitch.checked && useReleaseFeedbackSwitch.checked) ? 1.0 : 0.4 }
            Item { Layout.columnSpan: 2; Layout.fillWidth: true }

            // ---- 行2：抱闸反馈 ----
            Text { text: "使用抱闸反馈:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight
                opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            Switch { id: useBrakeFeedbackSwitch; checked: false; enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            Text { text: "反馈通道:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight
                opacity: (enabledSwitch.checked && useBrakeFeedbackSwitch.checked) ? 1.0 : 0.4 }
            DeviceInfo.CustomSpinBox { id: brakePositionChannelSpin; Layout.preferredWidth: root.fldW; from: 0; to: 15; value: 0
                enabled: enabledSwitch.checked && useBrakeFeedbackSwitch.checked; opacity: (enabledSwitch.checked && useBrakeFeedbackSwitch.checked) ? 1.0 : 0.4 }
            Text { text: "超时(秒):"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight
                opacity: (enabledSwitch.checked && useBrakeFeedbackSwitch.checked) ? 1.0 : 0.4 }
            DeviceInfo.CustomSpinBox { id: brakeTimeoutSpin; Layout.preferredWidth: root.fldW; from: 1; to: 60; value: 10
                enabled: enabledSwitch.checked && useBrakeFeedbackSwitch.checked; opacity: (enabledSwitch.checked && useBrakeFeedbackSwitch.checked) ? 1.0 : 0.4 }
            Item { Layout.columnSpan: 2; Layout.fillWidth: true }

            // ---- 分隔线 ----
            Rectangle { Layout.columnSpan: 8; Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#334155" }

            // ---- 行3：抱闸保持 | 松闸保持 | 抱闸动作延时 | 抱闸释放延时 ----
            Text { text: "抱闸保持:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            DeviceInfo.CustomTextField { id: holdTimeField; text: "0"; Layout.preferredWidth: root.fldW; keyboardManager: root.keyboardManager; enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            Text { text: "松闸保持:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            DeviceInfo.CustomTextField { id: releaseTimeField; text: "0"; Layout.preferredWidth: root.fldW; keyboardManager: root.keyboardManager; enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            Text { text: "抱闸动作延时:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            DeviceInfo.CustomTextField { id: brakeDelayField; text: "0"; Layout.preferredWidth: root.fldW; keyboardManager: root.keyboardManager; enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            Text { text: "抱闸释放延时:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            DeviceInfo.CustomTextField { id: releaseDelayField; text: "0"; Layout.preferredWidth: root.fldW; keyboardManager: root.keyboardManager; enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4 }

            // ---- 行4：抱闸检测延时 | 抱闸故障延时 | 抱闸动作电流 | 抱闸释放电流 ----
            Text { text: "抱闸检测延时:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            DeviceInfo.CustomTextField { id: detectDelayField; text: "0"; Layout.preferredWidth: root.fldW; keyboardManager: root.keyboardManager; enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            Text { text: "抱闸故障延时:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            DeviceInfo.CustomTextField { id: faultDelayField; text: "0"; Layout.preferredWidth: root.fldW; keyboardManager: root.keyboardManager; enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            Text { text: "抱闸动作电流:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            DeviceInfo.CustomTextField { id: brakeCurrentField; text: "0"; Layout.preferredWidth: root.fldW; keyboardManager: root.keyboardManager; enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            Text { text: "抱闸释放电流:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            DeviceInfo.CustomTextField { id: releaseCurrentField; text: "0"; Layout.preferredWidth: root.fldW; keyboardManager: root.keyboardManager; enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4 }

            // ---- 行5：抱闸动作电压 | 抱闸释放电压 ----
            // ✅ 2026-03-22 [Phase 7.48.74.2]: 电压行独立（旧：与启动延时同行）
            Text { text: "抱闸动作电压:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            DeviceInfo.CustomTextField { id: brakeVoltageField; text: "0"; Layout.preferredWidth: root.fldW; keyboardManager: root.keyboardManager; enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            Text { text: "抱闸释放电压:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            DeviceInfo.CustomTextField { id: releaseVoltageField; text: "0"; Layout.preferredWidth: root.fldW; keyboardManager: root.keyboardManager; enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            Item { Layout.columnSpan: 4; Layout.fillWidth: true }

            // ---- 分隔线：电压与延时区域分割 ----
            // ✅ 2026-03-22 [Phase 7.48.74.2]: 新增分割线
            Rectangle { Layout.columnSpan: 8; Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#334155" }

            // ---- 行6：松闸启动延时 | 抱闸启动延时 ----
            // ✅ 2026-03-22 [Phase 7.48.74.2]: 启动延时独立行（旧：与电压同行）
            Text { text: "松闸启动延时:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            DeviceInfo.CustomTextField { id: releaseStartupDelayField; text: "1.0"; Layout.preferredWidth: root.fldW; keyboardManager: root.keyboardManager; enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            Text { text: "抱闸启动延时:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            DeviceInfo.CustomTextField { id: brakeStartupDelayField; text: "1.0"; Layout.preferredWidth: root.fldW; keyboardManager: root.keyboardManager; enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            Item { Layout.columnSpan: 4; Layout.fillWidth: true }

            // ---- 行7：松闸停止延时 | 抱闸停止延时 ----
            // ✅ 2026-03-22 [Phase 7.48.74.2]: 停止延时独立行
            Text { text: "松闸停止延时:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            DeviceInfo.CustomTextField { id: releaseStopDelayField; text: "1.0"; Layout.preferredWidth: root.fldW; keyboardManager: root.keyboardManager; enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            Text { text: "抱闸停止延时:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            DeviceInfo.CustomTextField { id: brakeStopDelayField; text: "1.0"; Layout.preferredWidth: root.fldW; keyboardManager: root.keyboardManager; enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            Item { Layout.columnSpan: 4; Layout.fillWidth: true }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#334155" }

        // ========== 行6：语音配置（3组：标签+输入框） ==========
        RowLayout {
            Layout.fillWidth: true; spacing: 8; opacity: enabledSwitch.checked ? 1.0 : 0.4
            Text { text: "松闸预警:"; font.pixelSize: root.lblFs; color: root.lblC }
            DeviceInfo.CustomTextField { id: releaseWarningVoiceField; Layout.fillWidth: true; text: "制动器" + (root.brakeIndex + 1) + "松闸"; readOnly: true; keyboardManager: root.keyboardManager; enabled: enabledSwitch.checked }
            Text { text: "松闸失败:"; font.pixelSize: root.lblFs; color: root.lblC }
            DeviceInfo.CustomTextField { id: releaseFailureVoiceField; Layout.fillWidth: true; text: "制动器" + (root.brakeIndex + 1) + "松闸失败"; readOnly: true; keyboardManager: root.keyboardManager; enabled: enabledSwitch.checked }
            Text { text: "抱闸失败:"; font.pixelSize: root.lblFs; color: root.lblC }
            DeviceInfo.CustomTextField { id: brakeFailureVoiceField; Layout.fillWidth: true; text: "制动器" + (root.brakeIndex + 1) + "抱闸失败"; readOnly: true; keyboardManager: root.keyboardManager; enabled: enabledSwitch.checked }
        }

        // ========== 行7：LED指示 + 操作按钮 ==========
        RowLayout {
            Layout.fillWidth: true; spacing: 15; opacity: enabledSwitch.checked ? 1.0 : 0.4
            // LED指示灯
            Row {
                spacing: 20
                Row {
                    spacing: 6
                    Rectangle { id: releaseLed; width: 16; height: 16; radius: 8; color: "#555"; anchors.verticalCenter: parent.verticalCenter
                        border.width: 1; border.color: "#333" }
                    Text { text: "松闸到位"; font.pixelSize: root.lblFs; color: root.lblC; anchors.verticalCenter: parent.verticalCenter }
                }
                Row {
                    spacing: 6
                    Rectangle { id: brakeLed; width: 16; height: 16; radius: 8; color: "#555"; anchors.verticalCenter: parent.verticalCenter
                        border.width: 1; border.color: "#333" }
                    Text { text: "抱闸到位"; font.pixelSize: root.lblFs; color: root.lblC; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            Item { Layout.fillWidth: true }
            // 操作按钮
            Button {
                id: releaseBtn; text: "松闸"; Layout.preferredWidth: 100; Layout.preferredHeight: 40
                font.pixelSize: 16; font.weight: Font.Bold
                background: Rectangle {
                    color: releaseBtn.pressed ? "#1a7a3a" : (releaseBtn.hovered ? "#2ecc71" : "#27ae60"); radius: 6
                    border.color: (root.focusSubArea === 3 && root.focusButtonIndex === 0) ? "#FFFFFF" : "transparent"
                    border.width: (root.focusSubArea === 3 && root.focusButtonIndex === 0) ? 3 : 0
                }
                contentItem: Text { text: releaseBtn.text; font: releaseBtn.font; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: {
                    if (!enabledSwitch.checked) return
                    // 播放松闸预警语音
                    if (typeof alarmPlayback !== "undefined") {
                        var audioPath = buildAudioPath(releaseWarningVoiceField.text)
                        alarmPlayback.playAlarm(releaseWarningVoiceField.text, releaseWarningVoiceField.text, audioPath, false, "count", 1, 0)
                    }
                    // 发送松闸MQTT命令：松闸通道=1
                    var relCh = releaseOutputChannelSpin.value
                    var topic = "belt_control/do/module1/cmd"
                    var cmd = JSON.stringify({"action": "set", "channel": relCh, "value": 1})
                    console.log("[BrakeConfigPanel] 松闸命令 通道:", relCh)
                    if (typeof mqttController !== "undefined") {
                        mqttController.publish(topic, cmd, 1, false)
                    }
                    if (useReleaseFeedbackSwitch.checked) { root.waitingForRelease = true; releaseTimeoutTimer.start() }
                }
            }
            Button {
                id: brakeBtn; text: "抱闸"; Layout.preferredWidth: 100; Layout.preferredHeight: 40
                font.pixelSize: 16; font.weight: Font.Bold
                background: Rectangle {
                    color: brakeBtn.pressed ? "#1a5276" : (brakeBtn.hovered ? "#3498db" : "#2980b9"); radius: 6
                    border.color: (root.focusSubArea === 3 && root.focusButtonIndex === 1) ? "#FFFFFF" : "transparent"
                    border.width: (root.focusSubArea === 3 && root.focusButtonIndex === 1) ? 3 : 0
                }
                contentItem: Text { text: brakeBtn.text; font: brakeBtn.font; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: {
                    if (!enabledSwitch.checked) return
                    // 发送抱闸MQTT命令：先关松闸通道，再开抱闸通道
                    var topic = "belt_control/do/module1/cmd"
                    var relCh = releaseOutputChannelSpin.value
                    var brkCh = brakeOutputChannelSpin.value
                    console.log("[BrakeConfigPanel] 抱闸命令 松闸通道:", relCh, "抱闸通道:", brkCh)
                    if (typeof mqttController !== "undefined") {
                        // 先关闭松闸
                        mqttController.publish(topic, JSON.stringify({"action": "set", "channel": relCh, "value": 0}), 1, false)
                        // 再开启抱闸（如果有独立通道）
                        if (brkCh >= 0) {
                            mqttController.publish(topic, JSON.stringify({"action": "set", "channel": brkCh, "value": 1}), 1, false)
                        }
                    }
                    if (useBrakeFeedbackSwitch.checked) { root.waitingForBrake = true; brakeTimeoutTimer.start() }
                }
            }
            Button {
                id: stopBtn; text: "停止"; Layout.preferredWidth: 100; Layout.preferredHeight: 40
                font.pixelSize: 16; font.weight: Font.Bold
                background: Rectangle {
                    color: stopBtn.pressed ? "#922b21" : (stopBtn.hovered ? "#e74c3c" : "#c0392b"); radius: 6
                    border.color: (root.focusSubArea === 3 && root.focusButtonIndex === 2) ? "#FFFFFF" : "transparent"
                    border.width: (root.focusSubArea === 3 && root.focusButtonIndex === 2) ? 3 : 0
                }
                contentItem: Text { text: stopBtn.text; font: stopBtn.font; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: {
                    releaseTimeoutTimer.stop(); brakeTimeoutTimer.stop()
                    root.waitingForRelease = false; root.waitingForBrake = false
                    // 停止：关闭所有通道
                    var topic = "belt_control/do/module1/cmd"
                    var relCh = releaseOutputChannelSpin.value
                    var brkCh = brakeOutputChannelSpin.value
                    console.log("[BrakeConfigPanel] 停止命令 松闸通道:", relCh, "抱闸通道:", brkCh)
                    if (typeof mqttController !== "undefined") {
                        mqttController.publish(topic, JSON.stringify({"action": "set", "channel": relCh, "value": 0}), 1, false)
                        if (brkCh >= 0) {
                            mqttController.publish(topic, JSON.stringify({"action": "set", "channel": brkCh, "value": 0}), 1, false)
                        }
                    }
                }
            }
        }

        // 填充剩余空间（防止底部空白把内容撑开）
        Item { Layout.fillHeight: true; Layout.maximumHeight: 10 }
    }
    }  // Flickable 结束

    // ========== 定时器 ==========
    Timer {
        id: releaseTimeoutTimer; interval: releaseTimeoutSpin.value * 1000; repeat: false
        onTriggered: {
            root.waitingForRelease = false
            console.log("[BrakeConfigPanel] 松闸反馈超时，自动停止")
            // 播放松闸失败语音
            if (typeof alarmPlayback !== "undefined") {
                var audioPath = buildAudioPath(releaseFailureVoiceField.text)
                alarmPlayback.playAlarm(releaseFailureVoiceField.text, releaseFailureVoiceField.text, audioPath, false, "count", 1, 0)
            }
            // 停止：关闭松闸通道
            var topic = "belt_control/do/module1/cmd"
            if (typeof mqttController !== "undefined") {
                mqttController.publish(topic, JSON.stringify({"action": "set", "channel": releaseOutputChannelSpin.value, "value": 0}), 1, false)
            }
        }
    }
    Timer {
        id: brakeTimeoutTimer; interval: brakeTimeoutSpin.value * 1000; repeat: false
        onTriggered: {
            root.waitingForBrake = false
            console.log("[BrakeConfigPanel] 抱闸反馈超时，自动停止")
            // 播放抱闸失败语音
            if (typeof alarmPlayback !== "undefined") {
                var audioPath = buildAudioPath(brakeFailureVoiceField.text)
                alarmPlayback.playAlarm(brakeFailureVoiceField.text, brakeFailureVoiceField.text, audioPath, false, "count", 1, 0)
            }
            // 停止：关闭所有通道
            var topic = "belt_control/do/module1/cmd"
            var brkCh = brakeOutputChannelSpin.value
            if (typeof mqttController !== "undefined") {
                mqttController.publish(topic, JSON.stringify({"action": "set", "channel": releaseOutputChannelSpin.value, "value": 0}), 1, false)
                if (brkCh >= 0) {
                    mqttController.publish(topic, JSON.stringify({"action": "set", "channel": brkCh, "value": 0}), 1, false)
                }
            }
        }
    }

    // ========== DI反馈连接 ==========
    Connections {
        target: typeof mqttController !== "undefined" ? mqttController : null
        function onBitChanged(reg, bit, val) {
            if (useReleaseFeedbackSwitch.checked && reg === 2 && bit === releasePositionChannelSpin.value) {
                releaseLed.color = val ? "#4CAF50" : "#555"
                if (val && root.waitingForRelease) { root.waitingForRelease = false; releaseTimeoutTimer.stop() }
            }
            if (useBrakeFeedbackSwitch.checked && reg === 2 && bit === brakePositionChannelSpin.value) {
                brakeLed.color = val ? "#4CAF50" : "#555"
                if (val && root.waitingForBrake) { root.waitingForBrake = false; brakeTimeoutTimer.stop() }
            }
        }
    }

    // ========== 导航焦点指示器（浮动矩形） ==========
    Rectangle {
        id: navFocusRect
        visible: root.focusSubArea === 2 && root.focusParamIndex >= 0
        color: "transparent"; border.color: "#FFFFFF"; border.width: 3; radius: 4; z: 100
        function updatePosition() {
            var fields = _paramFields()
            var idx = root.focusParamIndex
            if (idx >= 0 && idx < fields.length && fields[idx]) {
                var field = fields[idx]
                var pos = field.mapToItem(root, 0, 0)
                x = pos.x - 2; y = pos.y - 2; width = field.width + 4; height = field.height + 4
            }
        }
        Connections { target: root
            function onFocusParamIndexChanged() { navFocusRect.updatePosition() }
            function onFocusSubAreaChanged() { navFocusRect.updatePosition() }
        }
        Timer { id: focusUpdateTimer; interval: 50; onTriggered: navFocusRect.updatePosition() }
        Component.onCompleted: focusUpdateTimer.start()
    }

    // ========== 导航函数 ==========
    function _paramFields() {
        return [enabledSwitch, releaseOutputChannelSpin, brakeOutputChannelSpin,
                useReleaseFeedbackSwitch, releasePositionChannelSpin, releaseTimeoutSpin,
                useBrakeFeedbackSwitch, brakePositionChannelSpin, brakeTimeoutSpin,
                holdTimeField, releaseTimeField, brakeDelayField, releaseDelayField,
                detectDelayField, faultDelayField, brakeCurrentField, releaseCurrentField,
                brakeVoltageField, releaseVoltageField,
                releaseStartupDelayField, brakeStartupDelayField,
                releaseStopDelayField, brakeStopDelayField]
    }
    function getParamFieldCount() { return 23 }
    function triggerParamInput(paramIndex) {
        var fields = _paramFields()
        if (paramIndex >= 0 && paramIndex < fields.length) {
            var field = fields[paramIndex]
            // Switch控件用toggle而不是forceActiveFocus
            if (paramIndex === 0 || paramIndex === 3 || paramIndex === 6) {
                field.checked = !field.checked
            } else {
                field.forceActiveFocus()
                // ✅ 2026-03-22 [Phase 7.48.74.2]: 虚拟键盘弹出时自动滚动到输入框可见位置
                paramScrollView.ensureVisible(field)
            }
        }
    }
    function toggleUsageStatus() { enabledSwitch.checked = !enabledSwitch.checked }
    function triggerButton(btnIndex) {
        if (btnIndex === 0) releaseBtn.clicked()
        else if (btnIndex === 1) brakeBtn.clicked()
        else if (btnIndex === 2) stopBtn.clicked()
    }
    function buildAudioPath(voiceText) {
        return "/home/linaro/belt-control-data/audio/paddlespeech-fastspeech2_csmsc-spk0/" +
               systemConfig.machineNumber + "#PD/" + voiceText + ".wav"
    }

    // ========== 数据持久化 ==========
    function collectConfig() {
        return {
            "enabled": enabledSwitch.checked,
            "release_output_channel": releaseOutputChannelSpin.value,
            "brake_output_channel": brakeOutputChannelSpin.value,
            "use_release_feedback": useReleaseFeedbackSwitch.checked ? 1 : 0,
            "release_feedback_channel": releasePositionChannelSpin.value,
            "release_feedback_timeout": releaseTimeoutSpin.value,
            "use_brake_feedback": useBrakeFeedbackSwitch.checked ? 1 : 0,
            "brake_feedback_channel": brakePositionChannelSpin.value,
            "brake_feedback_timeout": brakeTimeoutSpin.value,
            "hold_time": parseFloat(holdTimeField.text) || 0,
            "release_time": parseFloat(releaseTimeField.text) || 0,
            "brake_delay": parseFloat(brakeDelayField.text) || 0,
            "release_delay": parseFloat(releaseDelayField.text) || 0,
            "detect_delay": parseFloat(detectDelayField.text) || 0,
            "fault_delay": parseFloat(faultDelayField.text) || 0,
            "brake_current": parseFloat(brakeCurrentField.text) || 0,
            "release_current": parseFloat(releaseCurrentField.text) || 0,
            "brake_voltage": parseFloat(brakeVoltageField.text) || 0,
            "release_voltage": parseFloat(releaseVoltageField.text) || 0,
            "release_warning_voice": releaseWarningVoiceField.text,
            "release_failure_voice": releaseFailureVoiceField.text,
            "brake_failure_voice": brakeFailureVoiceField.text,
            // ✅ 2026-03-21 [Phase 7.48.68]: 新增启动延时字段
            "release_startup_delay": parseFloat(releaseStartupDelayField.text) || 1.0,
            "brake_startup_delay": parseFloat(brakeStartupDelayField.text) || 1.0,
            // ✅ 2026-03-22 [Phase 7.48.74]: 新增独立停止延时字段
            "release_stop_delay": parseFloat(releaseStopDelayField.text) || 1.0,
            "brake_stop_delay": parseFloat(brakeStopDelayField.text) || 1.0
        }
    }
    function saveBrakeConfig() {
        var config = collectConfig()
        var success = deviceConfigMgr.saveBrakeConfig(root.deviceId, root.brakeIndex, config)
        console.log(success ? "[BrakeConfigPanel] 保存成功" : "[BrakeConfigPanel] 保存失败")
        return success
    }
    function loadBrakeConfig() {
        // 先重置所有UI到默认值，防止上一个制动器的值残留
        enabledSwitch.checked = true
        releaseOutputChannelSpin.value = 0
        brakeOutputChannelSpin.value = 0
        useReleaseFeedbackSwitch.checked = false
        releasePositionChannelSpin.value = 0
        releaseTimeoutSpin.value = 10
        useBrakeFeedbackSwitch.checked = false
        brakePositionChannelSpin.value = 0
        brakeTimeoutSpin.value = 10
        holdTimeField.text = "0"
        releaseTimeField.text = "0"
        brakeDelayField.text = "0"
        releaseDelayField.text = "0"
        detectDelayField.text = "0"
        faultDelayField.text = "0"
        brakeCurrentField.text = "0"
        releaseCurrentField.text = "0"
        brakeVoltageField.text = "0"
        releaseVoltageField.text = "0"
        // ✅ 2026-03-21 [Phase 7.48.68]: 新增启动延时默认值
        releaseStartupDelayField.text = "1.0"
        brakeStartupDelayField.text = "1.0"
        // ✅ 2026-03-22 [Phase 7.48.74]: 新增停止延时默认值
        releaseStopDelayField.text = "1.0"
        brakeStopDelayField.text = "1.0"

        var config = deviceConfigMgr.loadBrakeConfig(root.deviceId, root.brakeIndex)
        if (!config || Object.keys(config).length === 0) return false
        if (config.hasOwnProperty("release_output_channel")) releaseOutputChannelSpin.value = config["release_output_channel"]
        if (config.hasOwnProperty("brake_output_channel")) brakeOutputChannelSpin.value = config["brake_output_channel"]
        if (config.hasOwnProperty("use_release_feedback")) useReleaseFeedbackSwitch.checked = (config["use_release_feedback"] === 1)
        if (config.hasOwnProperty("release_feedback_channel")) releasePositionChannelSpin.value = config["release_feedback_channel"]
        if (config.hasOwnProperty("release_feedback_timeout")) releaseTimeoutSpin.value = config["release_feedback_timeout"]
        if (config.hasOwnProperty("use_brake_feedback")) useBrakeFeedbackSwitch.checked = (config["use_brake_feedback"] === 1)
        if (config.hasOwnProperty("brake_feedback_channel")) brakePositionChannelSpin.value = config["brake_feedback_channel"]
        if (config.hasOwnProperty("brake_feedback_timeout")) brakeTimeoutSpin.value = config["brake_feedback_timeout"]
        if (config.hasOwnProperty("hold_time")) holdTimeField.text = config["hold_time"].toString()
        if (config.hasOwnProperty("release_time")) releaseTimeField.text = config["release_time"].toString()
        if (config.hasOwnProperty("brake_delay")) brakeDelayField.text = config["brake_delay"].toString()
        if (config.hasOwnProperty("release_delay")) releaseDelayField.text = config["release_delay"].toString()
        if (config.hasOwnProperty("detect_delay")) detectDelayField.text = config["detect_delay"].toString()
        if (config.hasOwnProperty("fault_delay")) faultDelayField.text = config["fault_delay"].toString()
        if (config.hasOwnProperty("brake_current")) brakeCurrentField.text = config["brake_current"].toString()
        if (config.hasOwnProperty("release_current")) releaseCurrentField.text = config["release_current"].toString()
        if (config.hasOwnProperty("brake_voltage")) brakeVoltageField.text = config["brake_voltage"].toString()
        if (config.hasOwnProperty("release_voltage")) releaseVoltageField.text = config["release_voltage"].toString()
        if (config.hasOwnProperty("release_warning_voice")) releaseWarningVoiceField.text = config["release_warning_voice"]
        if (config.hasOwnProperty("release_failure_voice")) releaseFailureVoiceField.text = config["release_failure_voice"]
        if (config.hasOwnProperty("brake_failure_voice")) brakeFailureVoiceField.text = config["brake_failure_voice"]
        // ✅ 2026-03-21 [Phase 7.48.68]: 加载启动延时
        if (config.hasOwnProperty("release_startup_delay")) releaseStartupDelayField.text = config["release_startup_delay"].toString()
        if (config.hasOwnProperty("brake_startup_delay")) brakeStartupDelayField.text = config["brake_startup_delay"].toString()
        // ✅ 2026-03-22 [Phase 7.48.74]: 加载停止延时
        if (config.hasOwnProperty("release_stop_delay")) releaseStopDelayField.text = config["release_stop_delay"].toString()
        if (config.hasOwnProperty("brake_stop_delay")) brakeStopDelayField.text = config["brake_stop_delay"].toString()
        return true
    }
    Component.onCompleted: { loadBrakeConfig() }
    // 2026-03-14: 切换制动器时先保存当前配置再加载新配置
    property int _previousBrakeIndex: -1
    onBrakeIndexChanged: {
        if (_previousBrakeIndex >= 0) {
            // 保存上一个制动器的配置
            var prevConfig = collectConfig()
            deviceConfigMgr.saveBrakeConfig(root.deviceId, _previousBrakeIndex, prevConfig)
        }
        _previousBrakeIndex = brakeIndex
        loadBrakeConfig()
    }
}
