# Modbus TCP 测试方案 - 8电机全覆盖语音报警测试

**日期**: 2026-03-13 (北京时间)
**目的**: 临时测试语音报警功能是否完整覆盖8个电机的所有保护类型

---

## 一、测试环境

| 项目 | 配置 |
|------|------|
| 模拟从站IP | 192.168.10.142 |
| 端口 | 502（Modbus TCP默认） |
| 模拟工具 | 电脑上运行 Modbus TCP 从站模拟器 |
| 寄存器类型 | 保持寄存器（功能码0x03） |

---

## 二、数据流设计

### 现有活跃报警链路（MQTT方式）

```
MQTT设备 → AIDataManager.channelChanged(moduleIndex, channelIndex, ChannelData)
         → MqttProtectionMonitor.onAIChannelChanged()
         → DeviceConfigManager.loadAllAnalogProtections(beltNumber)
         → 匹配保护配置（module_type + register_address）
         → 超限检测 → AlarmPlaybackService 播放报警语音
```

### 测试方案：Modbus TCP → 注入 AIDataManager 通道

```
Modbus TCP从站(192.168.10.142)
    ↓ NetworkTask轮询
    ↓ PT100/4-20mA公式转换 → AD值
    ↓ 构造 ChannelData
    ↓ 直接调用 AIDataManager.channelChanged 信号
    ↓ （复用整条MQTT报警链路）
MqttProtectionMonitor.onAIChannelChanged()
    ↓ 超限检测 → 语音报警
```

**关键点**：不新建报警链路，而是将 Modbus TCP 数据转换后注入现有 AIDataManager 信号通道，复用 MqttProtectionMonitor 完整链路。

---

## 三、寄存器地址规划

### 3.1 总体布局

每个电机分配16个连续寄存器（13个用+3个备用），8个电机共128个寄存器。

```
电机1: 寄存器 0  - 15
电机2: 寄存器 16 - 31
电机3: 寄存器 32 - 47
电机4: 寄存器 48 - 63
电机5: 寄存器 64 - 79
电机6: 寄存器 80 - 95
电机7: 寄存器 96 - 111
电机8: 寄存器 112 - 127
```

### 3.2 单个电机内部寄存器映射

每个电机的16个寄存器偏移量（基地址 = motorIndex × 16）：

| 偏移 | 保护类型 | Tab索引 | 传感器类型 | 转换公式 | 单位 |
|------|---------|---------|-----------|---------|------|
| 0 | 电流保护 | 1 | 4-20mA | 4-20mA公式 | A |
| 1 | 前轴承温度 | 2 | PT100 | PT100公式 | ℃ |
| 2 | 后轴承温度 | 3 | PT100 | PT100公式 | ℃ |
| 3 | A相绕组温度 | 4 | PT100 | PT100公式 | ℃ |
| 4 | B相绕组温度 | 5 | PT100 | PT100公式 | ℃ |
| 5 | C相绕组温度 | 6 | PT100 | PT100公式 | ℃ |
| 6 | 电机温度 | 7 | PT100 | PT100公式 | ℃ |
| 7 | X轴振动 | 8 | 4-20mA | 4-20mA公式 | mm/s |
| 8 | Y轴振动 | 9 | 4-20mA | 4-20mA公式 | mm/s |
| 9 | 堵转保护 | 10 | 4-20mA | 4-20mA公式 | A |
| 10 | 起动超时 | 11 | 4-20mA | 4-20mA公式 | A |
| 11 | 功率保护 | 12 | 4-20mA | 4-20mA公式 | kW |
| 12 | 三相不平衡 | 13 | 4-20mA | 4-20mA公式 | % |
| 13 | 备用 | - | - | - | - |
| 14 | 备用 | - | - | - | - |
| 15 | 备用 | - | - | - | - |

---

## 四、数据转换公式

### 4.1 PT100 温度转换

