import QtQuick 2.15
import QtQuick.Controls 2.15

// ✅ 2026-01-25 [电机控制参数设置] 电机控制主页面（左右分栏布局）
// ✅ 2026-01-25 [FIX 100.311]: 重构为模块化设计，支持键盘操作
// ✅ 2026-01-25 [FIX 100.312]: 添加背景图片预留位置
// ✅ 2026-01-25 [FIX 100.314]: 修复QDS预览问题，使用Loader加载组件
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
    property int focusItemIndex: -1  // -1 表示无焦点
    property int focusSubArea: 0  // 0:电机列表区域 1:Tab区域 2:参数区域
    property int focusTabIndex: 0  // Tab区域焦点索引
    property int focusParamIndex: 0  // 参数区域焦点索引

    // ✅ 2026-01-30 [FIX 100.300.106]: Qt 虚拟键盘引用
    property var virtualKeyboard: null

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

    // ✅ 2026-01-30 [FIX 100.300.106]: 键盘导航支持（暂时保留旧代码，注释掉）
    // Keys.onPressed: {
    //     // 将键盘事件转发给子组件
    //     if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
    //         motorListPanel.item.focus = true
    //     } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
    //         motorConfigPanel.item.focus = true
    //     }
    // }

    // ========== 左右分栏布局 ==========
    Row {
        anchors.fill: parent
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
                item.focusSubArea = Qt.binding(function() { return root.focusSubArea })
                item.focusTabIndex = Qt.binding(function() { return root.focusTabIndex })
                item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
            }
        }
    }
}
