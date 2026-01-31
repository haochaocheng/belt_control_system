import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15  // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.11.1]: 添加 Layouts 导入
import "../" as DeviceInfo  // ✅ 2026-01-30 [FIX 100.300.109 Phase 2]: 导入 NavigationManager

// ✅ 2026-01-25 [电机控制参数设置] 电机控制主页面（左右分栏布局）
// ✅ 2026-01-25 [FIX 100.311]: 重构为模块化设计，支持键盘操作
// ✅ 2026-01-25 [FIX 100.312]: 添加背景图片预留位置
// ✅ 2026-01-25 [FIX 100.314]: 修复QDS预览问题，使用Loader加载组件
// ✅ 2026-01-30 [FIX 100.300.109 Phase 2]: 集成 NavigationManager，实现平面导航
Rectangle {
    id: root
    // ✅ 2026-01-26 [FIX 100.300.25.12]: 使用 implicitWidth/Height 替代固定尺寸，确保运行时正确显示
    implicitWidth: 1000  // 默认宽度（用于QDS预览）
    implicitHeight: 600  // 默认高度（用于QDS预览）
    color: "transparent"

    // ========== 公开属性 ==========
    property int deviceId: 1
    property string deviceName: "1号皮带"
    property int currentMotorIndex: 0  // 当前选中的电机索引 (0-7)

    // ✅ 2026-01-30 [FIX 100.300.106]: 导航焦点索引
    // ✅ 2026-01-30 [FIX 100.300.106.2]: 修正 focusSubArea 定义
    // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.11]: 添加 focusButtonIndex
    property int focusItemIndex: -1  // -1 表示无焦点
    property int focusSubArea: 0  // 0:电机列表区域 1:Tab区域 2:参数区域 3:按钮区域
    property int focusTabIndex: 0  // Tab区域焦点索引
    property int focusParamIndex: 0  // 参数区域焦点索引
    property int focusButtonIndex: 0  // 按钮区域焦点索引 (0-4)

    // ✅ 2026-01-30 [FIX 100.300.106]: Qt 虚拟键盘引用
    property var virtualKeyboard: null

    // ✅ 2026-01-30 [FIX 100.300.109 Phase 2]: NavigationManager 实例
    DeviceInfo.NavigationManager {
        id: navigationManager

        // 初始化：从电机列表区开始
        Component.onCompleted: {
            currentArea = areaMotorList
            motorListIndex = 0
            tabIndex = 0
            paramIndex = 0
            buttonIndex = 0
            console.log("✅ [MotorControlPage] NavigationManager 初始化完成")

            // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.1]: 立即同步初始状态到root
            root.currentMotorIndex = 0
            root.focusItemIndex = 0
            root.focusSubArea = 0
            root.focusTabIndex = 0
            root.focusParamIndex = 0
            console.log("✅ [MotorControlPage] 初始状态已同步 - focusItemIndex:", root.focusItemIndex)
        }

        // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.5]: 修复信号处理器参数问题
        // QML 自动生成的属性变化信号不传递参数，直接使用属性值

        // 监听电机列表索引变化
        onMotorListIndexChanged: {
            console.log("✅ [MotorControlPage] 电机列表索引变化:", motorListIndex)
            root.currentMotorIndex = motorListIndex
            root.focusItemIndex = motorListIndex
        }

        // 监听Tab索引变化，切换参数区显示
        onTabIndexChanged: {
            console.log("✅ [MotorControlPage] Tab索引变化:", tabIndex, "参数区自动切换显示")
            root.focusTabIndex = tabIndex
            // 切换Tab时，参数区自动显示对应的参数
            if (motorConfigPanel.item) {
                motorConfigPanel.item.currentTabIndex = tabIndex
            }
        }

        // 监听参数索引变化
        onParamIndexChanged: {
            console.log("✅ [MotorControlPage] 参数索引变化:", paramIndex)
            root.focusParamIndex = paramIndex
        }

        // 监听按钮索引变化
        onButtonIndexChanged: {
            console.log("✅ [MotorControlPage] 按钮索引变化:", buttonIndex)
            // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.11]: 同步按钮焦点索引
            root.focusButtonIndex = buttonIndex
        }

        // 监听区域变化
        onAreaChanged: function(newArea) {
            console.log("✅ [MotorControlPage] 区域变化:", newArea)
            // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.8]: 清除其他区域的焦点指示器
            // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.11]: 添加按钮区域焦点处理
            // 根据区域更新 focusSubArea，并清除其他区域的焦点索引
            switch(newArea) {
            case areaMotorList:
                root.focusSubArea = 0
                root.focusItemIndex = motorListIndex
                // 清除其他区域的焦点
                root.focusTabIndex = -1
                root.focusParamIndex = -1
                root.focusButtonIndex = -1
                break
            case areaTabBar:
                root.focusSubArea = 1
                root.focusTabIndex = tabIndex
                // 清除其他区域的焦点
                root.focusItemIndex = -1
                root.focusParamIndex = -1
                root.focusButtonIndex = -1
                break
            case areaParams:
                root.focusSubArea = 2
                root.focusParamIndex = paramIndex
                // 清除其他区域的焦点
                root.focusItemIndex = -1
                root.focusTabIndex = -1
                root.focusButtonIndex = -1
                break
            case areaButtons:
                root.focusSubArea = 3
                root.focusButtonIndex = buttonIndex
                // 清除其他区域的焦点
                root.focusItemIndex = -1
                root.focusTabIndex = -1
                root.focusParamIndex = -1
                break
            }
        }

        // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.8]: 监听返回到类别信号
        onReturnToCategory: {
            console.log("✅ [MotorControlPage] 返回到左侧类别")
            // 发出信号通知 DeviceSettingsDialog 返回到左侧类别
            root.requestReturnToCategory()
        }
    }

    // ========== 背景装饰图片（预留位置，可在QDS中替换）==========
    Image {
        id: backgroundImage
        anchors.fill: parent
        source: ""  // 预留：在QDS中设置装饰图片路径
        fillMode: Image.Stretch
        z: -1  // 确保在所有内容下方
        visible: source != ""  // 只有设置了图片才显示
    }

    // ✅ 2026-01-30 [FIX 100.300.106]: 允许接收焦点，以便虚拟键盘关闭后焦点可以返回
    focus: true
    activeFocusOnTab: true

    // ✅ 2026-01-30 [FIX 100.300.109 Phase 2]: 使用 NavigationManager 处理键盘事件
    // ✅ 平面导航逻辑：只用方向键，不用Enter/Esc/Tab
    Keys.onUpPressed: {
        navigationManager.handleDirectionKey("Up")
        event.accepted = true
    }

    Keys.onDownPressed: {
        navigationManager.handleDirectionKey("Down")
        event.accepted = true
    }

    Keys.onLeftPressed: {
        navigationManager.handleDirectionKey("Left")
        event.accepted = true
    }

    Keys.onRightPressed: {
        navigationManager.handleDirectionKey("Right")
        event.accepted = true
    }

    // ✅ 2026-01-30 [FIX 100.300.106]: 旧的键盘导航支持（已废弃，注释掉）
    // Keys.onPressed: {
    //     // 将键盘事件转发给子组件
    //     if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
    //         motorListPanel.item.focus = true
    //     } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
    //         motorConfigPanel.item.focus = true
    //     }
    // }

    // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.11]: 改为 ColumnLayout，添加底部按钮区域
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ========== 上部：左右分栏布局 ==========
        Row {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ========== 左侧：电机列表（使用Loader加载）==========
            Loader {
                id: motorListPanel
                // ✅ 2026-01-26 [FIX 100.300.25.16]: 统一列表宽度为 240，与开关量/模拟量一致
                width: 240  // 从 200 改为 240
                height: parent.height
                source: "MyMotorListPanel.qml"

                onLoaded: {
                    item.currentMotorIndex = Qt.binding(function() { return root.currentMotorIndex })
                    // ✅ 2026-01-30 [FIX 100.300.106]: 传递焦点索引
                    item.focusItemIndex = Qt.binding(function() { return root.focusItemIndex })
                    item.motorSelected.connect(function(motorIndex) {
                        root.currentMotorIndex = motorIndex
                        console.log("选中电机:", motorIndex + 1)
                    })
                }
            }

            // ========== 分隔线 ==========
            Rectangle {
                width: 2
                height: parent.height
                color: "#3d4556"
            }

            // ========== 右侧：电机配置面板（使用Loader加载）==========
            Loader {
                id: motorConfigPanel
                width: parent.width - motorListPanel.width - 2
                height: parent.height
                source: "MotorConfigPanel.qml"

                onLoaded: {
                    item.motorIndex = Qt.binding(function() { return root.currentMotorIndex })
                    // ✅ 2026-01-30 [FIX 100.300.106]: 传递焦点索引和虚拟键盘
                    // ✅ 2026-01-30 [FIX 100.300.106.2]: 直接传递 focusSubArea
                    item.focusSubArea = Qt.binding(function() { return root.focusSubArea })
                    item.focusTabIndex = Qt.binding(function() { return root.focusTabIndex })
                    item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                    item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
                }
            }
        }

        // ========== 底部：按钮区域 ==========
        // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.11]: 添加底部按钮区域
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 90  // 两行按钮，每行35高度 + 间距
            color: "#1a1f2e"

            // 装饰边框
            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 2
                color: "#00d4ff"
                opacity: 0.3
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                // 第一行：添加输入、删除输入
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Button {
                        id: addInputButton
                        text: "添加输入"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35

                        background: Rectangle {
                            color: parent.pressed ? "#27ae60" : (parent.hovered ? "#2ecc71" : "#27ae60")
                            radius: 4
                            border.width: root.focusSubArea === 3 && root.focusButtonIndex === 0 ? 2 : 0
                            border.color: "#2196F3"
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
                            console.log("✅ [MotorControlPage] 添加输入")
                            // TODO: 实现添加输入功能
                        }
                    }

                    Button {
                        id: deleteInputButton
                        text: "删除输入"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35

                        background: Rectangle {
                            color: parent.pressed ? "#c0392b" : (parent.hovered ? "#e74c3c" : "#d35400")
                            radius: 4
                            border.width: root.focusSubArea === 3 && root.focusButtonIndex === 1 ? 2 : 0
                            border.color: "#2196F3"
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
                            console.log("✅ [MotorControlPage] 删除输入")
                            // TODO: 实现删除输入功能
                        }
                    }
                }

                // 第二行：保存、删除、重置
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Button {
                        id: saveButton
                        text: "保存"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35

                        background: Rectangle {
                            color: parent.pressed ? "#27ae60" : (parent.hovered ? "#2ecc71" : "#27ae60")
                            radius: 4
                            border.width: root.focusSubArea === 3 && root.focusButtonIndex === 2 ? 2 : 0
                            border.color: "#2196F3"
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
                            console.log("✅ [MotorControlPage] 保存")
                            // TODO: 实现保存功能
                        }
                    }

                    Button {
                        id: deleteButton
                        text: "删除"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35

                        background: Rectangle {
                            color: parent.pressed ? "#c0392b" : (parent.hovered ? "#e74c3c" : "#d35400")
                            radius: 4
                            border.width: root.focusSubArea === 3 && root.focusButtonIndex === 3 ? 2 : 0
                            border.color: "#2196F3"
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
                            console.log("✅ [MotorControlPage] 删除")
                            // TODO: 实现删除功能
                        }
                    }

                    Button {
                        id: resetButton
                        text: "重置"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35

                        background: Rectangle {
                            color: parent.pressed ? "#7f8c8d" : (parent.hovered ? "#95a5a6" : "#7f8c8d")
                            radius: 4
                            border.width: root.focusSubArea === 3 && root.focusButtonIndex === 4 ? 2 : 0
                            border.color: "#2196F3"
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
                            console.log("✅ [MotorControlPage] 重置")
                            // TODO: 实现重置功能
                        }
                    }
                }
            }
        }
    }

    // ✅ 2026-01-30 [FIX 100.300.106]: 导航函数
    // 获取参数字段数量
    function getParamFieldCount() {
        var currentTab = motorConfigPanel.item ? motorConfigPanel.item.getCurrentTab() : null
        if (currentTab && typeof currentTab.getParamFieldCount === "function") {
            return currentTab.getParamFieldCount()
        }
        return 0
    }

    // 触发参数输入
    function triggerParamInput(paramIndex) {
        console.log("✅ [MotorControlPage] 触发参数输入 - 索引:", paramIndex)

        var currentTab = motorConfigPanel.item ? motorConfigPanel.item.getCurrentTab() : null
        if (currentTab && typeof currentTab.triggerParamInput === "function") {
            currentTab.triggerParamInput(paramIndex)
        } else {
            console.log("⚠️ [MotorControlPage] 当前 Tab 不支持参数输入")
        }
    }

    // 切换 Tab
    function triggerTabSwitch(tabIndex) {
        console.log("✅ [MotorControlPage] 切换 Tab - 索引:", tabIndex)
        if (motorConfigPanel.item) {
            motorConfigPanel.item.currentTabIndex = tabIndex
        }
    }

    // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.8]: 公开信号，供 DeviceSettingsDialog 监听
    signal requestReturnToCategory()  // 请求返回到左侧类别

    // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.4]: 公开键盘事件处理函数
    // 供DeviceSettingsDialog调用，转发键盘事件给NavigationManager
    function handleKeyPress(direction) {
        console.log("✅ [MotorControlPage] 接收键盘事件:", direction)
        navigationManager.handleDirectionKey(direction)
    }
}
