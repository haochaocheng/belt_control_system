# Phase 7.48.76 - 修复张力传感器4项交互问题

## 修复日期
2026-03-22

## 问题描述

### 问题1：ComboBox回车键无反应
焦点在下拉输入框时（如模块类型、单位、输入类型、保护级别），按回车键没有切换参数。

**根因**：`triggerParamInput` 使用 `popup.open()` 试图打开下拉列表，但因焦点不在 ComboBox 上导致无效。

### 问题2：SpinBox回车键不弹出虚拟键盘
焦点在数值输入框时（如通道号、下限值、播放次数等），按回车键没有弹出虚拟键盘。

**根因**：`triggerParamInput` 使用 `forceActiveFocus()`，只给 SpinBox 外壳焦点，不触发虚拟键盘。CustomSpinBox 有专门的 `activateVirtualKeyboard()` 方法（调用内部 TextInput 的 forceActiveFocus + Qt.inputMethod.show）。

### 问题3：音频来源和播放方式被导航跳过
音频来源（默认/TTS）和播放方式（按次数/按时长）没有分配参数索引，导航焦点直接从保护级别(11)跳到TTS文本(12)。

**根因**：这两个字段在原设计中未纳入导航体系。

### 问题4：TTS文本按回车键不弹出中文输入法
TTS文本输入框按回车键没有弹出虚拟键盘，且弹出的是数字键盘而不是中文输入法。

**根因**：
1. `triggerParamInput` 只调用 `forceActiveFocus()` 没有调用 `Qt.inputMethod.show()`
2. CustomTextField 默认 `inputMethodHints: Qt.ImhDigitsOnly`（数字键盘），TTS文本需要 `Qt.ImhNone`

## 修改文件

### 1. TensionSensorConfigPanel.qml

#### 参数索引重编（15→16个参数）
| 旧索引 | 新索引 | 字段 |
|--------|--------|------|
| 0-11 | 0-11 | 不变 |
| - | **12** | **音频来源（新增）** |
| - | **13** | **播放方式（新增）** |
| 12 | 14 | TTS文本/音频文件 |
| 14 | 15 | 洒水编号 |

#### triggerParamInput 全面修复
- SpinBox: `forceActiveFocus()` → `activateVirtualKeyboard()`
- ComboBox: `popup.open()` → 循环切换值 `isUserAction=true; currentIndex=(currentIndex+1)%count`
- TextField: 增加 `Qt.inputMethod.show()` 手动触发虚拟键盘
- 新增 case 12（音频来源切换）和 case 13（播放方式切换）

#### inputMethodHints
- nameField: 添加 `inputMethodHints: Qt.ImhNone`（允许中文）
- ttsTextField: 添加 `inputMethodHints: Qt.ImhNone`（允许中文）

#### 焦点高亮
- 音频来源 Item: 添加 paramIndex===12 焦点边框
- 播放方式 Item: 添加 paramIndex===13 焦点边框
- TTS文本/音频文件: 焦点索引 12/13→14
- 洒水编号: 焦点索引 14→15

### 2. TensionControlConfigPanel.qml

#### triggerParamInput 修复
- SpinBox: `forceActiveFocus()` → `activateVirtualKeyboard()`
- TextField: 增加 `Qt.inputMethod.show()`

### 3. TensionControlPage.qml

#### 导航行映射更新（张力传感器）
- 旧: `[[0,2],[2,2],[4,2],[6,2],[8,2],[10,2],[12,2],[14,1]]` (8行)
- 新: `[[0,2],[2,2],[4,2],[6,2],[8,2],[10,2],[12,2],[14,1],[15,1]]` (9行)

#### 按钮区Up键最后索引
- 张力传感器: 14→15

## 参数索引（当前状态）

### 张力传感器 (16个参数, 0-15)
| 行 | 字段 |
|----|------|
| 0 | 名称(0) + 播放次数(1) |
| 1 | 模块类型(2) + 播放时长(3) |
| 2 | 通道号(4) + 上限值(5) |
| 3 | 下限值(6) + 量程(7) |
| 4 | 单位(8) + 输入类型(9) |
| 5 | 保护延时(10) + 保护级别(11) |
| 6 | 音频来源(12) + 播放方式(13) |
| 7 | TTS文本/音频文件(14) |
| 8 | 洒水编号(15) |

### 张紧控制 (9个参数, 0-8)
不变。

## 验证要点
1. ComboBox按回车键循环切换值（模块类型、单位、输入类型、保护级别）
2. SpinBox按回车键弹出数字虚拟键盘（通道号、下限值、播放次数等）
3. 音频来源和播放方式有焦点高亮，可导航到
4. 音频来源按回车切换默认/TTS
5. 播放方式按回车切换按次数/按时长
6. TTS文本按回车弹出中文输入法虚拟键盘
7. 名称按回车弹出中文输入法虚拟键盘
8. 张紧控制面板SpinBox回车弹出虚拟键盘
