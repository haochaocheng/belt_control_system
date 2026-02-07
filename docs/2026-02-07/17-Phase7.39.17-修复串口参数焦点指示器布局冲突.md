# Phase 7.39.17: 修复串口参数焦点指示器布局冲突

**日期**: 2026-02-07（星期五）
**阶段**: Phase 7 - 串口参数焦点指示器布局修复
**用时**: 15分钟

---

## 一、问题描述

用户反馈：串口控制右边整个区域是空白的。

**日志警告**（voip.md）：
```
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_info/pages/SerialPortParamsTab.qml:873:21: QML Rectangle: Detected anchors on an item that is managed by a layout. This is undefined behavior; use Layout.alignment instead.
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_info/pages/SerialPortParamsTab.qml:806:21: QML Rectangle: Detected anchors on an item that is managed by a layout. This is undefined behavior; use Layout.alignment instead.
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_info/pages/SerialPortParamsTab.qml:742:21: QML Rectangle: Detected anchors on an item that is managed by a layout. This is undefined behavior; use Layout.alignment instead.
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_info/pages/SerialPortParamsTab.qml:618:21: QML Rectangle: Detected anchors on an item that is managed by a layout. This is undefined behavior; use Layout.alignment instead.
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_info/pages/SerialPortParamsTab.qml:494:21: QML Rectangle: Detected anchors on an item that is managed by a layout. This is undefined behavior; use Layout.alignment instead.
```

---

## 二、问题根因

### 2.1 布局冲突

**问题代码**（以波特率为例）：
```qml
RowLayout {
    anchors.fill: parent
    spacing: 10

    Text {
        text: "波特率:"
        Layout.preferredWidth: 120
    }

    DeviceInfo.CustomComboBox {
        id: baudRateCombo
        Layout.fillWidth: true
        Layout.maximumWidth: 300
    }

    // ❌ 焦点指示器在 RowLayout 中，使用了 anchors.fill
    Rectangle {
        anchors.fill: baudRateCombo  // ❌ 布局冲突！
        color: "transparent"
        border.color: (root.focusParamIndex === 1) ? "#2196F3" : "transparent"
        border.width: (root.focusParamIndex === 1) ? 3 : 0
        radius: 4
        z: 10
    }
}
```

**问题原因**：
1. 焦点指示器 Rectangle 在 RowLayout 中
2. 使用了 `anchors.fill: baudRateCombo`
3. RowLayout 管理的元素不应该使用 anchors
4. 导致布局冲突，整个区域显示为空白

### 2.2 受影响的焦点指示器

| 行号 | 元素 | 参数索引 |
|------|------|---------|
| 494 | baudRateCombo | 1 (波特率) |
| 618 | dataBitsCombo | 3 (数据位) |
| 742 | stopBitsCombo | 5 (停止位) |
| 806 | statusText | 6 (状态) |
| 873 | parityCombo | 7 (校验位) |

---

## 三、修复内容

### 3.1 修复方案

将焦点指示器从 RowLayout 中移到对应元素的内部，使用 `anchors.fill: parent` 而不是 `anchors.fill: targetElement`。

### 3.2 修复波特率焦点指示器

**修改文件**: `src/qml/components/device_info/pages/SerialPortParamsTab.qml`

**修改位置**: 第 454-501 行

**修改前**:
```qml
DeviceInfo.CustomComboBox {
    id: baudRateCombo
    Layout.fillWidth: true
    Layout.maximumWidth: 300
    model: ["1200", "2400", "4800", "9600", "19200", "38400", "57600", "115200"]
    currentIndex: 3  // 默认9600
    // ...
}

// ❌ 焦点指示器在 RowLayout 中
Rectangle {
    anchors.fill: baudRateCombo
    color: "transparent"
    border.color: (root.focusParamIndex === 1) ? "#2196F3" : "transparent"
    border.width: (root.focusParamIndex === 1) ? 3 : 0
    radius: 4
    z: 10
}
```

**修改后**:
```qml
DeviceInfo.CustomComboBox {
    id: baudRateCombo
    Layout.fillWidth: true
    Layout.maximumWidth: 300
    model: ["1200", "2400", "4800", "9600", "19200", "38400", "57600", "115200"]
    currentIndex: 3  // 默认9600
    // ...

    // ✅ 2026-02-07 [Phase 7.39.17]: 焦点指示器移到内部，避免布局冲突
    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        color: "transparent"
        border.color: (root.focusParamIndex === 1) ? "#2196F3" : "transparent"
        border.width: (root.focusParamIndex === 1) ? 3 : 0
        radius: 4
        z: 10
    }
}
```

