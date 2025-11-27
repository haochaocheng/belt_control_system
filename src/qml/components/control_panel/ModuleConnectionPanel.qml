import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// Module Connection Panel - Shows PLC module connection status
// Right top corner
Rectangle {
    id: root
    width: 280
    height: 200
    color: "#dd1a2332"
    radius: 10
    border.color: "#00d4ff"
    border.width: 2

    // Module connection status
    property bool mainModuleConnected: true
    property bool inputModuleConnected: true
    property bool outputModuleConnected: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 12

        // Title
        Text {
            text: "模块连接状态"
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

        // Main Module
        RowLayout {
            Layout.fillWidth: true
            spacing: 15

            Rectangle {
                width: 12
                height: 12
                radius: 6
                color: root.mainModuleConnected ? "#00ff88" : "#ff4757"

                SequentialAnimation on opacity {
                    running: root.mainModuleConnected
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 1000 }
                    NumberAnimation { to: 1.0; duration: 1000 }
                }
            }

            Text {
                text: "主模块"
                font.pixelSize: 14
                color: "#95a5a6"
                Layout.preferredWidth: 80
            }

            Text {
                text: root.mainModuleConnected ? "在线" : "离线"
                font.pixelSize: 13
                font.bold: true
                color: root.mainModuleConnected ? "#00ff88" : "#ff4757"
            }

            Item { Layout.fillWidth: true }

            Text {
                visible: root.mainModuleConnected
                text: "CPU:15%"
                font.pixelSize: 11
                color: "#3498db"
            }
        }

        // Input Module
        RowLayout {
            Layout.fillWidth: true
            spacing: 15

            Rectangle {
                width: 12
                height: 12
                radius: 6
                color: root.inputModuleConnected ? "#00ff88" : "#ff4757"

                SequentialAnimation on opacity {
                    running: root.inputModuleConnected
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 1000 }
                    NumberAnimation { to: 1.0; duration: 1000 }
                }
            }

            Text {
                text: "输入模块"
                font.pixelSize: 14
                color: "#95a5a6"
                Layout.preferredWidth: 80
            }

            Text {
                text: root.inputModuleConnected ? "在线" : "离线"
                font.pixelSize: 13
                font.bold: true
                color: root.inputModuleConnected ? "#00ff88" : "#ff4757"
            }

            Item { Layout.fillWidth: true }

            Text {
                visible: root.inputModuleConnected
                text: "DI:32"
                font.pixelSize: 11
                color: "#3498db"
            }
        }

        // Output Module
        RowLayout {
            Layout.fillWidth: true
            spacing: 15

            Rectangle {
                width: 12
                height: 12
                radius: 6
                color: root.outputModuleConnected ? "#00ff88" : "#ff4757"

                SequentialAnimation on opacity {
                    running: root.outputModuleConnected
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 1000 }
                    NumberAnimation { to: 1.0; duration: 1000 }
                }
            }

            Text {
                text: "输出模块"
                font.pixelSize: 14
                color: "#95a5a6"
                Layout.preferredWidth: 80
            }

            Text {
                text: root.outputModuleConnected ? "在线" : "离线"
                font.pixelSize: 13
                font.bold: true
                color: root.outputModuleConnected ? "#00ff88" : "#ff4757"
            }

            Item { Layout.fillWidth: true }

            Text {
                visible: root.outputModuleConnected
                text: "DO:16"
                font.pixelSize: 11
                color: "#3498db"
            }
        }

        Item { Layout.fillHeight: true }

        // Overall status
        Rectangle {
            Layout.fillWidth: true
            height: 36
            radius: 5
            color: getAllModulesConnected() ? "#00ff8820" : "#ff475720"
            border.color: getAllModulesConnected() ? "#00ff88" : "#ff4757"
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: getAllModulesConnected() ? "系统正常" : "模块异常"
                font.pixelSize: 14
                font.bold: true
                color: getAllModulesConnected() ? "#00ff88" : "#ff4757"
            }
        }
    }

    function getAllModulesConnected() {
        return root.mainModuleConnected && root.inputModuleConnected && root.outputModuleConnected
    }
}
