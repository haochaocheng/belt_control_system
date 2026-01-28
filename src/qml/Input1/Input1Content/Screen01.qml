import QtQuick
import QtQuick.Controls
import Input1

// ✅ 2026-01-27 [FIX 100.300.54]: Screen01 包装器 - 添加键盘导航功能
// 这个文件包装 Screen01.ui.qml，添加键盘导航逻辑
Item {
    id: root
    width: 1920
    height: 1080

    // ✅ 接收外部传入的当前页面索引
    property int currentPageIndex: 0

    // ✅ 当前选中的组件索引（0-11）
    property int selectedIndex: 0

    // ✅ 网格参数
    readonly property int rows: 3
    readonly property int cols: 4
    readonly property int totalItems: 12

    // ✅ 加载 UI 文件
    Screen01Form {
        id: screen01Form
        anchors.fill: parent
        currentPageIndex: root.currentPageIndex

        // ✅ 组件数组（按行列顺序）
        property var dataItems: [
            data_row1_col1, data_row1_col2, data_row1_col3, data_row1_col4,
            data_row2_col1, data_row2_col2, data_row2_col3, data_row2_col4,
            data_row3_col1, data_row3_col2, data_row3_col3, data_row3_col4
        ]

        Component.onCompleted: {
            // 初始化：选中第一个组件
            updateSelection()
        }
    }

    // ✅ 更新选中状态
    function updateSelection() {
        for (var i = 0; i < screen01Form.dataItems.length; i++) {
            screen01Form.dataItems[i].selected = (i === selectedIndex)
        }
    }

    // ✅ 键盘导航
    focus: true
    Keys.onPressed: function(event) {
        var oldIndex = selectedIndex
        var row = Math.floor(selectedIndex / cols)
        var col = selectedIndex % cols

        if (event.key === Qt.Key_Up) {
            // 上键：移动到上一行
            if (row > 0) {
                selectedIndex = (row - 1) * cols + col
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            // 下键：移动到下一行
            if (row < rows - 1) {
                selectedIndex = (row + 1) * cols + col
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Left) {
            // 左键：移动到前一列
            if (col > 0) {
                selectedIndex = row * cols + (col - 1)
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            // 右键：移动到后一列
            if (col < cols - 1) {
                selectedIndex = row * cols + (col + 1)
            }
            event.accepted = true
        }

        // 如果索引改变，更新选中状态
        if (oldIndex !== selectedIndex) {
            console.log("[Screen01] 选中索引:", selectedIndex, "行:", Math.floor(selectedIndex / cols), "列:", selectedIndex % cols)
            updateSelection()
        }
    }
}
