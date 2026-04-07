# TCP控制完善方案 - Modbus点表与S7数据块分配

## 创建日期
2026-04-07 (北京时间)

## 一、问题背景

TCP控制当前只定义了协议连接参数（IP/端口/超时等），**没有定义数据具体放在哪里**。需要完善：
1. Modbus TCP 寄存器点表（地址分配）
2. S7 协议数据块映射
3. 数据适配层（本机数据 ↔ 寄存器/数据块自动同步）
4. QML界面（数据映射可视化）

## 二、两级控制架构

```
┌─────────────┐     Modbus TCP / S7     ┌──────────────────┐
│  上位机PLC   │ ◄─────────────────────► │  本机（从站/服务器）│
│  (主站/客户端) │     读写本机寄存器       │  自动刷新本机数据   │
└─────────────┘                         └──────────────────┘
                                               │
                                               │ Modbus TCP / S7
                                               ▼
                                        ┌──────────────────┐
                                        │  其他设备（从站）   │
                                        │  本机作为主站读写   │
                                        └──────────────────┘
```

- **从站模式**：本机被动响应上位机PLC的读写请求，自动将本机实时数据刷新到寄存器中
- **主站模式**：本机主动轮询读取其他设备的寄存器数据

## 三、本机数据清单

### 3.1 数据源（C++后端已实现）

| 数据管理器 | 数据内容 | 位/字数 |
|-----------|---------|---------|
| DODataManager | 8路DO输出状态 + 8路DI反馈 + 急停 | 17 bit |
| DIDataManager | 2模块×8位 = 16路开关量输入 | 16 bit |
| AIDataManager | 2模块×8通道 = 16路16位AD值 | 16 word |
| CSDataManager | 3类保护×64点位 = 沿线保护 | 192 bit |
| SystemConfig | 工作模式/本机编号/保护值(18个float) | ~40 word |
| CommonControl | 8电机/8制动器/2张紧/8洒水运行状态 | 26 bit |

### 3.2 控制命令（上位机可下发）

| 命令 | 说明 |
|------|------|
| DO输出控制 | 继电器1-8开关 |
| 启动/停止皮带 | 触发启停序列 |
| 紧急停车 | 急停命令 |
| 工作模式切换 | 检修/就地/点动/集控 |

---

## 四、Modbus TCP 从站寄存器点表

遵循工控行业标准：
- **离散输入(1xxxx)** = 只读开关量状态
- **线圈(0xxxx)** = 可写开关量控制
- **输入寄存器(3xxxx)** = 只读模拟量/状态值
- **保持寄存器(4xxxx)** = 可读可写控制参数

### 4.1 离散输入区（10001+ / 只读 / 上位机只能读）

| Modbus地址 | 内部地址 | 数量 | 数据来源 | 说明 |
|-----------|---------|------|----------|------|
| 10001-10008 | 0-7 | 8 | DODataManager.doStates[0-7] | DO输出状态（继电器1-8） |
| 10009-10016 | 8-15 | 8 | DODataManager.diFeedback[0-7] | DO反馈状态（反馈1-8） |
| 10017 | 16 | 1 | DODataManager.estop | DO模块急停状态 |
| 10018-10025 | 17-24 | 8 | DIDataManager.module1[0-7] | DI模块1开关量1-8 |
| 10026-10033 | 25-32 | 8 | DIDataManager.module2[0-7] | DI模块2开关量9-16 |
| 10034-10041 | 33-40 | 8 | CommonControl | 电机运行状态（电机1-8） |
| 10042-10049 | 41-48 | 8 | CommonControl | 制动器状态（制动器1-8） |
| 10050-10051 | 49-50 | 2 | CommonControl | 张紧状态（张紧1-2） |
| 10052-10059 | 51-58 | 8 | CommonControl | 洒水状态（洒水1-8） |
| 10060-10067 | 59-66 | 8 | SystemConfig | 保护状态（急停/跑偏/撕裂/烟雾/温度/护网/堆煤/主急停） |
| **10101-10164** | 100-163 | 64 | CSDataManager[0] | 沿线急停（64点位） |
| **10201-10264** | 200-263 | 64 | CSDataManager[1] | 沿线跑偏（64点位） |
| **10301-10364** | 300-363 | 64 | CSDataManager[2] | 沿线撕裂（64点位） |
| **总计** | | **259** | | 建议分配400个离散输入 |

### 4.2 输入寄存器区（30001+ / 只读 / 16位）

