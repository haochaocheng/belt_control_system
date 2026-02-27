// 2026-02-25 14:05 [Phase 7.47.2]: 批量合成内容组件
// 用途：批量语音合成的内容区域，可在 QDS 中可视化设计
// 使用方式：由 BatchSynthesisDialog.qml (Popup) 包装使用
// ✅ 2026-02-26 21:15 [Phase 7.47.18]: 添加 showHeader 属性，支持嵌入模式

import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5
import com.belt.control 1.0  // ✅ 2026-02-27 02:15 [Phase 7.47.28]: 导入TTSConfig单例

Rectangle {
    id: root
    width: 800
    height: 580
    color: "#1a1a2e"
    border.color: "#4a4a6a"
    border.width: 2
    radius: 8

    property var batchGenerator: null
    // ✅ 2026-02-26 21:15 [Phase 7.47.18]: 是否显示标题栏（嵌入模式设为 false）
    property bool showHeader: true

    // 关闭信号，由父组件处理
    signal closeRequested()

    // ✅ 2026-02-27 01:30 [Phase 7.47.27]: 获取输出基础目录（支持linaro和pi用户）
    function getOutputBaseDir() {
        // 从环境变量获取用户名，默认linaro
        var userName = Qt.platform.os === "linux" ?
            (typeof process !== 'undefined' && process.env.BELT_CONTROL_USER ?
             process.env.BELT_CONTROL_USER : "linaro") : "linaro"
        return "/home/" + userName + "/belt-control-data/audio"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10

        // 标题栏（可隐藏）
        RowLayout {
            Layout.fillWidth: true
            visible: root.showHeader  // ✅ 2026-02-26 21:15 [Phase 7.47.18]: 根据属性控制显示
            Text {
                text: "批量语音合成"
                font.pixelSize: 24
                font.bold: true
                color: "#ffffff"
            }
            Item { Layout.fillWidth: true }
            Button {
                text: "X"
                width: 30
                height: 30
                onClicked: root.closeRequested()
                background: Rectangle {
                    color: parent.hovered ? "#ff4444" : "transparent"
                    radius: 4
                }
                contentItem: Text {
                    text: parent.text
                    color: "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // 分隔线（可隐藏）
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#4a4a6a"
            visible: root.showHeader  // ✅ 2026-02-26 21:15 [Phase 7.47.18]: 根据属性控制显示
        }

        // 主内容区
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 20

            // 左侧：配置区
            // ✅ 2026-02-26 22:45 [Phase 7.47.19]: 修复对齐问题，添加顶部对齐
            ColumnLayout {
                Layout.preferredWidth: 350
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignTop
                spacing: 10

                // 分类选择
                GroupBox {
                    Layout.fillWidth: true
                    title: "选择分类"
                    background: Rectangle {
                        color: "#252540"
                        border.color: "#4a4a6a"
                        radius: 4
                        y: parent.topPadding - parent.padding
                        height: parent.height - parent.topPadding + parent.padding
                    }
                    label: Text {
                        text: parent.title
                        color: "#aaaacc"
                        font.pixelSize: 14
                    }

                    GridLayout {
                        columns: 2
                        columnSpacing: 15
                        rowSpacing: 5

                        CheckBox {
                            id: chkSwitchInput
                            text: "开关量输入保护"
                            checked: true
                            contentItem: Text {
                                text: parent.text
                                color: "#ffffff"
                                leftPadding: parent.indicator.width + 5
                            }
                        }
                        CheckBox {
                            id: chkAnalogInput
                            text: "模拟量输入保护"
                            checked: true
                            contentItem: Text {
                                text: parent.text
                                color: "#ffffff"
                                leftPadding: parent.indicator.width + 5
                            }
                        }
                        CheckBox {
                            id: chkMotor
                            text: "电机保护"
                            checked: true
                            contentItem: Text {
                                text: parent.text
                                color: "#ffffff"
                                leftPadding: parent.indicator.width + 5
                            }
                        }
                        CheckBox {
                            id: chkBrake
                            text: "制动器保护"
                            checked: true
                            contentItem: Text {
                                text: parent.text
                                color: "#ffffff"
                                leftPadding: parent.indicator.width + 5
                            }
                        }
                        CheckBox {
                            id: chkTension
                            text: "张紧控制保护"
                            checked: true
                            contentItem: Text {
                                text: parent.text
                                color: "#ffffff"
                                leftPadding: parent.indicator.width + 5
                            }
                        }
                        CheckBox {
                            id: chkLinePosition
                            text: "沿线点位保护"
                            checked: true
                            contentItem: Text {
                                text: parent.text
                                color: "#ffffff"
                                leftPadding: parent.indicator.width + 5
                            }
                        }
                        CheckBox {
                            id: chkSystemSound
                            text: "系统提示音"
                            checked: true
                            contentItem: Text {
                                text: parent.text
                                color: "#ffffff"
                                leftPadding: parent.indicator.width + 5
                            }
                        }
                        // ✅ 2026-02-27 05:30 [Phase 7.47.30]: 补充1#PD已有但批量代码缺失的语音分类
                        CheckBox {
                            id: chkBeltOperation
                            text: "皮带操作状态"
                            checked: true
                            contentItem: Text {
                                text: parent.text
                                color: "#ffffff"
                                leftPadding: parent.indicator.width + 5
                            }
                        }
                        CheckBox {
                            id: chkSystemStatus
                            text: "系统/通讯状态"
                            checked: true
                            contentItem: Text {
                                text: parent.text
                                color: "#ffffff"
                                leftPadding: parent.indicator.width + 5
                            }
                        }
                    }
                }

                // 范围设置 - 2列布局，更宽的输入框
                // ✅ 2026-02-26 22:50 [Phase 7.47.19]: 修复输入框宽度问题
                GroupBox {
                    Layout.fillWidth: true
                    title: "生成范围"
                    background: Rectangle {
                        color: "#252540"
                        border.color: "#4a4a6a"
                        radius: 4
                        y: parent.topPadding - parent.padding
                        height: parent.height - parent.topPadding + parent.padding
                    }
                    label: Text {
                        text: parent.title
                        color: "#aaaacc"
                        font.pixelSize: 14
                    }

                    GridLayout {
                        columns: 2
                        columnSpacing: 15
                        rowSpacing: 8
                        anchors.fill: parent

                        Text { text: "皮带数量:"; color: "#cccccc"; Layout.preferredWidth: 80 }
                        SpinBox {
                            id: spinBeltCount
                            from: 1; to: 8; value: 8
                            editable: true
                            Layout.fillWidth: true
                            Layout.preferredHeight: 35
                        }

                        Text { text: "电机数量:"; color: "#cccccc"; Layout.preferredWidth: 80 }
                        SpinBox {
                            id: spinMotorCount
                            from: 1; to: 4; value: 4
                            editable: true
                            Layout.fillWidth: true
                            Layout.preferredHeight: 35
                        }

                        Text { text: "制动器数量:"; color: "#cccccc"; Layout.preferredWidth: 80 }
                        SpinBox {
                            id: spinBrakeCount
                            from: 1; to: 4; value: 4
                            editable: true
                            Layout.fillWidth: true
                            Layout.preferredHeight: 35
                        }

                        Text { text: "张紧数量:"; color: "#cccccc"; Layout.preferredWidth: 80 }
                        SpinBox {
                            id: spinTensionCount
                            from: 1; to: 2; value: 2
                            editable: true
                            Layout.fillWidth: true
                            Layout.preferredHeight: 35
                        }

                        Text { text: "点位范围:"; color: "#cccccc"; Layout.preferredWidth: 80 }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            SpinBox {
                                id: spinLineStart
                                from: 1; to: 64; value: 1
                                editable: true
                                Layout.fillWidth: true
                                Layout.preferredHeight: 35
                            }
                            Text { text: "-"; color: "#cccccc" }
                            SpinBox {
                                id: spinLineEnd
                                from: 1; to: 64; value: 64
                                editable: true
                                Layout.fillWidth: true
                                Layout.preferredHeight: 35
                            }
                        }
                    }
                }
            }

            // 右侧：预览和进度区
            // ✅ 2026-02-26 22:45 [Phase 7.47.19]: 修复对齐问题，添加顶部对齐
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignTop
                spacing: 10

                // 统计信息
                GroupBox {
                    Layout.fillWidth: true
                    title: "统计信息"
                    background: Rectangle {
                        color: "#252540"
                        border.color: "#4a4a6a"
                        radius: 4
                        y: parent.topPadding - parent.padding
                        height: parent.height - parent.topPadding + parent.padding
                    }
                    label: Text {
                        text: parent.title
                        color: "#aaaacc"
                        font.pixelSize: 14
                    }

                    GridLayout {
                        columns: 2
                        columnSpacing: 20
                        rowSpacing: 5

                        Text { text: "预计文件数:"; color: "#cccccc" }
                        Text {
                            id: txtTotalFiles
                            text: calculateTotalFiles()
                            color: "#00ff88"
                            font.bold: true
                        }

                        Text { text: "已完成:"; color: "#cccccc" }
                        Text {
                            text: batchGenerator ? batchGenerator.completedFiles + " / " + batchGenerator.totalFiles : "0 / 0"
                            color: "#ffffff"
                        }

                        Text { text: "成功:"; color: "#cccccc" }
                        Text {
                            text: batchGenerator ? batchGenerator.successFiles : "0"
                            color: "#00ff88"
                        }

                        Text { text: "失败:"; color: "#cccccc" }
                        Text {
                            text: batchGenerator ? batchGenerator.failedFiles : "0"
                            color: "#ff4444"
                        }

                        Text { text: "跳过:"; color: "#cccccc" }
                        Text {
                            text: batchGenerator ? batchGenerator.skippedFiles : "0"
                            color: "#ffaa00"
                        }
                    }
                }

                // 进度区
                GroupBox {
                    Layout.fillWidth: true
                    title: "进度"
                    background: Rectangle {
                        color: "#252540"
                        border.color: "#4a4a6a"
                        radius: 4
                        y: parent.topPadding - parent.padding
                        height: parent.height - parent.topPadding + parent.padding
                    }
                    label: Text {
                        text: parent.title
                        color: "#aaaacc"
                        font.pixelSize: 14
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 5

                        ProgressBar {
                            Layout.fillWidth: true
                            // ✅ 2026-02-26 23:05 [Phase 7.47.19]: 修复属性名称
                            value: batchGenerator ? batchGenerator.progress / 100 : 0
                            background: Rectangle {
                                color: "#1a1a2e"
                                radius: 3
                            }
                            contentItem: Item {
                                Rectangle {
                                    // ✅ 2026-02-26 23:00 [Phase 7.47.19]: 修复属性名称，与后端匹配
                                    width: parent.width * (batchGenerator ? batchGenerator.progress / 100 : 0)
                                    height: parent.height
                                    radius: 3
                                    color: "#00aa66"
                                }
                            }
                        }

                        // ✅ 2026-02-26 23:00 [Phase 7.47.19]: 修复属性名称，与后端匹配
                        Text {
                            text: batchGenerator ? (batchGenerator.progress.toFixed(1) + "%") : "0%"
                            color: "#ffffff"
                            font.pixelSize: 16
                            Layout.alignment: Qt.AlignHCenter
                        }

                        // ✅ 2026-02-26 23:35 [Phase 7.47.21]: 添加时间统计显示
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "已用时间: " + (batchGenerator ? batchGenerator.elapsedTime : "0:00")
                                color: "#aaaaaa"
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "预计剩余: " + (batchGenerator ? batchGenerator.estimatedTime : "--:--")
                                color: "#aaaaaa"
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "已完成: " + (batchGenerator ? batchGenerator.completedFiles : 0) + " / " + (batchGenerator ? batchGenerator.totalFiles : 0)
                                color: "#aaaaaa"
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "失败: " + (batchGenerator ? batchGenerator.failedFiles : 0)
                                color: batchGenerator && batchGenerator.failedFiles > 0 ? "#ff6666" : "#aaaaaa"
                            }
                        }

                        Text {
                            text: "当前: " + (batchGenerator ? batchGenerator.currentFile : "")
                            color: "#88aaff"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

                // 日志区
                GroupBox {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: "日志"
                    background: Rectangle {
                        color: "#252540"
                        border.color: "#4a4a6a"
                        radius: 4
                        y: parent.topPadding - parent.padding
                        height: parent.height - parent.topPadding + parent.padding
                    }
                    label: Text {
                        text: parent.title
                        color: "#aaaacc"
                        font.pixelSize: 14
                    }

                    ScrollView {
                        anchors.fill: parent
                        TextArea {
                            id: logArea
                            readOnly: true
                            color: "#cccccc"
                            font.family: "Consolas"
                            font.pixelSize: 12
                            background: Rectangle {
                                color: "transparent"
                            }
                        }
                    }
                }

                // 选项
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 20

                    CheckBox {
                        id: chkSkipExisting
                        text: "跳过已存在的文件"
                        checked: true
                        contentItem: Text {
                            text: parent.text
                            color: "#ffffff"
                            leftPadding: parent.indicator.width + 5
                        }
                    }
                    CheckBox {
                        id: chkGenerateReport
                        text: "生成报告"
                        checked: true
                        contentItem: Text {
                            text: parent.text
                            color: "#ffffff"
                            leftPadding: parent.indicator.width + 5
                        }
                    }
                }
            }
        }

        // 底部按钮
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            spacing: 15

            Button {
                text: "预览清单"
                Layout.preferredWidth: 100
                Layout.preferredHeight: 36
                onClicked: previewFileList()
                background: Rectangle {
                    color: parent.hovered ? "#4a4a8a" : "#3a3a6a"
                    radius: 4
                }
                contentItem: Text {
                    text: parent.text
                    color: "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // ✅ 2026-02-27 00:35 [Phase 7.47.23]: 添加生成所有ID语音按钮
            Button {
                text: "生成所有ID语音"
                Layout.preferredWidth: 130
                Layout.preferredHeight: 36
                enabled: batchGenerator && !batchGenerator.isRunning
                onClicked: {
                    if (batchGenerator) {
                        appendLog("info", "开始生成所有说话人测试语音（174个）...")
                        batchGenerator.generateAllSpeakerSamples()
                    }
                }
                background: Rectangle {
                    color: parent.enabled ? (parent.hovered ? "#ff8800" : "#cc6600") : "#666666"
                    radius: 4
                }
                contentItem: Text {
                    text: parent.text
                    color: "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Item { Layout.fillWidth: true }

            Button {
                id: btnStart
                // ✅ 2026-02-26 23:00 [Phase 7.47.19]: 修复按钮逻辑，与后端匹配
                text: batchGenerator && batchGenerator.isRunning ? "停止" : "开始生成"
                Layout.preferredWidth: 100
                Layout.preferredHeight: 36
                onClicked: {
                    if (batchGenerator && batchGenerator.isRunning) {
                        batchGenerator.stop()
                    } else {
                        startGeneration()
                    }
                }
                background: Rectangle {
                    color: parent.hovered ? "#00aa66" : "#008855"
                    radius: 4
                }
                contentItem: Text {
                    text: parent.text
                    color: "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Button {
                text: "停止"
                Layout.preferredWidth: 80
                Layout.preferredHeight: 36
                enabled: batchGenerator && batchGenerator.isRunning
                onClicked: batchGenerator.stop()
                background: Rectangle {
                    color: parent.hovered ? "#aa4444" : "#884444"
                    radius: 4
                }
                contentItem: Text {
                    text: parent.text
                    color: "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Button {
                text: "关闭"
                Layout.preferredWidth: 80
                Layout.preferredHeight: 36
                onClicked: root.closeRequested()
                background: Rectangle {
                    color: parent.hovered ? "#4a4a6a" : "#3a3a5a"
                    radius: 4
                }
                contentItem: Text {
                    text: parent.text
                    color: "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    // 计算预计文件数
    // ✅ 2026-02-26 23:25 [Phase 7.47.20]: 更新文件数量计算，与后端一致
    function calculateTotalFiles() {
        var total = 0
        var beltCount = spinBeltCount.value
        var motorCount = spinMotorCount.value
        var brakeCount = spinBrakeCount.value
        var tensionCount = spinTensionCount.value
        var lineCount = spinLineEnd.value - spinLineStart.value + 1

        // 按设计方案的文件数量
        if (chkSwitchInput.checked) total += 8 * beltCount           // 开关量：8个/皮带
        if (chkAnalogInput.checked) total += 8 * beltCount           // 模拟量：8个/皮带
        if (chkMotor.checked) total += 9 * beltCount * motorCount    // 电机：9个/皮带/电机（与MotorControlPage Tab对应）
        if (chkBrake.checked) total += 3 * beltCount * brakeCount    // 制动器：3个/皮带/制动器
        if (chkTension.checked) total += 3 * beltCount * tensionCount // 张紧：3个/皮带/张紧
        if (chkLinePosition.checked) total += 3 * lineCount * beltCount // 沿线：3个/皮带/点位
        if (chkSystemSound.checked) total += 16                       // 系统提示音：16个
        // ✅ 2026-02-27 05:30 [Phase 7.47.30]: 补充1#PD已有但批量代码缺失的语音分类
        if (chkBeltOperation.checked) total += (5 + motorCount + brakeCount + tensionCount) * beltCount  // 皮带操作：(5+电机+制动器+张紧)/皮带
        if (chkSystemStatus.checked) total += 7 * beltCount            // 系统/通讯状态：7个/皮带

        return total.toString()
    }

    // 预览文件清单
    function previewFileList() {
        appendLog("info", "生成文件清单预览...")
        var config = buildConfig()
        if (batchGenerator) {
            batchGenerator.setConfig(config)
            var count = batchGenerator.generateFileList()
            appendLog("info", "预计生成 " + count + " 个文件")
        }
    }

    // 开始生成
    function startGeneration() {
        appendLog("info", "开始批量生成...")
        var config = buildConfig()
        if (batchGenerator) {
            batchGenerator.setConfig(config)
            batchGenerator.start()
        }
    }

    // 构建配置
    function buildConfig() {
        var categories = []
        if (chkSwitchInput.checked) categories.push("switchInput")
        if (chkAnalogInput.checked) categories.push("analogInput")
        if (chkMotor.checked) categories.push("motor")
        if (chkBrake.checked) categories.push("brake")
        if (chkTension.checked) categories.push("tension")
        if (chkLinePosition.checked) categories.push("linePosition")
        if (chkSystemSound.checked) categories.push("systemSound")
        // ✅ 2026-02-27 05:30 [Phase 7.47.30]: 补充1#PD已有但批量代码缺失的语音分类
        if (chkBeltOperation.checked) categories.push("beltOperation")
        if (chkSystemStatus.checked) categories.push("systemStatus")

        var beltNumbers = []
        for (var i = 1; i <= spinBeltCount.value; i++) beltNumbers.push(i)

        var motorNumbers = []
        for (var i = 1; i <= spinMotorCount.value; i++) motorNumbers.push(i)

        var brakeNumbers = []
        for (var i = 1; i <= spinBrakeCount.value; i++) brakeNumbers.push(i)

        var tensionNumbers = []
        for (var i = 1; i <= spinTensionCount.value; i++) tensionNumbers.push(i)

        return {
            categories: categories,
            beltNumbers: beltNumbers,
            motorNumbers: motorNumbers,
            brakeNumbers: brakeNumbers,
            tensionNumbers: tensionNumbers,
            linePositionStart: spinLineStart.value,
            linePositionEnd: spinLineEnd.value,
            skipExisting: chkSkipExisting.checked,
            generateReport: chkGenerateReport.checked,
            // ✅ 2026-02-26 23:20 [Phase 7.47.20]: 使用容器内路径
            // ✅ 2026-02-27 01:20 [Phase 7.47.26]: 修改为小写audio，与设备实际目录一致
            // ✅ 2026-02-27 01:30 [Phase 7.47.27]: 支持linaro和pi用户，使用环境变量
            // 参考：docs/2026-02-26/08-音频文件路径映射设计方案.md
            outputBaseDir: getOutputBaseDir(),
            engines: [{
                // ✅ 2026-02-27 00:10 [Phase 7.47.22]: 修复引擎名称大小写
                // 原因：后端注册的是 "PaddleSpeech"（大写P），QML 必须匹配
                engineName: "PaddleSpeech",
                // ✅ 2026-02-27 10:00 [Phase 7.47.34]: 使用语音管理界面选择的模型，不再硬编码
                // modelName: "fastspeech2-aishell3",  // 2026-02-27 10:00 注释：原硬编码值
                modelName: TTSConfig.modelName(TTSConfig.modelIndex(TTSConfig.Test)),
                // ✅ 2026-02-27 06:00 [Phase 7.47.31]: 使用语音管理界面保存的参数，不再硬编码
                // speakerId: 21,  // 2026-02-27 06:00 注释：原硬编码值
                speakerId: TTSConfig.speakerId(TTSConfig.Test),
                rate: TTSConfig.rate(TTSConfig.Test),
                volume: TTSConfig.volume(TTSConfig.Test),
                // ✅ 2026-02-27 10:00 [Phase 7.47.34]: 输出文件夹名称使用实际选择的模型
                // outputFolder: "paddlespeech-fastspeech2-aishell3-spk" + TTSConfig.speakerId(TTSConfig.Test)  // 2026-02-27 10:00 注释：原硬编码值
                outputFolder: "paddlespeech-" + TTSConfig.modelName(TTSConfig.modelIndex(TTSConfig.Test)) + "-spk" + TTSConfig.speakerId(TTSConfig.Test)
            }]
        }
    }

    // 添加日志
    // ✅ 2026-02-27 01:05 [Phase 7.47.24]: 添加自动滚动到底部
    function appendLog(level, message) {
        var timestamp = new Date().toLocaleTimeString()
        var prefix = level === "error" ? "[错误]" : level === "warn" ? "[警告]" : "[信息]"
        logArea.text += timestamp + " " + prefix + " " + message + "\n"
        // 自动滚动到底部
        logArea.cursorPosition = logArea.text.length
    }

    // ✅ 2026-02-27 02:15 [Phase 7.47.28]: 保存批量合成参数到持久化存储
    function saveBatchConfig() {
        TTSConfig.setValue("batch/chkSwitchInput", chkSwitchInput.checked)
        TTSConfig.setValue("batch/chkAnalogInput", chkAnalogInput.checked)
        TTSConfig.setValue("batch/chkMotor", chkMotor.checked)
        TTSConfig.setValue("batch/chkBrake", chkBrake.checked)
        TTSConfig.setValue("batch/chkTension", chkTension.checked)
        TTSConfig.setValue("batch/chkLinePosition", chkLinePosition.checked)
        TTSConfig.setValue("batch/chkSystemSound", chkSystemSound.checked)
        // ✅ 2026-02-27 05:30 [Phase 7.47.30]: 补充新分类持久化
        TTSConfig.setValue("batch/chkBeltOperation", chkBeltOperation.checked)
        TTSConfig.setValue("batch/chkSystemStatus", chkSystemStatus.checked)
        TTSConfig.setValue("batch/beltCount", spinBeltCount.value)
        TTSConfig.setValue("batch/motorCount", spinMotorCount.value)
        TTSConfig.setValue("batch/brakeCount", spinBrakeCount.value)
        TTSConfig.setValue("batch/tensionCount", spinTensionCount.value)
        TTSConfig.setValue("batch/lineStart", spinLineStart.value)
        TTSConfig.setValue("batch/lineEnd", spinLineEnd.value)
        TTSConfig.setValue("batch/skipExisting", chkSkipExisting.checked)
        TTSConfig.setValue("batch/generateReport", chkGenerateReport.checked)
    }

    // ✅ 2026-02-27 02:15 [Phase 7.47.28]: 从持久化存储恢复批量合成参数
    function loadBatchConfig() {
        chkSwitchInput.checked = TTSConfig.getValue("batch/chkSwitchInput", true)
        chkAnalogInput.checked = TTSConfig.getValue("batch/chkAnalogInput", true)
        chkMotor.checked = TTSConfig.getValue("batch/chkMotor", true)
        chkBrake.checked = TTSConfig.getValue("batch/chkBrake", true)
        chkTension.checked = TTSConfig.getValue("batch/chkTension", true)
        chkLinePosition.checked = TTSConfig.getValue("batch/chkLinePosition", true)
        chkSystemSound.checked = TTSConfig.getValue("batch/chkSystemSound", true)
        // ✅ 2026-02-27 05:30 [Phase 7.47.30]: 补充新分类恢复
        chkBeltOperation.checked = TTSConfig.getValue("batch/chkBeltOperation", true)
        chkSystemStatus.checked = TTSConfig.getValue("batch/chkSystemStatus", true)
        spinBeltCount.value = TTSConfig.getValue("batch/beltCount", 8)
        spinMotorCount.value = TTSConfig.getValue("batch/motorCount", 4)
        spinBrakeCount.value = TTSConfig.getValue("batch/brakeCount", 4)
        spinTensionCount.value = TTSConfig.getValue("batch/tensionCount", 2)
        spinLineStart.value = TTSConfig.getValue("batch/lineStart", 1)
        spinLineEnd.value = TTSConfig.getValue("batch/lineEnd", 64)
        chkSkipExisting.checked = TTSConfig.getValue("batch/skipExisting", true)
        chkGenerateReport.checked = TTSConfig.getValue("batch/generateReport", true)
        console.log("📂 已恢复批量合成参数")
    }

    // ✅ 2026-02-27 02:15 [Phase 7.47.28]: 组件加载时恢复参数
    Component.onCompleted: {
        loadBatchConfig()
    }

    // ✅ 2026-02-27 02:20 [Phase 7.47.28]: 监听参数变化，自动保存
    Connections {
        target: chkSwitchInput
        function onCheckedChanged() { saveBatchConfig() }
    }
    Connections {
        target: chkAnalogInput
        function onCheckedChanged() { saveBatchConfig() }
    }
    Connections {
        target: chkMotor
        function onCheckedChanged() { saveBatchConfig() }
    }
    Connections {
        target: chkBrake
        function onCheckedChanged() { saveBatchConfig() }
    }
    Connections {
        target: chkTension
        function onCheckedChanged() { saveBatchConfig() }
    }
    Connections {
        target: chkLinePosition
        function onCheckedChanged() { saveBatchConfig() }
    }
    Connections {
        target: chkSystemSound
        function onCheckedChanged() { saveBatchConfig() }
    }
    // ✅ 2026-02-27 05:30 [Phase 7.47.30]: 补充新分类监听
    Connections {
        target: chkBeltOperation
        function onCheckedChanged() { saveBatchConfig() }
    }
    Connections {
        target: chkSystemStatus
        function onCheckedChanged() { saveBatchConfig() }
    }
    Connections {
        target: spinBeltCount
        function onValueChanged() { saveBatchConfig() }
    }
    Connections {
        target: spinMotorCount
        function onValueChanged() { saveBatchConfig() }
    }
    Connections {
        target: spinBrakeCount
        function onValueChanged() { saveBatchConfig() }
    }
    Connections {
        target: spinTensionCount
        function onValueChanged() { saveBatchConfig() }
    }
    Connections {
        target: spinLineStart
        function onValueChanged() { saveBatchConfig() }
    }
    Connections {
        target: spinLineEnd
        function onValueChanged() { saveBatchConfig() }
    }
    Connections {
        target: chkSkipExisting
        function onCheckedChanged() { saveBatchConfig() }
    }
    Connections {
        target: chkGenerateReport
        function onCheckedChanged() { saveBatchConfig() }
    }

    // 连接信号
    Connections {
        target: batchGenerator
        function onLogMessage(level, message) {
            appendLog(level, message)
        }
        function onFinished(success, message) {
            appendLog(success ? "info" : "error", message)
        }
    }
}
