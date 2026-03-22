# Phase 7.48.78 - 修复张力传感器5项交互问题

## 修复日期
2026-03-22

## 问题描述

### 问题1：音频来源回车键不切换
焦点在音频来源时，按回车键需要在"默认"和"TTS"之间来回切换，但实际不切换。

**根因**：ButtonGroup 互斥导致双 `!checked` 失效。设 `audioDefaultRadio.checked = !checked`(true) 后，ButtonGroup 自动取消 `audioTtsRadio`，然后再设 `audioTtsRadio.checked = !checked`(true) 又覆盖回来。

### 问题2：TTS文字输入框虚拟键盘遮挡
焦点在TTS文字输入框，按回车弹出虚拟键盘时，没有自动滚动，输入框被遮挡。

**根因**：
1. 缺少 `import QtQuick.Window 2.15`，`root.Window.activeFocusItem` 为 undefined
2. triggerParamInput 中没有主动调用 ensureVisible

### 问题3：播放方式回车键不来回切换
焦点在播放方式时，按回车只能切换到"按时长"，再按不能切回"按次数"。

**根因**：与问题1相同的 ButtonGroup 互斥问题。

### 问题4：TTS文本下键导航错误
焦点在TTS文本时，按下键移动到了洒水编号，应该是洒水启用。

**根因**：洒水启用没有参数索引，未纳入导航体系。导航直接从 TTS文本(14) 跳到洒水编号(15)。

### 问题5：洒水布局未对齐
洒水启用应该和TTS文本对齐（左列），洒水编号应该和播放方式对齐（右列）。

**根因**：洒水区域使用 RowLayout 紧凑排列，没有与上方 GridLayout 的4列布局对齐。

## 修改文件

### 1. TensionSensorConfigPanel.qml

#### 添加导入
```qml
import QtQuick.Window 2.15  // ensureVisible需要Window.activeFocusItem
```

#### triggerParamInput 修复
- **case 12（音频来源）**：`双!checked` → `if/else 单向设置`
  ```javascript
  // 旧：audioDefaultRadio.checked = !audioDefaultRadio.checked; audioTtsRadio.checked = !audioTtsRadio.checked;
  // 新：
  if (audioDefaultRadio.checked) { audioTtsRadio.checked = true }
  else { audioDefaultRadio.checked = true }
  ```
- **case 13（播放方式）**：同上修复
- **case 14（TTS文本）**：添加 `Qt.callLater(function() { ensureVisible(ttsTextField) })`
- **case 15（新增洒水启用）**：`sprinklerSwitch.checked = !sprinklerSwitch.checked`
- **case 16（洒水编号，旧15）**：`sprinklerIndexSpin.activateVirtualKeyboard()`

#### getParamFieldCount
16 → 17（新增洒水启用索引15）

#### 洒水区域布局重构
- 旧：RowLayout 一行紧凑排列
- 新：GridLayout 4列对齐
  - 列0-1：洒水启用（对齐TTS文本位置）
  - 列2-3：洒水编号（对齐播放方式位置）

### 2. TensionControlPage.qml

#### 导航行映射
```javascript
// 旧: [[0,2],[2,2],[4,2],[6,2],[8,2],[10,2],[12,2],[14,1],[15,1]]
// 新: [[0,2],[2,2],[4,2],[6,2],[8,2],[10,2],[12,2],[14,1],[15,2]]
// Row8: 洒水启用(15) + 洒水编号(16)
```

#### 按钮区Up键最后索引
15 → 16

## 参数索引（当前状态）

### 张力传感器 (17个参数, 0-16)
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
| 8 | 洒水启用(15) + 洒水编号(16) |

## 验证要点
1. 音频来源回车键在"默认"和"TTS"之间来回切换
2. 播放方式回车键在"按次数"和"按时长"之间来回切换
3. TTS文本回车弹出虚拟键盘时自动滚动，输入框不被遮挡
4. TTS文本下键导航到洒水启用（不是洒水编号）
5. 洒水启用与TTS文本列对齐，洒水编号与播放方式列对齐
6. 洒水启用回车键切换开关
7. 洒水编号回车键弹出数字虚拟键盘
