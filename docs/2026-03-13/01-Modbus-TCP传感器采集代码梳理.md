# Modbus TCP 传感器采集代码梳理

**日期**: 2026-03-13 (北京时间)
**背景**: RS485接口禁用，PT100模块（绕组/轴承温度）和4-20mA模块（电流等保护）改用Modbus TCP代替

---

## 一、现有代码结构总览

### 1. 核心传感器数据采集层

| 层级 | 文件 | 功能 |
|------|------|------|
| **底层通信** | `src/network/ModbusTcpClient.cpp/.h` | 基于 Qt SerialBus 的 TCP 客户端，读写寄存器 |
| **数据采集** | `src/network/NetworkTask.cpp/.h` | 自动轮询采集传感器数据（**核心采集类**） |
| **应用控制** | `src/control/ModbusTCPMasterController.cpp/.h` | TCP 主站高级接口，8个实例对应8个从站设备 |

### 2. 从站/RTU 相关

| 文件 | 功能 | 状态 |
|------|------|------|
| `src/control/ModbusTCPSlaveController.cpp/.h` | TCP从站（本设备作为从站） | 使用中 |
| `src/control/ModbusController.cpp/.h` | RTU串口主站（RS485） | **已禁用** |
| `src/control/ModbusSlaveController.cpp/.h` | RTU串口从站 | **已禁用** |

### 3. QML 配置界面

| 文件 | 功能 |
|------|------|
| `src/qml/components/device_info/pages/ModbusTCPMasterTab.qml` | TCP主站配置界面（9项参数） |
| `src/qml/components/device_info/pages/ModbusTCPSlaveTab.qml` | TCP从站配置界面（8项参数） |
| `src/qml/components/device_info/pages/ModbusRegisterTab.qml` | 寄存器操作界面（手动读写） |

---

## 二、NetworkTask 采集的传感器数据（寄存器映射）

| 寄存器范围 | 模块类型 | 采集内容 |
|-----------|---------|---------|
| Reg 2 (1个) | DI 数字输入模块1 | 急停、跑偏、撕裂、烟雾、温度、护网、堆煤、主机急停 |
| Reg 5-12 (8个) | AI 模拟量模块1 | 速度、张力、红外温度×2、电流×2、电压、1号电机温度 |
| Reg 13-20 (8个) | AI 模拟量模块2 | 2号电机温度、振动X/Y×2、**1号电机绕组温度** |
| Reg 21-23 (3个) | AI 模拟量模块3 | **2号电机三相绕组温度** |

---

## 三、关键类详情

### ModbusTcpClient（底层TCP客户端）

```
文件：src/network/ModbusTcpClient.h / .cpp
依赖：QModbusTcpClient (Qt6::SerialBus)
```

- `connectToServer(host, port)` - TCP连接
- `readHoldingRegisters(startAddress, count)` - 读取保持寄存器（功能码0x03）
- `writeSingleRegister(address, value)` - 写入单个寄存器（功能码0x06）
- 超时：3000ms，重试：1次，默认端口：502

### ModbusTCPMasterController（应用层控制器）

```
文件：src/control/ModbusTCPMasterController.h / .cpp
创建：Phase 7.42
```

- 属性：targetIP, port, slaveAddress, pollInterval, timeout, retryCount, startRegister, registerCount
- 方法：connectToServer, startPolling, stopPolling, readHoldingRegisters, readInputRegisters, readCoils, readDiscreteInputs
- 信号：holdingRegistersRead, inputRegistersRead, coilsRead, discreteInputsRead, errorOccurred
- 支持配置持久化（saveConfig / loadConfig / resetConfig）

### NetworkTask（自动轮询采集）

```
文件：src/network/NetworkTask.h / .cpp
功能：集成 ModbusTcpClient，定时轮询设备，采集传感器数据
```

- 串行化请求队列（防止堆积）
- 自动重连
- 只在值变化时打印日志
- 信号：registerValueReceived(int, quint16), connectionStatusChanged(bool)

---

## 四、main.cpp 中的实例化

```cpp
// RTU主站（RS485 - 已禁用）
ModbusController modbusController;

// 8个 TCP 主站（用于8个独立从站设备）
ModbusTCPMasterController modbusTcpMaster1 ~ modbusTcpMaster8;

// 8个 TCP 从站（用于本设备作为从站）
ModbusTCPSlaveController modbusTcpSlave1 ~ modbusTcpSlave8;
```

---

## 五、CMakeLists.txt 编译配置

| 文件 | 配置内容 |
|------|---------|
| `CMakeLists.txt`（根目录） | `SerialBus # Modbus TCP/RTU support` |
| `src/control/CMakeLists.txt` | 源文件列表 + `Qt6::SerialBus` 链接 |
| `src/network/CMakeLists.txt` | ModbusTcpClient + `Qt6::SerialBus` 链接 |

---

## 六、与当前需求的对应关系

### 需要采集的传感器

| 传感器类型 | 模块 | 接口 | 现状 |
|-----------|------|------|------|
| PT100 绕组温度 | PT100模块（8路输入） | 原RS485/Modbus → **改Modbus TCP** | 已在AI模块2/3寄存器中映射 |
| PT100 轴承温度 | PT100模块 | 同上 | 已在AI模块2/3寄存器中映射 |
| 4-20mA 电流 | 4-20mA模块 | 原RS485/Modbus → **改Modbus TCP** | 已在AI模块1寄存器中映射 |
| 4-20mA 其他保护 | 4-20mA模块 | 同上 | 已在AI模块1寄存器中映射 |

### 待确认问题

1. **NetworkTask** 目前是否已通过 Modbus TCP 采集这些数据？还是仍依赖 RTU 串口？
2. PT100模块的 Modbus TCP 网关 IP 和端口是什么？
3. 4-20mA模块的 Modbus TCP 网关 IP 和端口是什么？
4. 8个 ModbusTCPMasterController 实例分别对应哪些物理设备？

---

## 七、可能不再需要的代码

| 文件 | 原因 |
|------|------|
| `src/control/ModbusController.cpp/.h` | RTU串口主站，RS485已禁用 |
| `src/control/ModbusSlaveController.cpp/.h` | RTU串口从站，RS485已禁用 |
| 相关QML界面中的RTU配置部分 | RS485不再使用 |

**注意**：RTU代码暂时保留不删除，仅做标记，以防后续需要恢复。