| Modbus地址 | 内部地址 | 数量 | 类型 | 数据来源 | 说明 |
|-----------|---------|------|------|----------|------|
| 30001-30008 | 0-7 | 8 | UINT16 | AIDataManager.module3[0-7] | AI模块1（AD原始值0-65535） |
| 30009-30016 | 8-15 | 8 | UINT16 | AIDataManager.module4[0-7] | AI模块2（AD原始值0-65535） |
| 30017 | 16 | 1 | UINT16 | SystemConfig.machineNumber | 本机编号(1-8) |
| 30018 | 17 | 1 | UINT16 | SystemConfig.workMode | 工作模式(0检修/1就地/2点动/3集控) |
| 30019-30020 | 18-19 | 2 | FLOAT32 | SystemConfig.speedValue | 皮带速度 |
| 30021-30022 | 20-21 | 2 | FLOAT32 | SystemConfig.tensionValue | 张力值 |
| 30023-30024 | 22-23 | 2 | FLOAT32 | SystemConfig.motor1CurrentValue | 电机1电流 |
| 30025-30026 | 24-25 | 2 | FLOAT32 | SystemConfig.motor2CurrentValue | 电机2电流 |
| 30027-30028 | 26-27 | 2 | FLOAT32 | SystemConfig.motor1VoltageValue | 电机1电压 |
| 30029-30030 | 28-29 | 2 | FLOAT32 | SystemConfig.motor2VoltageValue | 电机2电压 |
| 30031-30032 | 30-31 | 2 | FLOAT32 | SystemConfig.motor1XVibrationValue | 电机1 X振动 |
| 30033-30034 | 32-33 | 2 | FLOAT32 | SystemConfig.motor1YVibrationValue | 电机1 Y振动 |
| 30035-30036 | 34-35 | 2 | FLOAT32 | SystemConfig.motor2XVibrationValue | 电机2 X振动 |
| 30037-30038 | 36-37 | 2 | FLOAT32 | SystemConfig.motor2YVibrationValue | 电机2 Y振动 |
| 30039-30040 | 38-39 | 2 | FLOAT32 | SystemConfig.motor1TemperatureValue | 电机1温度 |
| 30041-30042 | 40-41 | 2 | FLOAT32 | SystemConfig.motor2TemperatureValue | 电机2温度 |
| 30043-30048 | 42-47 | 6 | 3×FLOAT32 | SystemConfig.motor1PhaseA/B/CWinding | 电机1绕组ABC |
| 30049-30054 | 48-53 | 6 | 3×FLOAT32 | SystemConfig.motor2PhaseA/B/CWinding | 电机2绕组ABC |
| 30055 | 54 | 1 | UINT16 | DODataManager(packed) | DO状态打包(bit0-7) |
| 30056 | 55 | 1 | UINT16 | DODataManager(packed) | DI反馈打包(bit0-7) |
| 30057 | 56 | 1 | UINT16 | DIDataManager(packed) | DI模块1打包(8bit) |
| 30058 | 57 | 1 | UINT16 | DIDataManager(packed) | DI模块2打包(8bit) |
| 30059 | 58 | 1 | UINT16 | CommonControl(packed) | 电机状态打包(bit0-7) |
| 30060 | 59 | 1 | UINT16 | CommonControl(packed) | 制动器状态打包(bit0-7) |
| 30061 | 60 | 1 | UINT16 | CommonControl(packed) | 洒水+张紧打包(洒水bit0-7,张紧bit8-9) |
| 30062 | 61 | 1 | UINT16 | SystemConfig(packed) | 保护状态打包(8bit) |
| **总计** | | **62** | | 建议分配100个输入寄存器 |

> **FLOAT32说明**: IEEE754浮点数占2个寄存器，高字在前(Big-Endian)。
> 例：30019(HiWord) + 30020(LoWord) = 皮带速度浮点值

### 4.3 线圈区（00001+ / 可读可写 / 上位机控制命令）

| Modbus地址 | 内部地址 | 数量 | 数据目标 | 说明 |
|-----------|---------|------|----------|------|
| 00001-00008 | 0-7 | 8 | NetworkTask | DO输出控制（继电器1-8） |
| 00009 | 8 | 1 | CommonControl.startBelt(1) | 启动皮带（上升沿触发） |
| 00010 | 9 | 1 | CommonControl.stopBelt(1) | 停止皮带（上升沿触发） |
| 00011 | 10 | 1 | CommonControl.emergencyStop | 紧急停车（上升沿触发） |
| 00012-00019 | 11-18 | 8 | (预留) | 预留控制命令 |
| **总计** | | **19** | | 建议分配32个线圈 |

> **上升沿触发说明**: 启停/急停命令是脉冲式的，写1触发一次动作后自动清零。
> TCPDataAdapter检测到线圈从0→1时执行命令，然后立即将线圈清零。

### 4.4 保持寄存器区（40001+ / 可读可写）

