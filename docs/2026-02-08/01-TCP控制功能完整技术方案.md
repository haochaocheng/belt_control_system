# TCP控制功能完整技术方案

**文档编号**: 01-TCP控制功能完整技术方案
**创建日期**: 2026-02-08
**版本**: v1.0
**状态**: 技术方案

---

## 1. 需求概述

### 1.1 功能定位
在"开关量输入"大类下的"CAN控制"下一行增加新的"TCP控制"功能，作为 Modbus TCP 和西门子 S7 协议的控制界面。

### 1.2 界面结构
```
开关量输入
├── ... (其他子项)
├── CAN控制 (索引7)
├── TCP控制 (索引8) ← 新增
└── 逻辑控制 (索引9) ← 原索引8，需要后移
```

### 1.3 TCP控制界面布局
```
┌─────────────────────────────────────────────────────────────────┐
│ TCP控制                                                          │
├─────────────┬───────────────────────────────────────────────────┤
│ 端口列表    │ 参数区域                                           │
│             │ ┌─────────────────────────────────────────────────┤
│ ○ 端口1     │ │ [Modbus主站] [Modbus从站] [S7主站] [S7从站]     │
│ ○ 端口2     │ ├─────────────────────────────────────────────────┤
│ ○ 端口3     │ │                                                  │
│ ○ 端口4     │ │  参数配置内容                                    │
│ ○ 端口5     │ │                                                  │
│ ○ 端口6     │ │                                                  │
│ ○ 端口7     │ │                                                  │
│ ○ 端口8     │ │                                                  │
│             │ └─────────────────────────────────────────────────┤
├─────────────┴───────────────────────────────────────────────────┤
│ [打开连接] [关闭连接] [保存配置] [删除配置] [重置]               │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. 端口配置

### 2.1 端口列表
| 端口名称 | 默认端口号 | 说明 |
|---------|-----------|------|
| 端口1 | 502 | Modbus TCP 标准端口 |
| 端口2 | 503 | |
| 端口3 | 504 | |
| 端口4 | 505 | |
| 端口5 | 506 | |
| 端口6 | 507 | |
| 端口7 | 508 | |
| 端口8 | 509 | |

### 2.2 端口号规则
- 默认端口号：端口1 = 502，后续每个端口 +1
- 端口号可修改
- 范围：1-65535

---

## 3. Modbus TCP 参数配置

### 3.1 Modbus 主站参数

| 参数名 | 类型 | 默认值 | 说明 |
|-------|------|-------|------|
| 端口号 | int | 502-509 | TCP 端口号 |
| 状态 | enum | 关闭 | 打开/关闭 |
| 轮询时间 | float | 1.0 | 单位：0.1秒（100ms） |
| 目标IP | string | 192.168.1.1 | 从站设备IP地址 |
| 从站地址 | int | 1 | Modbus 从站地址 (1-247) |
| 起始寄存器 | int | 0 | 读取起始地址 |
| 寄存器数量 | int | 10 | 读取寄存器数量 |
| 超时时间 | int | 3000 | 单位：毫秒 |
| 重试次数 | int | 3 | 通信失败重试次数 |

### 3.2 Modbus 从站参数

| 参数名 | 类型 | 默认值 | 说明 |
|-------|------|-------|------|
| 端口号 | int | 502-509 | TCP 监听端口号 |
| 状态 | enum | 关闭 | 打开/关闭 |
| 从站地址 | int | 1 | 本机从站地址 (1-247) |
| 最大连接数 | int | 5 | 最大客户端连接数 |
| 保持寄存器数量 | int | 100 | Holding Registers 数量 |
| 输入寄存器数量 | int | 100 | Input Registers 数量 |
| 线圈数量 | int | 100 | Coils 数量 |
| 离散输入数量 | int | 100 | Discrete Inputs 数量 |

---

## 4. 西门子 S7 协议参数配置

### 4.1 推荐开源库：Snap7

**Snap7** 是最广泛使用的开源 S7 通信库：
- 官网：http://snap7.sourceforge.net/
- 支持 S7-200、S7-300、S7-400、S7-1200、S7-1500
- C/C++ 编写，跨平台
- 支持客户端（主站）和服务器（从站）模式

### 4.2 S7 主站（客户端）参数

| 参数名 | 类型 | 默认值 | 说明 |
|-------|------|-------|------|
| 端口号 | int | 102 | S7 标准端口（ISO TCP） |
| 状态 | enum | 关闭 | 打开/关闭 |
| 目标IP | string | 192.168.0.1 | PLC IP地址 |
| Rack | int | 0 | 机架号 |
| Slot | int | 2 | 槽号 |
| 连接类型 | enum | PG | PG/OP/Basic |
| Local TSAP | hex | 0x0100 | 本地传输服务访问点 |
| Remote TSAP | hex | 0x0302 | 远程传输服务访问点 |
| PDU大小 | int | 480 | 协议数据单元大小 |
| 轮询时间 | float | 1.0 | 单位：0.1秒 |
| 超时时间 | int | 5000 | 单位：毫秒 |

#### 4.2.1 Rack/Slot 参考值

| PLC型号 | Rack | Slot | 说明 |
|--------|------|------|------|
| S7-300 | 0 | 2 | 标准配置 |
| S7-400 | 0 | 2 或 3 | 根据实际配置 |
| S7-1200 | 0 | 0 或 1 | 新型PLC |
| S7-1500 | 0 | 0 或 1 | 新型PLC |

#### 4.2.2 TSAP 计算公式
```
Remote TSAP = 0x03xx
其中 xx = (Rack * 0x20) + Slot

