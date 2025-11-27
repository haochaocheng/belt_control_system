import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5
import "../components/common"
import "../components/parameter_settings"

Item {
    id: root

    // Background
    Rectangle {
        anchors.fill: parent
        color: "#0a1628"
    }

    // Header
    Header {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
    }

    // Main content area - Flickable to support keyboard auto-scroll
    Flickable {
        id: mainFlickable
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.margins: 10

        contentWidth: width
        contentHeight: Math.max(height, mainContentColumn.implicitHeight + 20)
        clip: true

        // Enable keyboard auto-scroll
        interactive: contentHeight > height
        flickableDirection: Flickable.VerticalFlick

        property real scrollMarginVertical: 50

        // Monitor keyboard visibility and reset scroll when keyboard hides
        Connections {
            target: Qt.inputMethod
            function onVisibleChanged() {
                if (!Qt.inputMethod.visible) {
                    // Keyboard hidden - scroll back to top smoothly
                    scrollAnimation.to = 0
                    scrollAnimation.start()
                }
            }
        }

        // Smooth scroll animation
        NumberAnimation {
            id: scrollAnimation
            target: mainFlickable
            property: "contentY"
            duration: 300
            easing.type: Easing.OutQuad
        }

        // Function to ensure input field is visible
        function ensureVisible(item) {
            if (!item) return

            var yPos = item.mapToItem(mainFlickable.contentItem, 0, 0).y
            var itemHeight = item.height
            var keyboardHeight = Qt.inputMethod.keyboardRectangle.height
            var visibleAreaHeight = mainFlickable.height - keyboardHeight

            var targetY = 0
            // Scroll up if item is below visible area
            if (yPos + itemHeight + scrollMarginVertical > contentY + visibleAreaHeight) {
                targetY = yPos + itemHeight + scrollMarginVertical - visibleAreaHeight
            }
            // Scroll down if item is above visible area
            else if (yPos - scrollMarginVertical < contentY) {
                targetY = Math.max(0, yPos - scrollMarginVertical)
            } else {
                return // Already visible, no need to scroll
            }

            // Animate scroll
            scrollAnimation.to = targetY
            scrollAnimation.start()
        }

        ColumnLayout {
            id: mainContentColumn
            width: parent.width
            spacing: 8

                // Title
                Text {
                    text: "参数设置"
                    font.pixelSize: 32
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

            // Main grid layout - 2x2
            GridLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(600, mainFlickable.height - 120)
                columns: 2
                rows: 2
                rowSpacing: 8
                columnSpacing: 8

                // Top Left - Basic Parameters
                BasicParametersSection {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.row: 0
                    Layout.column: 0
                    dateTimePopup: dateTimePopup
                }

                // Top Right - Network Parameters
                NetworkParametersSection {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.row: 0
                    Layout.column: 1
                }

                // Bottom Left - Master Control Settings
                MasterControlSection {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.row: 1
                    Layout.column: 0
                    flickableParent: mainFlickable
                }

                // Bottom Right - Device Startup Sequence List
                DeviceSequenceSection {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.row: 1
                    Layout.column: 1
                    flickableParent: mainFlickable
                }
            }

            // Bottom buttons
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 55
                spacing: 20

                Item { Layout.fillWidth: true }

                Button {
                    Layout.preferredWidth: 180
                    Layout.preferredHeight: 50

                    background: Rectangle {
                        color: parent.pressed ? "#27ae60" : (parent.hovered ? "#2ecc71" : "#00ff88")
                        radius: 8
                        border.color: "#00d4ff"
                        border.width: 2
                    }

                    contentItem: Text {
                        text: "保存设置"
                        color: "#0a1628"
                        font.pixelSize: 20
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        console.log("Settings saved")
                    }
                }

                Button {
                    Layout.preferredWidth: 180
                    Layout.preferredHeight: 50

                    background: Rectangle {
                        color: parent.pressed ? "#c0392b" : (parent.hovered ? "#e74c3c" : "#ff4757")
                        radius: 8
                        border.color: "#00d4ff"
                        border.width: 2
                    }

                    contentItem: Text {
                        text: "恢复默认"
                        color: "white"
                        font.pixelSize: 20
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        console.log("Settings reset to default")
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }
    }

    // DateTime Picker Popup
    DateTimePickerPopup {
        id: dateTimePopup
    }
}
