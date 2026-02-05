import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../device_info" as DeviceInfo

// ✅ 2026-01-30 [FIX 100.300.109]: NavigationManager 测试页面
// 用于验证平面导航逻辑
Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#1e1e1e"
    focus: true

    // ========== NavigationManager 实例 ==========
    DeviceInfo.NavigationManager {
        id: navigationManager

        // 监听区域切换
        onAreaChanged: function(newArea) {
            console.log("✅ [测试] 区域切换:", newArea)
        }

        // 监听电机列表索引变化
        onMotorListIndexChanged: function(newIndex) {
            console.log("✅ [测试] 电机列表索引:", newIndex)
        }

        // 监听Tab索引变化
        onTabIndexChanged: function(newIndex) {
            console.log("✅ [测试] Tab索引:", newIndex)
            // 切换参数区显示
            paramStackLayout.currentIndex = newIndex
        }

        // 监听参数索引变化
        onParamIndexChanged: function(newIndex) {
            console.log("✅ [测试] 参数索引:", newIndex)
        }

        // 监听按钮索引变化
        onButtonIndexChanged: function(newIndex) {
            console.log("✅ [测试] 按钮索引:", newIndex)
        }
    }

    // ========== 键盘事件处理 ==========
    Keys.onPressed: function(event) {
        var direction = ""

        switch(event.key) {
        case Qt.Key_Up:
            direction = "Up"
            break
        case Qt.Key_Down:
            direction = "Down"
            break
        case Qt.Key_Left:
            direction = "Left"
            break
        case Qt.Key_Right:
            direction = "Right"
            break
        default:
            return
        }

        if (direction) {
            navigationManager.handleDirectionKey(direction)
            event.accepted = true
        }
    }

    // ========== 布局 ==========
    RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        // ========== 区域A：电机列表 ==========
        Rectangle {
            Layout.preferredWidth: 200
            Layout.fillHeight: true
            color: "#2e2e2e"
            border.color: navigationManager.currentArea === navigationManager.areaMotorList ? "#2196F3" : "#444"
            border.width: 2

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 5

                Text {
                    text: "电机列表区"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#fff"
                    Layout.fillWidth: true
                }

                Repeater {
                    model: 8
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        color: "#3e3e3e"
                        border.color: (navigationManager.currentArea === navigationManager.areaMotorList &&
                                      navigationManager.motorListIndex === index) ? "#2196F3" : "transparent"
                        border.width: 3
                        radius: 4

                        Text {
                            anchors.centerIn: parent
                            text: (index + 1) + "号电机"
                            font.pixelSize: 14
                            color: "#fff"
                        }
                    }
                }
            }
        }

        // ========== 右侧区域 ==========
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            // ========== 区域B：Tab导航 ==========
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                color: "#2e2e2e"
                border.color: navigationManager.currentArea === navigationManager.areaTabBar ? "#2196F3" : "#444"
                border.width: 2

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 5

                    Repeater {
                        model: ["基本配置", "电流保护", "前轴承温度", "后轴承温度", "A相绕组", "B相绕组", "C相绕组", "电机温度", "X轴振动"]
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "#3e3e3e"
                            border.color: (navigationManager.currentArea === navigationManager.areaTabBar &&
                                          navigationManager.tabIndex === index) ? "#2196F3" : "transparent"
                            border.width: 3
                            radius: 4

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: 12
                                color: "#fff"
                            }
                        }
                    }
                }
            }

            // ========== 区域C：参数区域 ==========
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#2e2e2e"
                border.color: navigationManager.currentArea === navigationManager.areaParams ? "#2196F3" : "#444"
                border.width: 2

                StackLayout {
                    id: paramStackLayout
                    anchors.fill: parent
                    anchors.margins: 10
                    currentIndex: navigationManager.tabIndex

                    // 9个Tab对应的参数区
                    Repeater {
                        model: 9
                        delegate: GridLayout {
                            columns: 4
                            columnSpacing: 10
                            rowSpacing: 12

                            Text {
                                text: "Tab " + index + " 参数区"
                                font.pixelSize: 16
                                font.bold: true
                                color: "#fff"
                                Layout.columnSpan: 4
                            }

                            // 9个参数（GridLayout 5行×2列）
                            Repeater {
                                model: 9
                                delegate: Rectangle {
                                    Layout.column: (index % 2 === 0) ? 0 : 2
                                    Layout.row: Math.floor(index / 2) + 1
                                    Layout.preferredWidth: 200
                                    Layout.preferredHeight: 60
                                    Layout.columnSpan: (index === 8) ? 2 : 1
                                    color: "#3e3e3e"
                                    border.color: (navigationManager.currentArea === navigationManager.areaParams &&
                                                  navigationManager.paramIndex === index) ? "#2196F3" : "transparent"
                                    border.width: 3
                                    radius: 4

                                    Text {
                                        anchors.centerIn: parent
                                        text: "参数 " + index
                                        font.pixelSize: 14
                                        color: "#fff"
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ========== 区域D：底部按钮 ==========
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                color: "#2e2e2e"
                border.color: navigationManager.currentArea === navigationManager.areaButtons ? "#2196F3" : "#444"
                border.width: 2

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Repeater {
                        model: ["启动测试", "停止测试", "参数校验"]
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "#3e3e3e"
                            border.color: (navigationManager.currentArea === navigationManager.areaButtons &&
                                          navigationManager.buttonIndex === index) ? "#2196F3" : "transparent"
                            border.width: 3
                            radius: 4

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: 14
                                color: "#fff"
                            }
                        }
                    }
                }
            }
        }
    }

    // ========== 状态显示 ==========
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 40
        color: "#333"

        Text {
            anchors.centerIn: parent
            text: navigationManager.getCurrentFocusInfo()
            font.pixelSize: 14
            color: "#fff"
        }
    }

    // ========== 帮助信息 ==========
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        width: 300
        height: 150
        color: "#333"
        opacity: 0.9

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 5

            Text {
                text: "导航测试"
                font.pixelSize: 16
                font.bold: true
                color: "#2196F3"
            }

            Text {
                text: "↑↓←→ 方向键导航"
                font.pixelSize: 12
                color: "#fff"
            }

            Text {
                text: "蓝色边框 = 当前焦点"
                font.pixelSize: 12
                color: "#fff"
            }

            Text {
                text: "Tab切换时参数区自动切换"
                font.pixelSize: 12
                color: "#fff"
            }
        }
    }
}