示例：
- Rack=0, Slot=2 → 0x0302
- Rack=0, Slot=1 → 0x0301
```

#### 4.2.3 连接类型说明
| 类型 | 说明 |
|-----|------|
| PG | 编程设备连接（Programming Device） |
| OP | 操作面板连接（Operator Panel） |
| Basic | 基本连接（S7 Basic Communication） |

### 4.3 S7 从站（服务器）参数

| 参数名 | 类型 | 默认值 | 说明 |
|-------|------|-------|------|
| 端口号 | int | 102 | S7 标准端口 |
| 状态 | enum | 关闭 | 打开/关闭 |
| 绑定IP | string | 0.0.0.0 | 监听IP地址 |
| 最大连接数 | int | 8 | 最大客户端连接数 |
| DB数量 | int | 10 | 数据块数量 |
| DB大小 | int | 1024 | 每个DB的字节数 |
| Merker大小 | int | 256 | M区大小（字节） |
| 输入大小 | int | 128 | I区大小（字节） |
| 输出大小 | int | 128 | Q区大小（字节） |
| 定时器数量 | int | 64 | 定时器数量 |
| 计数器数量 | int | 64 | 计数器数量 |

---

## 5. 技术实现方案

### 5.1 文件结构

```
src/
├── controllers/
│   ├── TCPController.h              # TCP控制器基类
│   ├── TCPController.cpp
│   ├── ModbusTCPMasterController.h  # Modbus TCP 主站控制器
│   ├── ModbusTCPMasterController.cpp
│   ├── ModbusTCPSlaveController.h   # Modbus TCP 从站控制器
│   ├── ModbusTCPSlaveController.cpp
│   ├── S7ClientController.h         # S7 客户端（主站）控制器
│   ├── S7ClientController.cpp
│   ├── S7ServerController.h         # S7 服务器（从站）控制器
│   └── S7ServerController.cpp
│
├── qml/components/device_info/pages/
│   ├── TCPControlPage.qml           # TCP控制主页面
│   ├── TCPConfigPanel.qml           # TCP配置面板（Tab容器）
│   ├── ModbusTCPMasterTab.qml       # Modbus主站Tab
│   ├── ModbusTCPSlaveTab.qml        # Modbus从站Tab
│   ├── S7MasterTab.qml              # S7主站Tab
│   └── S7SlaveTab.qml               # S7从站Tab
│
└── libs/
    └── snap7/                        # Snap7库（需要集成）
        ├── snap7.h
        ├── snap7.cpp
        └── ...
