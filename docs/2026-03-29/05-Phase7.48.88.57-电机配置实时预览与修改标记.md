# Phase 7.48.88.57 - 电机配置实时预览与修改标记

## 修改日期
2026-03-29

## 问题描述
1. **运行状态切换不实时同步**���切换电机的投入/禁用状态后，电机列表的显示只有保存后才更新，应该实时同步
2. **设备池更新时机确认**：逻辑控制里的设备池需要在保存时才更新（已验证正确）
3. **参数修改无视觉提示**：修改电机参数后，无法从电机列表看出哪个电机有未保存的修改

## 修改方案

### 问题1：运行状态实时预览
- BasicConfigTab 新增 `motorEnabledPreviewChanged(bool enabled)` 信号
- 切换投入/禁用时立即发出信号
- 信号链：BasicConfigTab → MotorConfigPanel → MotorControlPage
- MotorControlPage 收到信号后，浅拷贝 motorStatusList 并更新对应电机状态
- 赋新数组触发 QML 绑定更新，电机列表立即刷新显示

### 问题2：设备池仅保存时更新
- 已验证：`saveMotorConfig()` 中的 `commonControl.setDeviceFeedbackConfig()` 只在保存时执行
- 运行状态预览信号不触发设备池更新
- 无需修改

### 问题3：参数修改标记
- BasicConfigTab 新增 `configModified` 属性和 `_suppressModified` 抑制标志
- 新增 `markModified()` 函数，所有控件的 onValueChanged/onTextChanged 调用
- `applyConfig()` 期间抑制修改检测（加载配置不算修改）
- MotorControlPage 新增 `modifiedMotorIndex` 属性传递到 MyMotorListPanel
- MyMotorListPanel 在电机名称左侧显示黄色 ● 标记
- 保存后/切换电机时清除标记

## 修改的文件

### 1. `src/qml/components/device_info/pages/BasicConfigTab.qml`
- 新增 `configModified`, `_suppressModified` 属性
- 新增 `motorEnabledPreviewChanged(bool)`, `configModifiedStateChanged(bool)` 信号
- 新增 `markModified()` 函数
- `onMotorEnabledChanged` 触发预览信号和修改标记
- 所有 SpinBox 添加 `onValueChanged: root.markModified()`
- 所有 TextField 添加 `onTextChanged: root.markModified()`
- ComboBox 添加 `onCurrentIndexChanged: root.markModified()`
- `applyConfig()` 用 `_suppressModified` 包裹，结束时重置 configModified

### 2. `src/qml/components/device_info/pages/MotorConfigPanel.qml`
- 新增 `motorEnabledPreviewChanged(bool)`, `configModifiedStateChanged(bool)` 信号
- BasicConfigTab Loader onLoaded 中连接信号转发

### 3. `src/qml/components/device_info/pages/MotorControlPage.qml`
- 新增 `modifiedMotorIndex` 属性
- 连接 MotorConfigPanel 的 `motorEnabledPreviewChanged` 信号，实时更新 motorStatusList
- 连接 `configModifiedStateChanged` 信号，更新 modifiedMotorIndex
- 保存成功后清除修改标记并通知 BasicConfigTab
- 切换电机时清除修改标记
- 传递 modifiedMotorIndex 到 MyMotorListPanel

### 4. `src/qml/components/device_info/pages/MyMotorListPanel.qml`
- 新增 `modifiedMotorIndex` 属性
- delegate 中添加黄色 ● 标记（visible 绑定 modifiedMotorIndex === index）

## 测试要点
1. 切换1号电机的投入/禁���，确认电机列表立即更新（不需要保存）
2. 保存后，确认设备池被更新（CommonControl 同步）
3. 修改任意参数，确认电机名称左侧出现黄色 ● 标记
4. 点击保存，确认 ● 标记消失
5. 修改后不保存直接切换到其他电机，确认 ● 标记消失
6. 加载配置时（切换电机/首次打开），确认不触发 ● 标记
