import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as DeviceInfo

// ✅ 2026-03-18 [Phase 7.48.56]: 沿线点位保护主页面
// 左右分栏布局：左侧分组列表（3组×64点位） + 右侧参数配置面板
Rectangle {
    id: root
    implicitWidth: 800
    implicitHeight: 600
    color: "transparent"
    focus: true
    activeFocusOnTab: true

    signal requestReturnToCategory()

    // ========== 公开属性 ==========
    property int deviceId: systemConfig.machineNumber
    property int currentGroupIndex: 0    // 0=急停, 1=跑偏, 2=撕裂
    property int currentPointIndex: 0    // 0-63
    property var keyboardManager: null
    property var virtualKeyboard: null
    property int focusItemIndex: -1
    property int focusSubArea: 0         // 0:列表 1:参数 3:按钮
    property int focusParamIndex: 0
    property int focusButtonIndex: 0
    property int currentItemIndex: 0

    // 焦点变化时同步加载配置
    onFocusItemIndexChanged: {
        if (focusSubArea === 0 && focusItemIndex >= 0 && focusItemIndex < linePositionModel.count) {
            currentItemIndex = focusItemIndex
            loadPointConfig(focusItemIndex)
        }
    }

    // 左键返回类别
    Keys.onLeftPressed: function(event) {
        if (focusSubArea === 0) {
            root.requestReturnToCategory()
            event.accepted = true
        }
    }

    // ========== 沿线点位模型 ==========
    ListModel { id: linePositionModel }

    Component.onCompleted: {
        var groups = ["沿线急停", "沿线跑偏", "沿线撕裂"]
        var channelBases = [0, 100, 200]
        for (var g = 0; g < 3; g++) {
            for (var p = 1; p <= 64; p++) {
                linePositionModel.append({
                    "name": p + "号" + groups[g],
                    "groupIndex": g,
                    "groupName": groups[g],
                    "pointNumber": p,
                    "channelNumber": channelBases[g] + p - 1,
                    "active": false
                })
            }
        }
        loadPointConfig(0)
    }

    // ========== 主布局：左右分栏 ==========
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ========== 左侧：分组列表 ==========
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 240
            color: "transparent"
            clip: true

            Image {
                anchors.fill: parent
                source: "../images/33.png"
                fillMode: Image.Stretch
                z: -1
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 0
                spacing: 0

                // 标题栏
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    color: "transparent"
                    border.color: "transparent"
                    border.width: 0

                    Text {
                        anchors.centerIn: parent
                        text: "沿线点位保护"
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        color: "#E0E0E0"
                    }
                }

                // 点位列表
                ListView {
                    id: listView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: linePositionModel
                    spacing: 0
                    currentIndex: root.currentItemIndex

                    delegate: Column {
                        width: listView.width

                        // 分组标题（每64个一组）
                        Loader {
                            active: index % 64 === 0
                            width: parent.width
                            sourceComponent: Rectangle {
                                height: 35
                                width: parent ? parent.width : 0
                                color: "#1a2332"

                                Text {
                                    anchors.centerIn: parent
                                    text: model.groupName
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: "#4FC3F7"
                                }
                            }
                        }

                        // 点位行
                        Rectangle {
                            width: listView.width
                            height: 40
                            color: "transparent"

                            readonly property bool isSelected: (root.currentItemIndex === index)
                            readonly property bool isFocused: (root.focusSubArea === 0 && root.focusItemIndex === index)

                            // 实时状态
                            readonly property bool isActive: {
                                if (typeof csDataManager === 'undefined' || csDataManager === null) return false
                                return csDataManager.getBit(model.groupIndex, model.pointNumber - 1)
                            }

                            // 焦点边框
                            border.color: isFocused ? "#2196F3" : "transparent"
                            border.width: isFocused ? 3 : 0

                            // 背景图片
                            Image {
                                anchors.fill: parent
                                fillMode: Image.Stretch
                                z: -1
                                source: isSelected ? "../../../images/bhNameBK1.png" : "../../../images/bhNameBK.png"
                            }

                            // 焦点激活指示条
                            Rectangle {
                                visible: isFocused
                                width: 4
                                height: parent.height
                                color: "#2196F3"
                                anchors.left: parent.left
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 15
                                anchors.rightMargin: 10
                                spacing: 8

                                Text {
                                    text: model.pointNumber + "号"
                                    font.pixelSize: 14
                                    font.weight: isFocused ? Font.Bold : Font.Normal
                                    color: isFocused ? "#E0E0E0" : "#9E9E9E"
                                    Layout.preferredWidth: 40
                                }

                                // 状态指示灯
                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 2
                                    color: isActive ? "#F44336" : "#4CAF50"
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Text {
                                    text: isActive ? "故障" : "正常"
                                    font.pixelSize: 12
                                    color: isActive ? "#F44336" : "#4CAF50"
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    root.currentItemIndex = index
                                    root.focusItemIndex = index
                                    root.focusSubArea = 0
                                    loadPointConfig(index)
                                }
                            }
                        }
                    }
                }
            }
        }

        // ========== 右侧：参数配置面板 ==========
        Rectangle {
            Layout.fillHeight: true
            Layout.fillWidth: true
            color: "transparent"

            LinePositionConfigPanel {
                id: configPanel
                anchors.fill: parent
                keyboardManager: root.keyboardManager
                focusSubArea: root.focusSubArea
                focusParamIndex: root.focusParamIndex
                focusButtonIndex: root.focusButtonIndex
            }
        }
    }

    // ========== 函数 ==========
    function loadPointConfig(itemIndex) {
        if (itemIndex < 0 || itemIndex >= linePositionModel.count) return
        var item = linePositionModel.get(itemIndex)
        currentItemIndex = itemIndex

        if (typeof deviceConfigMgr !== "undefined") {
            var protection = deviceConfigMgr.loadDigitalProtectionByChannel("CS模块", item.channelNumber)
            if (protection && protection.protection_name) {
                configPanel.applyConfig(protection)
            } else {
                configPanel.applyDefaults(item)
            }
        }
    }

    function savePointConfig() {
        if (currentItemIndex < 0) return
        var item = linePositionModel.get(currentItemIndex)
        var config = configPanel.getConfig()
        config["module_type"] = "CS模块"
        config["register_address"] = 5
        config["channel_number"] = item.channelNumber

        if (typeof deviceConfigMgr !== "undefined") {
            deviceConfigMgr.saveDigitalProtection(root.deviceId, config)
        }
    }

    function getParamFieldCount() { return configPanel.getParamFieldCount() }
    function triggerParamInput(paramIndex) { configPanel.triggerParamInput(paramIndex) }
    function triggerButton(buttonIndex) {
        if (buttonIndex === 0) savePointConfig()
    }
}
