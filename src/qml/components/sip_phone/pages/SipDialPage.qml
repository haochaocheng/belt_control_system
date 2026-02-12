import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5
import QtQuick.Window 6.5
import QtMultimedia 6.5
import BeltControl.SipPhone 1.0

// Dial page with number pad
Page {
    id: root

    // Local number state as fallback
    property string localNumber: ""

    // ✅ 来电铃声播放器（使用固定路径初始化，避免初始化失败）
    MediaPlayer {
        id: ringtone
        source: "file:///C:/Windows/Media/Ring01.wav"  // ✅ 使用固定的系统铃声路径初始化
        loops: MediaPlayer.Infinite
        audioOutput: ringtoneOutput

        Component.onCompleted: {
            console.log("✅ [RINGTONE] MediaPlayer created with system ringtone")
            // ✅ 延迟100ms后尝试加载自定义铃声，避免初始化时阻塞
            ringtoneLoadTimer.start()
        }

        onPlaybackStateChanged: {
            if (playbackState === MediaPlayer.PlayingState) {
                console.log("🔔 [RINGTONE] Playing ringtone")
            }
        }

        onErrorOccurred: function(error, errorString) {
            console.log("❌ [RINGTONE] Error:", error, errorString)
        }
    }

    AudioOutput {
        id: ringtoneOutput
        volume: 1.0
    }

    // ✅ 延迟加载自定义铃声的定时器
    Timer {
        id: ringtoneLoadTimer
        interval: 100
        running: false
        repeat: false
        onTriggered: {
            try {
                var customPath = SipPhoneManager.getRingtonePath()
                if (customPath && customPath !== "") {
                    ringtone.source = customPath
                    console.log("🔔 [RINGTONE] Loaded custom ringtone:", customPath)
                }
            } catch (error) {
                console.log("⚠️ [RINGTONE] Failed to load custom ringtone, using system default")
            }
        }
    }

    // ✅ 监听自定义铃声路径变化
    Connections {
        target: SipPhoneManager
        function onRingtonePathChanged(newPath) {
            console.log("🔔 [RINGTONE] Ringtone path changed:", newPath)
            if (newPath && newPath !== "") {
                ringtone.source = newPath
            }
        }
    }

    Component.onCompleted: {
        console.log("✅ ========================================")
        console.log("✅ SipDialPage loaded and ready!")
        console.log("✅ ========================================")
    }

    // Monitor C++ property changes
    Connections {
        target: SipPhoneManager
        function onCurrentNumberChanged(number) {
            console.log("C++ currentNumberChanged signal received:", number)
            root.localNumber = number
        }

        // ✅ DEBUG: Monitor isIncomingVideoCall changes
        function onIsIncomingVideoCallChanged() {
            console.log("🔍 [QML] isIncomingVideoCall changed to:", SipPhoneManager.isIncomingVideoCall)
            console.log("🔍 [QML] Current callStatus:", SipPhoneManager.callStatus)
        }

        // ✅ 来电铃声控制
        function onCallStatusChanged() {
            var status = SipPhoneManager.callStatus
            console.log("📞 [RINGTONE] Call status changed:", status)

            if (status.indexOf("来电") >= 0) {
                // 来电：播放铃声
                console.log("🔔 [RINGTONE] Incoming call detected - playing ringtone")
                ringtone.play()
            } else {
                // 其他状态（接听、挂断、通话中等）：停止铃声
                if (ringtone.playbackState === MediaPlayer.PlayingState) {
                    console.log("🔕 [RINGTONE] Call status changed - stopping ringtone")
                    ringtone.stop()
                }
            }
        }

        // ✅ 仅视频通话时自动启动 PJSIP 本地视频预览（不使用 Qt Camera）
        function onIsInCallChanged() {
            if (SipPhoneManager.isInCall && SipPhoneManager.isCurrentCallVideo && !videoPreviewButton.previewActive) {
                console.log("✅ Video call started - auto-starting PJSIP local video preview")
                SipPhoneManager.localVideoManager.startPreview()
                videoPreviewButton.previewActive = true
            } else if (!SipPhoneManager.isInCall && videoPreviewButton.previewActive) {
                console.log("✅ Call ended - auto-stopping PJSIP local video preview")
                SipPhoneManager.localVideoManager.stopPreview()
                videoPreviewButton.previewActive = false

                // ✅ 通话结束时停止铃声（以防万一）
                if (ringtone.playbackState === MediaPlayer.PlayingState) {
                    console.log("🔕 [RINGTONE] Call ended - stopping ringtone")
                    ringtone.stop()
                }
            }
        }
    }

    // Inline RisipButton component
    component RisipButton: Button {
        id: control
        property color buttonColor: "#2c3e50"
        property color hoverColor: "#34495e"
        property color pressColor: "#2980b9"
        property color textColor: "#ffffff"
        property color borderColor: "#00d4ff"
        property int borderWidth: 2
        property int buttonRadius: 10
        property bool isHovered: false

        // Make sure the button is clickable
        enabled: true

        background: Rectangle {
            color: control.pressed ? control.pressColor : (control.isHovered ? control.hoverColor : control.buttonColor)
            radius: control.buttonRadius
            border.color: control.borderColor
            border.width: control.borderWidth
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        contentItem: Text {
            text: control.text
            font: control.font
            color: control.textColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        HoverHandler {
            onHoveredChanged: control.isHovered = hovered
        }
    }

    background: Rectangle {
        color: "transparent"
    }

    // ✅ 使用Flickable实现可滚动页面，防止视频通话时底部被盖住
    Flickable {
        id: flickable
        anchors.fill: parent
        contentWidth: width  // 禁用横向滚动
        contentHeight: contentColumn.height  // 内容高度由ColumnLayout决定
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        // 添加滚动条
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        ColumnLayout {
            id: contentColumn
            width: flickable.width - 40  // Flickable的宽度减去margins
            x: 20  // 左边距
            spacing: 15

        // ✅ Video display area - Shows local preview or both local & remote during video calls
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 240
            spacing: 5
            // ✅ 只在视频通话或手动预览时显示，语音通话不显示
            visible: videoPreviewButton.previewActive || (SipPhoneManager.isInCall && SipPhoneManager.isCurrentCallVideo)

            // 本机视频预览区域 (Local Video)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 240
                color: "#000000"
                radius: 10
                border.color: "#00d4ff"
                border.width: 2
                // ✅ 只在视频通话或手动预览时显示，语音通话不显示
                visible: videoPreviewButton.previewActive || (SipPhoneManager.isInCall && SipPhoneManager.isCurrentCallVideo)

                // 标签
                Text {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: 8
                    text: "📹 本机"
                    font.pixelSize: 12
                    font.bold: true
                    color: "#00d4ff"
                    z: 10
                }

                // ✅ 自定义 VideoSinkItem - 完全嵌入在 QML 中显示视频
                VideoSinkItem {
                    id: videoDisplay
                    anchors.fill: parent
                    anchors.margins: 2

                    Component.onCompleted: {
                        console.log("✅ VideoSinkItem created for local preview")
                        // 连接到 PJSIP local video manager 的 video sink
                        if (SipPhoneManager && SipPhoneManager.localVideoManager) {
                            sink = SipPhoneManager.localVideoManager.videoSink
                            console.log("✅ VideoSinkItem connected to PJSIP local video sink")
                        } else {
                            console.log("❌ LocalVideoManager not available")
                        }
                    }
                }

                // 加载提示文字（初始显示，视频开始后会被覆盖）
                Text {
                    anchors.centerIn: parent
                    text: "正在启动摄像头..."
                    font.pixelSize: 14
                    color: "#7f8c8d"
                    horizontalAlignment: Text.AlignHCenter
                    z: -1  // 在视频下方，视频出现后会被遮住
                }

                // ✅ 关闭按钮 - 浮动在视频预览区域右上角
                // ⚠️ 视频通话期间不显示关闭按钮，因为摄像头必须持续工作才能发送视频给对方
                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 10
                    width: 80
                    height: 35
                    color: "#e74c3c"
                    radius: 6
                    border.color: "#c0392b"
                    border.width: 2
                    visible: !SipPhoneManager.isInCall  // ✅ 通话时隐藏关闭按钮

                    Text {
                        anchors.centerIn: parent
                        text: "关闭"
                        font.pixelSize: 14
                        font.bold: true
                        color: "white"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            console.log("✅ Stopping PJSIP local video preview via close button")
                            SipPhoneManager.localVideoManager.stopPreview()
                            videoPreviewButton.previewActive = false
                        }
                    }
                }
            }

            // 远端视频显示区域 (Remote Video) - 通话时显示
            Rectangle {
                id: remoteVideoArea
                Layout.fillWidth: true
                Layout.preferredHeight: 240
                color: "#000000"
                radius: 10
                border.color: "#ff6b35"
                border.width: 2
                visible: SipPhoneManager.isInCall && SipPhoneManager.remoteVideoManager.hasRemoteVideo

                // 标签
                Text {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: 8
                    text: "📹 对方"
                    font.pixelSize: 12
                    font.bold: true
                    color: "#ff6b35"
                    z: 10
                }

                // VideoSinkItem - 显示远端视频 (Qt Multimedia 方案，真正嵌入)
                VideoSinkItem {
                    id: remoteVideoSink
                    anchors.fill: parent
                    anchors.margins: 2

                    Component.onCompleted: {
                        console.log("✅ Remote VideoSinkItem created")
                        // 安全地连接到 remote video manager 的 video sink
                        if (SipPhoneManager && SipPhoneManager.remoteVideoManager) {
                            sink = SipPhoneManager.remoteVideoManager.videoSink
                            console.log("✅ Remote VideoSinkItem connected to video sink")
                        } else {
                            console.log("❌ RemoteVideoManager not available")
                        }
                    }
                }

                // 提示信息（仅在无视频时显示）
                Text {
                    anchors.centerIn: parent
                    text: "等待远端视频..."
                    font.pixelSize: 14
                    color: "#7f8c8d"
                    visible: !SipPhoneManager.remoteVideoManager.hasRemoteVideo
                    horizontalAlignment: Text.AlignHCenter
                    z: 1
                }
            }
        }

        // Phone number display
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            color: "#0f3460"
            radius: 10
            border.color: "#00d4ff"
            border.width: 2

            Text {
                id: numberDisplay
                anchors.centerIn: parent
                text: root.localNumber || "请输入号码"
                font.pixelSize: 32
                font.bold: true
                color: root.localNumber ? "#ffffff" : "#7f8c8d"

                // Debug output
                onTextChanged: {
                    console.log("Number display text changed to:", text)
                }
            }

            // Backspace button
            RisipButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 15
                width: 50
                height: 50
                visible: root.localNumber.length > 0

                buttonColor: "transparent"
                hoverColor: "#c0392b"
                borderColor: "#e74c3c"

                contentItem: Text {
                    text: "⌫"
                    font.pixelSize: 24
                    color: "#e74c3c"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    if (root.localNumber.length > 0) {
                        root.localNumber = root.localNumber.slice(0, -1)
                        SipPhoneManager.currentNumber = root.localNumber
                    }
                }
            }
        }

        // Call status panel (like risip CallPage)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            color: "#0f3460"
            radius: 10
            border.color: {
                if (SipPhoneManager.callStatus.indexOf("通话中") >= 0) return "#27ae60"
                if (SipPhoneManager.callStatus === "拨号中") return "#f39c12"
                if (SipPhoneManager.callStatus === "振铃中") return "#f39c12"
                if (SipPhoneManager.callStatus.indexOf("来电") >= 0) return "#e74c3c"
                return "#00d4ff"
            }
            border.width: 2
            // Show during dialing, ringing, incoming call, and in-call
            visible: SipPhoneManager.callStatus === "拨号中" ||
                     SipPhoneManager.callStatus === "振铃中" ||
                     SipPhoneManager.callStatus.indexOf("通话中") >= 0 ||
                     SipPhoneManager.callStatus.indexOf("来电") >= 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8

                // Status label (Connecting.., Ringing.., Connected!)
                Text {
                    text: {
                        if (SipPhoneManager.callStatus.indexOf("通话中") >= 0) return "✓ " + SipPhoneManager.callStatus
                        if (SipPhoneManager.callStatus === "拨号中") return "📞 拨号中..."
                        if (SipPhoneManager.callStatus === "振铃中") return "🔔 振铃中..."
                        if (SipPhoneManager.callStatus.indexOf("来电") >= 0) return "📲 " + SipPhoneManager.callStatus
                        return SipPhoneManager.callStatus
                    }
                    font.pixelSize: 16
                    font.bold: true
                    color: {
                        if (SipPhoneManager.callStatus.indexOf("通话中") >= 0) return "#27ae60"
                        if (SipPhoneManager.callStatus === "拨号中") return "#f39c12"
                        if (SipPhoneManager.callStatus === "振铃中") return "#f39c12"
                        if (SipPhoneManager.callStatus.indexOf("来电") >= 0) return "#e74c3c"
                        return "#00d4ff"
                    }
                    Layout.alignment: Qt.AlignHCenter
                }

                // Call duration
                Text {
                    text: formatDuration(SipPhoneManager.callDuration)
                    font.pixelSize: 32
                    font.bold: true
                    color: "#ffffff"
                    Layout.alignment: Qt.AlignHCenter
                    visible: SipPhoneManager.callStatus.indexOf("通话中") >= 0
                }

                // Call control buttons
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 15

                    // ✅ 视频来电：显示三个按钮（视频接听、语音接听、拒绝）
                    // 音频来电：显示一个按钮（接听）
                    // 通话中：只显示麦克风静音按钮

                    // 视频接听按钮（仅视频来电时显示）
                    RisipButton {
                        Layout.preferredWidth: 60
                        Layout.preferredHeight: 60
                        buttonRadius: 30
                        buttonColor: "#3498db"
                        hoverColor: "#2980b9"
                        borderWidth: 2
                        borderColor: "#00d4ff"
                        visible: {
                            var hasCallStatus = SipPhoneManager.callStatus.indexOf("来电") >= 0
                            var isVideo = SipPhoneManager.isIncomingVideoCall
                            console.log("🔍 [QML] Video Accept Button visibility check:")
                            console.log("    callStatus:", SipPhoneManager.callStatus, "→ hasCallStatus:", hasCallStatus)
                            console.log("    isIncomingVideoCall:", isVideo)
                            console.log("    → visible:", hasCallStatus && isVideo)
                            return hasCallStatus && isVideo
                        }

                        contentItem: Text {
                            text: "📹"
                            font.pixelSize: 24
                            color: "#ffffff"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            console.log("✅ Answering video call with video")
                            SipPhoneManager.answerCall()  // 接受视频
                        }
                    }

                    // 语音接听按钮（仅视频来电时显示）
                    RisipButton {
                        Layout.preferredWidth: 60
                        Layout.preferredHeight: 60
                        buttonRadius: 30
                        buttonColor: "#27ae60"
                        hoverColor: "#229954"
                        borderWidth: 2
                        borderColor: "#00ff88"
                        visible: SipPhoneManager.callStatus.indexOf("来电") >= 0 && SipPhoneManager.isIncomingVideoCall

                        contentItem: Text {
                            text: "📞"
                            font.pixelSize: 24
                            color: "#ffffff"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            console.log("✅ Answering video call as audio-only")
                            SipPhoneManager.answerCallAsAudio()  // 仅语音接听
                        }
                    }

                    // 普通接听按钮（仅音频来电时显示）
                    RisipButton {
                        Layout.preferredWidth: 60
                        Layout.preferredHeight: 60
                        buttonRadius: 30
                        buttonColor: "#27ae60"
                        borderWidth: 1
                        visible: SipPhoneManager.callStatus.indexOf("来电") >= 0 && !SipPhoneManager.isIncomingVideoCall

                        contentItem: Text {
                            text: "✓"
                            font.pixelSize: 28
                            font.bold: true
                            color: "#ffffff"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            console.log("✅ Answering audio call")
                            SipPhoneManager.answerCall()
                        }
                    }

                    // Mute microphone button (only during call)
                    RisipButton {
                        id: micMuteButton
                        Layout.preferredWidth: 45
                        Layout.preferredHeight: 45
                        buttonRadius: 22
                        buttonColor: micMuted ? "#e74c3c" : "#34495e"
                        hoverColor: micMuted ? "#cb4335" : "#2c3e50"
                        borderWidth: 1
                        visible: SipPhoneManager.callStatus.indexOf("通话中") >= 0

                        property bool micMuted: false

                        contentItem: Text {
                            text: micMuteButton.micMuted ? "🔇" : "🎤"
                            font.pixelSize: 20
                            color: "#ffffff"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            micMuted = !micMuted
                            SipPhoneManager.muteMicrophone(micMuted)
                        }
                    }

                    // 拒接按钮（仅来电时显示）
                    RisipButton {
                        Layout.preferredWidth: 60
                        Layout.preferredHeight: 60
                        buttonRadius: 30
                        buttonColor: "#e74c3c"
                        hoverColor: "#cb4335"
                        borderWidth: 2
                        borderColor: "#ff6b6b"
                        visible: SipPhoneManager.callStatus.indexOf("来电") >= 0

                        contentItem: Text {
                            text: "✗"
                            font.pixelSize: 28
                            font.bold: true
                            color: "#ffffff"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            SipPhoneManager.hangupCall()
                        }
                    }
                }
            }
        }

        // Dial pad
        Grid {
            Layout.alignment: Qt.AlignHCenter
            columns: 3
            spacing: 15

            Repeater {
                model: [
                    {num: "1", text: ""},
                    {num: "2", text: "ABC"},
                    {num: "3", text: "DEF"},
                    {num: "4", text: "GHI"},
                    {num: "5", text: "JKL"},
                    {num: "6", text: "MNO"},
                    {num: "7", text: "PQRS"},
                    {num: "8", text: "TUV"},
                    {num: "9", text: "WXYZ"},
                    {num: "*", text: ""},
                    {num: "0", text: "+"},
                    {num: "#", text: ""}
                ]

                delegate: Rectangle {
                    width: 100
                    height: 80
                    color: mouseArea.pressed ? "#2980b9" : (mouseArea.containsMouse ? "#34495e" : "#2c3e50")
                    radius: 10
                    border.color: "#00d4ff"
                    border.width: 2

                    Behavior on color { ColorAnimation { duration: 150 } }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        Text {
                            text: modelData.num
                            font.pixelSize: 28
                            font.bold: true
                            color: "#ffffff"
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: modelData.text
                            font.pixelSize: 10
                            color: "#95a5a6"
                            Layout.alignment: Qt.AlignHCenter
                            visible: modelData.text !== ""
                        }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                            console.log("Dial pad button clicked:", modelData.num)
                            // Update local state immediately for responsive UI
                            root.localNumber = root.localNumber + modelData.num
                            // Also update C++ backend using property assignment
                            SipPhoneManager.currentNumber = root.localNumber
                            console.log("Number updated to:", root.localNumber)
                        }
                    }
                }
            }
        }

        // Action buttons - Voice Call and Video Call
        RowLayout {
            Layout.fillWidth: true
            spacing: 15

            // Voice Call button (Audio only)
            RisipButton {
                id: voiceCallButton
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                enabled: SipPhoneManager.currentNumber.length > 0 && !SipPhoneManager.isInCall

                buttonColor: "#27ae60"
                hoverColor: "#229954"
                pressColor: "#1e7e34"
                borderColor: "#00ff88"

                contentItem: RowLayout {
                    spacing: 10

                    Text {
                        text: "📞"
                        font.pixelSize: 24
                        color: "white"
                    }

                    Text {
                        text: "语音通话"
                        font.pixelSize: 18
                        font.bold: true
                        color: "white"
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                onClicked: {
                    console.log("[DEBUG] Voice call button clicked")
                    SipPhoneManager.makeCall(SipPhoneManager.currentNumber)
                }
            }

            // Video Call button (Audio + Video)
            RisipButton {
                id: videoCallButton
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                enabled: SipPhoneManager.currentNumber.length > 0 && !SipPhoneManager.isInCall

                buttonColor: "#3498db"
                hoverColor: "#2980b9"
                pressColor: "#2471a3"
                borderColor: "#00d4ff"

                contentItem: RowLayout {
                    spacing: 10

                    Text {
                        text: "📹"
                        font.pixelSize: 24
                        color: "white"
                    }

                    Text {
                        text: "视频通话"
                        font.pixelSize: 18
                        font.bold: true
                        color: "white"
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                onClicked: {
                    console.log("[DEBUG] Video call button clicked")
                    SipPhoneManager.makeVideoCall(SipPhoneManager.currentNumber)
                }
            }
        }

        // Video preview button row (本机视频预览)
        RowLayout {
            Layout.fillWidth: true
            spacing: 15

            // Video preview toggle button
            RisipButton {
                id: videoPreviewButton
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                enabled: SipPhoneManager.isInitialized && !SipPhoneManager.isInCall

                property bool previewActive: false

                buttonColor: previewActive ? "#9b59b6" : "#34495e"
                hoverColor: previewActive ? "#8e44ad" : "#2c3e50"
                pressColor: previewActive ? "#7d3c98" : "#1c2833"
                borderColor: previewActive ? "#ff00ff" : "#00d4ff"

                contentItem: RowLayout {
                    spacing: 10

                    Text {
                        text: videoPreviewButton.previewActive ? "📷" : "🎥"
                        font.pixelSize: 24
                        color: "white"
                    }

                    Text {
                        text: videoPreviewButton.previewActive ? "停止预览" : "本机预览"
                        font.pixelSize: 18
                        font.bold: true
                        color: "white"
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                onClicked: {
                    if (videoPreviewButton.previewActive) {
                        console.log("✅ Stopping PJSIP local video preview (embedded in SIP interface)")
                        // Use PJSIP preview (fully embedded in QML)
                        SipPhoneManager.localVideoManager.stopPreview()
                        videoPreviewButton.previewActive = false
                    } else {
                        console.log("✅ Starting PJSIP local video preview (embedded in SIP interface)")
                        // Use PJSIP preview (fully embedded in QML)
                        SipPhoneManager.localVideoManager.startPreview()
                        videoPreviewButton.previewActive = true
                    }
                }
            }
        }

        // Hangup button row
        RowLayout {
            Layout.fillWidth: true
            spacing: 15

            // Hang up button (only show during call)
            RisipButton {
                id: hangUpButton
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                visible: SipPhoneManager.isInCall  // ✅ 只在通话中显示

                buttonColor: "#e74c3c"
                hoverColor: "#cb4335"
                pressColor: "#c0392b"
                borderColor: "#ff5555"

                contentItem: RowLayout {
                    spacing: 10

                    Text {
                        text: "📵"
                        font.pixelSize: 24
                        color: "white"
                    }

                    Text {
                        text: "挂断"
                        font.pixelSize: 18
                        font.bold: true
                        color: "white"
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                onClicked: {
                    SipPhoneManager.hangupCall()
                }
            }
        }

        // ✅ 底部间距，确保最后的按钮不会被SIP窗口底部遮挡
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 30  // 底部留出30像素空白
        }

        }  // ColumnLayout 结束
    }  // Flickable 结束

    // Format duration from seconds to MM:SS
    function formatDuration(seconds) {
        var mins = Math.floor(seconds / 60)
        var secs = seconds % 60
        return mins.toString().padStart(2, '0') + ":" + secs.toString().padStart(2, '0')
    }
}
