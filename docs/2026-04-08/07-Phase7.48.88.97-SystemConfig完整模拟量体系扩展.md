# Phase 7.48.88.97 SystemConfig完整模拟量体系扩展

## 修复日期
2026-04-08

## 背景
Phase 7.48.88.96 为 SystemConfig 添加了 18 个模拟量保护值的 WRITE setter（速度、张力 + 16个电机1/2属性），解决了电机配置和TCP映射表中值始终为0的问题。但系统实际有更多模拟量值：
- 18 个环境保护项（速度、张力、温度一、温度二、温度、湿度、甲烷、粉尘浓度、煤流、煤仓高度、电压、烟雾、气压、氧气、一氧化碳、硫化氢、二氧化碳、风速）
- 8 个电机 × 14 个保护Tab（基本配置、电流、前轴承温度、后轴承温度、甲相绕组、乙相绕组、丙相绕组、电机温度、水平振动、垂直振动、堵转保护、起动超时、功率保护、三相不平衡）

用户要求"全部加入，包括8个电机全部加入"。

## 修改内容

### 1. SystemConfig.h — 完整模拟量体系

#### 新增环境模拟量（16项新增 + 2项已有）
| 属性名 | 保护名称 | 成员变量 |
|--------|----------|----------|
| speedValue | 速度 | m_speedValue |
| tensionValue | 张力 | m_tensionValue |
| temperature1Value | 温度一 | m_temperature1Value |
| temperature2Value | 温度二 | m_temperature2Value |
| temperatureValue | 温度 | m_temperatureValue_env |
| humidityValue | 湿度 | m_humidityValue |
| methaneValue | 甲烷 | m_methaneValue |
| dustValue | 粉尘浓度 | m_dustValue |
| coalFlowValue | 煤流 | m_coalFlowValue |
| siloHeightValue | 煤仓高度 | m_siloHeightValue |
| voltageValue | 电压 | m_voltageValue |
| smokeValue | 烟雾 | m_smokeValue_env |
| pressureValue | 气压 | m_pressureValue |
| oxygenValue | 氧气 | m_oxygenValue |
| coValue | 一氧化碳 | m_coValue |
| h2sValue | 硫化氢 | m_h2sValue |
| co2Value | 二氧化碳 | m_co2Value |
| windSpeedValue | 风速 | m_windSpeedValue |

注意：`temperatureValue`（环境温度）和 `smokeValue`（环境烟雾）的成员变量加了`_env`后缀，避免与开关量保护的 `temperatureActive`/`smokeActive` 混淆。

#### 电机保护值存储架构改造
- **旧方案**（Phase 7.48.88.96）：18个独立成员变量（m_motor1CurrentValue等），只支持1/2号电机
- **新方案**（Phase 7.48.88.97）：`double m_motorValues[8][14]` 二维数组
  - 行 = motorIndex (0-7)，8个电机
  - 列 = tabIndex (0-13)，14个保护Tab
  - Tab 0（基本配置）不存储保护值，但预留位置

#### Tab索引常量
```cpp
static constexpr int MOTOR_TAB_COUNT = 14;
static constexpr int MOTOR_COUNT = 8;
static constexpr int TAB_BASIC = 0;        // 基本配置（无保护值）
static constexpr int TAB_CURRENT = 1;      // 电流保护
static constexpr int TAB_FRONT_BEARING = 2;// 前轴承温度
static constexpr int TAB_REAR_BEARING = 3; // 后轴承温度
static constexpr int TAB_WINDING_A = 4;    // 甲相绕组
static constexpr int TAB_WINDING_B = 5;    // 乙相绕组
static constexpr int TAB_WINDING_C = 6;    // 丙相绕组
static constexpr int TAB_MOTOR_TEMP = 7;   // 电机温度
static constexpr int TAB_X_VIBRATION = 8;  // 水平振动
static constexpr int TAB_Y_VIBRATION = 9;  // 垂直振动
static constexpr int TAB_STALL = 10;       // 堵转保护
static constexpr int TAB_START_TIMEOUT = 11;// 起动超时
static constexpr int TAB_POWER = 12;       // 功率保护
static constexpr int TAB_IMBALANCE = 13;   // 三相不平衡
```

#### 通用访问接口
```cpp
Q_INVOKABLE double motorProtectionValue(int motorIndex, int tabIndex) const;
Q_INVOKABLE void setMotorProtectionValue(int motorIndex, int tabIndex, double value);
```

