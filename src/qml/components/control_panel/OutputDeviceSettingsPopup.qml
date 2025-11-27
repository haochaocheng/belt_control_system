import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// Output Device Settings Popup
Popup {
    id: root
    width: 600
    height: 650  // Fixed height
    modal: false  // Disable modal to prevent dim overlay from blocking keyboard
    focus: true
    closePolicy: Popup.CloseOnEscape
    z: 1000  // Lower z-index than keyboard (keyboard is 100000)
    clip: true  // Clip content during scale animation

    // Scale and opacity for entire popup animation
    scale: 1.0
    opacity: 1.0
    transformOrigin: Item.Center

    // Disable default overlay
    Overlay.modal: null
    Overlay.modeless: null

    // Ensure dim overlay is hidden when popup closes
    onClosed: {
        dimOverlay.opacity = 0
        // Reset scale and opacity in case popup was closed without animation
        root.scale = 1.0
        root.opacity = 1.0
    }

    // Click on empty area to show keyboard
    MouseArea {
        anchors.fill: parent
        z: -1
        propagateComposedEvents: true
        onClicked: function(mouse) {
            // Show keyboard when clicking empty area
            Qt.inputMethod.show()
            mouse.accepted = false  // Allow event to propagate
        }
    }

    // Center positioning
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2

    // Properties
    property string deviceName: ""
    property string outputModule: "输出模块"
    property int channelNumber: 1
    property bool useWarningVoice: true
    property real startupDelay: 1.0
    property string feedbackModule: "输入模块"
    property int feedbackChannel: 1
    property string relayType: "本机继电器"  // 本机继电器, 远程设备, 远程主机
    property bool isNewDevice: false
    property bool enablePopupAnimation: true  // 弹窗动画效果

    // Animation properties
    property var sourceItem: null
    property point sourcePos: Qt.point(0, 0)
    property point targetPos: Qt.point(0, 0)
    property bool isAnimating: false

    signal accepted()
    signal rejected()
    signal deleteRequested()

    // Dim overlay - appears instantly without animation (in Overlay.overlay layer)
    Rectangle {
        id: dimOverlay
        parent: Overlay.overlay
        anchors.fill: parent
        color: "#80000000"
        opacity: 0
        z: 999  // Below popup (1000) but above everything else

        // Fade in/out animation
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        // Click to close popup (optional)
        MouseArea {
            anchors.fill: parent
            onClicked: {
                root.rejected()
                closeWithAnimation()
            }
        }
    }

    background: Rectangle {
        color: "#2c3e50"
        radius: 10
        border.color: "#00d4ff"
        border.width: 3

        // Outer glow effect
        Rectangle {
            anchors.fill: parent
            anchors.margins: -5
            color: "transparent"
            border.color: "#00d4ff"
            border.width: 1
            radius: 12
            opacity: 0.3
            z: -1
        }
    }

    // Content
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        // Title
        Text {
            text: (root.isNewDevice ? "新增设备: " : "设备参数设置: ") + root.deviceName
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

        // Scrollable content area with keyboard auto-scroll
        Flickable {
            id: scrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            // Force contentHeight to be large enough for all content to scroll properly
            contentHeight: {
                // Force re-evaluation when contentColumn changes
                contentColumn.implicitHeight
                // Calculate actual height needed for all content
                var totalHeight = 0
                for (var i = 0; i < contentColumn.children.length; i++) {
                    var child = contentColumn.children[i]
                    if (child && child.visible !== false) {
                        totalHeight += child.implicitHeight || child.height || 0
                    }
                }
                // Add spacing between items
                totalHeight += contentColumn.spacing * (contentColumn.children.length - 1)
                // Need much larger contentHeight to allow full scrolling
                // Add extra space for keyboard (600px) + margin (100px)
                return Math.max(totalHeight + 700, 1200)
            }
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AlwaysOff  // Hide scrollbar for cleaner look
            }

            // Monitor keyboard visibility
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
                target: scrollView
                property: "contentY"
                duration: 300
                easing.type: Easing.OutQuad
            }

            // Function to ensure input field is visible above keyboard
            function ensureVisible(item) {
                if (!item) return

                Qt.callLater(function() {
                    // Get item position in scrollView's content coordinates
                    var itemRect = item.mapToItem(scrollView.contentItem, 0, 0)
                    var itemY = itemRect.y
                    var itemHeight = item.height

                    var keyboardHeight = Qt.inputMethod.keyboardRectangle.height
                    if (keyboardHeight === 0) {
                        keyboardHeight = 400 // Fallback estimate
                    }

                    // IMPORTANT: Virtual keyboard is at the SCREEN bottom (in Overlay.overlay),
                    // NOT at popup bottom! Popup repositions itself to avoid keyboard.
                    // After popup moves up, we need to calculate visible space in scrollView.

                    // Get item's global position on screen
                    var itemGlobalRect = item.mapToItem(null, 0, 0)
                    var itemGlobalY = itemGlobalRect.y
                    var itemGlobalBottom = itemGlobalY + itemHeight

                    // Get keyboard's global top position (screen height - keyboard height)
                    var screenHeight = root.parent ? root.parent.height : 1080
                    var keyboardGlobalTop = screenHeight - keyboardHeight

                    // Margin to account for candidate bar (中文输入法候选词区域)
                    var candidateBarHeight = 50
                    var margin = 10  // Small gap above candidate bar

                    // Target: position item bottom just above candidate bar
                    var targetGlobalBottom = keyboardGlobalTop - candidateBarHeight - margin

                    // If item is already above target, don't scroll
                    if (itemGlobalBottom <= targetGlobalBottom) {
                        console.log("Item already visible, no scroll needed")
                        return
                    }

                    // Calculate how much we need to scroll up
                    var scrollNeeded = itemGlobalBottom - targetGlobalBottom

                    // Apply scroll
                    var targetY = scrollView.contentY + scrollNeeded

                    // Clamp to valid range
                    var maxScroll = Math.max(0, scrollView.contentHeight - scrollView.height)
                    targetY = Math.max(0, Math.min(targetY, maxScroll))

                    scrollAnimation.to = targetY
                    scrollAnimation.start()

                    console.log("Scroll: itemY=" + itemY + " itemGlobalY=" + itemGlobalY +
                                " itemGlobalBottom=" + itemGlobalBottom +
                                " keyboardGlobalTop=" + keyboardGlobalTop +
                                " targetGlobalBottom=" + targetGlobalBottom +
                                " scrollNeeded=" + scrollNeeded + " targetY=" + targetY)
                })
            }

            ColumnLayout {
                id: contentColumn
                width: parent.width
                spacing: 15

                // Device Name
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "设备名称:"
                        font.pixelSize: 14
                        color: "#95a5a6"
                        Layout.preferredWidth: 120
                    }

                    TextField {
                        id: nameField
                        text: root.deviceName
                        enabled: root.isNewDevice
                        Layout.fillWidth: true

                        background: Rectangle {
                            color: nameField.enabled ? "#34495e" : "#2c3e50"
                            radius: 5
                            border.color: nameField.activeFocus ? "#3498db" : "#7f8c8d"
                            border.width: 1
                        }

                        color: "#ecf0f1"
                        font.pixelSize: 13

                        onFocusChanged: {
                            if (focus) {
                                scrollView.ensureVisible(nameField)
                            }
                        }
                    }
                }

                // Output Module
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "输出模块:"
                        font.pixelSize: 14
                        color: "#95a5a6"
                        Layout.preferredWidth: 120
                    }

                    ComboBox {
                        id: outputModuleCombo
                        Layout.fillWidth: true

                        model: ["输出模块", "主模块"]
                        currentIndex: {
                            var idx = model.indexOf(root.outputModule)
                            return idx >= 0 ? idx : 0
                        }

                        background: Rectangle {
                            color: "#34495e"
                            radius: 5
                            border.color: outputModuleCombo.pressed ? "#3498db" : "#7f8c8d"
                            border.width: 1
                        }

                        contentItem: Text {
                            text: outputModuleCombo.displayText
                            color: "#ecf0f1"
                            font.pixelSize: 13
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 10
                        }
                    }
                }

                // Channel Number
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "通道编号:"
                        font.pixelSize: 14
                        color: "#95a5a6"
                        Layout.preferredWidth: 120
                    }

                    SpinBox {
                        id: channelSpin
                        from: 1
                        to: 32
                        value: root.channelNumber
                        editable: true
                        Layout.fillWidth: true

                        background: Rectangle {
                            color: "#34495e"
                            radius: 5
                            border.color: channelSpin.activeFocus ? "#3498db" : "#7f8c8d"
                            border.width: 1
                        }

                        contentItem: TextInput {
                            text: channelSpin.textFromValue(channelSpin.value, channelSpin.locale)
                            font.pixelSize: 13
                            color: "#ecf0f1"
                            horizontalAlignment: Qt.AlignHCenter
                            verticalAlignment: Qt.AlignVCenter
                            readOnly: !channelSpin.editable
                            validator: channelSpin.validator
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#00d4ff"
                    opacity: 0.3
                }

                // Warning Voice or Startup Delay Selection
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "启动方式:"
                        font.pixelSize: 14
                        color: "#95a5a6"
                        Layout.preferredWidth: 120
                    }

                    RadioButton {
                        id: voiceRadio
                        text: "预警语音"
                        checked: root.useWarningVoice
                        font.pixelSize: 13

                        indicator: Rectangle {
                            implicitWidth: 20
                            implicitHeight: 20
                            x: voiceRadio.leftPadding
                            y: parent.height / 2 - height / 2
                            radius: 10
                            border.color: voiceRadio.checked ? "#00d4ff" : "#7f8c8d"
                            border.width: 2
                            color: "transparent"

                            Rectangle {
                                width: 10
                                height: 10
                                x: 5
                                y: 5
                                radius: 5
                                color: "#00d4ff"
                                visible: voiceRadio.checked
                            }
                        }

                        contentItem: Text {
                            text: voiceRadio.text
                            font: voiceRadio.font
                            color: "#ecf0f1"
                            leftPadding: voiceRadio.indicator.width + 8
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    RadioButton {
                        id: delayRadio
                        text: "启动延时"
                        checked: !root.useWarningVoice
                        font.pixelSize: 13

                        indicator: Rectangle {
                            implicitWidth: 20
                            implicitHeight: 20
                            x: delayRadio.leftPadding
                            y: parent.height / 2 - height / 2
                            radius: 10
                            border.color: delayRadio.checked ? "#00d4ff" : "#7f8c8d"
                            border.width: 2
                            color: "transparent"

                            Rectangle {
                                width: 10
                                height: 10
                                x: 5
                                y: 5
                                radius: 5
                                color: "#00d4ff"
                                visible: delayRadio.checked
                            }
                        }

                        contentItem: Text {
                            text: delayRadio.text
                            font: delayRadio.font
                            color: "#ecf0f1"
                            leftPadding: delayRadio.indicator.width + 8
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                // Startup Delay
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    visible: delayRadio.checked

                    Text {
                        text: "启动延时(秒):"
                        font.pixelSize: 14
                        color: "#95a5a6"
                        Layout.preferredWidth: 120
                    }

                    SpinBox {
                        id: delaySpin
                        from: 0
                        to: 60
                        value: root.startupDelay * 10
                        stepSize: 1
                        editable: true
                        Layout.fillWidth: true

                        property int decimals: 1
                        property real realValue: value / 10

                        validator: DoubleValidator {
                            bottom: Math.min(delaySpin.from, delaySpin.to)
                            top:  Math.max(delaySpin.from, delaySpin.to)
                        }

                        textFromValue: function(value, locale) {
                            return Number(value / 10).toLocaleString(locale, 'f', 1)
                        }

                        valueFromText: function(text, locale) {
                            return Number.fromLocaleString(locale, text) * 10
                        }

                        background: Rectangle {
                            color: "#34495e"
                            radius: 5
                            border.color: delaySpin.activeFocus ? "#3498db" : "#7f8c8d"
                            border.width: 1
                        }

                        contentItem: TextInput {
                            text: delaySpin.textFromValue(delaySpin.value, delaySpin.locale)
                            font.pixelSize: 13
                            color: "#ecf0f1"
                            horizontalAlignment: Qt.AlignHCenter
                            verticalAlignment: Qt.AlignVCenter
                            readOnly: !delaySpin.editable
                            validator: delaySpin.validator
                            inputMethodHints: Qt.ImhFormattedNumbersOnly

                            onActiveFocusChanged: {
                                if (activeFocus) {
                                    scrollView.ensureVisible(delaySpin)
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#00d4ff"
                    opacity: 0.3
                }

                // Feedback Settings Title
                Text {
                    text: "反馈设置"
                    font.pixelSize: 15
                    font.bold: true
                    color: "#00d4ff"
                    Layout.alignment: Qt.AlignLeft
                }

                // Feedback Module Type
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "反馈模块:"
                        font.pixelSize: 14
                        color: "#95a5a6"
                        Layout.preferredWidth: 120
                    }

                    ComboBox {
                        id: feedbackModuleCombo
                        Layout.fillWidth: true

                        model: ["输入模块", "主模块"]
                        currentIndex: {
                            var idx = model.indexOf(root.feedbackModule)
                            return idx >= 0 ? idx : 0
                        }

                        background: Rectangle {
                            color: "#34495e"
                            radius: 5
                            border.color: feedbackModuleCombo.pressed ? "#3498db" : "#7f8c8d"
                            border.width: 1
                        }

                        contentItem: Text {
                            text: feedbackModuleCombo.displayText
                            color: "#ecf0f1"
                            font.pixelSize: 13
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 10
                        }
                    }
                }

                // Feedback Channel
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "反馈通道:"
                        font.pixelSize: 14
                        color: "#95a5a6"
                        Layout.preferredWidth: 120
                    }

                    SpinBox {
                        id: feedbackChannelSpin
                        from: 1
                        to: 32
                        value: root.feedbackChannel
                        editable: true
                        Layout.fillWidth: true

                        background: Rectangle {
                            color: "#34495e"
                            radius: 5
                            border.color: feedbackChannelSpin.activeFocus ? "#3498db" : "#7f8c8d"
                            border.width: 1
                        }

                        contentItem: TextInput {
                            text: feedbackChannelSpin.textFromValue(feedbackChannelSpin.value, feedbackChannelSpin.locale)
                            font.pixelSize: 13
                            color: "#ecf0f1"
                            horizontalAlignment: Qt.AlignHCenter
                            verticalAlignment: Qt.AlignVCenter
                            readOnly: !feedbackChannelSpin.editable
                            validator: feedbackChannelSpin.validator
                            inputMethodHints: Qt.ImhFormattedNumbersOnly

                            onActiveFocusChanged: {
                                if (activeFocus) {
                                    scrollView.ensureVisible(feedbackChannelSpin)
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#00d4ff"
                    opacity: 0.3
                }

                // Relay Type Selection
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "继电器类型:"
                        font.pixelSize: 14
                        color: "#95a5a6"
                        Layout.preferredWidth: 120
                    }

                    ComboBox {
                        id: relayTypeCombo
                        Layout.fillWidth: true

                        model: ["本机继电器", "远程设备", "远程主机"]
                        currentIndex: {
                            var idx = model.indexOf(root.relayType)
                            return idx >= 0 ? idx : 0
                        }

                        background: Rectangle {
                            color: "#34495e"
                            radius: 5
                            border.color: relayTypeCombo.pressed ? "#3498db" : "#7f8c8d"
                            border.width: 1
                        }

                        contentItem: Text {
                            text: relayTypeCombo.displayText
                            color: "#ecf0f1"
                            font.pixelSize: 13
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 10
                        }
                    }
                }
            }
        }

        // Button row
        RowLayout {
            Layout.fillWidth: true
            spacing: 15

            Button {
                text: "确定"
                Layout.fillWidth: true
                Layout.preferredHeight: 40

                background: Rectangle {
                    color: parent.pressed ? "#27ae60" : (parent.hovered ? "#2ecc71" : "#27ae60")
                    radius: 5
                }

                contentItem: Text {
                    text: parent.text
                    font.pixelSize: 14
                    font.bold: true
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    // Update values
                    root.deviceName = nameField.text
                    root.outputModule = outputModuleCombo.currentText
                    root.channelNumber = channelSpin.value
                    root.useWarningVoice = voiceRadio.checked
                    root.startupDelay = delaySpin.realValue
                    root.feedbackModule = feedbackModuleCombo.currentText
                    root.feedbackChannel = feedbackChannelSpin.value
                    root.relayType = relayTypeCombo.currentText

                    root.accepted()
                    closeWithAnimation()
                }
            }

            Button {
                text: "删除"
                visible: !root.isNewDevice
                Layout.fillWidth: true
                Layout.preferredHeight: 40

                background: Rectangle {
                    color: parent.pressed ? "#c0392b" : (parent.hovered ? "#e74c3c" : "#d35400")
                    radius: 5
                }

                contentItem: Text {
                    text: parent.text
                    font.pixelSize: 14
                    font.bold: true
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    root.deleteRequested()
                    closeWithAnimation()
                }
            }

            Button {
                text: "取消"
                Layout.fillWidth: true
                Layout.preferredHeight: 40

                background: Rectangle {
                    color: parent.pressed ? "#7f8c8d" : (parent.hovered ? "#95a5a6" : "#7f8c8d")
                    radius: 5
                }

                contentItem: Text {
                    text: parent.text
                    font.pixelSize: 14
                    font.bold: true
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    root.rejected()
                    closeWithAnimation()
                }
            }
        }
    }

    // Public functions
    function openForDevice(name, srcItem) {
        root.isNewDevice = false
        root.deviceName = name
        root.outputModule = "输出模块"
        root.channelNumber = 1
        root.useWarningVoice = true
        root.startupDelay = 1.0
        root.feedbackModule = "输入模块"
        root.feedbackChannel = 1
        root.relayType = "本机继电器"
        root.sourceItem = srcItem || null

        openWithAnimation()
    }

    function openForNew(srcItem) {
        root.isNewDevice = true
        root.deviceName = "新设备"
        root.outputModule = "输出模块"
        root.channelNumber = 1
        root.useWarningVoice = true
        root.startupDelay = 1.0
        root.feedbackModule = "输入模块"
        root.feedbackChannel = 1
        root.relayType = "本机继电器"
        root.sourceItem = srcItem || null

        openWithAnimation()
    }

    // Open with flying animation - popup flies from source item to center
    function openWithAnimation() {
        if (!root.enablePopupAnimation || !root.sourceItem) {
            dimOverlay.opacity = 1  // Show dim overlay instantly
            root.open()
            return
        }

        root.isAnimating = true

        // Show dim overlay instantly (no flying effect)
        dimOverlay.opacity = 1

        // Get source position in global coordinates (relative to Overlay)
        var sourceGlobalPos = root.sourceItem.mapToItem(Overlay.overlay, 0, 0)
        // Calculate center position of source item
        root.sourcePos = Qt.point(
            sourceGlobalPos.x + root.sourceItem.width / 2 - root.width / 2,
            sourceGlobalPos.y + root.sourceItem.height / 2 - root.height / 2
        )

        // Calculate target position (center of screen)
        root.targetPos = Qt.point(
            (root.parent.width - root.width) / 2,
            (root.parent.height - root.height) / 2
        )

        // Position popup at source position, scaled down
        root.x = root.sourcePos.x
        root.y = root.sourcePos.y
        root.scale = 0.1  // Scale entire popup (border + content together)
        root.opacity = 0.3
        root.open()

        // Start open animation
        openAnimation.start()
    }

    // Close with flying animation - popup flies back to source item
    function closeWithAnimation() {
        if (!root.enablePopupAnimation || !root.sourceItem || root.isAnimating) {
            dimOverlay.opacity = 0  // Hide dim overlay
            root.close()
            return
        }

        root.isAnimating = true
        // Start close animation (dimOverlay will be hidden in onFinished)
        closeAnimation.start()
    }

    // Open animation - popup moves from source to center while scaling up
    ParallelAnimation {
        id: openAnimation

        NumberAnimation {
            target: root
            property: "x"
            from: root.sourcePos.x
            to: root.targetPos.x
            duration: 350
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "y"
            from: root.sourcePos.y
            to: root.targetPos.y
            duration: 350
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "scale"
            from: 0.1
            to: 1.0
            duration: 350
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "opacity"
            from: 0.3
            to: 1.0
            duration: 350
            easing.type: Easing.OutCubic
        }

        onFinished: {
            root.isAnimating = false
        }
    }

    // Close animation - popup moves from center to source while scaling down
    ParallelAnimation {
        id: closeAnimation

        NumberAnimation {
            target: root
            property: "x"
            from: root.targetPos.x
            to: root.sourcePos.x
            duration: 300
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: root
            property: "y"
            from: root.targetPos.y
            to: root.sourcePos.y
            duration: 300
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: root
            property: "scale"
            from: 1.0
            to: 0.1
            duration: 300
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: root
            property: "opacity"
            from: 1.0
            to: 0.0
            duration: 300
            easing.type: Easing.InCubic
        }

        onFinished: {
            root.close()
            // Hide dim overlay
            dimOverlay.opacity = 0
            // Reset popup appearance
            root.scale = 1.0
            root.opacity = 1.0
            root.isAnimating = false
        }
    }
}
