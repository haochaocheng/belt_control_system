import QtQuick 6.5

Item {
    id: root
    property bool active: false
    Rectangle {
        anchors.centerIn: parent
        width: 20
        height: 20
        radius: 10
        color: root.active ? "green" : "red"
    }
}
