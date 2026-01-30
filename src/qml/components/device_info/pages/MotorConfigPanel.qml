import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// ✅ 2026-01-25 [电机控制-右侧面板] 电机配置面板（Tab切换）
// ✅ 2026-01-28 [虚拟键盘集成]: 接收并传递键盘管理器
Rectangle {
    id: root
    width: 800  // 默认宽度（用于QDS预览）
    height: 600  // 默认高度（用于QDS预览）
    // ✅ 2026-01-26 [FIX 100.300.25.15]: 改为透明背景，与开关量/模拟量页面统一
    color: "transparent"  // 从 "#1a1f2e" 改为 "transparent"

    // ========== 公开属性 ==========
    property int motorIndex: 0  // 当前电机索引 (0-7)
    property int currentTabIndex: 0  // 当前Tab索引
    // ✅ 2026-01-28 [虚拟键盘]: 键盘管理器属性（已废弃）
    // property var keyboardManager: null

    // ✅ 2026-01-30 [FIX 100.300.106]: 导航焦点索引（从父页面传递）
    // ✅ 2026-01-30 [FIX 100.300.106.2]: 修正 focusSubArea 定义
    // focusSubArea 从 MotorControlPage 传递过来：
    // - 0: 焦点在电机列表（不在此组件内，不显示焦点）
    // - 1: 焦点在 Tab 区域（显示 Tab 焦点指示器）
    // - 2: 焦点在参数区域（显示参数焦点指示器）
    property int focusSubArea: 0  // 0:电机列表 1:Tab区域 2:参数区域
    property int focusTabIndex: 0  // Tab区域焦点索引
    property int focusParamIndex: 0  // 参数区域焦点索引
    property var virtualKeyboard: null  // Qt 虚拟键盘引用

    // ========== 键盘导航支持 ==========
    focus: true

    Keys.onLeftPressed: {
        if (root.currentTabIndex > 0) {
            root.currentTabIndex--
        }
    }

    Keys.onRightPressed: {
        if (root.currentTabIndex < 9) {  // 10个Tab (0-9)
            root.currentTabIndex++
        }
    }

    // ========== 标题栏 ==========
    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 50
        // ✅ 2026-01-26 [FIX 100.300.25.21]: 改为透明，使用背景图片
        color: "transparent"
        border.color: "transparent"
        border.width: 0

        // ✅ 2026-01-26 [FIX 100.300.25.21]: 添加背景图片，填充整个 header
        Image {
            id: headerBackground
            anchors.fill: parent
            source: "../images/059.png"
            fillMode: Image.Stretch  // 拉伸填充整个 header
            z: -1  // 放在最底层
        }

        Text {
            anchors.centerIn: parent
            text: (root.motorIndex + 1) + "号电机配置"
            font.pixelSize: 16
            font.weight: Font.Bold
            color: "#E0E0E0"
        }
    }

    // ========== Tab栏 ==========
    Rectangle {
        id: tabBar
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 50
        color: "#252b3d"
        border.color: "#3d4556"
        border.width: 1

        // ✅ 使用 Flickable 支持横向滑动（Tab较多时）
        // ✅ 2026-01-26 [FIX 100.300.21.1]: 改用 Flickable 支持鼠标拖动和滚轮滑动
        Flickable {
            id: tabFlickable
            anchors.fill: parent
            clip: true
            contentWidth: tabRow.width  // 内容宽度
            contentHeight: height  // 内容高度等于自身高度（不需要纵向滚动）
            flickableDirection: Flickable.HorizontalFlick  // 只允许横向滑动
            boundsBehavior: Flickable.StopAtBounds  // 到达边界时停止

            // ✅ 2026-01-26 [FIX]: 支持鼠标滚轮横向滚动
            MouseArea {
                anchors.fill: parent
                propagateComposedEvents: true  // 传递事件给子元素

                onWheel: {
                    // 将纵向滚轮转换为横向滚动
                    var delta = wheel.angleDelta.y
                    tabFlickable.contentX = Math.max(0, Math.min(
                        tabFlickable.contentX - delta,
                        tabFlickable.contentWidth - tabFlickable.width
                    ))
                    wheel.accepted = true
                }

                // 不拦截点击事件，让子元素的 MouseArea 处理
                onPressed: mouse.accepted = false
            }

            Row {
                id: tabRow
                spacing: 0
                height: parent.height
                // ✅ 2026-01-26 [FIX]: 明确设置宽度，确保 Flickable 知道需要滚动
                width: childrenRect.width

                Repeater {
                    model: ["基本配置", "电流保护", "前轴承温度", "后轴承温度", "A相绕组", "B相绕组", "C相绕组", "电机温度", "X轴振动", "Y轴振动"]

                    Rectangle {
                        id: rectangle
                        width: 120
                        height: 50
                        // ✅ 2026-01-26 [FIX 100.300.25.20]: 改为透明，使用背景图片
                        color: "transparent"
                        border.color: "transparent"
                        border.width: 0

                        // ✅ 2026-01-30 [FIX 100.300.106]: 焦点指示器
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: (root.focusSubArea === 1 && root.focusTabIndex === index) ? "#2196F3" : "transparent"
                            border.width: (root.focusSubArea === 1 && root.focusTabIndex === index) ? 3 : 0
                            radius: 4
                            z: 11  // 确保在背景图片之上
                        }

                        // ✅ 2026-01-26 [FIX 100.300.25.20]: 添加背景图片
                        Image {
                            id: buttonBackgroundImage
                            anchors.fill: parent
                            fillMode: Image.Stretch
                            z: -1  // 放在最底层

                            // ✅ 2026-01-26 [FIX 100.300.25.20.1]: 修正路径（向上一级到 device_info，然后进入 images）
                            source: "../images/DJHeadbutton1.png"

                            states: [
                                State {
                                    name: "selected"
                                    when: root.currentTabIndex === index
                                    PropertyChanges {
                                        target: buttonBackgroundImage
                                        source: "../images/DJHeadbutton2.png"
                                    }
                                },
                                State {
                                    name: "normal"
                                    when: root.currentTabIndex !== index
                                    PropertyChanges {
                                        target: buttonBackgroundImage
                                        source: "../images/DJHeadbutton1.png"
                                    }
                                }
                            ]
                        }

                        // ✅ 底部激活指示条（保留，增强视觉效果）
                        Rectangle {
                            visible: root.currentTabIndex === index
                            width: parent.width
                            height: 3
                            color: "#2196F3"
                            anchors.bottom: parent.bottom
                        }

                        Text {

                            text: modelData
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 45
                            font.pixelSize: 14
                            font.weight: root.currentTabIndex === index ? Font.Bold : Font.Normal
                            color: root.currentTabIndex === index ? "#E0E0E0" : "#9E9E9E"
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.currentTabIndex = index
                                root.focus = true  // 获取焦点以支持键盘操作
                            }
                        }
                    }
                }
            }

            // ✅ 2026-01-26 [FIX]: 添加横向滚动条指示器
            Rectangle {
                id: scrollIndicator
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                height: 3
                width: parent.width * (parent.width / tabRow.width)
                color: "#2196F3"
                opacity: 0.5
                x: tabFlickable.contentX * (parent.width / tabRow.width)
                visible: tabRow.width > parent.width  // 只在需要滚动时显示
            }
        }
    }

    // ========== 内容区域 ==========
    Rectangle {
        id: contentArea
        anchors.top: tabBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: "transparent"

        StackLayout {
            anchors.fill: parent
            currentIndex: root.currentTabIndex

            // 0: 基本配置
            Loader {
                id: basicConfigLoader
                active: root.currentTabIndex === 0
                source: "BasicConfigTab.qml"

                onLoaded: {
                    if (item) {
                        item.motorIndex = root.motorIndex
                        // ✅ 2026-01-28 [虚拟键盘]: 键盘管理器已废弃
                        // item.keyboardManager = root.keyboardManager
                        // ✅ 2026-01-30 [FIX 100.300.106]: 传递焦点索引和虚拟键盘
                        item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                        item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
                    }
                }
            }

            // 1: 电流保护
            Loader {
                id: currentProtectionLoader
                active: root.currentTabIndex === 1
                source: "CurrentProtectionTab.qml"

                onLoaded: {
                    if (item) {
                        item.motorIndex = root.motorIndex
                        // ✅ 2026-01-30 [FIX 100.300.106]: 传递焦点索引和虚拟键盘
                        item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                        item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
                    }
                }
            }

            // 2: 前轴承温度
            Loader {
                id: frontBearingTempLoader
                active: root.currentTabIndex === 2
                source: "FrontBearingTempTab.qml"
                onLoaded: {
                    if (item) {
                        item.motorIndex = root.motorIndex
                        // ✅ 2026-01-30 [FIX 100.300.106]: 传递焦点索引和虚拟键盘
                        item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                        item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
                    }
                }
            }

            // 3: 后轴承温度
            Loader {
                active: root.currentTabIndex === 3
                source: "RearBearingTempTab.qml"
                onLoaded: {
                    if (item) {
                        item.motorIndex = root.motorIndex
                        item.keyboardManager = root.keyboardManager  // ✅ 2026-01-28 [虚拟键盘]: 传递键盘管理器
                    }
                }
            }

            // 4: A相绕组
            Loader {
                active: root.currentTabIndex === 4
                source: "PhaseAWindingTab.qml"
                onLoaded: {
                    if (item) {
                        item.motorIndex = root.motorIndex
                        item.keyboardManager = root.keyboardManager  // ✅ 2026-01-28 [虚拟键盘]: 传递键盘管理器
                    }
                }
            }

            // 5: B相绕组
            Loader {
                active: root.currentTabIndex === 5
                source: "PhaseBWindingTab.qml"
                onLoaded: {
                    if (item) {
                        item.motorIndex = root.motorIndex
                        item.keyboardManager = root.keyboardManager  // ✅ 2026-01-28 [虚拟键盘]: 传递键盘管理器
                    }
                }
            }

            // 6: C相绕组
            Loader {
                active: root.currentTabIndex === 6
                source: "PhaseCWindingTab.qml"
                onLoaded: {
                    if (item) {
                        item.motorIndex = root.motorIndex
                        item.keyboardManager = root.keyboardManager  // ✅ 2026-01-28 [虚拟键盘]: 传递键盘管理器
                    }
                }
            }

            // 7: 电机温度
            Loader {
                active: root.currentTabIndex === 7
                source: "MotorTempTab.qml"
                onLoaded: {
                    if (item) {
                        item.motorIndex = root.motorIndex
                        item.keyboardManager = root.keyboardManager  // ✅ 2026-01-28 [虚拟键盘]: 传递键盘管理器
                    }
                }
            }

            // 8: X轴振动
            Loader {
                active: root.currentTabIndex === 8
                source: "XAxisVibrationTab.qml"
                onLoaded: {
                    if (item) {
                        item.motorIndex = root.motorIndex
                        item.keyboardManager = root.keyboardManager  // ✅ 2026-01-28 [虚拟键盘]: 传递键盘管理器
                    }
                }
            }

            // 9: Y轴振动
            Loader {
                active: root.currentTabIndex === 9
                source: "YAxisVibrationTab.qml"
                onLoaded: {
                    if (item) {
                        item.motorIndex = root.motorIndex
                        item.keyboardManager = root.keyboardManager  // ✅ 2026-01-28 [虚拟键盘]: 传递键盘管理器
                    }
                }
            }
        }
    }

    // ✅ 2026-01-30 [FIX 100.300.106]: 获取当前 Tab 的引用
    function getCurrentTab() {
        switch(root.currentTabIndex) {
        case 0:
            return basicConfigLoader.item
        case 1:
            return currentProtectionLoader.item
        case 2:
            return frontBearingTempLoader.item
        // TODO: 其他 Tab
        default:
            return null
        }
    }
}
