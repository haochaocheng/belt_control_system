# Phase 7.47.47 - 通道状态实时同步 + LED图标2倍大小

**创建时间**: 2026-02-28
**阶段**: Phase 7.47.47
**关联文件**:
- `src/qml/components/device_info/pages/SwitchInputPage.qml`

---

## 一、问题描述

| 问题 | 现象 |
|------|------|
| 通道状态不同步 | 右侧"通道状态"LED指示灯始终显示"正常监测(0)"，不会随实际DI模块位变化 |
| 列表状态不同步 | 左侧列表的"已激活/正常"状态固定为 `active: false`（ListModel初始值），不更新 |
| LED图标太小 | 原24x24px图标，用户要求增大到2倍（48x48px） |

---

## 二、根本原因

原代码 `channelStatusItem.isActive` 读取的是 `digitalProtectionModel.get(index).active`，而 ListModel 中的 `active` 字段**从未被更新**（始终为初始值 `false`）。

需要直接读取 `diDataManager`（开关量数据管理器）的实时位状态。

---

## 三、技术方案

### 3.1 diDataManager 已注册

`diDataManager` 已在 `src/main/main.cpp` 第351行注册为 QML 上下文属性：

```cpp
#ifdef MQTT_ENABLED
    engine.rootContext()->setContextProperty("diDataManager", &diDataManager);
#endif
```

**Windows**（无 MQTT）：`diDataManager` 未定义，QML 用 `typeof diDataManager !== 'undefined'` 检查，fallback 到 `model.active` 静态值。

### 3.2 响应式绑定原理

`DIDataManager` 有两个 `Q_PROPERTY`：
- `module1Data` (NOTIFY: `module1DataChanged`) — 模块1的8位状态数组
- `module2Data` (NOTIFY: `module2DataChanged`) — 模块2的8位状态数组

**关键技巧**：在 QML 属性表达式中**访问这两个 Q_PROPERTY**，QML 绑定引擎会自动建立依赖关系。当 `module1DataChanged` 或 `module2DataChanged` 信号触发时，属性自动重新计算。

```qml
readonly property bool isActive: {
    var item = digitalProtectionModel.get(root.currentProtectionIndex)
    if (typeof diDataManager !== 'undefined' && diDataManager !== null) {
        var moduleIdx = (item.moduleType === "开关量输入模块1") ? 0 : 1
        var bitIdx = item.channelNumber
        // 通过访问 Q_PROPERTY 建立响应式依赖（signal: module1/2DataChanged）
        var _dep = (moduleIdx === 0) ? diDataManager.module1Data : diDataManager.module2Data
        return diDataManager.getBit(moduleIdx, bitIdx)
    }
    return item.active  // fallback（Windows）
}
```

无需手动 `connect()`，完全依赖 QML 绑定引擎自动追踪。

### 3.3 模块索引映射规则

| `moduleType` 字段 | DI 模块索引 |
|-------------------|------------|
| `"开关量输入模块1"` | 0 |
| `"开关量输入模块2"` | 1 |

`bitIndex` = `channelNumber`（0-7）

---

## 四、修改内容

### 4.1 列表项（左侧面板）

在 `delegate: Rectangle` 中新增 `_diIsActive` 属性：

```qml
// ✅ 2026-02-28 [Phase 7.47.47]: 从 diDataManager 实时读取位状态
readonly property bool _diIsActive: {
    if (typeof diDataManager !== 'undefined' && diDataManager !== null) {
        var moduleIdx = (model.moduleType === "开关量输入模块1") ? 0 : 1
        var bitIdx = model.channelNumber
        var _dep = (moduleIdx === 0) ? diDataManager.module1Data : diDataManager.module2Data
        return diDataManager.getBit(moduleIdx, bitIdx)
    }
    return model.active  // fallback
}
```

状态指示替换：
- `model.active ? "#F44336" : "#4CAF50"` → `_diIsActive ? "#F44336" : "#4CAF50"`
- `model.active ? "已激活" : "正常"` → `_diIsActive ? "已激活" : "正常"`

### 4.2 通道状态 LED（右侧参数区）

`channelStatusItem.isActive` 改为读取 `diDataManager.getBit(moduleIdx, bitIdx)`（逻辑同上）。

`implicitHeight: 50` → `implicitHeight: 60`（容纳更大的图标）

### 4.3 LED 图标尺寸（2倍）

| 元素 | 旧尺寸 | 新尺寸 |
|------|--------|--------|
| 容器 Item | 24×24 | 48×48 |
| 外环 Rectangle | 24×24, radius 12 | 48×48, radius 24 |
| 内核 Rectangle | 14×14, radius 7 | 28×28, radius 14 |
| 高亮点 Rectangle | 4×4, radius 2 | 8×8, radius 4 |
| 高亮点边距 | margins: 3 | margins: 5 |

---

## 五、数据流

```
MQTT 消息
    ↓
MQTTAutoManager::moduleDataReceived
    ↓
DIDataManager::parseData(moduleIndex, payload)
    ↓
DIDataManager::module1DataChanged() 或 module2DataChanged()
    ↓（QML 响应式绑定自动触发）
SwitchInputPage.qml _diIsActive / isActive 重新计算
    ↓
LED 颜色 / 脉冲动画 / 文字 自动更新
```

---

## 六、测试说明

**Windows 开发机**（无 MQTT）：
- `diDataManager` 未定义，所有通道状态显示为"正常监测(0)"（fallback 行为正常）

**Linux 设备**（MQTT 启用）：
1. 触发物理开关量输入（DI模块位从0→1）
2. MQTT 模块发布数据
3. 左侧列表对应保护项变为"已激活"（红色圆点）
4. 右侧通道状态 LED 变为绿色 + 脉冲动画
5. 文字变为"信号激活 (1)" / "保护已触发"
