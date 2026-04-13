# Phase 7.48.88.117-126 集控管理界面系列修复

**日期**：2026-04-14  
**分支**：feature/hardware-video-codec  
**类型**：fix + feat（编译修复 + 界面增强）

---

## 修复总览

| Phase | 提交 | 类型 | 内容 |
|---|---|---|---|
| 7.48.88.117 | 7c49941 | fix | MQTT模块冲突（模块0→7）+ main.cpp依赖注入 + loadAllConfigs |
| 7.48.88.118 | a5bf6bc | fix | Qt6编译错误——QMap::unite()已移除 |
| 7.48.88.119 | 529e9a8 | fix | CustomComboBox下拉选项无法修改 |
| 7.48.88.120 | b6bd316 | feat | 集控管理界面完整键盘导航（4文件） |
| 7.48.88.121 | c6af5fb | fix | 虚拟键盘弹出 + 分站列表导航 + 字体尺寸统一 |
| 7.48.88.122 | f547f86 | fix | 输入框不可见（Layout.fillWidth→preferredWidth） |
| 7.48.88.123 | be06b47 | fix | 分站管理下键无法进入分站列表（focusSubArea判断） |
| 7.48.88.124 | 9c990ee | fix | 分站列表导航——事件由DeviceSettingsDialog处理 |
| 7.48.88.125 | 8140443 | fix | 分站列表整体高亮→改为单项高亮 |
| 7.48.88.126 | b8e50b1 | fix | 分站列表上下键不响应——补充focusSubArea===0分支 |

---

## Phase 7.48.88.117 MQTT模块冲突修复 + 依赖注入

**问题**：集控管理使用MQTT模块0（`CENTRAL_MQTT_MODULE=0`），与DI开关量模块冲突。main.cpp缺少依赖注入和配置加载。

**修复**：
- `CentralizedControlManager.cpp`：`CENTRAL_MQTT_MODULE` 从0改为7（预留模块）
- `enterMasterMode/enterSubStationMode`：先调用 `connectToModule(7)` 再订阅
- `main.cpp`：
  - 添加 `mqttController.loadAllConfigs()` 确保broker地址生效
  - 添加5个依赖注入：MQTTController / CommonControl / SystemConfig / MqttProtectionMonitor / TCPDataAdapter

**文件**：`src/control/CentralizedControlManager.cpp`、`src/main/main.cpp`

---

## Phase 7.48.88.118 Qt6编译错误修复

**问题**：`QMap::unite()` 在Qt6中已移除，编译失败。

**修复**：
```cpp
// 修复前
m.unite(m_slots[i].protocolParams);

// 修复后
for (auto it = m_slots[i].protocolParams.cbegin(); it != m_slots[i].protocolParams.cend(); ++it)
    m.insert(it.key(), it.value());
```

**文件**：`src/control/CentralizedControlManager.cpp`（2处）

---

## Phase 7.48.88.119 CustomComboBox下拉选项无法修改

**问题**：下拉列表点击选项后值恢复原样，无法修改。

**根本原因**：`CustomComboBox.onCurrentIndexChanged` 的防键盘导航逻辑过于宽泛：
```
旧判断：!isUserAction && activeFocus → 恢复savedIndex
```
下拉框弹出时用户点击选项，`isUserAction=false` 且 `activeFocus=true`，导致变更被强制恢复。

**修复**：增加 `root.popup.visible` 判断——弹出列表打开时的变化必然是用户选择，应接受。

| 情况 | 旧 | 新 |
|---|---|---|
| 用户点击下拉选项 | 恢复原值 | 接受 |
| 键盘上下键导航 | 恢复原值 | 恢复原值 |
| 回车/空格切换 | 接受 | 接受 |
| C++后端改值 | 接受 | 接受 |

**影响范围**：所有使用CustomComboBox的界面。

**文件**：`src/qml/components/device_info/CustomComboBox.qml`

---

## Phase 7.48.88.120 集控管理界面完整键盘导航

**新增功能**：为集控管理3个Tab页面添加完整的键盘上下左右导航。

**修改文件**：

| 文件 | 修改内容 |
|---|---|
| CentralControlPage.qml | handleNavigationKey()、Tab1分站列表区域切换、paramColumns=2 |
| CentralRoleTab.qml | parentDialog属性、4个参数焦点指示器（蓝色边框） |
| SubStationManageTab.qml | 分站列表焦点高亮、参数焦点指示器、parentDialog |
| MQTTCentralTab.qml | parentDialog属性、8个参数焦点指示器 |

