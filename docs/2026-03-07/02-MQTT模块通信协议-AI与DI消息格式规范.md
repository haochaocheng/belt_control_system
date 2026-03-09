# MQTT 模块通信协议 — AI 与 DI 消息格式规范

**日期**：2026-03-07
**用途**：硬件模块（模拟量/开关量）通过 MQTT 上报数据的标准消息格式
**来源**：`src/mqtt/AIDataManager.cpp`、`src/mqtt/DIDataManager.cpp`、`src/mqtt/MQTTAutoManager.cpp`

---

## 一、Topic 规范

| 模块类型   | Topic 格式                            | 示例                             | QoS |
|:----------:|:--------------------------------------|:---------------------------------|:---:|
| 开关量模块1 | `belt_control/di/module1/status`      | 上报8路开关量状态                | 1   |
| 开关量模块2 | `belt_control/di/module2/status`      | 上报8路开关量状态                | 1   |
| 模拟量模块1 | `belt_control/ai/module1/status`      | 上报8路模拟量AD值                | 1   |
| 模拟量模块2 | `belt_control/ai/module2/status`      | 上报8路模拟量AD值                | 1   |

**控制主题**（上位机下发控制命令）：

| 模块类型   | Topic 格式                            | 说明                             |
|:----------:|:--------------------------------------|:---------------------------------|
| 开关量模块  | `belt_control/di/module{N}/control`   | 下发开关量控制命令               |
| 模拟量模块  | `belt_control/ai/module{N}/control`   | 下发模拟量控制命令               |

---

## 二、AI（模拟量）消息格式

### 2.1 完整 JSON 格式

```json
{
  "module": 1,
  "type": "ai",
  "timestamp": 1707456789,
  "data": {
    "channels": [
      {"value": 1234, "voltage": 0.94},
      {"value": 2345, "voltage": 1.79},
      {"value": 3456, "voltage": 2.64},
      {"value": 4567, "voltage": 3.49},
      {"value": 5678, "voltage": 4.34},
      {"value": 6789, "voltage": 5.19},
      {"value": 7890, "voltage": 6.03},
      {"value": 8901, "voltage": 6.80}
    ]
  },
  "quality": "good"
}
```

### 2.2 字段说明

| 层级 | 字段名 | 类型 | 必填 | 取值范围 | 说明 |
|:----:|:------:|:----:|:----:|:--------:|:-----|
| 根   | module | int | 否 | 1, 2 | 模块编号（代码不解析，仅靠 topic 区分） |
| 根   | type | string | 否 | "ai" | 模块类型（代码不解析） |
| 根   | timestamp | int64 | **是** | Unix 时间戳 | 数据采集时间，存入每个通道的 `ch.timestamp` |
| 根   | data | object | **是** | — | 数据对象，必须包含 `channels` 字段 |
| 根   | quality | string | 否 | "good" 等 | 数据质量标记（代码不解析） |
| data | channels | array | **是** | 长度必须为 **8** | 8个通道的数据对象数组 |
| channels[i] | value | int | **是** | 0 ~ 65535 | AD 原始值（`quint16`） |
| channels[i] | voltage | double | **是** | 0.0 ~ 10.0 | 对应电压值 |

### 2.3 关键约束

1. **`data.channels` 必须是对象数组**，不是整数数组
   - ✅ 正确：`"channels": [{"value": 1234, "voltage": 0.94}, ...]`
   - ❌ 错误：`"channels": [1234, 2345, ...]`
2. **`channels` 数组长度必须为 8**，否则解析失败
3. **`timestamp` 字段被实际使用**，存入 `ChannelData.timestamp`
4. **`module` 和 `quality` 字段不被解析**，模块区分依靠 MQTT topic

### 2.4 模拟量模块通道分配

#### 模拟量模块1（topic: `belt_control/ai/module1/status`）

| 通道(CH) | channels[index] | 保护名称 | 单位  |
|:--------:|:---------------:|:--------:|:-----:|
| 0        | channels[0]     | 速度     | m/s   |
| 1        | channels[1]     | 张力     | T     |
| 2        | channels[2]     | 温度一   | ℃     |
| 3        | channels[3]     | 温度二   | ℃     |
| 4        | channels[4]     | 电压     | V     |
| 5        | channels[5]     | 甲烷     | %CH₄  |
| 6        | channels[6]     | 一氧化碳 | ppm   |
| 7        | channels[7]     | 二氧化碳 | %CO₂  |

#### 模拟量模块2（topic: `belt_control/ai/module2/status`）

| 通道(CH) | channels[index] | 保护名称 | 单位    |
|:--------:|:---------------:|:--------:|:-------:|
| 0        | channels[0]     | 硫化氢   | ppm     |
| 1        | channels[1]     | 氧气     | %O₂    |
| 2        | channels[2]     | 烟雾     | mg/m³  |
| 3        | channels[3]     | 粉尘浓度 | mg/m³  |
| 4        | channels[4]     | 温度（环境） | ℃ |
| 5        | channels[5]     | 湿度     | %RH    |
| 6        | channels[6]     | 煤流     | t/h     |
| 7        | channels[7]     | 煤仓高度 | m       |

> **✅ 2026-03-07 [Phase 7.48.22] 通道按截图顺序分配**：前8项=模块1 CH0-7，后8项=模块2 CH0-7，16个通道全部独立分配。

---

## 三、DI（开关量）消息格式

### 3.1 完整 JSON 格式

DI 模块支持两种数据格式：**bits 数组格式**和 **byte 格式**，二选一。

#### 格式 A：bits 数组（推荐）

