# DeviceMonitorPage 改进计划

基于对 9 个 QML 参考项目的深入分析，制定以下改进计划。

## 📋 改进优先级

### Phase 1: 配色和主题优化（立即执行）
- [ ] 创建统一的 Theme.qml 单例
- [ ] 替换所有硬编码颜色为主题颜色
- [ ] 优化对比度和可读性

### Phase 2: 动画增强（立即执行）
- [ ] 为所有数值变化添加平滑动画
- [ ] 优化过渡效果
- [ ] 添加交互反馈动画

### Phase 3: 控件升级（今天完成）
- [ ] 升级 LED 指示灯（添加发光效果）
- [ ] 改进按钮设计（Tesla 风格）
- [ ] 优化进度条（工业风格）

### Phase 4: 图表增强（明天完成）
- [ ] 添加实时折线图
- [ ] 改进趋势图显示
- [ ] 添加图表交互

---

## 🎨 配色方案（基于 Tesla + industrial-controls）

### 主色调
```qml
primary: "#17161c"              // 深黑背景
accent: "#439df3"               // 亮蓝强调
surface: "#1a1f2e"              // 表面灰
```

### 状态色
```qml
success: "#2bbe6d"              // 绿色（正常）
warning: "#ffa300"              // 橙色（警告）
error: "#e40b0b"                // 红色（错误）
info: "#19d6c4"                 // 青色（信息）
```

### 文字色
```qml
textPrimary: "#ffffff"          // 主要文字
textSecondary: "#5a6f8f"        // 次要文字
textDisabled: "#3a4f6f"         // 禁用文字
```

---

## 🔧 需要创建的新组件

### 1. Theme.qml（单例）
```qml
pragma Singleton
import QtQuick 2.15

QtObject {
    // 颜色
    readonly property color primary: "#17161c"
    readonly property color accent: "#439df3"
    readonly property color success: "#2bbe6d"
    readonly property color warning: "#ffa300"
    readonly property color error: "#e40b0b"
    readonly property color info: "#19d6c4"
    readonly property color surface: "#1a1f2e"
    readonly property color textPrimary: "#ffffff"
    readonly property color textSecondary: "#5a6f8f"

    // 尺寸
    readonly property int baseSize: 32
    readonly property int spacing: 16
    readonly property int radius: 8
    readonly property int borderWidth: 2

    // 动画
    readonly property int animationDuration: 300
    readonly property int animationEasing: Easing.OutCubic

    // 阴影
    readonly property int shadowSize: 8
    readonly property real shadowOpacity: 0.4
}
```

### 2. ModernButton.qml（Tesla 风格）
```qml
import QtQuick 2.15
import QtQuick.Controls 2.15

Button {
    id: control

    property color buttonColor: Theme.accent
    property color hoverColor: Qt.lighter(buttonColor, 1.2)
    property color pressColor: Qt.darker(buttonColor, 1.2)

    background: Rectangle {
        implicitWidth: 120
        implicitHeight: 40
        radius: Theme.radius
        color: control.pressed ? pressColor :
               control.hovered ? hoverColor : buttonColor

        Behavior on color {
            ColorAnimation {
                duration: Theme.animationDuration
                easing.type: Theme.animationEasing
            }
        }

        // 外层发光
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            color: "transparent"
            border.width: 1
            border.color: parent.color
            radius: parent.radius + 2
            opacity: control.hovered ? 0.5 : 0.2

            Behavior on opacity {
                NumberAnimation { duration: Theme.animationDuration }
            }
        }
    }

    contentItem: Text {
        text: control.text
        font.pixelSize: 14
        font.family: "Microsoft YaHei"
        color: Theme.textPrimary
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
```

### 3. GlowLed.qml（发光 LED）
```qml
import QtQuick 2.15
import Qt5Compat.GraphicalEffects

Rectangle {
    id: root

    property bool isActive: false
    property color activeColor: Theme.success
    property color inactiveColor: "#3a4f6f"
    property int glowRadius: 8

    width: 20
    height: 20
    radius: width / 2
    color: isActive ? activeColor : inactiveColor

    Behavior on color {
        ColorAnimation {
            duration: Theme.animationDuration
            easing.type: Theme.animationEasing
        }
    }

    // 发光效果
    layer.enabled: true
    layer.effect: Glow {
        radius: isActive ? root.glowRadius : 0
        samples: 10
        color: root.color

        Behavior on radius {
            NumberAnimation { duration: Theme.animationDuration }
        }
    }

    // 闪烁动画（可选）
    SequentialAnimation on opacity {
        running: isActive
        loops: Animation.Infinite
        NumberAnimation { from: 1.0; to: 0.6; duration: 800 }
        NumberAnimation { from: 0.6; to: 1.0; duration: 800 }
    }
}
```