```cpp
// 原始公式（来自嵌入式代码）：
// tCoreIn->AnalogCurrentValue = (float)((float)(PT100Data*250) / 4096.0f - 50.0f);
//
// 温度范围：-50℃ ~ +200℃
// rawValue 0    → -50℃
// rawValue 4096 → +200℃
//
// 转换为AD值（反向，用于注入AIDataManager）：
// Modbus原始值(0-4095) → AD值(0-65535)
// adValue = rawValue * 65535 / 4096 = rawValue * 16（近似）

double pt100ToTemperature(quint16 rawValue) {
    return (double)(rawValue * 250) / 4096.0 - 50.0;
}

// 反向：温度 → Modbus寄存器值（模拟器设置用）
quint16 temperatureToRaw(double tempC) {
    return (quint16)((tempC + 50.0) * 4096.0 / 250.0);
}
// 示例：
//   25℃  → (75 × 4096/250) = 1228.8 ≈ 1229
//   100℃ → (150 × 4096/250) = 2457.6 ≈ 2458
//   150℃ → (200 × 4096/250) = 3276.8 ≈ 3277
```

### 4.2 4-20mA 电流型转换

```cpp
// 原始公式（来自嵌入式代码）：
// tCoreIn->AnalogCurrentValue = ((float)(rawValue - 819) * Range) / (float)(4096 - 819);
//
// 4mA  对应 rawValue = 819  → 物理量 = 0
// 20mA 对应 rawValue = 4096 → 物理量 = Range（量程）
// < 819 = 欠量程（传感器断线/故障）
//
// Range 由保护配置中的 range_value 字段决定

double currentLoopToValue(quint16 rawValue, double range) {
    if (rawValue < 819) return 0.0;  // 欠量程
    return ((double)(rawValue - 819) * range) / (double)(4096 - 819);
}

// 反向：物理值 → Modbus寄存器值（模拟器设置用）
quint16 valueToCurrentLoopRaw(double value, double range) {
    if (range <= 0) return 819;
    return (quint16)(value * (4096 - 819) / range + 819);
}
// 示例（Range=100A电流保护）：
//   0A   → 819
//   50A  → 819 + 50×3277/100 = 819 + 1638.5 ≈ 2458
//   100A → 4096
```

---

## 五、与 MqttProtectionMonitor 的对接

### 5.1 MqttProtectionMonitor.onAIChannelChanged 参数说明

```cpp
void onAIChannelChanged(int moduleIndex, int channelIndex, const ChannelData &data);
```

- **moduleIndex**: AI模块全局索引（2=模拟量模块1, 3=模拟量模块2）
  - 内部转换：`aiLocalIndex = moduleIndex - 2`（0或1）
- **channelIndex**: 通道索引（0-7）
- **data.adValue**: AD转换值（0-65535）

### 5.2 保护配置匹配逻辑

```
1. 根据 aiLocalIndex 确定 module_type（"模拟量模块1" 或 "模拟量模块2"）
2. 根据 m_aiBeltMapping[aiLocalIndex] 确定皮带编号
3. loadAllAnalogProtections(beltNumber) 加载该皮带所有保护配置
4. 匹配条件：module_type 相同 AND register_address == channelIndex
5. AD值转工程量：engineeringValue = lowerLimit + (adValue / 65535.0) * rangeValue
6. 对比上��限，超限则触发报警
```

### 5.3 Modbus → AIDataManager 注入方案

每个电机的数据需要映射到 `(moduleIndex, channelIndex)`：

**映射规则**：
- 目前 AIDataManager 只有2个模块（module 2和3，即aiLocalIndex 0和1）
- 每个模块8通道，共16个通道
- 每个电机需要13个通道

**方案**：为 Modbus TCP 数据扩展 AIDataManager 的模块索引范围，或者直接调用 MqttProtectionMonitor.onAIChannelChanged。

每个电机可以映射为一个虚拟AI模块：
- 电机1 → aiLocalIndex=0（moduleIndex=2），通道0-7 + aiLocalIndex=1（moduleIndex=3），通道0-4
- 但这会和MQTT的AI数据冲突...

**更简单的方案**：直接在 NetworkTask 中调用 MqttProtectionMonitor 的检测逻辑，不经过 AIDataManager。

---

## 六、已确认信息

- **8个电机属于同一条皮带**（beltNumber 相同）
- **堵转/起动超时/功率/三相不平衡** 通过电流通道数据计算，不需要独立传感器
- 每电机实际需要 **9个独立通道**（6×PT100 + 3×4-20mA）

## 七、关键发现 - 两套保护配置

| 配置表 | 用途 | 监控类 |
|--------|------|--------|
| `device_analog_protections` | 皮带模拟量保护（速度、张力等） | MqttProtectionMonitor ✅ 活跃 |
| `device_motor_config` | 电机保护（绕组温度、轴承温度等） | **无监控** ❌ 需要新建 |

