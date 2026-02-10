import QtQuick 2.15
import Qt5Compat.GraphicalEffects

// ✅ 2026-02-10 [Phase 7.45.13]: 发光 LED 指示灯组件
// 基于 industrial-controls 和 Qt-HMI 的设计，添加发光和闪烁效果
Rectangle {
    id: root

    property bool isActive: false
    property color activeColor: Theme.success
    property color inactiveColor: Theme.textDisabled
    property int glowRadius: Theme.glowRadius
    property bool blinkEnabled: false
    property int blinkDuration: 800

    width: 20
    height: 20
    radius: width / 2
    color: isActive ? activeColor : inactiveColor

    Behavior on color {
        ColorAnimation {
            duration: Theme.animationDuration
            easing.type: Theme.animationEasing
        }
    }

    // 发光效果
    layer.enabled: true
    layer.effect: Glow {
        radius: isActive ? root.glowRadius : 0
        samples: Theme.glowSamples
        color: root.color

        Behavior on radius {
            NumberAnimation { duration: Theme.animationDuration }
        }
    }

    // 闪烁动画（可选）
    SequentialAnimation on opacity {
        running: isActive && blinkEnabled
        loops: Animation.Infinite
        NumberAnimation {
            from: 1.0
            to: 0.6
            duration: root.blinkDuration
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            from: 0.6
            to: 1.0
            duration: root.blinkDuration
            easing.type: Easing.InOutQuad
        }
    }

    // 光晕效果（3层）
    Rectangle {
        anchors.centerIn: parent
        width: parent.width + 8
        height: parent.height + 8
        radius: (parent.width + 8) / 2
        color: "transparent"
        border.width: 2
        border.color: parent.color
        opacity: isActive ? 0.5 : 0
        visible: isActive

        Behavior on opacity {
            NumberAnimation { duration: Theme.animationDuration }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width + 16
        height: parent.height + 16
        radius: (parent.width + 16) / 2
        color: "transparent"
        border.width: 1
        border.color: parent.color
        opacity: isActive ? 0.3 : 0
        visible: isActive

        Behavior on opacity {
            NumberAnimation { duration: Theme.animationDuration }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width + 24
        height: parent.height + 24
        radius: (parent.width + 24) / 2
        color: "transparent"
        border.width: 1
        border.color: parent.color
        opacity: isActive ? 0.1 : 0
        visible: isActive

        Behavior on opacity {
            NumberAnimation { duration: Theme.animationDuration }
        }
    }
}
