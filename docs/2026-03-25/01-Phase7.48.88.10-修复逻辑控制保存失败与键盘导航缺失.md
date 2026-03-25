# Phase 7.48.88.10 - 修复逻辑控制保存失败与键盘导航缺失

## 修复日期
2026-03-25

## 问题描述

### 问题1：逻辑控制配置保存失败
用户在逻辑控制面板中修改配置（如删除启动/停车步骤），点击保存按钮后，关闭再重新打开面板，配置恢复为默认值。所有皮带的逻辑控制配置均无法持久化保存。

### 问题2：键盘导航无法到达逻辑控制
在设备设置对话框的左侧分类列表中，使用键盘下键（↓）导航，焦点最多只能移动到"TCP控制"（分类9），无法到达"MQTT控制"（分类10）、"逻辑控制"（分类11）和"沿线点位保护"（分类12）。

## 根本原因分析

### 问题1根因
`DeviceSettingsDialog.qml` 保存按钮的 `onClicked` 处理中，`switch(root.currentCategory)` 只处理了 case 0-7（基本配置到串口控制），**缺少 case 8-11**。

当用户在逻辑控制面板（分类11）点击保存时，执行流程如下：
```
保存按钮 onClicked
  → switch(11)
  → 匹配 default 分支
  → 打印 "⚠️ 未知分类: 11"
  → LogicControlPanel.saveToConfig() 从未被调用
  → 数据从未写入数据库
```

**日志证据**（voip.md）：
```
[DEBUG] ✅ [DeviceSettingsDialog] 保存参数 - 当前分类: 11
[DEBUG] ⚠️ [DeviceSettingsDialog] 未知分类: 11
```

整个日志中没有任何 `💾 LogicControlPanel: saveToConfig` 的输出，证实 saveToConfig 从未执行。

### 问题2根因
Down 键导航的上限硬编码为 `currentCategory < 9`，这是在添加 TCP 控制（Phase 7.42）时设置的值，之后新增的 MQTT 控制（10）、逻辑控制（11）、沿线点位保护（12）未更新此上限。

## 修改文件

### 1. src/qml/components/device_info/DeviceSettingsDialog.qml

#### 修改点1：补充 case 8-11 的保存逻辑（行 2219-2233）

**修改前**：
```qml
case 7:  // 串口控制
    // TODO: 调用串口控制的保存函数
    break
default:
    console.log("⚠️ [DeviceSettingsDialog] 未知分类:", root.currentCategory)
    break
```

**修改后**：
```qml
case 7:  // 串口控制
    // TODO: 调用串口控制的保存函数
    break
case 8:  // CAN控制
    // TODO: 调用CAN控制的保存函数
    break
case 9:  // TCP控制
    // TODO: 调用TCP控制的保存函数
    break
case 10:  // MQTT控制
    // TODO: 调用MQTT控制的保存函数
    break
case 11:  // 逻辑控制
    if (logicControlPageLoader.item && typeof logicControlPageLoader.item.saveToConfig === "function") {
        logicControlPageLoader.item.saveToConfig()
    }
    break
default:
    console.log("⚠️ [DeviceSettingsDialog] 未知分类:", root.currentCategory)
    break
```

#### 修改点2：修正键盘Down键导航上限（行 881）

**修改前**：
```qml
case 1:  // 左侧类别（9个类别：0-8）
    if (currentCategory < 9) {
        currentCategory++
    }
```

**修改后**：
```qml
case 1:  // 左侧类别（13个类别：0-12）
    if (currentCategory < 12) {
        currentCategory++
    }
```

## 与昨日修复(Phase 7.48.88.9)的关系

昨日的修复（将 loadFromConfig 移到 Loader.onLoaded、保存后回读验证）解决的是**加载时机**问题，修复本身是正确的。但真正导致"保存失败"的原因是保存按钮根本没调用 saveToConfig —— 两个问题叠加导致了用户看到的现象。

| 修复 | 解决的问题 |
|------|-----------|
| Phase 7.48.88.9（昨日） | 切换皮带时 Component.onCompleted 用错误 deviceId=1 加载覆盖 |
| Phase 7.48.88.10（今日） | 保存按钮 switch 缺少 case 11，saveToConfig 从未被调用 |

## 测试验证

1. 打开1号皮带 → 逻辑控制 → 删除"张紧控制" → 保存 → 关闭
2. 打开2号皮带 → 逻辑控制 → 删除"2号电机" → 保存 → 关闭
3. 打开3号皮带 → 逻辑控制 → 删除"1号电机" → 保存 → 关闭
4. 重新打开1号皮带 → 逻辑控制 → 验证"张紧控制"已被删除
5. 重新打开2号皮带 → 验证"2号电机"已被删除
6. 重新打开3号皮带 → 验证"1号电机"已被删除
7. 使用键盘↓键从"基本配置"导航到"逻辑控制"，验证焦点可到达

## Git 提交
- `1c42bf0` - fix: Phase 7.48.88.10 修复逻辑控制保存按钮未连接saveToConfig
- `a894c65` - fix: Phase 7.48.88.10 修复键盘导航无法到达逻辑控制等分类