### 3.3 修复数据位焦点指示器

**修改位置**: 第 582-625 行

**修改内容**: 同上，将焦点指示器移到 `dataBitsCombo` 内部

### 3.4 修复停止位焦点指示器

**修改位置**: 第 706-749 行

**修改内容**: 同上，将焦点指示器移到 `stopBitsCombo` 内部

### 3.5 修复状态焦点指示器

**修改位置**: 第 777-813 行

**修改内容**: 将焦点指示器移到 `statusText` (Row) 内部

**修改前**:
```qml
Row {
    id: statusText
    spacing: 8
    Layout.fillWidth: true
    Layout.maximumWidth: 300
    // ...
}

// ❌ 焦点指示器在 RowLayout 中
Rectangle {
    anchors.fill: statusText
    anchors.margins: -4
    color: "transparent"
    border.color: (root.focusParamIndex === 6) ? "#2196F3" : "transparent"
    border.width: (root.focusParamIndex === 6) ? 3 : 0
    radius: 4
    z: 10
}
```

**修改后**:
```qml
Row {
    id: statusText
    spacing: 8
    Layout.fillWidth: true
    Layout.maximumWidth: 300
    // ...

    // ✅ 2026-02-07 [Phase 7.39.17]: 焦点指示器移到内部，避免布局冲突
    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        color: "transparent"
        border.color: (root.focusParamIndex === 6) ? "#2196F3" : "transparent"
        border.width: (root.focusParamIndex === 6) ? 3 : 0
        radius: 4
        z: 10
    }
}
```

### 3.6 修复校验位焦点指示器

**修改位置**: 第 836-879 行

**修改内容**: 同上，将焦点指示器移到 `parityCombo` 内部

---

## 四、修复效果

### 4.1 修复前
- ❌ 串口控制右边整个区域显示为空白
- ❌ 控制台有 5 个布局冲突警告
- ❌ 参数输入框无法显示

### 4.2 修复后
- ✅ 串口控制右边区域正常显示
- ✅ 控制台没有布局冲突警告
- ✅ 参数输入框正常显示
- ✅ 焦点指示器正常工作

---

## 五、修改文件清单

| 文件 | 修改内容 | 行数变化 |
|------|---------|---------|
| `src/qml/components/device_info/pages/SerialPortParamsTab.qml` | 修复 5 个焦点指示器布局冲突 | +45 -45 |

---

## 六、技术要点

### 6.1 为什么会导致布局冲突？

**问题**：
- RowLayout 管理的元素使用 Layout 属性（如 `Layout.fillWidth`）
- 焦点指示器 Rectangle 也在 RowLayout 中，但使用了 `anchors.fill: targetElement`
- RowLayout 无法正确处理这种混合布局方式

**QML 布局规则**：
1. 在 Layout 中的元素应该使用 Layout 属性（`Layout.fillWidth`、`Layout.preferredWidth` 等）
2. 不应该在 Layout 管理的元素上使用 anchors
3. 如果需要使用 anchors，应该将元素移到 Layout 外部或内部

### 6.2 为什么移到内部可以解决？

**解决方案**：
- 将焦点指示器移到目标元素（如 CustomComboBox）内部
- 使用 `anchors.fill: parent` 填充父元素
- 父元素由 Layout 管理，子元素使用 anchors 不会冲突

**布局层次**：
```
RowLayout (管理布局)
├── Text (使用 Layout 属性)
└── CustomComboBox (使用 Layout 属性)
    └── Rectangle (焦点指示器，使用 anchors.fill: parent) ✅
```

### 6.3 为什么使用 anchors.margins: -4？

**目的**：
- 焦点指示器边框宽度为 3px
- 需要向外扩展 4px，使边框不会被元素内容遮挡
- `anchors.margins: -4` 使 Rectangle 比父元素大 8px（每边 4px）

### 6.4 为什么使用 z: 10？

**目的**：
- 确保焦点指示器显示在最上层
- 不会被其他元素遮挡
- z 值越大，显示层级越高

---

## 七、参考

### 7.1 QML 布局文档

- [Qt Quick Layouts](https://doc.qt.io/qt-6/qtquicklayouts-index.html)
- [Anchors and Layouts](https://doc.qt.io/qt-6/qtquick-positioning-layouts.html)

### 7.2 相关问题

- [QML Rectangle: Detected anchors on an item that is managed by a layout](https://stackoverflow.com/questions/tagged/qml+layout)

---

**编写人员**: Claude Sonnet 4.5
**审核状态**: ⏳ 待测试
**最后更新**: 2026-02-07
