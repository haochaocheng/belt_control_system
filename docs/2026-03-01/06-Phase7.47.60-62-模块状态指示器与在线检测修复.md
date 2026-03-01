# Phase 7.47.60-62 - 模块状态指示器与在线检测修复

**日期**: 2026-03-01
**阶段**: Phase 7.47.60 ~ 7.47.62.2

---

## 一、Phase 7.47.60 - 模块在线状态指示器

**提交**: `b6bda36b`

### 需求
在开关量输入保护参数设置页面增加模块在线/离线状态指示，根据当前选中保护项的模块类型自动展示。

### 实现
- 在 SwitchInputPage.qml GridLayout 第5行新增 `moduleStatusItem`
- LED 指示灯风格与通道状态一致（Cyberpunk 双环设计）
- 根据 `mqttAutoManager.healthStatus[moduleIndex]` 读取状态

### 修改文件
- `src/qml/components/device_info/pages/SwitchInputPage.qml`

---

## 二、Phase 7.47.61 - 修复模块断开后通道状态冻结

**提交**: `52ff7093`, `d80d7f15`

### 问题
模块断开后，DIDataManager 中 `m_diData` 保持最后值不清零，导致：
- 模块显示"离线"（红色LED）
- 通道仍显示"信号激活"（绿色LED闪烁）
- 界面出现矛盾状态

### 根因
1. DIDataManager 没有 `resetModule()` 方法
2. main.cpp 没有将断开事件传递到数据层
3. QML `isActive`/`_diIsActive` 没有联合判断模块在线状态

### 三层修复

| 层级 | 修改 |
|------|------|
| C++ DIDataManager | 新增 `resetModule(int moduleIndex)` — 清零数据并触发信号 |
| C++ main.cpp | 连接 `MQTTController::connectedChanged` → `diDataManager.resetModule()` |
| QML SwitchInputPage | `isActive`/`_diIsActive` 增加模块在线判断 |

### 修改文件
- `src/mqtt/DIDataManager.h` — 新增 resetModule 声明
- `src/mqtt/DIDataManager.cpp` — 新增 resetModule 实现
- `src/main/main.cpp` — 连接断开信号到 resetModule
- `src/qml/components/device_info/pages/SwitchInputPage.qml` — QML 双重保护

---

## 三、Phase 7.47.62 - 修复模块未启动却显示在线

**提交**: `c64b4d9a`

### 问题
MQTT 连上 broker 后，即使硬件模块未响应，界面仍显示"在线"。

### 根因
1. C++ `checkModuleHealth()` 中 `if (health.lastDataTime > 0)` — 从未收到数据时 `lastDataTime=0`，超时检查被跳过，`status` 停留在 `"已连接"`
2. QML `isOnline` 判断 `connected && status !== "数据超时"` — `status="已连接"` 时也返回 true

### 修复

**C++ 层**：`lastDataTime=0` 时设 `status="等待数据"`
```cpp
if (health.lastDataTime == 0) {
    health.status = "等待数据";
    return;
}
```

**QML 层**：只有 `status === "正常"` 才算在线
```qml
return hs[moduleIndex].status === "正常"
```

### 状态流转
```
未连接 → 已连接 → 等待数据 → 正常 → 数据超时
```

### 修改文件
- `src/mqtt/MQTTAutoManager.cpp` — checkModuleHealth 增加 lastDataTime=0 处理
- `src/qml/components/device_info/pages/SwitchInputPage.qml` — isOnline/isActive/_diIsActive 改为 status==="正常"

---

## 四、Phase 7.47.62.1 - 三色状态指示器

**提交**: `ab2f827c`

### 需求
MQTTX 测试时只连接 broker 不主动发数据，需要区分"连上 broker"和"硬件在线"。

### 实现

| 颜色 | 状态 | 含义 |
|------|------|------|
| 红色 `#ff4757` | 离线 | 未连接 MQTT broker |
| 黄色 `#f59e0b` | 已连接 | 连上 broker 但无持续数据 |
| 青色 `#00d4ff` | 在线 | 硬件模块持续发送数据（status=正常） |

### 关键属性
```qml
readonly property string moduleState: {
    if (hs[moduleIndex].status === "正常") return "online"      // 青色
    if (hs[moduleIndex].connected) return "connected"           // 黄色
    return "offline"                                             // 红色
}
```

### 修改文件
- `src/qml/components/device_info/pages/SwitchInputPage.qml`

---

## 五、Phase 7.47.62.2 - 修复状态指示器不刷新

**提交**: `f75ce8e9`

### 问题
模块状态变化后，LED 指示器不更新，始终显示青色在线。

### 根因
QML 对 `QVariantList` 的变化检测不可靠。`healthStatusChanged` 信号触发时，`readonly property` 可能不重新求值。

### 修复
添加 `_healthTick` 计数器，通过 `Connections` 监听 `healthStatusChanged` 信号递增，在 `moduleState` 中引用强制绑定刷新。

```qml
property int _healthTick: 0
Connections {
    target: typeof mqttAutoManager !== 'undefined' ? mqttAutoManager : null
    function onHealthStatusChanged() { moduleStatusItem._healthTick++ }
}

readonly property string moduleState: {
    var tick = _healthTick  // 强制绑定依赖
    // ...
}
```

### 修改文件
- `src/qml/components/device_info/pages/SwitchInputPage.qml`

---

## 六、提交记录

| 提交 | Phase | 内容 |
|------|-------|------|
| `b6bda36b` | 7.47.60 | 模块在线状态指示器 |
| `52ff7093` | 7.47.61 | 三层修复通道状态冻结 |
| `d80d7f15` | 7.47.61.1 | 增强在线检测（数据超时判断） |
| `c64b4d9a` | 7.47.62 | 修复未启动显示在线 |
| `ab2f827c` | 7.47.62.1 | 三色状态指示器 |
| `f75ce8e9` | 7.47.62.2 | 修复状态不刷新 |