**导航路径**：
```
Tab0/Tab2: ←返回类别 → Tab栏(左右) → ↓参数区(上下左右) → ↓保存按钮
Tab1:      ←返回类别 → Tab栏(左右) → ↓分站列表(上下) → →参数区 → ↓保存按钮
```

---

## Phase 7.48.88.121 集控界面4项修复

**问题1/3：回车键不弹虚拟键盘**
- 原：`root.virtualKeyboard.targetInput = field; virtualKeyboard.show()`（错误API）
- 改：`field.activateVirtualKeyboard()` 或 `field.forceActiveFocus()`

**问题2：下键无法进入分站列表**
- CentralControlPage覆盖Down/Right/Left键处理
- Tab1+TabBar+Down → motorList；motorList+Right → params；params+Left → motorList

**问题4：字体/尺寸不统一**
- 标签：pixelSize 13→21，color #B0BEC5→#9E9E9E，width 100→160，右对齐
- 控件：高度48px（与CustomComboBox/SpinBox一致）

**文件**：4个QML文件

---

## Phase 7.48.88.122 输入框不可见

**问题**：控件用 `Layout.fillWidth: true` 在流式GridLayout中宽度计算为0。

**原因**：BasicConfigTab 用显式 `Layout.column/row` 定位可以用 fillWidth，但集控Tab用流式布局不支持。

**修复**：改为 `Layout.preferredWidth: 200`。

**文件**：CentralRoleTab.qml、MQTTCentralTab.qml、SubStationManageTab.qml

---

## Phase 7.48.88.123-124 分站管理下键进入分站列表

**问题**：从Tab栏按下键直接跳到"启用"参数，不经过分站列表。

**根本原因**：**键盘事件由 DeviceSettingsDialog 统一拦截**，CentralControlPage.Keys.onDownPressed 完全不被触发。DeviceSettingsDialog 对 category=14 直接调用 `navigationManager.handleDirectionKey("Down")`，NavigationManager 的 `moveInTabBar("Down")` 固定去 areaParams。

**修复**：在 DeviceSettingsDialog 中添加条件判断：

| 键 | 条件 | 修复前 | 修复后 |
|---|---|---|---|
| Down | Tab1 + focusSubArea=1 | → areaParams | → areaMotorList |
| Right | Tab1 + focusSubArea=0 | → areaTabBar | → areaParams |
| Left | Tab1 + focusSubArea=2 + 首列 | → areaTabBar | → areaMotorList |

**文件**：`src/qml/components/device_info/DeviceSettingsDialog.qml`

---

## Phase 7.48.88.125 分站列表整体高亮→单项高亮

**问题**：进入列表后整个面板蓝框，不是单个分站项高亮。

**修复**：
- 去掉容器级蓝色外框（`border.color: focusSubArea===0?蓝`）
- 改为标题文字"分站列表"在焦点时变白提示
- 当前选中项 `currentSlotIndex`：列表模式(focusSubArea=0)时橙色边框，否则蓝色
- `onAreaChanged` 中用 `Qt.callLater` 直接设置tab的 currentSlotIndex（绕过Loader异步问题）

**文件**：SubStationManageTab.qml、CentralControlPage.qml

---

## Phase 7.48.88.126 分站列表上下键不响应

**问题**：进入分站列表后按上下键，焦点始终停在分站1。

**根本原因**：DeviceSettingsDialog 的 `focusSubArea===0`（列表区）Down/Up 分支有串口(7)、CAN(8)、TCP(9)的处理，但没有集控管理(14)的处理。

**修复**：在 `focusSubArea===0` 的 Down 和 Up 两个分支中，各增加 `currentCategory===14` 判断，调用 `centralPage.navigationManager.handleDirectionKey("Down"/"Up")`。

**文件**：`src/qml/components/device_info/DeviceSettingsDialog.qml`

---

## 关键经验教训

1. **键盘事件路由**：在此系统中，所有键盘事件由 `DeviceSettingsDialog` 统一拦截分发，子页面的 `Keys.onXxxPressed` 不会被触发。新增页面必须在 DeviceSettingsDialog 中注册所有方向键和回车键的处理。

2. **Qt6兼容性**：`QMap::unite()` 在Qt6中已移除，需要用迭代器循环替代。

3. **MQTT模块占用**：模块0-6已被DI/AI/DO/CS占用，新功能必须使用模块7（预留模块）。

4. **GridLayout布局**：流式GridLayout（只设columns，不用Layout.column/row）中 `Layout.fillWidth:true` 可能宽度为0，必须用 `Layout.preferredWidth`。

5. **CustomComboBox防护逻辑**：`popup.visible` 是区分"用户下拉选择"和"键盘导航引起的index变化"的关键条件。
