import QtQuick

// ✅ 2026-01-27 [FIX 100.300.54]: 添加选中状态支持
// ✅ 2026-02-02 [FIX 100.300.112.8.19.3]: 重新设计组件布局
// ✅ 2026-03-26 [Phase 7.48.88.25]: 重新设计卡片 - 显示实时数据+序列阶段+保护状态
// ✅ 2026-03-26 [Phase 7.48.88.26]: 修复5个UI问题
// ✅ 2026-03-28 [Phase 7.48.88.49]: 卡片布局重设计 - 水平排列优先
//   - 参数区: 2行×2列，每个参数名+进度条+数值同行
//   - 顶部状态栏: 合并在线/离线、今日运行时间
//   - 设备LED: 放大，LED+文字同行水平排列
//   - 保护指示: 移到底部，LED+文字同行
//   设计原则: 高度受限宽度充裕，全面水平化布局
Image {
    id: iN_Data
    source: "images/IN_Data.png"
    fillMode: Image.PreserveAspectFit

    // ========== 公开属性 ==========
    property bool selected: false

    // 设备信息属性
    property string deviceName: "设备 01"
    property int deviceIndex: 0  // 0-11
    property bool isLocalDevice: false

    // ✅ 运行状态（三态: "停止"/"运行"/"故障"）
    property string deviceStatus: "停止"
    property bool commOnline: false

    // ✅ 2026-03-27 [Phase 7.48.88.34]: 工作模式与连锁状态
    property int workMode: 1              // 0=检修, 1=就地, 2=点动, 3=集控
    property bool interlockActive: true   // 连锁状态（检修=false, 其他=true）

    // ✅ 2026-03-27 [Phase 7.48.88.38]: 允许运行与故障详情
    property bool allowRun: true          // 允许运行（所有保护正常且无故障）
    property string faultDetail: ""       // 故障详情（如"张紧控制运行失败"，空字符串=无故障）

    // ✅ 序列执行阶段（核心显示区域）
    property string sequencePhase: ""          // 当前阶段: "起车预警"/"1号制动器"/"1号电机"/"运行"/"停车预警"/"停止"
    property int sequenceCurrent: 0            // 当前步骤
    property int sequenceTotal: 0              // 总步骤数
    property int sequenceDelayMs: 0            // 倒计时毫秒
    property real countdownSeconds: 0          // 倒计时秒数（Timer驱动递减）

    // ✅ 核心参数（实时数据）
    property string param1Name: "速度"
    property string param1Value: "--"
    property string param1Unit: "m/s"
    property real param1Percent: 0
    property string param2Name: "电流"
    property string param2Value: "--"
    property string param2Unit: "A"
    property real param2Percent: 0
    property string param3Name: "温度"
    property string param3Value: "--"
    property string param3Unit: "℃"
    property real param3Percent: 0
    property string param4Name: "张力"
    property string param4Value: "--"
    property string param4Unit: "kN"
    property real param4Percent: 0

    // ✅ 保护状态（DI开关量位图）
    property int protectionBits: 0x00  // 8位: bit0=急停 bit1=跑偏 bit2=撕裂 bit3=烟雾 bit4=温度 bit5=护网 bit6=堆煤
    // ✅ 2026-03-26 [Phase 7.48.88.27]: 保护锁存位图（三态指示）
    property int latchedProtectionBits: 0x00

    // ✅ 运行时间
    property string dailyRuntime: "--"

    // ✅ 2026-03-28 [Phase 7.48.88.48]: 输出设备运行状态LED
    property var outputDevices: []        // 设备名列表，从启动序列+洒水同步
    property var outputDeviceStates: ({}) // 设备名→是否运行 映射

    // 内部：倒计时定时器
    Timer {
        id: countdownTimer
        interval: 100  // 100ms更新
        repeat: true
        running: iN_Data.countdownSeconds > 0
        onTriggered: {
            iN_Data.countdownSeconds = Math.max(0, iN_Data.countdownSeconds - 0.1)
        }
    }

    // 新的倒计时启动时，重置秒数
    onSequenceDelayMsChanged: {
        if (sequenceDelayMs > 0) {
            countdownSeconds = sequenceDelayMs / 1000.0
        }
    }

    // ========== 工具函数 ==========
    function statusColor() {
        if (deviceStatus === "故障") return "#DC2626"
        if (deviceStatus === "运行") return "#22C55E"
        if (deviceStatus === "启动中" || deviceStatus === "停止中") return "#F59E0B"
        if (deviceStatus === "起车预警" || deviceStatus === "停车预警") return "#F59E0B"
        if (isLocalDevice) return "#38BDF8"
        return "#6B7280"  // 停止
    }

    function phaseColor() {
        if (sequencePhase === "运行") return "#22C55E"
        if (sequencePhase === "停止" || sequencePhase === "") return "#6B7280"
        if (sequencePhase === "起车预警" || sequencePhase === "停车预警") return "#F59E0B"
        return "#3B82F6"  // 序列执行中（亮蓝色）
    }

    function accentColor() {
        return isLocalDevice ? "#7DD3FC" : "#F8FAFC"
    }

    function normalizedPercent(percentValue) {
        return Math.max(0, Math.min(1, percentValue || 0))
    }

    function valueColor(valueText, percentValue) {
        if (valueText === "--") return isLocalDevice ? "#7DD3FC99" : "#475569"
        var percent = normalizedPercent(percentValue)
        if (percent >= 0.9) return "#DC2626"
        if (percent >= 0.7) return "#F59E0B"
        return accentColor()
    }

    function progressColor(percentValue) {
        var percent = normalizedPercent(percentValue)
        if (percent >= 0.9) return "#DC2626"
        if (percent >= 0.7) return "#F59E0B"
        return isLocalDevice ? "#38BDF8" : "#22C55E"
    }

    function progressGlowColor(percentValue) {
        var percent = normalizedPercent(percentValue)
        if (percent >= 0.9) return "#F87171"
        if (percent >= 0.7) return "#FCD34D"
        return isLocalDevice ? "#7DD3FC" : "#4ADE80"
    }

    function progressTrackColor() {
        return isLocalDevice ? "#10273A" : "#1E293B"
    }

    function shortDeviceName(name) {
        if (name === "张紧控制") return "张紧"
        var m = name.match(/(\d+)号制动器/)
        if (m) return "闸" + m[1]
        m = name.match(/(\d+)号电机/)
        if (m) return "机" + m[1]
        m = name.match(/洒水(\d+)/)
        if (m) return "水" + m[1]
        return name.substring(0, 2)
    }

    // ========== 故障时红色半透明遮罩 ==========
    Rectangle {
        anchors.fill: parent
        color: "#DC2626"
        opacity: deviceStatus === "故障" ? 0.15 : 0
        z: 1

        SequentialAnimation on opacity {
            loops: Animation.Infinite
            running: deviceStatus === "故障"
            NumberAnimation { to: 0.25; duration: 400 }
            NumberAnimation { to: 0.08; duration: 400 }
        }
    }

    // ========== ① 标题栏 - 背景图header band中央 ==========
    Item {
        id: titleBar
        x: 0
        y: 5
        width: parent.width
        height: 45
        z: 3

        Text {
            id: deviceNameText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            text: iN_Data.deviceName
            font.pixelSize: 24
            font.bold: true
            font.family: "Microsoft YaHei"
            color: accentColor()
            style: Text.Outline
            styleColor: "#00000080"
        }
    }

    // ========== ② 顶部状态栏 - 合并所有状态信息到一行 ==========
    // ✅ 2026-03-28 [Phase 7.48.88.49]: 合并在线/离线、今日运行时间到顶部
    Row {
        id: statusRow
        x: 12
        y: 55
        width: parent.width - 24
        z: 3
        spacing: 6

        // --- 状态指示灯 + 文字 ---
        Row {
            spacing: 3
            anchors.verticalCenter: parent.verticalCenter

            Item {
                width: 14
                height: 14
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    radius: 10
                    color: statusColor()
                    opacity: 0.3
                    visible: deviceStatus === "运行" || deviceStatus === "故障"
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 12
                    height: 12
                    radius: 6
                    color: statusColor()

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: deviceStatus === "运行"
                        NumberAnimation { to: 0.4; duration: 1000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
                    }
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: deviceStatus === "故障"
                        NumberAnimation { to: 0; duration: 250 }
                        NumberAnimation { to: 1; duration: 250 }
                    }
                }
            }

            Text {
                text: iN_Data.deviceStatus
                font.pixelSize: 16
                font.bold: true
                color: statusColor()
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // --- 模式徽章 ---
        Rectangle {
            width: modeText.implicitWidth + 10
            height: 18
            radius: 3
            color: workMode === 0 ? "#33F59E0B" : "#3322C55E"
            border.color: workMode === 0 ? "#F59E0B" : "#22C55E"
            border.width: 1
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: modeText
                anchors.centerIn: parent
                text: workMode === 0 ? "检修" : "就地"
                font.pixelSize: 11
                font.family: "Microsoft YaHei"
                color: workMode === 0 ? "#F59E0B" : "#22C55E"
            }
        }

        // --- 连锁徽章 ---
        Rectangle {
            width: lockText.implicitWidth + 10
            height: 18
            radius: 3
            color: interlockActive ? "#333B82F6" : "#33EF4444"
            border.color: interlockActive ? "#3B82F6" : "#EF4444"
            border.width: 1
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: lockText
                anchors.centerIn: parent
                text: interlockActive ? "连锁" : "解锁"
                font.pixelSize: 11
                font.family: "Microsoft YaHei"
                color: interlockActive ? "#3B82F6" : "#EF4444"
            }
        }

        // --- 允许运行徽章 ---
        Rectangle {
            width: allowRunText.implicitWidth + 10
            height: 18
            radius: 3
            color: allowRun ? "#3322C55E" : "#33DC2626"
            border.color: allowRun ? "#22C55E" : "#DC2626"
            border.width: 1
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: allowRunText
                anchors.centerIn: parent
                text: allowRun ? "允许" : "禁止"
                font.pixelSize: 11
                font.family: "Microsoft YaHei"
                color: allowRun ? "#22C55E" : "#DC2626"
            }
        }

        // --- 通讯在线/离线 ---
        Row {
            spacing: 3
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                width: 8
                height: 8
                radius: 4
                color: commOnline ? "#22C55E" : "#DC2626"
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: commOnline ? "在线" : "离线"
                font.pixelSize: 11
                font.bold: true
                color: commOnline ? "#22C55E" : "#DC2626"
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // --- 分隔竖线 ---
        Rectangle {
            width: 1
            height: 12
            color: "#334155"
            anchors.verticalCenter: parent.verticalCenter
        }

        // --- 今日运行时间 ---
        Row {
            spacing: 3
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: "今日"
                font.pixelSize: 11
                color: "#64748B"
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: dailyRuntime
                font.pixelSize: 12
                font.bold: true
                color: "#94A3B8"
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // --- 故障详情徽章（仅故障时显示） ---
        Rectangle {
            width: Math.min(faultDetailText.implicitWidth + 12, 140)
            height: 18
            radius: 3
            color: "#33DC2626"
            border.color: "#DC2626"
            border.width: 1
            anchors.verticalCenter: parent.verticalCenter
            visible: faultDetail !== ""

            Text {
                id: faultDetailText
                anchors.centerIn: parent
                width: parent.width - 8
                text: faultDetail
                font.pixelSize: 11
                font.bold: true
                font.family: "Microsoft YaHei"
                color: "#DC2626"
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: faultDetail !== ""
                NumberAnimation { to: 0.5; duration: 600 }
                NumberAnimation { to: 1.0; duration: 600 }
            }
        }
    }

    // ========== 主内容区域 ==========
    // ✅ 2026-03-28 [Phase 7.48.88.49]: 锚点布局，保护固定底部，参数填充剩余空间
    Item {
        id: contentArea
        x: 14
        y: 78
        width: parent.width - 28
        height: parent.height - 78 - 22
        z: 2

        // ========== ⑤ 保护状态栏 - 固定在底部 ==========
        Item {
            id: protectionRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 32

            Rectangle {
                anchors.fill: parent
                color: "#0D1B2A"
                opacity: 0.35
                radius: 4
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 4
                spacing: 0

                Repeater {
                    model: [
                        { name: "急停", bit: 0 },
                        { name: "跑偏", bit: 1 },
                        { name: "撕裂", bit: 2 },
                        { name: "烟雾", bit: 3 },
                        { name: "温度", bit: 4 },
                        { name: "堆煤", bit: 6 }
                    ]

                    Item {
                        width: (parent.width - 8) / 6
                        height: parent.height

                        property bool triggered: (protectionBits & (1 << modelData.bit)) !== 0
                        property bool latched: !triggered && ((latchedProtectionBits & (1 << modelData.bit)) !== 0)
                        property color indicatorColor: triggered ? (modelData.bit <= 2 ? "#DC2626" : "#F59E0B")
                                                     : latched ? "#FF8C00"
                                                     : "#22C55E"

                        Row {
                            anchors.centerIn: parent
                            spacing: 3

                            Item {
                                width: 16
                                height: 16
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 22
                                    height: 22
                                    radius: 11
                                    color: indicatorColor
                                    opacity: 0.3
                                    visible: triggered || latched
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    radius: 8
                                    color: indicatorColor

                                    SequentialAnimation on scale {
                                        loops: Animation.Infinite
                                        running: triggered
                                        NumberAnimation { to: 1.3; duration: 500 }
                                        NumberAnimation { to: 1.0; duration: 500 }
                                    }

                                    SequentialAnimation on opacity {
                                        loops: Animation.Infinite
                                        running: latched && !triggered
                                        NumberAnimation { to: 0.4; duration: 800 }
                                        NumberAnimation { to: 1.0; duration: 800 }
                                    }
                                }
                            }

                            Text {
                                text: modelData.name
                                font.pixelSize: 14
                                font.bold: triggered || latched
                                color: indicatorColor
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }
        }

        // ========== ④ 输出设备LED - 保护栏上方 ==========
        Item {
            id: deviceRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: protectionRow.top
            anchors.bottomMargin: 3
            // ✅ 2026-03-28 [Phase 7.48.88.49.2]: 增大设备LED行高度
            height: outputDevices.length > 0 ? 40 : 0
            visible: outputDevices.length > 0

            Rectangle {
                anchors.fill: parent
                color: "#0D1B2A"
                opacity: 0.25
                radius: 3
            }

            Row {
                anchors.centerIn: parent
                spacing: 8

                Repeater {
                    model: outputDevices

                    Row {
                        spacing: 4

                        property bool isOn: {
                            var states = outputDeviceStates
                            return states && states[modelData] === true
                        }

                        // ✅ 2026-03-28 [Phase 7.48.88.49.2]: 放大设备方形LED 16→22px，字体14→18px
                        Item {
                            width: 22
                            height: 22
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                anchors.centerIn: parent
                                width: 30
                                height: 30
                                radius: 5
                                color: "#22C55E"
                                opacity: 0.25
                                visible: isOn
                                z: -1
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: 22
                                height: 22
                                radius: 4
                                color: isOn ? "#22C55E" : "#4B5563"
                            }
                        }

                        Text {
                            text: shortDeviceName(modelData)
                            font.pixelSize: 18
                            font.bold: isOn
                            color: isOn ? "#22C55E" : "#64748B"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }

        // ========== 分隔线（设备与保护之间） ==========
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: deviceRow.visible ? deviceRow.top : protectionRow.top
            anchors.bottomMargin: 1
            height: 1
            color: "#4A90E2"
            opacity: 0.4
        }

        // ========== ③ 参数区 - 填充上方剩余空间 ==========
        Item {
            id: paramArea
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: deviceRow.visible ? deviceRow.top : protectionRow.top
            anchors.bottomMargin: 6

            // 暗色半透明背���
            Rectangle {
                anchors.fill: parent
                color: "#0D1B2A"
                opacity: 0.45
                radius: 4
            }

            // ---- 模式A: 参数显示（2行×2列水平） ----
            Column {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 6
                visible: sequencePhase === "" || sequencePhase === "运行" || sequencePhase === "停止"

                // 第1行: 速度 + 电流
                Row {
                    width: parent.width
                    height: (parent.height - 6) / 2
                    spacing: 10

                    // 参数1: 速度
                    // ✅ 2026-03-28 [Phase 7.48.88.49.2]: 数值移到右上角，名称+进度条在底部
                    Item {
                        width: (parent.width - 10) / 2
                        height: parent.height

                        Row {
                            id: p1ValRow
                            anchors.right: parent.right
                            anchors.rightMargin: 2
                            anchors.top: parent.top
                            anchors.topMargin: 2
                            spacing: 2

                            Text {
                                text: iN_Data.param1Value
                                font.pixelSize: 22
                                font.bold: true
                                color: valueColor(iN_Data.param1Value, iN_Data.param1Percent)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: iN_Data.param1Unit
                                font.pixelSize: 11
                                color: "#64748B"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Text {
                            id: p1Name
                            anchors.left: parent.left
                            anchors.leftMargin: 2
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            text: iN_Data.param1Name
                            font.pixelSize: 14
                            color: "#64748B"
                        }

                        Item {
                            anchors.left: p1Name.right
                            anchors.leftMargin: 6
                            anchors.right: parent.right
                            anchors.rightMargin: 2
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            height: 10

                            Rectangle {
                                anchors.fill: parent
                                radius: 4
                                color: progressTrackColor()
                            }

                            Rectangle {
                                width: parent.width * normalizedPercent(iN_Data.param1Percent)
                                height: parent.height
                                radius: 4
                                color: progressColor(iN_Data.param1Percent)
                                visible: iN_Data.param1Value !== "--"

                                Rectangle {
                                    width: parent.width
                                    height: 2
                                    radius: 1
                                    color: "#FFFFFF"
                                    opacity: 0.15
                                }

                                Behavior on width {
                                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                                }
                            }
                        }
                    }

                    // 参数2: 电流
                    Item {
                        width: (parent.width - 10) / 2
                        height: parent.height

                        Row {
                            id: p2ValRow
                            anchors.right: parent.right
                            anchors.rightMargin: 2
                            anchors.top: parent.top
                            anchors.topMargin: 2
                            spacing: 2

                            Text {
                                text: iN_Data.param2Value
                                font.pixelSize: 22
                                font.bold: true
                                color: valueColor(iN_Data.param2Value, iN_Data.param2Percent)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: iN_Data.param2Unit
                                font.pixelSize: 11
                                color: "#64748B"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Text {
                            id: p2Name
                            anchors.left: parent.left
                            anchors.leftMargin: 2
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            text: iN_Data.param2Name
                            font.pixelSize: 14
                            color: "#64748B"
                        }

                        Item {
                            anchors.left: p2Name.right
                            anchors.leftMargin: 6
                            anchors.right: parent.right
                            anchors.rightMargin: 2
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            height: 10

                            Rectangle {
                                anchors.fill: parent
                                radius: 4
                                color: progressTrackColor()
                            }

                            Rectangle {
                                width: parent.width * normalizedPercent(iN_Data.param2Percent)
                                height: parent.height
                                radius: 4
                                color: progressColor(iN_Data.param2Percent)
                                visible: iN_Data.param2Value !== "--"

                                Rectangle {
                                    width: parent.width
                                    height: 2
                                    radius: 1
                                    color: "#FFFFFF"
                                    opacity: 0.15
                                }

                                Behavior on width {
                                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                                }
                            }
                        }
                    }
                }

                // 第2行: 温度 + 张力
                Row {
                    width: parent.width
                    height: (parent.height - 6) / 2
                    spacing: 10

                    // 参数3: 温度
                    // ✅ 2026-03-28 [Phase 7.48.88.49.2]: 数值移到右上角
                    Item {
                        width: (parent.width - 10) / 2
                        height: parent.height

                        Row {
                            id: p3ValRow
                            anchors.right: parent.right
                            anchors.rightMargin: 2
                            anchors.top: parent.top
                            anchors.topMargin: 2
                            spacing: 2

                            Text {
                                text: iN_Data.param3Value
                                font.pixelSize: 22
                                font.bold: true
                                color: valueColor(iN_Data.param3Value, iN_Data.param3Percent)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: iN_Data.param3Unit
                                font.pixelSize: 11
                                color: "#64748B"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Text {
                            id: p3Name
                            anchors.left: parent.left
                            anchors.leftMargin: 2
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            text: iN_Data.param3Name
                            font.pixelSize: 14
                            color: "#64748B"
                        }

                        Item {
                            anchors.left: p3Name.right
                            anchors.leftMargin: 6
                            anchors.right: parent.right
                            anchors.rightMargin: 2
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            height: 10

                            Rectangle {
                                anchors.fill: parent
                                radius: 4
                                color: progressTrackColor()
                            }

                            Rectangle {
                                width: parent.width * normalizedPercent(iN_Data.param3Percent)
                                height: parent.height
                                radius: 4
                                color: progressColor(iN_Data.param3Percent)
                                visible: iN_Data.param3Value !== "--"

                                Rectangle {
                                    width: parent.width
                                    height: 2
                                    radius: 1
                                    color: "#FFFFFF"
                                    opacity: 0.15
                                }

                                Behavior on width {
                                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                                }
                            }
                        }
                    }

                    // 参数4: 张力
                    // ✅ 2026-03-28 [Phase 7.48.88.49.2]: 数值移到右上角
                    Item {
                        width: (parent.width - 10) / 2
                        height: parent.height

                        Row {
                            id: p4ValRow
                            anchors.right: parent.right
                            anchors.rightMargin: 2
                            anchors.top: parent.top
                            anchors.topMargin: 2
                            spacing: 2

                            Text {
                                text: iN_Data.param4Value
                                font.pixelSize: 22
                                font.bold: true
                                color: valueColor(iN_Data.param4Value, iN_Data.param4Percent)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: iN_Data.param4Unit
                                font.pixelSize: 11
                                color: "#64748B"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Text {
                            id: p4Name
                            anchors.left: parent.left
                            anchors.leftMargin: 2
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            text: iN_Data.param4Name
                            font.pixelSize: 14
                            color: "#64748B"
                        }

                        Item {
                            anchors.left: p4Name.right
                            anchors.leftMargin: 6
                            anchors.right: parent.right
                            anchors.rightMargin: 2
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            height: 10

                            Rectangle {
                                anchors.fill: parent
                                radius: 4
                                color: progressTrackColor()
                            }

                            Rectangle {
                                width: parent.width * normalizedPercent(iN_Data.param4Percent)
                                height: parent.height
                                radius: 4
                                color: progressColor(iN_Data.param4Percent)
                                visible: iN_Data.param4Value !== "--"

                                Rectangle {
                                    width: parent.width
                                    height: 2
                                    radius: 1
                                    color: "#FFFFFF"
                                    opacity: 0.15
                                }

                                Behavior on width {
                                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                                }
                            }
                        }
                    }
                }
            }

            // ---- 模式B: 序列执行中 - 大字体阶段+倒计时 ----
            Column {
                anchors.centerIn: parent
                spacing: 6
                visible: sequencePhase !== "" && sequencePhase !== "运行" && sequencePhase !== "停止"

                Text {
                    text: sequencePhase
                    font.pixelSize: 42
                    font.bold: true
                    color: phaseColor()
                    anchors.horizontalCenter: parent.horizontalCenter
                    style: Text.Outline
                    styleColor: "#00000060"

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: sequencePhase === "起车预警" || sequencePhase === "停��预警"
                        NumberAnimation { to: 0.3; duration: 500 }
                        NumberAnimation { to: 1.0; duration: 500 }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 14

                    Text {
                        text: sequenceTotal > 0 ? "[" + sequenceCurrent + "/" + sequenceTotal + "]" : ""
                        font.pixelSize: 24
                        font.bold: true
                        color: "#94A3B8"
                        visible: sequenceTotal > 0
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: countdownSeconds > 0 ? countdownSeconds.toFixed(1) + "s" : ""
                        font.pixelSize: 32
                        font.bold: true
                        color: "#F59E0B"
                        visible: countdownSeconds > 0
                        anchors.verticalCenter: parent.verticalCenter

                        SequentialAnimation on scale {
                            loops: Animation.Infinite
                            running: countdownSeconds > 0
                            NumberAnimation { to: 1.05; duration: 500 }
                            NumberAnimation { to: 1.0; duration: 500 }
                        }
                    }
                }
            }
        }
    }

    // ========== 运行时左侧状态指示条 ==========
    Rectangle {
        x: 3
        y: 78
        width: 4
        height: parent.height - 78 - 22
        radius: 2
        color: statusColor()
        z: 3
        opacity: deviceStatus === "停止" ? 0.3 : 0.8

        SequentialAnimation on opacity {
            loops: Animation.Infinite
            running: deviceStatus === "运行"
            NumberAnimation { to: 0.4; duration: 1500; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.9; duration: 1500; easing.type: Easing.InOutSine }
        }
    }

    // ✅ 使用 states 切换背景图片
    states: [
        State {
            name: "normal"
            when: !iN_Data.selected
            PropertyChanges {
                target: iN_Data
                source: "images/IN_Data.png"
            }
        },
        State {
            name: "selected"
            when: iN_Data.selected
            PropertyChanges {
                target: iN_Data
                source: "images/IN_Data_OK.png"
            }
        }
    ]
}
