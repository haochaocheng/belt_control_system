# Phase 7.48.88.58 - 未保存修改提示与输出通道实时预览

## 修改日期
2026-03-29

## 功能描述

### 功能1：离开电机控制时未保存修改提示
当用户在电机配置界面修改了参数但未保存，尝试切换到其他类别（如制动器控制）时：
- 弹出提示对话框："电机控制有未保存的修改，是否保存当前修改？"
- **保存(Enter)**：自动执行保存，然后切换到目标类别
- **放弃(Esc)**：恢复到修改前的参数（重新加载数据库值），然后切换

拦截了所有3个类别切换���口：
- 鼠标点击左侧类别按钮
- 键盘Up键切换到上一个类别
- 键盘Down键切换到下一个类别

### 功能2：输出通道变化实时预览
修改输出通道值时，电机列表立即更新状态显示：
- 输出通道改为 -1 → 列表立即显示"未配置"（暗灰）
- 输出通���改为 ≥0 → 列表根据运行状态显示"投入"（绿）或"禁用"（红）

电机列表状态显示逻辑：
| 输出通道 | 运行状态 | 显示文字 | 颜色 |
|---------|---------|---------|------|
| -1 | 任意 | 未配置 | #555555 暗灰 |
| ≥0 | 投入 | 投入 | #4CAF50 绿色 |
| ≥0 | 禁用 | 禁用 | #FF5722 红色 |

## 修改的文件

### 1. `src/qml/components/device_info/DeviceSettingsDialog.qml`
- 新增 `_pendingCategory` 属性和 `hasMotorUnsavedChanges()` 函数
- 新增 `tryChangeCategory(newIndex)` 函数（替代直接赋值）
- 3处 `currentCategory` 赋值改为调用 `tryChangeCategory()`
- 新增 `unsavedChangesDialog` 弹窗组件（保存/放弃按钮，支持Enter/Esc快捷键）

### 2. `src/qml/components/device_info/pages/BasicConfigTab.qml`
- 新增 `outputChannelPreviewChanged(int channel)` 信号
- outputChannelSpin 的 onValueChanged 同时发出预览信号

### 3. `src/qml/components/device_info/pages/MotorConfigPanel.qml`
- 新增 `outputChannelPreviewChanged(int channel)` 信号转发

### 4. `src/qml/components/device_info/pages/MotorControlPage.qml`
- 连接 outputChannelPreviewChanged 信号，实时更新 motorStatusList 中的 outputChannel

## 测试要点
1. 修改电机参数后，切换到制动器控制 → 应弹出保存提示
2. 点击"保存" → 参数保存，切换成功
3. 点击"放弃" → 参数恢复原值，切换成功
4. 未修改参数时切换类别 → 不弹窗，直接切换
5. 修改输出通道为-1 → 电机列表立即显示"未配置"
6. 修改输出通道为正数 → 电机列表根据运行状态显示
