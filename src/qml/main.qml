import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.VirtualKeyboard 6.5
import Qt5Compat.GraphicalEffects
import "components/sip_phone"

ApplicationWindow {
    id: root
    visible: true
    width: 1920
    height: 1080
    title: "Belt Control System"

    // Overlay to detect clicks outside keyboard - only above the keyboard area
    MouseArea {
        id: keyboardOverlay
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: parent.height - Qt.inputMethod.keyboardRectangle.height
        z: 98
        visible: inputPanel.active
        propagateComposedEvents: true  // 允许事件传播到下层组件

        onVisibleChanged: {
            if (visible) {
                console.log("KeyboardOverlay MouseArea:")
                console.log("  Height:", height)
                console.log("  Parent height:", parent.height)
                console.log("  Keyboard height:", Qt.inputMethod.keyboardRectangle.height)
            }
        }

        onClicked: function(mouse) {
            // 检查是否点击在右上角的 VoIP 按钮区域 (假设按钮在右上角 100x100 区域)
            var voipButtonArea = {
                x: parent.width - 120,  // 右边距 20 + 按钮宽度 80 + 边距 20
                y: 0,
                width: 120,
                height: 120
            };

            if (mouse.x >= voipButtonArea.x && mouse.x <= parent.width &&
                mouse.y >= voipButtonArea.y && mouse.y <= voipButtonArea.height) {
                console.log("Clicked on VoIP button area, propagating event")
                mouse.accepted = false  // 不接受此事件，让它传播到下层
                return
            }

            console.log("Clicked outside keyboard at y:", mouse.y)
            // Click outside keyboard to close it
            Qt.inputMethod.commit()
            Qt.inputMethod.hide()
        }
    }

    App {
        id: mainApp
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: inputPanel.top
        z: 1
    }

    // Qt Official Virtual Keyboard - Must be on top of everything including Popups
    // Using Overlay.overlay as parent to ensure keyboard is above all Popups
    Loader {
        id: keyboardLoader
        active: Qt.inputMethod.visible
        sourceComponent: Item {
            parent: Overlay.overlay
            anchors.fill: parent
            z: 100000

            InputPanel {
                id: inputPanel
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
            }

            // Close button for virtual keyboard
            Button {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: inputPanel.height - 10
                anchors.rightMargin: 10
                width: 50
                height: 50
                visible: true

                background: Rectangle {
                    color: parent.pressed ? "#c0392b" : "#e74c3c"
                    radius: 25
                    border.color: "#00d4ff"
                    border.width: 2
                }

                contentItem: Text {
                    text: "×"
                    color: "white"
                    font.pixelSize: 32
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    Qt.inputMethod.hide()
                }
            }
        }
    }

    // Dummy InputPanel reference for anchors
    Item {
        id: inputPanel
        anchors.bottom: parent.bottom
        height: Qt.inputMethod.keyboardRectangle.height
        width: parent.width
    }

    // VoIP Button - Must be at top level to avoid being blocked by keyboard overlay
    Button {
        id: sipPhoneButton
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 20
        anchors.rightMargin: 20
        width: 80
        height: 80
        z: 999  // High z-index to be above keyboard overlay

        property bool isHovered: false

        background: Rectangle {
            color: sipPhoneButton.pressed ? "#1e7e34" : (sipPhoneButton.isHovered ? "#27ae60" : "#218838")
            radius: 40
            border.color: "#00ff88"
            border.width: 3

            // Glow effect
            Rectangle {
                anchors.fill: parent
                anchors.margins: -5
                color: "transparent"
                border.color: "#00ff88"
                border.width: 2
                radius: 45
                opacity: 0.5
                z: -1
            }

            // Pulsing animation
            SequentialAnimation on opacity {
                running: true
                loops: Animation.Infinite
                NumberAnimation { from: 0.8; to: 1.0; duration: 1000; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 1.0; to: 0.8; duration: 1000; easing.type: Easing.InOutQuad }
            }
        }

        contentItem: Text {
            text: "📞"
            font.pixelSize: 40
            color: "white"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        onClicked: {
            // Open SIP phone popup
            console.log("SIP button clicked, opening SIP popup...")
            sipPopup.open()
        }

        HoverHandler {
            onHoveredChanged: sipPhoneButton.isHovered = hovered
        }

        // Tooltip
        ToolTip {
            visible: sipPhoneButton.isHovered
            text: "SIP 语音电话"
            delay: 500

            background: Rectangle {
                color: "#2c3e50"
                radius: 5
                border.color: "#00d4ff"
                border.width: 1
            }

            contentItem: Text {
                text: parent.text
                color: "#00d4ff"
                font.pixelSize: 12
            }
        }
    }

    // SIP Phone Popup
    Popup {
        id: sipPopup
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: Math.min(800, parent.width * 0.85)
        height: parent.height * 0.9
        modal: true
        closePolicy: Popup.CloseOnEscape
        z: 10000  // Very high z-index

        onOpened: {
            console.log("SIP Popup opened successfully")
            console.log("Popup size:", width, "x", height)
        }

        onClosed: {
            console.log("SIP Popup closed")
        }

        background: Rectangle {
            color: "#1a1a2e"
            radius: 15
            border.color: "#00d4ff"
            border.width: 2

            // Shadow effect
            layer.enabled: true
            layer.effect: DropShadow {
                transparentBorder: true
                horizontalOffset: 0
                verticalOffset: 4
                radius: 16
                samples: 33
                color: "#80000000"
            }
        }

        SipMainPage {
            anchors.fill: parent
        }

        // Close button
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 15
            anchors.rightMargin: 15
            width: 40
            height: 40
            radius: 20
            color: closeMouseArea.containsMouse ? "#e74c3c" : "#c0392b"
            z: 1000

            Text {
                anchors.centerIn: parent
                text: "✕"
                font.pixelSize: 20
                font.bold: true
                color: "white"
            }

            MouseArea {
                id: closeMouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: sipPopup.close()
            }
        }
    }
}
