// ReservedModulePanel.qml
// 预留模块显示面板
// 创建日期: 2026-02-09
// ✅ 2026-02-09 [Phase 7.44.8]: 预留模块显示组件

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "#ECF0F1"
    radius: 8
    border.width: 2
    border.color: "#BDC3C7"
    height: 400

    // ========== 公开属性 ==========
    property int moduleIndex: 0
    property string moduleName: "预留模块"

    // ========== 布局 ==========
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        // 标题
        Text {
            text: moduleName
            font.pixelSize: 20
            font.bold: true
            color: "#2C3E50"
            Layout.alignment: Qt.AlignHCenter
        }

        // 提示信息
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 150
            color: "#E2E3E5"
            radius: 8
            border.width: 2
            border.color: "#6C757D"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15

                Text {
                    text: "📦 预留模块"
                    font.pixelSize: 18
                    font.bold: true
                    color: "#383D41"
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: "此模块位置预留，暂无功能定义"
                    font.pixelSize: 14
                    color: "#383D41"
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: "可根据实际需求扩展功能"
                    font.pixelSize: 14
                    color: "#383D41"
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
