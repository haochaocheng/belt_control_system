// VoiceModulePanel.qml
// 语音模块显示面板 - 语音播报控制
// 创建日期: 2026-02-09
// ✅ 2026-02-09 [Phase 7.44.8]: 语音模块显示组件

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
    property string moduleName: "语音模块"

    // ========== 布局 ==========
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        // 标题
        Text {
            text: moduleName + " - 语音播报控制"
            font.pixelSize: 20
            font.bold: true
            color: "#2C3E50"
            Layout.alignment: Qt.AlignHCenter
        }

        // 提示信息
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            color: "#D1ECF1"
            radius: 8
            border.width: 2
            border.color: "#17A2B8"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10

                Text {
                    text: "🔊 语音模块功能待实施"
                    font.pixelSize: 18
                    font.bold: true
                    color: "#0C5460"
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: "此模块用于控制语音播报功能"
                    font.pixelSize: 14
                    color: "#0C5460"
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        // 占位内容
        GroupBox {
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: "语音播报状态"
            font.pixelSize: 16

            ColumnLayout {
                anchors.fill: parent
                spacing: 10

                Text {
                    text: "• 播报状态: 空闲"
                    font.pixelSize: 14
                    color: "#2C3E50"
                }

                Text {
                    text: "• 最后播报: 无"
                    font.pixelSize: 14
                    color: "#2C3E50"
                }

                Text {
                    text: "• 音量: 80%"
                    font.pixelSize: 14
                    color: "#2C3E50"
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
