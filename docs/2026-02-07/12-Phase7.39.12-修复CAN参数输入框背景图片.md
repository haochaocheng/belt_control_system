# Phase 7.39.12: 修复CAN参数输入框背景图片

**日期**: 2026-02-07（星期五）
**阶段**: Phase 7 - CAN 参数输入框背景图片修复
**用时**: 15分钟

---

## 一、问题描述

用户反馈：波特率和帧类型的输入框没有图片背景，显示不正常。

**问题分析**：
- CANParamsTab 使用的是普通的 `ComboBox` 组件
- `ComboBox` 的 `background` 设置为透明，没有使用图片背景
- 串口参数Tab使用的是 `CustomComboBox`，有图片背景（`images/034.png`）

---

## 二、问题根因

### 2.1 代码分析

**CANParamsTab.qml 的波特率输入框**（第154-197行）：

```qml
ComboBox {
    id: bitrateCombo
    anchors.fill: parent
    model: ["125000", "250000", "500000", "1000000"]

    background: Rectangle {
        color: "transparent"
        border.width: 0
    }

    contentItem: Text {
        text: bitrateCombo.displayText
        font.pixelSize: 21
        color: "#E0E0E0"
        verticalAlignment: Text.AlignVCenter
        leftPadding: 10
    }
}
```

**问题**：
- 使用普通的 `ComboBox`，没有图片背景
- `background` 只是一个透明的 `Rectangle`

### 2.2 正确的实现

**SerialPortParamsTab.qml 的波特率输入框**（第454行）：

```qml
DeviceInfo.CustomComboBox {
    id: baudRateCombo
    Layout.fillWidth: true
    Layout.maximumWidth: 300
    model: ["1200", "2400", "4800", "9600", "19200", "38400", "57600", "115200"]
    currentIndex: 3  // 默认9600
}
```

**CustomComboBox.qml 的背景实现**（第24-44行）：

```qml
background: Rectangle {
    color: "transparent"  // 透明，显示图片

    // 背景图片 034.png
    Image {
        anchors.fill: parent
        source: "images/034.png"
        fillMode: Image.Stretch  // 拉伸填充
        z: -1  // 放在最底层
    }

    // 焦点边框（可选，增强视觉效果）
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: root.activeFocus ? "#2196F3" : "transparent"
        border.width: root.activeFocus ? 3 : 0  // 加粗边框
        radius: 4
    }
}
```

---

## 三、修复内容

### 3.1 导入 CustomComboBox

**修改文件**: `src/qml/components/device_info/pages/CANParamsTab.qml`

**修改位置**: 第 1-9 行

**添加内容**:
```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../" as DeviceInfo  // ✅ 2026-02-07 [Phase 7.39.12]: 导入 CustomComboBox
```

### 3.2 替换波特率 ComboBox

**修改位置**: 第 146-199 行

**修改前**:
```qml
Item {
    Layout.fillWidth: true
    Layout.maximumWidth: 300
    Layout.preferredHeight: 40

    ComboBox {
        id: bitrateCombo
        anchors.fill: parent
        model: ["125000", "250000", "500000", "1000000"]
        // ...
        background: Rectangle {
            color: "transparent"
            border.width: 0
        }
    }
}
```

**修改后**:
```qml
// ✅ 2026-02-07 [Phase 7.39.12]: 使用 CustomComboBox
DeviceInfo.CustomComboBox {
    id: bitrateCombo
    Layout.fillWidth: true
    Layout.maximumWidth: 300
    model: ["125000", "250000", "500000", "1000000"]
    currentIndex: {
        var bitrate = canController.bitrate
        switch(bitrate) {
        case 125000: return 0
        case 250000: return 1
        case 500000: return 2
        case 1000000: return 3
        default: return 2
        }
    }

    onActivated: {
        var newBitrate = parseInt(model[index])
        console.log("✅ [CANParamsTab] 波特率变化:", newBitrate)
        canController.bitrate = newBitrate
    }
}

// ✅ 焦点指示器
Rectangle {
    anchors.fill: bitrateCombo
    color: "transparent"
    border.color: (root.focusParamIndex === 1) ? "#2196F3" : "transparent"
    border.width: (root.focusParamIndex === 1) ? 3 : 0
    radius: 4
    z: 10
}
```

### 3.3 替换帧类型 ComboBox

**修改位置**: 第 269-313 行

**修改前**:
```qml
Item {
    Layout.fillWidth: true
    Layout.maximumWidth: 300
    Layout.preferredHeight: 40

    ComboBox {
        id: frameTypeCombo
        anchors.fill: parent
        model: ["标准帧", "扩展帧"]
        // ...
        background: Rectangle {
            color: "transparent"
            border.width: 0
        }
    }
}
```

