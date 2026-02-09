# Phase 7.44.23 - 修复MQTT数据展示界面布局和字体

**日期**: 2026-02-09
**阶段**: Phase 7.44.23
**类型**: UI修复 + 布局优化

---

## 问题描述

用户反馈MQTT数据展示界面存在以下问题：

1. ❌ 字体太粗，不易阅读
2. ❌ 文字太小，看不清楚
3. ❌ "AD"和"电压"标签对齐不正确
4. ❌ 底部有多余的3个按钮（添加逻辑、删除逻辑、测试逻辑）
5. ❌ 面板距离底部有很大空白，统计信息区域没有靠近底部

---

## 修复内容

### 1. AIModulePanel.qml - 字体和对齐优化

**文件**: `src/qml/components/device_info/pages/AIModulePanel.qml`

#### 1.1 字体大小调整

| 元素 | 修改前 | 修改后 | 说明 |
|------|--------|--------|------|
| 通道标题 | 13px | 15px | 增加可读性 |
| "AD:" 标签 | 11px | 14px | 增加可读性 |
| AD值 | 15px | 18px | 增加可读性 |
| "电压:" 标签 | 11px | 14px | 增加可读性 |
| 电压值 | 17px | 20px | 增加可读性 |
| 统计信息标签 | 13px | 15px | 增加可读性 |
| 统计信息数值 | 15px | 17px | 增加可读性 |

#### 1.2 字体粗细调整

- 所有数值显示的 `font.bold: true` 改为 `font.bold: false`
- 保持标题和标签的粗体显示

#### 1.3 对齐修复

为所有Text组件添加 `verticalAlignment: Text.AlignVCenter`，确保"AD:"和"电压:"标签与数值垂直居中对齐。

**代码示例**：
```qml
Text {
    text: "AD:"
    font.pixelSize: 14  // 11 → 14
    font.family: "Consolas"
    color: "#5a6f8f"
    verticalAlignment: Text.AlignVCenter  // ✅ 垂直居中对齐
}

Text {
    text: getChannelADValue(index).toString()
    font.pixelSize: 18  // 15 → 18
    font.bold: false  // true → false
    font.family: "Consolas"
    color: "#00d4ff"
    Layout.fillWidth: true
    verticalAlignment: Text.AlignVCenter  // ✅ 垂直居中对齐
}
```

#### 1.4 布局优化

**移除固定高度**：
```qml
Rectangle {
    id: root
    color: "#1a1f2e"
    radius: 8
    border.width: 2
    border.color: "#00d4ff"
    // ✅ 2026-02-09 [Phase 7.44.23]: 移除固定高度，让面板填充整个可用空间
    // height: 300  // 注释掉固定高度
```

**通道数据区域填充剩余空间**：
```qml
GridLayout {
    Layout.fillWidth: true
    Layout.fillHeight: true  // ✅ 填充剩余空间
    columns: 4
    rowSpacing: 10
    columnSpacing: 10
```

### 2. DIModulePanel.qml - 布局优化

**文件**: `src/qml/components/device_info/pages/DIModulePanel.qml`

**移除固定高度**：
```qml
Rectangle {
    id: root
    color: "#1a1f2e"  // 深色背景
    radius: 8
    border.width: 2
    border.color: "#00d4ff"  // 青色发光边框
    // ✅ 2026-02-09 [Phase 7.44.23]: 移除固定高度，让面板填充整个可用空间
    // height: 220  // 注释掉固定高度
```

### 3. MQTTAutoControlTab.qml - 移除ScrollView

**文件**: `src/qml/components/device_info/pages/MQTTAutoControlTab.qml`

**问题根源**：
- ScrollView 包裹了 StackLayout，导致布局计算复杂
- ScrollView 的 contentHeight 和 StackLayout 的 height 之间存在冲突
- 即使设置了各种高度属性，面板仍然无法正确填充到底部

**修复方案**：
- **移除 ScrollView**，直接使用 StackLayout
- 每个面板内部已经有自己的布局管理（ColumnLayout with anchors.fill）
- 如果内容过多，面板内部可以自行添加 ScrollView

**修改前**：
```qml
ScrollView {
    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true

    StackLayout {
        width: parent.width
        height: parent.height
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

    // ... 其他模块面板
}
```

