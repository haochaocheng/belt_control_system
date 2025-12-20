import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.15

/**
 * 视频通话窗口 - 科技感设计
 *
 * 功能：
 * - 远程视频大屏显示（主视频）
 * - 本地视频预览（画中画，右下角）
 * - 视频控制按钮（摄像头开关、挂断等）
 * - 通话信息显示
 */
Item {
    id: root
    width: 1280
    height: 720

    property var videoCallManager: null
    property string remoteName: "对方"
    property string callDuration: "00:00"
    property bool videoEnabled: videoCallManager ? videoCallManager.videoEnabled : false
    property bool inCall: false

    // 背景 - 深色科技风
    Rectangle {
        anchors.fill: parent
        color: "#0a0e27"  // 深蓝黑色背景
    }

    // 远程视频区域（主视频）
    Item {
        id: remoteVideoContainer
        anchors.fill: parent

        // 视频占位符（无视频时显示）
        Rectangle {
            id: remotePlaceholder
            anchors.fill: parent
            color: "#1a1e3a"
            visible: !inCall || !videoEnabled

            // 中央图标
            Item {
                anchors.centerIn: parent
                width: 200
                height: 200

                // 圆形背景光晕
                Rectangle {
                    id: glowCircle
                    anchors.centerIn: parent
                    width: 180
                    height: 180
                    radius: 90
                    color: "#6366f1"
                    opacity: 0.3

                    // 呼吸动画
                    SequentialAnimation on opacity {
                        running: true
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.5; duration: 2000; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 0.3; duration: 2000; easing.type: Easing.InOutQuad }
                    }
                }

                // 用户头像图标
                Text {
                    anchors.centerIn: parent
                    text: "\uf2bd"  // FontAwesome user-circle
                    font.family: "Font Awesome 5 Free"
                    font.pixelSize: 120
                    color: "#8b5cf6"
                }
            }

            // 状态文字
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.verticalCenter
                anchors.topMargin: 140
                text: inCall ? "等待对方开启视频..." : "等待视频通话..."
                font.pixelSize: 20
                font.family: "Microsoft YaHei"
                color: "#a5b4fc"
            }
        }

        // 远程视频窗口
        Rectangle {
            id: remoteVideoWindow
            anchors.fill: parent
            color: "#000000"
            visible: inCall && videoEnabled

            // VideoRenderer 将在这里显示远程视频
            // 通过 VideoCallManager 管理

            // 视频加载指示器
            BusyIndicator {
                anchors.centerIn: parent
                running: visible
                visible: remoteVideoWindow.visible && !remoteVideoReady
                width: 80
                height: 80

                // 自定义颜色
                contentItem: Item {
                    implicitWidth: 80
                    implicitHeight: 80

                    Item {
                        id: busyItem
                        width: parent.width
                        height: parent.height
                        opacity: parent.parent.running ? 1 : 0

                        RotationAnimator {
                            target: busyItem
                            running: parent.parent.running
                            from: 0
                            to: 360
                            loops: Animation.Infinite
                            duration: 1500
                        }

                        Repeater {
                            model: 12
                            Rectangle {
                                x: busyItem.width / 2 - width / 2
                                y: busyItem.height / 2 - height / 2
                                width: busyItem.width / 10
                                height: busyItem.height / 4
                                radius: width / 2
                                color: "#6366f1"
                                opacity: 1.0 - index / 12
                                transform: [
                                    Translate { y: -busyItem.height * 0.35 },
                                    Rotation {
                                        angle: index * 30
                                        origin.x: width / 2
                                        origin.y: busyItem.height / 2
                                    }
                                ]
                            }
                        }
                    }
                }
            }

            property bool remoteVideoReady: false
        }
    }

    // 本地视频预览（画中画 - 右下角）
    Item {
        id: localVideoContainer
        anchors.right: parent.right
        anchors.bottom: controlBar.top
        anchors.margins: 20
        width: 240
        height: 180
        visible: videoEnabled

        // 背景卡片效果
        Rectangle {
            anchors.fill: parent
            color: "#1e293b"
            radius: 12
            border.color: "#334155"
            border.width: 2

            // 内阴影效果
            layer.enabled: true
            layer.effect: DropShadow {
                transparentBorder: true
                horizontalOffset: 0
                verticalOffset: 4
                radius: 12.0
                samples: 17
                color: "#80000000"
            }
        }

        // 本地视频窗口
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            color: "#000000"
            radius: 10

            // VideoRenderer 将在这里显示本地视频
            // 通过 VideoCallManager 管理

            // 占位符
            Item {
                anchors.centerIn: parent
                width: parent.width * 0.8
                height: parent.height * 0.8
                visible: !localVideoReady

                Text {
                    anchors.centerIn: parent
                    text: "\uf03d"  // FontAwesome video-camera
                    font.family: "Font Awesome 5 Free"
                    font.pixelSize: 48
                    color: "#475569"
                }
            }

            property bool localVideoReady: false
        }

        // 标签
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 8
            width: labelText.width + 16
            height: 24
            radius: 12
            color: "#6366f1"
            opacity: 0.9

            Text {
                id: labelText
                anchors.centerIn: parent
                text: "本地"
                font.pixelSize: 12
                font.family: "Microsoft YaHei"
                font.bold: true
                color: "#ffffff"
            }
        }

        // 拖拽功能（可选）
        MouseArea {
            anchors.fill: parent
            drag.target: localVideoContainer
            drag.axis: Drag.XAndYAxis
            drag.minimumX: 20
            drag.maximumX: root.width - localVideoContainer.width - 20
            drag.minimumY: 20
            drag.maximumY: root.height - localVideoContainer.height - controlBar.height - 40
            cursorShape: Qt.SizeAllCursor
        }
    }

    // 顶部信息栏
    Rectangle {
        id: topBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 80
        color: "#1e293b"
        opacity: 0.95

        // 渐变底部边框
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#00000000" }
                GradientStop { position: 0.5; color: "#6366f1" }
                GradientStop { position: 1.0; color: "#00000000" }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            // 对方信息
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: remoteName
                    font.pixelSize: 24
                    font.family: "Microsoft YaHei"
                    font.bold: true
                    color: "#ffffff"
                }

                RowLayout {
                    spacing: 8

                    // 通话时长
                    Rectangle {
                        width: durationText.width + 12
                        height: 24
                        radius: 12
                        color: "#10b981"

                        Text {
                            id: durationText
                            anchors.centerIn: parent
                            text: callDuration
                            font.pixelSize: 12
                            font.family: "Consolas"
                            font.bold: true
                            color: "#ffffff"
                        }
                    }

                    // 视频质量指示器
                    RowLayout {
                        spacing: 4

                        Rectangle {
                            width: 4
                            height: 12
                            radius: 2
                            color: "#10b981"
                        }
                        Rectangle {
                            width: 4
                            height: 16
                            radius: 2
                            color: "#10b981"
                        }
                        Rectangle {
                            width: 4
                            height: 20
                            radius: 2
                            color: "#10b981"
                        }

                        Text {
                            text: "高清"
                            font.pixelSize: 12
                            font.family: "Microsoft YaHei"
                            color: "#10b981"
                        }
                    }
                }
            }

            // 加密指示
            Rectangle {
                width: encryptIcon.width + 16
                height: 32
                radius: 16
                color: "#334155"

                RowLayout {
                    id: encryptIcon
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "\uf023"  // FontAwesome lock
                        font.family: "Font Awesome 5 Free"
                        font.pixelSize: 14
                        color: "#10b981"
                    }

                    Text {
                        text: "加密通话"
                        font.pixelSize: 12
                        font.family: "Microsoft YaHei"
                        color: "#94a3b8"
                    }
                }
            }
        }
    }

    // 底部控制栏
    Rectangle {
        id: controlBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 100
        color: "#1e293b"
        opacity: 0.95

        // 渐变顶部边框
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#00000000" }
                GradientStop { position: 0.5; color: "#6366f1" }
                GradientStop { position: 1.0; color: "#00000000" }
            }
        }

        RowLayout {
            anchors.centerIn: parent
            spacing: 24

            // 切换摄像头按钮
            VideoControlButton {
                iconText: "\uf021"  // sync/refresh
                label: "切换"
                buttonColor: "#334155"
                onClicked: {
                    if (videoCallManager) {
                        videoCallManager.toggleCamera()
                    }
                }
            }

            // 摄像头开关
            VideoControlButton {
                iconText: videoEnabled ? "\uf03d" : "\uf video-slash"
                label: videoEnabled ? "关闭摄像头" : "开启摄像头"
                buttonColor: videoEnabled ? "#334155" : "#dc2626"
                onClicked: {
                    if (videoCallManager) {
                        videoCallManager.videoEnabled = !videoCallManager.videoEnabled
                    }
                }
            }

            // 挂断按钮（红色）
            VideoControlButton {
                iconText: "\uf3dd"  // phone-slash
                label: "挂断"
                buttonColor: "#dc2626"
                iconSize: 28
                buttonSize: 70
                onClicked: {
                    // 触发挂断
                    root.hangupCall()
                }
            }

            // 静音按钮
            VideoControlButton {
                iconText: "\uf6a9"  // microphone-slash
                label: "静音"
                buttonColor: "#334155"
                onClicked: {
                    // 触发静音
                }
            }

            // 更多选项
            VideoControlButton {
                iconText: "\uf142"  // ellipsis-v
                label: "更多"
                buttonColor: "#334155"
                onClicked: {
                    // 显示更多选项菜单
                }
            }
        }
    }

    // 信号
    signal hangupCall()

    // 函数
    function startVideoCall() {
        if (videoCallManager) {
            // 通过 SipPhoneManager 获取当前通话 ID
            // videoCallManager.startVideoCall(callId)
        }
        inCall = true
    }

    function stopVideoCall() {
        if (videoCallManager) {
            videoCallManager.stopVideoCall()
        }
        inCall = false
    }

    Component.onCompleted: {
        console.log("VideoCallWindow: Initialized")
    }
}
