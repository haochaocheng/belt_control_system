import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// Protection Panel - Shows protection sensors status
// Click to configure parameters
Rectangle {
    id: root
    width: 280
    height: 400
    color: "#dd1a2332"
    radius: 10
    border.color: "#00d4ff"
    border.width: 2

    // Signals
    signal protectionClicked(string protectionName, var sourceItem)
    signal addProtectionClicked(var sourceItem)

    // Protection items model
    ListModel {
        id: protectionModel

        ListElement { name: "速度"; active: false; type: "analog"; value: 2.2; unit: "m/s" }
        ListElement { name: "张力"; active: false; type: "analog"; value: 1.2; unit: "T" }
        ListElement { name: "跑偏"; active: false; type: "digital"; value: 0.0; unit: "" }
        ListElement { name: "撕裂"; active: false; type: "digital"; value: 0.0; unit: "" }
        ListElement { name: "急停"; active: true; type: "digital"; value: 0.0; unit: "" }
        ListElement { name: "温度"; active: false; type: "analog"; value: 23.2; unit: "℃" }
        ListElement { name: "烟雾"; active: false; type: "digital"; value: 0.0; unit: "" }
        ListElement { name: "堆煤"; active: false; type: "digital"; value: 0.0; unit: "" }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10

        // Title
        Text {
            text: "保护信息"
            font.pixelSize: 18
            font.bold: true
            color: "#00d4ff"
            Layout.alignment: Qt.AlignHCenter
        }

        Rectangle {
            Layout.fillWidth: true
            height: 2
            color: "#00d4ff"
            opacity: 0.5
        }

        // Protection items grid with scroll support
        ScrollView {
            id: scrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff

            Flow {
                width: scrollView.width
                spacing: 10

                Repeater {
                    model: protectionModel

                    Rectangle {
                        id: protectionItem
                        width: 70
                        height: 60
                        radius: 8
                        color: model.active ? "#ff4757" : "#2c3e50"
                        border.color: model.active ? "#ff6b7a" : "#00d4ff"
                        border.width: 2

                        // Blinking animation when active
                        SequentialAnimation on opacity {
                            running: model.active
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.5; duration: 500 }
                            NumberAnimation { to: 1.0; duration: 500 }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 3

                            Text {
                                text: model.name
                                font.pixelSize: 14
                                font.bold: true
                                color: model.active ? "white" : "#00d4ff"
                                Layout.alignment: Qt.AlignHCenter
                            }

                            // Value display for analog types
                            Text {
                                text: model.type === "analog" ? (model.value.toFixed(1) + model.unit) : ""
                                font.pixelSize: 11
                                color: model.active ? "#ffcccc" : "#00ff88"
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                                visible: model.type === "analog"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.protectionClicked(model.name, protectionItem)

                            hoverEnabled: true
                            onEntered: parent.scale = 1.05
                            onExited: parent.scale = 1.0
                        }

                        Behavior on scale {
                            NumberAnimation { duration: 150 }
                        }
                    }
                }

                // Add new protection button
                Rectangle {
                    id: addProtectionButton
                    width: 70
                    height: 60
                    radius: 8
                    color: "#34495e"
                    border.color: "#00ff88"
                    border.width: 2

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        font.pixelSize: 32
                        font.bold: true
                        color: "#00ff88"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.addProtectionClicked(addProtectionButton)

                        hoverEnabled: true
                        onEntered: parent.scale = 1.05
                        onExited: parent.scale = 1.0
                    }

                    Behavior on scale {
                        NumberAnimation { duration: 150 }
                    }
                }
            }
        }
    }

    // Public functions
    function setProtectionActive(protectionName, active) {
        for (var i = 0; i < protectionModel.count; i++) {
            if (protectionModel.get(i).name === protectionName) {
                protectionModel.setProperty(i, "active", active)
                break
            }
        }
    }

    function addProtection(name, type) {
        protectionModel.append({"name": name, "active": false, "type": type})
    }

    function getProtectionCount() {
        return protectionModel.count
    }

    function getProtectionAt(index) {
        if (index >= 0 && index < protectionModel.count) {
            return protectionModel.get(index)
        }
        return null
    }

    function removeProtection(name) {
        for (var i = 0; i < protectionModel.count; i++) {
            if (protectionModel.get(i).name === name) {
                protectionModel.remove(i)
                break
            }
        }
    }
}
