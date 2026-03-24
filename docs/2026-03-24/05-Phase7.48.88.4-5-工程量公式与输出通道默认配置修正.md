# Phase 7.48.88.4+5 - 工程量公式修正 + 输出通道默认配置不冲突

## 修改时间
2026-03-24 (北京时间)

---

## Phase 7.48.88.4 - 工程量公式去掉 lowerLimit

### 问题描述

速度保护配置：输入类型 4-20mA，lower_limit=0.5 m/s，range=5.0 m/s。
皮带静止，速度传感器输出 4mA，工程量显示 0.5 m/s（应为 0 m/s）。

### 根因分析

4-20mA 工程量公式错误地将 `lower_limit`（保护报警阈值）当作传感器零点：

```
旧公式：engineeringValue = lowerLimit + ((adValue - adZero) / (65535 - adZero)) × rangeValue
```

- `lower_limit = 0.5` 是"低于此值触发下限报警"的阈值
- 不是传感器的工程量零点
- 4mA = 传感器物理零点，应映射到 0

对比已有的 `convert420mA()` 函数（电机保护用），其公式正确地不加 lowerLimit：
```cpp
return ((double)(rawValue - 819) * range) / (double)(4096 - 819);  // 4mA→0
```

### 修复公式

```
新公式（4-20mA/1-5V）：
    adZero = 65535 × 0.2 = 13107
    if (adValue <= adZero):
        engineeringValue = 0.0          // 不是 lowerLimit
    else:
        engineeringValue = ((adValue - adZero) / (65535 - adZero)) × rangeValue  // 不加 lowerLimit

新公式（0-20mA/0-5V/0-10V）：
    engineeringValue = (adValue / 65535.0) × rangeValue  // 不加 lowerLimit
```

### 修复前后对比

速度保护（lower_limit=0.5, range=5.0, 4-20mA）：

| 输入 | 修复前 | 修复后 |
|------|--------|--------|
| 4mA | 0.5 m/s ❌ | 0.0 m/s ✅ |
| 12mA (中点) | 3.0 m/s | 2.5 m/s ✅ |
| 20mA (满量程) | 5.5 m/s | 5.0 m/s ✅ |

lower_limit=0.5 现在仅用于报警：速度 < 0.5 m/s 时触发下限保护。

### 修改文件

| 文件 | 修改内容 |
|------|---------|
| `src/control/MqttProtectionMonitor.cpp` | `onAIChannelChanged()` 工程量公式去掉 lowerLimit |
| `src/qml/components/device_info/pages/AnalogInputPage.qml` | 两处工程量计算（实时+手动刷新）去掉 lower |

---

## Phase 7.48.88.5 - 输出通道默认配置不冲突 + 清理旧代码

### 问题描述

1. 电机、制动器、张紧控制的默认输出通道全部是 0，互相冲突
2. `CommonControl::getDeviceChannel()` 硬编码映射表已不使用（实际控制走 QML → MQTT 直接发布到 DO 模块）
3. 各 SpinBox 的通道范围仅 0-7，实际继电器模块有 16 个通道（0-15）

### 16 通道默认分配方案

常规配置（1 张紧 + 2 制动器 + 2 电机 + 8 洒水）：

| DO通道 | 默认分配 | 配置面板 | 默认值计算 |
|--------|---------|---------|-----------|
| 0 | 张紧控制 | TensionControlConfigPanel | value: 0 |
| 1 | 1号制动器 松闸 | BrakeConfigPanel | brakeIndex(0) + 1 |
| 2 | 2号制动器 松闸 | BrakeConfigPanel | brakeIndex(1) + 1 |
| 3 | 1号电机 | BasicConfigTab | motorIndex(0) + 3 |
| 4 | 2号电机 | BasicConfigTab | motorIndex(1) + 3 |
| 5 | 洒水1 | SprinklerConfigPanel | sprinklerIndex(0) + 5 |
| 6 | 洒水2 | SprinklerConfigPanel | sprinklerIndex(1) + 5 |
| 7-12 | 洒水3-8 | SprinklerConfigPanel | sprinklerIndex + 5 |
| 13-15 | 扩展备用 | - | - |

制动器抱闸通道默认 -1（不使用），仅松闸通道分配。

### 修改文件

| 文件 | 修改内容 |
|------|---------|
| `src/qml/.../BasicConfigTab.qml` | 电机默认通道 motorIndex → motorIndex+3，范围 0-15 |
| `src/qml/.../MotorControlPage.qml` | 默认配置 output_channel 同步修改 |
| `src/qml/.../BrakeConfigPanel.qml` | 松闸默认 brakeIndex+1，抱闸默认 -1（旧: 都是0） |
| `src/qml/.../TensionControlConfigPanel.qml` | 通道范围 0-7 → 0-15 |
| `src/qml/.../SprinklerConfigPanel.qml` | 默认通道 sprinklerIndex → sprinklerIndex+5，范围 0-15 |
| `src/control/CommonControl.h` | 注释 getDeviceChannel() 声明 |
| `src/control/CommonControl.cpp` | 注释 getDeviceChannel() 和 Modbus 控制调用 |

### 旧代码清理说明

`CommonControl::activateDevice()` 中通过 `getDeviceChannel()` → `NetworkTask::writeDeviceControl()` 控制 Modbus 寄存器的路径已注释。

实际设备控制流程：
```
QML配置面板 → outputChannelSpin.value（从数据库加载）
    → mqttController.publish("belt_control/do/module1/cmd", {channel: X, value: 1})
    → DO模块（Luckfox设备5）继电器输出
```

运行状态来源：
```
DO模块 → MQTT发布 do_states[0-7]
    → doDataManager.getDoState(outputChannelSpin.value)
    → QML LED 显示
```
