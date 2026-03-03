import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// ✅ 2026-02-28 [Phase 7.47.46]: 报警记录页面完整重写
// 主要改动：
//   1. uipro Cyberpunk 工业风重新美化
//   2. 连接真实 alarmHistoryDB 数据库（替换硬编码 ListModel）
//   3. 最新记录排在最顶部（DB层已用 ORDER BY timestamp DESC）
//   4. 筛选按钮：日期（全部/今日/近7天）+ 保护名称 ComboBox
//   5. 新增"保护名称"和"事件类型"列（触发/恢复 badge）
//   6. 空数据占位图、统计信息

Item {
    id: root

    // ========== 筛选属性 ==========
    // 日期筛选模式："all" | "today" | "week"
    property string currentDateFilter: "all"
    // 保护名称筛选："" 表示全部
    property string currentNameFilter: ""

    // ========== 统计属性 ==========
    property int totalCount: 0
    property int todayCount: 0

    // ========== 数据模型 ==========
    ListModel {
        id: alarmModel
    }

    // ========== 初始化 ==========
    Component.onCompleted: {
        Qt.callLater(loadAlarms)
    }

    // ✅ 2026-02-28 [Phase 7.47.48]: 监听 alarmHistoryDB 的 alarmAdded 信号，自动刷新列表
    // 原因：保护触发后 saveAlarmTriggered() 写入DB，但AlarmPage不会主动刷新
    // 修复：alarmAdded 信号触发时，重新调用 loadAlarms() 更新界面
    Connections {
        target: typeof alarmHistoryDB !== "undefined" ? alarmHistoryDB : null
        // ✅ 2026-03-03 [Phase 7.47.78]: QDS 兼容 - QDS 中 alarmHistoryDB 为 undefined
        // 原因：target 为 undefined 时报 "alarmHistoryDB is not defined"，信号也报警告
        ignoreUnknownSignals: true
        function onAlarmAdded() {
            Qt.callLater(loadAlarms)
        }
    }

    // ========== 加载数据函数 ==========
    function loadAlarms() {
        alarmModel.clear()

        // ✅ 2026-03-03 [Phase 7.47.78]: QDS 兼容 - alarmHistoryDB 在 QDS 中未定义
        // 原因：C++ context property 在 QDS 中不存在，直接调用会报 ReferenceError
        if (typeof alarmHistoryDB === "undefined" || alarmHistoryDB === null) {
            console.warn("⚠️ [QDS] alarmHistoryDB 不可用，跳过报警加载")
            return
        }

        var records

        if (currentNameFilter !== "") {
            // 按保护名称筛选（忽略日期筛选）
            records = alarmHistoryDB.queryAlarmByProtection(currentNameFilter, 500)
        } else if (currentDateFilter === "today") {
            // 今日记录
            var todayStart = new Date()
            todayStart.setHours(0, 0, 0, 0)
            var todayEnd = new Date()
            todayEnd.setHours(23, 59, 59, 999)
            records = alarmHistoryDB.queryAlarmByDateRange(todayStart, todayEnd)
        } else if (currentDateFilter === "week") {
            // 近7天记录
            var weekStart = new Date()
            weekStart.setDate(weekStart.getDate() - 7)
            weekStart.setHours(0, 0, 0, 0)
            var weekEnd = new Date()
            records = alarmHistoryDB.queryAlarmByDateRange(weekStart, weekEnd)
        } else {
            // 全部记录（最多500条，已按timestamp DESC排序）
            records = alarmHistoryDB.queryAlarmHistory(500, 0)
        }

        if (records && records.length > 0) {
            for (var i = 0; i < records.length; i++) {
                var r = records[i]
                alarmModel.append({
                    // ✅ 2026-02-28 [Phase 7.47.50]: 修复序号倒序——新记录序号最大在顶部，1在最底部
                    // 旧值：i + 1（正序）
                    "rowNum":         records.length - i,
                    "alarmDate":      r.date || "",
                    "alarmTime":      r.time || "",
                    "protectionName": r.protectionName || "",
                    "protectionType": r.protectionType || "",
                    "eventType":      r.eventType || "triggered",
                    "triggerValue":   (r.triggerValue !== undefined) ?
                                       r.triggerValue.toFixed(2) : "0.00"
                })
            }
        }

        // 更新统计
        // ✅ 2026-02-28 [Phase 7.47.50]: 修复总记录数不更新——改用 countAllAlarms() 查DB真实总数
        // 旧值：alarmModel.count（只反映当前筛选结果数量，不是全量）
        totalCount = alarmHistoryDB.countAllAlarms()
        todayCount = alarmHistoryDB.countAlarmsToday()

        console.log("✅ [AlarmPage] 加载报警记录:", alarmModel.count, "条")
    }

    // ========== 主容器 ==========
    Rectangle {
        anchors.fill: parent
        anchors.margins: 10
        color: "#0d1117"
        radius: 12
        border.color: "#1e3a5f"
        border.width: 1

        // 顶部高光线（uipro）
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            anchors.topMargin: 0
            height: 2
            radius: 1
            color: "#00d4ff"
            opacity: 0.7
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // ========== 标题栏 ==========
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // 左侧青色竖条 + 标题
                Rectangle {
                    width: 4
                    height: 32
                    radius: 2
                    color: "#00d4ff"
                }

                Text {
                    text: "报警记录"
                    font.pixelSize: 26
                    font.bold: true
                    color: "#e0f7ff"
                    font.letterSpacing: 2
                }

                Item { Layout.fillWidth: true }

                // 今日报警数统计 badge
                Rectangle {
                    height: 42
                    width: 180
                    radius: 4
                    color: root.todayCount > 0 ? "#1a0808" : "#0d1117"
                    border.color: root.todayCount > 0 ? "#ef4444" : "#334155"
                    border.width: 1
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6
                        // 左侧LED点
                        Rectangle {
                            width: 10; height: 10; radius: 5
                            color: root.todayCount > 0 ? "#ef4444" : "#475569"
                            // 闪烁动画（有报警时）
                            SequentialAnimation on opacity {
                                running: root.todayCount > 0
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 700 }
                                NumberAnimation { to: 1.0; duration: 700 }
                            }
                        }
                        Text {
                            text: "今日报警: " + root.todayCount
                            font.pixelSize: 20
                            color: root.todayCount > 0 ? "#fca5a5" : "#64748B"
                        }
                    }
                }

                // 总记录数统计 badge
                Rectangle {
                    height: 42
                    width: 180
                    radius: 4
                    color: "#0d1b2e"
                    border.color: "#1e3a5f"
                    border.width: 1
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6
                        Rectangle { width: 10; height: 10; radius: 5; color: "#00d4ff"; opacity: 0.7 }
                        Text {
                            text: "总记录: " + root.totalCount
                            font.pixelSize: 20
                            color: "#7ecfff"
                        }
                    }
                }

                // 刷新按钮
                Button {
                    id: refreshBtn
                    width: 110; height: 42

                    background: Rectangle {
                        color: refreshBtn.pressed ? "#1565c0" : (refreshBtn.hovered ? "#1976d2" : "#0d1b2e")
                        radius: 4
                        border.color: refreshBtn.hovered ? "#00d4ff" : "#1e3a5f"
                        border.width: 1
                    }
                    contentItem: Text {
                        text: "刷新"
                        font.pixelSize: 21; font.bold: true
                        color: "#00d4ff"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: loadAlarms()
                }

                // 清空按钮
                Button {
                    id: clearBtn
                    width: 110; height: 42

                    background: Rectangle {
                        color: clearBtn.pressed ? "#7f1d1d" : (clearBtn.hovered ? "#991b1b" : "#1a0808")
                        radius: 4
                        border.color: clearBtn.hovered ? "#ef4444" : "#7f1d1d"
                        border.width: 1
                    }
                    contentItem: Text {
                        text: "清空"
                        font.pixelSize: 21; font.bold: true
                        color: "#ef4444"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        alarmHistoryDB.clearHistory()
                        loadAlarms()
                    }
                }
            }

            // ========== 分隔线 ==========
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#00d4ff"
                opacity: 0.25
            }

            // ========== 筛选栏 ==========
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // 日期筛选标签
                Text {
                    text: "日期:"
                    font.pixelSize: 20
                    color: "#64748B"
                }

                // [全部] 按钮
                Button {
                    id: filterAllBtn
                    text: "全部"
                    width: 90; height: 40
                    checkable: true
                    checked: root.currentDateFilter === "all" && root.currentNameFilter === ""

                    background: Rectangle {
                        color: filterAllBtn.checked ? "#0d3d5c" : (filterAllBtn.hovered ? "#1e2d42" : "#141920")
                        radius: 4
                        border.color: filterAllBtn.checked ? "#00d4ff" : "#334155"
                        border.width: filterAllBtn.checked ? 2 : 1
                        Rectangle {
                            visible: filterAllBtn.checked
                            anchors.top: parent.top
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.margins: 1
                            height: 2; radius: 1; color: "#00d4ff"
                        }
                    }
                    contentItem: Text {
                        text: parent.text
                        font.pixelSize: 20
                        color: filterAllBtn.checked ? "#00d4ff" : "#9E9E9E"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        root.currentDateFilter = "all"
                        root.currentNameFilter = ""
                        nameFilterCombo.currentIndex = 0
                        loadAlarms()
                    }
                }

                // [今日] 按钮
                Button {
                    id: filterTodayBtn
                    text: "今日"
                    width: 90; height: 40
                    checkable: true
                    checked: root.currentDateFilter === "today" && root.currentNameFilter === ""

                    background: Rectangle {
                        color: filterTodayBtn.checked ? "#0f2d14" : (filterTodayBtn.hovered ? "#1e2d42" : "#141920")
                        radius: 4
                        border.color: filterTodayBtn.checked ? "#22C55E" : "#334155"
                        border.width: filterTodayBtn.checked ? 2 : 1
                        Rectangle {
                            visible: filterTodayBtn.checked
                            anchors.top: parent.top
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.margins: 1
                            height: 2; radius: 1; color: "#22C55E"
                        }
                    }
                    contentItem: Text {
                        text: parent.text
                        font.pixelSize: 20
                        color: filterTodayBtn.checked ? "#22C55E" : "#9E9E9E"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        root.currentDateFilter = "today"
                        root.currentNameFilter = ""
                        nameFilterCombo.currentIndex = 0
                        loadAlarms()
                    }
                }

                // [近7天] 按钮
                Button {
                    id: filterWeekBtn
                    text: "近7天"
                    width: 100; height: 40
                    checkable: true
                    checked: root.currentDateFilter === "week" && root.currentNameFilter === ""

                    background: Rectangle {
                        color: filterWeekBtn.checked ? "#1c1500" : (filterWeekBtn.hovered ? "#1e2d42" : "#141920")
                        radius: 4
                        border.color: filterWeekBtn.checked ? "#F59E0B" : "#334155"
                        border.width: filterWeekBtn.checked ? 2 : 1
                        Rectangle {
                            visible: filterWeekBtn.checked
                            anchors.top: parent.top
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.margins: 1
                            height: 2; radius: 1; color: "#F59E0B"
                        }
                    }
                    contentItem: Text {
                        text: parent.text
                        font.pixelSize: 20
                        color: filterWeekBtn.checked ? "#F59E0B" : "#9E9E9E"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        root.currentDateFilter = "week"
                        root.currentNameFilter = ""
                        nameFilterCombo.currentIndex = 0
                        loadAlarms()
                    }
                }

                // 分隔线
                Rectangle {
                    width: 1; height: 30
                    color: "#334155"
                }

                // 保护名称筛选标签
                Text {
                    text: "保护名称:"
                    font.pixelSize: 20
                    color: "#64748B"
                }

                // 保护名称 ComboBox
                ComboBox {
                    id: nameFilterCombo
                    model: ["全部保护", "急停", "跑偏", "撕裂", "烟雾", "温度", "护网", "堆煤", "主机急停"]
                    width: 190; height: 40

                    background: Rectangle {
                        color: nameFilterCombo.pressed ? "#1e2d42" : "#141920"
                        radius: 4
                        border.color: root.currentNameFilter !== "" ? "#00d4ff" : "#334155"
                        border.width: root.currentNameFilter !== "" ? 2 : 1
                    }
                    contentItem: Text {
                        text: nameFilterCombo.displayText
                        font.pixelSize: 20
                        color: root.currentNameFilter !== "" ? "#00d4ff" : "#E0E0E0"
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 8
                    }
                    indicator: Item {
                        x: nameFilterCombo.width - width - 8
                        y: (nameFilterCombo.height - height) / 2
                        width: 16; height: 16
                        Text {
                            text: "▾"
                            font.pixelSize: 16
                            color: "#64748B"
                            anchors.centerIn: parent
                        }
                    }
                    popup: Popup {
                        y: nameFilterCombo.height + 4
                        width: nameFilterCombo.width
                        implicitHeight: contentItem.implicitHeight
                        padding: 0
                        background: Rectangle {
                            color: "#1a1a2e"
                            border.color: "#00d4ff"
                            border.width: 1
                            radius: 4
                        }
                        contentItem: ListView {
                            clip: true
                            implicitHeight: contentHeight
                            model: nameFilterCombo.delegateModel
                        }
                    }
                    delegate: ItemDelegate {
                        width: nameFilterCombo.width
                        height: 44
                        background: Rectangle {
                            color: hovered ? "#1e3a5f" : "#141920"
                        }
                        contentItem: Text {
                            text: modelData
                            font.pixelSize: 20
                            color: "#E0E0E0"
                            leftPadding: 8
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    // onActivated 只在用户手动选择时触发（不在初始化时触发）
                    onActivated: {
                        if (currentIndex === 0) {
                            root.currentNameFilter = ""
                        } else {
                            // ✅ 2026-02-28 [Phase 7.47.50]: 修复过滤——UI短名 → DB完整名映射
                            // 旧：root.currentNameFilter = model[currentIndex]（"急停"查不到"沿线急停"）
                            var nameMap = { "急停": "沿线急停", "跑偏": "沿线跑偏", "撕裂": "沿线撕裂" }
                            var selected = model[currentIndex]
                            root.currentNameFilter = nameMap[selected] || selected
                            root.currentDateFilter = "all"
                        }
                        loadAlarms()
                    }
                }

                Item { Layout.fillWidth: true }

                // DB连接状态
                RowLayout {
                    spacing: 6
                    Rectangle {
                        width: 10; height: 10; radius: 5
                        color: "#22C55E"
                    }
                    Text {
                        text: "数据库已连接"
                        font.pixelSize: 18
                        color: "#475569"
                    }
                }
            }

            // ========== 表格区域 ==========
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#090e14"
                radius: 8
                border.color: "#1e3a5f"
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 0
                    spacing: 0

                    // ---------- 表头 ----------
                    Rectangle {
                        Layout.fillWidth: true
                        height: 60
                        color: "#0d1f3a"
                        radius: 8

                        // 底部直角覆盖层
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 8
                            color: "#0d1f3a"
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 16
                            spacing: 0

                            // # 序号
                            Text {
                                text: "#"
                                font.pixelSize: 20; font.bold: true
                                color: "#00d4ff"
                                Layout.preferredWidth: 70
                                horizontalAlignment: Text.AlignHCenter
                            }
                            Rectangle { width: 1; Layout.fillHeight: true; color: "#00d4ff"; opacity: 0.15; Layout.topMargin: 10; Layout.bottomMargin: 10 }

                            // 日期
                            Text {
                                text: "日期"
                                font.pixelSize: 20; font.bold: true
                                color: "#00d4ff"
                                Layout.preferredWidth: 150
                                horizontalAlignment: Text.AlignHCenter
                            }
                            Rectangle { width: 1; Layout.fillHeight: true; color: "#00d4ff"; opacity: 0.15; Layout.topMargin: 10; Layout.bottomMargin: 10 }

                            // 时间
                            Text {
                                text: "时间"
                                font.pixelSize: 20; font.bold: true
                                color: "#00d4ff"
                                Layout.preferredWidth: 130
                                horizontalAlignment: Text.AlignHCenter
                            }
                            Rectangle { width: 1; Layout.fillHeight: true; color: "#00d4ff"; opacity: 0.15; Layout.topMargin: 10; Layout.bottomMargin: 10 }

                            // 保护名称
                            Text {
                                text: "保护名称"
                                font.pixelSize: 20; font.bold: true
                                color: "#00d4ff"
                                Layout.preferredWidth: 180
                                horizontalAlignment: Text.AlignHCenter
                            }
                            Rectangle { width: 1; Layout.fillHeight: true; color: "#00d4ff"; opacity: 0.15; Layout.topMargin: 10; Layout.bottomMargin: 10 }

                            // 事件类型
                            Text {
                                text: "事件"
                                font.pixelSize: 20; font.bold: true
                                color: "#00d4ff"
                                Layout.preferredWidth: 130
                                horizontalAlignment: Text.AlignHCenter
                            }
                            Rectangle { width: 1; Layout.fillHeight: true; color: "#00d4ff"; opacity: 0.15; Layout.topMargin: 10; Layout.bottomMargin: 10 }

                            // 详情
                            Text {
                                text: "详情"
                                font.pixelSize: 20; font.bold: true
                                color: "#00d4ff"
                                Layout.fillWidth: true
                                leftPadding: 16
                            }
                        }
                    }

                    // 表头底部分隔线
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: "#00d4ff"
                        opacity: 0.25
                    }

                    // ---------- 空数据占位 ----------
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: alarmModel.count === 0

                        Column {
                            anchors.centerIn: parent
                            spacing: 14

                            // 空状态图标
                            Rectangle {
                                width: 64; height: 64; radius: 32
                                color: "#0d1f3a"
                                border.color: "#1e3a5f"
                                border.width: 2
                                anchors.horizontalCenter: parent.horizontalCenter

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 2
                                    Repeater {
                                        model: 3
                                        Rectangle {
                                            width: 28; height: 4; radius: 2
                                            color: "#1e3a5f"
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }
                                }
                            }

                            Text {
                                text: "暂无报警记录"
                                font.pixelSize: 22
                                color: "#334155"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Text {
                                text: "当保护触发时，记录将自动出现在此处"
                                font.pixelSize: 18
                                color: "#1e3a5f"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }

                    // ---------- 数据列表 ----------
                    ScrollView {
                        id: alarmScrollView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        visible: alarmModel.count > 0

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            width: 10

                            contentItem: Rectangle {
                                implicitWidth: 6; radius: 3
                                color: parent.pressed ? "#00d4ff" : (parent.hovered ? "#0090aa" : "#1e3a5f")
                                opacity: parent.pressed || parent.hovered ? 1.0 : 0.7
                            }
                            background: Rectangle {
                                color: "#0d1117"
                                radius: 3
                                opacity: 0.3
                            }
                        }

                        ListView {
                            id: alarmListView
                            model: alarmModel
                            spacing: 1

                            delegate: Rectangle {
                                // 行宽留出滚动条空间
                                width: alarmListView.width - 14
                                height: 66

                                // 根据事件类型决定行背景色
                                readonly property bool isTriggered: model.eventType === "triggered"

                                color: {
                                    if (isTriggered) {
                                        return (index % 2 === 0) ? "#160808" : "#1a0a0a"
                                    } else {
                                        return (index % 2 === 0) ? "#08120a" : "#0a150c"
                                    }
                                }

                                // Hover 高亮
                                HoverHandler { id: rowHover }
                                Rectangle {
                                    anchors.fill: parent
                                    color: "#00d4ff"
                                    opacity: rowHover.hovered ? 0.06 : 0
                                    Behavior on opacity { NumberAnimation { duration: 120 } }
                                }

                                // 左侧彩色竖条（触发=红，恢复=绿）
                                Rectangle {
                                    x: 0; y: 10
                                    width: 3; height: parent.height - 20
                                    radius: 2
                                    color: isTriggered ? "#ef4444" : "#22C55E"
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 6
                                    spacing: 0

                                    // # 序号
                                    Text {
                                        text: model.rowNum
                                        font.pixelSize: 20
                                        color: isTriggered ? "#f87171" : "#4ade80"
                                        Layout.preferredWidth: 70
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    Rectangle { width: 1; Layout.fillHeight: true; color: "#00d4ff"; opacity: 0.07; Layout.topMargin: 12; Layout.bottomMargin: 12 }

                                    // 日期
                                    Text {
                                        text: model.alarmDate
                                        font.pixelSize: 20
                                        color: "#94a3b8"
                                        Layout.preferredWidth: 150
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    Rectangle { width: 1; Layout.fillHeight: true; color: "#00d4ff"; opacity: 0.07; Layout.topMargin: 12; Layout.bottomMargin: 12 }

                                    // 时间
                                    Text {
                                        text: model.alarmTime
                                        font.pixelSize: 20; font.bold: true
                                        color: "#cbd5e1"
                                        Layout.preferredWidth: 130
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    Rectangle { width: 1; Layout.fillHeight: true; color: "#00d4ff"; opacity: 0.07; Layout.topMargin: 12; Layout.bottomMargin: 12 }

                                    // 保护名称
                                    Text {
                                        text: model.protectionName
                                        font.pixelSize: 20; font.bold: true
                                        color: "#e2e8f0"
                                        Layout.preferredWidth: 180
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.NoWrap
                                    }
                                    Rectangle { width: 1; Layout.fillHeight: true; color: "#00d4ff"; opacity: 0.07; Layout.topMargin: 12; Layout.bottomMargin: 12 }

                                    // 事件类型 Badge
                                    Item {
                                        Layout.preferredWidth: 130
                                        Layout.fillHeight: true

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 110; height: 36; radius: 6
                                            color: isTriggered ? "#3d0f0f" : "#0a2214"
                                            border.color: isTriggered ? "#ef4444" : "#22C55E"
                                            border.width: 1

                                            // 顶部高光线
                                            Rectangle {
                                                anchors.top: parent.top
                                                anchors.left: parent.left; anchors.right: parent.right
                                                anchors.margins: 1
                                                height: 1; radius: 1
                                                color: isTriggered ? "#ef4444" : "#22C55E"
                                                opacity: 0.5
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: isTriggered ? "保护触发" : "保护恢复"
                                                font.pixelSize: 18; font.bold: true
                                                color: isTriggered ? "#fca5a5" : "#86efac"
                                            }
                                        }
                                    }
                                    Rectangle { width: 1; Layout.fillHeight: true; color: "#00d4ff"; opacity: 0.07; Layout.topMargin: 12; Layout.bottomMargin: 12 }

                                    // 详情
                                    Text {
                                        text: {
                                            if (model.protectionType && model.protectionType.length > 0) {
                                                return model.protectionType
                                            }
                                            if (isTriggered) {
                                                return "触发值: " + model.triggerValue
                                            }
                                            return "已恢复正常"
                                        }
                                        font.pixelSize: 20
                                        color: isTriggered ? "#f87171" : "#4ade80"
                                        Layout.fillWidth: true
                                        leftPadding: 16
                                        elide: Text.ElideRight
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }

                                // 行间分隔线
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 1
                                    color: "#00d4ff"
                                    opacity: 0.05
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
