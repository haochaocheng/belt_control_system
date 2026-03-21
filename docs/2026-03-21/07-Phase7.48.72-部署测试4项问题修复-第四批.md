# Phase 7.48.72 - 部署测试4项问题修复（第四批）

## 日期：2026-03-21

## 问题清单与修复

### 问题1：切换到MQTT等面板后再切回逻辑控制，时间轴状态丢失
**根因**：`DeviceSettingsDialog.qml` 中 LogicControlPanel 的 Loader 使用 `active: root.currentCategory === 11`，切换到其他面板时 Loader 销毁组件，所有实时状态（rtPhase、rtElapsed、进度等）全部丢失。
**修复**：Loader 改为"加载后保持存活"模式：
```qml
active: root.currentCategory === 11 || logicControlPageLoader.status === Loader.Ready
```
首次选中时加载，之后即使切走也保持 `active=true`（因为 `status===Ready`），不销毁组件。

### 问题2：延时语义应为"前等待"（先等再激活）
**用户描述**：按R键→播放10秒预警→等张紧的5秒延时→才激活张紧→等制动器的1秒→才激活制动器

**根因**：C++ `executeNextDeviceInSequence()` 采用"后等待"模式：先激活设备，再用该设备的延时等待下一设备。导致第一个设备（张紧）被立即激活无延时，不符合预期。

**修复 — C++端完全重构**：
- `executeNextDeviceInSequence()` 改为只读取延时并启动定时器（不激活设备）
- `onDeviceSequenceTimer()` 改为定时器到期后激活设备、推进索引、递归调用

流程变为：
1. 预警结束 → `executeNext(index=0)` → 读张紧延时5s → timer(5s)
2. Timer到期 → 激活张紧 → index=1 → `executeNext(index=1)` → 读制动器延时1s → timer(1s)
3. Timer到期 → 激活制动器 → index=2 → ...

**修复 — QML端**：
- arrowItem 延时颜色/标签/编辑：从 `currentDelays[index]` 改为 `currentDelays[index + 1]`
- `getArrowProgress()` 延时：从 `currentDelays[deviceIndex]` 改为 `currentDelays[deviceIndex + 1]`
- 前缀进度条2（启车预警→第一个设备）：恢复延时标签，显示 `currentDelays[0]`，有实时进度

### 问题3：按S应立即切换到停止Tab
**根因**：`onStopSequenceStarted` 在停车音频播完后才触发，按S到切Tab有明显延迟。
**修复**：
1. C++：新增 `stopWarningStarted()` 信号，在 `stopBelt()` 中播放停车音频前 emit
2. QML：新增 `onStopWarningStarted` 处理器 → 立即设 `currentTab=1`、`rtPhase=5`（停车预警中）
3. `onStopSequenceStarted` 不再切Tab（已在 `onStopWarningStarted` 中完成），仅切 rtPhase=5→4

### 问题4：停止顺序进度条缺少停车预警进度
**根因**：上一版本的停止前缀进度条在 `rtPhase=4` 时才显示（此时停车音频已播完），无法展示预警过程。
**修复**：
- 停止前缀进度条1（停止键→停车预警）：rtPhase=5 时显示实时进度（用5秒估算停车音频时长），rtPhase=4 时填满
- "停止键开始"方框：rtPhase=5 时加粗边框表示正在预警
- 停止前缀进度条2（停车预警→第一个设备）：rtPhase=4 时显示第一个设备的延时进度（前等待）
- 状态文字：rtPhase=5 时显示"停车预警 Xs"

## rtPhase 状态说明（更新）
- 0 = 空闲
- 1 = 启车预警中（R键按下→预警音频播放）
- 2 = 启动序列运行中（预警结束→设备逐个启动）
- 3 = 故障
- 4 = 停止序列运行中（停车音频结束→设备逐个停止）
- 5 = 停车预警中（S键按下→停车音频播放）← **新增**

## 延时语义最终定义

**"前等待"（本次确定的正确语义）**：
- 含义：每个设备的延时是"激活该设备前需要等待的时间"
- 箭头在设备A和设备B之间 → 显示设备B的延时
- 前缀进度条2 → 显示第一个设备的延时
- C++：`delayIndex = m_currentSequenceIndex`（即将激活的设备）
- QML：arrowItem 用 `currentDelays[index + 1]`，prefix bar 2 用 `currentDelays[0]`

**举例**：序列=[张紧(5s), 制动器(1s), 电机(8s)]
1. 预警结束 → 等5s → 激活张紧
2. 张紧激活 → 等1s → 激活制动器
3. 制动器激活 → 等8s → 激活电机

## 修改文件清单

| 文件 | 改动 |
|------|------|
| `src/control/CommonControl.h` | 新增 stopWarningStarted() 信号 |
| `src/control/CommonControl.cpp` | emit stopWarningStarted(); 重构executeNextDeviceInSequence为"前等待" |
| `src/qml/components/device_info/DeviceSettingsDialog.qml` | Loader改为加载后保持存活 |
| `src/qml/components/device_info/pages/LogicControlPanel.qml` | onStopWarningStarted+rtPhase=5; 箭头延时index+1; 前缀进度条2延时标签+进度; 停止前缀实时进度 |
