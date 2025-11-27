import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5
import BeltControl.SipPhone 1.0

// Main SIP phone page with tab navigation
Rectangle {
    id: root
    color: "#1a1a2e"

    // Inline RisipButton component
    component RisipButton: Button {
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
            Behavior on color { ColorAnimation { duration: 150 } }
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

    // Connect to C++ signals - Moved to Connections for safety
    Connections {
        target: SipPhoneManager
        function onIncomingCall(number, name) {
            handleIncomingCall(number, name)
        }
        function onCallConnected() {
            handleCallConnected()
        }
        function onCallDisconnected() {
            handleCallDisconnected()
        }
        function onErrorOccurred(error) {
            handleError(error)
        }
    }

    // Initialize endpoint when first visible
    onVisibleChanged: {
        if (visible && !SipPhoneManager.isInitialized) {
            SipPhoneManager.initializeEndpoint()
        }
    }

    // Signal handlers
    function handleIncomingCall(number, name) {
        console.log("Incoming call from:", number, name)
        // Show incoming call dialog (like risip)
        incomingCallDialog.callerNumber = number
        incomingCallDialog.callerName = name
        incomingCallDialog.open()
    }

    function handleCallConnected() {
        console.log("Call connected")
        // Close incoming dialog if open
        incomingCallDialog.close()
        // Switch to dial page to show call status
        tabBarRect.currentIndex = 1
    }

    function handleCallDisconnected() {
        console.log("Call disconnected")
        // Close incoming dialog if open
        incomingCallDialog.close()
    }

    function handleError(error) {
        console.error("SIP Error:", error)
        errorDialog.errorMessage = error
        errorDialog.open()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Top bar with title and status
        Rectangle {
            Layout.fillWidth: true
            height: 60
            color: "#0f3460"
            z: 10

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 15

                Text {
                    text: "📞 SIP 电话"
                    font.pixelSize: 24
                    font.bold: true
                    color: "#00d4ff"
                    Layout.fillWidth: true
                }

                // Call status indicator
                Rectangle {
                    width: 120
                    height: 35
                    radius: 17
                    visible: SipPhoneManager.isInCall
                    color: {
                        if (SipPhoneManager.callStatus === "通话中") return "#27ae60"
                        if (SipPhoneManager.callStatus === "拨号中") return "#f39c12"
                        return "#34495e"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: SipPhoneManager.callStatus
                        font.pixelSize: 12
                        font.bold: true
                        color: "white"
                    }
                }

                // Server status indicator
                Rectangle {
                    width: 20
                    height: 20
                    radius: 10
                    color: SipPhoneManager.isRegistered ? "#27ae60" : "#e74c3c"

                    SequentialAnimation on opacity {
                        running: SipPhoneManager.isRegistered
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.3; duration: 800 }
                        NumberAnimation { from: 0.3; to: 1.0; duration: 800 }
                    }
                }
            }
        }

        // Separator
        Rectangle {
            Layout.fillWidth: true
            height: 2
            color: "#00d4ff"
            opacity: 0.3
        }

        // Main content area with StackLayout
        StackLayout {
            id: stackLayout
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: 1  // Will be controlled by tabBarRect

            // Contacts page
            Loader {
                source: "pages/SipContactsPage.qml"
                onLoaded: {
                    item.callContact.connect(function(number) {
                        SipPhoneManager.setCurrentNumber(number)
                        SipPhoneManager.makeCall(number)
                        tabBarRect.currentIndex = 1
                    })
                }
            }

            // Dial page
            Loader {
                source: "pages/SipDialPage.qml"
            }

            // History page
            Loader {
                source: "pages/SipHistoryPage.qml"
                onLoaded: {
                    item.callNumber.connect(function(number) {
                        SipPhoneManager.setCurrentNumber(number)
                        SipPhoneManager.makeCall(number)
                        tabBarRect.currentIndex = 1
                    })
                }
            }

            // Settings page
            Loader {
                source: "pages/SipSettingsPage.qml"
            }
        }

        // Bottom tab bar
        Rectangle {
            id: tabBarRect
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: "#0f3460"

            property int currentIndex: 1 // Start with dial page

            RowLayout {
                anchors.fill: parent
                spacing: 0

                Repeater {
                    model: [
                        {icon: "👥", text: "联系人"},
                        {icon: "📞", text: "拨号"},
                        {icon: "📋", text: "历史"},
                        {icon: "⚙️", text: "设置"}
                    ]

                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: {
                            if (tabBarRect.currentIndex === index) return "#2980b9"
                            if (tabMouseArea.containsMouse) return "#34495e"
                            return "transparent"
                        }

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                text: modelData.icon
                                font.pixelSize: 24
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: modelData.text
                                font.pixelSize: 12
                                color: tabBarRect.currentIndex === index ? "#ffffff" : "#95a5a6"
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }

                        MouseArea {
                            id: tabMouseArea
                            anchors.fill: parent
                            hoverEnabled: true

                            onClicked: {
                                console.log("Tab clicked, switching to index:", index)
                                tabBarRect.currentIndex = index
                            }
                        }
                    }
                }
            }

            // Bind to StackLayout
            onCurrentIndexChanged: {
                stackLayout.currentIndex = currentIndex
            }
        }
    }

    // Incoming call dialog (like risip CallPage incoming state)
    Dialog {
        id: incomingCallDialog
        title: "来电"
        modal: true
        anchors.centerIn: parent
        width: 450
        height: 400

        property string callerNumber: ""
        property string callerName: ""

        background: Rectangle {
            color: "#1a1a2e"
            radius: 15
            border.color: "#27ae60"
            border.width: 3

            // Pulsing animation
            SequentialAnimation on border.width {
                running: incomingCallDialog.visible
                loops: Animation.Infinite
                NumberAnimation { from: 2; to: 4; duration: 800 }
                NumberAnimation { from: 4; to: 2; duration: 800 }
            }
        }

        header: Rectangle {
            height: 60
            color: "#27ae60"
            radius: 15

            Text {
                anchors.centerIn: parent
                text: "📞 来电"
                font.pixelSize: 24
                font.bold: true
                color: "#ffffff"
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 30

            // Caller avatar (placeholder icon)
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 100
                height: 100
                radius: 50
                color: "#0f3460"
                border.color: "#00d4ff"
                border.width: 3

                Text {
                    anchors.centerIn: parent
                    text: "👤"
                    font.pixelSize: 50
                }
            }

            // Caller info
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10

                Text {
                    text: incomingCallDialog.callerName || "未知来电"
                    font.pixelSize: 24
                    font.bold: true
                    color: "#ffffff"
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: incomingCallDialog.callerNumber
                    font.pixelSize: 18
                    color: "#00d4ff"
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: "来电中..."
                    font.pixelSize: 14
                    font.italic: true
                    color: "#95a5a6"
                    Layout.alignment: Qt.AlignHCenter

                    SequentialAnimation on opacity {
                        running: incomingCallDialog.visible
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.3; duration: 1000 }
                        NumberAnimation { from: 0.3; to: 1.0; duration: 1000 }
                    }
                }
            }

            // Answer and Reject buttons
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 30

                // Reject button
                RisipButton {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 100
                    buttonRadius: 50
                    buttonColor: "#e74c3c"
                    hoverColor: "#c0392b"
                    borderColor: "#ff5555"
                    borderWidth: 3

                    contentItem: ColumnLayout {
                        spacing: 5

                        Text {
                            text: "📵"
                            font.pixelSize: 40
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: "拒接"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#ffffff"
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    onClicked: {
                        console.log("Rejecting incoming call")
                        SipPhoneManager.hangupCall()
                        incomingCallDialog.close()
                    }
                }

                // Answer button
                RisipButton {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 100
                    buttonRadius: 50
                    buttonColor: "#27ae60"
                    hoverColor: "#229954"
                    borderColor: "#00ff88"
                    borderWidth: 3

                    contentItem: ColumnLayout {
                        spacing: 5

                        Text {
                            text: "📞"
                            font.pixelSize: 40
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: "接听"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#ffffff"
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    onClicked: {
                        console.log("Answering incoming call")
                        SipPhoneManager.answerCall()
                        incomingCallDialog.close()
                        // Switch to dial page to show call status
                        tabBarRect.currentIndex = 1
                    }
                }
            }
        }
    }

    // Error dialog
    Dialog {
        id: errorDialog
        title: "错误"
        modal: true
        anchors.centerIn: parent
        width: 400

        property string errorMessage: ""

        background: Rectangle {
            color: "#1a1a2e"
            radius: 10
            border.color: "#e74c3c"
            border.width: 2
        }

        header: Rectangle {
            height: 50
            color: "#e74c3c"
            radius: 10

            Text {
                anchors.centerIn: parent
                text: "❌ 错误"
                font.pixelSize: 18
                font.bold: true
                color: "#ffffff"
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 20

            Text {
                text: errorDialog.errorMessage
                font.pixelSize: 14
                color: "#ffffff"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            RisipButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 45
                text: "确定"
                buttonColor: "#e74c3c"

                onClicked: {
                    errorDialog.close()
                }
            }
        }
    }
}
