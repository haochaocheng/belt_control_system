# Phase 7.48.88.48 - 设备卡片增加输出设备运行状态LED指示

## 日期
2026-03-28

## 需求描述

在设备监控卡片上增加输出设备的运行状态指示，用方形LED表示设备是否运行中（灰色=停止，绿色=运行）。设备列表与逻辑控制面板启动序列同步，包括洒水设备。LED需要永久展示，与保护指示灯一样始终可见。

## 实现方案

### 1. MyIN_Data.ui.qml - 卡片组件

**新增属性**：
```qml
property var outputDevices: []        // 设备名列表
property var outputDeviceStates: ({}) // 设备名→运行状态映射
```

**新增输出设备LED行**（分隔线与保护栏之间）：
- 方形LED 10×10px，圆角2px
- 灰色 `#4B5563`（停止）/ 绿色 `#22C55E`（运行），运行时带外发光
- 设备名缩写：张紧控制→"张紧"，1号制动器→"闸1"，1号电机→"机1"，洒水1→"水1"
- 无设备时自动隐藏（height=0）

**布局压缩**（为LED行腾出空间）：
| 区域 | 旧高度 | 新高度 |
|------|--------|--------|
| 核心数据区 | 140 | 118 |
| 保护状态栏 | 46 | 38 |
| 底部信息栏 | 26 | 20 |
| Column spacing | 4 | 2 |
| **输出设备LED** | **无** | **32** |

总高：118+6+32+1+38+20 + 5×2 = 225px < 233px可用

### 2. Screen01.qml - 数据驱动

**`loadOutputDeviceList()`**：
- 从DB加载启动序列（`deviceConfigMgr.loadDeviceLogicConfig`）
- 追加已启用的洒水设备（`loadSprinklerConfig`，enabled=1）
- 设置到本机卡片的 `outputDevices` 属性

**监听 `deviceStatusChanged` 信号**：
- CommonControl 在设备激活/停用时发出此信号
- Screen01 接收后更新本机卡片的 `outputDeviceStates` 映射
- 创建新对象赋值以触发QML binding更新

**今日运行时间修复**：
- 原信号方式（`onDailyRuntimeChanged`）不可靠，改为Timer每秒轮询 `runtimeTracker.dailyRuntime`

## 修复的问题

1. **dailyRuntime始终00:00:00**：信号连接时序问题，改用Timer轮询
2. **Column布局溢出**：原总高247px > 233px可用，底部元素被裁剪。缩减核心数据区和spacing后225px < 233px

## 影响范围

- 本机卡片新增输出设备LED行，实时显示设备运行状态
- 保护指示灯缩小（18→14px LED，14→12px字号）但功能不变
- 底部栏缩小但功能不变
- 非本机卡片不显示输出设备行

## 验证要点

1. 本机卡片显示启动序列中的所有设备 + 已启用洒水设备
2. 启动序列执行时LED依次变绿，停止后依次变灰
3. 序列执行视图（倒计时）不影响LED行显示
4. 今日运行时间正确递增
5. 保护指示灯和底部栏正常显示不被裁剪

## 提交
- `f452345` - 初始实现
- `1bebdc4` - 修复dailyRuntime和布局溢出
