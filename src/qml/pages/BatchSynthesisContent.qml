// 2026-02-25 14:05 [Phase 7.47.2]: 批量合成内容组件
// 用途：批量语音合成的内容区域，可在 QDS 中可视化设计
// 使用方式：由 BatchSynthesisDialog.qml (Popup) 包装使用
// ✅ 2026-02-26 21:15 [Phase 7.47.18]: 添加 showHeader 属性，支持嵌入模式

import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

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
            ColumnLayout {
                Layout.preferredWidth: 350
                Layout.fillHeight: true
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
                    }
                }

                // 范围设置 - 4列布局
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
                        columns: 4
                        columnSpacing: 10
                        rowSpacing: 6

                        Text { text: "皮带:"; color: "#cccccc" }
                        SpinBox {
                            id: spinBeltCount
                            from: 1; to: 8; value: 8
                            editable: true
                            Layout.preferredWidth: 80
                        }
                        Text { text: "电机:"; color: "#cccccc" }
                        SpinBox {
                            id: spinMotorCount
                            from: 1; to: 4; value: 4
                            editable: true
                            Layout.preferredWidth: 80
                        }

                        Text { text: "制动器:"; color: "#cccccc" }
                        SpinBox {
                            id: spinBrakeCount
                            from: 1; to: 4; value: 4
                            editable: true
                            Layout.preferredWidth: 80
                        }
                        Text { text: "张紧:"; color: "#cccccc" }
                        SpinBox {
                            id: spinTensionCount
                            from: 1; to: 2; value: 2
                            editable: true
                            Layout.preferredWidth: 80
                        }

                        Text { text: "点位:"; color: "#cccccc" }
                        RowLayout {
                            Layout.columnSpan: 3
                            spacing: 5
                            SpinBox {
                                id: spinLineStart
                                from: 1; to: 64; value: 1
                                editable: true
                                Layout.preferredWidth: 80
                            }
                            Text { text: "-"; color: "#cccccc" }
                            SpinBox {
                                id: spinLineEnd
                                from: 1; to: 64; value: 64
                                editable: true
                                Layout.preferredWidth: 80
                            }
                        }
                    }
                }
            }

            // 右侧：预览和进度区
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
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
                            value: batchGenerator ? batchGenerator.progressPercent / 100 : 0
                            background: Rectangle {
                                color: "#1a1a2e"
                                radius: 3
                            }
                            contentItem: Item {
                                Rectangle {
                                    width: parent.width * (batchGenerator ? batchGenerator.progressPercent / 100 : 0)
                                    height: parent.height
                                    radius: 3
                                    color: "#00aa66"
                                }
                            }
                        }

                        Text {
                            text: batchGenerator ? (batchGenerator.progressPercent.toFixed(1) + "%") : "0%"
                            color: "#ffffff"
                            font.pixelSize: 16
                            Layout.alignment: Qt.AlignHCenter
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "已用时间: " + (batchGenerator ? batchGenerator.elapsedTime : "0:00")
                                color: "#aaaaaa"
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "预计剩余: " + (batchGenerator ? batchGenerator.estimatedTime : "0:00")
                                color: "#aaaaaa"
                            }
                        }

                        Text {
                            text: "当前: " + (batchGenerator ? batchGenerator.currentText : "")
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

            Item { Layout.fillWidth: true }

            Button {
                id: btnStart
                text: batchGenerator && batchGenerator.isRunning ? "暂停" : "开始生成"
                Layout.preferredWidth: 100
                Layout.preferredHeight: 36
                enabled: !batchGenerator || !batchGenerator.isPaused
                onClicked: {
                    if (batchGenerator && batchGenerator.isRunning) {
                        batchGenerator.pause()
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
    function calculateTotalFiles() {
        var total = 0
        var beltCount = spinBeltCount.value
        var motorCount = spinMotorCount.value
        var brakeCount = spinBrakeCount.value
        var tensionCount = spinTensionCount.value
        var lineCount = spinLineEnd.value - spinLineStart.value + 1

        if (chkSwitchInput.checked) total += 33 * beltCount
        if (chkAnalogInput.checked) total += 16 * beltCount
        if (chkMotor.checked) total += 12 * beltCount * motorCount
        if (chkBrake.checked) total += 8 * beltCount * brakeCount
        if (chkTension.checked) total += 10 * beltCount * tensionCount
        if (chkLinePosition.checked) total += lineCount * beltCount
        if (chkSystemSound.checked) total += 20

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
            outputBaseDir: "E:/AUDIO/",
            engines: [{
                engineName: "paddlespeech",
                modelName: "fastspeech2-aishell3",
                speakerId: 174,
                outputFolder: "paddlespeech-fastspeech2-aishell3-spk174"
            }]
        }
    }

    // 添加日志
    function appendLog(level, message) {
        var timestamp = new Date().toLocaleTimeString()
        var prefix = level === "error" ? "[错误]" : level === "warn" ? "[警告]" : "[信息]"
        logArea.text += timestamp + " " + prefix + " " + message + "\n"
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
