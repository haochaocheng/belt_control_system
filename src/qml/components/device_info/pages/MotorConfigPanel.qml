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

    // ✅ 2026-02-02 [FIX 100.300.112.8.24.8]: 信号 - 请求更新焦点索引
    // 从子组件（BasicConfigTab 等）转发到父组件（MotorControlPage）
    signal requestFocusParamIndex(int paramIndex)

    // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.3]: 移除旧的键盘导航支持
    // 原因：与 NavigationManager 冲突，导致导航逻辑不正确
    // 现在由 MotorControlPage 的 NavigationManager 统一处理键盘事件
    // ========== 旧的键盘导航支持（已废弃，注释掉）==========
    // focus: true
    //
    // Keys.onLeftPressed: {
    //     if (root.currentTabIndex > 0) {
    //         root.currentTabIndex--
    //     }
    // }
    //
    // Keys.onRightPressed: {
    //     if (root.currentTabIndex < 9) {  // 10个Tab (0-9)
    //         root.currentTabIndex++
    //     }
    // }

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
        // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.7]: 添加自动滚动到当前Tab
        Flickable {
            id: tabFlickable
            anchors.fill: parent
            clip: true
            contentWidth: tabRow.width  // 内容宽度
            contentHeight: height  // 内容高度等于自身高度（不需要纵向滚动）
            flickableDirection: Flickable.HorizontalFlick  // 只允许横向滑动
            boundsBehavior: Flickable.StopAtBounds  // 到达边界时停止

            // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.7]: 自动滚动到当前Tab
            function scrollToTab(tabIndex) {
                if (tabIndex < 0) return

                // 每个Tab宽度120，计算目标Tab的位置
                var tabWidth = 120
                var targetX = tabIndex * tabWidth

                // 计算需要滚动到的位置，使目标Tab居中显示
                var centerX = targetX - (width / 2) + (tabWidth / 2)

                // 限制在有效范围内
                centerX = Math.max(0, Math.min(centerX, contentWidth - width))

                // 平滑滚动到目标位置
                contentX = centerX
            }

            // 监听 currentTabIndex 变化，自动滚动
            Connections {
                target: root
                function onCurrentTabIndexChanged() {
                    tabFlickable.scrollToTab(root.currentTabIndex)
                }
            }

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
                    // ✅ 2026-03-10 [Phase 7.48.29]: 从10个Tab扩展到14个Tab（新增4种保护类型）
                    // ✅ 2026-03-13 [Phase 7.48.43]: A/B/C→甲/乙/丙，X/Y→水平/垂直（TTS中文兼容）
                    // 旧：["基本配置", "电流保护", "前轴承温度", "后轴承温度", "A相绕组", "B相绕组", "C相绕组", "电机温度", "X轴振动", "Y轴振动", ...]
                    model: ["基本配置", "电流保护", "前轴承温度", "后轴承温度", "甲相绕组", "乙相绕组", "丙相绕组", "电机温度", "水平振动", "垂直振动", "堵转保护", "起动超时", "功率保护", "三相不平衡"]

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

            // 0: 基本配置（保持不变）
            Loader {
                id: basicConfigLoader
                active: root.currentTabIndex === 0
                source: "BasicConfigTab.qml"
                onLoaded: {
                    if (item) {
                        // ✅ 2026-03-10 [Phase 7.48.36]: 改为Qt.binding，确保切换电机时motorIndex同步更新
                        // 旧：item.motorIndex = root.motorIndex（赋值，不跟踪变化）
                        item.motorIndex = Qt.binding(function() { return root.motorIndex })
                        item.deviceId = 1  // ✅ 2026-03-10 [Phase 7.48.33]: 传递设备ID
                        item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                        item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
                        item.requestFocusParamIndex.connect(function(paramIndex) {
                            root.requestFocusParamIndex(paramIndex)
                        })
                    }
                }
            }

            // ✅ 2026-03-10 [Phase 7.48.29]: Tab 1-13 全部使用统一的 MotorProtectionTab.qml
            // 旧：9个独立Loader（CurrentProtectionTab, FrontBearingTempTab 等）
            // 新：13个统一Loader，通过属性传入不同默认值

            // 1: 电流保护
            Loader {
                id: tab1Loader
                active: root.currentTabIndex === 1
                source: "MotorProtectionTab.qml"
                onLoaded: {
                    if (item) {
                        item.tabIndex = 1; item.protectionName = "电流保护"
                        item.defaultUnit = "A"; item.defaultUpperLimit = 80; item.defaultLowerLimit = 0
                        item.defaultRange = 100; item.defaultInputType = "4-20mA电流型"
                        item.defaultProtectionDelay = 30; item.defaultFilterDelay = 5.0
                        item.defaultProtectionLevel = 3; item.defaultSprinklerEnabled = false
                        item.motorIndex = root.motorIndex; item.deviceId = 1
                        item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                        item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
                        item.requestFocusParamIndex.connect(function(pi) { root.requestFocusParamIndex(pi) })
                    }
                }
            }

            // 2: 前轴承温度
            Loader {
                id: tab2Loader
                active: root.currentTabIndex === 2
                source: "MotorProtectionTab.qml"
                onLoaded: {
                    if (item) {
                        item.tabIndex = 2; item.protectionName = "前轴承温度"
                        item.defaultUnit = "℃"; item.defaultUpperLimit = 60; item.defaultLowerLimit = 0
                        item.defaultRange = 150; item.defaultInputType = "PT100热电阻"
                        item.defaultProtectionDelay = 50; item.defaultFilterDelay = 10.0
                        item.defaultProtectionLevel = 3; item.defaultSprinklerEnabled = true
                        item.motorIndex = root.motorIndex; item.deviceId = 1
                        item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                        item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
                        item.requestFocusParamIndex.connect(function(pi) { root.requestFocusParamIndex(pi) })
                    }
                }
            }

            // 3: 后轴承温度
            Loader {
                id: tab3Loader
                active: root.currentTabIndex === 3
                source: "MotorProtectionTab.qml"
                onLoaded: {
                    if (item) {
                        item.tabIndex = 3; item.protectionName = "后轴承温度"
                        item.defaultUnit = "℃"; item.defaultUpperLimit = 60; item.defaultLowerLimit = 0
                        item.defaultRange = 150; item.defaultInputType = "PT100热电阻"
                        item.defaultProtectionDelay = 50; item.defaultFilterDelay = 10.0
                        item.defaultProtectionLevel = 3; item.defaultSprinklerEnabled = true
                        item.motorIndex = root.motorIndex; item.deviceId = 1
                        item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                        item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
                        item.requestFocusParamIndex.connect(function(pi) { root.requestFocusParamIndex(pi) })
                    }
                }
            }

            // 4: A相绕组
            Loader {
                id: tab4Loader
                active: root.currentTabIndex === 4
                source: "MotorProtectionTab.qml"
                onLoaded: {
                    if (item) {
                        item.tabIndex = 4; item.protectionName = "甲相绕组"
                        item.defaultUnit = "℃"; item.defaultUpperLimit = 130; item.defaultLowerLimit = 0
                        item.defaultRange = 200; item.defaultInputType = "PT100热电阻"
                        item.defaultProtectionDelay = 50; item.defaultFilterDelay = 10.0
                        item.defaultProtectionLevel = 3; item.defaultSprinklerEnabled = false
                        item.motorIndex = root.motorIndex; item.deviceId = 1
                        item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                        item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
                        item.requestFocusParamIndex.connect(function(pi) { root.requestFocusParamIndex(pi) })
                    }
                }
            }

            // 5: B相绕组
            Loader {
                id: tab5Loader
                active: root.currentTabIndex === 5
                source: "MotorProtectionTab.qml"
                onLoaded: {
                    if (item) {
                        item.tabIndex = 5; item.protectionName = "乙相绕组"
                        item.defaultUnit = "℃"; item.defaultUpperLimit = 130; item.defaultLowerLimit = 0
                        item.defaultRange = 200; item.defaultInputType = "PT100热电阻"
                        item.defaultProtectionDelay = 50; item.defaultFilterDelay = 10.0
                        item.defaultProtectionLevel = 3; item.defaultSprinklerEnabled = false
                        item.motorIndex = root.motorIndex; item.deviceId = 1
                        item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                        item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
                        item.requestFocusParamIndex.connect(function(pi) { root.requestFocusParamIndex(pi) })
                    }
                }
            }

            // 6: C相绕组
            Loader {
                id: tab6Loader
                active: root.currentTabIndex === 6
                source: "MotorProtectionTab.qml"
                onLoaded: {
                    if (item) {
                        item.tabIndex = 6; item.protectionName = "丙相绕组"
                        item.defaultUnit = "℃"; item.defaultUpperLimit = 130; item.defaultLowerLimit = 0
                        item.defaultRange = 200; item.defaultInputType = "PT100热电阻"
                        item.defaultProtectionDelay = 50; item.defaultFilterDelay = 10.0
                        item.defaultProtectionLevel = 3; item.defaultSprinklerEnabled = false
                        item.motorIndex = root.motorIndex; item.deviceId = 1
                        item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                        item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
                        item.requestFocusParamIndex.connect(function(pi) { root.requestFocusParamIndex(pi) })
                    }
                }
            }

            // 7: 电机温度
            Loader {
                id: tab7Loader
                active: root.currentTabIndex === 7
                source: "MotorProtectionTab.qml"
                onLoaded: {
                    if (item) {
                        item.tabIndex = 7; item.protectionName = "电机温度"
                        item.defaultUnit = "℃"; item.defaultUpperLimit = 80; item.defaultLowerLimit = 0
                        item.defaultRange = 150; item.defaultInputType = "PT100热电阻"
                        item.defaultProtectionDelay = 50; item.defaultFilterDelay = 10.0
                        item.defaultProtectionLevel = 2; item.defaultSprinklerEnabled = true
                        item.motorIndex = root.motorIndex; item.deviceId = 1
                        item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                        item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
                        item.requestFocusParamIndex.connect(function(pi) { root.requestFocusParamIndex(pi) })
                    }
                }
            }

            // 8: X轴振动
            Loader {
                id: tab8Loader
                active: root.currentTabIndex === 8
                source: "MotorProtectionTab.qml"
                onLoaded: {
                    if (item) {
                        item.tabIndex = 8; item.protectionName = "水平振动"
                        item.defaultUnit = "mm/s"; item.defaultUpperLimit = 7; item.defaultLowerLimit = 0
                        item.defaultRange = 20; item.defaultInputType = "4-20mA电流型"
                        item.defaultProtectionDelay = 100; item.defaultFilterDelay = 20.0
                        item.defaultProtectionLevel = 2; item.defaultSprinklerEnabled = false
                        item.motorIndex = root.motorIndex; item.deviceId = 1
                        item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                        item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
                        item.requestFocusParamIndex.connect(function(pi) { root.requestFocusParamIndex(pi) })
                    }
                }
            }

            // 9: Y轴振动
            Loader {
                id: tab9Loader
                active: root.currentTabIndex === 9
                source: "MotorProtectionTab.qml"
                onLoaded: {
                    if (item) {
                        item.tabIndex = 9; item.protectionName = "垂直振动"
                        item.defaultUnit = "mm/s"; item.defaultUpperLimit = 7; item.defaultLowerLimit = 0
                        item.defaultRange = 20; item.defaultInputType = "4-20mA电流型"
                        item.defaultProtectionDelay = 100; item.defaultFilterDelay = 20.0
                        item.defaultProtectionLevel = 2; item.defaultSprinklerEnabled = false
                        item.motorIndex = root.motorIndex; item.deviceId = 1
                        item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                        item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
                        item.requestFocusParamIndex.connect(function(pi) { root.requestFocusParamIndex(pi) })
                    }
                }
            }

            // 10: 堵转保护
            Loader {
                id: tab10Loader
                active: root.currentTabIndex === 10
                source: "MotorProtectionTab.qml"
                onLoaded: {
                    if (item) {
                        item.tabIndex = 10; item.protectionName = "堵转保护"
                        item.defaultUnit = "A"; item.defaultUpperLimit = 500; item.defaultLowerLimit = 0
                        item.defaultRange = 1000; item.defaultInputType = "4-20mA电流型"
                        item.defaultProtectionDelay = 80; item.defaultFilterDelay = 5.0
                        item.defaultProtectionLevel = 3; item.defaultSprinklerEnabled = false
                        item.motorIndex = root.motorIndex; item.deviceId = 1
                        item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                        item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
                        item.requestFocusParamIndex.connect(function(pi) { root.requestFocusParamIndex(pi) })
                    }
                }
            }

            // 11: 起动超时
            Loader {
                id: tab11Loader
                active: root.currentTabIndex === 11
                source: "MotorProtectionTab.qml"
                onLoaded: {
                    if (item) {
                        item.tabIndex = 11; item.protectionName = "起动超时"
                        item.defaultUnit = "A"; item.defaultUpperLimit = 300; item.defaultLowerLimit = 0
                        item.defaultRange = 500; item.defaultInputType = "4-20mA电流型"
                        item.defaultProtectionDelay = 300; item.defaultFilterDelay = 10.0
                        item.defaultProtectionLevel = 3; item.defaultSprinklerEnabled = false
                        item.motorIndex = root.motorIndex; item.deviceId = 1
                        item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                        item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
                        item.requestFocusParamIndex.connect(function(pi) { root.requestFocusParamIndex(pi) })
                    }
                }
            }

            // 12: 功率保护
            Loader {
                id: tab12Loader
                active: root.currentTabIndex === 12
                source: "MotorProtectionTab.qml"
                onLoaded: {
                    if (item) {
                        item.tabIndex = 12; item.protectionName = "功率保护"
                        item.defaultUnit = "kW"; item.defaultUpperLimit = 150; item.defaultLowerLimit = 10
                        item.defaultRange = 500; item.defaultInputType = "4-20mA电流型"
                        item.defaultProtectionDelay = 100; item.defaultFilterDelay = 20.0
                        item.defaultProtectionLevel = 2; item.defaultSprinklerEnabled = false
                        item.motorIndex = root.motorIndex; item.deviceId = 1
                        item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                        item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
                        item.requestFocusParamIndex.connect(function(pi) { root.requestFocusParamIndex(pi) })
                    }
                }
            }

            // 13: 三相不平衡
            Loader {
                id: tab13Loader
                active: root.currentTabIndex === 13
                source: "MotorProtectionTab.qml"
                onLoaded: {
                    if (item) {
                        item.tabIndex = 13; item.protectionName = "三相不平衡"
                        item.defaultUnit = "%"; item.defaultUpperLimit = 30; item.defaultLowerLimit = 0
                        item.defaultRange = 100; item.defaultInputType = "4-20mA电流型"
                        item.defaultProtectionDelay = 100; item.defaultFilterDelay = 20.0
                        item.defaultProtectionLevel = 2; item.defaultSprinklerEnabled = false
                        item.motorIndex = root.motorIndex; item.deviceId = 1
                        item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                        item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
                        item.requestFocusParamIndex.connect(function(pi) { root.requestFocusParamIndex(pi) })
                    }
                }
            }
        }
    }

    // ✅ 2026-03-10 [Phase 7.48.29]: 更新 getCurrentTab，支持 Tab 0-13
    // 旧：switch case 0-9
    function getCurrentTab() {
        switch(root.currentTabIndex) {
        case 0:
            return basicConfigLoader.item
        case 1:
            return tab1Loader.item
        case 2:
            return tab2Loader.item
        case 3:
            return tab3Loader.item
        case 4:
            return tab4Loader.item
        case 5:
            return tab5Loader.item
        case 6:
            return tab6Loader.item
        case 7:
            return tab7Loader.item
        case 8:
            return tab8Loader.item
        case 9:
            return tab9Loader.item
        case 10:
            return tab10Loader.item
        case 11:
            return tab11Loader.item
        case 12:
            return tab12Loader.item
        case 13:
            return tab13Loader.item
        default:
            return null
        }
    }
}
