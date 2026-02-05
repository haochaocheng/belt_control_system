import QtQuick 2.15
import QtQuick.Controls 2.15

// ✅ 2026-01-24 [设备信息界面重构] 设备信息网格容器
// 4x3布局，管理12个设备卡片，支持键盘导航和选中状态
FocusScope {
    id: root

    // ========== 公开属性 ==========
    property int currentIndex: -1               // 当前选中索引 (-1表示未选中)
    property var deviceList: []                 // 设备数据列表

    // ========== 信号 ==========
    signal deviceSelected(int index)
    signal deviceDoubleClicked(int index)

    // ========== 响应式尺寸计算 ==========
    readonly property real scaleFactor: {
        // 根据屏幕宽度计算缩放系数
        if (width >= 1800) {
            return 1.5  // 1920x1080
        } else {
            return 1.0  // 1280x800
        }
    }

    readonly property real itemWidth: 280 * scaleFactor
    readonly property real itemHeight: 180 * scaleFactor
    readonly property real itemSpacing: 20 * scaleFactor
    readonly property real marginHorizontal: 40 * scaleFactor
    readonly property real marginVertical: 30 * scaleFactor

    // ========== 主容器 ==========
    Rectangle {
        anchors.fill: parent
        color: "transparent"

        // ========== 4x3 网格布局 ==========
        Grid {
            id: deviceGrid
            anchors.centerIn: parent
            columns: 4
            rows: 3
            columnSpacing: itemSpacing
            rowSpacing: itemSpacing

            Repeater {
                model: 12  // 固定12个设备

                DeviceInfoItem {
                    width: itemWidth
                    height: itemHeight

                    // 从设备列表获取数据
                    deviceName: {
                        if (index < deviceList.length && deviceList[index]) {
                            return deviceList[index].name || getDefaultName(index)
                        }
                        return getDefaultName(index)
                    }

                    deviceId: {
                        if (index < deviceList.length && deviceList[index]) {
                            return deviceList[index].id || (index + 1).toString()
                        }
                        return (index + 1).toString()
                    }

                    imagePath: {
                        if (index < deviceList.length && deviceList[index]) {
                            return deviceList[index].imagePath || ""
                        }
                        return ""
                    }

                    isSelected: root.currentIndex === index
                    isRunning: {
                        if (index < deviceList.length && deviceList[index]) {
                            return deviceList[index].isRunning || false
                        }
                        return false
                    }

                    speed: {
                        if (index < deviceList.length && deviceList[index]) {
                            return deviceList[index].speed || 0.0
                        }
                        return 0.0
                    }

                    status: {
                        if (index < deviceList.length && deviceList[index]) {
                            return deviceList[index].status || "停止"
                        }
                        return "停止"
                    }

                    onClicked: {
                        root.currentIndex = index
                        root.deviceSelected(index)
                        root.forceActiveFocus()  // 获取焦点以支持键盘导航
                    }

                    onDoubleClicked: {
                        root.deviceDoubleClicked(index)
                    }
                }
            }
        }

        // ========== 空白区域点击取消选中 ==========
        MouseArea {
            anchors.fill: parent
            z: -1  // 放在最底层
            onClicked: {
                root.currentIndex = -1
            }
        }
    }

    // ========== 键盘导航 ==========
    focus: true
    Keys.onPressed: {
        if (currentIndex === -1) {
            // 如果未选中，按任意方向键选中第一个
            if (event.key === Qt.Key_Left || event.key === Qt.Key_Right ||
                event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                currentIndex = 0
                deviceSelected(0)
                event.accepted = true
            }
            return
        }

        var row = Math.floor(currentIndex / 4)
        var col = currentIndex % 4
        var newIndex = currentIndex

        switch(event.key) {
            case Qt.Key_Left:
                if (col > 0) {
                    newIndex = currentIndex - 1
                }
                break
            case Qt.Key_Right:
                if (col < 3) {
                    newIndex = currentIndex + 1
                }
                break
            case Qt.Key_Up:
                if (row > 0) {
                    newIndex = currentIndex - 4
                }
                break
            case Qt.Key_Down:
                if (row < 2) {
                    newIndex = currentIndex + 4
                }
                break
            case Qt.Key_Return:
            case Qt.Key_Enter:
                deviceDoubleClicked(currentIndex)
                event.accepted = true
                return
            case Qt.Key_Escape:
                currentIndex = -1
                event.accepted = true
                return
        }

        if (newIndex !== currentIndex) {
            currentIndex = newIndex
            deviceSelected(newIndex)
            event.accepted = true
        }
    }

    // ========== 辅助函数 ==========
    function getDefaultName(index) {
        var names = [
            "1号皮带", "2号皮带", "3号皮带", "4号皮带",
            "5号皮带", "6号皮带", "7号皮带", "8号皮带",
            "破碎机", "转载机", "前刮板机", "后刮板机"
        ]
        return names[index] || "设备" + (index + 1)
    }

    // ========== 调试信息 ==========
    Component.onCompleted: {
        console.log("[DeviceInfoGrid] 初始化完成")
        console.log("   屏幕尺寸:", width, "x", height)
        console.log("   缩放系数:", scaleFactor)
        console.log("   设备卡片尺寸:", itemWidth, "x", itemHeight)
    }
}
