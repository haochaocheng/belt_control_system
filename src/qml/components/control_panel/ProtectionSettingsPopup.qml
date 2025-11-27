import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// Protection Settings Popup - Using Popup instead of Dialog (more stable)
Popup {
    id: root
    width: 600
    height: 700  // Fixed height
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
    property string protectionName: ""
    property string protectionType: "analog"  // analog or digital
    property bool isNewProtection: false

    // Parameter values
    property real upperLimit: 100.0
    property real lowerLimit: 0.0
    property real range: 10.0
    property real ratedValue: 50.0
    property real protectionDelay: 1.0
    property int playCount: 3
    property real playDuration: 5.0
    property string moduleType: "输入模块"
    property int channelNumber: 1
    property string audioFile: ""
    property bool useTextToSpeech: true
    property string ttsText: ""
    property string unit: "m/s"
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
        id: popupBackground
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
            text: (root.isNewProtection ? "新增保护: " : "编辑保护: ") + root.protectionName
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

                // Protection Name
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "保护名称:"
                        font.pixelSize: 14
                        color: "#95a5a6"
                        Layout.preferredWidth: 120
                    }

                    TextField {
                        id: nameField
                        text: root.protectionName
                        enabled: root.isNewProtection
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

                // Protection Type
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "保护类型:"
                        font.pixelSize: 14
                        color: "#95a5a6"
                        Layout.preferredWidth: 120
                    }

                    ComboBox {
                        id: typeCombo
                        enabled: root.isNewProtection
                        Layout.fillWidth: true

                        model: ["模拟量", "开关量"]
                        currentIndex: root.protectionType === "analog" ? 0 : 1

                        background: Rectangle {
                            color: "#34495e"
                            radius: 5
                            border.color: typeCombo.pressed ? "#3498db" : "#7f8c8d"
                            border.width: 1
                        }

                        contentItem: Text {
                            text: typeCombo.displayText
                            color: "#ecf0f1"
                            font.pixelSize: 13
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 10
                        }
                    }
                }

                // Module Type
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "模块类型:"
                        font.pixelSize: 14
                        color: "#95a5a6"
                        Layout.preferredWidth: 120
                    }

                    ComboBox {
                        id: moduleTypeCombo
                        Layout.fillWidth: true

                        model: ["输入模块", "输出模块", "主模块"]
                        currentIndex: {
                            var idx = model.indexOf(root.moduleType)
                            return idx >= 0 ? idx : 0
                        }

                        background: Rectangle {
                            color: "#34495e"
                            radius: 5
                            border.color: moduleTypeCombo.pressed ? "#3498db" : "#7f8c8d"
                            border.width: 1
                        }

                        contentItem: Text {
                            text: moduleTypeCombo.displayText
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

                            onActiveFocusChanged: {
                                if (activeFocus) {
                                    scrollView.ensureVisible(channelSpin)
                                }
                            }
                        }
                    }
                }

                // Upper Limit
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    visible: typeCombo.currentIndex === 0

                    Text {
                        text: "上限值:"
                        font.pixelSize: 14
                        color: "#95a5a6"
                        Layout.preferredWidth: 120
                    }

                    SpinBox {
                        id: upperLimitSpin
                        from: 0
                        to: 10000
                        value: root.upperLimit
                        stepSize: 10
                        editable: true
                        Layout.fillWidth: true

                        background: Rectangle {
                            color: "#34495e"
                            radius: 5
                            border.color: upperLimitSpin.activeFocus ? "#3498db" : "#7f8c8d"
                            border.width: 1
                        }

                        contentItem: TextInput {
                            text: upperLimitSpin.textFromValue(upperLimitSpin.value, upperLimitSpin.locale)
                            font.pixelSize: 13
                            color: "#ecf0f1"
                            horizontalAlignment: Qt.AlignHCenter
                            verticalAlignment: Qt.AlignVCenter
                            readOnly: !upperLimitSpin.editable
                            validator: upperLimitSpin.validator
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }
                    }
                }

                // Lower Limit
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    visible: typeCombo.currentIndex === 0

                    Text {
                        text: "下限值:"
                        font.pixelSize: 14
                        color: "#95a5a6"
                        Layout.preferredWidth: 120
                    }

                    SpinBox {
                        id: lowerLimitSpin
                        from: 0
                        to: 10000
                        value: root.lowerLimit
                        stepSize: 10
                        editable: true
                        Layout.fillWidth: true

                        background: Rectangle {
                            color: "#34495e"
                            radius: 5
                            border.color: lowerLimitSpin.activeFocus ? "#3498db" : "#7f8c8d"
                            border.width: 1
                        }

                        contentItem: TextInput {
                            text: lowerLimitSpin.textFromValue(lowerLimitSpin.value, lowerLimitSpin.locale)
                            font.pixelSize: 13
                            color: "#ecf0f1"
                            horizontalAlignment: Qt.AlignHCenter
                            verticalAlignment: Qt.AlignVCenter
                            readOnly: !lowerLimitSpin.editable
                            validator: lowerLimitSpin.validator
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }
                    }
                }

                // Range
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    visible: typeCombo.currentIndex === 0

                    Text {
                        text: "量程:"
                        font.pixelSize: 14
                        color: "#95a5a6"
                        Layout.preferredWidth: 120
                    }

                    SpinBox {
                        id: rangeSpin
                        from: 1
                        to: 10000
                        value: root.range
                        stepSize: 10
                        editable: true
                        Layout.fillWidth: true

                        background: Rectangle {
                            color: "#34495e"
                            radius: 5
                            border.color: rangeSpin.activeFocus ? "#3498db" : "#7f8c8d"
                            border.width: 1
                        }

                        contentItem: TextInput {
                            text: rangeSpin.textFromValue(rangeSpin.value, rangeSpin.locale)
                            font.pixelSize: 13
                            color: "#ecf0f1"
                            horizontalAlignment: Qt.AlignHCenter
                            verticalAlignment: Qt.AlignVCenter
                            readOnly: !rangeSpin.editable
                            validator: rangeSpin.validator
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }
                    }
                }

                // Rated Value (only for "速度" protection)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    visible: typeCombo.currentIndex === 0 && root.protectionName === "速度"

                    Text {
                        text: "额定值:"
                        font.pixelSize: 14
                        color: "#95a5a6"
                        Layout.preferredWidth: 120
                    }

                    SpinBox {
                        id: ratedValueSpin
                        from: 0
                        to: 10000
                        value: root.ratedValue
                        stepSize: 10
                        editable: true
                        Layout.fillWidth: true

                        background: Rectangle {
                            color: "#34495e"
                            radius: 5
                            border.color: ratedValueSpin.activeFocus ? "#3498db" : "#7f8c8d"
                            border.width: 1
                        }

                        contentItem: TextInput {
                            text: ratedValueSpin.textFromValue(ratedValueSpin.value, ratedValueSpin.locale)
                            font.pixelSize: 13
                            color: "#ecf0f1"
                            horizontalAlignment: Qt.AlignHCenter
                            verticalAlignment: Qt.AlignVCenter
                            readOnly: !ratedValueSpin.editable
                            validator: ratedValueSpin.validator
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }
                    }
                }

                // Unit selection (for analog types)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    visible: typeCombo.currentIndex === 0

                    Text {
                        text: "单位:"
                        font.pixelSize: 14
                        color: "#95a5a6"
                        Layout.preferredWidth: 120
                    }

                    ComboBox {
                        id: unitCombo
                        Layout.fillWidth: true

                        model: ["m/s", "T", "℃", "kW", "A", "V", "MPa", "%"]
                        editable: true
                        currentIndex: {
                            var idx = model.indexOf(root.unit)
                            return idx >= 0 ? idx : 0
                        }

                        background: Rectangle {
                            color: "#34495e"
                            radius: 5
                            border.color: unitCombo.pressed ? "#3498db" : "#7f8c8d"
                            border.width: 1
                        }

                        contentItem: TextInput {
                            text: unitCombo.editable ? unitCombo.editText : unitCombo.displayText
                            font.pixelSize: 13
                            color: "#ecf0f1"
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 10
                            readOnly: !unitCombo.editable
                            selectByMouse: true
                        }
                    }
                }

                // Protection Delay
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "保护延时(秒):"
                        font.pixelSize: 14
                        color: "#95a5a6"
                        Layout.preferredWidth: 120
                    }

                    SpinBox {
                        id: delaySpin
                        from: 0
                        to: 60
                        value: root.protectionDelay * 10
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

                // Play Count
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "播放次数:"
                        font.pixelSize: 14
                        color: "#95a5a6"
                        Layout.preferredWidth: 120
                    }

                    SpinBox {
                        id: playCountSpin
                        from: 1
                        to: 99
                        value: root.playCount
                        editable: true
                        Layout.fillWidth: true

                        background: Rectangle {
                            color: "#34495e"
                            radius: 5
                            border.color: playCountSpin.activeFocus ? "#3498db" : "#7f8c8d"
                            border.width: 1
                        }

                        contentItem: TextInput {
                            text: playCountSpin.textFromValue(playCountSpin.value, playCountSpin.locale)
                            font.pixelSize: 13
                            color: "#ecf0f1"
                            horizontalAlignment: Qt.AlignHCenter
                            verticalAlignment: Qt.AlignVCenter
                            readOnly: !playCountSpin.editable
                            validator: playCountSpin.validator
                            inputMethodHints: Qt.ImhFormattedNumbersOnly

                            onActiveFocusChanged: {
                                if (activeFocus) {
                                    scrollView.ensureVisible(playCountSpin)
                                }
                            }
                        }
                    }
                }

                // Play Duration
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "播放时长(秒):"
                        font.pixelSize: 14
                        color: "#95a5a6"
                        Layout.preferredWidth: 120
                    }

                    SpinBox {
                        id: durationSpin
                        from: 1
                        to: 600
                        value: root.playDuration * 10
                        stepSize: 5
                        editable: true
                        Layout.fillWidth: true

                        property int decimals: 1
                        property real realValue: value / 10

                        textFromValue: function(value, locale) {
                            return Number(value / 10).toLocaleString(locale, 'f', 1)
                        }

                        valueFromText: function(text, locale) {
                            return Number.fromLocaleString(locale, text) * 10
                        }

                        background: Rectangle {
                            color: "#34495e"
                            radius: 5
                            border.color: durationSpin.activeFocus ? "#3498db" : "#7f8c8d"
                            border.width: 1
                        }

                        contentItem: TextInput {
                            text: durationSpin.textFromValue(durationSpin.value, durationSpin.locale)
                            font.pixelSize: 13
                            color: "#ecf0f1"
                            horizontalAlignment: Qt.AlignHCenter
                            verticalAlignment: Qt.AlignVCenter
                            readOnly: !durationSpin.editable
                            validator: durationSpin.validator
                            inputMethodHints: Qt.ImhFormattedNumbersOnly

                            onActiveFocusChanged: {
                                if (activeFocus) {
                                    scrollView.ensureVisible(durationSpin)
                                }
                            }
                        }
                    }
                }

                // Voice Alarm Type Selection
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "语音报警:"
                        font.pixelSize: 14
                        color: "#95a5a6"
                        Layout.preferredWidth: 120
                    }

                    RadioButton {
                        id: ttsRadio
                        text: "文字转语音"
                        checked: root.useTextToSpeech
                        font.pixelSize: 13

                        indicator: Rectangle {
                            implicitWidth: 20
                            implicitHeight: 20
                            x: ttsRadio.leftPadding
                            y: parent.height / 2 - height / 2
                            radius: 10
                            border.color: ttsRadio.checked ? "#00d4ff" : "#7f8c8d"
                            border.width: 2
                            color: "transparent"

                            Rectangle {
                                width: 10
                                height: 10
                                x: 5
                                y: 5
                                radius: 5
                                color: "#00d4ff"
                                visible: ttsRadio.checked
                            }
                        }

                        contentItem: Text {
                            text: ttsRadio.text
                            font: ttsRadio.font
                            color: "#ecf0f1"
                            leftPadding: ttsRadio.indicator.width + 8
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    RadioButton {
                        id: fileRadio
                        text: "音频文件"
                        checked: !root.useTextToSpeech
                        font.pixelSize: 13

                        indicator: Rectangle {
                            implicitWidth: 20
                            implicitHeight: 20
                            x: fileRadio.leftPadding
                            y: parent.height / 2 - height / 2
                            radius: 10
                            border.color: fileRadio.checked ? "#00d4ff" : "#7f8c8d"
                            border.width: 2
                            color: "transparent"

                            Rectangle {
                                width: 10
                                height: 10
                                x: 5
                                y: 5
                                radius: 5
                                color: "#00d4ff"
                                visible: fileRadio.checked
                            }
                        }

                        contentItem: Text {
                            text: fileRadio.text
                            font: fileRadio.font
                            color: "#ecf0f1"
                            leftPadding: fileRadio.indicator.width + 8
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                // Text to Speech Input
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    visible: ttsRadio.checked

                    Text {
                        text: "报警文字:"
                        font.pixelSize: 14
                        color: "#95a5a6"
                        Layout.preferredWidth: 120
                    }

                    TextField {
                        id: ttsTextField
                        text: root.ttsText
                        placeholderText: "输入报警文字内容..."
                        Layout.fillWidth: true

                        background: Rectangle {
                            color: "#34495e"
                            radius: 5
                            border.color: ttsTextField.activeFocus ? "#3498db" : "#7f8c8d"
                            border.width: 1
                        }

                        color: "#ecf0f1"
                        font.pixelSize: 13

                        onFocusChanged: {
                            if (focus) {
                                scrollView.ensureVisible(ttsTextField)
                            }
                        }
                    }
                }

                // Audio File Selection
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    visible: fileRadio.checked

                    Text {
                        text: "音频文件:"
                        font.pixelSize: 14
                        color: "#95a5a6"
                        Layout.preferredWidth: 120
                    }

                    TextField {
                        id: audioField
                        text: root.audioFile
                        placeholderText: "选择音频文件..."
                        Layout.fillWidth: true
                        readOnly: true

                        background: Rectangle {
                            color: "#34495e"
                            radius: 5
                            border.color: "#7f8c8d"
                            border.width: 1
                        }

                        color: "#ecf0f1"
                        font.pixelSize: 13
                    }

                    Button {
                        text: "浏览"
                        Layout.preferredWidth: 60

                        background: Rectangle {
                            color: parent.pressed ? "#2980b9" : (parent.hovered ? "#3498db" : "#34495e")
                            radius: 5
                            border.color: "#3498db"
                            border.width: 1
                        }

                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 12
                            color: "#ecf0f1"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            fileDialog.open()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#00d4ff"
                    opacity: 0.3
                }

                // Popup Animation Setting
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "弹窗效果:"
                        font.pixelSize: 14
                        color: "#95a5a6"
                        Layout.preferredWidth: 120
                    }

                    CheckBox {
                        id: animationCheckbox
                        checked: root.enablePopupAnimation
                        text: "启用飞行动画"
                        font.pixelSize: 13

                        indicator: Rectangle {
                            implicitWidth: 20
                            implicitHeight: 20
                            x: animationCheckbox.leftPadding
                            y: parent.height / 2 - height / 2
                            radius: 3
                            border.color: animationCheckbox.checked ? "#00d4ff" : "#7f8c8d"
                            border.width: 2
                            color: "transparent"

                            Rectangle {
                                width: 12
                                height: 12
                                x: 4
                                y: 4
                                radius: 2
                                color: "#00d4ff"
                                visible: animationCheckbox.checked
                            }
                        }

                        contentItem: Text {
                            text: animationCheckbox.text
                            font: animationCheckbox.font
                            color: "#ecf0f1"
                            leftPadding: animationCheckbox.indicator.width + 8
                            verticalAlignment: Text.AlignVCenter
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
                    root.protectionName = nameField.text
                    root.protectionType = typeCombo.currentIndex === 0 ? "analog" : "digital"
                    root.upperLimit = upperLimitSpin.value
                    root.lowerLimit = lowerLimitSpin.value
                    root.range = rangeSpin.value
                    root.ratedValue = ratedValueSpin.value
                    root.protectionDelay = delaySpin.realValue
                    root.playCount = playCountSpin.value
                    root.playDuration = durationSpin.realValue
                    root.moduleType = moduleTypeCombo.currentText
                    root.channelNumber = channelSpin.value
                    root.useTextToSpeech = ttsRadio.checked
                    root.ttsText = ttsTextField.text
                    root.audioFile = audioField.text
                    root.unit = unitCombo.editable ? unitCombo.editText : unitCombo.displayText
                    root.enablePopupAnimation = animationCheckbox.checked

                    root.accepted()
                    closeWithAnimation()
                }
            }

            Button {
                text: "删除"
                visible: !root.isNewProtection
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

    // File Dialog for audio file selection
    Popup {
        id: fileDialog
        width: 500
        height: 400
        modal: true
        anchors.centerIn: Overlay.overlay

        background: Rectangle {
            color: "#2c3e50"
            radius: 10
            border.color: "#00d4ff"
            border.width: 2
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 10

            Text {
                text: "选择音频文件"
                font.pixelSize: 16
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

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    model: ListModel {
                        ListElement { fileName: "alarm_high.wav" }
                        ListElement { fileName: "alarm_low.wav" }
                        ListElement { fileName: "warning.wav" }
                        ListElement { fileName: "emergency.wav" }
                        ListElement { fileName: "fault.wav" }
                    }

                    delegate: Rectangle {
                        width: parent ? parent.width : 0
                        height: 40
                        color: mouseArea.containsMouse ? "#34495e" : "transparent"
                        radius: 5

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: model.fileName
                            color: "#ecf0f1"
                            font.pixelSize: 13
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                audioField.text = model.fileName
                                fileDialog.close()
                            }
                        }
                    }
                }
            }

            Button {
                text: "取消"
                Layout.alignment: Qt.AlignRight
                Layout.preferredWidth: 80
                Layout.preferredHeight: 35

                background: Rectangle {
                    color: parent.pressed ? "#7f8c8d" : (parent.hovered ? "#95a5a6" : "#7f8c8d")
                    radius: 5
                }

                contentItem: Text {
                    text: parent.text
                    font.pixelSize: 13
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: fileDialog.close()
            }
        }
    }

    // Public functions
    function openForEdit(name, type, srcItem) {
        root.isNewProtection = false
        root.protectionName = name
        root.protectionType = type
        root.sourceItem = srcItem

        // Load existing values (in real app, these would come from backend)
        root.upperLimit = 100
        root.lowerLimit = 0
        root.range = 100
        root.ratedValue = 50
        root.protectionDelay = 1.0
        root.playCount = 3
        root.playDuration = 5.0
        root.moduleType = "输入模块"
        root.channelNumber = 1
        root.useTextToSpeech = true
        root.ttsText = name + "保护报警"
        root.audioFile = "alarm_high.wav"

        // Set appropriate unit based on protection name
        if (name === "速度") {
            root.unit = "m/s"
        } else if (name === "张力") {
            root.unit = "T"
        } else if (name === "温度") {
            root.unit = "℃"
        } else {
            root.unit = "m/s"
        }

        openWithAnimation()
    }

    function openForNew(srcItem) {
        root.isNewProtection = true
        root.protectionName = "新保护"
        root.protectionType = "analog"
        root.upperLimit = 100
        root.lowerLimit = 0
        root.range = 100
        root.ratedValue = 50
        root.protectionDelay = 1.0
        root.playCount = 3
        root.playDuration = 5.0
        root.moduleType = "输入模块"
        root.channelNumber = 1
        root.useTextToSpeech = true
        root.ttsText = ""
        root.audioFile = ""
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
