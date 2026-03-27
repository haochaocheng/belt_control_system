# Phase 7.48.88.41 - 模拟量数据隔离到本机卡片

## 修改时间
2026-03-27

## 问题描述

8个卡片的速度、电流、温度、张力参数全部显示相同数据。这些数据来自本机传感器（AI模拟量模块和Modbus电机保护），应仅在本机设备对应的卡片上显示。

## 根因分析

三个函数将本机传感器数据应用到所有卡片：

1. **`applyAnalogChannelUpdate()`**：遍历所有8个卡片检查通道映射匹配。由于所有卡片的数据库配置可能指向相同的物理通道，导致所有卡片显示相同速度/张力值。

2. **`onMotorValueUpdated()`**：直接用 `motorIndex` 作为卡片索引 `dataItems[motorIndex]`。本机设备只有自己的电机数据，但写入了错误的卡片位置。

3. **`refreshMappedAnalogValues()`**：遍历所有8个卡片触发刷新。

## 修复方案

三个函数都改为仅更新 `localIdx = getLocalDeviceId() - 1` 对应的本机卡片。

### applyAnalogChannelUpdate() - 只匹配本机卡片的传感器映射

```javascript
var localIdx = getLocalDeviceId() - 1
var item = dataItems[localIdx]
var mappingGroup = beltSensorMappings[localIdx]
```

### onMotorValueUpdated() - 电机数据写入本机卡片

```javascript
var localIdx = getLocalDeviceId() - 1
var item = dataItems[localIdx]
```

### refreshMappedAnalogValues() - 只刷新本机卡片

```javascript
var localIdx = getLocalDeviceId() - 1
var mappingGroup = beltSensorMappings[localIdx]
```

## 修改文件

| 文件 | 修改内容 |
|------|----------|
| `src/qml/Input1/Input1Content/Screen01.qml` | 三个数据更新函数限制为仅更新本机卡片 |
