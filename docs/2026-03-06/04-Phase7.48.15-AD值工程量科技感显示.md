# Phase 7.48.15 — AD值和工程量科技感显示

**日期**：2026-03-06
**阶段**：Phase 7.48.15
**类型**：UI 优化
**用时**：20 分钟

---

## 一、问题描述

### 用户反馈
模拟量输入页面的 AD 值和工程量输入框太长，看起来像进度条，视觉效果不佳。

### 问题截图
用户提供的截图显示：
- AD 值和工程量使用长条形 Rectangle
- 宽度占满整个左侧区域
- 看起来像进度条，不像只读显示

---

## 二、设计方案

### 旧设计（Phase 7.48.13）
```qml
ColumnLayout {
    // AD值
    RowLayout {
        Text { text: "AD值:" }
        Rectangle {
            Layout.fillWidth: true  // ❌ 太宽，像进度条
            Layout.preferredHeight: 28
            Text { text: "0" }
        }
    }
    // 工程量
    RowLayout {
        Text { text: "工程量:" }
        Rectangle {
            Layout.fillWidth: true  // ❌ 太宽，像进度条
            Layout.preferredHeight: 28
            Text { text: "0.00 m/s" }
        }
    }
}
```

**问题**：
- 横向布局，标签在左，值在右
- Rectangle 宽度填满整个区域
- 看起来像进度条或输入框

### 新设计（Phase 7.48.15）
```qml
RowLayout {
    spacing: 12

    // AD值显示盒子
    Rectangle {
        Layout.preferredWidth: (parent.width - 12) / 2  // ✅ 固定宽度，紧凑
        Layout.preferredHeight: 55
        color: "#0A0E1A"
        border.color: "#00D9FF"

        Column {
            // 标签在上
            Text { text: "AD值"; color: "#64748B" }
            // 数值在下
            Text { text: "0"; color: "#00D9FF"; font.family: "Consolas" }
        }
    }

    // 工程量显示盒子
    Rectangle {
        Layout.preferredWidth: (parent.width - 12) / 2  // ✅ 固定宽度，紧凑
        Layout.preferredHeight: 55
        color: "#0A0E1A"
        border.color: "#00D9FF"

        Column {
            // 标签在上
            Text { text: "工程量"; color: "#64748B" }
            // 数值+单位在下
            Row {
                Text { text: "0.00"; color: "#00D9FF"; font.family: "Consolas" }
                Text { text: "m/s"; color: "#64748B" }
            }
        }
    }
}
```

**优点**：
- 两个并排的显示盒子，紧凑布局
- 标签在上，数值在下，纵向布局
- 固定宽度（各占一半），不会太长
- 青色边框 + 微光效果，科技感强
- 单位单独显示，动态变化

---

## 三、设计特点

### 3.1 科技感样式
- **深色背景**：`#0A0E1A`（深蓝黑色）
- **青色边框**：`#00D9FF`（Cyberpunk 主题色）
- **微光效果**：内部半透明边框（opacity: 0.15）
- **等宽字体**：Consolas（数字显示专用）

### 3.2 视觉层次
```
┌─────────────────────────────────────┐
│  AD值                    工程量      │  ← 小号灰色标签
│  12345                   2.50 m/s   │  ← 大号青色数值
└─────────────────────────────────────┘
```

- **标签**：11px，灰色（#64748B），微软雅黑
- **数值**：18px，青色（#00D9FF），Consolas，粗体
- **单位**：11px，灰色（#64748B），微软雅黑

### 3.3 紧凑布局
- **总高度**：55px（旧设计：28px × 2 + 8px spacing = 64px）
- **宽度**：各占一半（旧设计：填满整个区域）
- **间距**：12px（两个盒子之间）

---

## 四、修改文件

| 文件 | 修改内容 | 行数 |
|------|---------|------|
| `src/qml/components/device_info/pages/AnalogInputPage.qml` | 重构 AD 值和工程量显示（第 1611-1669 行） | 约 120 行 |
| `src/qml/components/device_info/pages/AnalogInputPage.qml` | 更新 `refreshADValue()` 函数（第 2240-2266 行） | 约 30 行 |

---

## 五、代码修改详情

### 5.1 显示组件重构（第 1611-1669 行）

