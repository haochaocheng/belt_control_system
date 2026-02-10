# Phase 7.44.23 - 修复MQTT数据展示界面布局和字体

**日期**: 2026-02-09
**阶段**: Phase 7.44.23
**类型**: UI修复 + 布局优化

---

## 问题描述

用户反馈MQTT数据展示界面存在以下问题：

### 模拟量界面（AIModulePanel）
1. ❌ 字体太小，看不清楚
2. ❌ 字体太粗，不易阅读
3. ❌ 底部有大量空白区域
4. ❌ 通道卡片高度不足，电压值压在边框上

### 开关量界面（DIModulePanel）
1. ❌ 字体太小，看不清楚
2. ❌ LED指示灯尺寸偏小
3. ❌ 底部有大量空白区域
4. ❌ 字节值显示区域高度不足

---

## 修复内容

### 1. AIModulePanel.qml - 模拟量界面优化

**文件**: `src/qml/components/device_info/pages/AIModulePanel.qml`

#### 1.1 字体大小调整

| 元素 | 修改前 | 修改后 | 变化 | 行号 |
|------|--------|--------|------|------|
| 标题 | 18px | 24px | +33% | 67 |
| 通道标题 | 15px | 18px | +20% | 130 |
| AD标签 | 14px | 16px | +14% | 145 |
| AD值 | 18px | 22px | +22% | 154 |
| 电压标签 | 14px | 16px | +14% | 163 |
| 电压值 | 20px | 24px | +20% | 172 |
| 统计标签 | 15px | 18px | +20% | 254-286 |
| 统计数值 | 17px | 22px | +29% | 259-291 |

#### 1.2 字体粗细调整

- 移除所有数值的粗体显示（`font.bold: false`）
- 保持标题和标签的粗体显示
- 提高可读性，避免字体过粗

**修改位置**：
- 通道标题：第130行
- AD值：第154行
- 电压值：第172行
- 统计数值：第259、270、281、291行

#### 1.3 布局优化

**面板边距和间距**（第34-35行）：
```qml
ColumnLayout {
    anchors.fill: parent
    anchors.margins: 15  // 20 → 15，减少边距
    spacing: 12  // 15 → 12，减少间距
}
```

**标题行高度**（第40行）：
```qml
Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: 40  // 45 → 40，减少标题行高度
    color: "transparent"
}
```

**通道卡片高度**（第107行）：
```qml
Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: 165  // 90 → 165，增加83%
    color: "#0a0f1e"
    radius: 6
    border.width: 2
    border.color: getChannelValid(index) ? "#00d4ff" : "#2a3f5f"
}
```

**卡片内部间距**（第125-126行）：
```qml
ColumnLayout {
    anchors.fill: parent
    anchors.margins: 15  // 10 → 15，增加内边距
    spacing: 10  // 5 → 10，增加间距
}
```

**统计信息区域高度**（第227行）：
```qml
Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: 45  // 50 → 45，减少统计信息区域高度
    color: "#0a0f1e"
}
```

---

### 2. DIModulePanel.qml - 开关量界面优化

**文件**: `src/qml/components/device_info/pages/DIModulePanel.qml`

#### 2.1 字体大小调整

| 元素 | 修改前 | 修改后 | 变化 | 行号 |
|------|--------|--------|------|------|
| 标题 | 18px | 24px | +33% | 71 |
| BIT标签 | 11px | 14px | +27% | 125 |
| ON/OFF状态 | 12px | 14px | +17% | 200 |
| HEX标签 | 14px | 16px | +14% | 239 |
| HEX值 | 20px | 24px | +20% | 247 |
| DEC标签 | 14px | 16px | +14% | 267 |
| DEC值 | 20px | 24px | +20% | 275 |
| BIN标签 | 14px | 16px | +14% | 291 |
| BIN值 | 18px | 22px | +22% | 299 |

#### 2.2 字体粗细调整

