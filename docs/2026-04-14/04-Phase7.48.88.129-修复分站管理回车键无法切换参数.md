# Phase 7.48.88.129 修复分站管理回车键无法切换启用参数

**日期**：2026-04-14  
**分支**：feature/hardware-video-codec  
**类型**：fix（QML响应式绑定修复）

---

## 问题现象

焦点在"启用"或"协议类型"参数框时，按回车键（Enter）应循环切换参数值（关闭↔打开、MQTT→S7→Modbus），但实际上参数值没有任何变化。

日志显示：
```
[导航] 回车键已被集控管理页面处理
```
说明 `handleEnterKey()` → `triggerParamInput(0)` 确实被调用了，但 UI 没有更新。

---

## 根本原因

### QML 绑定的响应性规则

在 QML 中，属性绑定只对 **Q_PROPERTY 读取**有响应性（会自动跟踪依赖）。**函数调用的返回值不是响应式的**，即使函数内部的状态发生了变化，绑定也不会重新求值。

### 问题代码

`SubStationManageTab.qml` 中两个 ComboBox 的 `currentIndex` 绑定：

```qml
// 启用字段 —— 使用函数调用，不响应式
currentIndex: (typeof centralControlManager !== "undefined" &&
               centralControlManager.isSlotEnabled(root.currentSlotIndex)) ? 1 : 0

// 协议类型字段 —— 使用函数调用，不响应式
currentIndex: {
    switch(getCurrentSlotProtocol()) { ... }
}
```

`isSlotEnabled()` 和 `getSlotProtocol()` 都是 `Q_INVOKABLE` 函数调用，不是 Q_PROPERTY。

### 调用链分析

1. 用户按 Enter → `handleEnterKey()` → `triggerParamInput(0)`
2. `triggerParamInput(0)` 调用 `centralControlManager.setSlotEnabled(currentSlotIndex, !isEnabled)`
3. C++ 中 `setSlotEnabled` 改变内部状态，发出 `subStationsChanged` 信号
4. QML 绑定检查：`isSlotEnabled()` 是函数调用，**不被信号驱动重新求值**
5. `enabledField.currentIndex` 保持旧值，UI 不更新

---

## 修复方案

将两个 `currentIndex` 绑定改为读取 **`centralControlManager.subStations`**——这是 Q_PROPERTY，`setSlotEnabled` 执行后发出 `subStationsChanged` 信号，绑定会自动重新求值。

```qml
// 修复后：启用字段 —— 使用 Q_PROPERTY subStations，响应式
currentIndex: {
    if (typeof centralControlManager === "undefined") return 0
    var slots = centralControlManager.subStations
    if (!slots || root.currentSlotIndex >= slots.length) return 0
    return slots[root.currentSlotIndex].enabled ? 1 : 0
}

// 修复后：协议类型字段 —— 同上
currentIndex: {
    if (typeof centralControlManager === "undefined") return 0
    var slots = centralControlManager.subStations
    if (!slots || root.currentSlotIndex >= slots.length) return 0
    var proto = slots[root.currentSlotIndex].protocol || ""
    switch(proto) {
    case "s7":     return 1
    case "modbus": return 2
    default:       return 0
    }
}
```

### 响应链（修复后）

1. `triggerParamInput(0)` → `setSlotEnabled()` → 发出 `subStationsChanged`
2. `centralControlManager.subStations` 变化（Q_PROPERTY + NOTIFY）
3. QML 绑定重新求值 → `enabledField.currentIndex` 更新 → UI 显示新值 ✅

---

## 修改文件

| 文件 | 修改 |
|---|---|
| `src/qml/components/device_info/pages/SubStationManageTab.qml` | `enabledField.currentIndex` 和 `protocolField.currentIndex` 绑定改为读 `subStations` |

---

## 经验教训

**QML 绑定响应性规则**：

| 类型 | 是否响应式 |
|---|---|
| `Q_PROPERTY` 属性读取 | ✅ 是（信号触发重新求值） |
| `Q_INVOKABLE` 函数调用 | ❌ 否（返回值变化不触发重新求值） |
| 本地 QML 属性 | ✅ 是 |
| `Qt.binding()` 内读取的属性 | ✅ 是 |

在绑定中调用 C++ 函数获取动态数据时，必须通过 Q_PROPERTY + NOTIFY 来确保响应性，或者通过直接赋值（但会破坏绑定）。
