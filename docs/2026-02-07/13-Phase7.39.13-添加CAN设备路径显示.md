# Phase 7.39.13: 添加CAN设备路径显示

**日期**: 2026-02-07（星期五）
**阶段**: Phase 7 - CAN 设备路径显示
**用时**: 10分钟

---

## 一、需求描述

用户要求：在CAN接口列表中显示设备路径信息，不仅仅显示"CAN0"和"CAN1"。

**参考信息**（来自 01-RK3588工控机外设测试报告.md）：
- `/sys/class/net/can0` → `/devices/platform/fea50000.can/net/can0`
- `/sys/class/net/can1` → `/devices/platform/fea60000.can/net/can1`

---

## 二、实施内容

### 2.1 更新 CAN 数据结构

**修改文件**: `src/qml/components/device_info/pages/CANControlPage.qml`

**修改位置**: 第 183-188 行

**修改前**:
```qml
// ========== CAN 数据 ==========
property var canInterfaces: [
    { name: "CAN0", path: "can0", bitrate: 500000 },
    { name: "CAN1", path: "can1", bitrate: 250000 }
]
```

**修改后**:
```qml
// ========== CAN 数据 ==========
// ✅ 2026-02-07 [Phase 7.39.13]: 添加设备路径信息
property var canInterfaces: [
    { name: "CAN0", path: "can0", bitrate: 500000, devicePath: "/devices/platform/fea50000.can/net/can0" },
    { name: "CAN1", path: "can1", bitrate: 250000, devicePath: "/devices/platform/fea60000.can/net/can1" }
]
```

### 2.2 修改 CAN 列表显示

**修改文件**: `src/qml/components/device_info/pages/CANListPanel.qml`

**修改位置**: 第 109-144 行

**修改前**:
```qml
// ========== CAN 名称居中显示 ==========
Text {
    text: root.canInterfaces[index] ? root.canInterfaces[index].name : ""
    font.pixelSize: 16
    font.weight: root.currentCanIndex === index ? Font.Bold : Font.Normal
    color: root.currentCanIndex === index ? "#E0E0E0" : "#9E9E9E"
    anchors.centerIn: parent
}
```

**修改后**:
```qml
// ========== CAN 名称和设备路径显示 ==========
// ✅ 2026-02-07 [Phase 7.39.13]: 添加设备路径显示
Column {
    anchors.centerIn: parent
    spacing: 4

    // CAN 名称
    Text {
        text: root.canInterfaces[index] ? root.canInterfaces[index].name : ""
        font.pixelSize: 16
        font.weight: root.currentCanIndex === index ? Font.Bold : Font.Normal
        color: root.currentCanIndex === index ? "#E0E0E0" : "#9E9E9E"
        anchors.horizontalCenter: parent.horizontalCenter
    }

    // 设备路径（简化显示）
    Text {
        text: {
            if (!root.canInterfaces[index] || !root.canInterfaces[index].devicePath) {
                return ""
            }
            var fullPath = root.canInterfaces[index].devicePath
            // 提取最后一部分：fea50000.can
            var parts = fullPath.split("/")
            for (var i = parts.length - 1; i >= 0; i--) {
                if (parts[i].indexOf(".can") !== -1) {
                    return parts[i]
                }
            }
            return fullPath
        }
        font.pixelSize: 12
        color: root.currentCanIndex === index ? "#B0B0B0" : "#707070"
        anchors.horizontalCenter: parent.horizontalCenter
    }
}
```

---

## 三、显示效果

### 3.1 修改前
```
┌─────────────┐
│   CAN0      │
├─────────────┤
│   CAN1      │
└─────────────┘
```

### 3.2 修改后
```
┌─────────────────┐
│     CAN0        │
│ fea50000.can    │
├─────────────────┤
│     CAN1        │
│ fea60000.can    │
└─────────────────┘
```

**显示说明**：
- **第一行**：CAN 名称（CAN0、CAN1），字体大小 16px，粗体（选中时）
- **第二行**：设备路径简化显示（fea50000.can、fea60000.can），字体大小 12px，灰色

---

## 四、技术要点

### 4.1 为什么简化显示设备路径？

**完整路径**：
- `/devices/platform/fea50000.can/net/can0`

**简化显示**：
- `fea50000.can`

**原因**：
1. **空间限制**：列表项高度有限（60px），完整路径太长会导致显示不全
2. **关键信息**：`fea50000.can` 和 `fea60000.can` 是最关键的硬件标识
3. **用户友好**：简化后的路径更易读，用户可以快速识别不同的 CAN 接口

### 4.2 路径提取逻辑

```qml
var fullPath = root.canInterfaces[index].devicePath
// 提取最后一部分：fea50000.can
var parts = fullPath.split("/")
for (var i = parts.length - 1; i >= 0; i--) {
    if (parts[i].indexOf(".can") !== -1) {
        return parts[i]
    }
}
return fullPath
```

**逻辑说明**：
1. 将完整路径按 `/` 分割成数组
2. 从后往前查找包含 `.can` 的部分
3. 找到后返回该部分（如 `fea50000.can`）
4. 如果没找到，返回完整路径（兜底）

### 4.3 布局结构

使用 `Column` 布局：
- `anchors.centerIn: parent`：整体居中
- `spacing: 4`：两行之间间距 4px
- 每个 `Text` 使用 `anchors.horizontalCenter: parent.horizontalCenter`：水平居中

### 4.4 颜色方案

**CAN 名称**：
- 选中：`#E0E0E0`（亮灰色）
- 未选中：`#9E9E9E`（中灰色）

**设备路径**：
- 选中：`#B0B0B0`（浅灰色）
- 未选中：`#707070`（深灰色）

**设计原则**：
- 设备路径颜色比名称更暗，突出主要信息（名称）
- 选中时两者都变亮，保持视觉一致性

---

## 五、修改文件清单

| 文件 | 修改内容 | 行数变化 |
|------|---------|---------|
| `src/qml/components/device_info/pages/CANControlPage.qml` | 添加 devicePath 属性 | +2 |
| `src/qml/components/device_info/pages/CANListPanel.qml` | 添加设备路径显示 | +35 -7 |

---

## 六、验证方法

### 6.1 测试步骤

1. 启动应用程序
2. 进入 CAN 控制页面
3. 查看 CAN 接口列表

### 6.2 预期结果

- ✅ CAN0 下方显示 `fea50000.can`
- ✅ CAN1 下方显示 `fea60000.can`
- ✅ 设备路径字体比名称小，颜色更暗
- ✅ 选中时，名称和路径都变亮
- ✅ 布局居中，间距合理

---

## 七、下一步计划

### 功能测试（必须）
1. 测试 CAN 接口列表是否正确显示设备路径
2. 测试选中和未选中状态的颜色变化
3. 验证布局是否居中，间距是否合理

### 可选优化
1. 如果需要显示完整路径，可以添加 Tooltip 或详情面板
2. 如果需要动态获取设备路径，可以从 CANController 读取

---

**编写人员**: Claude Sonnet 4.5
**审核状态**: ✅ 已完成
**最后更新**: 2026-02-07
