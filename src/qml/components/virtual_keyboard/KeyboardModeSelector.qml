import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// Keyboard mode selector component
RowLayout {
    id: root
    spacing: 5

    property string currentMode: "numeric"

    Repeater {
        model: ListModel {
            ListElement { mode: "numeric"; label: "数字" }
            ListElement { mode: "english"; label: "英文" }
            ListElement { mode: "chinese"; label: "中文" }
        }

        Button {
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: label

            background: Rectangle {
                color: root.currentMode === mode ? "#00d4ff" : "#34495e"
                radius: 5
                border.color: "#00d4ff"
                border.width: 1
            }

            contentItem: Text {
                text: parent.text
                color: root.currentMode === mode ? "#0a1628" : "#ecf0f1"
                font.pixelSize: 14
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: {
                root.currentMode = mode
            }
        }
    }
}
