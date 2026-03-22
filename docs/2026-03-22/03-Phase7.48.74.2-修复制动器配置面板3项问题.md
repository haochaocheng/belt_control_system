# Phase 7.48.74.2 - 修复制动器配置面板3项问题

## 修复日期
2026-03-22

## 问题描述

### 问题1：保存失败 - Parameter count mismatch
制动器配置保存时报错 `"保存设备1制动器1配置失败: Parameter count mismatch"`。

**根因**：`DeviceConfigManager.cpp` 的 `saveBrakeConfig()` 函数中，INSERT SQL 语句有 42 个列名，42 个 addBindValue() 调用，但 VALUES 子句只有 38 个 `?` 占位符。差 4 个（对应 Phase 7.48.74 新增的 release_startup_delay、brake_startup_delay、release_stop_delay、brake_stop_delay）。

### 问题2：虚拟键盘遮挡输入框
焦点在松闸停止延时等底部字段时，按回车弹出虚拟键盘，输入框被遮挡看不到实际输入信息。

**根因**：BrakeConfigPanel 使用 ColumnLayout 直接布局，没有 ScrollView/Flickable 包裹，无法滚动。

### 问题3：布局需要调整
松闸启动延时和抱闸启动延时与电压字段混在同一行（4列），停止延时另起一行。需要：
- 电压字段独立一行
- 分割线分隔
- 启动延时独立一行
- 停止延时独立一行

## 修改文件

### 1. DeviceConfigManager.cpp (行2949-2952)
VALUES 占位符从 38 个修正为 42 个。

### 2. BrakeConfigPanel.qml
1. **ScrollView 包裹**：在 ColumnLayout 外层添加 ScrollView，clip: true
2. **布局重组**：
   - 行5: 抱闸动作电压(17) + 抱闸释放电压(18) + 4列空白
   - 分割线
   - 行6: 松闸启动延时(19) + 抱闸启动延时(20) + 4列空白
   - 行7: 松闸停止延时(21) + 抱闸停止延时(22) + 4列空白
3. **焦点自动滚动**：navFocusRect.updatePosition() 中添加 Flickable 自动滚动逻辑

### 3. BrakeControlPage.qml (行179)
导航行映射更新：
- 旧：`[[0,3],[3,3],[6,3],[9,4],[13,4],[17,4],[21,2]]`（7行）
- 新：`[[0,3],[3,3],[6,3],[9,4],[13,4],[17,2],[19,2],[21,2]]`（8行）

## 参数索引（不变，仍为0-22）

| 行 | 字段 |
|----|------|
| 0 | 启用(0) + 松闸输出(1) + 抱闸输出(2) |
| 1 | 使用松闸反馈(3) + 反馈通道(4) + 超时(5) |
| 2 | 使用抱闸反馈(6) + 反馈通道(7) + 超时(8) |
| 3 | 抱闸保持(9) + 松闸保持(10) + 抱闸动作延时(11) + 抱闸释放延时(12) |
| 4 | 检测延时(13) + 故障延时(14) + 抱闸电流(15) + 释放电流(16) |
| 5 | 抱闸动作电压(17) + 抱闸释放电压(18) |
| — | 分割线 |
| 6 | 松闸启动延时(19) + 抱闸启动延时(20) |
| 7 | 松闸停止延时(21) + 抱闸停止延时(22) |

## 验证要点
1. 制动器配置保存成功（不再报 Parameter count mismatch）
2. 虚拟键盘弹出时底部输入框自动滚动可见
3. 电压行和延时行之间有分割线
4. 启动延时和停止延时各占独立一行
5. 键盘导航在新布局中正常工作

## 后续修复记录（fix2 ~ fix4）

### fix2: ensureVisible 使用错误的 screenHeight（commit 73b8aee）

**现象**：虚拟键盘弹出后，内容向上滚动过多，所有输入框都看不到。

**根因**：`ensureVisible` 中 `var screenHeight = root.parent ? root.parent.height : 1080` 获取的是 Loader 高度（~600px），不是屏幕高度（1080px），导致 `keyboardGlobalTop` 偏小，滚动量过大。

**修复**：
- 使用 `Qt.inputMethod.keyboardRectangle.y` 获取键盘坐标
- `contentHeight` 缓冲从 +700 减为 +300

### fix3: kbRect.y 是锚点位置而非键盘顶部（commit b4b57ab）

**现象**：所有输入框都显示"无需滚动"，实际被键盘遮挡。

**日志确认**：
```
kbRect.y=1080  kbRect.h=600  kbTop=1080  safeBottom=1020
itemBottom=729 <= 1020 → "无需滚动"
```

**根因**：`kbRect.y=1080` 是 InputPanel 的锚点位置（屏幕底部），不是键盘顶部（480px）。`kbRect.y > 100` 条件为真，错误地使用了 1080 作为键盘顶部。

**修复**：
- 始终用 `kbTop = screenHeight - kbRect.height = 1080 - 600 = 480` 计算键盘顶部
- `screenHeight` 从 `kbRect.y`（如果 ≥ kbRect.height）推断

### fix4: maxScroll 不足 + 焦点框不跟随滚动（commit d8d344e）

**现象**：
1. 焦点白框在滚动时停留在原位，不跟随内容移动
2. 上面几个参数滚动正常，底部参数滚动不够，仍被键盘遮挡

**日志确认**：
```
Index 9:  needed=89,   targetY=89,  maxScroll=185 ← OK
Index 13: needed=142,  targetY=142, maxScroll=185 ← OK
Index 17: needed=195,  targetY=185, maxScroll=185 ← CLAMPED! 差10px
Index 19: needed=256,  targetY=185, maxScroll=185 ← CLAMPED! 差71px
Index 21: needed=309,  targetY=185, maxScroll=185 ← CLAMPED! 差124px
```

**根因**：
1. `navFocusRect.updatePosition()` 仅在 `focusParamIndex` 变化时触发，未监听 `contentY` 变化
2. `contentHeight = implicitHeight + 300`，`maxScroll = 185`，底部字段需要 309px 被截断

**修复**：
1. 添加 `Connections { target: paramScrollView; onContentYChanged: updatePosition() }` 让焦点框跟随滚动
2. 增加可见性裁剪：焦点框超出 Flickable 区域时自动隐藏
3. `contentHeight` 改为 `implicitHeight + 键盘高度(动态)`：键盘显示时 +600（maxScroll≈485），键盘隐藏时 +0
