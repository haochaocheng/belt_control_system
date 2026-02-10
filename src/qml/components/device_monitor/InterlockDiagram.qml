import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// ✅ 2026-02-10 [Phase 7.45.3]: 连锁关系图
// 显示设备之间的连锁关系
Rectangle {
    id: root

    // ========== 公开属性 ==========
    implicitWidth: 800
    implicitHeight: 200
    color: "#0a0f1e"
    border.width: 2
    border.color: "#00d4ff"
    radius: 8

    // ========== 标题 ==========
    Text {
        id: title
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 15
        text: "【连锁关系】"
        font.pixelSize: 18
        font.bold: true
        font.family: "Microsoft YaHei"
        color: "#00d4ff"
    }

    // ========== 连锁关系文本显示 ==========
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 10

        // 第一行：皮带连锁
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 15

            Text {
                text: "1号皮带"
                font.pixelSize: 16
                font.family: "Microsoft YaHei"
                color: "#00d4ff"
            }

            Text {
                text: "→"
                font.pixelSize: 20
                font.bold: true
                color: "#00ff00"
            }

            Text {
                text: "2号皮带"
                font.pixelSize: 16
                font.family: "Microsoft YaHei"
                color: "#00d4ff"
            }

            Text {
                text: "→"
                font.pixelSize: 20
                font.bold: true
                color: "#00ff00"
            }

            Text {
                text: "3号皮带"
                font.pixelSize: 16
                font.family: "Microsoft YaHei"
                color: "#00d4ff"
            }

            Text {
                text: "→"
                font.pixelSize: 20
                font.bold: true
                color: "#00ff00"
            }

            Text {
                text: "4号皮带"
                font.pixelSize: 16
                font.family: "Microsoft YaHei"
                color: "#00d4ff"
            }
        }

        // 垂直箭头
        Text {
            Layout.alignment: Qt.AlignLeft
            Layout.leftMargin: 50
            text: "↓"
            font.pixelSize: 20
            font.bold: true
            color: "#00ff00"
        }

        // 第二行：辅助设备连锁
        RowLayout {
            Layout.alignment: Qt.AlignLeft
            Layout.leftMargin: 30
            spacing: 15

            Text {
                text: "转载机"
                font.pixelSize: 16
                font.family: "Microsoft YaHei"
                color: "#00d4ff"
            }

            Text {
                text: "→"
                font.pixelSize: 20
                font.bold: true
                color: "#00ff00"
            }

            Text {
                text: "破碎机"
                font.pixelSize: 16
                font.family: "Microsoft YaHei"
                color: "#00d4ff"
            }
        }

        // 垂直箭头
        Text {
            Layout.alignment: Qt.AlignLeft
            Layout.leftMargin: 50
            text: "↓"
            font.pixelSize: 20
            font.bold: true
            color: "#00ff00"
        }

        // 第三行：刮板连锁
        RowLayout {
            Layout.alignment: Qt.AlignLeft
            Layout.leftMargin: 30
            spacing: 15

            Text {
                text: "前刮板"
                font.pixelSize: 16
                font.family: "Microsoft YaHei"
                color: "#00d4ff"
            }

            Text {
                text: "←"
                font.pixelSize: 20
                font.bold: true
                color: "#00ff00"
            }

            Text {
                text: "后刮板"
                font.pixelSize: 16
                font.family: "Microsoft YaHei"
                color: "#00d4ff"
            }
        }
    }

    // ========== 说明文字 ==========
    Text {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 10
        text: "💡 箭头表示连锁方向"
        font.pixelSize: 12
        font.family: "Microsoft YaHei"
        color: "#5a6f8f"
    }
}
