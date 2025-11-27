import QtQuick 6.5
import QtQuick.Controls 6.5

Button {
    id: root
    text: "Motor Control"
    background: Rectangle {
        color: root.pressed ? "#2980b9" : "#3498db"
        radius: 5
    }
    contentItem: Text {
        text: root.text
        color: "white"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
