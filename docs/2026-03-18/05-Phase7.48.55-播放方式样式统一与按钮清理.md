# Phase 7.48.55 - 播放方式样式统一与按钮清理

## 日期：2026-03-18

## 修改内容

### 1. 播放方式选择器统一为 Cyberpunk 工业风切换按钮

**问题**：播放方式选择器在不同界面使用了三种不同样式：
- 开关量输入/模拟量输入：Cyberpunk 切换按钮（蓝色/琥珀色）
- 9个电机保护Tab：CustomComboBox 下拉框，标签为"报警类型"
- 电机配置 MotorProtectionTab：简单 Button 蓝色/灰色切换
- 张力传感器面板：RadioButton

**修复**：全部统一为 Cyberpunk 工业风切换按钮：
- 标签统一为"播放方式"
- 选项统一为"按次数/按时长"
- 选中按次数：深蓝背景 + 青色边框 + 顶部青色高亮线 + LED点
- 选中按时长：深橙背景 + 橙色边框 + 顶部橙色高亮线 + LED点

### 2. 删除串口/CAN/TCP控制界面的保存删除重置按钮

**问题**：串口控制、CAN控制、TCP控制界面底部有保存、删除、重置三个按钮，不需要。

**修复**：删除第二行 RowLayout（保存/删除/重置按钮）及对应 triggerButton case 2/3/4。

## 涉及文件

| 文件 | 修改内容 |
|------|----------|
| `CurrentProtectionTab.qml` | ComboBox→Cyberpunk切换按钮，标签改为"播放方式" |
| `FrontBearingTempTab.qml` | 同上 |
| `RearBearingTempTab.qml` | 同上 |
| `MotorTempTab.qml` | 同上 |
| `PhaseAWindingTab.qml` | 同上 |
| `PhaseBWindingTab.qml` | 同上 |
| `PhaseCWindingTab.qml` | 同上 |
| `XAxisVibrationTab.qml` | 同上 |
| `YAxisVibrationTab.qml` | 同上 |
| `MotorProtectionTab.qml` | 简单Button→Cyberpunk切换按钮 |
| `TensionSensorConfigPanel.qml` | RadioButton→Cyberpunk切换按钮 |
| `SerialPortControlPage.qml` | 删除保存/删除/重置按钮 |
| `CANControlPage.qml` | 删除保存/删除/重置按钮 |
| `TCPControlPage.qml` | 删除保存/删除/重置按钮 |

## Git 提交

- `407da32` - 删除串口/CAN/TCP控制界面的保存删除重置按钮
- `8efa0d3` - 统一播放方式为Cyberpunk切换按钮样式（10个文件）
- `26000f8` - 修复遗漏MotorProtectionTab播放方式
