# Phase 7.48.86 - 速度保护启动延时修复 + 保护停车后F键复位

## 修改时间
2026-03-23 (北京时间)

## 问题描述

### 问题1：速度保护启动延时无效
- `notifyMotorStarted(beltNumber)` 已实现但**从未被任何代码调用**
- `m_motorRunning[beltNumber]` 始终为 false
- 速度保护的启动延时检查条件永远不成立
- 电机停止后速度=0，仍会触发速度下限保护（false alarm）

### 问题2：保护停车后可直接重启
- 保护触发停车后，`runtimeTracker.isFault` 未被设置
- 按R键可直接重启，缺少复位确认环节
- 所有保护类型（开关量、模拟量、电机、CS沿线）都需要F键复位

## 修复方案

### 修复1：速度保护 — 仅在电机运行且延时到期后检测

| 修改文件 | 修改内容 |
|---------|---------|
| `CommonControl.h` | 新增 `motorActivated`/`motorDeactivated` 信号 |
| `CommonControl.cpp` | `activateDevice()` 中检测电机设备时 emit 信号 |
| `MqttProtectionMonitor.cpp` | 速度保护跳过电机未运行 + `notifyMotorStopped()` 清除速度报警 |
| `main.cpp` | 连接 `motorActivated/Deactivated` 到 `notifyMotorStarted/Stopped` |

**关键逻辑：**
```
电机未运行 → 跳过速度保护检测（不触发下限报警）
电机刚启动 → 启动延时期间跳过检测
启动延时到期 → 正常检测速度保护
电机停止 → 清除速度保护报警状态 + emit protectionActionCleared
```

### 修复2：保护停车后必须按F键复位

| 修改文件 | 修改内容 |
|---------|---------|
| `ProtectionLogicController.h` | 新增 `m_runtimeTracker` + `setDeviceRuntimeTracker()` |
| `ProtectionLogicController.cpp` | level=0/1 停车时调用 `setFault()` + `onDeviceFault()` |
| `App.qml` | F键增加保护检查 + 新增保护未恢复弹窗 + faultWarning显示保护名 |
| `main.cpp` | `protectionLogicController.setDeviceRuntimeTracker(&runtimeTracker)` |

**F键复位流程：**
```
按F键
  ├─ 检查 protectionLogicController.activeProtections()
  │   ├─ 有活跃保护 → 弹出"保护未恢复"弹窗（显示具体保护名）→ 不允许复位
  │   └─ 无活跃保护 → resetAllProtections() → 继续复位
  ├─ runtimeTracker.resetFault()  // 清除故障标识
  └─ protectionMonitor.manualReset()  // 检查外部信号
```

**R键启动流程（不变）：**
```
按R键
  ├─ runtimeTracker.isFault == true → 弹出故障警告弹窗 → 阻止启动
  └─ runtimeTracker.isFault == false → 正常启动
```

## 保护复位条件汇总

| 保护类型 | 触发条件 | 恢复条件 | F键复位前提 |
|---------|---------|---------|-----------|
| 开关量（急停/跑偏/撕裂） | bit=1 | bit恢复为0 | 外部信号已恢复 |
| 模拟量（温度/张力） | 超上/下限 | 值回到安全范围 | 值已恢复正常 |
| 速度保护 | 超速/低速打滑 | **禁止自动清除** | **必须按F键手动复位** |
| 电机保护 | 电流/温度超限 | 寄存器值恢复 | 外部信号已恢复 |
| CS沿线点位 | bit=1 | bit恢复为0 | 外部信号已恢复 |

## Phase 7.48.86.1 补充：速度保护禁止自动清除

**问题**：Phase 7.48.86 中 `notifyMotorStopped()` 会自动清除速度保护报警并 emit `protectionActionCleared`，导致速度保护可自动复位。

**修改**：
1. `notifyMotorStopped()` 不再清除 `m_protectionAlarmActive` 和 emit 信号，只重置检测状态（计时器等）
2. 新增 `resetSpeedProtectionAlarm(beltNumber)` 方法，仅在F键复位时由 `resetAllProtections()` 调用
3. ProtectionLogicController 新增 `m_mqttProtectionMonitor` 引用，`resetAllProtections()` 中遍历已停车皮带清除速度保护

## Phase 7.48.86.2 补充：多电机启动延时计时器不重置

**问题**：一条皮带有多个电机（电机1、电机2...），`CommonControl::activateDevice()` 对每个电机都 emit `motorActivated`，导致 `notifyMotorStarted()` 被调用多次，每次都重置延时计时器。同样，每个电机停止都 emit `motorDeactivated`，第一个电机停止就将 `m_motorRunning` 置为 false。

**修改**：
1. 新增 `m_activeMotorCount[beltNumber]`：追踪每条皮带已激活的电机数量
2. `notifyMotorStarted()`：只在第一个电机启动时（`m_motorRunning==false`）开始延时计时，后续电机启动只增加计数不重置计时器
3. `notifyMotorStopped()`：递减计数，只在最后一个电机停止时（`count<=0`）才标记 `m_motorRunning=false`

**逻辑流程**：
```
电机1启动 → count=1, motorRunning=true, 延时计时开始
电机2启动 → count=2, 不重置计时器
电机3启动 → count=3, 不重置计时器
...延时到期后开始速度保护检测...
电机3停止 → count=2, 继续检测
电机2停止 → count=1, 继续检测
电机1停止 → count=0, motorRunning=false, 停止检测
```

## Phase 7.48.86.3 补充：电机启动皮带号与AI模块映射不匹配

**问题**：`CommonControl::activateDevice()` emit `motorActivated(m_currentBeltNumber)`，`m_currentBeltNumber=2`，但AI模块0映射的皮带号是1。导致 `m_motorRunning[2]=true`，而速度保护检测 `m_motorRunning[1]` 始终为 false。

**修改**：
1. `notifyMotorStarted/Stopped()` 忽略传入的 `beltNumber` 参数（`Q_UNUSED`）
2. 遍历 `m_aiBeltMapping` 获取所有已映射皮带号
3. 为所有已映射皮带统一设置电机运行状态和延时计时器

**效果**：任意电机启动 → 所有已映射皮带的速度保护开始延时计时

## 验证方法
1. 电机未运行时速度=0 → 不触发下限报警
2. 电机启动后延时到期前 → 不检测速度保护
3. 保护触发停车后按R键 → 弹出故障警告弹窗
4. 保护恢复后按F键 → 成功复位 → 可按R键启动
5. 保护未恢复按F键 → 弹出"保护未恢复"弹窗
6. 故障弹窗显示具体保护名称（如"1号皮带 速度超上限"）
