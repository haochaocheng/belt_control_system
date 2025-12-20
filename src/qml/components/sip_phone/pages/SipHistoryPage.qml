import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5
import BeltControl.SipPhone 1.0

// Call history page
Page {
    id: root

    signal callNumber(string number)
    signal callNumberVideo(string number)  // 视频回拨
    signal deleteCallRecord(int index)     // 删除通话记录

    // ✅ 统计可见记录数
    function updateVisibleCount() {
        if (!historyList.model) {
            historyList.visibleCount = 0
            return
        }

        var count = 0
        var totalCount = historyList.model.rowCount()

        // Qt::UserRole = 256, so:
        // CallContactRole = 257, CallDirectionRole = 258, CallDurationRole = 259
        var CallDirectionRole = 258
        var CallDurationRole = 259

        for (var i = 0; i < totalCount; i++) {
            var modelIndex = historyList.model.index(i, 0)
            var direction = historyList.model.data(modelIndex, CallDirectionRole)
            var duration = historyList.model.data(modelIndex, CallDurationRole)

            var isMissed = (direction === 1) && ((duration || 0) < 1000)
            var isIncoming = (direction === 1) && ((duration || 0) >= 1000)

            if (historyList.currentFilter === "all") {
                count++
            } else if (historyList.currentFilter === "missed" && isMissed) {
                count++
            } else if (historyList.currentFilter === "incoming" && isIncoming) {
                count++
            } else if (historyList.currentFilter === "outgoing" && direction === 2) {
                count++
            }
        }

        historyList.visibleCount = count
    }

    // ✅ 从 contact 字符串中提取纯净的号码
    // 输入格式："Extension 1006" 1006 或 "1006" 或 1006
    // 输出：1006
    function extractNumber(contact) {
        if (!contact) return ""

        // 移除所有引号
        var cleaned = contact.replace(/"/g, '')

        // 如果包含空格，取最后一个部分（通常是号码）
        var parts = cleaned.split(' ')
        var result = ""
        if (parts.length > 1) {
            result = parts[parts.length - 1].trim()
        } else {
            result = cleaned.trim()
        }

        // ✅ 去除括号，提取纯数字号码
        // 例如: "(1006)" → "1006", "小七 (1006)" → "1006"
        result = result.replace(/[()]/g, '')

        console.log("📞 [EXTRACT] Contact:", contact, "→ Number:", result)
        return result
    }

    // ✅ 监听账户注册状态，注册成功后刷新历史记录模型
    Connections {
        target: SipPhoneManager
        function onIsRegisteredChanged() {
            if (SipPhoneManager.isRegistered) {
                // 使用 Timer 延迟刷新，确保通话资源已完全清理
                refreshTimer.start()
            }
        }
    }

    // 延迟刷新定时器，避免访问刚结束的通话对象导致崩溃
    Timer {
        id: refreshTimer
        interval: 500
        repeat: false
        onTriggered: {
            try {
                console.log("📝 Refreshing call history model...")
                historyList.model = null

                var newModel = SipPhoneManager.getCallHistoryModel()
                if (newModel) {
                    console.log("   ✅ Model retrieved, rowCount:", newModel.rowCount())
                    historyList.model = newModel
                } else {
                    console.log("   ⚠️ Model is null, no call history available")
                }
            } catch (e) {
                console.error("❌ Error refreshing call history:", e)
            }
        }
    }

    // Inline RisipButton component
    component RisipButton: Button {
        id: control
        property color buttonColor: "#2c3e50"
        property color hoverColor: "#34495e"
        property color pressColor: "#2980b9"
        property color textColor: "#ffffff"
        property color borderColor: "#00d4ff"
        property int borderWidth: 2
        property int buttonRadius: 10
        property bool isHovered: false

        background: Rectangle {
            color: control.pressed ? control.pressColor : (control.isHovered ? control.hoverColor : control.buttonColor)
            radius: control.buttonRadius
            border.color: control.borderColor
            border.width: control.borderWidth
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        contentItem: Text {
            text: control.text
            font: control.font
            color: control.textColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        HoverHandler {
            onHoveredChanged: control.isHovered = hovered
        }
    }

    background: Rectangle {
        color: "transparent"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        // Toolbar with filters and clear button
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            RisipButton {
                id: allCallsBtn
                Layout.preferredWidth: 80
                Layout.preferredHeight: 40
                text: "全部"
                buttonColor: historyList.currentFilter === "all" ? "#2980b9" : "#34495e"

                onClicked: {
                    historyList.currentFilter = "all"
                }
            }

            RisipButton {
                id: incomingCallsBtn
                Layout.preferredWidth: 80
                Layout.preferredHeight: 40
                text: "接入"
                buttonColor: historyList.currentFilter === "incoming" ? "#2980b9" : "#34495e"

                onClicked: {
                    historyList.currentFilter = "incoming"
                }
            }

            RisipButton {
                id: missedCallsBtn
                Layout.preferredWidth: 80
                Layout.preferredHeight: 40
                text: "未接"
                buttonColor: historyList.currentFilter === "missed" ? "#2980b9" : "#34495e"

                onClicked: {
                    historyList.currentFilter = "missed"
                }
            }

            RisipButton {
                id: outgoingCallsBtn
                Layout.preferredWidth: 80
                Layout.preferredHeight: 40
                text: "已拨"
                buttonColor: historyList.currentFilter === "outgoing" ? "#2980b9" : "#34495e"

                onClicked: {
                    historyList.currentFilter = "outgoing"
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }

        // History list header
        Rectangle {
            Layout.fillWidth: true
            height: 40
            color: "#0f3460"
            radius: 5

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 15
                anchors.rightMargin: 15
                spacing: 10

                Text {
                    text: "类型"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#00d4ff"
                    Layout.preferredWidth: 50
                    Layout.minimumWidth: 50
                    Layout.maximumWidth: 50
                }

                Text {
                    text: "号码/姓名"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#00d4ff"
                    Layout.preferredWidth: 180
                    Layout.minimumWidth: 180
                    Layout.maximumWidth: 180
                }

                Text {
                    text: "时间"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#00d4ff"
                    Layout.preferredWidth: 110
                    Layout.minimumWidth: 110
                    Layout.maximumWidth: 110
                }

                Text {
                    text: "时长"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#00d4ff"
                    Layout.preferredWidth: 55
                    Layout.minimumWidth: 55
                    Layout.maximumWidth: 55
                    horizontalAlignment: Text.AlignRight
                }

                Text {
                    text: "操作"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#00d4ff"
                    Layout.preferredWidth: 130
                    Layout.minimumWidth: 130
                    Layout.maximumWidth: 130
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // History list
        ListView {
            id: historyList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 5

            property string currentFilter: "all"
            property int visibleCount: 0  // ✅ 实时统计可见记录数

            // ✅ 当过滤器改变时，重新统计
            onCurrentFilterChanged: {
                Qt.callLater(function() {
                    root.updateVisibleCount()
                })
            }

            // ✅ 当模型改变时，重新统计
            onModelChanged: {
                Qt.callLater(function() {
                    root.updateVisibleCount()
                })

                // 连接模型信号，监听数据变化
                if (model) {
                    model.rowsRemoved.connect(function() {
                        Qt.callLater(function() {
                            root.updateVisibleCount()
                        })
                    })
                    model.rowsInserted.connect(function() {
                        Qt.callLater(function() {
                            root.updateVisibleCount()
                        })
                    })
                    model.dataChanged.connect(function() {
                        Qt.callLater(function() {
                            root.updateVisibleCount()
                        })
                    })
                }
            }

            // ✅ Use call history model from Risip (initially get, then updates on registration)
            model: SipPhoneManager.getCallHistoryModel()

            delegate: Rectangle {
                width: historyList.width
                color: index % 2 === 0 ? "#1e2a3a" : "#16213e"
                radius: 5

                property bool isHovered: false
                property bool isMissedCall: model.callDirection === 1 && (model.callDuration || 0) < 1000
                property bool isIncomingCall: model.callDirection === 1 && (model.callDuration || 0) >= 1000

                // ✅ 过滤逻辑：根据 currentFilter 决定是否显示
                visible: {
                    if (historyList.currentFilter === "all") return true
                    if (historyList.currentFilter === "missed") return isMissedCall
                    if (historyList.currentFilter === "incoming") return isIncomingCall
                    if (historyList.currentFilter === "outgoing") return model.callDirection === 2
                    return true
                }

                // ✅ 动态高度：隐藏时高度为0，避免占用空间
                height: visible ? 60 : 0

                Rectangle {
                    anchors.fill: parent
                    color: "#00d4ff"
                    opacity: parent.isHovered ? 0.1 : 0
                    radius: 5

                    Behavior on opacity {
                        NumberAnimation { duration: 150 }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 15
                    anchors.rightMargin: 15
                    anchors.topMargin: 8
                    anchors.bottomMargin: 8
                    spacing: 10

                    // Call type icon - 固定50px
                    Text {
                        text: {
                            // ✅ Risip SDK enum: Incoming=1, Outgoing=2, Unknown=-1
                            if (model.callDirection === 2) return "📤"  // Outgoing (拨出)
                            if (model.callDirection === 1) {
                                // 区分已接和未接：时长<1秒视为未接
                                if ((model.callDuration || 0) < 1000) return "❌"  // Missed (未接)
                                return "📥"  // Incoming answered (已接)
                            }
                            return "📞"  // Unknown
                        }
                        font.pixelSize: 22
                        Layout.preferredWidth: 50
                        Layout.minimumWidth: 50
                        Layout.maximumWidth: 50
                        Layout.alignment: Qt.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    // Number and contact - 固定180px，超出省略
                    ColumnLayout {
                        Layout.preferredWidth: 180
                        Layout.minimumWidth: 180
                        Layout.maximumWidth: 180
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        Text {
                            text: model.callContact || "未知号码"
                            font.pixelSize: 15
                            font.bold: true
                            color: "#ffffff"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: {
                                if (model.callDirection === 2) return "拨出"
                                if (model.callDirection === 1) {
                                    return (model.callDuration || 0) < 1000 ? "未接" : "接入"
                                }
                                return "未知"
                            }
                            font.pixelSize: 11
                            color: "#95a5a6"
                        }
                    }

                    // Timestamp - 固定110px
                    ColumnLayout {
                        Layout.preferredWidth: 110
                        Layout.minimumWidth: 110
                        Layout.maximumWidth: 110
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        Text {
                            text: Qt.formatDateTime(model.callTimestamp, "yyyy-MM-dd")
                            font.pixelSize: 11
                            color: "#00d4ff"
                        }

                        Text {
                            text: Qt.formatDateTime(model.callTimestamp, "hh:mm:ss")
                            font.pixelSize: 11
                            color: "#95a5a6"
                        }
                    }

                    // Duration - 固定55px
                    Text {
                        text: formatDuration(model.callDuration || 0)
                        font.pixelSize: 13
                        color: "#ffffff"
                        Layout.preferredWidth: 55
                        Layout.minimumWidth: 55
                        Layout.maximumWidth: 55
                        Layout.alignment: Qt.AlignVCenter
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    // 语音回拨按钮
                    RisipButton {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 36
                        Layout.alignment: Qt.AlignVCenter
                        buttonRadius: 18
                        buttonColor: "#27ae60"
                        hoverColor: "#229954"
                        borderWidth: 1

                        contentItem: Text {
                            text: "📞"
                            font.pixelSize: 15
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            var cleanNumber = root.extractNumber(model.callContact || "")
                            console.log("语音回拨:", model.callContact, "→", cleanNumber)
                            root.callNumber(cleanNumber)
                        }
                    }

                    // 视频回拨按钮
                    RisipButton {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 36
                        Layout.alignment: Qt.AlignVCenter
                        buttonRadius: 18
                        buttonColor: "#3498db"
                        hoverColor: "#2980b9"
                        borderWidth: 1

                        contentItem: Text {
                            text: "📹"
                            font.pixelSize: 15
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            var cleanNumber = root.extractNumber(model.callContact || "")
                            console.log("视频回拨:", model.callContact, "→", cleanNumber)
                            root.callNumberVideo(cleanNumber)
                        }
                    }

                    // 删除按钮
                    RisipButton {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 36
                        Layout.alignment: Qt.AlignVCenter
                        buttonRadius: 18
                        buttonColor: "#e74c3c"
                        hoverColor: "#c0392b"
                        borderWidth: 1

                        contentItem: Text {
                            text: "🗑️"
                            font.pixelSize: 15
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            console.log("删除通话记录 #" + index)
                            root.deleteCallRecord(index)
                        }
                    }
                }

                HoverHandler {
                    onHoveredChanged: parent.isHovered = hovered
                }
            }

            // Custom scrollbar
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded

                contentItem: Rectangle {
                    implicitWidth: 8
                    radius: 4
                    color: parent.pressed ? "#00d4ff" : "#34495e"
                    opacity: parent.active ? 1.0 : 0.5
                }
            }
        }

        // Status bar
        Rectangle {
            Layout.fillWidth: true
            height: 30
            color: "#0f3460"
            radius: 5

            Text {
                anchors.centerIn: parent
                text: {
                    if (!historyList.model || historyList.model.rowCount() === 0) {
                        return "无通话记录"
                    }
                    var filterText = ""
                    if (historyList.currentFilter === "incoming") filterText = "接入: "
                    else if (historyList.currentFilter === "missed") filterText = "未接: "
                    else if (historyList.currentFilter === "outgoing") filterText = "已拨: "
                    return filterText + "显示 " + historyList.visibleCount + " 条通话记录"
                }
                font.pixelSize: 12
                color: "#95a5a6"
            }
        }
    }

    // Format duration from milliseconds to MM:SS
    // ✅ CRITICAL FIX: callDuration is in milliseconds, not seconds!
    function formatDuration(milliseconds) {
        // 即使为0也显示为 00:00，方便识别短时通话或未接通的通话
        var totalSeconds = Math.floor(milliseconds / 1000)  // Convert to seconds
        var mins = Math.floor(totalSeconds / 60)
        var secs = totalSeconds % 60
        return mins.toString().padStart(2, '0') + ":" + secs.toString().padStart(2, '0')
    }
}
