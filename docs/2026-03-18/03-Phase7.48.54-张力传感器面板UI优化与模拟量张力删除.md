# Phase 7.48.54 - 张力传感器面板UI优化与模拟量张力删除

## 日期：2026-03-18

## 修复内容

### 问题3：张力传感器音频来源默认值

**问题**：TensionSensorConfigPanel 音频来源初始选中"默认"，但实际没有预录音频文件。

**修复**：`audioTtsRadio.checked: true`，默认选中TTS。

### 问题4：播放方式与保护级别对齐

**问题**：播放方式在 RowLayout 中，与上方 GridLayout 的保护级别列不对齐。

**修复**：将音频来源+播放方式从 RowLayout 改为独立 GridLayout（4列），播放方式位于 column 2-3，与保护级别列对齐。TTS文本/音频文件行使用 columnSpan: 3 横跨。

### 问题5：音频文件输入框文字

**问题**：audioFileField 的 placeholderText 为"自动生成"，不够明确。

**修复**：改为"张力保护"。

### 问题6：删除模拟量保护中的张力

**问题**：模拟量保护列表中的张力与张紧控制大类的 TensionSensorConfigPanel 功能重复，同一个传感器不需要两处管理。

**修复**：
- `AnalogInputPage.qml`：删除张力监测分组的 ListElement
- `DeviceConfigManager.cpp`：initDefaultAnalogProtections 删除张力项
- `DeviceConfigManager.cpp`：新增迁移024，DELETE 已有数据库中的张力保护记录

### 问题7：张力传感器状态监控

**问题**：张力传感器配置界面没有实时值显示，无法直观查看当前张力。

**修复**：在 TensionSensorConfigPanel 底部新增状态监控区域，参照 BasicConfigTab 传感器实时数据卡片：
- 监听 `aiDataManager.onChannelChanged` 信号获取实时AD值
- 工程量计算：下限 + (AD值 / 65535) × 量程
- 超限判断：工程量超出上下限时红色脉冲发光动画
- 卡片显示：名称 + 数值 + 单位，正常蓝色/超限红色

## 涉及文件

| 文件 | 修改内容 |
|------|---------|
| `src/qml/components/device_info/pages/TensionSensorConfigPanel.qml` | 音频来源默认TTS、GridLayout对齐、placeholderText、状态监控卡片 |
| `src/qml/components/device_info/pages/AnalogInputPage.qml` | 删除张力监测分组ListElement |
| `src/control/DeviceConfigManager.cpp` | 删除张力默认值+迁移024 |

## Git 提交

- `33b4b79` - 张力传感器面板UI优化+模拟量保护删除张力
