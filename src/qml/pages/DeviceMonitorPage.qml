import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components/device_monitor"
import "../Input1/Input1Content"
import "../theme"  // ✅ 2026-02-11 [Phase 7.45.23]: 导入 theme 模块（Theme, AnimatedCounter, CircularProgress）

// ✅ 2026-02-10 [Phase 7.45.9]: 设备监控页面 - 数字孪生布局
// 参考工业监控系统界面，添加 3D 数字孪生效果
// 布局：左侧信息面板 + 中央数字孪生区域 + 右侧控制面板 + 底部数据面板
// ✅ 2026-02-10 [Phase 7.45.13]: 应用 Theme 主题系统和现代化组件
Item {
    id: root

    // ✅ 2026-02-11 [Phase 7.45.25]: 移除固定尺寸，避免与anchors.fill冲突导致polish()循环
    // width: 1920  // ❌ 注释掉，使用anchors.fill自动填充
    // height: 1080  // ❌ 注释掉，使用anchors.fill自动填充
    anchors.fill: parent

    // ========== 背景 ==========
    Back {
        anchors.fill: parent
        z: 0
        enabled: false
    }

    // ========== 头部 ==========
    Item {
        id: headerContainer
        anchors.top: parent.top
        anchors.left: parent.left
        width: 1920
        height: 80
        clip: true
        z: 10

        transform: Scale {
            property real scaleFactor: root.width / 1920
            xScale: scaleFactor
            yScale: scaleFactor
            origin.x: 0
            origin.y: 0
        }

        Head {
            width: 1920
            height: 80
            currentPageIndex: 1
        }
    }

    // ========== 主内容区域（三栏布局）==========
    RowLayout {
        anchors.top: headerContainer.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: bottomPanel.top
        anchors.margins: 10
        spacing: 10

        // ========== 左侧信息面板 ==========
        Rectangle {
            Layout.preferredWidth: 280
            Layout.fillHeight: true
            color: Theme.primary
            border.width: Theme.borderWidth
            border.color: Theme.borderPrimary
            radius: Theme.radius
            opacity: 0.95

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 15

                // 设备总览（增强版）
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.lighter(Theme.surface, 1.1) }
                        GradientStop { position: 1.0; color: Theme.surface }
                    }
                    border.width: Theme.borderWidthThin
                    border.color: Theme.accent
                    radius: Theme.radiusSmall

                    // ✅ 角落装饰
                    CornerDecoration {
                        corner: "topLeft"
                        lineLength: 15
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 5
                    }

                    CornerDecoration {
                        corner: "bottomRight"
                        lineLength: 15
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: 5
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 5

                        Text {
                            text: "设备总览"
                            font.pixelSize: Theme.fontSizeLarge
                            font.bold: true
                            font.family: Theme.fontFamily
                            color: Theme.accent
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.accent
                            opacity: 0.3
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            rowSpacing: 8
                            columnSpacing: 10

                            Text {
                                text: "总设备:"
                                font.pixelSize: Theme.fontSizeNormal
                                font.family: Theme.fontFamily
                                color: Theme.textSecondary
                            }
                            AnimatedCounter {
                                targetValue: 12
                                decimals: 0
                                fontSize: Theme.fontSizeMedium
                                textColor: Theme.accent
                            }

                            Text {
                                text: "在线:"
                                font.pixelSize: Theme.fontSizeNormal
                                font.family: Theme.fontFamily
                                color: Theme.textSecondary
                            }
                            AnimatedCounter {
                                targetValue: 8
                                decimals: 0
                                fontSize: Theme.fontSizeMedium
                                textColor: Theme.success
                            }

                            Text {
                                text: "运行中:"
                                font.pixelSize: Theme.fontSizeNormal
                                font.family: Theme.fontFamily
                                color: Theme.textSecondary
                            }
                            AnimatedCounter {
                                targetValue: 5
                                decimals: 0
                                fontSize: Theme.fontSizeMedium
                                textColor: Theme.success
                            }
                        }
                    }
                }

                // 本机信息（使用 GlowLed）
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 100
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.lighter(Theme.success, 1.3) }
                        GradientStop { position: 1.0; color: Theme.darker(Theme.success, 1.5) }
                    }
                    border.width: Theme.borderWidth
                    border.color: Theme.success
                    radius: Theme.radiusSmall

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 5

                        RowLayout {
                            spacing: 5

                            // ✅ 使用 GlowLed 替换普通指示灯
                            GlowLed {
                                width: 12
                                height: 12
                                isActive: true
                                activeColor: Theme.success
                                blinkEnabled: true
                            }

                            Text {
                                text: "本机设备"
                                font.pixelSize: Theme.fontSizeMedium
                                font.bold: true
                                font.family: Theme.fontFamily
                                color: Theme.success
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.success
                            opacity: 0.3
                        }

                        Text {
                            text: "1号皮带"
                            font.pixelSize: Theme.fontSizeLarge
                            font.bold: true
                            font.family: Theme.fontFamily
                            color: Theme.success
                        }

                        Text {
                            text: "状态: 运行中"
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            color: Theme.success
                        }
                    }
                }

                // 关键指标（增强版）
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 280
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.lighter(Theme.surface, 1.1) }
                        GradientStop { position: 1.0; color: Theme.surface }
                    }
                    border.width: Theme.borderWidthThin
                    border.color: Theme.accent
                    radius: Theme.radiusSmall

                    // ✅ 角落装饰
                    CornerDecoration {
                        corner: "topRight"
                        lineLength: 15
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 5
                    }

                    CornerDecoration {
                        corner: "bottomLeft"
                        lineLength: 15
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.margins: 5
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        Text {
                            text: "关键指标"
                            font.pixelSize: Theme.fontSizeMedium
                            font.bold: true
                            font.family: Theme.fontFamily
                            color: Theme.accent
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.accent
                            opacity: 0.3
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            rowSpacing: 6
                            columnSpacing: 8

                            Text {
                                text: "总产量:"
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: Theme.fontFamily
                                color: Theme.textSecondary
                            }
                            AnimatedCounter {
                                targetValue: 5863
                                decimals: 0
                                suffix: " t"
                                fontSize: Theme.fontSizeMedium
                                textColor: Theme.accent
                            }

                            Text {
                                text: "运行时长:"
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: Theme.fontFamily
                                color: Theme.textSecondary
                            }
                            Text {
                                text: "127h 56m"
                                font.pixelSize: Theme.fontSizeMedium
                                font.bold: true
                                font.family: "Consolas"
                                color: Theme.accent
                            }

                            Text {
                                text: "效率:"
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: Theme.fontFamily
                                color: Theme.textSecondary
                            }
                            AnimatedCounter {
                                targetValue: 100
                                decimals: 0
                                suffix: "%"
                                fontSize: Theme.fontSizeMedium
                                textColor: Theme.success
                            }
                        }

                        // ✅ 圆形进度指示器
                        CircularProgress {
                            Layout.alignment: Qt.AlignHCenter
                            targetProgress: 1.0
                            size: 90
                            lineWidth: 8
                            startColor: Theme.accent
                            endColor: Theme.success
                        }

                        // ✅ 迷你趋势图
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            Text {
                                text: "产量趋势"
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: Theme.fontFamily
                                color: Theme.textSecondary
                            }

                            MiniTrendChart {
                                id: productionTrend
                                Layout.fillWidth: true
                                height: 50
                                dataPoints: [45, 48, 52, 50, 55, 58, 60, 62, 65, 63, 68, 70, 72, 75, 78, 80, 82, 85, 88, 90]
                                minValue: 0
                                maxValue: 100
                                lineColor: Theme.accent
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        // ========== 中央数字孪生区域 ==========
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.primary
            border.width: Theme.borderWidth
            border.color: Theme.accent
            radius: Theme.radius
            opacity: 0.95

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10

                // 标题
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "【皮带输送系统 - 数字孪生】"
                        font.pixelSize: Theme.fontSizeXLarge
                        font.bold: true
                        font.family: Theme.fontFamily
                        color: Theme.accent

                        SequentialAnimation on opacity {
                            running: true
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.7; duration: 1500 }
                            NumberAnimation { from: 0.7; to: 1.0; duration: 1500 }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "更新: " + Qt.formatTime(new Date(), "hh:mm:ss")
                        font.pixelSize: Theme.fontSizeNormal
                        font.family: "Consolas"
                        color: Theme.textSecondary
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 2
                    color: Theme.accent
                    opacity: 0.3
                }

                // 皮带连接关系图
                BeltConnectionDiagram {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }

        // ========== 右侧控制面板 ==========
        Rectangle {
            Layout.preferredWidth: 280
            Layout.fillHeight: true
            color: Theme.primary
            border.width: Theme.borderWidth
            border.color: Theme.accent
            radius: Theme.radius
            opacity: 0.95

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 15

                // 快速操作（增强版）
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.lighter(Theme.surface, 1.1) }
                        GradientStop { position: 1.0; color: Theme.surface }
                    }
                    border.width: Theme.borderWidthThin
                    border.color: Theme.accent
                    radius: Theme.radiusSmall

                    // ✅ 角落装饰
                    CornerDecoration {
                        corner: "topLeft"
                        lineLength: 15
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 5
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        Text {
                            text: "快速操作"
                            font.pixelSize: Theme.fontSizeMedium
                            font.bold: true
                            font.family: Theme.fontFamily
                            color: Theme.accent
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.accent
                            opacity: 0.3
                        }

                        // ✅ 系统状态徽章
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            StatusBadge {
                                Layout.fillWidth: true
                                statusText: "系统正常"
                                statusIcon: "●"
                                statusColor: Theme.success
                            }

                            StatusBadge {
                                Layout.fillWidth: true
                                statusText: "MQTT连接"
                                statusIcon: "◉"
                                statusColor: Theme.accent
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            rowSpacing: 8
                            columnSpacing: 8

                            // ✅ 使用 ModernButton 替换普通按钮
                            ModernButton {
                                text: "全部启动"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 35
                                buttonColor: Theme.success
                            }

                            ModernButton {
                                text: "全部停止"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 35
                                buttonColor: Theme.error
                            }
                        }
                    }
                }

                // 设备列表
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.lighter(Theme.surface, 1.1) }
                        GradientStop { position: 1.0; color: Theme.surface }
                    }
                    border.width: Theme.borderWidthThin
                    border.color: Theme.accent
                    radius: Theme.radiusSmall

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        Text {
                            text: "设备列表"
                            font.pixelSize: Theme.fontSizeMedium
                            font.bold: true
                            font.family: Theme.fontFamily
                            color: Theme.accent
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.accent
                            opacity: 0.3
                        }

                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            ListView {
                                model: 12
                                spacing: 5

                                delegate: Rectangle {
                                    width: parent.width
                                    height: 40
                                    color: index === 0 ? Theme.darker(Theme.success, 1.8) : Theme.surface
                                    border.width: Theme.borderWidthThin
                                    border.color: index === 0 ? Theme.success : Theme.borderSecondary
                                    radius: Theme.radiusSmall

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 8

                                        // ✅ 使用 GlowLed 替换普通指示灯
                                        GlowLed {
                                            width: 8
                                            height: 8
                                            isActive: index < 8
                                            activeColor: Theme.success
                                            inactiveColor: Theme.error
                                        }

                                        Text {
                                            text: index < 8 ? ((index + 1) + "号皮带") :
                                                  (index === 8 ? "转载机" :
                                                   index === 9 ? "破碎机" :
                                                   index === 10 ? "前刮板" : "后刮板")
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.family: Theme.fontFamily
                                            color: index === 0 ? Theme.success : Theme.accent
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: index < 5 ? "运行" : "停止"
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.family: Theme.fontFamily
                                            color: index < 5 ? Theme.success : Theme.error
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor

                                        onEntered: {
                                            parent.scale = 1.05
                                        }

                                        onExited: {
                                            parent.scale = 1.0
                                        }
                                    }

                                    Behavior on scale {
                                        NumberAnimation { duration: 150 }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ========== 底部数据面板 ==========
    Rectangle {
        id: bottomPanel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        height: 200
        color: Theme.primary
        border.width: Theme.borderWidth
        border.color: Theme.accent
        radius: Theme.radius
        opacity: 0.95

        RowLayout {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 15

            // 实时数据表格
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.lighter(Theme.surface, 1.1) }
                    GradientStop { position: 1.0; color: Theme.surface }
                }
                border.width: Theme.borderWidthThin
                border.color: Theme.accent
                radius: Theme.radiusSmall

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 5

                    Text {
                        text: "实时运行数据"
                        font.pixelSize: Theme.fontSizeMedium
                        font.bold: true
                        font.family: Theme.fontFamily
                        color: Theme.accent
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.accent
                        opacity: 0.3
                    }

                    // 表格头
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "设备"
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            color: Theme.textSecondary
                            Layout.preferredWidth: 80
                        }
                        Text {
                            text: "速度"
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            color: Theme.textSecondary
                            Layout.preferredWidth: 60
                        }
                        Text {
                            text: "电流"
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            color: Theme.textSecondary
                            Layout.preferredWidth: 60
                        }
                        Text {
                            text: "温度"
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            color: Theme.textSecondary
                            Layout.preferredWidth: 60
                        }
                        Text {
                            text: "状态"
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            color: Theme.textSecondary
                            Layout.preferredWidth: 60
                        }
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        ListView {
                            model: 5
                            spacing: 3

                            delegate: RowLayout {
                                width: parent.width
                                spacing: 10

                                Text {
                                    text: (index + 1) + "号皮带"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontFamily
                                    color: Theme.accent
                                    Layout.preferredWidth: 80
                                }
                                Text {
                                    text: (1.2 + index * 0.1).toFixed(1) + " m/s"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: "Consolas"
                                    color: Theme.success
                                    Layout.preferredWidth: 60
                                }
                                Text {
                                    text: (45 + index * 5) + " A"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: "Consolas"
                                    color: Theme.warning
                                    Layout.preferredWidth: 60
                                }
                                Text {
                                    text: (35 + index * 2) + " °C"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: "Consolas"
                                    color: Theme.accent
                                    Layout.preferredWidth: 60
                                }
                                Text {
                                    text: "运行中"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontFamily
                                    color: Theme.success
                                    Layout.preferredWidth: 60
                                }
                            }
                        }
                    }
                }
            }

            // 故障统计
            Rectangle {
                Layout.preferredWidth: 250
                Layout.fillHeight: true
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.lighter(Theme.surface, 1.1) }
                    GradientStop { position: 1.0; color: Theme.surface }
                }
                border.width: Theme.borderWidthThin
                border.color: Theme.accent
                radius: Theme.radiusSmall

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 5

                    Text {
                        text: "故障统计"
                        font.pixelSize: Theme.fontSizeMedium
                        font.bold: true
                        font.family: Theme.fontFamily
                        color: Theme.accent
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.accent
                        opacity: 0.3
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 6
                        columnSpacing: 10

                        Text {
                            text: "今日故障:"
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            color: Theme.textSecondary
                        }
                        Text {
                            text: "0"
                            font.pixelSize: Theme.fontSizeMedium
                            font.bold: true
                            font.family: "Consolas"
                            color: Theme.success
                        }

                        Text {
                            text: "本周故障:"
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            color: Theme.textSecondary
                        }
                        Text {
                            text: "2"
                            font.pixelSize: Theme.fontSizeMedium
                            font.bold: true
                            font.family: "Consolas"
                            color: Theme.warning
                        }

                        Text {
                            text: "本月故障:"
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            color: Theme.textSecondary
                        }
                        Text {
                            text: "5"
                            font.pixelSize: Theme.fontSizeMedium
                            font.bold: true
                            font.family: "Consolas"
                            color: Theme.error
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Text {
                        text: "平均故障间隔: 127h"
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                        color: Theme.textSecondary
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            // 报警信息
            Rectangle {
                Layout.preferredWidth: 300
                Layout.fillHeight: true
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.lighter(Theme.surface, 1.1) }
                    GradientStop { position: 1.0; color: Theme.surface }
                }
                border.width: Theme.borderWidthThin
                border.color: Theme.accent
                radius: Theme.radiusSmall

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 5

                    Text {
                        text: "最近报警"
                        font.pixelSize: Theme.fontSizeMedium
                        font.bold: true
                        font.family: Theme.fontFamily
                        color: Theme.accent
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.accent
                        opacity: 0.3
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        ListView {
                            model: 3
                            spacing: 5

                            delegate: Rectangle {
                                width: parent.width
                                height: 40
                                color: Theme.surface
                                border.width: Theme.borderWidthThin
                                border.color: Theme.borderSecondary
                                radius: Theme.radiusSmall

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 2

                                    Text {
                                        text: index === 0 ? "3号皮带速度异常" :
                                              index === 1 ? "5号皮带温度过高" : "转载机电流波动"
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.family: Theme.fontFamily
                                        color: Theme.warning
                                    }

                                    Text {
                                        text: "2026-02-10 " + (15 - index) + ":30:00"
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.family: "Consolas"
                                        color: Theme.textSecondary
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        console.log("✅ [DeviceMonitorPage] 数字孪生设备监控页面已加载")
    }
}
