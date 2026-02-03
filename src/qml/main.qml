import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.VirtualKeyboard 6.5
import Qt5Compat.GraphicalEffects
import "components/sip_phone"

ApplicationWindow {
    id: root
    visible: true
    // Auto-detect screen resolution for proper fullscreen display
    // Device 151 (EGLFS): 1920x1080
    // Device 155 (X11): 1280x800
    width: Screen.width > 0 ? Screen.width : 1920
    height: Screen.height > 0 ? Screen.height : 1080
    title: "Belt Control System"

    // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.15]: 添加虚拟键盘高度属性
    // 原因：CustomSpinBox 需要这个属性来计算准确的滚动距离
    property real virtualKeyboardHeight: 600  // 固定高度，与 InputPanel 的 height 一致

    // ✅ Windows platform: Prevent window from being maximized
    minimumWidth: Qt.platform.os === "windows" ? 1920 : 0
    minimumHeight: Qt.platform.os === "windows" ? 1080 : 0
    maximumWidth: Qt.platform.os === "windows" ? 1920 : 65535
    maximumHeight: Qt.platform.os === "windows" ? 1080 : 65535

    // For X11 mode (Device 155): Make fullscreen to hide window decorations and taskbar
    // EGLFS mode (Device 151) naturally has no window decorations
    // Windows platform: Use windowed mode (1920x1080) for development
    // Use screen width to detect device: 1280=Device155(X11), 1920=Device151(EGLFS)
    Component.onCompleted: {
        console.log("[FULLSCREEN DEBUG] Screen size:", Screen.width, "x", Screen.height)
        console.log("[FULLSCREEN DEBUG] Window size:", width, "x", height)
        console.log("[FULLSCREEN DEBUG] Current visibility:", visibility)
        console.log("[FULLSCREEN DEBUG] Platform:", Qt.platform.os)

        // ✅ Windows platform: Always use windowed mode (1920x1080)
        if (Qt.platform.os === "windows") {
            visibility = Window.Windowed
            // Center the window on screen
            x = (Screen.width - width) / 2
            y = (Screen.height - height) / 2
            console.log("[FULLSCREEN DEBUG] Windows platform detected, using windowed mode 1920x1080")
            console.log("[FULLSCREEN DEBUG] Window positioned at:", x, y)
            return
        }

        // Device 155 has screen width 1280 (rotated from 800x1280)
        // Device 151 has screen width 1920
        if (Screen.width === 1280 || Screen.height === 1280) {
            visibility = Window.FullScreen
            console.log("[FULLSCREEN DEBUG] Device 155 (1280x800) detected, set to fullscreen")
        } else if (Screen.width === 1920 || Screen.height === 1920) {
            console.log("[FULLSCREEN DEBUG] Device 151 (1920x1080) detected, EGLFS naturally fullscreen")
        } else {
            console.log("[FULLSCREEN DEBUG] Unknown screen size, trying fullscreen anyway")
            visibility = Window.FullScreen
        }
    }

    // ✅ MOVED keyboardOverlay to Overlay.overlay layer - see Loader below
    // This ensures it's in the same hierarchy as InputPanel and won't block events

    App {
        id: mainApp
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: dummyInputPanel.top
        z: 1
    }

    // ✅ Dummy InputPanel for layout calculations
    Item {
        id: dummyInputPanel
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: Qt.inputMethod.visible ? Qt.inputMethod.keyboardRectangle.height : 0
    }

    // ✅ CRITICAL: Both keyboardOverlay and InputPanel in Overlay.overlay
    // This ensures they're in the same hierarchy and keyboardOverlay won't block InputPanel events
    Loader {
        id: keyboardLoader
        active: true  // Always active to ensure initialization
        asynchronous: false  // Synchronous loading to ensure immediate availability

        sourceComponent: Item {
            id: keyboardContainerItem
            // Wrapper Item containing both keyboard overlay and InputPanel
            parent: Overlay.overlay
            anchors.fill: parent ? parent : undefined
            z: 1  // ✅ 默认 z 值，会动态调整

            Component.onCompleted: {
                console.log("========================================")
                console.log("🔧 [Keyboard Container] Initialized in Overlay")
                console.log("   - parent:", parent)
                console.log("   - parent is Overlay:", parent === Overlay.overlay)
                console.log("   - Initial z-index:", z, "⬅️ Will be dynamically adjusted")
                console.log("========================================")
            }

            // ✅ 监听虚拟键盘显示/隐藏
            Connections {
                target: Qt.inputMethod
                function onVisibleChanged() {
                    if (Qt.inputMethod.visible) {
                        console.log("⌨️ [Keyboard] Visible changed to TRUE")
                        adjustKeyboardZIndex()
                    } else {
                        console.log("⌨️ [Keyboard] Visible changed to FALSE")
                        // 键盘隐藏时恢复默认 z 值
                        keyboardContainerItem.z = 1
                        console.log("   - Reset z to:", keyboardContainerItem.z)
                    }
                }
            }

            // ✅ 动态调整键盘 z 值的函数
            function adjustKeyboardZIndex() {
                console.log("🔍 [Dynamic Z] Searching for active input...")

                // ✅ 获取当前焦点元素 - 使用 Overlay.overlay 的方式
                var focusItem = null

                // 方法1: 通过 parent 找到 ApplicationWindow
                var parentItem = keyboardContainerItem.parent
                while (parentItem) {
                    if (parentItem.activeFocusItem !== undefined) {
                        focusItem = parentItem.activeFocusItem
                        console.log("   ✅ Found activeFocusItem via parent chain")
                        break
                    }
                    parentItem = parentItem.parent
                }

                if (!focusItem) {
                    console.log("   ⚠️ No active focus item found")
                    keyboardContainerItem.z = 20000  // 默认高 z 值
                    return
                }

                console.log("   ✅ Found focus item:", focusItem)
                console.log("      - Type:", focusItem.toString())

                // 遍历父级链，找到最高的 z 值
                var maxZ = 0
                var item = focusItem
                var level = 0

                while (item && level < 50) {
                    if (item.z !== undefined && item.z > maxZ) {
                        maxZ = item.z
                        console.log("      - Level", level, "z:", item.z, "=>", item.toString())
                    }
                    item = item.parent
                    level++
                }

                // 设置键盘 z 为输入框层级 + 10000
                var newZ = maxZ + 10000
                console.log("   🎯 Max z found:", maxZ)
                console.log("   ✅ Setting keyboard z to:", newZ, "(maxZ + 10000)")

                keyboardContainerItem.z = newZ
            }

            // ✅ Keyboard Overlay - 覆盖键盘上方区域，点击即关闭键盘
            // ⚠️ 但要避免拦截 Dialog 内的点击！
            MouseArea {
                id: keyboardOverlay
                anchors.left: parent ? parent.left : undefined
                anchors.right: parent ? parent.right : undefined
                anchors.top: parent ? parent.top : undefined
                height: parent ? (parent.height - Qt.inputMethod.keyboardRectangle.height) : 0
                z: 3  // ✅ CRITICAL: 在容器内，高于 InputPanel wrapper (z:2)
                visible: false  // ✅ CRITICAL: 禁用主界面的 keyboardOverlay，改用 Dialog 内的！
                enabled: false  // ✅ CRITICAL: 完全禁用，避免拦截 Dialog 事件！
                propagateComposedEvents: true  // ✅ CRITICAL: 允许事件穿透到下层元素（如 TextField）

                Component.onCompleted: {
                    console.log("=========================================")
                    console.log("🔥🔥🔥 VERSION: 2025-12-19-07:00 DYNAMIC-Z 🔥🔥🔥")
                    console.log("🛡️ [Main keyboardOverlay] DISABLED - using Dialog overlay instead")
                    console.log("   - z-index:", z, "(parent container z:", parent.z, "- DYNAMIC)")
                    console.log("   - visible:", visible, "(SHOULD be false)")
                    console.log("   - enabled:", enabled, "(SHOULD be false)")
                    console.log("=========================================")
                }

                onVisibleChanged: {
                    if (visible) {
                        console.log("🛡️ [keyboardOverlay] Visible changed to true")
                        console.log("   - Height:", height)
                        console.log("   - Keyboard height:", Qt.inputMethod.keyboardRectangle.height)
                        console.log("   - z:", z, "enabled:", enabled)
                    }
                }

                onPressed: function(mouse) {
                    console.log("=====================================")
                    console.log("🛡️🛡️🛡️ [Main keyboardOverlay] 👇 PRESSED")
                    console.log("   - Position:", mouse.x, mouse.y)
                    console.log("   - z-index:", z)
                    console.log("   - enabled:", enabled)
                    console.log("   - visible:", visible)
                    console.log("   - mouse.accepted BEFORE:", mouse.accepted)
                    // ✅ CRITICAL: 不要 accept，让事件继续传播到下层（TextField 等）
                    mouse.accepted = false
                    console.log("   - mouse.accepted AFTER:", mouse.accepted)
                    console.log("   - Event should propagate to lower layers")
                    console.log("=====================================")
                }

                onClicked: function(mouse) {
                    console.log("=====================================")
                    console.log("🛡️🛡️🛡️ [Main keyboardOverlay] 🖱️ CLICKED")
                    console.log("   - Position:", mouse.x, mouse.y)
                    console.log("   - Keyboard visible:", Qt.inputMethod.visible)
                    console.log("   ✅ Closing keyboard from main keyboardOverlay")

                    // 点击键盘上方任意位置，关闭键盘
                    Qt.inputMethod.commit()
                    Qt.inputMethod.hide()

                    // ✅ Accept 事件防止进一步传播
                    mouse.accepted = true
                    console.log("   - Keyboard should be closed now")
                    console.log("=====================================")
                }
            }

            // ✅ InputPanel - the actual virtual keyboard
            Item {
                anchors.left: parent ? parent.left : undefined
                anchors.right: parent ? parent.right : undefined
                anchors.bottom: parent ? parent.bottom : undefined
                height: 600  // Fixed height for keyboard
                z: 2  // Above keyboardOverlay (z:1)
                visible: Qt.inputMethod.visible

                Component.onCompleted: {
                    console.log("========================================")
                    console.log("🔧 [Keyboard Wrapper] Initialized")
                    console.log("   - z-index:", z, "(above keyboardOverlay)")
                    console.log("   - width:", width)
                    console.log("   - height:", height)
                    console.log("========================================")
                }

                // ✅ DEBUG: MouseArea to intercept all keyboard events and log them
                MouseArea {
                    id: keyboardDebugArea
                    anchors.fill: parent
                    z: -1  // Below InputPanel but captures events if InputPanel doesn't
                    enabled: true
                    propagateComposedEvents: true

                    Component.onCompleted: {
                        console.log("🖱️ [Keyboard Debug MouseArea] Initialized")
                        console.log("   - Size:", width, "x", height)
                        console.log("   - Z-index:", z)
                        console.log("   - Enabled:", enabled)
                    }

                    onPressed: function(mouse) {
                        console.log("🖱️🖱️🖱️ [Keyboard Debug] 👇👇👇 PRESSED at:", mouse.x, mouse.y)
                        console.log("   - MouseArea size:", width, "x", height)
                        console.log("   - MouseArea z:", z)
                        console.log("   - MouseArea enabled:", enabled)
                        console.log("   - mouse.accepted BEFORE:", mouse.accepted)
                        mouse.accepted = false  // Let it propagate
                    }

                    onReleased: function(mouse) {
                        console.log("🖱️🖱️🖱️ [Keyboard Debug] 👆👆👆 RELEASED at:", mouse.x, mouse.y)
                        mouse.accepted = false
                    }

                    onClicked: function(mouse) {
                        console.log("🖱️🖱️🖱️ [Keyboard Debug] 🖱️🖱️🖱️ CLICKED at:", mouse.x, mouse.y)
                        console.log("   ❗❗❗ This means the click reached this MouseArea")
                        console.log("   ❗❗❗ It should have been captured by InputPanel first!")
                        mouse.accepted = false
                    }

                    onEnabledChanged: {
                        console.log("🖱️ [Keyboard Debug MouseArea] Enabled changed:", enabled)
                    }

                    onVisibleChanged: {
                        console.log("🖱️ [Keyboard Debug MouseArea] Visible changed:", visible)
                    }
                }

                InputPanel {
                    id: virtualKeyboard
                    anchors.fill: parent
                    z: 1  // Above the debug MouseArea
                    visible: Qt.inputMethod.visible
                    enabled: true

                    Component.onCompleted: {
                        console.log("========================================")
                        console.log("⌨️ [InputPanel] Virtual keyboard initialized")
                        console.log("   - parent:", parent)
                        console.log("   - z-index:", z)
                        console.log("   - width:", width)
                        console.log("   - height:", height)
                        console.log("   - enabled:", enabled)
                        console.log("   - visible:", visible)
                        console.log("========================================")
                    }

                    onVisibleChanged: {
                        console.log("⌨️ [InputPanel] Visibility changed:", visible)
                    }

                    onEnabledChanged: {
                        console.log("⌨️ [InputPanel] Enabled changed:", enabled)
                    }

                    // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.15]: 添加 ESC 键处理
                    // 原因：用户按 ESC 键时，虚拟键盘应该关闭
                    Shortcut {
                        sequence: "Escape"
                        enabled: Qt.inputMethod.visible
                        onActivated: {
                            console.log("⌨️ [InputPanel] ESC 键按下，关闭虚拟键盘")
                            Qt.inputMethod.hide()
                        }
                    }
                }
            }
        }
    }

    // VoIP Button - Must be at top level to avoid being blocked by keyboard overlay
    Button {
        id: sipPhoneButton
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 20
        anchors.rightMargin: 20
        width: 80
        height: 80
        z: 999  // High z-index to be above keyboard overlay

        property bool isHovered: false

        background: Rectangle {
            color: sipPhoneButton.pressed ? "#1e7e34" : (sipPhoneButton.isHovered ? "#27ae60" : "#218838")
            radius: 40
            border.color: "#00ff88"
            border.width: 3

            // Glow effect
            Rectangle {
                anchors.fill: parent
                anchors.margins: -5
                color: "transparent"
                border.color: "#00ff88"
                border.width: 2
                radius: 45
                opacity: 0.5
                z: -1
            }

            // Pulsing animation
            SequentialAnimation on opacity {
                running: true
                loops: Animation.Infinite
                NumberAnimation { from: 0.8; to: 1.0; duration: 1000; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 1.0; to: 0.8; duration: 1000; easing.type: Easing.InOutQuad }
            }
        }

        contentItem: Text {
            text: "📞"
            font.pixelSize: 40
            color: "white"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        onClicked: {
            // Open SIP phone popup
            console.log("SIP button clicked, opening SIP popup...")
            sipPopup.open()
        }

        HoverHandler {
            onHoveredChanged: sipPhoneButton.isHovered = hovered
        }

        // Tooltip
        ToolTip {
            visible: sipPhoneButton.isHovered
            text: "SIP 语音电话"
            delay: 500

            background: Rectangle {
                color: "#2c3e50"
                radius: 5
                border.color: "#00d4ff"
                border.width: 1
            }

            contentItem: Text {
                text: parent.text
                color: "#00d4ff"
                font.pixelSize: 12
            }
        }
    }

    // SIP Phone Popup
    Popup {
        id: sipPopup
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: Math.min(800, parent.width * 0.85)
        height: parent.height * 0.9
        modal: true
        closePolicy: Popup.CloseOnEscape
        z: 10000  // Very high z-index

        onOpened: {
            console.log("SIP Popup opened successfully")
            console.log("Popup size:", width, "x", height)
        }

        onClosed: {
            console.log("SIP Popup closed")
        }

        background: Rectangle {
            color: "#1a1a2e"
            radius: 15
            border.color: "#00d4ff"
            border.width: 2

            // Shadow effect
            layer.enabled: true
            layer.effect: DropShadow {
                transparentBorder: true
                horizontalOffset: 0
                verticalOffset: 4
                radius: 16
                samples: 33
                color: "#80000000"
            }
        }

        SipMainPage {
            anchors.fill: parent
        }

        // Close button
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 15
            anchors.rightMargin: 15
            width: 40
            height: 40
            radius: 20
            color: closeMouseArea.containsMouse ? "#e74c3c" : "#c0392b"
            z: 1000

            Text {
                anchors.centerIn: parent
                text: "✕"
                font.pixelSize: 20
                font.bold: true
                color: "white"
            }

            MouseArea {
                id: closeMouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: sipPopup.close()
            }
        }
    }
}
