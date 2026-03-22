# Phase 7.48.82 - 修复启动焦点抢夺和反馈配置保存同步

## 修复日期
2026-03-22

## 问题1：启动时右键导航需要按4次才切换页面

### 问题描述
程序启动后，SwipeView 在 index 0（ControlPanel），按右键应直接切换到下一页。
但实际需要按4次右键才切换，因为焦点被 Screen01（Input1Page，index 5）的4列设备网格拦截。

### 根因
`Screen01.qml:254` 的 `Component.onCompleted` 中无条件调用 `root.forceActiveFocus()`，
即使当前 SwipeView 不在 Input1Page 页面，Screen01 仍然抢夺了全局焦点。

### 修复
在 `forceActiveFocus()` 前添加 `root.visible` 判断，只在页面可见时获取焦点。

## 问题2：电机反馈配置保存后未同步到逻辑控制

### 问题描述
用户在设备配置中将1号电机的 `使用反馈` 关闭并保存，但启动时仍然执行反馈检测，
播放"1号电机运行失败"。配置虽然在数据库中已保存（`use_feedback:0`），但逻辑控制未读取新值。

### 根因
`ParameterSettings.qml` 的 `syncDeviceFeedbackConfigs()` 只在 `Component.onCompleted` 调用一次，
将数据库配置同步到 `CommonControl` 内存。用户保存配置后，`CommonControl` 内存中仍是旧值。

### 修复
在电机、张紧控制、制动器的保存函数中，保存成功后立即调用
`commonControl.setDeviceFeedbackConfig()` 同步反馈配置到 CommonControl 内存。

## 修改文件

| 文件 | 修改内容 |
|------|---------|
| Screen01.qml | forceActiveFocus() 添加 visible 条件判断 |
| MotorControlPage.qml | saveMotorConfig() 保存后同步反馈配置 |
| TensionControlConfigPanel.qml | saveTensionControlConfig() 保存后同步反馈配置 |
| BrakeConfigPanel.qml | saveBrakeConfig() 保存后同步反馈配置 |
