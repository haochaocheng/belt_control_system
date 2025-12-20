import QtQuick 2.15
import QtQuick.Controls 2.15
import QtGraphicalEffects 1.15

/**
 * 视频控制按钮 - 圆形图标按钮
 */
Item {
    id: root
    width: buttonSize + 60
    height: buttonSize + 40

    property string iconText: "\uf03d"  // FontAwesome icon
    property string label: "按钮"
    property color buttonColor: "#334155"
    property int iconSize: 24
    property int buttonSize: 60
    property bool enabled: true

    signal clicked()

    Column {
        anchors.centerIn: parent
        spacing: 8

        // 圆形按钮
        Rectangle {
            id: button
            width: root.buttonSize
            height: root.buttonSize
            radius: root.buttonSize / 2
            color: buttonColor
            anchors.horizontalCenter: parent.horizontalCenter

            // 光晕效果
            layer.enabled: true
            layer.effect: DropShadow {
                transparentBorder: true
                horizontalOffset: 0
                verticalOffset: 4
                radius: 12.0
                samples: 17
                color: "#40000000"
            }

            // 图标
            Text {
                anchors.centerIn: parent
                text: iconText
                font.family: "Font Awesome 5 Free"
                font.pixelSize: iconSize
                color: "#ffffff"
            }

            // 悬停效果
            states: [
                State {
                    name: "hovered"
                    when: mouseArea.containsMouse && root.enabled
                    PropertyChanges {
                        target: button
                        scale: 1.1
                    }
                },
                State {
                    name: "pressed"
                    when: mouseArea.pressed && root.enabled
                    PropertyChanges {
                        target: button
                        scale: 0.95
                    }
                }
            ]

            transitions: Transition {
                NumberAnimation {
                    properties: "scale"
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            // 鼠标交互
            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                enabled: root.enabled

                onClicked: {
                    if (root.enabled) {
                        root.clicked()

                        // 点击动画
                        clickAnimation.start()
                    }
                }
            }

            // 点击波纹动画
            Item {
                id: ripple
                anchors.fill: parent
                visible: false

                Rectangle {
                    id: rippleCircle
                    anchors.centerIn: parent
                    width: 0
                    height: 0
                    radius: width / 2
                    color: "#ffffff"
                    opacity: 0.5
                }
            }

            SequentialAnimation {
                id: clickAnimation

                ScriptAction {
                    script: ripple.visible = true
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: rippleCircle
                        properties: "width,height"
                        from: 0
                        to: button.width * 1.5
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: rippleCircle
                        property: "opacity"
                        from: 0.5
                        to: 0
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                }

                ScriptAction {
                    script: {
                        ripple.visible = false
                        rippleCircle.width = 0
                        rippleCircle.height = 0
                        rippleCircle.opacity = 0.5
                    }
                }
            }
        }

        // 标签文本
        Text {
            text: label
            font.pixelSize: 12
            font.family: "Microsoft YaHei"
            color: root.enabled ? "#e2e8f0" : "#64748b"
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // 禁用时的遮罩
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: root.enabled ? 0 : 0.3
        radius: buttonSize / 2
    }
}