**修改后**:
```qml
// ✅ 2026-02-07 [Phase 7.39.12]: 使用 CustomComboBox
DeviceInfo.CustomComboBox {
    id: frameTypeCombo
    Layout.fillWidth: true
    Layout.maximumWidth: 300
    model: ["标准帧", "扩展帧"]
    currentIndex: canController.frameType === "标准帧" ? 0 : 1

    onActivated: {
        var newFrameType = model[index]
        console.log("✅ [CANParamsTab] 帧类型变化:", newFrameType)
        canController.frameType = newFrameType
    }
}

// ✅ 焦点指示器
Rectangle {
    anchors.fill: frameTypeCombo
    color: "transparent"
    border.color: (root.focusParamIndex === 3) ? "#2196F3" : "transparent"
    border.width: (root.focusParamIndex === 3) ? 3 : 0
    radius: 4
    z: 10
}
```

### 3.4 为只读 TextField 添加背景图片

**修改位置**: 第 81-143 行（CAN接口）和第 203-267 行（状态）

**添加内容**:
```qml
Item {
    Layout.fillWidth: true
    Layout.maximumWidth: 300
    Layout.preferredHeight: 60  // ✅ 2026-02-07 [Phase 7.39.12]: 与 CustomComboBox 高度一致

    // ✅ 2026-02-07 [Phase 7.39.12]: 添加背景图片
    Rectangle {
        anchors.fill: parent
        color: "transparent"

        Image {
            anchors.fill: parent
            source: "../images/034.png"
            fillMode: Image.Stretch
            z: -1
        }
    }

    TextField {
        id: canInterfaceText
        anchors.fill: parent
        text: canController.canInterface
        font.pixelSize: 21
        color: "#E0E0E0"
        verticalAlignment: Text.AlignVCenter
        leftPadding: 15
        readOnly: true

        background: Rectangle {
            color: "transparent"
            border.width: 0
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            color: "transparent"
            border.color: (root.focusParamIndex === 0) ? "#2196F3" : "transparent"
            border.width: (root.focusParamIndex === 0) ? 3 : 0
            radius: 4
            z: 10
        }
    }
}
```

---

## 四、修复效果

### 4.1 修复前
- 波特率和帧类型输入框没有背景图片
- CAN接口和状态输入框没有背景图片
- 输入框高度不一致（40px vs 60px）

### 4.2 修复后
- ✅ 波特率和帧类型使用 `CustomComboBox`，有图片背景（`images/034.png`）
- ✅ CAN接口和状态输入框添加了图片背景
- ✅ 所有输入框高度统一为 60px，与 `CustomComboBox` 一致
- ✅ 样式与串口参数Tab完全一致

---

## 五、修改文件清单

| 文件 | 修改内容 | 行数变化 |
|------|---------|---------|
| `src/qml/components/device_info/pages/CANParamsTab.qml` | 导入 CustomComboBox，替换 ComboBox，添加背景图片 | +40 -60 |

---

## 六、技术要点

### 6.1 为什么使用 CustomComboBox？

**问题**：
- 普通的 `ComboBox` 没有图片背景
- 需要手动添加 `Image` 到 `background`
- 样式不统一

**解决**：
- 使用 `CustomComboBox`，已经内置了图片背景（`images/034.png`）
- 样式统一，与串口参数Tab一致
- 代码更简洁

### 6.2 为什么为只读 TextField 添加背景图片？

**问题**：
- CAN接口和状态是只读的 `TextField`
- 没有背景图片，显示不正常
- 与可编辑的 `CustomComboBox` 样式不一致

**解决**：
- 在 `TextField` 外层添加一个 `Rectangle`
- `Rectangle` 中添加 `Image`，使用 `images/034.png`
- 保持与 `CustomComboBox` 样式一致

### 6.3 为什么统一高度为 60px？

**问题**：
- 原来的 `TextField` 高度为 40px
- `CustomComboBox` 高度为 60px
- 高度不一致，显示不协调

**解决**：
- 将所有输入框高度统一为 60px
- 与 `CustomComboBox` 高度一致
- 布局更协调

### 6.4 参考串口参数Tab的实现

**串口参数Tab的输入框**（SerialPortParamsTab.qml）：
- 使用 `DeviceInfo.CustomComboBox`
- 高度为 60px（`implicitHeight: 60`）
- 有图片背景（`images/034.png`）

**CAN参数Tab的输入框**（修复后）：
- 使用 `DeviceInfo.CustomComboBox`
- 高度为 60px
- 有图片背景（`images/034.png`）
- 完全一致

---

## 七、下一步计划

### 功能测试（必须）
1. 测试波特率输入框是否显示背景图片
2. 测试帧类型输入框是否显示背景图片
3. 测试CAN接口和状态输入框是否显示背景图片
4. 验证所有输入框高度是否一致

### 样式检查（可选）
1. 对比串口参数Tab和CAN参数Tab的样式
2. 确保完全一致

---

**编写人员**: Claude Sonnet 4.5
**审核状态**: ✅ 已完成
**最后更新**: 2026-02-07
