import QtQuick 2.15
import QtQuick.Controls 2.15

// ✅ 2026-02-10 [Phase 7.45.13]: 现代化按钮组件
// 基于 Tesla Dashboard 的设计，添加发光效果和平滑动画
Button {
    id: control

    property color buttonColor: Theme.accent
    property color hoverColor: Theme.lighter(buttonColor, 1.2)
    property color pressColor: Theme.darker(buttonColor, 1.2)
    property bool glowEnabled: true

    implicitWidth: 120
    implicitHeight: 40

    background: Rectangle {
        radius: Theme.radius
        color: control.pressed ? pressColor :
               control.hovered ? hoverColor : buttonColor

        Behavior on color {
            ColorAnimation {
                duration: Theme.animationDuration
                easing.type: Theme.animationEasing
            }
        }

        // 外层发光效果
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            color: "transparent"
            border.width: 1
            border.color: parent.color
            radius: parent.radius + 2
            opacity: control.hovered ? 0.5 : 0.2
            visible: control.glowEnabled

            Behavior on opacity {
                NumberAnimation { duration: Theme.animationDuration }
            }
        }

        // 内层光晕
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            color: "transparent"
            border.width: 1
            border.color: parent.color
            radius: parent.radius - 2
            opacity: control.hovered ? 0.3 : 0
            visible: control.glowEnabled

            Behavior on opacity {
                NumberAnimation { duration: Theme.animationDuration }
            }
        }
    }

    contentItem: Text {
        text: control.text
        font.pixelSize: Theme.fontSizeMedium
        font.family: Theme.fontFamily
        color: Theme.textPrimary
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    // 缩放动画
    scale: control.pressed ? 0.95 : 1.0

    Behavior on scale {
        NumberAnimation {
            duration: Theme.animationDurationFast
            easing.type: Theme.animationEasing
        }
    }
}
