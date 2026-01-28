import QtQuick 2.15
import QtQuick.Controls 2.15

// ✅ 2026-01-27 [制动器控制参数设置] 制动器控制主页面（左右分栏布局）
// 设计风格与电机控制完全一样
Rectangle {
    id: root
    // ✅ 使用 implicitWidth/Height 替代固定尺寸，确保运行时正确显示
    implicitWidth: 1000  // 默认宽度（用于QDS预览）
    implicitHeight: 600  // 默认高度（用于QDS预览）
    color: "transparent"

    // ========== 公开属性 ==========
    property int deviceId: 1
    property string deviceName: "1号皮带"
    property int currentBrakeIndex: 0  // 当前选中的制动器索引 (0-7)

    // ========== 背景装饰图片（预留位置，可在QDS中替换）==========
    Image {
        id: backgroundImage
        anchors.fill: parent
        source: ""  // 预留：在QDS中设置装饰图片路径
        fillMode: Image.Stretch
        z: -1  // 确保在所有内容下方
        visible: source != ""  // 只有设置了图片才显示
    }

    // ========== 键盘导航支持 ==========
    focus: true

    Keys.onPressed: {
        // 将键盘事件转发给子组件
        if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
            brakeListPanel.item.focus = true
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
            brakeConfigPanel.item.focus = true
        }
    }

    // ========== 左右分栏布局 ==========
    Row {
        anchors.fill: parent
        spacing: 0

        // ========== 左侧：制动器列表（使用Loader加载）==========
        Loader {
            id: brakeListPanel
            // ✅ 2026-01-27 [FIX 100.300.35]: 宽度减少到80%（240px → 192px）
            width: 192
            height: parent.height
            source: "BrakeListPanel.qml"

            onLoaded: {
                item.currentBrakeIndex = Qt.binding(function() { return root.currentBrakeIndex })
                item.brakeSelected.connect(function(brakeIndex) {
                    root.currentBrakeIndex = brakeIndex
                    console.log("选中制动器:", brakeIndex + 1)
                })
            }
        }

        // ========== 分隔线 ==========
        Rectangle {
            width: 2
            height: parent.height
            color: "#3d4556"
        }

        // ========== 右侧：制动器配置面板（使用Loader加载）==========
        Loader {
            id: brakeConfigPanel
            width: parent.width - brakeListPanel.width - 2
            height: parent.height
            source: "BrakeConfigPanel.qml"

            onLoaded: {
                item.brakeIndex = Qt.binding(function() { return root.currentBrakeIndex })
            }
        }
    }
}
