// SerialPortConfigPanel.qml
// 串口配置面板
// ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37]: 完全重构，采用 Tab 架构（参考 MotorConfigPanel）
// 原因：ScrollView 包裹所有区域导致焦点丢失，改为 Tab 切换，每个 Tab 内部独立管理滚动
// 创建日期: 2026-02-04

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "transparent"

    // ========== 公开属性 ==========
    property var currentSerialPort: null  // 当前串口信息

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37]: 新增 Tab 相关属性
    property int currentTabIndex: 0  // 当前 Tab 索引（0=参数配置, 1=发送区, 2=接收区, 3=MODBUS寄存器）

    // 焦点管理属性
    property int focusSubArea: 0  // 0=列表 1=Tab栏 2=参数 3=按钮
    property int focusTabIndex: -1  // Tab 焦点索引
    property int focusParamIndex: -1  // 参数焦点索引

    // 虚拟键盘引用
    property var virtualKeyboard: null

    // ========== 信号 ==========
    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37]: 添加焦点请求信号
    signal requestFocusParamIndex(int paramIndex)

    // ========== 辅助函数 ==========
    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9.3]: 获取当前Tab的item
    function getCurrentTabItem() {
        switch(currentTabIndex) {
        case 0:  // 参数配置
            return paramsTabLoader.item
        case 1:  // 发送区
            return sendTabLoader.item
        case 2:  // 接收区
            return receiveTabLoader.item
        case 3:  // MODBUS寄存器
            return modbusTabLoader.item
        default:
            return null
        }
    }

    // ========== 组件加载完成 ==========
    Component.onCompleted: {
        console.log("✅ [SerialPortConfigPanel] Component.onCompleted 开始")
        console.log("✅ [SerialPortConfigPanel] currentSerialPort:", currentSerialPort)
        console.log("✅ [SerialPortConfigPanel] 使用 Tab 架构")
        console.log("✅ [SerialPortConfigPanel] Component.onCompleted 完成")
    }

    // ========== 监听串口变化 ==========
    onCurrentSerialPortChanged: {
        console.log("✅ [SerialPortConfigPanel] currentSerialPort 变化:", currentSerialPort)
        if (currentSerialPort) {
            console.log("   - 串口名称:", currentSerialPort.name)
            console.log("   - 设备路径:", currentSerialPort.path)
            console.log("   - 串口类型:", currentSerialPort.type)
        }
    }

    // ========== 标题栏 ==========
    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 50
        color: "transparent"

        // 背景图片
        Image {
            anchors.fill: parent
            source: "../images/059.png"
            fillMode: Image.Stretch
            z: -1
        }

        Text {
            anchors.centerIn: parent
            text: "串口配置"
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

        Flickable {
            id: tabFlickable
            anchors.fill: parent
            clip: true
            contentWidth: tabRow.width
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds

            // 自动滚动到当前Tab
            function scrollToTab(tabIndex) {
                var tabWidth = 120
                var targetX = tabIndex * tabWidth
                var centerX = targetX - (width / 2) + (tabWidth / 2)
                centerX = Math.max(0, Math.min(centerX, contentWidth - width))
                contentX = centerX
            }

            // 监听 currentTabIndex 变化
            Connections {
                target: root
                function onCurrentTabIndexChanged() {
                    tabFlickable.scrollToTab(root.currentTabIndex)
                }
            }

            // 支持鼠标滚轮横向滚动
            MouseArea {
                anchors.fill: parent
                propagateComposedEvents: true

                onWheel: {
                    var delta = wheel.angleDelta.y
                    tabFlickable.contentX = Math.max(0, Math.min(
                        tabFlickable.contentX - delta,
                        tabFlickable.contentWidth - tabFlickable.width
                    ))
                    wheel.accepted = true
                }

                onPressed: mouse.accepted = false
            }

            Row {
                id: tabRow
                spacing: 0
                height: parent.height
                width: childrenRect.width

                Repeater {
                    model: ["参数配置", "发送区", "接收区", "MODBUS寄存器"]

                    Rectangle {
                        width: 120
                        height: 50
                        color: "transparent"

                        // 焦点指示器
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: (root.focusSubArea === 1 && root.focusTabIndex === index)
                                          ? "#2196F3" : "transparent"
                            border.width: (root.focusSubArea === 1 && root.focusTabIndex === index) ? 3 : 0
                            radius: 4
                            z: 11
                        }

                        // 背景图片
                        Image {
                            anchors.fill: parent
                            fillMode: Image.Stretch
                            z: -1
                            source: root.currentTabIndex === index
                                    ? "../images/DJHeadbutton2.png"
                                    : "../images/DJHeadbutton1.png"
                        }

                        // 底部激活指示条
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
                                root.focus = true
                            }
                        }
                    }
                }
            }

            // 横向滚动条指示器
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                height: 3
                width: parent.width * (parent.width / tabRow.width)
                color: "#2196F3"
                opacity: 0.5
                x: tabFlickable.contentX * (parent.width / tabRow.width)
                visible: tabRow.width > parent.width
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

            // 0: 参数配置
            Loader {
                id: paramsTabLoader
                active: root.currentTabIndex === 0
                source: "SerialPortParamsTab.qml"  // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 2]: 使用新文件名

                onLoaded: {
                    console.log("✅ [SerialPortConfigPanel] SerialPortParamsTab 加载成功")
                    if (item) {
                        // 传递当前串口信息
                        item.currentSerialPort = Qt.binding(function() {
                            return root.currentSerialPort
                        })

                        // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 2]: 传递焦点索引
                        item.focusParamIndex = Qt.binding(function() {
                            return root.focusParamIndex
                        })

                        // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 2]: 传递虚拟键盘引用
                        item.virtualKeyboard = Qt.binding(function() {
                            return root.virtualKeyboard
                        })

                        // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 2]: 连接信号，转发焦点更新
                        item.requestFocusParamIndex.connect(function(paramIndex) {
                            root.requestFocusParamIndex(paramIndex)
                        })
                    }
                }
            }

            // 1: 发送区
            Loader {
                id: sendTabLoader
                active: root.currentTabIndex === 1
                source: "SerialPortSendTab.qml"  // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 3]: 使用新文件名

                onLoaded: {
                    console.log("✅ [SerialPortConfigPanel] SerialPortSendTab 加载成功")
                    if (item) {
                        // 传递当前串口信息
                        item.currentSerialPort = Qt.binding(function() {
                            return root.currentSerialPort
                        })

                        // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9.2]: 传递焦点索引
                        item.focusParamIndex = Qt.binding(function() {
                            return root.focusParamIndex
                        })

                        // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9.2]: 传递虚拟键盘引用
                        item.virtualKeyboard = Qt.binding(function() {
                            return root.virtualKeyboard
                        })

                        // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9.2]: 连接信号，转发焦点更新
                        item.requestFocusParamIndex.connect(function(paramIndex) {
                            root.requestFocusParamIndex(paramIndex)
                        })
                    }
                }
            }

            // 2: 接收区
            Loader {
                id: receiveTabLoader
                active: root.currentTabIndex === 2
                source: "SerialPortReceiveTab.qml"  // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 3]: 使用新文件名

                onLoaded: {
                    console.log("✅ [SerialPortConfigPanel] SerialPortReceiveTab 加载成功")
                    if (item) {
                        // 传递当前串口信息
                        item.currentSerialPort = Qt.binding(function() {
                            return root.currentSerialPort
                        })

                        // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9.7]: 传递焦点索引
                        item.focusParamIndex = Qt.binding(function() {
                            return root.focusParamIndex
                        })

                        // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9.7]: 传递虚拟键盘引用
                        item.virtualKeyboard = Qt.binding(function() {
                            return root.virtualKeyboard
                        })

                        // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9.7]: 连接信号，转发焦点更新
                        item.requestFocusParamIndex.connect(function(paramIndex) {
                            root.requestFocusParamIndex(paramIndex)
                        })
                    }
                }
            }

            // 3: MODBUS寄存器
            Loader {
                id: modbusTabLoader
                active: root.currentTabIndex === 3
                source: "ModbusRegisterTab.qml"  // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 3]: 使用新文件名

                onLoaded: {
                    console.log("✅ [SerialPortConfigPanel] ModbusRegisterTab 加载成功")
                    if (item) {
                        // 传递当前串口信息
                        item.currentSerialPort = Qt.binding(function() {
                            return root.currentSerialPort
                        })

                        // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.10.1]: 传递焦点索引
                        item.focusParamIndex = Qt.binding(function() {
                            return root.focusParamIndex
                        })

                        // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.10.1]: 传递虚拟键盘引用
                        item.virtualKeyboard = Qt.binding(function() {
                            return root.virtualKeyboard
                        })

                        // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.10.1]: 连接信号，转发焦点更新
                        item.requestFocusParamIndex.connect(function(paramIndex) {
                            root.requestFocusParamIndex(paramIndex)
                        })
                    }
                }
            }
        }
    }

    // ========== 获取当前 Tab 的引用 ==========
    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37]: 添加 getCurrentTab() 函数
    function getCurrentTab() {
        switch(root.currentTabIndex) {
        case 0:
            return paramsTabLoader.item
        case 1:
            return sendTabLoader.item
        case 2:
            return receiveTabLoader.item
        case 3:
            return modbusTabLoader.item
        default:
            return null
        }
    }

    // ========== 旧代码备份（2026-02-04 Phase 7.37 之前）==========
    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37]: 移除 ScrollView 架构
    // 原因：ScrollView 包裹所有 4 个区域导致 Qt 的 ensureVisible() 触发不必要的滚动
    // 旧代码：
    // ScrollView {
    //     id: scrollView
    //     anchors.fill: parent
    //     clip: true
    //     ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    //
    //     Connections {
    //         target: scrollView.contentItem
    //         function onContentYChanged() { ... }
    //         function onFlickStarted() { ... }
    //         function onFlickEnded() { ... }
    //         function onMovementStarted() { ... }
    //         function onMovementEnded() { ... }
    //         function onInteractiveChanged() { ... }
    //     }
    //
    //     ColumnLayout {
    //         width: scrollView.width
    //         spacing: 16
    //
    //         Loader { id: paramsSection; source: "SerialPortParamsSection.qml" }
    //         Loader { id: sendSection; source: "SerialPortSendSection.qml" }
    //         Loader { id: receiveSection; source: "SerialPortReceiveSection.qml" }
    //         Loader { id: modbusSection; source: "ModbusRegisterSection.qml" }
    //     }
    // }
    //
    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.5]: 暴露子区域的 Loader，供 triggerParamInput 访问
    // property alias paramsSection: paramsSection
    // property alias sendSection: sendSection
    // property alias receiveSection: receiveSection
    // property alias modbusSection: modbusSection
}
