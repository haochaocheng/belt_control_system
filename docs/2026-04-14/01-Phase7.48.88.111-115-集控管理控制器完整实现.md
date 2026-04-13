# Phase 7.48.88.111-115 集控管理控制器完整实现

**日期**：2026-04-14  
**分支**：feature/hardware-video-codec  
**类型**：feat（新功能）

---

## 背景

Phase 7.48.88.110（上一阶段）完成了集控管理的 UI 框架（三个 Tab、基础连接管理），但数据协议、寄存器映射、控制逻辑、状态显示均未实现。

本阶段完成 `CentralizedControlManager.cpp` 全部实现（共 1775 行），涵盖五个子 Phase。

---

## 实现内容

### Phase 7.48.88.111 — SubStationStatus 结构 + 初始化框架

**文件**：`src/control/CentralizedControlManager.cpp`（新建）、`src/control/CentralizedControlManager.h`（更新）

- 新增 `SubStationStatus` 结构体，包含：运行状态、电机位图、模拟量（速度/张力/电流/电压/振动/温度/环境量×16）、开关量、保护字节、连接健康字段
- 新增 `SubStationStatus::toVariantMap()` 供 QML 绑定
- `initSlots()`：初始化 8 个槽位数据
- `initTimers()`：注册 4 个定时器（pollTimer 500ms、heartbeatTimer 3s、healthCheckTimer 3s、statusPublishTimer 500ms）
- 角色属性 setter、MQTT 配置 setter、槽位配置操作、依赖注入接口（`setCommonControl`、`setSystemConfig` 等）
- `saveConfig / loadConfig`：QSettings 持久化全量配置
- 大端浮点转换工具函数（与 `TCPDataAdapter::floatToBytes` 对称）

---

### Phase 7.48.88.112 — 主站 S7 轮询解析 + DB2 控制命令

**核心方法**：`pollS7SlotStatus`、`parseS7DB1`、`buildS7DB2Command`、`sendS7Command`

#### DB1 解析映射（只读，复用 TCPDataAdapter::syncS7DB1 逆操作）

| 字节偏移 | 内容 |
|---|---|
| 0 | DO 输出状态 |
| 1 | DI 反馈状态 |
| 2 | DI 模块1（急停/拉绳/跑偏/撕裂/烟雾/温度/护网/堆煤） |
| 3 | DI 模块2 |
| 4 | 主急停状态 |
| 5 | 电机运行位图（bit0-7 = 电机1-8） |
| 9 | 保护汇总字节 |
| 44-91 | 速度/张力/电流×2/电压×2/振动×4/温度×2（REAL, 大端） |
| 140-203 | 16个环境模拟量（REAL） |

#### DB2 控制映射（可写）

| 字节 | 控制内容 |
|---|---|
| 1 | 皮带控制：bit0=启动, bit1=停止, bit2=急停 |
| 6 | 电机启动位图 |
| 7 | 电机停止位图 |
| 10 | 复位：bit0=保护, bit2=故障 |
| 11 | 目标皮带编号 |

---

### Phase 7.48.88.113 — 主站 Modbus 轮询 + 控制

**核心方法**：`pollModbusSlotStatus`、`parseModbusDiscreteInputs`、`parseModbusInputRegisters`、`sendModbusCommand`、`sendModbusRegister`

#### 离散输入映射

| DI 地址 | 内容 |
|---|---|
| 0-7 | DO 输出反馈 |
| 8-15 | DI 反馈 |
| 16-23 | DI 模块1 |
| 24-31 | DI 模块2 |
| 32 | 主急停 |
| 40-47 | 电机运行位图 |
| 56-63 | 保护汇总位 |

#### 输入寄存器映射（FLOAT32，每值占2寄存器）

| IR 起始 | 内容 |
|---|---|
| 0 | 速度 |
| 2 | 张力 |
| 4/6 | 电机1/2电流 |
| 8/10 | 电机1/2电压 |
| 12-19 | 振动×4 |
| 20/22 | 电机1/2温度 |
| 62-93 | 16个环境模拟量 |