| Modbus地址 | 内部地址 | 数量 | 类型 | 说明 |
|-----------|---------|------|------|------|
| 40001 | 0 | 1 | UINT16 | 工作模式设置(0-3) |
| 40002 | 1 | 1 | UINT16 | 本机编号设置(1-8) |
| 40003-40010 | 2-9 | 8 | UINT16 | DO输出控制字（与线圈联动） |
| 40011 | 10 | 1 | UINT16 | 心跳计数器（上位机写入，本机+1回写） |
| 40012-40020 | 11-19 | 9 | UINT16 | 预留控制参数 |
| **总计** | | **20** | | 建议分配32个保持寄存器 |

---

## 五、S7 从站数据块分配

### 5.1 DB1 - 设备状态区（只读，供上位机PLC读取）

| 偏移(Byte) | 长度 | S7类型 | 数据来源 | 说明 |
|------------|------|--------|----------|------|
| 0.0 | 1 byte | BYTE | DODataManager | DO输出状态(bit0-7=继电器1-8) |
| 1.0 | 1 byte | BYTE | DODataManager | DI反馈状态(bit0-7=反馈1-8) |
| 2.0 | 1 byte | BYTE | DIDataManager.module1 | DI模块1(bit0-7) |
| 3.0 | 1 byte | BYTE | DIDataManager.module2 | DI模块2(bit0-7) |
| 4.0 | 1 byte | BYTE | DODataManager.estop | 急停状态(0/1) |
| 5.0 | 1 byte | BYTE | CommonControl | 电机运行状态(bit0-7) |
| 6.0 | 1 byte | BYTE | CommonControl | 制动器状态(bit0-7) |
| 7.0 | 1 byte | BYTE | CommonControl | 洒水状态(bit0-7) |
| 8.0 | 1 byte | BYTE | CommonControl | 张紧状态(bit0-1) |
| 9.0 | 1 byte | BYTE | SystemConfig | 保护状态汇总(8bit) |
| 10.0 | 2 bytes | WORD | SystemConfig | 工作模式(高字节) + 本机编号(低字节) |
| 12.0-43.0 | 32 bytes | 16×WORD | AIDataManager | AI 16通道AD原始值 |
| 44.0-47.0 | 4 bytes | REAL | SystemConfig.speedValue | 皮带速度 |
| 48.0-51.0 | 4 bytes | REAL | SystemConfig.tensionValue | 张力值 |
| 52.0-55.0 | 4 bytes | REAL | motor1CurrentValue | 电机1电流 |
| 56.0-59.0 | 4 bytes | REAL | motor2CurrentValue | 电机2电流 |
| 60.0-63.0 | 4 bytes | REAL | motor1VoltageValue | 电机1电压 |
| 64.0-67.0 | 4 bytes | REAL | motor2VoltageValue | 电机2电压 |
| 68.0-71.0 | 4 bytes | REAL | motor1XVibrationValue | 电机1 X振动 |
| 72.0-75.0 | 4 bytes | REAL | motor1YVibrationValue | 电机1 Y振动 |
| 76.0-79.0 | 4 bytes | REAL | motor2XVibrationValue | 电机2 X振动 |
| 80.0-83.0 | 4 bytes | REAL | motor2YVibrationValue | 电机2 Y振动 |
| 84.0-87.0 | 4 bytes | REAL | motor1TemperatureValue | 电机1温度 |
| 88.0-91.0 | 4 bytes | REAL | motor2TemperatureValue | 电机2温度 |
| 92.0-115.0 | 24 bytes | 6×REAL | SystemConfig | 电机1/2绕组ABC(6个) |
| 116.0-123.0 | 8 bytes | 64×BOOL | CSDataManager[0] | 沿线急停(64点位) |
| 124.0-131.0 | 8 bytes | 64×BOOL | CSDataManager[1] | 沿线跑偏(64点位) |
| 132.0-139.0 | 8 bytes | 64×BOOL | CSDataManager[2] | 沿线撕裂(64点位) |
| **总计** | **140 bytes** | | | **建议分配256字节** |

### 5.2 DB2 - 控制命令区（可写，上位机PLC下发）

| 偏移(Byte) | 长度 | S7类型 | 数据目标 | 说明 |
|------------|------|--------|----------|------|
| 0.0 | 1 byte | BYTE | NetworkTask | DO输出控制字(bit0-7) |
| 1.0 | 1 bit | BOOL | CommonControl.startBelt | 启动皮带(上升沿) |
| 1.1 | 1 bit | BOOL | CommonControl.stopBelt | 停止皮带(上升沿) |
| 1.2 | 1 bit | BOOL | CommonControl.emergencyStop | 紧急停车(上升沿) |
| 2.0 | 1 byte | BYTE | SystemConfig | 工作模式切换(0-3) |
| 3.0 | 1 byte | BYTE | (预留) | 命令序列号 |
| 4.0-5.0 | 2 bytes | WORD | (心跳) | 心跳计数器 |
| **总计** | **6 bytes** | | | **建议分配64字节** |

