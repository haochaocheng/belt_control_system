import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5
import BeltControl.SipPhone 1.0

// Contacts/Phonebook page
Page {
    id: root

    signal callContact(string number)
    signal callContactVideo(string number)  // 视频通话

    // ✅ 加载联系人列表
    Component.onCompleted: {
        loadContacts()
    }

    // 从数据库加载联系人
    function loadContacts() {
        console.log("📇 Loading contacts from database...")

        // 清空当前列表
        contactsListModel.clear()

        // 从数据库加载联系人
        var contacts = SipPhoneManager.getAllContacts()
        console.log("📇 Loaded", contacts.length, "contacts from database")

        // 添加到列表模型
        for (var i = 0; i < contacts.length; i++) {
            contactsListModel.append({
                id: contacts[i].id,
                name: contacts[i].name,
                number: contacts[i].number,
                company: ""  // ContactDatabase 暂时不支持 company 字段
            })
        }
    }

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
                    Layout.preferredWidth: 140
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
                // ✅ 联系人数据从数据库动态加载，不再使用硬编码数据
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
                        Layout.preferredWidth: 140
                        spacing: 5

                        // 语音通话按钮
                        RisipButton {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 36
                            buttonRadius: 18
                            buttonColor: "#27ae60"
                            hoverColor: "#229954"
                            borderWidth: 1

                            contentItem: Text {
                                text: "📞"
                                font.pixelSize: 15
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: {
                                root.callContact(model.number)
                            }
                        }

                        // 视频通话按钮
                        RisipButton {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 36
                            buttonRadius: 18
                            buttonColor: "#3498db"
                            hoverColor: "#2980b9"
                            borderWidth: 1

                            contentItem: Text {
                                text: "📹"
                                font.pixelSize: 15
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: {
                                root.callContactVideo(model.number)
                            }
                        }

                        // 删除按钮
                        RisipButton {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 36
                            buttonRadius: 18
                            buttonColor: "#e74c3c"
                            hoverColor: "#cb4335"
                            borderWidth: 1

                            contentItem: Text {
                                text: "🗑"
                                font.pixelSize: 15
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: {
                                // ✅ 从数据库删除联系人
                                var success = SipPhoneManager.deleteContact(model.id)
                                if (success) {
                                    console.log("✅ 联系人删除成功:", model.name)
                                    // 重新加载列表
                                    loadContacts()
                                } else {
                                    console.log("❌ 联系人删除失败")
                                }
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

    // Add contact dialog - Dialog with Flickable for scrolling
    Dialog {
        id: addContactDialog
        modal: false
        closePolicy: Popup.NoAutoClose
        x: (parent.width - width) / 2
        y: 30
        width: Math.min(450, parent.width * 0.9)
        height: Math.min(550, parent.height * 0.85)

        background: Rectangle {
            color: "#1a1a2e"
            radius: 15
            border.color: "#00d4ff"
            border.width: 2
        }

        header: Rectangle {
            height: 40
            color: "#16213e"
            radius: 15

            Text {
                anchors.centerIn: parent
                text: "添加联系人"
                font.pixelSize: 16
                font.bold: true
                color: "#00d4ff"
            }

            // MouseArea to close keyboard when clicking header
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    console.log("[Dialog Header] Clicked - closing keyboard")
                    Qt.inputMethod.commit()
                    Qt.inputMethod.hide()
                }
            }
        }

        contentItem: Flickable {
            id: dialogFlickable
            clip: true
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

            interactive: contentHeight > height
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
                    anchors.fill: dialogContent  // ✅ Fill ColumnLayout area
                    z: -1  // ✅ Behind ColumnLayout content
                    propagateComposedEvents: true

                    onClicked: function(mouse) {
                        console.log("[Dialog Content] MouseArea clicked, mouse.accepted:", mouse.accepted)
                        if (!mouse.accepted) {
                            console.log("[Dialog Content] Clicked blank space - closing keyboard")
                            Qt.inputMethod.commit()
                            Qt.inputMethod.hide()
                        }
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

        onAccepted: {
            Qt.inputMethod.hide()
            if (nameInput.text && numberInput.text) {
                // ✅ 保存到数据库
                var success = SipPhoneManager.addContact(nameInput.text, numberInput.text)
                if (success) {
                    console.log("✅ 联系人保存成功:", nameInput.text, numberInput.text)
                    // ✅ 重新加载联系人列表以显示最新数据
                    loadContacts()
                } else {
                    console.log("❌ 联系人保存失败")
                }

                nameInput.text = ""
                numberInput.text = ""
                companyInput.text = ""
            }
        }

        onRejected: {
            Qt.inputMethod.hide()
            nameInput.text = ""
            numberInput.text = ""
            companyInput.text = ""
        }

        footer: DialogButtonBox {
            background: Rectangle {
                color: "#16213e"
            }

            Button {
                text: "取消"
                DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
                implicitHeight: 45

                background: Rectangle {
                    color: parent.pressed ? "#95a5a6" : "#7f8c8d"
                    radius: 8
                }

                contentItem: Text {
                    text: parent.text
                    color: "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 15
                    font.bold: true
                }
            }

            Button {
                text: "保存"
                DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
                implicitHeight: 45

                background: Rectangle {
                    color: parent.pressed ? "#229954" : "#27ae60"
                    radius: 8
                }

                contentItem: Text {
                    text: parent.text
                    color: "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 15
                    font.bold: true
                }
            }
        }
    }
}
