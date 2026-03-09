import QtQuick 2.15
import QtQuick.Controls 2.15
import "../" as DeviceInfo

// ✅ 2026-03-09 [洒水控制主页面] 左右分栏布局
// 左侧：洒水列表（洒水1-洒水8）
// 右侧：洒水配置面板（基本配置）
// 设计风格与张紧控制页面完全一样
Rectangle {
    id: root
    implicitWidth: 1000
    implicitHeight: 600
    color: "transparent"

    // ========== 公开属性 ==========
    property int deviceId: 1
    property string deviceName: "1号皮带"
    property int currentSprinklerIndex: 0  // 当前选中的洒水索引 (0-7)

    // 导航焦点属性（3区域模式：0:列表 1:参数 2:按钮）
    property int focusItemIndex: -1
    property int focusSubArea: 0
    property int focusParamIndex: 0
    property int focusButtonIndex: 0
    property var virtualKeyboard: null

    // 监听 focusItemIndex 变化，同步到 currentSprinklerIndex
    onFocusItemIndexChanged: {
        if (focusSubArea === 0 && focusItemIndex >= 0 && focusItemIndex <= 7) {
            currentSprinklerIndex = focusItemIndex
            navigationManager.listIndex = focusItemIndex
        }
    }

    // ========== NavigationManager ==========
    DeviceInfo.NavigationManager {
        id: navigationManager

        // 区域定义
        readonly property int areaList: 0
        readonly property int areaParams: 1
        readonly property int areaButtons: 2

        // 当前状态
        property int currentArea: areaList
        property int listIndex: 0       // 列表索引（0-7）
        property int paramIndex: 0      // 参数索引
        property int buttonIndex: 0     // 按钮索引（0-1）

        Component.onCompleted: {
            root.focusItemIndex = 0
            root.focusSubArea = 0
        }

        // 监听列表索引变化
        onListIndexChanged: {
            root.currentSprinklerIndex = listIndex
            if (currentArea === areaList) {
                root.focusSubArea = 0
                root.focusItemIndex = listIndex
                root.focusParamIndex = -1
                root.focusButtonIndex = -1
            }
        }

        // 监听参数索引变化
        onParamIndexChanged: {
            if (currentArea === areaParams) {
                root.focusSubArea = 1
                root.focusParamIndex = paramIndex
                root.focusItemIndex = -1
                root.focusButtonIndex = -1
            }
        }

        // 监听按钮索引变化
        onButtonIndexChanged: {
            if (currentArea === areaButtons) {
                root.focusSubArea = 2
                root.focusButtonIndex = buttonIndex
                root.focusItemIndex = -1
                root.focusParamIndex = -1
            }
        }

        // 区域切换
        function switchToArea(newArea) {
            currentArea = newArea
            switch(newArea) {
            case areaList:
                root.focusSubArea = 0
                root.focusItemIndex = listIndex
                root.focusParamIndex = -1
                root.focusButtonIndex = -1
                break
            case areaParams:
                root.focusSubArea = 1
                root.focusParamIndex = paramIndex
                root.focusItemIndex = -1
                root.focusButtonIndex = -1
                break
            case areaButtons:
                root.focusSubArea = 2
                root.focusButtonIndex = buttonIndex
                root.focusItemIndex = -1
                root.focusParamIndex = -1
                break
            }
        }

        // 导航：列表区域（8个洒水项，0-7）
        function moveInListArea(direction) {
            var newIndex = listIndex

            switch(direction) {
            case "Up":
                if (listIndex > 0) newIndex = listIndex - 1
                break
            case "Down":
                if (listIndex < 7) newIndex = listIndex + 1
                break
            case "Right":
                switchToArea(areaParams)
                paramIndex = 0
                return
            }

            if (newIndex !== listIndex) {
                listIndex = newIndex
            }
        }

        // 导航：参数区域（5个参数）
        function moveInParamArea(direction) {
            var newIndex = paramIndex
            var maxIndex = 4  // 5个参数（0-4）

            switch(direction) {
            case "Left":
                if (paramIndex % 2 === 1) {
                    newIndex = paramIndex - 1
                } else {
                    switchToArea(areaList)
                    return
                }
                break
            case "Right":
                if (paramIndex % 2 === 0 && paramIndex < maxIndex) {
                    newIndex = paramIndex + 1
                }
                break
            case "Up":
                if (paramIndex >= 2) {
                    newIndex = paramIndex - 2
                } else {
                    switchToArea(areaList)
                    return
                }
                break
            case "Down":
                if (paramIndex <= maxIndex - 2) {
                    newIndex = paramIndex + 2
                } else {
                    switchToArea(areaButtons)
                    buttonIndex = 0
                    return
                }
                break
            }

            if (newIndex !== paramIndex && newIndex >= 0 && newIndex <= maxIndex) {
                paramIndex = newIndex
            }
        }

        // 导航：按钮区域（2个按钮，0-1）
        function moveInButtonArea(direction) {
            var newIndex = buttonIndex

            switch(direction) {
            case "Left":
                if (buttonIndex > 0) {
                    newIndex = buttonIndex - 1
                } else {
                    switchToArea(areaList)
                    return
                }
                break
            case "Right":
                if (buttonIndex < 1) {
                    newIndex = buttonIndex + 1
                }
                break
            case "Up":
                switchToArea(areaParams)
                paramIndex = 4  // 最后一个参数
                return
            }

            if (newIndex !== buttonIndex) {
                buttonIndex = newIndex
            }
        }
    }

    // ========== 键盘导航 ==========
    focus: true

    Keys.onPressed: (event) => {
        var direction = ""

        switch(event.key) {
        case Qt.Key_Up: direction = "Up"; break
        case Qt.Key_Down: direction = "Down"; break
        case Qt.Key_Left: direction = "Left"; break
        case Qt.Key_Right: direction = "Right"; break
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (navigationManager.currentArea === navigationManager.areaParams) {
                sprinklerConfigPanel.item.triggerParamInput(navigationManager.paramIndex)
            } else if (navigationManager.currentArea === navigationManager.areaButtons) {
                sprinklerConfigPanel.item.triggerButton(navigationManager.buttonIndex)
            }
            event.accepted = true
            return
        default:
            return
        }

        switch(navigationManager.currentArea) {
        case navigationManager.areaList:
            navigationManager.moveInListArea(direction)
            break
        case navigationManager.areaParams:
            navigationManager.moveInParamArea(direction)
            break
        case navigationManager.areaButtons:
            navigationManager.moveInButtonArea(direction)
            break
        }

        event.accepted = true
    }

    // 处理键盘事件（供 DeviceSettingsDialog 调用）
    function handleKeyPress(direction) {
        switch(navigationManager.currentArea) {
        case navigationManager.areaList:
            navigationManager.moveInListArea(direction)
            break
        case navigationManager.areaParams:
            navigationManager.moveInParamArea(direction)
            break
        case navigationManager.areaButtons:
            navigationManager.moveInButtonArea(direction)
            break
        }
    }

    // 保存所有配置（供 DeviceSettingsDialog 调用）
    function saveAllConfig() {
        if (sprinklerConfigPanel.item && typeof sprinklerConfigPanel.item.saveSprinklerConfig === "function") {
            sprinklerConfigPanel.item.saveSprinklerConfig()
        }
    }

    // ========== 左右分栏布局 ==========
    Row {
        anchors.fill: parent
        spacing: 0

        // ========== 左侧：洒水列表 ==========
        Loader {
            id: sprinklerListPanel
            width: 192
            height: parent.height
            source: "SprinklerListPanel.qml"

            onLoaded: {
                item.currentSprinklerIndex = Qt.binding(function() { return navigationManager.listIndex })
                item.focusItemIndex = Qt.binding(function() { return root.focusItemIndex })
                item.focusSubArea = Qt.binding(function() { return root.focusSubArea })
                item.sprinklerSelected.connect(function(sprinklerIndex) {
                    root.currentSprinklerIndex = sprinklerIndex
                    root.focusItemIndex = sprinklerIndex
                    root.focusSubArea = 0
                    navigationManager.listIndex = sprinklerIndex
                })
            }
        }

        // ========== 分隔线 ==========
        Rectangle {
            width: 2
            height: parent.height
            color: "#3d4556"
        }

        // ========== 右侧：洒水配置面板 ==========
        Loader {
            id: sprinklerConfigPanel
            width: parent.width - sprinklerListPanel.width - 2
            height: parent.height
            source: "SprinklerConfigPanel.qml"

            onLoaded: {
                item.deviceId = Qt.binding(function() { return root.deviceId })
                item.sprinklerIndex = Qt.binding(function() { return root.currentSprinklerIndex })
                item.focusSubArea = Qt.binding(function() { return root.focusSubArea })
                item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                item.focusButtonIndex = Qt.binding(function() { return root.focusButtonIndex })
                item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
            }
        }
    }
}
