import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5
import QtQuick.Window 2.15
import QtQuick.VirtualKeyboard 6.5

// Independent SIP Phone Window
Window {
    id: sipWindow
    width: 800
    height: 900
    title: "SIP 语音电话"
    color: "#1a1a2e"

    // Normal window with standard controls
    flags: Qt.Window

    // Center on screen
    Component.onCompleted: {
        x = (Screen.width - width) / 2
        y = (Screen.height - height) / 2
    }

    // Main container
    Rectangle {
        anchors.fill: parent
        color: "#1a1a2e"

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Custom title bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: "#0f3460"
                z: 100

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    // Title
                    Text {
                        text: "📞 SIP 语音电话"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#00d4ff"
                        Layout.fillWidth: true
                    }

                    // Minimize button
                    Button {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30

                        background: Rectangle {
                            color: parent.pressed ? "#34495e" : (parent.hovered ? "#2c3e50" : "transparent")
                            radius: 5
                        }

                        contentItem: Text {
                            text: "━"
                            font.pixelSize: 16
                            font.bold: true
                            color: "#ffffff"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            sipWindow.showMinimized()
                        }
                    }

                    // Close button
                    Button {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30

                        background: Rectangle {
                            color: parent.pressed ? "#c0392b" : (parent.hovered ? "#e74c3c" : "transparent")
                            radius: 5
                        }

                        contentItem: Text {
                            text: "✕"
                            font.pixelSize: 16
                            font.bold: true
                            color: "#ffffff"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            sipWindow.close()
                        }
                    }
                }

                // Make title bar draggable
                MouseArea {
                    anchors.fill: parent
                    property point lastMousePos: Qt.point(0, 0)

                    onPressed: {
                        lastMousePos = Qt.point(mouseX, mouseY)
                    }

                    onMouseXChanged: {
                        if (pressed) {
                            sipWindow.x += (mouseX - lastMousePos.x)
                        }
                    }

                    onMouseYChanged: {
                        if (pressed) {
                            sipWindow.y += (mouseY - lastMousePos.y)
                        }
                    }
                }
            }

            // Load the main SIP page
            SipMainPage {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }

    // ✅ CRITICAL: SipPhoneWindow 是独立 Window，必须有自己的 keyboardOverlay 和 InputPanel
    MouseArea {
        id: keyboardOverlay
        parent: Overlay.overlay
        anchors.left: parent ? parent.left : undefined
        anchors.right: parent ? parent.right : undefined
        anchors.top: parent ? parent.top : undefined
        height: parent ? (parent.height - Qt.inputMethod.keyboardRectangle.height) : 0
        z: 500000  // 高于 Dialog 但低于 InputPanel
        visible: Qt.inputMethod.visible
        enabled: true
        propagateComposedEvents: true

        Component.onCompleted: {
            console.log("=========================================")
            console.log("🔥🔥🔥 SIP WINDOW OVERLAY VERSION: 2025-12-18-20:45 🔥🔥🔥")
            console.log("🛡️ [SIP keyboardOverlay] Initialized")
            console.log("   - z-index:", z)
            console.log("   - enabled:", enabled)
            console.log("   - propagateComposedEvents:", propagateComposedEvents)
            console.log("=========================================")
        }

        onVisibleChanged: {
            if (visible) {
                console.log("=====================================")
                console.log("🛡️ [SIP keyboardOverlay] Visible TRUE")
                console.log("   - Height:", height)
                console.log("   - z:", z, "enabled:", enabled)
                console.log("=====================================")
            }
        }

        onPressed: function(mouse) {
            console.log("=====================================")
            console.log("🛡️🛡️🛡️ [SIP keyboardOverlay] 👇 PRESSED")
            console.log("   - Position:", mouse.x, mouse.y)
            console.log("   - mouse.accepted BEFORE:", mouse.accepted)
            mouse.accepted = false
            console.log("   - mouse.accepted AFTER:", mouse.accepted)
            console.log("=====================================")
        }

        onClicked: function(mouse) {
            console.log("=====================================")
            console.log("🛡️🛡️🛡️ [SIP keyboardOverlay] 🖱️ CLICKED")
            console.log("   - Position:", mouse.x, mouse.y)
            console.log("   ✅ Closing keyboard now!")

            Qt.inputMethod.commit()
            Qt.inputMethod.hide()

            mouse.accepted = true
            console.log("   - Keyboard closed")
            console.log("=====================================")
        }
    }

    // ✅ CRITICAL: 独立 Window 需要自己的 InputPanel
    InputPanel {
        id: inputPanel
        parent: Overlay.overlay
        width: sipWindow.width
        x: 0
        y: active ? sipWindow.height - height : sipWindow.height
        z: 1000000  // 高于 keyboardOverlay
        visible: active

        Component.onCompleted: {
            console.log("=========================================")
            console.log("🔥🔥🔥 SIP InputPanel VERSION: 2025-12-18-20:45 🔥🔥🔥")
            console.log("⌨️ [SIP InputPanel] Initialized")
            console.log("   - z-index:", z)
            console.log("   - width:", width)
            console.log("=========================================")
        }

        onActiveChanged: {
            console.log("⌨️ [SIP InputPanel] Active:", active, "z:", z)
        }
    }
}
