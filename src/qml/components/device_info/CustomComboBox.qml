import QtQuick 2.15
import QtQuick.Controls 2.15

// ✅ 2026-01-28 [FIX 100.300.78]: 自定义 ComboBox 组件，使用 034.png 作为背景
// 与 CustomSpinBox 保持一致的样式
ComboBox {
    id: root

    // ========== 默认样式 ==========
    // ✅ 高度与 CustomSpinBox 一致（60px）
    implicitHeight: 60

    // ========== 背景：使用 034.png 图片 ==========
    background: Rectangle {
        color: "transparent"  // 透明，显示图片

        // 背景图片 034.png
        Image {
            anchors.fill: parent
            source: "images/034.png"
            fillMode: Image.Stretch  // 拉伸填充
            z: -1  // 放在最底层
        }

        // 焦点边框（可选，增强视觉效果）
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: root.activeFocus ? "#2196F3" : "transparent"
            border.width: root.activeFocus ? 2 : 0
            radius: 4
        }
    }

    // ========== 文本显示区域 ==========
    contentItem: Text {
        text: root.displayText
        // ✅ 字体大小与 CustomSpinBox 一致（21px）
        font.pixelSize: 21
        color: "#E0E0E0"
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignLeft
        leftPadding: 15
        rightPadding: root.indicator.width + 15
        elide: Text.ElideRight
    }

    // ========== 下拉箭头指示器 ==========
    indicator: Rectangle {
        x: root.width - width - 2
        y: (root.height - height) / 2
        width: 24
        height: 24
        color: root.pressed ? "#2196F3" : (root.hovered ? "#1E88E5" : "#1a1f2e")
        border.color: "#3d4556"
        border.width: 1
        radius: 2

        Text {
            text: "▼"
            font.pixelSize: 10
            color: "#E0E0E0"
            anchors.centerIn: parent
        }
    }

    // ========== 下拉列表弹出框 ==========
    popup: Popup {
        y: root.height
        width: root.width
        implicitHeight: contentItem.implicitHeight
        padding: 1

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex

            ScrollIndicator.vertical: ScrollIndicator { }
        }

        background: Rectangle {
            color: "#2d3548"
            border.color: "#3d4556"
            border.width: 1
            radius: 2
        }
    }

    // ========== 下拉列表项样式 ==========
    delegate: ItemDelegate {
        width: root.width
        height: 40

        contentItem: Text {
            text: modelData
            font.pixelSize: 18
            color: highlighted ? "#FFFFFF" : "#E0E0E0"
            verticalAlignment: Text.AlignVCenter
            leftPadding: 15
        }

        background: Rectangle {
            color: highlighted ? "#2196F3" : (hovered ? "#3d4556" : "transparent")
        }

        highlighted: root.highlightedIndex === index
    }
}