### 4. ModernCard.qml（卡片容器）
```qml
import QtQuick 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root

    property alias content: contentLoader.sourceComponent
    property string title: ""
    property color cardColor: Theme.surface
    property color borderColor: Theme.accent

    color: cardColor
    radius: Theme.radius
    border.width: Theme.borderWidth
    border.color: borderColor

    // 渐变背景
    gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.lighter(cardColor, 1.1) }
        GradientStop { position: 1.0; color: cardColor }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10

        // 标题
        Text {
            text: root.title
            font.pixelSize: 16
            font.bold: true
            font.family: "Microsoft YaHei"
            color: Theme.accent
            visible: root.title !== ""
        }

        // 分隔线
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.accent
            opacity: 0.3
            visible: root.title !== ""
        }

        // 内容
        Loader {
            id: contentLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }

    // 角落装饰
    CornerDecoration {
        corner: "topLeft"
        lineLength: 15
        lineColor: borderColor
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 5
    }

    CornerDecoration {
        corner: "bottomRight"
        lineLength: 15
        lineColor: borderColor
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 5
    }
}
```

### 5. SmoothLineChart.qml（平滑折线图）
```qml
import QtQuick 2.15
import QtCharts 2.15

ChartView {
    id: chartView

    property var dataPoints: []
    property real minValue: 0
    property real maxValue: 100
    property color lineColor: Theme.accent

    legend.visible: false
    antialiasing: true
    backgroundColor: "transparent"

    margins {
        top: 0
        bottom: 0
        left: 0
        right: 0
    }

    ValueAxis {
        id: xAxis
        min: 0
        max: dataPoints.length - 1
        visible: false
    }

    ValueAxis {
        id: yAxis
        min: minValue
        max: maxValue
        visible: false
    }

    LineSeries {
        id: lineSeries
        axisX: xAxis
        axisY: yAxis
        color: lineColor
        width: 2

        Component.onCompleted: {
            updateData()
        }
    }

    function updateData() {
        lineSeries.clear()
        for (var i = 0; i < dataPoints.length; i++) {
            lineSeries.append(i, dataPoints[i])
        }
    }

    onDataPointsChanged: {
        updateData()
    }
}
```

---

## 📝 DeviceMonitorPage.qml 改进清单

### 左侧面板改进
- [ ] 使用 ModernCard 替换 Rectangle
- [ ] 使用 GlowLed 替换普通指示灯
- [ ] 添加数值变化动画
- [ ] 优化文字对比度

### 中央区域改进
- [ ] 优化 BeltConnectionDiagram 配色
- [ ] 添加更流畅的动画
- [ ] 改进连接线渐变效果
- [ ] 添加设备悬停高亮

### 右侧面板改进
- [ ] 使用 ModernButton 替换普通按钮
- [ ] 优化状态徽章设计
- [ ] 添加按钮点击反馈
- [ ] 改进设备列表样式

### 底部面板改进
- [ ] 使用 SmoothLineChart 替换 MiniTrendChart
- [ ] 添加图表交互
- [ ] 优化数据表格样式
- [ ] 改进报警列表显示

---

## 🚀 实施步骤

### Step 1: 创建主题系统（30分钟）
1. 创建 `Theme.qml` 单例
2. 创建 `qmldir` 文件注册单例
3. 在 DeviceMonitorPage 中导入主题

### Step 2: 创建新组件（1小时）
1. 创建 `ModernButton.qml`
2. 创建 `GlowLed.qml`
3. 创建 `ModernCard.qml`
4. 创建 `SmoothLineChart.qml`

### Step 3: 替换现有组件（1小时）
1. 替换所有硬编码颜色
2. 替换按钮为 ModernButton
3. 替换指示灯为 GlowLed
4. 替换卡片容器为 ModernCard

### Step 4: 优化动画（30分钟）
1. 为所有数值添加 Behavior
2. 优化过渡时间
3. 统一缓动函数

### Step 5: 测试和调整（30分钟）
1. 在 QDS 中预览
2. 在设备上测试
3. 调整细节

---

## 📊 预期效果

### 视觉改进
- ✅ 更专业的配色方案
- ✅ 更流畅的动画效果
- ✅ 更清晰的信息层级
- ✅ 更强的科技感

### 用户体验改进
- ✅ 更好的交互反馈
- ✅ 更直观的状态显示
- ✅ 更易读的数据展示
- ✅ 更舒适的视觉体验

### 代码质量改进
- ✅ 更好的代码复用
- ✅ 更易维护的结构
- ✅ 更统一的样式管理
- ✅ 更清晰的组件接口

---

**创建日期**: 2026-02-10
**预计完成时间**: 3-4 小时
**状态**: 待执行
