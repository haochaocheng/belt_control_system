# Phase 7.48.88.127-132 集控管理深度修复系列

**日期**：2026-04-14  
**分支**：feature/hardware-video-codec  
**类型**：fix + feat

---

## 修复总览

| Phase | 提交 | 类型 | 内容 |
|---|---|---|---|
| 7.48.88.127 | 6223527 | fix | onCurrentFocusAreaChanged 强制覆盖 focusSubArea |
| 7.48.88.128 | 2d37b3a | fix | Qt.callLater 直接赋值破坏 Qt.binding |
| 7.48.88.129 | 03e68df | fix | 回车切换参数——subStations 响应式绑定 |
| 7.48.88.130 | eabec1c | fix | Qt6 event 参数注入弃用警告 |
| 7.48.88.131 | 2839f57 | fix | 直接操作 ComboBox.currentIndex 切换参数 |
| 7.48.88.132 | f02d847 | feat | 状态指示 + 保存修复 |

---

## Phase 7.48.88.127 修复右键进入参数区焦点不可见

**问题**：从分站列表按右键，日志显示切换成功（A→C），但参数区焦点边框不出现。

**根本原因**：`DeviceSettingsDialog` 中 `Connections.onCurrentFocusAreaChanged` 处理器每次触发时强制 `focusSubArea = 1`（TabBar），覆盖了 NavigationManager 刚设置的 `focusSubArea = 0/2`。

该代码写于 Phase 7.48.88.110（"集控无端口列表，直接进入Tab区域"），后来加了分站列表但未同步修改。

**修复**：只在 `focusSubArea < 0`（未初始化）时设为 1，不覆盖已有值。

```qml
// 旧
centralControlPageLoader.item.focusSubArea = 1

// 新
var currentSub = centralControlPageLoader.item.focusSubArea
if (currentSub < 0) {
    centralControlPageLoader.item.focusSubArea = 1
}
```

**文件**：`src/qml/components/device_info/DeviceSettingsDialog.qml`

---

## Phase 7.48.88.128 修复 Qt.callLater 破坏 Qt.binding

**问题**：从分站列表右键进入参数区后，切换到其他分站再回来，参数焦点失效。

**根本原因**：Phase 7.48.88.125 的 `Qt.callLater` 代码中直接赋值：
```qml
subStationManageTabLoader.item.focusSubArea = 0
```
QML 规则：对绑定属性直接赋值会**永久销毁** `Qt.binding`。之后 `root.focusSubArea` 改为 2 时，tab 的 `focusSubArea` 不再跟随更新。

**修复**：移除该行直接赋值。`root.focusSubArea = 0` 已在 `onAreaChanged` 中设置，`Qt.binding` 会自动同步。

**文件**：`src/qml/components/device_info/pages/CentralControlPage.qml`

---

## Phase 7.48.88.129 修复回车切换参数——subStations 响应式绑定

**问题**：焦点在启用/协议类型时按回车，`triggerParamInput` 调用了但 UI 不更新。

**根本原因**：QML 绑定响应性规则——函数调用返回值不是响应式的：

```qml
// 旧：isSlotEnabled() 是 Q_INVOKABLE 函数，不响应 subStationsChanged 信号
currentIndex: centralControlManager.isSlotEnabled(root.currentSlotIndex) ? 1 : 0
```

`setSlotEnabled` 发出 `subStationsChanged` 后，绑定不重新求值，UI 冻结。

**修复**：改为读 `centralControlManager.subStations`（Q_PROPERTY + NOTIFY）：

```qml
// 新：subStations 是响应式 Q_PROPERTY，信号后自动重新求值
currentIndex: {
    var slots = centralControlManager.subStations
    return slots[root.currentSlotIndex].enabled ? 1 : 0
}
```

**响应链**：`setSlotEnabled()` → `subStationsChanged` → `subStations` 变化 → binding 重新求值 → UI 更新

| 类型 | 是否响应式 |
|---|---|
| Q_PROPERTY 属性读取 | ✅ |
| Q_INVOKABLE 函数调用 | ❌ |

**文件**：`src/qml/components/device_info/pages/SubStationManageTab.qml`（`enabledField.currentIndex`、`protocolField.currentIndex`）

---

## Phase 7.48.88.130 修复 Qt6 event 参数注入弃用警告

**问题**：按回车键时出现警告：
```
Parameter "event" is not declared. Injection of parameters into signal
handlers is deprecated. Use JavaScript functions with formal parameters instead.
```

**根本原因**：旧式信号处理器声明方式 `Keys.onReturnPressed: {`，Qt6 中 `event` 可能未被注入（undefined），导致 `event.accepted = true` 抛出 TypeError，中断执行流。

**修复**：改为显式形式：
```qml
// 旧（Qt6 弃用）
Keys.onReturnPressed: { ... event.accepted = true ... }

// 新（Qt6 推荐）
Keys.onReturnPressed: function(event) { ... event.accepted = true ... }
```

