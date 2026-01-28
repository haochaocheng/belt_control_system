import QtQuick
import QtQuick.Controls
import Input1
import Input1Content

// ✅ 2026-01-27 [FIX 100.300.54]: Screen01 包装器 - 添加键盘导航功能
// ✅ 2026-01-27 [FIX 100.300.56]: 添加 Input1Content 导入以加载 Screen01Form
// ✅ 2026-01-27 [FIX 100.300.58]: 增强焦点管理和调试信息
// ✅ 2026-01-28 [FIX 100.300.60]: 添加 dataItems 空值检查，修复 QDS 中 undefined 错误
Item {
    id: root
    width: 1920
    height: 1080

    property int currentPageIndex: 0
    property int selectedIndex: 0

    readonly property int rows: 3
    readonly property int cols: 4
    readonly property int totalItems: 12

    focus: true
    activeFocusOnTab: true

    onActiveFocusChanged: {
        console.log("[Screen01] 🎯 焦点状态:", activeFocus ? "✅ 获得" : "❌ 失去")
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            console.log("[Screen01] 🖱️ 点击屏幕，强制获取焦点")
            root.forceActiveFocus()
        }
        propagateComposedEvents: true
    }

    Screen01Form {
        id: screen01Form
        anchors.fill: parent
        currentPageIndex: root.currentPageIndex

        property var dataItems: [
            data_row1_col1, data_row1_col2, data_row1_col3, data_row1_col4,
            data_row2_col1, data_row2_col2, data_row2_col3, data_row2_col4,
            data_row3_col1, data_row3_col2, data_row3_col3, data_row3_col4
        ]

        Component.onCompleted: {
            console.log("[Screen01] ✅ 组件加载完成")

            // ✅ 2026-01-28 [FIX 100.300.60]: 添加 dataItems 空值检查
            if (dataItems && dataItems.length > 0) {
                console.log("[Screen01] 📊 dataItems 数量:", dataItems.length)
                console.log("[Screen01] 🔄 初始化选中状态...")
                updateSelection()
            } else {
                console.warn("[Screen01] ⚠️ dataItems 未定义或为空，跳过初始化")
            }

            console.log("[Screen01] 🎯 强制获取焦点...")
            root.forceActiveFocus()
        }
    }

    function updateSelection() {
        // ✅ 2026-01-28 [FIX 100.300.60]: 添加 dataItems 空值检查
        if (!screen01Form.dataItems || screen01Form.dataItems.length === 0) {
            console.warn("[Screen01] ⚠️ dataItems 未定义或为空，跳过更新")
            return
        }

        console.log("[Screen01] 🔄 updateSelection 开始，selectedIndex:", selectedIndex)
        var successCount = 0
        for (var i = 0; i < screen01Form.dataItems.length; i++) {
            var item = screen01Form.dataItems[i]
            if (item) {
                item.selected = (i === selectedIndex)
                if (item.selected) {
                    console.log("[Screen01] ✅ 组件", i, "已选中")
                }
                successCount++
            } else {
                console.warn("[Screen01] ⚠️ 组件", i, "为 null")
            }
        }
        console.log("[Screen01] 🔄 updateSelection 完成，成功更新", successCount, "个组件")
    }

    onSelectedIndexChanged: {
        var row = Math.floor(selectedIndex / cols)
        var col = selectedIndex % cols
        console.log("[Screen01] 📍 selectedIndex 变化:", selectedIndex, "→ 行", row, "列", col)
    }

    Keys.onPressed: function(event) {
        console.log("[Screen01] ⌨️ 按键事件 - Key:", event.key, "焦点:", activeFocus ? "✅" : "❌")

        if (!activeFocus) {
            console.warn("[Screen01] ⚠️ 无焦点，按键被忽略！请点击屏幕获取焦点")
            return
        }

        var oldIndex = selectedIndex
        var row = Math.floor(selectedIndex / cols)
        var col = selectedIndex % cols

        var keyName = ""
        if (event.key === Qt.Key_Up) {
            keyName = "↑ 上"
            if (row > 0) {
                selectedIndex = (row - 1) * cols + col
                event.accepted = true
            } else {
                console.log("[Screen01] 🚫 已在第一行，无法向上")
            }
        } else if (event.key === Qt.Key_Down) {
            keyName = "↓ 下"
            if (row < rows - 1) {
                selectedIndex = (row + 1) * cols + col
                event.accepted = true
            } else {
                console.log("[Screen01] 🚫 已在最后一行，无法向下")
            }
        } else if (event.key === Qt.Key_Left) {
            keyName = "← 左"
            if (col > 0) {
                selectedIndex = row * cols + (col - 1)
                event.accepted = true
            } else {
                console.log("[Screen01] 🚫 已在第一列，无法向左")
            }
        } else if (event.key === Qt.Key_Right) {
            keyName = "→ 右"
            if (col < cols - 1) {
                selectedIndex = row * cols + (col + 1)
                event.accepted = true
            } else {
                console.log("[Screen01] 🚫 已在最后一列，无法向右")
            }
        } else {
            console.log("[Screen01] ℹ️ 未处理的按键:", event.key)
        }

        if (oldIndex !== selectedIndex) {
            console.log("[Screen01] 🎯 导航成功:", keyName, "- 索引", oldIndex, "→", selectedIndex)
            updateSelection()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: root.activeFocus ? "yellow" : "red"
        border.width: 3
        z: 1000
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        width: 300
        height: 120
        color: "#80000000"
        z: 999

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 5

            Text {
                text: "焦点: " + (root.activeFocus ? "✅ 有" : "❌ 无")
                color: root.activeFocus ? "#00FF00" : "#FF0000"
                font.pixelSize: 18
                font.bold: true
            }

            Text {
                text: "选中: " + selectedIndex
                color: "white"
                font.pixelSize: 16
            }

            Text {
                text: "行" + Math.floor(selectedIndex / cols) + " 列" + (selectedIndex % cols)
                color: "white"
                font.pixelSize: 16
            }

            Text {
                text: "点击屏幕获取焦点"
                color: "#FFFF00"
                font.pixelSize: 12
            }
        }
    }
}