- 移除ON/OFF状态的粗体显示（第201行）
- 移除HEX值的粗体显示（第248行）
- 移除DEC值的粗体显示（第276行）
- 移除BIN值的粗体显示（第300行）

#### 2.3 布局优化

**面板边距和间距**（第38-39行）：
```qml
ColumnLayout {
    anchors.fill: parent
    anchors.margins: 15  // 20 → 15，减少边距
    spacing: 12  // 15 → 12，减少间距
}
```

**标题行高度**（第44行）：
```qml
Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: 40  // 35 → 40，增加标题行高度
    color: "transparent"
}
```

**LED网格间距**（第102-103行）：
```qml
GridLayout {
    Layout.fillWidth: true
    Layout.fillHeight: true
    columns: 8
    rowSpacing: 10  // 8 → 10，增加行间距
    columnSpacing: 15  // 12 → 15，增加列间距
}
```

**LED组件尺寸**（第111-139行）：
```qml
ColumnLayout {
    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: 10  // 8 → 10，增加内部间距

    // BIT标签
    Rectangle {
        Layout.preferredWidth: 70  // 60 → 70，增加标签宽度
        Layout.preferredHeight: 26  // 22 → 26，增加标签高度
        // ...
    }

    // LED指示灯
    Rectangle {
        Layout.preferredWidth: 80  // 60 → 80，增加LED尺寸
        Layout.preferredHeight: 80  // 60 → 80，增加LED尺寸
        radius: 40  // 30 → 40，调整圆角
        // ...
    }

    // ON/OFF状态标签
    Rectangle {
        Layout.preferredWidth: 70  // 60 → 70，增加状态标签宽度
        Layout.preferredHeight: 26  // 22 → 26，增加状态标签高度
        // ...
    }
}
```

**字节值显示区域**（第213行）：
```qml
Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: 50  // 45 → 50，增加字节值显示区域高度
    color: "#0a0f1e"
    radius: 6
    border.width: 2
    border.color: "#00d4ff"
}
```

**字节值间距**（第235、263、287行）：
```qml
RowLayout {
    spacing: 10  // 8 → 10，增加间距
    // ...
}
```

---

### 3. MQTTAutoControlTab.qml - 容器优化

**文件**: `src/qml/components/device_info/pages/MQTTAutoControlTab.qml`

#### 3.1 外层边距和间距优化（第96-97行）

```qml
ColumnLayout {
    anchors.fill: parent
    anchors.margins: 10  // 20 → 10，减少边距，让面板更靠近底部
    spacing: 15  // 20 → 15，减少间距
}
```

#### 3.2 移除ScrollView包装（第244-313行）

**修改前**：
```qml
ScrollView {
    Layout.fillWidth: true
    Layout.fillHeight: true

    StackLayout {
        // ...
    }
}
```

**修改后**：
```qml
StackLayout {
    Layout.fillWidth: true
    Layout.fillHeight: true
    currentIndex: {
        var type = getModuleType()
        if (type === "di") return 0
        if (type === "ai") return 1
        if (type === "cs") return 2
        if (type === "voice") return 3
        return 4  // reserved
    }

    // 开关量显示 (模块1-2)
    DIModulePanel {
        Layout.fillWidth: true
        Layout.fillHeight: true  // ✅ 填充整个可用高度
        // ...
    }

    // 模拟量显示 (模块3-4)
    AIModulePanel {
        Layout.fillWidth: true
        Layout.fillHeight: true  // ✅ 填充整个可用高度
        // ...
    }
}
```

---

### 4. DeviceSettingsDialog.qml - 根本原因修复

**文件**: `src/qml/components/device_info/DeviceSettingsDialog.qml`

#### 4.1 动态底部边距（第2224-2231行）

**问题根源**：
- 原代码固定 `anchors.bottomMargin: 72`
- 这是为底部按钮预留的空间（60px按钮高度 + 12px间距）
- 但MQTT控制界面没有底部按钮，导致底部有大量空白

