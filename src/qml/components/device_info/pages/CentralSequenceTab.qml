// CentralSequenceTab.qml
// 集控顺序启动 Tab
// ✅ 2026-04-14 [Phase 7.48.88.147]: 集控顺序启动界面
// 功能：配置分站启动顺序、间隔时间，顺序启动/停止，停止为倒序

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../" as DeviceInfo

Rectangle {
    id: root
    color: "transparent"

    // ========== 公开属性 ==========
    property int focusParamIndex: -1
    property int focusSubArea: 0
    property var virtualKeyboard: null
    property var parentDialog: null

    // 列表中当前键盘焦点项（0-based）
    property int focusListIndex: -1

    // ========== 辅助 ==========
    function getParamFieldCount() { return 1 }  // 仅间隔时间参数
    function triggerParamInput(index) {
        if (index === 0 && intervalField.activateVirtualKeyboard)
            intervalField.activateVirtualKeyboard()
    }

    // ========== 主布局 ==========
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        // ===== 间隔时间设置 =====
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            color: "#12192b"
            radius: 6
            border.color: "#2a3550"; border.width: 1

            RowLayout {
                anchors.fill: parent; anchors.margins: 12; spacing: 10

                Text {
                    text: "步间隔:"
                    font.pixelSize: 16; color: "#9E9E9E"
                    font.weight: Font.Medium
                }
                Item {
                    Layout.preferredWidth: 120; Layout.preferredHeight: 36
                    DeviceInfo.CustomSpinBox {
                        id: intervalField
                        anchors.fill: parent
                        from: 1; to: 300
                        value: typeof centralControlManager !== "undefined"
                               ? centralControlManager.sequenceInterval : 5
                        onValueChanged: {
                            if (typeof centralControlManager !== "undefined")
                                centralControlManager.sequenceInterval = value
                        }
                    }
                    Rectangle {
                        anchors.fill: parent; color: "transparent"
                        border.color: (root.focusSubArea === 2 && root.focusParamIndex === 0) ? "#2196F3" : "transparent"
                        border.width: 2; radius: 4; z: 1; enabled: false
                    }
                }
                Text { text: "秒"; font.pixelSize: 15; color: "#78909C" }

                Item { Layout.fillWidth: true }

                // 运行状态指示
                Row {
                    spacing: 6
                    Rectangle {
                        width: 8; height: 8; radius: 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: (typeof centralControlManager !== "undefined" &&
                                centralControlManager.sequenceRunning) ? "#FFA726" : "#2a3550"
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                    Text {
                        text: (typeof centralControlManager !== "undefined" &&
                               centralControlManager.sequenceRunning) ? "执行中" : "待机"
                        font.pixelSize: 12; color: "#78909C"
                    }
                }
            }
        }

        // ===== 状态文字 =====
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            color: "#0d1520"; radius: 4
            border.color: "#1e2a40"; border.width: 1
            visible: typeof centralControlManager !== "undefined" &&
                     centralControlManager.sequenceStatusText.length > 0

            Text {
                anchors.centerIn: parent
                text: typeof centralControlManager !== "undefined"
                      ? centralControlManager.sequenceStatusText : ""
                font.pixelSize: 12; color: "#4FC3F7"
            }
        }

        // ===== 进度指示 =====
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 6
            color: "#1e2a40"; radius: 3
            visible: typeof centralControlManager !== "undefined" &&
                     centralControlManager.sequenceRunning

            Rectangle {
                width: {
                    if (typeof centralControlManager === "undefined") return 0
                    var order = centralControlManager.sequenceOrder
                    if (!order || order.length === 0) return 0
                    var step = centralControlManager.sequenceCurrentStep
                    return parent.width * Math.max(0, step) / order.length
                }
                height: parent.height; radius: parent.radius
                color: "#4FC3F7"
                Behavior on width { NumberAnimation { duration: 300 } }
            }
        }

        // ===== 分站顺序列表 =====
        Text {
            text: "启动顺序（上下键调整焦点，回车切换选中移动）"
            font.pixelSize: 11; color: "#607080"
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#0d1520"; radius: 6
            border.color: "#2a3550"; border.width: 1
            clip: true

            ListView {
                id: seqListView
                anchors.fill: parent
                anchors.margins: 4
                spacing: 2

                model: typeof centralControlManager !== "undefined"
                       ? centralControlManager.sequenceOrder : []

                delegate: Rectangle {
                    width: seqListView.width
                    height: 50    // ✅ Phase 7.48.88.151: 增高以容纳延迟输入
                    radius: 4

                    property bool isKeyFocused: root.focusListIndex === index
                    property int  execStep: typeof centralControlManager !== "undefined"
                                            ? centralControlManager.sequenceCurrentStep : -1
                    property bool isCurrentExec: centralControlManager && centralControlManager.sequenceRunning
                                                 && index < execStep

                    color: {
                        if (isCurrentExec) return "#0d2a1a"
                        if (isKeyFocused)  return "#1e3a5c"
                        return index % 2 === 0 ? "#0d1520" : "#111827"
                    }
                    border.color: isKeyFocused ? "#4FC3F7" : "transparent"
                    border.width: isKeyFocused ? 2 : 0

                    RowLayout {
                        anchors.fill: parent; anchors.margins: 8; spacing: 6

                        // 序号圆圈
                        Rectangle {
                            width: 24; height: 24; radius: 12
                            color: isCurrentExec ? "#2E7D32" : "#E65100"
                            Layout.alignment: Qt.AlignVCenter
                            Text {
                                anchors.centerIn: parent
                                text: (index + 1).toString()
                                font.pixelSize: 11; font.weight: Font.Bold
                                color: "#FFFFFF"
                            }
                        }

                        // 分站名称
                        Text {
                            text: modelData.name || ("分站" + (index + 1))
                            font.pixelSize: 13
                            color: isCurrentExec ? "#81C784" : (modelData.isLocal ? "#FFD54F" : "#B0BEC5")
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // ✅ 2026-04-15 [Phase 7.48.88.153]: 本站徽标
                        Rectangle {
                            visible: modelData.isLocal === true
                            width: 22; height: 16; radius: 3
                            color: "#E65100"
                            Layout.alignment: Qt.AlignVCenter
                            Text {
                                anchors.centerIn: parent
                                text: "本"; font.pixelSize: 10; font.weight: Font.Bold
                                color: "#FFFFFF"
                            }
                        }

                        // 在线 LED
                        Rectangle {
                            width: 8; height: 8; radius: 4
                            Layout.alignment: Qt.AlignVCenter
                            color: modelData.online ? "#4CAF50" : "#37474F"
                        }

                        // ✅ Phase 7.48.88.151: 每步独立延迟输入
                        Text {
                            text: "后"
                            font.pixelSize: 11; color: "#607080"
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Rectangle {
                            width: 52; height: 30; radius: 3
                            color: "#12192b"
                            border.color: delayInput.activeFocus ? "#4FC3F7" : "#2a3550"
                            border.width: 1
                            Layout.alignment: Qt.AlignVCenter
                            enabled: !centralControlManager || !centralControlManager.sequenceRunning

                            TextInput {
                                id: delayInput
                                anchors.fill: parent; anchors.margins: 4
                                text: modelData.delay !== undefined ? modelData.delay.toString() : "5"
                                font.pixelSize: 13; color: "#B0BEC5"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                inputMethodHints: Qt.ImhDigitsOnly
                                validator: IntValidator { bottom: 1; top: 300 }
                                onEditingFinished: {
                                    if (typeof centralControlManager !== "undefined") {
                                        var v = parseInt(text) || 5
                                        centralControlManager.setSequenceStepDelay(index, v)
                                    }
                                }
                            }
                        }
                        Text {
                            text: "秒"
                            font.pixelSize: 11; color: "#607080"
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // ↑ 按钮
                        Rectangle {
                            width: 26; height: 26; radius: 4
                            color: upHov.containsMouse ? "#1e3a5c" : "transparent"
                            border.color: "#2a3550"; border.width: 1
                            Layout.alignment: Qt.AlignVCenter
                            enabled: index > 0 && !centralControlManager.sequenceRunning

                            Text {
                                anchors.centerIn: parent
                                text: "▲"; font.pixelSize: 10
                                color: parent.enabled ? "#78909C" : "#2a3550"
                            }
                            HoverHandler { id: upHov }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (typeof centralControlManager !== "undefined")
                                        centralControlManager.moveSequenceItem(index, index - 1)
                                    root.focusListIndex = index - 1
                                }
                            }
                        }

                        // ↓ 按钮
                        Rectangle {
                            width: 26; height: 26; radius: 4
                            color: dnHov.containsMouse ? "#1e3a5c" : "transparent"
                            border.color: "#2a3550"; border.width: 1
                            Layout.alignment: Qt.AlignVCenter
                            enabled: {
                                if (typeof centralControlManager === "undefined") return false
                                return index < centralControlManager.sequenceOrder.length - 1
                                       && !centralControlManager.sequenceRunning
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "▼"; font.pixelSize: 10
                                color: parent.enabled ? "#78909C" : "#2a3550"
                            }
                            HoverHandler { id: dnHov }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (typeof centralControlManager !== "undefined")
                                        centralControlManager.moveSequenceItem(index, index + 1)
                                    root.focusListIndex = index + 1
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.focusListIndex = index
                    }
                }
            }
        }

        // ===== 操作按钮区 =====
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            // 顺序启动
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 40
                radius: 6
                color: enabled ? (startHov.containsMouse ? "#1B5E20" : "#2E7D32") : "#1a2a1a"
                border.color: enabled ? "#4CAF50" : "#2a4a2a"; border.width: 1
                enabled: typeof centralControlManager !== "undefined"
                         && !centralControlManager.sequenceRunning
                         && centralControlManager.isMasterMode

                Text { anchors.centerIn: parent; text: "顺序启动"
                       font.pixelSize: 13; color: parent.enabled ? "#A5D6A7" : "#4a6a4a" }
                HoverHandler { id: startHov }
                MouseArea { anchors.fill: parent
                    onClicked: { if (typeof centralControlManager !== "undefined") centralControlManager.startSequence() }
                }
            }

            // 顺序停止
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 40
                radius: 6
                color: enabled ? (stopHov.containsMouse ? "#E65100" : "#BF360C") : "#1a1510"
                border.color: enabled ? "#FF8F00" : "#3a2a1a"; border.width: 1
                enabled: typeof centralControlManager !== "undefined"
                         && !centralControlManager.sequenceRunning
                         && centralControlManager.isMasterMode

                Text { anchors.centerIn: parent; text: "顺序停止"
                       font.pixelSize: 13; color: parent.enabled ? "#FFCC80" : "#4a3a2a" }
                HoverHandler { id: stopHov }
                MouseArea { anchors.fill: parent
                    onClicked: { if (typeof centralControlManager !== "undefined") centralControlManager.stopSequence() }
                }
            }

            // 中止
            Rectangle {
                Layout.preferredWidth: 70; Layout.preferredHeight: 40
                radius: 6
                color: enabled ? (abortHov.containsMouse ? "#C62828" : "#B71C1C") : "#1a1010"
                border.color: enabled ? "#EF9A9A" : "#2a1a1a"; border.width: 1
                enabled: typeof centralControlManager !== "undefined"
                         && centralControlManager.sequenceRunning

                Text { anchors.centerIn: parent; text: "中止"
                       font.pixelSize: 13; color: parent.enabled ? "#EF9A9A" : "#3a2a2a" }
                HoverHandler { id: abortHov }
                MouseArea { anchors.fill: parent
                    onClicked: { if (typeof centralControlManager !== "undefined") centralControlManager.abortSequence() }
                }
            }

            // 重置顺序
            Rectangle {
                Layout.preferredWidth: 80; Layout.preferredHeight: 40
                radius: 6
                color: resetHov.containsMouse ? "#263238" : "#1a2030"
                border.color: "#3d4556"; border.width: 1
                enabled: typeof centralControlManager !== "undefined"
                         && !centralControlManager.sequenceRunning

                Text { anchors.centerIn: parent; text: "重置"
                       font.pixelSize: 13; color: "#78909C" }
                HoverHandler { id: resetHov }
                MouseArea { anchors.fill: parent
                    onClicked: { if (typeof centralControlManager !== "undefined") centralControlManager.resetSequenceOrder() }
                }
            }
        }

        // 提示说明
        Text {
            text: "停止顺序 = 启动顺序倒置 | 跳过离线分站"
            font.pixelSize: 10; color: "#3d4556"
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
