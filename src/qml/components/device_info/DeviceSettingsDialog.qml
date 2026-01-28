import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../" as DeviceInfo  // ✅ 2026-01-25 [工业科技感设计]: 导入主题

// ✅ 2026-01-24 [设备信息界面重构] 设备参数设置弹窗
// ✅ 2026-01-25 [工业科技感设计]: 应用 IndustrialTheme
// ✅ 2026-01-28 [FIX 100.300.66]: 自适应屏幕尺寸（1920×1080 和 1280×800），居中显示
// ✅ 2026-01-28 [FIX 100.300.67]: 修改尺寸为屏幕的 80%
// QDS 预览版本：使用 Rectangle 替代 Dialog
Rectangle {
    id: root

    // ✅ 2026-01-28 [FIX 100.300.67]: 占整个屏幕的 80%
    // 1920×1080: 1536×864 (80%)
    // 1280×800: 1024×640 (80%)
    width: parent ? parent.width * 0.8 : 1536
    height: parent ? parent.height * 0.8 : 864

    // ✅ 2026-01-28 [FIX 100.300.66]: 居中显示
    anchors.centerIn: parent

    color: "#ec1e1e1e"
    // ✅ 2026-01-25: 使用主题背景色

    // ========== 公开属性 ==========
    property string deviceName: "1号皮带（预览）"  // 设备名称
    property int deviceId: 1                      // 设备ID
    property int currentCategory: 0               // 当前选中的参数类别
    property int currentBottomButtonIndex: 0      // ✅ 2026-01-24 [FIX]: 当前选中的底部按钮索引

    // ✅ 2026-01-24 [FIX]: 键盘导航支持
    focus: true

    Keys.onUpPressed: {
        // 上键：选择上一个类别
        if (root.currentCategory > 0) {
            root.currentCategory--
            root.currentBottomButtonIndex = 0  // 重置底部按钮索引
        }
    }

    Keys.onDownPressed: {
        // 下键：选择下一个类别
        if (root.currentCategory < 6) {  // ✅ 2026-01-24 [FIX]: 7个类别 (0-6)
            root.currentCategory++
            root.currentBottomButtonIndex = 0  // 重置底部按钮索引
        }
    }

    Keys.onLeftPressed: {
        // 左键：选择上一个底部按钮
        var bottomButtons = getBottomButtons(root.currentCategory)
        if (bottomButtons.length > 0 && root.currentBottomButtonIndex > 0) {
            root.currentBottomButtonIndex--
        }
    }

    Keys.onRightPressed: {
        // 右键：选择下一个底部按钮
        var bottomButtons = getBottomButtons(root.currentCategory)
        if (bottomButtons.length > 0 && root.currentBottomButtonIndex < bottomButtons.length - 1) {
            root.currentBottomButtonIndex++
        }
    }

    Keys.onReturnPressed: {
        // 回车键：触发当前选中的底部按钮
        var bottomButtons = getBottomButtons(root.currentCategory)
        if (bottomButtons.length > 0 && root.currentBottomButtonIndex < bottomButtons.length) {
            console.log("触发底部按钮:", bottomButtons[root.currentBottomButtonIndex])
        }
    }

    Keys.onEscapePressed: {
        // Escape 键：关闭弹窗
        root.visible = false
    }

    // ========== 背景图片 ==========
    Image {
        anchors.fill: parent
        source: "images/deviceInfo40.png"
        fillMode: Image.Stretch
        smooth: true
    }

    // ========== 内容区域 ==========
    Item {
        id: item1
        anchors.fill: parent

        // ========== 上部按钮栏 ==========
        // ✅ 2026-01-24 [FIX]: 使用 Rectangle 容器，351.png 作为背景
        Rectangle {
            id: topButtonsContainer
            anchors.top: parent.top
            anchors.left: parent.left  // ✅ 2026-01-24 [FIX]: 左右对齐
            anchors.right: parent.right  // ✅ 2026-01-24 [FIX]: 左右对齐
            anchors.topMargin: 15
            anchors.leftMargin: 2
            anchors.rightMargin: 2
            height: 45
            color: "transparent"

            // ✅ 2026-01-26 [FIX 100.300.25.17]: 添加 MouseArea 阻止点击事件穿透到背景
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    // 阻止点击事件穿透，不做任何操作
                    mouse.accepted = true
                }
            }

            // ✅ 背景图片 351.png（填充整个宽度）
            Image {
                id: topButtonsBackground
                anchors.fill: parent
                source: "images/351.png"
                fillMode: Image.Stretch
                smooth: true
                z: -1  // ✅ 确保在按钮下方
            }

            // ✅ 设备名称显示（左侧）
            // ✅ 2026-01-25 [工业科技感设计]: 使用直接颜色值
            Text {
                id: deviceNameText
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 20
                text: root.deviceName
                font.pixelSize: 18  // ✅ 标题字体
                font.weight: Font.Bold
                color: "#E0E0E0"  // ✅ 浅灰文字
                opacity: 1.0
            }

            // ✅ 按钮行（右侧）
            Row {
                id: topButtons
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 20
                spacing: 20

                // ✅ 2026-01-25 [工业科技感设计]: 关闭按钮
                Button {
                    text: "关闭"
                    width: 80
                    height: 35
                    flat: true
                    background: Rectangle {
                        color: "transparent"
                        border.color: "#3d4556"  // ✅ 灰色边框
                        border.width: 2
                        radius: 2
                        opacity: 1.0
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#E0E0E0"  // ✅ 浅灰文字
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        opacity: 1.0
                    }
                    onClicked: {
                        // ✅ 2026-01-24: 关闭弹窗
                        root.visible = false
                    }
                }

                // ✅ 2026-01-25 [工业科技感设计]: 保存按钮
                Button {
                    text: "保存"
                    width: 80
                    height: 35
                    flat: true
                    background: Rectangle {
                        color: "#2196F3"  // ✅ 科技蓝背景
                        border.color: "#42A5F5"
                        border.width: 1
                        radius: 2
                        opacity: 1.0
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#FFFFFF"  // ✅ 白色文字
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        opacity: 1.0
                    }
                    onClicked: {
                        // ✅ 2026-01-24: 保存参数（待实现）
                        console.log("保存参数")
                    }
                }

                // ✅ 2026-01-25 [工业科技感设计]: 重置按钮
                Button {
                    text: "重置"
                    width: 80
                    height: 35
                    flat: true
                    background: Rectangle {
                        color: "#FF9800"  // ✅ 橙色背景
                        border.color: "#FF9800"
                        border.width: 1
                        radius: 2
                        opacity: 1.0
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#FFFFFF"  // ✅ 白色文字
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        opacity: 1.0
                    }
                    onClicked: {
                        // ✅ 2026-01-24: 重置参数（待实现）
                        console.log("重置参数")
                    }
                }
            }
        }

        // ========== 左侧按钮列 ==========
        // ✅ 2026-01-24 [FIX 100.301]: 使用 Rectangle 容器，042.png 作为背景
        Rectangle {
            id: leftButtonsContainer
            anchors.left: parent.left

            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: 0
            anchors.topMargin: 65
            anchors.bottomMargin: 8
            width: 142
            color: "transparent"

            // ✅ 2026-01-26 [FIX 100.300.25.17]: 添加 MouseArea 阻止点击事件穿透到背景
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    // 阻止点击事件穿透，不做任何操作
                    mouse.accepted = true
                }
            }

            // ✅ 背景图片 042.png（使用 Image 作为背景）
            Image {
                id: leftButtonsBackground
                anchors.fill: parent
                anchors.rightMargin: 8
                source: "images/042.png"
                fillMode: Image.Stretch  // ✅ 2026-01-24 [FIX]: 拉伸填充整个区域
                smooth: true
                z: -1  // ✅ 确保在按钮下方
            }

            // ✅ 按钮列（在背景图片上方）
            Column {
                id: leftButtons
                anchors.fill: parent
                anchors.margins: 10
                anchors.leftMargin: 8
                anchors.rightMargin: 0
                anchors.topMargin: 13
                spacing: 10

                Repeater {
                    model: ["基本配置", "开关量输入", "模拟量输入", "电机控制", "制动器控制", "张紧控制", "逻辑控制"]

                    Button {
                        width: parent.width - 20
                        height: 40
                        text: modelData
                        // ✅ 2026-01-25 [工业科技感设计]: 禁用默认样式
                        flat: true

                        background: Rectangle {
                            // ✅ 2026-01-26 [FIX 100.300.25.6]: 改为透明，使用背景图片
                            color: "transparent"
                            border.color: root.currentCategory === index ? "#2196F3" : "#3d4556"
                            border.width: root.currentCategory === index ? 2 : 1
                            radius: 2
                            opacity: 1.0

                            // ✅ 2026-01-26 [FIX 100.300.25.6]: 添加背景图片
                            Image {
                                id: buttonBackgroundImage
                                anchors.fill: parent
                                fillMode: Image.Stretch
                                z: -1  // 放在最底层

                                // 使用相对路径，便于QDS预览
                                source: "../../images/dvList.png"

                                states: [
                                    State {
                                        name: "selected"
                                        when: root.currentCategory === index
                                        PropertyChanges {
                                            target: buttonBackgroundImage
                                            source: "../../images/dvList2.png"
                                        }
                                    },
                                    State {
                                        name: "normal"
                                        when: root.currentCategory !== index
                                        PropertyChanges {
                                            target: buttonBackgroundImage
                                            source: "../../images/dvList.png"
                                        }
                                    }
                                ]
                            }

                            // ✅ 2026-01-25 [工业科技感设计]: 激活状态左侧强调条
                            Rectangle {
                                visible: root.currentCategory === index
                                width: 4
                                height: parent.height
                                color: "#2196F3"
                                anchors.left: parent.left
                            }
                        }

                        contentItem: Text {
                            text: parent.text
                            // ✅ 2026-01-25 [FIX]: 使用直接颜色值以确保 QDS 预览正常
                            color: root.currentCategory === index ? "#E0E0E0" : "#9E9E9E"
                            font.pixelSize: 14
                            font.weight: root.currentCategory === index ? Font.Medium : Font.Normal
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            // ✅ 2026-01-25 [FIX]: 确保文字可见
                            opacity: 1.0
                        }

                        // ✅ 2026-01-24 [FIX]: 点击时更新类别和重置底部按钮索引
                        onClicked: {
                            root.currentCategory = index
                            root.currentBottomButtonIndex = 0
                        }
                    }
                }
            }
        }

        // ========== 中间参数显示区域 ==========
        Rectangle {
            id: contentArea
            anchors.left: leftButtonsContainer.right  // ✅ 2026-01-24 [FIX]: 更新锚点引用
            anchors.right: parent.right
            anchors.top: topButtonsContainer.bottom
            anchors.bottom: parent.bottom  // ✅ 2026-01-26 [FIX 100.300.25.8]: 延伸到底部，覆盖底部按钮区域
            anchors.leftMargin: 2
            anchors.rightMargin: 2
            anchors.topMargin: 2
            anchors.bottomMargin: 8
            color: "transparent"  // 透明，显示背景图片

            // ✅ 2026-01-26 [FIX 100.300.25.17]: 添加 MouseArea 阻止点击事件穿透到背景
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    // 阻止点击事件穿透，不做任何操作
                    mouse.accepted = true
                }
            }

            // ✅ 2026-01-26 [FIX 100.300.25.7]: 添加背景图片154.png
            Image {
                id: contentAreaBackground
                anchors.fill: parent
                anchors.leftMargin: -14
                anchors.rightMargin: 8
                anchors.topMargin: 8
                anchors.bottomMargin: 8
                source: "../../images/036.png"
                fillMode: Image.Stretch
                z: -1  // 放在最底层，作为所有页面的统一背景
            }

            // ✅ 2026-01-24 [FIX]: 使用 StackLayout 切换页面
            StackLayout {
                id: contentStack
                // ✅ 2026-01-26 [FIX 100.300.25.19]: 移除硬编码高度和无效 anchor
                // 原因：bottomButtonsContainer 不是 StackLayout 的兄弟元素，anchor 无效
                // 解决：使用 anchors.fill + bottomMargin 为底部按钮留出空间
                anchors.fill: parent
                // ✅ 2026-01-26 [FIX 100.300.25.13]: 添加 margins，让内容在背景图片边框内部显示
                anchors.leftMargin: 2
                anchors.rightMargin: 19
                anchors.topMargin: 19
                // ✅ 2026-01-26 [FIX 100.300.25.19]: 为底部按钮留出空间
                // bottomButtonsContainer 高度 60 + bottomMargin 20 - contentArea bottomMargin 8 = 72
                anchors.bottomMargin: 72
                currentIndex: root.currentCategory  // 自动切换页面

                // ✅ 2026-01-26 [FIX 100.300.25.9]: 添加调试输出
                Component.onCompleted: {
                    console.log("✅ [DEBUG] StackLayout 宽度:", width)
                    console.log("✅ [DEBUG] StackLayout 高度:", height)
                    console.log("✅ [DEBUG] StackLayout 子元素数量:", count)
                }

                // 0: 基本配置
                // ✅ 2026-01-24 [FIX 100.302]: 使用 BasicConfigPage 组件
                Loader {
                    id: basicConfigPageLoader
                    // ✅ 2026-01-26 [FIX 100.300.25.11]: 为 Loader 设置明确尺寸，便于 QDS 预览
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    active: root.currentCategory === 0  // 仅在选中时加载
                    source: "pages/BasicConfigPage.qml"

                    onLoaded: {
                        if (item) {
                            console.log("✅ [DeviceSettingsDialog] BasicConfigPage 加载成功")
                            item.deviceId = root.deviceId
                            item.deviceName = root.deviceName
                        }
                    }

                    onStatusChanged: {
                        if (basicConfigPageLoader.status === Loader.Error) {
                            console.error("❌ [DeviceSettingsDialog] BasicConfigPage 加载失败")
                        }
                    }
                }

                // 1: 开关量输入
                // ✅ 2026-01-25 [FIX 100.306]: 使用 SwitchInputPage 组件
                Loader {
                    id: switchInputPageLoader
                    // ✅ 2026-01-26 [FIX 100.300.25.11]: 为 Loader 设置明确尺寸，便于 QDS 预览
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    active: root.currentCategory === 1  // 仅在选中时加载
                    source: "pages/SwitchInputPage.qml"

                    // ✅ 2026-01-26 [FIX 100.300.25.9]: 添加调试输出
                    Component.onCompleted: {
                        console.log("✅ [DEBUG] SwitchInputPage Loader 宽度:", width)
                        console.log("✅ [DEBUG] SwitchInputPage Loader 高度:", height)
                    }

                    onLoaded: {
                        if (item) {
                            console.log("✅ [DeviceSettingsDialog] SwitchInputPage 加载成功")
                            console.log("✅ [DEBUG] SwitchInputPage item 宽度:", item.width)
                            console.log("✅ [DEBUG] SwitchInputPage item 高度:", item.height)
                            item.deviceId = root.deviceId
                            item.deviceName = root.deviceName
                        }
                    }

                    onStatusChanged: {
                        if (switchInputPageLoader.status === Loader.Error) {
                            console.error("❌ [DeviceSettingsDialog] SwitchInputPage 加载失败")
                        }
                    }
                }

                // 2: 模拟量输入
                // ✅ 2026-01-25 [FIX 100.308]: 使用 AnalogInputPage 组件
                Loader {
                    id: analogInputPageLoader
                    // ✅ 2026-01-26 [FIX 100.300.25.11]: 为 Loader 设置明确尺寸，便于 QDS 预览
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    active: root.currentCategory === 2  // 仅在选中时加载
                    source: "pages/AnalogInputPage.qml"

                    onLoaded: {
                        if (item) {
                            console.log("✅ [DeviceSettingsDialog] AnalogInputPage 加载成功")
                            // ✅ 2026-01-28 [FIX 100.300.73.2]: 移除 Qt.binding()，使用 anchors.fill 方案
                            item.deviceId = root.deviceId
                            item.deviceName = root.deviceName
                        }
                    }

                    onStatusChanged: {
                        if (analogInputPageLoader.status === Loader.Error) {
                            console.error("❌ [DeviceSettingsDialog] AnalogInputPage 加载失败")
                        }
                    }
                }

                // 3: 电机控制
                // ✅ 2026-01-25 [FIX 100.310]: 使用 MotorControlPage 组件
                Loader {
                    id: motorControlPageLoader
                    // ✅ 2026-01-26 [FIX 100.300.25.11]: 为 Loader 设置明确尺寸，便于 QDS 预览
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    active: root.currentCategory === 3  // 仅在选中时加载
                    source: "pages/MotorControlPage.qml"

                    onLoaded: {
                        if (item) {
                            console.log("✅ [DeviceSettingsDialog] MotorControlPage 加载成功")
                            item.deviceId = root.deviceId
                            item.deviceName = root.deviceName
                        }
                    }

                    onStatusChanged: {
                        if (motorControlPageLoader.status === Loader.Error) {
                            console.error("❌ [DeviceSettingsDialog] MotorControlPage 加载失败")
                        }
                    }
                }

                // 4: 制动器控制
                Rectangle {
                    color: "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "制动器控制\n（待实现）"
                        font.pixelSize: 18
                        color: "#CCCCCC"
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                // 5: 张紧控制
                Rectangle {
                    color: "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "张紧控制\n（待实现）"
                        font.pixelSize: 18
                        color: "#CCCCCC"
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                // 6: 逻辑控制
                Rectangle {
                    color: "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "逻辑控制\n（待实现）"
                        font.pixelSize: 18
                        color: "#CCCCCC"
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }

        // ========== 底部按钮区域 ==========
        // ✅ 2026-01-24 [FIX]: 根据左侧选择的类别动态显示不同的按钮
        Rectangle {
            id: bottomButtonsContainer
            anchors.left: leftButtonsContainer.right
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            anchors.bottomMargin: 20
            height: 60
            color: "transparent"

            // ✅ 按钮行（根据 currentCategory 动态显示）
            Row {
                id: bottomButtons
                anchors.centerIn: parent
                spacing: 20

                // ✅ 2026-01-24: 使用 Repeater 根据类别动态生成按钮
                Repeater {
                    model: getBottomButtons(root.currentCategory)

                    Button {
                        text: modelData
                        width: 100
                        height: 40
                        background: Rectangle {
                            // ✅ 2026-01-24 [FIX]: 选中状态高亮
                            color: root.currentBottomButtonIndex === index ? "#00AA00" : "#555555"
                            border.color: root.currentBottomButtonIndex === index ? "#00FF00" : "#888888"
                            border.width: root.currentBottomButtonIndex === index ? 2 : 1
                            radius: 4
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "#FFFFFF"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.bold: root.currentBottomButtonIndex === index  // ✅ 选中时加粗
                        }
                        onClicked: {
                            root.currentBottomButtonIndex = index  // ✅ 点击时更新选中索引
                            console.log("底部按钮点击:", modelData)
                        }
                    }
                }
            }
        }
    }

    // ========== 辅助函数 ==========
    function getCategoryName(index) {
        var names = ["基本配置", "开关量输入", "模拟量输入", "电机控制", "制动器控制", "张紧控制", "逻辑控制"]
        return names[index] || "未知类别"
    }

    // ✅ 2026-01-24 [FIX]: 根据类别返回底部按钮列表
    function getBottomButtons(categoryIndex) {
        switch(categoryIndex) {
        case 0: // 基本配置
            return ["保存配置", "恢复默认", "导入配置", "导出配置"]
        case 1: // 开关量输入
            return ["添加输入", "删除输入", "测试输入"]
        case 2: // 模拟量输入
            return ["添加输入", "删除输入", "校准"]
        case 3: // 电机控制
            return ["启动测试", "停止测试", "参数校验"]
        case 4: // 制动器控制
            return ["制动测试", "释放测试", "参数校验"]
        case 5: // 张紧控制
            return ["张紧测试", "释放测试", "参数校验"]
        case 6: // 逻辑控制
            return ["添加逻辑", "删除逻辑", "测试逻辑"]
        default:
            return []
        }
    }
}