### 4. DeviceSettingsDialog.qml - 移除多余按钮

**文件**: `src/qml/components/device_info/DeviceSettingsDialog.qml`

**修复内容**：
- 将 case 9（MQTT控制）的按钮从 `["添加逻辑", "删除逻辑", "测试逻辑"]` 改为 `[]`
- 将 case 10（逻辑控制）保留 `["添加逻辑", "删除逻辑", "测试逻辑"]`

**代码**：
```qml
function getBottomButtons(categoryIndex) {
    switch(categoryIndex) {
    // ...
    case 8: // TCP控制
        return []  // ✅ 2026-02-08 [Phase 7.42]: TCP控制按钮已在 TCPControlPage 内部实现
    case 9: // MQTT控制
        return []  // ✅ 2026-02-09 [Phase 7.44.23]: MQTT控制按钮已在 MQTTAutoControlTab 内部实现
    case 10: // 逻辑控制
        return ["添加逻辑", "删除逻辑", "测试逻辑"]
    default:
        return []
    }
}
```

---

## 修改的文件

1. **src/qml/components/device_info/pages/AIModulePanel.qml**
   - 行16-17：移除固定高度
   - 行34-35：减少面板边距和间距（20→15px, 15→12px）
   - 行40：减少标题行高度（45→40px）
   - 行67：增大标题字体（18→24px）
   - 行97：通道数据显示区域填充剩余空间
   - 行107：增加通道卡片高度（90→165px，增加83%）
   - 行125-126：增加卡片内边距和间距（10→15px, 5→10px）
   - 行130-182：调整字体大小和粗细，移除粗体，添加垂直居中对齐
     - 通道标题：15→18px，移除粗体
     - AD标签：11→16px
     - AD值：15→22px，移除粗体
     - 电压标签：11→16px
     - 电压值：17→24px，移除粗体
   - 行227：减少统计信息区域高度（50→45px）
   - 行254-315：调整统计信息字体大小和粗细
     - 标签：13→18px
     - 数值：15→22px，移除粗体

2. **src/qml/components/device_info/pages/DIModulePanel.qml**
   - 行16-17：移除固定高度

3. **src/qml/components/device_info/pages/MQTTAutoControlTab.qml**
   - 行96-97：减少外层边距和间距（20→10px, 20→15px）
   - 行244-254：移除 ScrollView，直接使用 StackLayout
   - 行258：DIModulePanel 添加 `Layout.fillHeight: true`
   - 行275：AIModulePanel 添加 `Layout.fillHeight: true`
   - 行292：CSModulePanel 添加 `Layout.fillHeight: true`
   - 行300：VoiceModulePanel 添加 `Layout.fillHeight: true`
   - 行308：ReservedModulePanel 添加 `Layout.fillHeight: true`

4. **src/qml/components/device_info/DeviceSettingsDialog.qml**
   - 行2224-2231：动态调整底部边距（根据是否有底部按钮：72px或20px）
   - 行3279-3282：修复MQTT控制按钮配置（返回空数组）

---

## 测试结果

### 预期效果

- ✅ 字体大小适中，易于阅读
- ✅ 字体不再太粗
- ✅ "AD"和"电压"标签垂直居中对齐
- ✅ 面板自动填充整个可用空间
- ✅ 统计信息区域靠近弹窗底部，保持适当间距
- ✅ MQTT控制界面底部不再显示多余按钮

### 布局效果

**修改前**：
- 面板固定高度（AI: 300px, DI: 220px）
- 统计信息区域下方有大量空白
- 面板不填充整个可用空间

**修改后**：
- 面板自动填充整个可用空间
- 统计信息区域自然靠近底部
- 保持适当的底部间距（20px margins）

---

## 相关文档

1. **设计文档**: [docs/2026-02-09/18-Phase7.44.22-重新设计MQTT数据展示界面.md](18-Phase7.44.22-重新设计MQTT数据展示界面.md)
2. **完成总结**: [docs/2026-02-09/19-Phase7.44.22-完成总结.md](19-Phase7.44.22-完成总结.md)

---

**文档版本**: v1.0
**最后更新**: 2026-02-09
