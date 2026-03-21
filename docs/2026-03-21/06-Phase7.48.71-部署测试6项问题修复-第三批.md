# Phase 7.48.71 - 部署测试6项问题修复（第三批）

## 日期：2026-03-21

## 问题清单与修复

### 问题1：切换Tab后启动流程时间轴重置到初始状态
**现象**：启动流程运行中，切换到"停止顺序"Tab再切回，或切换到其他面板（MQTT、电机控制）再回来，时间轴丢失实时状态。
**根因**：Tab点击处理器中调用了 `resetRealtimeTracking()`，每次Tab切换都清空所有实时数据。
**修复**：Tab `MouseArea.onClicked` 中移除 `resetRealtimeTracking()` 调用，仅更改 `root.currentTab = index`。

### 问题2：按S自动切到停止Tab，但按R不能自动切到启动Tab
**根因**：`onWarningStarted()` 信号处理器中没有设置 `root.currentTab = 0`。
**修复**：在 `onWarningStarted()` 开头添加 `root.currentTab = 0`，与 `onStopSequenceStarted` 的 `root.currentTab = 1` 对称。

### 问题3：切换到启动顺序后按R键，进度条不动
**根因**：由问题1导致——Tab切换重置了实时状态，按R键虽触发 `onWarningStarted` 但之前的跟踪已丢失。
**修复**：问题1和2修复后自动解决。

### 问题4：张紧控制配置5秒但实际运行只有约1秒
**根因**：Phase 7.48.70 错误地将延时语义从"后等待"改为"前等待"。

**"后等待"语义（正确）**：`delayIndex = m_currentSequenceIndex - 1`（刚激活的设备），即"张紧控制的 startup_delay=5s"表示"张紧激活后，等5秒再激活下一个设备"。

**"前等待"语义（错误，7.48.70）**：`delayIndex = m_currentSequenceIndex`（即将激活的设备），导致张紧激活后读取的是1号制动器的延时（1s），而非张紧的延时（5s）。

**修复**：
1. C++：`delayIndex` 恢复为 `m_currentSequenceIndex - 1`
2. QML arrowItem：延时标签、颜色、进度计算、编辑弹窗从 `currentDelays[index+1]` 恢复为 `currentDelays[index]`
3. QML `getArrowProgress()`：延时从 `currentDelays[deviceIndex+1]` 恢复为 `currentDelays[deviceIndex]`
4. 前缀进度条2：移除延时标签（"后等待"下，预警结束后第一个设备立即启动，无等待时间）

### 问题5：停止顺序缺少"停止键开始"和"停车预警"前缀框
**根因**：所有前缀节点（"运行键开始"、前缀进度条1、"启车预警"、前缀进度条2）均设 `visible: root.currentTab === 0`，停止Tab无对应元素。
**修复**：新增4个停止Tab专属前缀节点：
1. "停止键开始" 方框（红色主题，■ 图标）
2. 前缀进度条1（停止键→停车预警，含预警时间标签）
3. "停车预警" 方框（红色主题，⚠ 图标）
4. 前缀进度条2（停车预警→第一个停止设��）

所有节点 `visible: root.currentTab === 1`，在 rtPhase=4 时显示为已完成状态（因 `stopSequenceStarted` 信号在停车音频播放完成后才发出）。

同时新增停止序列状态文字："停止中 Xs 设备 N/M"。

### 问题6：设备超过4个时时间轴宽度不够
**现状**：Flickable 已包裹时间轴，超出部分可左右滑动。
**修复**：
1. 在时间轴右侧添加滚动提示图标（◀☰▶），当内容超出可视区时自动显示
2. 底部提示栏追加"← 左右滑动查看 →"文字提示

## 修改文件清单

| 文件 | 改动 |
|------|------|
| `src/control/CommonControl.cpp` | 问题4: delayIndex 恢复为 m_currentSequenceIndex-1（后等待语义） |
| `src/qml/components/device_info/pages/LogicControlPanel.qml` | 问题1: Tab切换不重置实时状态；问题2: onWarningStarted自动切Tab0；问题4: 延时标签/进度恢复为index；问题5: 停止Tab前缀节点+状态文字；问题6: 滚动提示；前缀进度条2移除错误的延时标签 |

## 延时语义总结

**"后等待"（当前正确语义）**：
- 箭头在设备A和设备B之间 → 显示设备A的延时
- 含义：设备A激活后，等待A的 startup_delay 秒，再激活设备B
- C++ `delayIndex = m_currentSequenceIndex - 1`（刚激活的设备）
- QML `currentDelays[index]`（当前设备的延时）

## rtPhase 状态
- 0 = 空闲
- 1 = 启车预警中
- 2 = 启动序列运行中
- 3 = 故障
- 4 = 停止序列运行中
