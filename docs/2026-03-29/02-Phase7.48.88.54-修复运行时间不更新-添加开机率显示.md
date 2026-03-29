# Phase 7.48.88.54 - 修复运行时间不更新 + 添加开机率显示

## 修改日期
2026-03-29

## 问题描述
1. **运行时间不更新**：卡片顶部的"今日 00:00:00"在设备运行时不随秒更新
2. **缺少开机率**：需要在卡片上显示今日开机率百分比

## 原因分析
### 运行时间不更新
- Phase 7.48.88.48 使用 QML Timer 轮询 `runtimeTracker.dailyRuntime`
- Timer 的 `running` 条件使用 `typeof runtimeTracker !== "undefined"`，此表达式在 QML 中对 context property 行为不一致
- 可能导致 Timer 从未启动，或在某些设备上评估为 false

### 开机率
- C++ `DeviceRuntimeTracker` 已有 `dailyUptime` 属性（double，百分比）
- 计算方式：今日运行秒数 / 今日已过去秒数 × 100%
- 只需在 QML 卡片中绑定显示

## 修改的文件

### 1. `src/qml/Input1/Input1Content/MyIN_Data.ui.qml`
- 新增 `dailyUptime` 属性（real，百分比值）
- 在运行时间后添加竖线分隔 + 开机率显示
- 开机率颜色：≥80% 绿色，≥50% 黄色，<50% 灰色

### 2. `src/qml/Input1/Input1Content/Screen01.qml`
- 提取 `updateRuntimeDisplay()` 公共函数，同时更新运行时间和开机率
- 新增 Connections 直接监听 `runtimeTracker.dailyRuntimeChanged` 和 `dailyUptimeChanged` 信号
- Timer 改为备份机制（每2秒兜底），`running: true` 避免条件判断失效
- 初始化时同时加载 dailyUptime

## 修复方案对比
| 方案 | Phase 7.48.88.48（旧）| Phase 7.48.88.54（新）|
|------|----------------------|----------------------|
| 信号 | 弃用 | Connections 直接监听 |
| Timer | 唯一更新源，1秒 | 备份兜底，2秒 |
| running 条件 | typeof 判断 | 始终 true |
| 开机率 | 无 | dailyUptime 显示 |

## 测试要点
1. 启动皮带后，观察运行时间是否每秒递增
2. 开机率是否随运行时间增加
3. 停止皮带后，运行时间停止递增但保持累计值
4. 重启应用后，累计运行时间从数据库加载
