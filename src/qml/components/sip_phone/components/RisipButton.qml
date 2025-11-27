import QtQuick 6.5
import QtQuick.Controls 6.5

// Reusable button component for SIP phone interface
Button {
    id: control

    property color buttonColor: "#2c3e50"
    property color hoverColor: "#34495e"
    property color pressColor: "#2980b9"
    property color textColor: "#ffffff"
    property color borderColor: "#00d4ff"
    property int borderWidth: 2
    property int buttonRadius: 10
    property bool isHovered: false

    background: Rectangle {
        color: control.pressed ? control.pressColor : (control.isHovered ? control.hoverColor : control.buttonColor)
        radius: control.buttonRadius
        border.color: control.borderColor
        border.width: control.borderWidth

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
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