---

## 六、C++后端完善方案

### 6.1 新建 TCPDataAdapter（核心适配层）

**文件**: `src/control/TCPDataAdapter.h / .cpp`

**职责**:
1. 持有所有数据管理器指针
2. 定时（100ms）从数据管理器采集数据 → 刷新到从站寄存器/S7数据块
3. 监听上位机写入事件 → 转发为控制命令
4. 提供Q_INVOKABLE供QML查看映射表和实时数据

```
数据流（从站模式）:
  MQTT → DODataManager/DIDataManager/AIDataManager
    → TCPDataAdapter.onSyncTimer() (100ms)
      → ModbusTCPSlaveController.setDiscreteInput/setInputRegister
      → S7ServerController.setDBData

数据流（上位机写入）:
  PLC → ModbusTCPSlaveController.handleDataWritten()
    → TCPDataAdapter.onCoilWritten/onHoldingRegisterWritten()
      → CommonControl.startBelt() / NetworkTask.writeDeviceControl()
```

### 6.2 完善 ModbusTCPMasterController.handlePollTimeout()

当前是空实现。完善后按配置的startRegister/registerCount自动轮询：
```cpp
void handlePollTimeout() {
    if (!isConnected()) return;
    readHoldingRegisters(m_startRegister, m_registerCount);
}
```

### 6.3 完善 S7ServerController 数据区管理

当前 registerDB()/setDBData()/getDBData() 是空壳。需要实现 Snap7 的 RegisterArea + 共享内存方案。

### 6.4 安全控制

- 检修模式(workMode=0)下拒绝远程启停命令
- 集控模式(workMode=3)下允许远程控制
- 线圈写入命令使用"上升沿触发+自动清零"防止重复执行

---

## 七、QML界面完善方案

### 7.1 从站Tab新增内容

在现有连接参数下方增加"数据映射表"区域：
- 标题分隔线: "数据映射表（自动同步）"
- 同步状态指示灯 + 同步间隔配置(SpinBox)
- ListView展示寄存器映射: [地址] [名称] [数据源] [当前值]
- 数据来自 TCPDataAdapter.getModbusRegisterMap()

### 7.2 主站Tab新增内容

在现有连接参数下方增加"轮询数据"区域：
- 读取模式下拉框（保持寄存器/输入寄存器/线圈/离散输入）
- 轮询数据实时展示ListView
- 手动写入面板（调试用）

### 7.3 新建 RegisterMapView.qml 组件

通用寄存器映射表格组件，供从站Tab复用：
- 支持地址排序和名称过滤
- 实时刷新当前值
- 不同数据类型格式化（UINT16/FLOAT32/BOOL）

---

## 八、实施步骤（优先级排序）

### Phase 1: 数据适配层（最高优先级，2-3天）
1. 新建 TCPDataAdapter.h/.cpp
2. 实现 Modbus 寄存器点表映射（离散输入、输入寄存器刷新）
3. 实现上位机写入的命令转发
4. 在 main.cpp 中实例化并连接数据管理器
5. 用 Modbus Poll 软件验证数据读取

### Phase 2: 完善控制器空实现（高优先级，1天）
1. ModbusTCPMasterController.handlePollTimeout()
2. S7ServerController registerDB/setDBData/getDBData（Snap7 RegisterArea）
3. S7ClientController.handlePollTimeout()
4. TCPDataAdapter增加S7 DB1同步

### Phase 3: QML从站数据映射界面（中优先级，2天）
1. 新建 RegisterMapView.qml
2. 修改 ModbusTCPSlaveTab.qml 增加映射表
3. 修改 S7SlaveTab.qml 增加DB映射表

### Phase 4: QML主站数据查看界面（中优先级，1-2天）
1. ModbusTCPMasterTab.qml 增加读取模式和数据展示
2. S7MasterTab.qml 增加轮询配置和数据展示

### Phase 5: 配置持久化和集成测试（1天）
1. 映射配置QSettings持久化
2. 端口1自动启动从站服务（可配置）
3. 上位机PLC集成测试

---

## 九、关键设计决策

| 决策 | 理由 |
|------|------|
| float用2个寄存器(HiWord+LoWord) | Modbus行业标准，IEEE754 32位需要2×16位寄存器 |
| 同步间隔100ms | 10Hz刷新率满足工控监控，可配置降到50ms |
| 线圈用上升沿触发 | 防止PLC持续写1导致重复启停 |
| 从站默认端口502 | Modbus TCP标准端口 |
| S7用DB1状态+DB2控制分离 | 工控惯例，读写权限清晰 |
| 检修模式拒绝远程命令 | 安全要求，防止检修时误操作 |
