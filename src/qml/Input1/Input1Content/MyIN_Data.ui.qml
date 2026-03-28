import QtQuick

// ✅ 2026-01-27 [FIX 100.300.54]: 添加选中状态支持
// ✅ 2026-02-02 [FIX 100.300.112.8.19.3]: 重新设计组件布局
// ✅ 2026-03-26 [Phase 7.48.88.25]: 重新设计卡片 - 显示实时数据+序列阶段+保护状态
// ✅ 2026-03-26 [Phase 7.48.88.26]: 修复5个UI问题：
//   问题1: 标题文字与背景图装饰线重合 → 标题放入header band内(y:6,h:50)，内容区从y:62开始
//   问题2: 参数值"--"条件 → 添加数据绑定接口说明
//   问题3: 布局不均匀/底部空白 → 重新计算各区域高度分配
//   问题4: 字体像素与卡片尺寸不匹配 → 加大核心数据字号，优化视觉层次
//   问题5: 设计过于简单 → 添加工业SCADA深色科技风元素（渐变背景/发光效果/进度条/科技感分隔线）
//   设计风格: 工业SCADA深色科技风 (ui-ux-pro-max: Real-Time Monitoring + Dark Mode OLED)
//   颜色方案: #22C55E(正常) / #F59E0B(预警) / #DC2626(报警) 三级状态指示
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
    // 保护触发时设置，保护物理恢复后保持，仅F键复位时清除
    // 三态：绿(正常) / 红(保护触发中) / 琥珀(已恢复待确认)
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

    // 状态颜色函数
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
        if (valueText === "--") {
            return isLocalDevice ? "#7DD3FC99" : "#475569"
        }

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

    // ✅ 2026-03-28 [Phase 7.48.88.48]: 输出设备名缩写
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

    function progressTrackColor() {
        return isLocalDevice ? "#10273A" : "#1E293B"
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

    // ========== ① 标题栏 - 放在背景图header band中央 ==========
    // ✅ 2026-03-26 [Phase 7.48.88.26.3]: 设备名移到header band中央（装饰线之间）
    // 原因：用户反馈"放在顶部中央的位置，放在背景图片线条之间的位置更好看"
    // 背景图header band: y:0~55, 中央六边形区域约 x:80~400, y:5~45
    // 设备名：居中在header band中央
    Item {
        id: titleBar
        x: 0
        y: 5
        width: parent.width
        height: 45
        z: 3

        // 设备名称（居中显示在header band中央）
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

    // ========== 状态指示 - header band下方左侧 ==========
    // ✅ 2026-03-27 [Phase 7.48.88.34]: 扩展为三栏：[状态指示灯+文字] [模式徽章] [连锁徽章]
    Row {
        id: statusRow
        x: 24
        y: 55
        z: 3
        spacing: 8

        // --- 第1元素：状态指示灯 + 状态文字（保留现有） ---
        Row {
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter

            // 状态指示灯（外发光效果）
            Item {
                width: 16
                height: 16
                anchors.verticalCenter: parent.verticalCenter

                // 外发光
                Rectangle {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    radius: 11
                    color: statusColor()
                    opacity: 0.3
                    visible: deviceStatus === "运行" || deviceStatus === "故障"
                }

                // 核心指示灯
                Rectangle {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    radius: 7
                    color: statusColor()

                    // 运行时呼吸灯
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: deviceStatus === "运行"
                        NumberAnimation { to: 0.4; duration: 1000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
                    }
                    // 故障时快速闪烁
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
                font.pixelSize: 18
                font.bold: true
                color: statusColor()
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // --- 第2元素：模式徽章 ---
        Rectangle {
            width: modeText.implicitWidth + 12
            height: 20
            radius: 3
            // 旧代码：无模式徽章
            color: workMode === 0 ? "#33F59E0B" : "#3322C55E"
            border.color: workMode === 0 ? "#F59E0B" : "#22C55E"
            border.width: 1
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: modeText
                anchors.centerIn: parent
                text: workMode === 0 ? "检修" : "就地"
                font.pixelSize: 12
                font.family: "Microsoft YaHei"
                color: workMode === 0 ? "#F59E0B" : "#22C55E"
            }
        }

        // --- 第3元素：连锁徽章 ---
        Rectangle {
            width: lockText.implicitWidth + 12
            height: 20
            radius: 3
            // 旧代码：无连锁徽章
            color: interlockActive ? "#333B82F6" : "#33EF4444"
            border.color: interlockActive ? "#3B82F6" : "#EF4444"
            border.width: 1
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: lockText
                anchors.centerIn: parent
                text: interlockActive ? "连锁" : "解锁"
                font.pixelSize: 12
                font.family: "Microsoft YaHei"
                color: interlockActive ? "#3B82F6" : "#EF4444"
            }
        }

        // --- 第4元素：允许运行徽章 ---
        // ✅ 2026-03-27 [Phase 7.48.88.38]: 允许运行指示
        Rectangle {
            width: allowRunText.implicitWidth + 12
            height: 20
            radius: 3
            color: allowRun ? "#3322C55E" : "#33DC2626"
            border.color: allowRun ? "#22C55E" : "#DC2626"
            border.width: 1
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: allowRunText
                anchors.centerIn: parent
                text: allowRun ? "允许" : "禁止"
                font.pixelSize: 12
                font.family: "Microsoft YaHei"
                color: allowRun ? "#22C55E" : "#DC2626"
            }
        }

        // --- 第5元素：故障详情徽章（仅故障时显示） ---
        // ✅ 2026-03-27 [Phase 7.48.88.38]: 具体故障原因指示
        // ✅ 2026-03-27 [Phase 7.48.88.39]: 限制最大宽度防止溢出，文字截断
        // ✅ 2026-03-27 [Phase 7.48.88.40]: 使用固定最大宽度，避免parent.width-x循环依赖导致polish()循环
        Rectangle {
            width: Math.min(faultDetailText.implicitWidth + 12, 180)
            height: 20
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
                font.pixelSize: 12
                font.bold: true
                font.family: "Microsoft YaHei"
                color: "#DC2626"
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            // 故障时闪烁
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: faultDetail !== ""
                NumberAnimation { to: 0.5; duration: 600 }
                NumberAnimation { to: 1.0; duration: 600 }
            }
        }
    }

    // ========== 主内容区域 ==========
    // ✅ 2026-03-26 [Phase 7.48.88.26.3]: y从100改为78（状态指示y:55+h:20=75，留3px间距）
    // 起始y: 78, 结束y: 310 (底部装饰上方)
    // 可用高度: 232px
    Column {
        id: contentArea
        x: 18
        y: 78
        width: parent.width - 36
        height: parent.height - 78 - 22
        // ✅ 2026-03-28 [Phase 7.48.88.48]: spacing从4缩减到2，为输出设备LED腾出空间
        spacing: 2
        z: 2

        // ========== ② 核心数据区 ==========
        // 序列空闲时: 2×2参数网格 + 微型进度条
        // 序列执行时: 大字体阶段名 + 倒计时
        // ✅ 2026-03-28 [Phase 7.48.88.48]: 从140→130→118，配合spacing缩减避免Column溢出
        Item {
            width: parent.width
            height: 118

            // 暗色半透明背景（增加层次感和可读性）
            Rectangle {
                anchors.fill: parent
                color: "#0D1B2A"
                opacity: 0.45
                radius: 4
            }

            // ---- 模式A: 参数显示（空闲/运行/停止时） ----
            Grid {
                anchors.fill: parent
                anchors.margins: 6
                columns: 2
                rowSpacing: 4
                columnSpacing: 10
                visible: sequencePhase === "" || sequencePhase === "运行" || sequencePhase === "停止"

                // 参数1
                // ✅ 2026-03-26 [Phase 7.48.88.26.2]: h:64→52, 数值字体32→26（修复Grid溢出重叠）
                Item {
                    width: (parent.width - 10) / 2
                    height: 56

                    Column {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        spacing: 1

                        // 标签行
                        Text {
                            text: iN_Data.param1Name
                            font.pixelSize: 14
                            color: "#64748B"
                        }

                        // 数值行
                        Item {
                            width: parent.width - 8
                            height: 30

                            Text {
                                id: param1ValueText
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                text: iN_Data.param1Value
                                font.pixelSize: 26
                                font.bold: true
                                color: valueColor(iN_Data.param1Value, iN_Data.param1Percent)
                            }

                            Text {
                                anchors.left: param1ValueText.right
                                anchors.leftMargin: 4
                                anchors.bottom: param1ValueText.bottom
                                anchors.bottomMargin: 3
                                text: iN_Data.param1Unit
                                font.pixelSize: 14
                                color: "#64748B"
                            }
                        }

                        // ✅ 2026-03-26 [Phase 7.48.88.26.3]: 增强进度条 - 工业仪表风格
                        // 分段刻度 + 渐变填充 + 发光球 + 光晕
                        Item {
                            width: parent.width - 8
                            height: 10

                            // 轨道背景（带分段刻度线）
                            Rectangle {
                                anchors.fill: parent
                                radius: 3
                                color: progressTrackColor()

                                // 分段刻度线（10等分）
                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 1
                                    anchors.rightMargin: 1
                                    spacing: 0

                                    Repeater {
                                        model: 9
                                        Rectangle {
                                            x: (index + 1) * (parent.width / 10) - 0.5
                                            width: 1
                                            height: parent.height
                                            color: "#334155"
                                            opacity: 0.5
                                        }
                                    }
                                }
                            }

                            // 填充条（带渐变效果）
                            Rectangle {
                                width: parent.width * normalizedPercent(iN_Data.param1Percent)
                                height: parent.height
                                radius: 3
                                color: progressColor(iN_Data.param1Percent)
                                visible: iN_Data.param1Value !== "--"

                                // 顶部高光线
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

                            // 发光球（在填充条末端）
                            Rectangle {
                                width: 14
                                height: 14
                                radius: 7
                                x: Math.max(0, Math.min(parent.width - width,
                                    parent.width * normalizedPercent(iN_Data.param1Percent) - width / 2))
                                y: (parent.height - height) / 2
                                color: progressGlowColor(iN_Data.param1Percent)
                                visible: iN_Data.param1Value !== "--" && normalizedPercent(iN_Data.param1Percent) > 0
                                opacity: 0.85

                                // 内核高亮
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: "#FFFFFF"
                                    opacity: 0.6
                                }
                            }

                            // 底部光晕
                            Rectangle {
                                width: parent.width * normalizedPercent(iN_Data.param1Percent)
                                height: parent.height + 6
                                radius: 5
                                x: 0
                                y: -3
                                color: progressGlowColor(iN_Data.param1Percent)
                                opacity: 0.12
                                visible: iN_Data.param1Value !== "--"
                            }
                        }
                    }
                }

                // 参数2
                // ✅ 2026-03-26 [Phase 7.48.88.26.2]: h:64→52, 字体32→26
                Item {
                    width: (parent.width - 10) / 2
                    height: 56

                    Column {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        spacing: 1

                        Text {
                            text: iN_Data.param2Name
                            font.pixelSize: 14
                            color: "#64748B"
                        }
                        Item {
                            width: parent.width - 8
                            height: 30

                            Text {
                                id: param2ValueText
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                text: iN_Data.param2Value
                                font.pixelSize: 26
                                font.bold: true
                                color: valueColor(iN_Data.param2Value, iN_Data.param2Percent)
                            }

                            Text {
                                anchors.left: param2ValueText.right
                                anchors.leftMargin: 4
                                anchors.bottom: param2ValueText.bottom
                                anchors.bottomMargin: 3
                                text: iN_Data.param2Unit
                                font.pixelSize: 14
                                color: "#64748B"
                            }
                        }
                        // ✅ 2026-03-26 [Phase 7.48.88.26.3]: 增强进度条 - 工业仪表风格
                        Item {
                            width: parent.width - 8
                            height: 10

                            Rectangle {
                                anchors.fill: parent
                                radius: 3
                                color: progressTrackColor()

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 1
                                    anchors.rightMargin: 1
                                    spacing: 0

                                    Repeater {
                                        model: 9
                                        Rectangle {
                                            x: (index + 1) * (parent.width / 10) - 0.5
                                            width: 1
                                            height: parent.height
                                            color: "#334155"
                                            opacity: 0.5
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width * normalizedPercent(iN_Data.param2Percent)
                                height: parent.height
                                radius: 3
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

                            Rectangle {
                                width: 14
                                height: 14
                                radius: 7
                                x: Math.max(0, Math.min(parent.width - width,
                                    parent.width * normalizedPercent(iN_Data.param2Percent) - width / 2))
                                y: (parent.height - height) / 2
                                color: progressGlowColor(iN_Data.param2Percent)
                                visible: iN_Data.param2Value !== "--" && normalizedPercent(iN_Data.param2Percent) > 0
                                opacity: 0.85

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: "#FFFFFF"
                                    opacity: 0.6
                                }
                            }

                            Rectangle {
                                width: parent.width * normalizedPercent(iN_Data.param2Percent)
                                height: parent.height + 6
                                radius: 5
                                x: 0
                                y: -3
                                color: progressGlowColor(iN_Data.param2Percent)
                                opacity: 0.12
                                visible: iN_Data.param2Value !== "--"
                            }
                        }
                    }
                }

                // 参数3
                // ✅ 2026-03-26 [Phase 7.48.88.26.2]: h:64→52, 字体32→26
                Item {
                    width: (parent.width - 10) / 2
                    height: 56

                    Column {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        spacing: 1

                        Text {
                            text: iN_Data.param3Name
                            font.pixelSize: 14
                            color: "#64748B"
                        }
                        Item {
                            width: parent.width - 8
                            height: 30

                            Text {
                                id: param3ValueText
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                text: iN_Data.param3Value
                                font.pixelSize: 26
                                font.bold: true
                                color: valueColor(iN_Data.param3Value, iN_Data.param3Percent)
                            }

                            Text {
                                anchors.left: param3ValueText.right
                                anchors.leftMargin: 4
                                anchors.bottom: param3ValueText.bottom
                                anchors.bottomMargin: 3
                                text: iN_Data.param3Unit
                                font.pixelSize: 14
                                color: "#64748B"
                            }
                        }
                        // ✅ 2026-03-26 [Phase 7.48.88.26.3]: 增强进度条 - 工业仪表风格
                        Item {
                            width: parent.width - 8
                            height: 10

                            Rectangle {
                                anchors.fill: parent
                                radius: 3
                                color: progressTrackColor()

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 1
                                    anchors.rightMargin: 1
                                    spacing: 0

                                    Repeater {
                                        model: 9
                                        Rectangle {
                                            x: (index + 1) * (parent.width / 10) - 0.5
                                            width: 1
                                            height: parent.height
                                            color: "#334155"
                                            opacity: 0.5
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width * normalizedPercent(iN_Data.param3Percent)
                                height: parent.height
                                radius: 3
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

                            Rectangle {
                                width: 14
                                height: 14
                                radius: 7
                                x: Math.max(0, Math.min(parent.width - width,
                                    parent.width * normalizedPercent(iN_Data.param3Percent) - width / 2))
                                y: (parent.height - height) / 2
                                color: progressGlowColor(iN_Data.param3Percent)
                                visible: iN_Data.param3Value !== "--" && normalizedPercent(iN_Data.param3Percent) > 0
                                opacity: 0.85

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: "#FFFFFF"
                                    opacity: 0.6
                                }
                            }

                            Rectangle {
                                width: parent.width * normalizedPercent(iN_Data.param3Percent)
                                height: parent.height + 6
                                radius: 5
                                x: 0
                                y: -3
                                color: progressGlowColor(iN_Data.param3Percent)
                                opacity: 0.12
                                visible: iN_Data.param3Value !== "--"
                            }
                        }
                    }
                }

                // 参数4
                // ✅ 2026-03-26 [Phase 7.48.88.26.2]: h:64→52, 字体32→26
                Item {
                    width: (parent.width - 10) / 2
                    height: 56

                    Column {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        spacing: 1

                        Text {
                            text: iN_Data.param4Name
                            font.pixelSize: 14
                            color: "#64748B"
                        }
                        Item {
                            width: parent.width - 8
                            height: 30

                            Text {
                                id: param4ValueText
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                text: iN_Data.param4Value
                                font.pixelSize: 26
                                font.bold: true
                                color: valueColor(iN_Data.param4Value, iN_Data.param4Percent)
                            }

                            Text {
                                anchors.left: param4ValueText.right
                                anchors.leftMargin: 4
                                anchors.bottom: param4ValueText.bottom
                                anchors.bottomMargin: 3
                                text: iN_Data.param4Unit
                                font.pixelSize: 14
                                color: "#64748B"
                            }
                        }
                        // ✅ 2026-03-26 [Phase 7.48.88.26.3]: 增强进度条 - 工业仪表风格
                        Item {
                            width: parent.width - 8
                            height: 10

                            Rectangle {
                                anchors.fill: parent
                                radius: 3
                                color: progressTrackColor()

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 1
                                    anchors.rightMargin: 1
                                    spacing: 0

                                    Repeater {
                                        model: 9
                                        Rectangle {
                                            x: (index + 1) * (parent.width / 10) - 0.5
                                            width: 1
                                            height: parent.height
                                            color: "#334155"
                                            opacity: 0.5
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width * normalizedPercent(iN_Data.param4Percent)
                                height: parent.height
                                radius: 3
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

                            Rectangle {
                                width: 14
                                height: 14
                                radius: 7
                                x: Math.max(0, Math.min(parent.width - width,
                                    parent.width * normalizedPercent(iN_Data.param4Percent) - width / 2))
                                y: (parent.height - height) / 2
                                color: progressGlowColor(iN_Data.param4Percent)
                                visible: iN_Data.param4Value !== "--" && normalizedPercent(iN_Data.param4Percent) > 0
                                opacity: 0.85

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: "#FFFFFF"
                                    opacity: 0.6
                                }
                            }

                            Rectangle {
                                width: parent.width * normalizedPercent(iN_Data.param4Percent)
                                height: parent.height + 6
                                radius: 5
                                x: 0
                                y: -3
                                color: progressGlowColor(iN_Data.param4Percent)
                                opacity: 0.12
                                visible: iN_Data.param4Value !== "--"
                            }
                        }
                    }
                }
            }

            // ---- 模式B: 序列执行中 - 大字体阶段+倒计时 ----
            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: sequencePhase !== "" && sequencePhase !== "运行" && sequencePhase !== "停止"

                // 阶段名称（超大字体）
                Text {
                    text: sequencePhase
                    font.pixelSize: 42
                    font.bold: true
                    color: phaseColor()
                    anchors.horizontalCenter: parent.horizontalCenter
                    style: Text.Outline
                    styleColor: "#00000060"

                    // 预警阶段文字闪烁
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: sequencePhase === "起车预警" || sequencePhase === "停车预警"
                        NumberAnimation { to: 0.3; duration: 500 }
                        NumberAnimation { to: 1.0; duration: 500 }
                    }
                }

                // 进度和倒计时
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 16

                    // 进度指示: [2/4]
                    Text {
                        text: sequenceTotal > 0 ? "[" + sequenceCurrent + "/" + sequenceTotal + "]" : ""
                        font.pixelSize: 26
                        font.bold: true
                        color: "#94A3B8"
                        visible: sequenceTotal > 0
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // 倒计时（醒目橙色）
                    Text {
                        text: countdownSeconds > 0 ? countdownSeconds.toFixed(1) + "s" : ""
                        font.pixelSize: 36
                        font.bold: true
                        color: "#F59E0B"
                        visible: countdownSeconds > 0
                        anchors.verticalCenter: parent.verticalCenter
                        style: Text.Outline
                        styleColor: "#00000040"

                        // 倒计时数字脉冲效果
                        SequentialAnimation on scale {
                            loops: Animation.Infinite
                            running: countdownSeconds > 0
                            NumberAnimation { to: 1.05; duration: 500 }
                            NumberAnimation { to: 1.0; duration: 500 }
                        }
                    }
                }

                // ✅ 2026-03-26 [Phase 7.48.88.26.3]: 增强序列进度条 - 工业仪表风格
                Item {
                    width: 320
                    height: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: sequenceTotal > 0

                    // 轨道背景（带分段刻度线）
                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: progressTrackColor()

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 1
                            anchors.rightMargin: 1
                            spacing: 0

                            Repeater {
                                model: Math.max(0, sequenceTotal - 1)
                                Rectangle {
                                    x: (index + 1) * (parent.width / sequenceTotal) - 0.5
                                    width: 1
                                    height: parent.height
                                    color: "#4A90E2"
                                    opacity: 0.4
                                }
                            }
                        }
                    }

                    // 填充条
                    Rectangle {
                        width: sequenceTotal > 0 ? parent.width * (sequenceCurrent / sequenceTotal) : 0
                        height: parent.height
                        radius: 4
                        color: phaseColor()

                        Rectangle {
                            width: parent.width
                            height: 2
                            radius: 1
                            color: "#FFFFFF"
                            opacity: 0.2
                        }

                        Behavior on width {
                            NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                        }
                    }

                    // 发光球
                    Rectangle {
                        width: 16
                        height: 16
                        radius: 8
                        x: Math.max(0, Math.min(parent.width - width,
                            (sequenceTotal > 0 ? parent.width * (sequenceCurrent / sequenceTotal) : 0) - width / 2))
                        y: (parent.height - height) / 2
                        color: phaseColor()
                        opacity: 0.88
                        visible: sequenceTotal > 0 && sequenceCurrent > 0

                        Rectangle {
                            anchors.centerIn: parent
                            width: 6
                            height: 6
                            radius: 3
                            color: "#FFFFFF"
                            opacity: 0.6
                        }
                    }

                    // 底部光晕
                    Rectangle {
                        width: sequenceTotal > 0 ? parent.width * (sequenceCurrent / sequenceTotal) : 0
                        height: parent.height + 8
                        radius: 6
                        x: 0
                        y: -4
                        color: phaseColor()
                        opacity: 0.16
                        visible: sequenceTotal > 0 && sequenceCurrent > 0
                    }
                }
            }
        }

        // ========== 科技感分隔线 ==========
        Item {
            width: parent.width
            height: 6

            // 中心发光线
            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: 1
                color: "#4A90E2"
                opacity: 0.6
            }

            // 发光效果
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.6
                height: 3
                radius: 1
                color: "#4A90E2"
                opacity: 0.15
            }
        }

        // ========== ⑤ 输出设备运行状态LED ==========
        // ✅ 2026-03-28 [Phase 7.48.88.48]: 方形LED显示启动序列中设备的运行状态
        // 设备列表从LogicControlPanel启动序列+洒水设备同步
        Item {
            width: parent.width
            height: outputDevices.length > 0 ? 32 : 0
            visible: outputDevices.length > 0

            // 暗色半透明背景
            Rectangle {
                anchors.fill: parent
                color: "#0D1B2A"
                opacity: 0.25
                radius: 3
            }

            Row {
                anchors.centerIn: parent
                spacing: 2

                Repeater {
                    model: outputDevices

                    Item {
                        width: Math.min(55, (contentArea.width - 8) / Math.max(outputDevices.length, 1))
                        height: 30

                        property bool isOn: {
                            var states = outputDeviceStates
                            return states && states[modelData] === true
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

                            // 方形LED
                            Rectangle {
                                width: 10
                                height: 10
                                radius: 2
                                color: isOn ? "#22C55E" : "#4B5563"
                                anchors.horizontalCenter: parent.horizontalCenter

                                // 运行时外发光
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    radius: 3
                                    color: "#22C55E"
                                    opacity: 0.3
                                    visible: isOn
                                    z: -1
                                }
                            }

                            // 设备缩写名
                            Text {
                                text: shortDeviceName(modelData)
                                font.pixelSize: 11
                                color: isOn ? "#22C55E" : "#64748B"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
                }
            }
        }

        // 细分隔线（输出设备与保护栏之间）
        Rectangle {
            width: parent.width
            height: 1
            color: "#4A90E2"
            opacity: outputDevices.length > 0 ? 0.3 : 0
            visible: outputDevices.length > 0
        }

        // ========== ③ 保护状态栏 ==========
        // ✅ 2026-03-28 [Phase 7.48.88.48]: 从46缩减到38，为输出设备LED腾出空间
        // ✅ 2026-03-26 [Phase 7.48.88.26.1]: 从54缩减到46
        Item {
            width: parent.width
            height: 38

            // 暗色半透明背景
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

                        // ✅ 2026-03-26 [Phase 7.48.88.27]: 三态保护指示
                        // triggered: 保护当前触发中（DI位=1）→ 红色
                        // latched: 保护曾触发已恢复，未F键确认 → 琥珀色闪烁
                        // 正常: 绿色
                        property bool triggered: (protectionBits & (1 << modelData.bit)) !== 0
                        property bool latched: !triggered && ((latchedProtectionBits & (1 << modelData.bit)) !== 0)

                        // 三态颜色
                        property color indicatorColor: triggered ? (modelData.bit <= 2 ? "#DC2626" : "#F59E0B")
                                                     : latched ? "#FF8C00"  // 琥珀色（待确认）
                                                     : "#22C55E"            // 绿色（正常）

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

                            // 保护指示灯（带外发光）
                            // ✅ 2026-03-28 [Phase 7.48.88.48]: 从22缩减到16，spacing从4到2
                            Item {
                                width: 16
                                height: 16
                                anchors.horizontalCenter: parent.horizontalCenter

                                // 外发光（触发或待确认时）
                                // ✅ 2026-03-28 [Phase 7.48.88.48]: 从30缩减到22
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 22
                                    height: 22
                                    radius: 11
                                    color: indicatorColor
                                    opacity: 0.3
                                    visible: triggered || latched
                                }

                                // ✅ 2026-03-28 [Phase 7.48.88.48]: 从18缩减到14
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 14
                                    height: 14
                                    radius: 7
                                    color: indicatorColor

                                    // 触发时快速脉冲
                                    SequentialAnimation on scale {
                                        loops: Animation.Infinite
                                        running: triggered
                                        NumberAnimation { to: 1.3; duration: 500 }
                                        NumberAnimation { to: 1.0; duration: 500 }
                                    }

                                    // ✅ 2026-03-26 [Phase 7.48.88.27]: 待确认时慢速闪烁
                                    SequentialAnimation on opacity {
                                        loops: Animation.Infinite
                                        running: latched && !triggered
                                        NumberAnimation { to: 0.4; duration: 800 }
                                        NumberAnimation { to: 1.0; duration: 800 }
                                    }
                                }
                            }

                            // 标签
                            // ✅ 2026-03-28 [Phase 7.48.88.48]: 从14缩减到12
                            Text {
                                text: modelData.name
                                font.pixelSize: 12
                                font.bold: triggered || latched
                                color: indicatorColor
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
                }
            }
        }

        // ========== ④ 底部信息栏 ==========
        // ✅ 2026-03-28 [Phase 7.48.88.48]: 从26缩减到20，为输出设备LED腾出空间
        // ✅ 2026-03-26 [Phase 7.48.88.26.1]: 从30缩减到26
        Item {
            width: parent.width
            height: 20

            Row {
                anchors.fill: parent
                spacing: 12

                // 通讯状态
                Row {
                    height: parent.height
                    spacing: 6

                    // 状态灯（带发光）
                    // ✅ 2026-03-28 [Phase 7.48.88.48]: 缩减尺寸
                    Item {
                        width: 12
                        height: 12
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            radius: 8
                            color: commOnline ? "#22C55E" : "#DC2626"
                            opacity: 0.25
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 10
                            height: 10
                            radius: 5
                            color: commOnline ? "#22C55E" : "#DC2626"
                        }
                    }

                    Text {
                        text: commOnline ? "在线" : "离线"
                        font.pixelSize: 13
                        font.bold: true
                        color: commOnline ? "#22C55E" : "#DC2626"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // 分隔竖线
                Rectangle {
                    width: 1
                    height: 12
                    color: "#334155"
                    anchors.verticalCenter: parent.verticalCenter
                }

                // 今日运行时间
                Row {
                    height: parent.height
                    spacing: 4

                    Text {
                        text: "今日"
                        font.pixelSize: 12
                        color: "#64748B"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: dailyRuntime
                        font.pixelSize: 14
                        font.bold: true
                        color: "#94A3B8"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }

    // ========== 运行时左侧状态指示条 ==========
    // ✅ 2026-03-26 [Phase 7.48.88.26.3]: y从100改为78（与contentArea同步）
    Rectangle {
        x: 3
        y: 78
        width: 4
        height: parent.height - 78 - 22
        radius: 2
        color: statusColor()
        z: 3
        opacity: deviceStatus === "停止" ? 0.3 : 0.8

        // 运行时呼吸
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
