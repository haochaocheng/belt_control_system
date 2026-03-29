# Phase 7.48.88.56 - 修复电机配置界面3个问题

## 修改日期
2026-03-29

## 问题描述
1. **电机列表全部显示运行中**：选中卡片按回车打开配置，电机列表8个电机都显示绿色"运行中"
2. **运行状态无法切换**：基本配置中"运行状态"选中后，按回车键无法在投入/禁用之间切换
3. **模块类型样式不一致**：基本配置中"模块类型"输入框外观与其他参数（CustomSpinBox 034.png背景）不同

## 原因分析

### 问题1
`MyMotorListPanel.qml` 第165-177行硬编码了 `color: "#4CAF50"` 和 `text: "运行中"`，没有绑定任何实际数据。

### 问题2
`BasicConfigTab.qml` 第1506-1509行的 `triggerParamInput(0)` 只有 `// TODO: 切换运行状态`，未实现切换逻辑。RadioButton 的 `visible` 属性也是硬编码的 `true/false`。

### 问题3
模块类型使用 `Rectangle { color: "#2d3548"; border.color: "#3d4556"; implicitHeight: 60 }`，而其他参数使用 `CustomSpinBox`（034.png 背景，implicitHeight: 48）。

## 修改的文件

### 1. `src/qml/components/device_info/pages/BasicConfigTab.qml`
- 新增 `motorEnabled` 属性（bool，true=投入/false=禁用）
- RadioButton 的 visible 绑定到 `motorEnabled`
- 投入文字选中时绿色，禁用文字选中时红色
- `triggerParamInput(0)` 实现回车切换：`root.motorEnabled = !root.motorEnabled`
- `collectConfig()` 保存实际状态：`config["running_state"] = root.motorEnabled ? "投入" : "禁用"`
- `applyConfig()` 加载状态
- 模块类型改用 034.png 背景 + implicitHeight 48

### 2. `src/qml/components/device_info/pages/MyMotorListPanel.qml`
- 新增 `motorStatusList` 属性（数组，每元素含 `enabled` 和 `outputChannel`）
- 状态指示绑定到 `motorStatusList[index]`
- 显示：投入（绿色）/ 禁用（红色）/ 未配置（暗灰）

### 3. `src/qml/components/device_info/pages/MotorControlPage.qml`
- 新增 `motorStatusList` 属性和 `loadAllMotorStatuses()` 函数
- 初始化时加载所有8个电机的基本配置
- 保存配置后刷新状态列表
- `motorStatusList` 通过 `Qt.binding()` 传递给 MyMotorListPanel

## 测试要点
1. 打开电机配置，确认电机列表显示正确状态（投入/禁用/未配置）
2. 选中"运行状态"按回车，确认投入/禁用切换
3. 保存后退出重进，确认状态持久化
4. 确认"模块类型"输入框外观与其他参数一致