#### 控制线圈/寄存器

| 地址 | 类型 | 内容 |
|---|---|---|
| 8 | Coil | 皮带启动 |
| 9 | Coil | 皮带停止 |
| 10 | Coil | 皮带急停 |
| 20 | Holding | 目标皮带编号 |
| 21 | Holding | 复位保护 |
| 22 | Holding | 复位故障 |

---

### Phase 7.48.88.114 — MQTT 协议 + 分站被动模式

**核心方法**：`setupMqttSubscriptions`、`handleMqttMessage`、`handleMqttStatusMessage`、`publishLocalStatus`、`handleRemoteCommand`

#### Topic 命名规范

```
主站订阅（接收分站数据）：
  {topicPrefix}{deviceId}/status      — 状态上报 (500ms, QoS 1)
  {topicPrefix}{deviceId}/heartbeat   — 心跳 (3s, QoS 0)
  {topicPrefix}{deviceId}/alarm       — 报警 (触发时, QoS 1)

分站订阅（接收主站命令）：
  {topicPrefix}{localDeviceId}/command   — 点对点命令
  {topicPrefix}broadcast/command         — 广播命令
```

#### 状态上报 JSON 格式

```json
{
  "ver": 1, "ts": 1714000000000, "deviceId": 3, "stationId": 2,
  "run":    { "state": 2, "faultCode": 0 },
  "motor":  { "byte": 3, "states": [true,true,false,...] },
  "analog": { "speed": 3.25, "tension": 120.5, "m1Current": 45.2, ... },
  "di":     { "doStates": 3, "diFeedback": 3, "protByte": 0 },
  "runtime":{ "dailySec": 28800, "isFault": false }
}
```

#### 控制命令路由（分站模式）

| cmd | 路由到 CommonControl |
|---|---|
| start_belt | startBelt(beltNumber) |
| stop_belt | stopBelt(beltNumber) |
| emergency_stop | emergencyStopBelt(beltNumber) |
| reset_protection | systemConfig->setProperty("resetProtection", true) |
| reset_fault | systemConfig->setProperty("resetFault", true) |

---

### Phase 7.48.88.115 — 心跳 + 连接健康监测 + 自动重连

**核心方法**：`checkConnectionHealth`、`handleSlotOnline`、`handleSlotOffline`、`attemptReconnect`

#### 超时判定

| 协议 | 超时阈值 | 说明 |
|---|---|---|
| S7 / Modbus | 3000ms | 500ms 轮询，超 3s 无更新 |
| MQTT | 9000ms | 心跳 3s，连续 3 次未收 |

#### 自动重连退避策略

| 重连次数 | 等待时间 |
|---|---|
| 第1次 | 5s |
| 第2次 | 10s |
| 第3次 | 20s |
| 第4次及以后 | 60s |

MQTT 分站通过心跳感知，不需要主动重连。

---

## 控制命令汇总（三协议对照）

| 命令 | S7 (DB2) | Modbus | MQTT |
|---|---|---|---|
| 启动皮带 | Byte1 bit0=1 | Coil 8 = true | cmd: start_belt |
| 停止皮带 | Byte1 bit1=1 | Coil 9 = true | cmd: stop_belt |
| 急停 | Byte1 bit2=1 | Coil 10 = true | cmd: emergency_stop |
| 单电机启动 | Byte6 对应bit=1 | Coil 8 代替 | cmd: motor_start |
| 单电机停止 | Byte7 对应bit=1 | Coil 9 代替 | cmd: motor_stop |
| 复位保护 | Byte10 bit0=1 | HR 21 = 1 | cmd: reset_protection |
| 复位故障 | Byte10 bit2=1 | HR 22 = 1 | cmd: reset_fault |

---

## 修改的文件

| 文件 | 类型 |
|---|---|
| `src/control/CentralizedControlManager.cpp` | 新建，1775 行 |
| `src/control/CentralizedControlManager.h` | 更新，新增 SubStationStatus、定时器、控制方法声明 |
