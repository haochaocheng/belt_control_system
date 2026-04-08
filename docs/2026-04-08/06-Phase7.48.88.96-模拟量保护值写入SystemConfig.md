# Phase 7.48.88.96 模拟量保护值写入SystemConfig

## 修复日期
2026-04-08

## 问题描述

### 问题1：电机配置-状态监控-电流值始终显示0.0A
**现象**：用户将2号电机电流保护的模块类型改为"模拟量模块1"、通道改为0。MQTT数据显示通道0有值（AD值47242），但电机配置BasicConfigTab中状态监控的电流值始终为0.0A。

**根因**：
1. `SystemConfig`中所有模拟量保护值属性（motor2CurrentValue等）为READ-ONLY，没有WRITE setter
2. `MqttProtectionMonitor.onAIChannelChanged()`只检查`device_analog_protections`表中的保护项，不检查`device_motor_config`表
3. 用户在电机配置中将module_type设为"模拟量模块1"，AI通道数据到来时不会触发`motorValueUpdated`信号

### 问题2：TCP从站映射表-输入寄存器-电机2电流为0
**现象**：Modbus从站映射表中"输入寄存器电机2电流"数据来源为`systemConfig.motor2CurrentValue`，始终为0。

**根因**：同上，SystemConfig中motor2CurrentValue属性没有WRITE setter，值始终为初始值0.0。

## 修复方案

### 1. SystemConfig添加WRITE setter（SystemConfig.h + SystemConfig.cpp）
- 为所有18个模拟量保护值属性添加WRITE setter：
  - speedValue, tensionValue
  - motor1CurrentValue, motor2CurrentValue
  - motor1VoltageValue, motor2VoltageValue
  - motor1/2 XVibrationValue, YVibrationValue
  - motor1/2 TemperatureValue
  - motor1/2 PhaseA/B/CWindingValue
- Q_PROPERTY声明从`READ + NOTIFY`改为`READ + WRITE + NOTIFY`
- setter使用`qFuzzyCompare(1.0 + old, 1.0 + new)`避免零值比较问题

### 2. MqttProtectionMonitor写入SystemConfig（MqttProtectionMonitor.h + .cpp）
- 新增`m_systemConfig`成员和`setSystemConfig()`注入方法
- 新增`updateSystemConfigFromAI()`：按保护名称映射到SystemConfig属性
  - "速度" → speedValue
  - "张力" → tensionValue
  - "电压" → motor1VoltageValue
  - "1号电机电流"/"电流" → motor1CurrentValue
  - "2号电机电流" → motor2CurrentValue
- 新增`updateSystemConfigFromMotor()`：按motorIndex+tabIndex映射
  - tabIndex 1→电流, 4→甲相绕组, 5→乙相绕组, 6→丙相绕组, 7→温度, 8→X振动, 9→Y振动
- 在`onAIChannelChanged()`中：
  - 计算工程量后调用`updateSystemConfigFromAI()`
  - 新增：查询`device_motor_config`中使用当前AI通道的电机配置，计算工程量并emit `motorValueUpdated`
- 在`onMotorRegisterReceived()`中：
  - 计算工程量后调用`updateSystemConfigFromMotor()`

### 3. DeviceConfigManager新增查询函数
- `findMotorConfigsByAIChannel(deviceId, moduleType, channelIndex)` — 按AI模块和通道查找电机配置

### 4. main.cpp连接
- `mqttProtectionMonitor.setSystemConfig(&systemConfig)` 注入SystemConfig引用

## 数据流修复后

### AI通道数据路径（模拟量模块）
```
MQTT → AIDataManager → channelChanged → MqttProtectionMonitor.onAIChannelChanged
  → updateSystemConfigFromAI()     → SystemConfig属性更新 → TCPDataAdapter读取
  → findMotorConfigsByAIChannel()  → motorValueUpdated信号 → BasicConfigTab QML显示
```

### 电机寄存器数据路径（Modbus TCP）
```
NetworkTask → motorRegisterReceived → MqttProtectionMonitor.onMotorRegisterReceived
  → updateSystemConfigFromMotor()  → SystemConfig属性更新 → TCPDataAdapter读取
  → motorValueUpdated信号          → BasicConfigTab QML显示
```

## 涉及文件
- `src/control/SystemConfig.h` — Q_PROPERTY添加WRITE，声明18个setter
- `src/control/SystemConfig.cpp` — 实现18个setter
- `src/control/MqttProtectionMonitor.h` — 新增SystemConfig成员和辅助函数声明
- `src/control/MqttProtectionMonitor.cpp` — 实现SystemConfig写入逻辑和电机配置AI通道匹配
- `src/control/DeviceConfigManager.h` — 声明findMotorConfigsByAIChannel()
- `src/control/DeviceConfigManager.cpp` — 实现findMotorConfigsByAIChannel()
- `src/main/main.cpp` — 注入SystemConfig到MqttProtectionMonitor
