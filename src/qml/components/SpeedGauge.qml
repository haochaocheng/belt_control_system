import QtQuick 6.5

Item {
    id: root
    property real value: 0.0
    Text {
        anchors.centerIn: parent
        text: "Speed: " + root.value.toFixed(1)
        color: "white"
    }
}
