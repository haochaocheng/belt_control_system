import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// Contacts/Phonebook page
Page {
    id: root

    signal callContact(string number)

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

    // Inline RisipLineEdit component
    component RisipLineEdit: TextField {
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
            border.color: control.activeFocus ? "#00ff88" : control.borderColor
            border.width: control.borderWidth
        }

        color: control.textColor
        placeholderTextColor: control.placeholderColor
        font.pixelSize: 16
        selectByMouse: true
        leftPadding: 15
        rightPadding: 15
    }

    background: Rectangle {
        color: "transparent"
    }

    // Click anywhere to dismiss keyboard
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            root.forceActiveFocus()
            Qt.inputMethod.hide()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        // Search bar
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            RisipLineEdit {
                id: searchField
                Layout.fillWidth: true
                placeholderText: "搜索联系人..."
                inputMethodHints: Qt.ImhPreferLowercase  // Chinese input

                // TODO: Implement search filtering when needed
                // onTextChanged: {
                //     // Filter contacts based on search text
                // }
            }

            RisipButton {
                Layout.preferredWidth: 50
                Layout.preferredHeight: 50
                buttonRadius: 25

                contentItem: Text {
                    text: "+"
                    font.pixelSize: 28
                    font.bold: true
                    color: "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    Qt.inputMethod.hide()
                    addContactDialog.open()
                }
            }
        }

        // Contacts list header
        Rectangle {
            Layout.fillWidth: true
            height: 40
            color: "#0f3460"
            radius: 5

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 15
                anchors.rightMargin: 15
                spacing: 10

                Text {
                    text: "姓名"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#00d4ff"
                    Layout.preferredWidth: 150
                }

                Text {
                    text: "号码"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#00d4ff"
                    Layout.fillWidth: true
                }

                Text {
                    text: "操作"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#00d4ff"
                    Layout.preferredWidth: 100
                }
            }
        }

        // Contacts list
        ListView {
            id: contactsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 5

            model: ListModel {
                id: contactsListModel

                ListElement {
                    name: "张三"
                    number: "1001"
                    company: "技术部"
                }
                ListElement {
                    name: "李四"
                    number: "1002"
                    company: "管理部"
                }
                ListElement {
                    name: "王五"
                    number: "1003"
                    company: "运维部"
                }
                ListElement {
                    name: "赵六"
                    number: "1004"
                    company: "安全部"
                }
            }

            delegate: Rectangle {
                width: contactsList.width
                height: 60
                color: index % 2 === 0 ? "#1e2a3a" : "#16213e"
                radius: 5

                property bool isHovered: false

                Rectangle {
                    anchors.fill: parent
                    color: "#00d4ff"
                    opacity: parent.isHovered ? 0.1 : 0
                    radius: 5

                    Behavior on opacity {
                        NumberAnimation { duration: 150 }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 15
                    anchors.rightMargin: 15
                    spacing: 10

                    ColumnLayout {
                        Layout.preferredWidth: 150
                        spacing: 2

                        Text {
                            text: model.name
                            font.pixelSize: 16
                            font.bold: true
                            color: "#ffffff"
                        }

                        Text {
                            text: model.company || ""
                            font.pixelSize: 11
                            color: "#95a5a6"
                            visible: model.company !== undefined
                        }
                    }

                    Text {
                        text: model.number
                        font.pixelSize: 14
                        color: "#00d4ff"
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.preferredWidth: 100
                        spacing: 5

                        RisipButton {
                            Layout.preferredWidth: 45
                            Layout.preferredHeight: 40
                            buttonRadius: 20
                            buttonColor: "#27ae60"
                            hoverColor: "#229954"
                            borderWidth: 1

                            contentItem: Text {
                                text: "📞"
                                font.pixelSize: 18
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: {
                                root.callContact(model.number)
                            }
                        }

                        RisipButton {
                            Layout.preferredWidth: 45
                            Layout.preferredHeight: 40
                            buttonRadius: 20
                            buttonColor: "#e74c3c"
                            hoverColor: "#cb4335"
                            borderWidth: 1

                            contentItem: Text {
                                text: "🗑"
                                font.pixelSize: 18
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: {
                                contactsListModel.remove(index)
                            }
                        }
                    }
                }

                HoverHandler {
                    onHoveredChanged: parent.isHovered = hovered
                }
            }

            // Custom scrollbar
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded

                contentItem: Rectangle {
                    implicitWidth: 8
                    radius: 4
                    color: parent.pressed ? "#00d4ff" : "#34495e"
                    opacity: parent.active ? 1.0 : 0.5
                }
            }
        }

        // Status bar
        Rectangle {
            Layout.fillWidth: true
            height: 30
            color: "#0f3460"
            radius: 5

            Text {
                anchors.centerIn: parent
                text: "共 " + contactsListModel.count + " 个联系人"
                font.pixelSize: 12
                color: "#95a5a6"
            }
        }
    }

    // Add contact dialog - Popup with Flickable for scrolling
    Popup {
        id: addContactDialog
        modal: true
        anchors.centerIn: parent
        width: Math.min(450, parent.width * 0.9)
        height: Math.min(600, parent.height * 0.85)
        padding: 0

        background: Rectangle {
            color: "#1a1a2e"
            radius: 15
            border.color: "#00d4ff"
            border.width: 3
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Header
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                color: "#0f3460"
                radius: 15

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: parent.height / 2
                    color: parent.color
                }

                Text {
                    anchors.centerIn: parent
                    text: "添加联系人"
                    font.pixelSize: 20
                    font.bold: true
                    color: "#00d4ff"
                }
            }

            // Content with Flickable for keyboard auto-scroll
            Flickable {
                id: dialogFlickable
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                // Add extra height when keyboard is visible to allow scrolling
                contentHeight: {
                    var baseHeight = dialogContent.implicitHeight + 40
                    var keyboardHeight = Qt.inputMethod.keyboardRectangle.height
                    if (keyboardHeight > 0) {
                        // Add keyboard height plus margin to ensure scrollability
                        return baseHeight + keyboardHeight + 100
                    }
                    return baseHeight
                }

                interactive: true
                flickableDirection: Flickable.VerticalFlick

                property real scrollMarginVertical: 80

                // Monitor keyboard visibility and adjust scroll
                Connections {
                    target: Qt.inputMethod
                    function onVisibleChanged() {
                        console.log("Keyboard visibility changed:", Qt.inputMethod.visible)
                        if (Qt.inputMethod.visible) {
                            // Keyboard shown - find which input has focus and scroll to it
                            if (nameInput.activeFocus) {
                                dialogFlickable.ensureVisible(nameInput)
                            } else if (numberInput.activeFocus) {
                                dialogFlickable.ensureVisible(numberInput)
                            } else if (companyInput.activeFocus) {
                                dialogFlickable.ensureVisible(companyInput)
                            }
                        } else {
                            // Keyboard hidden - scroll back to top
                            console.log("Keyboard hidden, scrolling back to top")
                            dialogScrollAnimation.to = 0
                            dialogScrollAnimation.start()
                        }
                    }
                }

                // Smooth scroll animation for Flickable
                NumberAnimation {
                    id: dialogScrollAnimation
                    target: dialogFlickable
                    property: "contentY"
                    duration: 300
                    easing.type: Easing.OutQuad
                }

                // Function to ensure input field is visible by scrolling Flickable
                function ensureVisible(item) {
                    if (!item) return

                    var keyboardHeight = Qt.inputMethod.keyboardRectangle.height
                    if (keyboardHeight === 0) {
                        return
                    }

                    // Get Flickable's global position
                    var flickableGlobal = dialogFlickable.mapToGlobal(0, 0)

                    // Get screen and keyboard info
                    var screenHeight = addContactDialog.Window.window ? addContactDialog.Window.window.height : 1080
                    var keyboardTop = screenHeight - keyboardHeight

                    // Calculate where the keyboard appears relative to Flickable
                    var keyboardTopInFlickable = keyboardTop - flickableGlobal.y

                    // Get item's position in Flickable content coordinates
                    var itemPos = item.mapToItem(dialogFlickable.contentItem, 0, 0)
                    var itemY = itemPos.y
                    var itemBottom = itemY + item.height

                    var margin = 20

                    console.log("Correct scroll calculation:")
                    console.log("  Flickable global Y:", flickableGlobal.y)
                    console.log("  Flickable height:", height)
                    console.log("  Keyboard top (global):", keyboardTop)
                    console.log("  Keyboard top in Flickable:", keyboardTopInFlickable)
                    console.log("  Item Y in content:", itemY)
                    console.log("  Item height:", item.height)
                    console.log("  Item bottom in content:", itemBottom)
                    console.log("  Current contentY:", contentY)

                    // If keyboard blocks most of the Flickable, position item near top with some space
                    var targetY
                    if (keyboardTopInFlickable < 100) {
                        // Keyboard blocks most - just show the item near top
                        // Leave some space at top so item isn't at the very edge
                        targetY = Math.max(0, itemY - 30)
                        console.log("  Keyboard blocks most of Flickable, scrolling item to near top")
                    } else {
                        // Normal case: position item bottom above keyboard
                        targetY = itemBottom + margin - keyboardTopInFlickable
                        console.log("  Normal positioning above keyboard")
                    }

                    // Don't scroll past the end or before start
                    var maxContentY = Math.max(0, contentHeight - height)
                    targetY = Math.max(0, Math.min(targetY, maxContentY))

                    console.log("  Target contentY:", targetY)
                    console.log("  Max contentY:", maxContentY)

                    dialogScrollAnimation.to = targetY
                    dialogScrollAnimation.start()
                }

                // Click anywhere to dismiss keyboard
                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: {
                        addContactDialog.forceActiveFocus()
                        Qt.inputMethod.hide()
                    }
                }

                ColumnLayout {
                    id: dialogContent
                    width: parent.width
                    spacing: 20
                    anchors.margins: 25

                    Item { height: 5 }

                    Text {
                        text: "姓名"
                        font.pixelSize: 15
                        font.bold: true
                        color: "#00d4ff"
                        Layout.leftMargin: 25
                    }

                    TextField {
                        id: nameInput
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        Layout.leftMargin: 25
                        Layout.rightMargin: 25
                        placeholderText: "请输入姓名"
                        inputMethodHints: Qt.ImhPreferLowercase
                        font.pixelSize: 16
                        color: "#ffffff"
                        placeholderTextColor: "#7f8c8d"
                        selectByMouse: true
                        leftPadding: 15
                        rightPadding: 15

                        background: Rectangle {
                            color: "#0f3460"
                            radius: 10
                            border.color: parent.activeFocus ? "#00ff88" : "#00d4ff"
                            border.width: 2
                        }

                        onActiveFocusChanged: {
                            console.log("nameInput activeFocus changed:", activeFocus)
                            if (activeFocus) {
                                dialogFlickable.ensureVisible(nameInput)
                            }
                        }

                        onTextChanged: {
                            console.log("nameInput text changed:", text)
                        }
                    }

                    Text {
                        text: "号码"
                        font.pixelSize: 15
                        font.bold: true
                        color: "#00d4ff"
                        Layout.leftMargin: 25
                        Layout.topMargin: 5
                    }

                    TextField {
                        id: numberInput
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        Layout.leftMargin: 25
                        Layout.rightMargin: 25
                        placeholderText: "请输入号码"
                        inputMethodHints: Qt.ImhDigitsOnly
                        font.pixelSize: 16
                        color: "#ffffff"
                        placeholderTextColor: "#7f8c8d"
                        selectByMouse: true
                        leftPadding: 15
                        rightPadding: 15

                        background: Rectangle {
                            color: "#0f3460"
                            radius: 10
                            border.color: parent.activeFocus ? "#00ff88" : "#00d4ff"
                            border.width: 2
                        }

                        onActiveFocusChanged: {
                            if (activeFocus) {
                                dialogFlickable.ensureVisible(numberInput)
                            }
                        }
                    }

                    Text {
                        text: "公司/部门 (可选)"
                        font.pixelSize: 15
                        font.bold: true
                        color: "#00d4ff"
                        Layout.leftMargin: 25
                        Layout.topMargin: 5
                    }

                    TextField {
                        id: companyInput
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        Layout.leftMargin: 25
                        Layout.rightMargin: 25
                        placeholderText: "请输入公司/部门"
                        inputMethodHints: Qt.ImhPreferLowercase
                        font.pixelSize: 16
                        color: "#ffffff"
                        placeholderTextColor: "#7f8c8d"
                        selectByMouse: true
                        leftPadding: 15
                        rightPadding: 15

                        background: Rectangle {
                            color: "#0f3460"
                            radius: 10
                            border.color: parent.activeFocus ? "#00ff88" : "#00d4ff"
                            border.width: 2
                        }

                        onActiveFocusChanged: {
                            if (activeFocus) {
                                dialogFlickable.ensureVisible(companyInput)
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // Bottom buttons
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 80
                color: "#0f3460"
                radius: 15

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: parent.height / 2
                    color: parent.color
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 15

                    RisipButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        text: "取消"
                        buttonColor: "#7f8c8d"
                        hoverColor: "#95a5a6"

                        onClicked: {
                            Qt.inputMethod.hide()
                            nameInput.text = ""
                            numberInput.text = ""
                            companyInput.text = ""
                            addContactDialog.close()
                        }
                    }

                    RisipButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        text: "保存"
                        buttonColor: "#27ae60"
                        hoverColor: "#229954"

                        onClicked: {
                            Qt.inputMethod.hide()
                            if (nameInput.text && numberInput.text) {
                                contactsListModel.append({
                                    name: nameInput.text,
                                    number: numberInput.text,
                                    company: companyInput.text
                                })
                                nameInput.text = ""
                                numberInput.text = ""
                                companyInput.text = ""
                                addContactDialog.close()
                            }
                        }
                    }
                }
            }
        }
    }
}