**旧代码**（Phase 7.48.13）：
```qml
// 左侧：AD值和工程量显示
ColumnLayout {
    Layout.fillWidth: true
    spacing: 8

    // AD值
    RowLayout {
        spacing: 10
        Text {
            text: "AD值:"
            font.pixelSize: 14
            color: "#9E9E9E"
            Layout.preferredWidth: 60
        }
        Rectangle {
            Layout.fillWidth: true  // ❌ 太宽
            Layout.preferredHeight: 28
            color: "#1a1a1a"
            border.color: "#555555"
            border.width: 1
            radius: 3

            Text {
                id: adValueText
                anchors.centerIn: parent
                text: "0"
                font.pixelSize: 13
                color: "#00d4ff"
            }
        }
    }

    // 工程量（类似结构）
    RowLayout { ... }
}
```

**新代码**（Phase 7.48.15）：
```qml
// 左侧：AD值和工程量显示
// ✅ 2026-03-06 [Phase 7.48.15]: 重构为科技感紧凑显示（旧样式太长像进度条）
RowLayout {
    Layout.fillWidth: true
    spacing: 12

    // AD值显示盒子
    Rectangle {
        Layout.preferredWidth: (parent.width - 12) / 2  // ✅ 固定宽度
        Layout.preferredHeight: 55
        color: "#0A0E1A"
        border.color: "#00D9FF"
        border.width: 1
        radius: 4

        // 内部微光效果
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            color: "transparent"
            border.color: "#00D9FF"
            border.width: 1
            opacity: 0.15
            radius: 3
        }

        Column {
            anchors.centerIn: parent
            spacing: 2

            // 标签
            Text {
                text: "AD值"
                font.pixelSize: 11
                font.family: "Microsoft YaHei"
                color: "#64748B"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // 数值
            Text {
                id: adValueText
                text: "0"
                font.pixelSize: 18
                font.family: "Consolas"
                font.bold: true
                color: "#00D9FF"
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // 工程量显示盒子（类似结构，单位单独显示）
    Rectangle { ... }
}
```

### 5.2 数据更新函数修改（第 2240-2266 行）

**旧代码**：
```qml
engineeringValueText.text = engVal.toFixed(2) + " " + (item.unit || "")
```

**新代码**：
```qml
// ✅ 2026-03-06 [Phase 7.48.15]: 单位单独显示，不包含在text中
engineeringValueText.text = engVal.toFixed(2)
```

**原因**：新设计中单位通过 Row 布局单独显示，不需要拼接到数值文本中。

---

## 六、视觉对比

### 旧设计
```
┌────────────────────────────────────────────────────┐
│ AD值:    [                 0                    ]  │
│ 工程量:  [              0.00 m/s                ]  │
└────────────────────────────────────────────────────┘
```
- 横向布局，标签在左
- 长条形 Rectangle，像进度条
- 宽度填满整个区域

### 新设计
```
┌──────────────────────┬──────────────────────┐
│      AD值            │      工程量          │
│      12345           │      2.50 m/s       │
└──────────────────────┴──────────────────────┘
```
- 两个并排的盒子
- 标签在上，数值在下
- 固定宽度，紧凑布局
- 青色边框，科技感强

---

## 七、技术要点

### 7.1 动态单位显示

**实现方式**：
```qml
Text {
    text: {
        if (root.currentProtectionIndex >= 0 &&
            root.currentProtectionIndex < analogProtectionModel.count) {
            return analogProtectionModel.get(root.currentProtectionIndex).unit
        }
        return "m/s"
    }
    font.pixelSize: 11
    color: "#64748B"
}
```

**优点**：
- 单位根据当前保护项自动变化
- 不需要在 `refreshADValue()` 中拼接字符串
- 代码更简洁，逻辑更清晰

### 7.2 微光效果

**实现方式**：
```qml
Rectangle {
    anchors.fill: parent
    anchors.margins: 1
    color: "transparent"
    border.color: "#00D9FF"
    border.width: 1
    opacity: 0.15  // 半透明
    radius: 3
}
```

**效果**：
- 内部边框半透明，产生微光效果
- 增强科技感和立体感
- 不影响主要内容的可读性

### 7.3 等宽字体

**为什么使用 Consolas**：
- 数字宽度一致，不会跳动
- 适合显示数值和代码
- Windows 系统自带，兼容性好

---

## 八、完成总结

✅ **视觉优化**：从长条形进度条样式改为紧凑的科技感显示盒子
✅ **布局改进**：从横向布局改为纵向布局，标签在上，数值在下
✅ **宽度控制**：从填满整个区域改为固定宽度（各占一半）
✅ **科技感增强**：青色边框 + 微光效果 + 等宽字体
✅ **代码简化**：单位单独显示，不需要拼接字符串

**下一步**：编译部署到设备 185，查看实际显示效果。
