# Phase 7.48.88.2 - 4-20mA/1-5V 工程量公式零点偏移修正

## 修改时间
2026-03-24 (北京时间)

## 问题描述

模拟量列表→速度保护，输入类型选择 4-20mA，外部输入 4mA 信号，工程量应显示 0 m/s，但界面显示 1.6 m/s。

### 根因分析

原公式：
```
engineeringValue = lowerLimit + (adValue / 65535) × rangeValue
```

此公式将 ADC=0 映射为工程量下限，ADC=65535 映射为工程量上限。

但 4-20mA 传感器的特点是：
- **4mA = 量程零点**（对应工程量下限）
- **20mA = 量程满点**（对应工程量上限）
- 4mA 在 16 位 ADC 中对应 65535 × 20% = **13107**

以速度保护为例（lower_limit=0.5, range=5.0）：
- 输入 4mA → ADC ≈ 13107
- 旧公式：`0.5 + (13107/65535) × 5.0 = 0.5 + 1.0 = 1.5 m/s` ❌ （用户看到 ≈1.6）
- 正确值：`0.5 + 0 = 0.5 m/s`（4mA = 零点，工程量 = 下限）

## 修复方案

### 新公式（4-20mA / 1-5V）

```
adZero = 65535 × 0.2 = 13107  // 4mA/1V 对应的 ADC 零点
if (adValue <= adZero):
    engineeringValue = lowerLimit  // 钳位到下限
else:
    engineeringValue = lowerLimit + ((adValue - adZero) / (65535 - adZero)) × rangeValue
```

### 无偏移公式（0-20mA / 0-5V / 0-10V）

保持原公式不变：
```
engineeringValue = lowerLimit + (adValue / 65535) × rangeValue
```

### 输入类型判断

通过 `input_type` 字段（数据库字段，QML 属性 `root.inputType`）判断：
- 包含 "4-20mA" 或 "1-5V" → 使用零点偏移公式
- 其他（0-20mA, 0-5V, 0-10V）→ 使用原公式

## 修改文件

| 文件 | 修改内容 |
|------|---------|
| `src/control/MqttProtectionMonitor.cpp` | `onAIChannelChanged()` 读取 `input_type`，4-20mA/1-5V 使用零点偏移公式 |
| `src/qml/components/device_info/pages/AnalogInputPage.qml` | 两处工程量计算（实时更新 + 手动刷新）均增加 4-20mA/1-5V 零点偏移 |

## 验证方法

1. 速度保护，输入类型 4-20mA，输入 4mA → 工程量显示 ≈ 0.5 m/s（下限值）
2. 速度保护，输入类型 4-20mA，输入 20mA → 工程量显示 ≈ 5.5 m/s（下限+量程）
3. 速度保护，输入类型 4-20mA，输入 12mA（中点）→ 工程量显示 ≈ 3.0 m/s
4. 输入类型 0-20mA 的保护项 → 工程量计算不受影响（使用原公式）
5. MqttProtectionMonitor 保护检测使用同样的修正公式