**涉及范围**：
- `Keys.onReturnPressed` 主处理器（第 2232 行）
- `Keys.onEscapePressed` 主处理器（第 2454 行）
- 12 个对话框按钮内联处理器（第 4721-4778 行）

**文件**：`src/qml/components/device_info/DeviceSettingsDialog.qml`

---

## Phase 7.48.88.131 修复启用参数回车切换——直接操作 ComboBox

**问题**：回车键仍无法切换启用/协议类型 ComboBox 值。

**根本原因**：`triggerParamInput(0/1)` 只调用后端方法，没有直接操作 ComboBox 控件。即使后端状态改变，UI 也不一定立即更新。

**参考 BasicConfigTab 的正确模式**：
```qml
// BasicConfigTab case 0 (是否启用)
enabledSwitch.toggle()  // 直接操作 Switch 控件

// BasicConfigTab case 12 (音频来源)
audioSourceCombo.currentIndex = 1  // 直接设置 ComboBox
```

**修复**：`triggerParamInput` 中先直接切换 ComboBox 的 `currentIndex`（立即视觉更新），再调用后端同步：

```qml
case 0:
    var newEnabledIndex = (enabledField.currentIndex + 1) % 2
    enabledField.currentIndex = newEnabledIndex          // 直接操作 UI
    centralControlManager.setSlotEnabled(currentSlotIndex, newEnabledIndex === 1)  // 同步后端
    break
case 1:
    var newProtoIndex = (protocolField.currentIndex + 1) % protocolField.count
    protocolField.currentIndex = newProtoIndex           // 直接操作 UI
    centralControlManager.setSlotProtocol(currentSlotIndex, protocols[newProtoIndex])  // 同步后端
    break
```

**关键原则**：`triggerParamInput` 必须直接操作 UI 控件（立即视觉反馈），后端调用是额外同步，不能只依赖 binding 链路。

**文件**：`src/qml/components/device_info/pages/SubStationManageTab.qml`

---

## Phase 7.48.88.132 集控管理状态指示 + 保存修复

### 1. 保存修复（`未知分类：14` 警告消除）

**问题**：在集控管理界面点保存，日志出现 `⚠️ [DeviceSettingsDialog] 未知分类: 14`。

**原因**：`DeviceSettingsDialog` 的保存 switch 只到 case 11（逻辑控制），缺少 12/13/14。

**修复**：
- `getCategoryName` 补全：12=逻辑控制, 13=沿线点位保护, 14=集控管理
- 保存 switch 增加：
  - `case 12`: 沿线保护配置无需额外保存
  - `case 13`: 预留
  - `case 14`: 调用 `centralControlManager.saveConfig()`

### 2. CentralControlPage 状态栏

在标题栏下方新增状态栏（36px 高），所有 Tab 页面均可见：

| 区域 | 内容 |
|---|---|
| 角色指示 | 蓝色圆 + "角色: 主站" / 绿色圆 + "角色: 分站" / 灰色圆 + "角色: 独立" |
| MQTT状态 | 绿/红圆 + "MQTT: IP:Port 已连接/未连接" |
| 在线统计 | 主站模式：`在线: N/M 站` |
| 设备ID | 分站模式：`设备ID: N` |

### 3. MQTT集控配置 Tab 连接状态

在说明框上方增加状态框（56px 高）：

| 状态 | 视觉 |
|---|---|
| 已连接 | 绿色 LED + 绿色边框 + "MQTT模块7 已连接 IP:Port" |
| 连接中 | 橙色 LED + "MQTT模块7 连接中…" |
| 未连接 | 红色 LED + 红色边框 + "MQTT模块7 未连接 IP:Port" |
| 未配置 | 红色 LED + "⚠ 未填写Broker地址" |

### 4. 分站列表状态增强

| LED 颜色 | 含义 |
|---|---|
| 灰 `#555` | 未启用 |
| 黄 `#FFA726` | 已启用但未连接 |
| 绿 `#4CAF50` | 在线 |

- 分站名下方新增状态小字（"已连接"/"未配置"/"离线"/"重连中"等）
- 未启用分站名字颜色变暗灰
- 使用 `subStations` Q_PROPERTY 替代函数调用（响应式更新）

---

## 今日关键经验（合并汇总）

1. **Qt.binding 不可被直接赋值破坏**：对绑定属性赋值会永久销毁绑定，之后依赖的属性变化不再触发更新

2. **Q_INVOKABLE 函数调用不是响应式的**：binding 中只有 Q_PROPERTY 读取才会被追踪，需改用 Q_PROPERTY 访问

3. **triggerParamInput 必须直接操作 UI 控件**：参考 BasicConfigTab 模式，直接设 currentIndex 等，再调用后端

4. **Qt6 信号处理器必须使用 function(event) 形式**：旧式隐式注入在部分版本中失效导致 TypeError

5. **DeviceSettingsDialog 拦截所有键盘事件**：新增页面必须在 DeviceSettingsDialog 中注册所有方向键、回车键处理，且保存 switch 需补充对应 case
