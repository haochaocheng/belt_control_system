// CSModulePanel.qml
// CS模块显示面板 - 沿线急停状态+通讯数据
// 创建日期: 2026-02-09
// ✅ 2026-02-09 [Phase 7.44.8]: CS模块显示组件

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
    property string moduleName: "CS模块"

    // ========== 布局 ==========
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        // 标题
        Text {
            text: moduleName + " - 沿线急停状态监控"
            font.pixelSize: 20
            font.bold: true
            color: "#2C3E50"
            Layout.alignment: Qt.AlignHCenter
        }

        // 提示信息
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            color: "#FFF3CD"
            radius: 8
            border.width: 2
            border.color: "#FFC107"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10

                Text {
                    text: "⚠️ CS模块功能待实施"
                    font.pixelSize: 18
                    font.bold: true
                    color: "#856404"
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: "此模块用于监控沿线急停状态和主机通讯数据"
                    font.pixelSize: 14
                    color: "#856404"
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        // 占位内容
        GroupBox {
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: "急停状态"
            font.pixelSize: 16

            ColumnLayout {
                anchors.fill: parent
                spacing: 10

                Text {
                    text: "• 急停位置1: 正常"
                    font.pixelSize: 14
                    color: "#27AE60"
                }

                Text {
                    text: "• 急停位置2: 正常"
                    font.pixelSize: 14
                    color: "#27AE60"
                }

                Text {
                    text: "• 急停位置3: 正常"
                    font.pixelSize: 14
                    color: "#27AE60"
                }

                Text {
                    text: "• 通讯状态: 在线"
                    font.pixelSize: 14
                    color: "#27AE60"
                }

                Text {
                    text: "• 信号强度: 85%"
                    font.pixelSize: 14
                    color: "#27AE60"
                }

                Item { Layout.fillHeight: true }

                Text {
                    text: "（模拟数据，实际功能待实施）"
                    font.pixelSize: 12
                    color: "#95A5A6"
                    font.italic: true
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }
}
