# Phase 7.48.42 - 电机保护 Modbus TCP 测试模式实现

**日期**: 2026-03-13 (北京时间)
**阶段**: Phase 7.48.42

---

## 一、功能概述

实现 Modbus TCP 测试模式，用于测试8个电机的全覆盖语音报警功能。

**数据流**：
```
Modbus TCP从站(192.168.10.142:502)
    ↓ NetworkTask 轮询96个寄存器(0-95)
    ↓ processMotorRegisters 映射到 (motorIndex, tabIndex)
    ↓ 发射 motorRegisterReceived 信号
    ↓ MqttProtectionMonitor.onMotorRegisterReceived()
    ↓ 从 device_motor_config 加载保护配置
    ↓ PT100/4-20mA 转换公式
    ↓ 超限检测（边沿触发）
    ↓ AlarmPlaybackService 语音报警
```

---

## 二、修改文件

### 2.1 NetworkTask.h

- 新增常量：`MOTOR_COUNT=8`, `REGS_PER_MOTOR=12`, `MOTOR_PROTECTIONS=9`, `TOTAL_MOTOR_REGS=96`
- 新增信号：`motorRegisterReceived(int motorIndex, int tabIndex, quint16 rawValue)`
- 新增方法：`setMotorTestMode(bool, QString ip, int port)`
- 新增私有函数：`processMotorRegisters()`
- 新增成员：`m_motorTestMode`, `m_motorTestIp`, `m_motorTestPort`

### 2.2 NetworkTask.cpp

- 构造函数初始化测试模式成员
- `connectToServer()`: 测试模式使用独立IP
- `setMotorTestMode()`: 设置测试模式参数，支持运行中切换
- `onPollTimerTimeout()`: 测试模式下轮询0-47和48-95两段寄存器
- `onReadSuccess()`: 测试模式下调用`processMotorRegisters()`
- `processMotorRegisters()`: 将寄存器地址映射为(motorIndex, tabIndex)并发射信号

### 2.3 MqttProtectionMonitor.h

- 新增 public slot：`onMotorRegisterReceived(int motorIndex, int tabIndex, quint16 rawValue)`
- 新增私有静态函数：`convertPT100(quint16 rawValue)`, `convert420mA(quint16 rawValue, double range)`
- 新增成员：`m_motorProtectionAlarmActive` (边沿触发状态追踪)

### 2.4 MqttProtectionMonitor.cpp

- `convertPT100()`: PT100温度转换 (rawValue×250/4096 - 50)
- `convert420mA()`: 4-20mA电流型转换 ((rawValue-819)×Range/(4096-819))
- `onMotorRegisterReceived()`:
  - 加载 `device_motor_config` 配置
  - 根据 `input_type` 选择转换公式
  - 边沿触发超限检测
  - 触发 `AlarmPlaybackService.playAlarm()`
  - 发射 `analogProtectionTriggered`/`analogProtectionRestored` 信号

### 2.5 main.cpp

- 连接 `NetworkTask::motorRegisterReceived` → `MqttProtectionMonitor::onMotorRegisterReceived`
- 设置 `systemConfig` 并启用电机测试模式
- 自动调用 `networkTask.start()`

---

## 三、寄存器映射

每电机12个寄存器（9用+3备用），8电机共96个：

| 电机 | 寄存器范围 | 偏移0-8对应Tab |
|------|-----------|---------------|
| 电机1 | 0-11 | 1=电流, 2=前轴承, 3=后轴承, 4-6=绕组, 7=电机温度, 8=X振动, 9=Y振动 |
| 电机2 | 12-23 | 同上 |
| ... | ... | ... |
| 电机8 | 84-95 | 同上 |

---

## 四、转换公式

| 类型 | 公式 | 范围 |
|------|------|------|
| PT100 | temperature = raw × 250 / 4096 - 50 | -50℃ ~ +200℃ |
| 4-20mA | value = (raw - 819) × Range / (4096 - 819) | 0 ~ Range |

---

## 五、测试方法

1. 电脑运行 Modbus TCP 从站模拟器，IP 192.168.10.142，端口 502
2. 设置保持寄存器 0-95 的值
3. 应用程序自动连接并轮询
4. 修改寄存器值使其超过阈值，观察语音报警是否触发