**MqttProtectionMonitor 只监控 `device_analog_protections`，不监控 `device_motor_config`。**

### device_motor_config 表结构（关键字段）

```
device_id         → 皮带编号
motor_index       → 电机索引（0-7）
tab_index         → 保护类型（1=电流, 2=前轴承温度, ... 13=三相不平衡）
input_type        → "PT100热电阻" 或 "4-20mA电流型"
module_type       → "模拟量模块1"
register_address  → 通道号
range_value       → 量程
upper_limit       → 上限
lower_limit       → 下限
protection_delay  → 保护延时
```

### 默认保护配置（initDefaultMotorConfigs）

| Tab | 保护类型 | input_type | 上限 | 下限 | 量程 | 延时 |
|-----|---------|------------|------|------|------|------|
| 1 | 电流保护 | 4-20mA电流型 | 80A | 0 | 100A | 30 |
| 2 | 前轴承温度 | PT100热电阻 | 60℃ | 0 | 150℃ | 50 |
| 3 | 后轴承温度 | PT100热电阻 | 60℃ | 0 | 150℃ | 50 |
| 4 | A相绕组 | PT100热电阻 | 130℃ | 0 | 200℃ | 50 |
| 5 | B相绕组 | PT100热电阻 | 130℃ | 0 | 200℃ | 50 |
| 6 | C相绕组 | PT100热电阻 | 130℃ | 0 | 200℃ | 50 |
| 7 | 电机温度 | PT100热电阻 | 80℃ | 0 | 150℃ | 50 |
| 8 | X轴振动 | 4-20mA电流型 | 7mm/s | 0 | 20mm/s | 100 |
| 9 | Y轴振动 | 4-20mA电流型 | 7mm/s | 0 | 20mm/s | 100 |
| 10 | 堵转保护 | 4-20mA电流型 | 500A | 0 | 1000A | 80 |
| 11 | 起动超时 | 4-20mA电流型 | 300A | 0 | 500A | 300 |
| 12 | 功率保护 | 4-20mA电流型 | 150kW | 10 | 500kW | 100 |
| 13 | 三相不平衡 | 4-20mA电流型 | 30% | 0 | 100% | 100 |

## 八、实际需要的寄存器（简化版）

堵转/起动超时/功率/三相不平衡通过电流通道计算，不需要独立传感器。

每电机实际需要9个独立寄存器：

| 偏移 | 保护类型 | Tab | 传感器 | 转换公式 |
|------|---------|-----|--------|---------|
| 0 | 电流保护 | 1 | 4-20mA | (raw-819)×Range/(4096-819) |
| 1 | 前轴承温度 | 2 | PT100 | raw×250/4096-50 |
| 2 | 后轴承温度 | 3 | PT100 | raw×250/4096-50 |
| 3 | A相绕组温度 | 4 | PT100 | raw×250/4096-50 |
| 4 | B相绕组温度 | 5 | PT100 | raw×250/4096-50 |
| 5 | C相绕组温度 | 6 | PT100 | raw×250/4096-50 |
| 6 | 电机温度 | 7 | PT100 | raw×250/4096-50 |
| 7 | X轴振动 | 8 | 4-20mA | (raw-819)×Range/(4096-819) |
| 8 | Y轴振动 | 9 | 4-20mA | (raw-819)×Range/(4096-819) |

每电机分配 **12个寄存器**（9用+3备用），8电机共96个寄存器（地址0-95）。

```
电机1: 寄存器 0  - 11
电机2: 寄存器 12 - 23
电机3: 寄存器 24 - 35
电机4: 寄存器 36 - 47
电机5: 寄存器 48 - 59
电机6: 寄存器 60 - 71
电机7: 寄存器 72 - 83
电机8: 寄存器 84 - 95
```

## 九、实施方案

### 方案：在 MqttProtectionMonitor 中新增电机保护监控

1. **NetworkTask**：连接 192.168.10.142，轮询寄存器 0-95
2. **新增信号**：`motorRegisterReceived(int motorIndex, int tabIndex, quint16 rawValue)`
3. **MqttProtectionMonitor 新增函数**：`onMotorRegisterReceived()`
   - 加载 `device_motor_config` 中该电机该Tab的保护配置
   - 根据 `input_type` 选择 PT100 或 4-20mA 转换公式
   - 对比阈值，超限触发 AlarmPlaybackService
4. **连接**：NetworkTask → MqttProtectionMonitor