```json
{
  "module": 1,
  "type": "di",
  "timestamp": 1707456789,
  "data": {
    "bits": [1, 0, 1, 0, 0, 1, 0, 0]
  }
}
```

#### 格式 B：byte 整数

```json
{
  "module": 1,
  "type": "di",
  "timestamp": 1707456789,
  "data": {
    "byte": 37
  }
}
```

> byte = 37 的二进制为 `00100101`，即 bit0=1, bit2=1, bit5=1，其余为0。

### 3.2 字段说明

| 层级 | 字段名 | 类型 | 必填 | 取值范围 | 说明 |
|:----:|:------:|:----:|:----:|:--------:|:-----|
| 根   | module | int | 否 | 1, 2 | 模块编号（代码不解析） |
| 根   | type | string | 否 | "di" | 模块类型（代码不解析） |
| 根   | timestamp | int64 | 否 | Unix 时间戳 | 时间戳（代码不使用） |
| 根   | data | object | **是** | — | 数据对象，必须包含 `bits` 或 `byte` |
| data | bits | array | **二选一** | 长度必须为 **8** | 8路开关状态，0=OFF / 非0=ON |
| data | byte | int | **二选一** | 0 ~ 255 | 8路开关状态的位压缩，bit0=CH0 |

### 3.3 关键约束

1. **`data` 对象内必须包含 `bits` 或 `byte`**，缺少两者都会解析失败
2. **优先解析 `bits`**：如果同时存在 `bits` 和 `byte`，只使用 `bits`
3. **`bits` 数组长度必须为 8**，否则解析失败
4. **`bits` 中的值**：`0` 表示 OFF，`非0`（如 `1`）表示 ON
5. **`byte` 字段的位顺序**：bit0 对应 CH0（LSB first）
   - 例：`byte=5`（二进制 `00000101`）→ CH0=ON, CH1=OFF, CH2=ON, 其余 OFF

### 3.4 byte 与 bits 换算示例

| byte 值 | 二进制       | bits 数组                    | 含义                     |
|:--------:|:------------|:-----------------------------|:-------------------------|
| 0        | `00000000`  | `[0,0,0,0,0,0,0,0]`         | 全部 OFF                 |
| 1        | `00000001`  | `[1,0,0,0,0,0,0,0]`         | 仅 CH0 ON               |
| 5        | `00000101`  | `[1,0,1,0,0,0,0,0]`         | CH0 + CH2 ON            |
| 37       | `00100101`  | `[1,0,1,0,0,1,0,0]`         | CH0 + CH2 + CH5 ON      |
| 255      | `11111111`  | `[1,1,1,1,1,1,1,1]`         | 全部 ON                  |

---

## 四、代码解析流程

### 4.1 AI 数据流

```
硬件模块 → MQTT Broker
    ↓ topic: belt_control/ai/module{1,2}/status
MQTTController → onModuleMessageReceived()
    ↓
MQTTAutoManager → updateLastDataTime() + emit moduleDataReceived()
    ↓
AIDataManager::parseData(moduleIndex, payload)
    ↓ moduleIndex: 2=模块1, 3=模块2 → dataIndex: 0, 1
AIDataManager::parseJsonData(dataIndex, payload)
    ↓ 解析 JSON → data.channels[8] → 每个通道的 value + voltage
    ↓ applyFilter() 滤波处理
detectChanges() → emit channelChanged() / dataChanged()
    ↓
MqttProtectionMonitor::onAIChannelChanged() → 保护逻辑判断
```

### 4.2 DI 数据流

```
硬件模块 → MQTT Broker
    ↓ topic: belt_control/di/module{1,2}/status
MQTTController → onModuleMessageReceived()
    ↓
MQTTAutoManager → updateLastDataTime() + emit moduleDataReceived()
    ↓
DIDataManager::parseData(moduleIndex, payload)
    ↓ moduleIndex: 0=模块1, 1=模块2
DIDataManager::parseJsonData(moduleIndex, payload)
    ↓ 解析 JSON → data.bits[8] 或 data.byte → 8路布尔值
detectChanges() → emit bitChanged() / dataChanged()
    ↓
MqttProtectionMonitor::onDIBitChanged() → 保护逻辑判断
```

---

## 五、测试用 MQTT 发送命令

使用 `mosquitto_pub` 测试（EMQX 或 Mosquitto Broker）：

### AI 模块1 测试

```bash
mosquitto_pub -h localhost -t "belt_control/ai/module1/status" -q 1 -m '{
  "timestamp": 1707456789,
  "data": {
    "channels": [
      {"value": 32768, "voltage": 2.50},
      {"value": 16384, "voltage": 1.25},
      {"value": 49152, "voltage": 3.75},
      {"value": 49152, "voltage": 3.75},
      {"value": 45000, "voltage": 3.44},
      {"value": 0, "voltage": 0.00},
      {"value": 20000, "voltage": 1.53},
      {"value": 10000, "voltage": 0.76}
    ]
  }
}'
```

### DI 模块1 测试（bits 格式）

```bash
mosquitto_pub -h localhost -t "belt_control/di/module1/status" -q 1 -m '{
  "timestamp": 1707456789,
  "data": {
    "bits": [1, 0, 1, 0, 0, 1, 0, 0]
  }
}'
```

### DI 模块1 测试（byte 格式）

```bash
mosquitto_pub -h localhost -t "belt_control/di/module1/status" -q 1 -m '{
  "timestamp": 1707456789,
  "data": {
    "byte": 37
  }
}'
```

---

**文档版本**：v1.0
**创建时间**：2026-03-07
**状态**：已确认（与代码完全一致）
