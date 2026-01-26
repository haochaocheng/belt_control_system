import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// ✅ 2026-01-25 [开关量输入页面] 左右分栏布局：左侧列表 + 右侧参数编辑
Rectangle {
    id: root
    color: "transparent"

    // ========== 公开属性 ==========
    property int deviceId: 1
    property string deviceName: "1号皮带"
    property int currentProtectionIndex: 0  // 当前选中的保护项索引

    // ========== 开关量保护模型 ==========
    ListModel {
        id: digitalProtectionModel
        ListElement { name: "急停"; active: false; moduleType: "输入模块1"; registerAddress: 2; channelNumber: 0 }
        ListElement { name: "跑偏"; active: false; moduleType: "输入模块1"; registerAddress: 2; channelNumber: 1 }
        ListElement { name: "撕裂"; active: false; moduleType: "输入模块1"; registerAddress: 2; channelNumber: 2 }
        ListElement { name: "烟雾"; active: false; moduleType: "输入模块1"; registerAddress: 2; channelNumber: 3 }
        ListElement { name: "温度"; active: false; moduleType: "输入模块1"; registerAddress: 2; channelNumber: 4 }
        ListElement { name: "护网"; active: false; moduleType: "输入模块1"; registerAddress: 2; channelNumber: 5 }
        ListElement { name: "堆煤"; active: false; moduleType: "输入模块1"; registerAddress: 2; channelNumber: 6 }
        ListElement { name: "主机急停"; active: false; moduleType: "输入模块1"; registerAddress: 2; channelNumber: 7 }
    }

    // ========== 主布局：左右分栏 ==========
    RowLayout {
        anchors.fill: parent
        spacing: 15

        // ========== 左侧：开关量列表 ==========
        // ✅ 2026-01-26 [FIX 100.300.22]: 统一为电机控制的主题风格
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 240
            color: "#1a1f2e"  // 与电机控制一致的深蓝灰背景

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 0
                spacing: 0

                // 标题栏
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    color: "#252b3d"
                    border.color: "#3d4556"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "开关量列表"
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        color: "#E0E0E0"
                    }
                }

                // 开关量列表
                ListView {
                    id: protectionListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: digitalProtectionModel
                    spacing: 0
                    currentIndex: root.currentProtectionIndex

                    delegate: Rectangle {
                        width: protectionListView.width
                        height: 60
                        color: "transparent"  // ✅ 2026-01-26 [FIX 100.300.25]: 改为透明，使用背景图片
                        border.color: root.currentProtectionIndex === index ? "#2196F3" : "#3d4556"
                        border.width: 1

                        // ✅ 2026-01-26 [FIX 100.300.25]: 添加背景图片
                        // ✅ 2026-01-26 [FIX 100.300.25.2]: 改用states方式，使用相对路径便于QDS预览
                        Image {
                            id: backgroundImage
                            anchors.fill: parent
                            fillMode: Image.Stretch
                            z: -1  // 放在最底层

                            // 使用相对路径，便于QDS预览
                            source: "../../images/bhNameBK.png"

                            states: [
                                State {
                                    name: "selected"
                                    when: root.currentProtectionIndex === index
                                    PropertyChanges {
                                        target: backgroundImage
                                        source: "../../images/bhNameBK1.png"
                                    }
                                },
                                State {
                                    name: "normal"
                                    when: root.currentProtectionIndex !== index
                                    PropertyChanges {
                                        target: backgroundImage
                                        source: "../../images/bhNameBK.png"
                                    }
                                }
                            ]
                        }

                        // ✅ 左侧激活指示条
                        Rectangle {
                            visible: root.currentProtectionIndex === index
                            width: 4
                            height: parent.height
                            color: "#2196F3"
                            anchors.left: parent.left
                        }

                        // ✅ 开关量信息
                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 20
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            // 开关量名称
                            Text {
                                text: model.name
                                font.pixelSize: 16
                                font.weight: root.currentProtectionIndex === index ? Font.Bold : Font.Normal
                                color: root.currentProtectionIndex === index ? "#E0E0E0" : "#9E9E9E"
                            }

                            // 状态指示
                            Row {
                                spacing: 8

                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 2
                                    color: model.active ? "#F44336" : "#4CAF50"  // 红色激活，绿色正常
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: model.active ? "已激活" : "正常"
                                    font.pixelSize: 12
                                    color: "#9E9E9E"
                                }
                            }
                        }

                        // ✅ 鼠标点击
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.currentProtectionIndex = index
                                loadProtectionData(index)
                            }
                        }
                    }
                }
            }
        }

        // ========== 右侧：参数编辑区域 ==========
        // ✅ 2026-01-26 [FIX 100.300.24]: 统一为电机控制的主题风格
        Rectangle {
            Layout.fillHeight: true
            Layout.fillWidth: true
            color: "transparent"  // 与电机控制一致：透明背景
            // 移除 radius
            // 移除 border

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 12

                // 标题
                Text {
                    text: "保护参数设置"
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    color: "#E0E0E0"  // 与电机控制一致：浅灰色
                    Layout.alignment: Qt.AlignHCenter
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#3d4556"  // 与电机控制一致：中灰色
                    opacity: 0.5
                }

                // 滚动区域：参数字段
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    ColumnLayout {
                        width: parent.width - 20
                        spacing: 12

                        // 保护名称
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: "保护名称:"
                                font.pixelSize: 14
                                color: "#9E9E9E"  // 与电机控制一致：标签灰色
                                Layout.preferredWidth: 100
                            }

                            TextField {
                                id: nameField
                                Layout.fillWidth: true
                                font.pixelSize: 14

                                background: Rectangle {
                                    color: "#2d3548"  // 与电机控制一致：深蓝灰
                                    radius: 2  // 与电机控制一致：小圆角
                                    border.color: nameField.activeFocus ? "#2196F3" : "#3d4556"  // 与电机控制一致
                                    border.width: 1
                                }

                                color: "#E0E0E0"  // 与电机控制一致：浅灰色
                            }
                        }

                        // 模块类型
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: "模块类型:"
                                font.pixelSize: 14
                                color: "#9E9E9E"
                                Layout.preferredWidth: 100
                            }

                            ComboBox {
                                id: moduleTypeCombo
                                Layout.fillWidth: true

                                model: ["输入模块1", "输入模块2", "输入模块3", "输入模块4", "输出模块", "主模块"]

                                background: Rectangle {
                                    color: "#2d3548"
                                    radius: 2
                                    border.color: moduleTypeCombo.pressed ? "#3498db" : "#7f8c8d"
                                    border.width: 1
                                }

                                contentItem: Text {
                                    text: moduleTypeCombo.displayText
                                    color: "#E0E0E0"
                                    font.pixelSize: 12
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: 10
                                }

                                onCurrentTextChanged: {
                                    // 根据模块类型自动设置寄存器地址
                                    if (currentText === "输入模块1") {
                                        registerAddressSpin.value = 2
                                    } else if (currentText === "输入模块2") {
                                        registerAddressSpin.value = 3
                                    } else if (currentText === "输入模块3") {
                                        registerAddressSpin.value = 4
                                    } else if (currentText === "输入模块4") {
                                        registerAddressSpin.value = 5
                                    } else if (currentText === "输出模块") {
                                        registerAddressSpin.value = 50
                                    }
                                }
                            }
                        }

                        // 寄存器地址
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            visible: moduleTypeCombo.currentText !== "主模块"

                            Text {
                                text: "寄存器地址:"
                                font.pixelSize: 14
                                color: "#9E9E9E"
                                Layout.preferredWidth: 100
                            }

                            SpinBox {
                                id: registerAddressSpin
                                from: 0
                                to: 255
                                editable: true
                                Layout.fillWidth: true

                                background: Rectangle {
                                    color: "#2d3548"
                                    radius: 2
                                    border.color: registerAddressSpin.activeFocus ? "#3498db" : "#7f8c8d"
                                    border.width: 1
                                }

                                contentItem: TextInput {
                                    text: registerAddressSpin.textFromValue(registerAddressSpin.value, registerAddressSpin.locale)
                                    font.pixelSize: 12
                                    color: "#E0E0E0"
                                    horizontalAlignment: Qt.AlignHCenter
                                    verticalAlignment: Qt.AlignVCenter
                                    readOnly: !registerAddressSpin.editable
                                    validator: registerAddressSpin.validator
                                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                                }
                            }
                        }

                        // 通道编号
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: "通道编号:"
                                font.pixelSize: 14
                                color: "#9E9E9E"
                                Layout.preferredWidth: 100
                            }

                            SpinBox {
                                id: channelSpin
                                from: 0
                                to: 7
                                editable: true
                                Layout.fillWidth: true

                                background: Rectangle {
                                    color: "#2d3548"
                                    radius: 2
                                    border.color: channelSpin.activeFocus ? "#3498db" : "#7f8c8d"
                                    border.width: 1
                                }

                                contentItem: TextInput {
                                    text: channelSpin.textFromValue(channelSpin.value, channelSpin.locale)
                                    font.pixelSize: 12
                                    color: "#E0E0E0"
                                    horizontalAlignment: Qt.AlignHCenter
                                    verticalAlignment: Qt.AlignVCenter
                                    readOnly: !channelSpin.editable
                                    validator: channelSpin.validator
                                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: "#3d4556"
                            opacity: 0.2
                        }

                        // 保护延时
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: "保护延时(秒):"
                                font.pixelSize: 14
                                color: "#9E9E9E"
                                Layout.preferredWidth: 100
                            }

                            SpinBox {
                                id: delaySpin
                                from: 0
                                to: 600
                                value: 10
                                stepSize: 1
                                editable: true
                                Layout.fillWidth: true

                                property int decimals: 1
                                property real realValue: value / 10

                                textFromValue: function(value, locale) {
                                    return Number(value / 10).toLocaleString(locale, 'f', 1)
                                }

                                valueFromText: function(text, locale) {
                                    return Number.fromLocaleString(locale, text) * 10
                                }

                                background: Rectangle {
                                    color: "#2d3548"
                                    radius: 2
                                    border.color: delaySpin.activeFocus ? "#3498db" : "#7f8c8d"
                                    border.width: 1
                                }

                                contentItem: TextInput {
                                    text: delaySpin.textFromValue(delaySpin.value, delaySpin.locale)
                                    font.pixelSize: 12
                                    color: "#E0E0E0"
                                    horizontalAlignment: Qt.AlignHCenter
                                    verticalAlignment: Qt.AlignVCenter
                                    readOnly: !delaySpin.editable
                                    validator: delaySpin.validator
                                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                                }
                            }
                        }

                        // 播放次数
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: "播放次数:"
                                font.pixelSize: 14
                                color: "#9E9E9E"
                                Layout.preferredWidth: 100
                            }

                            SpinBox {
                                id: playCountSpin
                                from: 1
                                to: 99
                                value: 3
                                editable: true
                                Layout.fillWidth: true

                                background: Rectangle {
                                    color: "#2d3548"
                                    radius: 2
                                    border.color: playCountSpin.activeFocus ? "#3498db" : "#7f8c8d"
                                    border.width: 1
                                }

                                contentItem: TextInput {
                                    text: playCountSpin.textFromValue(playCountSpin.value, playCountSpin.locale)
                                    font.pixelSize: 12
                                    color: "#E0E0E0"
                                    horizontalAlignment: Qt.AlignHCenter
                                    verticalAlignment: Qt.AlignVCenter
                                    readOnly: !playCountSpin.editable
                                    validator: playCountSpin.validator
                                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                                }
                            }
                        }

                        // 播放时长
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: "播放时长(秒):"
                                font.pixelSize: 14
                                color: "#9E9E9E"
                                Layout.preferredWidth: 100
                            }

                            SpinBox {
                                id: durationSpin
                                from: 1
                                to: 600
                                value: 50
                                stepSize: 5
                                editable: true
                                Layout.fillWidth: true

                                property int decimals: 1
                                property real realValue: value / 10

                                textFromValue: function(value, locale) {
                                    return Number(value / 10).toLocaleString(locale, 'f', 1)
                                }

                                valueFromText: function(text, locale) {
                                    return Number.fromLocaleString(locale, text) * 10
                                }

                                background: Rectangle {
                                    color: "#2d3548"
                                    radius: 2
                                    border.color: durationSpin.activeFocus ? "#3498db" : "#7f8c8d"
                                    border.width: 1
                                }

                                contentItem: TextInput {
                                    text: durationSpin.textFromValue(durationSpin.value, durationSpin.locale)
                                    font.pixelSize: 12
                                    color: "#E0E0E0"
                                    horizontalAlignment: Qt.AlignHCenter
                                    verticalAlignment: Qt.AlignVCenter
                                    readOnly: !durationSpin.editable
                                    validator: durationSpin.validator
                                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: "#3d4556"
                            opacity: 0.2
                        }

                        // 语音报警类型
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: "语音报警:"
                                font.pixelSize: 14
                                color: "#9E9E9E"
                                Layout.preferredWidth: 100
                            }

                            RadioButton {
                                id: ttsRadio
                                text: "文字转语音"
                                checked: true
                                font.pixelSize: 12

                                indicator: Rectangle {
                                    implicitWidth: 18
                                    implicitHeight: 18
                                    x: ttsRadio.leftPadding
                                    y: parent.height / 2 - height / 2
                                    radius: 9
                                    border.color: ttsRadio.checked ? "#00d4ff" : "#7f8c8d"
                                    border.width: 2
                                    color: "transparent"

                                    Rectangle {
                                        width: 10
                                        height: 10
                                        x: 4
                                        y: 4
                                        radius: 5
                                        color: "#3d4556"
                                        visible: ttsRadio.checked
                                    }
                                }

                                contentItem: Text {
                                    text: ttsRadio.text
                                    font: ttsRadio.font
                                    color: "#E0E0E0"
                                    leftPadding: ttsRadio.indicator.width + 8
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            RadioButton {
                                id: fileRadio
                                text: "音频文件"
                                checked: false
                                font.pixelSize: 12

                                indicator: Rectangle {
                                    implicitWidth: 18
                                    implicitHeight: 18
                                    x: fileRadio.leftPadding
                                    y: parent.height / 2 - height / 2
                                    radius: 9
                                    border.color: fileRadio.checked ? "#00d4ff" : "#7f8c8d"
                                    border.width: 2
                                    color: "transparent"

                                    Rectangle {
                                        width: 10
                                        height: 10
                                        x: 4
                                        y: 4
                                        radius: 5
                                        color: "#3d4556"
                                        visible: fileRadio.checked
                                    }
                                }

                                contentItem: Text {
                                    text: fileRadio.text
                                    font: fileRadio.font
                                    color: "#E0E0E0"
                                    leftPadding: fileRadio.indicator.width + 8
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }

                        // TTS文字输入
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            visible: ttsRadio.checked

                            Text {
                                text: "报警文字:"
                                font.pixelSize: 14
                                color: "#9E9E9E"
                                Layout.preferredWidth: 100
                            }

                            TextField {
                                id: ttsTextField
                                placeholderText: "输入报警文字内容..."
                                Layout.fillWidth: true
                                font.pixelSize: 12

                                background: Rectangle {
                                    color: "#2d3548"
                                    radius: 2
                                    border.color: ttsTextField.activeFocus ? "#3498db" : "#7f8c8d"
                                    border.width: 1
                                }

                                color: "#ecf0f1"
                            }
                        }

                        // 音频文件选择
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            visible: fileRadio.checked

                            Text {
                                text: "音频文件:"
                                font.pixelSize: 14
                                color: "#9E9E9E"
                                Layout.preferredWidth: 100
                            }

                            TextField {
                                id: audioField
                                placeholderText: "选择音频文件..."
                                Layout.fillWidth: true
                                readOnly: true
                                font.pixelSize: 12

                                background: Rectangle {
                                    color: "#2d3548"
                                    radius: 2
                                    border.color: "#3d4556"
                                    border.width: 1
                                }

                                color: "#ecf0f1"
                            }

                            Button {
                                text: "浏览"
                                Layout.preferredWidth: 60
                                Layout.preferredHeight: 30

                                background: Rectangle {
                                    color: parent.pressed ? "#2980b9" : (parent.hovered ? "#3498db" : "#34495e")
                                    radius: 2
                                    border.color: "#2196F3"
                                    border.width: 1
                                }

                                contentItem: Text {
                                    text: parent.text
                                    font.pixelSize: 11
                                    color: "#E0E0E0"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: {
                                    console.log("打开文件选择对话框")
                                    // TODO: 实现文件选择
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#00d4ff"
                    opacity: 0.3
                }

                // 底部按钮
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Button {
                        text: "保存"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35

                        background: Rectangle {
                            color: parent.pressed ? "#27ae60" : (parent.hovered ? "#2ecc71" : "#27ae60")
                            radius: 2
                        }

                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 13
                            font.bold: true
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            saveProtectionData()
                        }
                    }

                    Button {
                        text: "删除"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35

                        background: Rectangle {
                            color: parent.pressed ? "#c0392b" : (parent.hovered ? "#e74c3c" : "#d35400")
                            radius: 2
                        }

                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 13
                            font.bold: true
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            console.log("删除保护:", nameField.text)
                            // TODO: 实现删除功能
                        }
                    }

                    Button {
                        text: "重置"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35

                        background: Rectangle {
                            color: parent.pressed ? "#7f8c8d" : (parent.hovered ? "#95a5a6" : "#7f8c8d")
                            radius: 2
                        }

                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 13
                            font.bold: true
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            loadProtectionData(root.currentProtectionIndex)
                        }
                    }
                }
            }
        }
    }

    // ========== 辅助函数 ==========

    // 加载保护数据到右侧编辑区域
    function loadProtectionData(index) {
        if (index < 0 || index >= digitalProtectionModel.count) {
            return
        }

        var item = digitalProtectionModel.get(index)

        // ✅ 2026-01-25 [数据库集成] 从数据库加载完整的保护参数
        var protection = deviceConfigMgr.loadDigitalProtection(root.deviceId, item.name)

        if (protection && protection.protection_name) {
            // 从数据库加载完整参数
            nameField.text = protection.protection_name
            moduleTypeCombo.currentIndex = moduleTypeCombo.model.indexOf(protection.module_type)
            registerAddressSpin.value = protection.register_address
            channelSpin.value = protection.channel_number
            delaySpin.value = protection.protection_delay * 10  // 转换为整数（0.1秒精度）
            playCountSpin.value = protection.play_count
            durationSpin.value = protection.play_duration * 10  // 转换为整数（0.1秒精度）
            ttsRadio.checked = protection.use_text_to_speech === 1
            fileRadio.checked = protection.use_text_to_speech === 0
            ttsTextField.text = protection.tts_text || (item.name + "保护报警")
            audioField.text = protection.audio_file || ""

            console.log("✅ [SwitchInputPage] 从数据库加载完整参数:", item.name)
        } else {
            // 数据库中没有，使用ListModel中的基本数据
            nameField.text = item.name
            moduleTypeCombo.currentIndex = moduleTypeCombo.model.indexOf(item.moduleType)
            registerAddressSpin.value = item.registerAddress
            channelSpin.value = item.channelNumber

            // 设置默认值
            delaySpin.value = 10  // 1.0秒
            playCountSpin.value = 3
            durationSpin.value = 50  // 5.0秒
            ttsRadio.checked = true
            ttsTextField.text = item.name + "保护报警"
            audioField.text = ""

            console.log("⚠️ [SwitchInputPage] 数据库中没有详细参数，使用默认值:", item.name)
        }
    }

    // 保存保护数据
    function saveProtectionData() {
        if (root.currentProtectionIndex < 0 || root.currentProtectionIndex >= digitalProtectionModel.count) {
            return
        }

        // 更新ListModel
        digitalProtectionModel.setProperty(root.currentProtectionIndex, "name", nameField.text)
        digitalProtectionModel.setProperty(root.currentProtectionIndex, "moduleType", moduleTypeCombo.currentText)
        digitalProtectionModel.setProperty(root.currentProtectionIndex, "registerAddress", registerAddressSpin.value)
        digitalProtectionModel.setProperty(root.currentProtectionIndex, "channelNumber", channelSpin.value)

        console.log("✅ 保存保护数据到内存:", nameField.text)

        // ✅ 2026-01-25 [数据库集成] 保存到数据库
        var protection = {
            "protection_name": nameField.text,
            "module_type": moduleTypeCombo.currentText,
            "register_address": registerAddressSpin.value,
            "channel_number": channelSpin.value,
            "protection_delay": delaySpin.realValue,
            "play_count": playCountSpin.value,
            "play_duration": durationSpin.realValue,
            "use_text_to_speech": ttsRadio.checked,
            "tts_text": ttsTextField.text,
            "audio_file": audioField.text
        }

        if (deviceConfigMgr.saveDigitalProtection(root.deviceId, protection)) {
            console.log("✅ [SwitchInputPage] 保存到数据库成功:", nameField.text)
        } else {
            console.error("❌ [SwitchInputPage] 保存到数据库失败:", nameField.text)
        }
    }

    // 组件加载完成后，加载第一个保护项的数据
    Component.onCompleted: {
        // ✅ 2026-01-25 [数据库集成] 从数据库加载开关量保护配置
        console.log("✅ [SwitchInputPage] 开始加载设备", deviceId, "的开关量保护配置")

        var protections = deviceConfigMgr.loadAllDigitalProtections(deviceId)
        console.log("✅ [SwitchInputPage] 从数据库加载了", protections.length, "个保护项")

        if (protections.length > 0) {
            // 清空现有模型
            digitalProtectionModel.clear()

            // 加载数据库中的配置
            for (var i = 0; i < protections.length; i++) {
                var p = protections[i]
                digitalProtectionModel.append({
                    name: p.protection_name,
                    active: p.active === 1,
                    moduleType: p.module_type,
                    registerAddress: p.register_address,
                    channelNumber: p.channel_number
                })
            }

            console.log("✅ [SwitchInputPage] 数据库配置加载完成")
        } else {
            console.log("⚠️ [SwitchInputPage] 数据库中没有配置，使用默认配置")
        }

        // 加载第一个保护项的详细参数
        if (digitalProtectionModel.count > 0) {
            loadProtectionData(0)
        }
    }
}