```

### 5.2 类图

```
┌─────────────────────┐
│   TCPController     │ (基类)
│─────────────────────│
│ - port: int         │
│ - status: bool      │
│ - pollInterval: int │
│─────────────────────│
│ + open()            │
│ + close()           │
│ + saveConfig()      │
└─────────┬───────────┘
          │
    ┌─────┴─────┬─────────────┬─────────────┐
    │           │             │             │
┌───▼───┐  ┌────▼────┐  ┌─────▼─────┐  ┌────▼────┐
│Modbus │  │ Modbus  │  │    S7     │  │   S7    │
│TCP    │  │  TCP    │  │  Client   │  │ Server  │
│Master │  │ Slave   │  │Controller │  │Controller│
└───────┘  └─────────┘  └───────────┘  └─────────┘
```

### 5.3 依赖库

#### 5.3.1 Modbus TCP
- **Qt SerialBus 模块**：Qt 官方 Modbus 实现
  - `QModbusTcpClient`：Modbus TCP 主站
  - `QModbusTcpServer`：Modbus TCP 从站

#### 5.3.2 S7 协议
- **Snap7 库**：开源 S7 通信库
  - 需要下载并集成到项目中
  - 官网：http://snap7.sourceforge.net/
  - GitHub 镜像：https://github.com/SCADACS/snap7

### 5.4 Qt 集成 Snap7

#### 5.4.1 下载 Snap7
```bash
# 从 SourceForge 下载
wget https://sourceforge.net/projects/snap7/files/latest/download -O snap7.zip

# 或从 GitHub 克隆
git clone https://github.com/SCADACS/snap7.git
```

#### 5.4.2 CMakeLists.txt 配置
```cmake
# 添加 Snap7 库
set(SNAP7_DIR ${CMAKE_SOURCE_DIR}/libs/snap7)
include_directories(${SNAP7_DIR}/src/core)
include_directories(${SNAP7_DIR}/src/lib)

# 编译 Snap7 源码
add_library(snap7 STATIC
    ${SNAP7_DIR}/src/core/s7_client.cpp
    ${SNAP7_DIR}/src/core/s7_server.cpp
    ${SNAP7_DIR}/src/core/s7_partner.cpp
    ${SNAP7_DIR}/src/core/s7_micro_client.cpp
    ${SNAP7_DIR}/src/core/s7_peer.cpp
    ${SNAP7_DIR}/src/core/s7_text.cpp
    ${SNAP7_DIR}/src/core/s7_isotcp.cpp
    ${SNAP7_DIR}/src/lib/snap7_libmain.cpp
)

