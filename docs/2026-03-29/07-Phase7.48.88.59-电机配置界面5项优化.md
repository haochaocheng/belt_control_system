# Phase 7.48.88.59 - 电机配置界面5项优化

## 修改日期
2026-03-29

## 功能描述

### 问题1：输出通道冲突检测与自动交换
- 继电器模块共12个通道，已全部分配
- 修改电机输出通道时，自动检测新通道是否被其他电机占用
- 如被占用，自动将被占用电机的通道设为-1（未配置），并显示橙色提示条4秒
- 信号链：BasicConfigTab → MotorConfigPanel → MotorControlPage

### 问题2：参数输入框文字对齐统一为居中
- CustomTextField：添加 `horizontalAlignment: Qt.AlignHCenter`
- CustomComboBox：从 `Text.AlignLeft` 改为 `Text.AlignHCenter`
- CustomSpinBox 已经是居中对齐（无需修改）

### 问题3：状态监控布局优化
- "状态监控"文字移到左侧（column 0），不再独占一行
- "运行状态" LED和文字移到同一行（column 1）
- "反馈状态" LED和文字也在同一行（column 2-3）
- 原来占2行（行8+行9），现在只占1行（行8）

### 问题4：模拟量区域Y坐标上移
- 状态监控合并为一行后，传感器数据面板（电流/前轴承温度等）自然上移一行
- 测试操作区域也相应上移

### 问题5：删除底部多余按钮
- 删除 MotorControlPage 底部的"保存""删除""重置"三个按钮
- 这些按钮与 DeviceSettingsDialog 的保存功能重复
- NavigationManager 设置 `skipButtonArea: true`，跳过按钮区域导航

## 修改的文件

### 1. `src/qml/components/device_info/pages/BasicConfigTab.qml`
- 新增 `requestOutputChannelConflictCheck` 信号
- outputChannelSpin 的 onValueChanged 增加冲突检查逻辑
- "状态监控"移到 column 0，与运行/反馈LED同一行（row 8）
- 所有后续行号递减1（传感器面板、分隔线、测试操作）

### 2. `src/qml/components/device_info/pages/MotorConfigPanel.qml`
- 新增 `requestOutputChannelConflictCheck` 信号转发

### 3. `src/qml/components/device_info/pages/MotorControlPage.qml`
- 新增 `handleOutputChannelConflict()` 函数：遍历8个电机检查通道冲突
- 新增 `channelConflictMessage` 属性和 4秒自动隐藏计时器
- 新增橙色冲突提示条 UI
- 删除底部按钮区域（保存/删除/重置）
- NavigationManager 设置 `skipButtonArea: true`

### 4. `src/qml/components/device_info/CustomTextField.qml`
- 新增 `horizontalAlignment: Qt.AlignHCenter`

### 5. `src/qml/components/device_info/CustomComboBox.qml`
- `horizontalAlignment` 从 `Text.AlignLeft` 改为 `Text.AlignHCenter`

## 测试要点
1. 修改电机输出通道为已被其他电机占用的通道 → 应显示橙色提示，被占用电机自动变为-1
2. CustomTextField、CustomComboBox 文字应居中显示
3. 状态监控、运行状态LED、反馈状态LED 应在同一行
4. 传感器数据面板位置应上移
5. 电机配置底部不应再显示保存/删除/重置按钮