#### 向后兼容
- 旧的 motor1/2 Q_PROPERTY（如 motor1CurrentValue）保留不变
- Getter 从数组读取：`motor1CurrentValue() { return m_motorValues[0][TAB_CURRENT]; }`
- Setter 委托到数组：`setMotor1CurrentValue(v) { setMotorProtectionValue(0, TAB_CURRENT, v); }`
- emitMotorCompatSignal()：数组值变化时同时 emit 旧的 motor1/2 专用信号
- 电压保留独立变量（来自模拟量保护表，不属于电机Tab）

### 2. SystemConfig.cpp — setter 实现

- 18 个环境模拟量 setter（setTemperature1Value, setHumidityValue 等）
- `motorProtectionValue()` / `setMotorProtectionValue()` 实现
- `emitMotorCompatSignal()` 实现
- 16 个兼容 setter 委托到 `setMotorProtectionValue()`

### 3. MqttProtectionMonitor.cpp — 映射函数扩展

#### updateSystemConfigFromAI()
- 旧：仅映射5项（速度/张力/电压/1号电流/2号电流）
- 新：全部18项环境保护名称完整映射

#### updateSystemConfigFromMotor()
- 旧：仅支持 motorIndex 0-1，switch-case 分别调用 motor1/2 专用 setter
- 新：直接调用 `m_systemConfig->setMotorProtectionValue(motorIndex, tabIndex, value)`
- 支持全部8个电机（0-7）和全部14个Tab（0-13）

### 4. TCPDataAdapter.h — 输入寄存器地址扩展

#### 新增寄存器区域
| 地址范围 | 内容 | 说明 |
|----------|------|------|
| 62-93 | 环境模拟量（16个FLOAT32） | 温度一/二、温度、湿度、甲烷等 |
| 94-117 | 电机1-2扩展Tab（12个FLOAT32） | 前/后轴承、堵转、起动超时、功率、不平衡 |
| 120-287 | 电机3-8完整数据块 | 每电机28寄存器（13个Tab + 电压） |

- IR_TOTAL_COUNT 从 100 扩展到 300

#### 电机3-8地址计算
```
基地址 = IR_MOTOR_BLOCK_START + (motorIndex - 2) × IR_MOTOR_BLOCK_SIZE
Tab偏移 = (tabIndex - 1) × 2
```
例：5号电机电流 = 120 + (4-2)×28 + (1-1)×2 = 176

### 5. TCPDataAdapter.cpp — 同步逻辑扩展

- syncInputRegisters() 新增16个环境 syncFloat 调用
- 新增 syncMotorTab lambda：通过 motorProtectionValue() 读取数组值
- 电机1-2：新增6×2个扩展Tab同步
- 电机3-8：循环同步全部13个Tab

## 数据流总览

### 环境模拟量路径
```
MQTT → AIDataManager → channelChanged → MqttProtectionMonitor.onAIChannelChanged
  → updateSystemConfigFromAI("甲烷", 1.5)
  → SystemConfig.setMethaneValue(1.5)
  → emit methaneValueChanged()
  → TCPDataAdapter.syncFloat(IR_METHANE_START, "methaneValue")
  → Modbus从站输入寄存器 30071-30072
```

### 电机保护值路径（全8电机）
```
NetworkTask → motorRegisterReceived(3, 1, rawValue) // 4号电机电流
  → MqttProtectionMonitor.onMotorRegisterReceived
  → updateSystemConfigFromMotor(3, 1, 25.6)
  → SystemConfig.setMotorProtectionValue(3, 1, 25.6)
  → m_motorValues[3][1] = 25.6
  → emit motorProtectionValueChanged(3, 1, 25.6)
  → TCPDataAdapter: base = 120 + (3-2)*28 = 148, addr = 148 + (1-1)*2 = 148
  → Modbus从站输入寄存器 30149-30150
```

## 涉及文件
- `src/control/SystemConfig.h` — 完整重写：环境属性 + 电机数组 + Tab常量 + 通用接口
- `src/control/SystemConfig.cpp` — 完整重写：18个环境setter + 数组setter + 兼容setter + emitMotorCompatSignal
- `src/control/MqttProtectionMonitor.cpp` — 扩展updateSystemConfigFromAI/FromMotor
- `src/control/TCPDataAdapter.h` — 新增IR常量（环境+电机1-2扩展+电机3-8数据块），IR_TOTAL_COUNT=300
- `src/control/TCPDataAdapter.cpp` — 扩展syncInputRegisters和getInputRegisterMap
