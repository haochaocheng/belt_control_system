import QtQuick 6.5
import QtQuick.Controls 6.5

// Reusable line edit component for SIP phone interface
TextField {
    id: control

    property color backgroundColor: "#0f3460"
    property color borderColor: "#00d4ff"
    property color textColor: "#ffffff"
    property color placeholderColor: "#7f8c8d"
    property int borderWidth: 2
    property int inputRadius: 10

    background: Rectangle {
        color: control.backgroundColor
        radius: control.inputRadius
        border.color: control.borderColor
        border.width: control.borderWidth
    }

    color: control.textColor
    placeholderTextColor: control.placeholderColor
    font.pixelSize: 16
    selectByMouse: true

    leftPadding: 15
    rightPadding: 15
}