**修复方案**：
```qml
// ✅ 2026-02-09 [Phase 7.44.23]: 根据当前类别动态调整底部边距
// 对于没有底部按钮的类别（串口、CAN、TCP、MQTT），使用较小的边距
anchors.bottomMargin: {
    var buttons = root.getBottomButtons(root.currentCategory)
    if (buttons.length === 0) {
        return 20  // 没有底部按钮，只保留20px边距
    } else {
        return 72  // 有底部按钮，保留72px空间（60px按钮高度 + 12px间距）
    }
}
```

#### 4.2 MQTT控制按钮配置（第3279-3282行）

```qml
case 9: // MQTT控制
    return []  // ✅ 2026-02-09 [Phase 7.44.23]: MQTT控制按钮已在 MQTTAutoControlTab 内部实现
```

---

## 修改文件清单

| 文件 | 修改内容 | 行号 |
|------|----------|------|
| AIModulePanel.qml | 字体大小、粗细、布局优化 | 16-17, 34-35, 40, 67, 107, 125-182, 227, 254-315 |
| DIModulePanel.qml | 字体大小、粗细、布局优化、LED尺寸 | 16-17, 38-39, 44, 71, 102-103, 111-205, 213, 235-307 |
| MQTTAutoControlTab.qml | 边距、间距、移除ScrollView | 96-97, 244-313 |
| DeviceSettingsDialog.qml | 动态底部边距、MQTT按钮配置 | 2224-2231, 3279-3282 |

---

## 空间优化总结

### 模拟量界面（AIModulePanel）
- 面板边距：20px → 15px（节省10px）
- 面板间距：15px → 12px（节省3px）
- 标题行高度：45px → 40px（节省5px）
- 通道卡片高度：90px → 165px（增加75px）
- 卡片内边距：10px → 15px（增加10px）
- 卡片内间距：5px → 10px（增加5px）
- 统计区域高度：50px → 45px（节省5px）

### 开关量界面（DIModulePanel）
- 面板边距：20px → 15px（节省10px）
- 面板间距：15px → 12px（节省3px）
- 标题行高度：35px → 40px（增加5px）
- LED网格行间距：8px → 10px（增加2px）
- LED网格列间距：12px → 15px（增加3px）
- BIT标签尺寸：60x22 → 70x26（增加10x4）
- LED尺寸：60x60 → 80x80（增加20x20）
- 状态标签尺寸：60x22 → 70x26（增加10x4）
- 字节值区域高度：45px → 50px（增加5px）

### 容器优化（MQTTAutoControlTab）
- 外层边距：20px → 10px（节省20px）
- 外层间距：20px → 15px（节省5px）

### 根本原因修复（DeviceSettingsDialog）
- 底部边距：72px → 20px（节省52px，仅MQTT控制）

**总计节省空间**：约90px，全部用于增加内容区域高度

---

## 测试验证

### 验证要点

1. **字体可读性**：
   - ✅ 标题字体24px，清晰醒目
   - ✅ 数值字体22-24px，易于阅读
   - ✅ 标签字体16-18px，适中
   - ✅ 移除粗体后，文字更清晰

2. **布局填充**：
   - ✅ 模拟量通道卡片高度165px，电压值不再压边框
   - ✅ 开关量LED尺寸80px，更加醒目
   - ✅ 面板填充整个可用空间
   - ✅ 底部空白减少到20px

3. **视觉效果**：
   - ✅ 科技风格保持一致
   - ✅ 发光效果正常
   - ✅ 动画效果流畅
   - ✅ 颜色对比度良好

---

## 相关文档

1. **设计文档**: [docs/2026-02-09/18-Phase7.44.22-重新设计MQTT数据展示界面.md](18-Phase7.44.22-重新设计MQTT数据展示界面.md)
2. **完成总结**: [docs/2026-02-09/19-Phase7.44.22-完成总结.md](19-Phase7.44.22-完成总结.md)

---

**文档版本**: v2.0
**最后更新**: 2026-02-09