target_link_libraries(${PROJECT_NAME} snap7)
```

---

## 6. 实施计划

### 6.1 阶段一：基础框架（预计工作量：中）
1. 修改 DeviceSettingsDialog.qml，添加 TCP控制 类别
2. 创建 TCPControlPage.qml 主页面
3. 创建 TCPConfigPanel.qml Tab 容器
4. 实现端口列表（8个端口）

### 6.2 阶段二：Modbus TCP 实现（预计工作量：中）
1. 创建 ModbusTCPMasterController（复用 Qt SerialBus）
2. 创建 ModbusTCPSlaveController
3. 创建 ModbusTCPMasterTab.qml
4. 创建 ModbusTCPSlaveTab.qml
5. 测试 Modbus TCP 通信

### 6.3 阶段三：S7 协议实现（预计工作量：高）
1. 集成 Snap7 库到项目
2. 创建 S7ClientController（主站）
3. 创建 S7ServerController（从站）
4. 创建 S7MasterTab.qml
5. 创建 S7SlaveTab.qml
6. 测试 S7 通信

### 6.4 阶段四：完善和测试（预计工作量：低）
1. 键盘导航支持
2. 虚拟键盘支持
3. 配置保存/加载
4. 完整功能测试

---

## 7. 风险和注意事项

### 7.1 Snap7 集成风险
- **端口冲突**：S7 使用端口 102，需要 root 权限（Linux）
- **Windows 冲突**：如果安装了 Step 7 或 TIA Portal，需要停止 s7oiehsx 服务
- **交叉编译**：需要为 ARM64 平台编译 Snap7

### 7.2 Modbus TCP 注意事项
- 与串口 Modbus RTU 共享寄存器数据结构
- 需要处理多客户端连接

### 7.3 界面一致性
- 参考 CAN控制 和 串口控制 的界面风格
- 保持键盘导航逻辑一致

---

## 8. 参考资料

### 8.1 Snap7 官方文档
- 官网：http://snap7.sourceforge.net/
- 客户端文档：http://snap7.sourceforge.net/snap7_client.html
- 服务器文档：http://snap7.sourceforge.net/snap7_server.html

### 8.2 Qt SerialBus 文档
- Modbus TCP：https://doc.qt.io/qt-6/qtserialbus-modbus-tcp-example.html

### 8.3 项目内部参考
- CAN控制实现：`src/qml/components/device_info/pages/CANControlPage.qml`
- 串口控制实现：`src/qml/components/device_info/pages/SerialPortControlPage.qml`
- Modbus RTU 实现：`src/controllers/ModbusSlaveController.cpp`

---

## 9. 附录

### 9.1 Snap7 主要 API

#### 客户端（主站）
```cpp
// 创建客户端
TS7Client *client = new TS7Client();

// 连接到 PLC
int result = client->ConnectTo("192.168.0.1", 0, 2);  // IP, Rack, Slot

// 设置连接参数
client->SetConnectionParams("192.168.0.1", 0x0100, 0x0302);  // IP, LocalTSAP, RemoteTSAP

// 读取数据块
byte buffer[100];
client->DBRead(1, 0, 100, buffer);  // DB号, 起始地址, 长度, 缓冲区

// 写入数据块
client->DBWrite(1, 0, 100, buffer);

// 断开连接
client->Disconnect();
```

#### 服务器（从站）
```cpp
// 创建服务器
TS7Server *server = new TS7Server();

// 注册数据区域
byte DB1[1024];
server->RegisterArea(srvAreaDB, 1, DB1, sizeof(DB1));

// 设置事件回调
server->SetEventsCallback(EventCallback, NULL);

// 启动服务器
server->Start();

// 停止服务器
server->Stop();
```

### 9.2 Qt Modbus TCP API

#### 主站
```cpp
// 创建 Modbus TCP 客户端
QModbusTcpClient *client = new QModbusTcpClient(this);
client->setConnectionParameter(QModbusDevice::NetworkAddressParameter, "192.168.1.1");
client->setConnectionParameter(QModbusDevice::NetworkPortParameter, 502);
client->connectDevice();

// 读取保持寄存器
QModbusDataUnit readUnit(QModbusDataUnit::HoldingRegisters, 0, 10);
QModbusReply *reply = client->sendReadRequest(readUnit, 1);
```

#### 从站
```cpp
// 创建 Modbus TCP 服务器
QModbusTcpServer *server = new QModbusTcpServer(this);
server->setConnectionParameter(QModbusDevice::NetworkPortParameter, 502);

// 设置数据映射
QModbusDataUnitMap reg;
reg.insert(QModbusDataUnit::HoldingRegisters, {QModbusDataUnit::HoldingRegisters, 0, 100});
server->setMap(reg);

// 启动服务器
server->connectDevice();
```

---

**文档结束**
