# Phase 7.48.88.83 - TCP数据适配层实现

## 日期
2026-04-07

## 概述
实现TCP数据适配层（TCPDataAdapter），作为MQTT数据管理器与TCP控制器之间的数据桥梁。完善Modbus主站轮询、S7客户端轮询和S7服务器数据区管理。

## 新增文件

### 1. TCPDataAdapter.h / TCPDataAdapter.cpp
- **路径**: `src/control/`
- **职责**:
  - 持有所有数据管理器指针（DODataManager, DIDataManager, AIDataManager, CSDataManager）
  - 100ms定时器从数据管理器采集数据 → 刷新到Modbus从站寄存器 / S7数据块
  - 监听上位机Coil/HoldingRegister写入事件 → 转发为控制命令
  - 提供Q_INVOKABLE供QML查看寄存器映射表

### 2. Modbus寄存器映射

| 区域 | 地址范围 | 数量 | 用途 |
|------|---------|------|------|
| 离散输入 (1xxxx) | 0-363 | 400 | DO状态、DI反馈、设备运行、保护、沿线保护 |
| 输入寄存器 (3xxxx) | 0-61 | 100 | AI通道、系统参数(float)、打包状态 |
| 线圈 (0xxxx) | 0-10 | 32 | DO控制、启动/停止/急停 |
| 保持寄存器 (4xxxx) | 0-10 | 32 | 工作模式、编号、DO控制字、心跳 |

### 3. S7数据块映射

| 数据块 | 大小 | 用途 |
|--------|------|------|
| DB1 | 256 bytes | 状态区（DO/DI/AI/保护/浮点参数/沿线保护） |
| DB2 | 64 bytes | 控制区（DO控制/启停/模式切换/心跳） |

## 修改文件

### 4. ModbusTCPMasterController.cpp
- **修改**: 实现`handlePollTimeout()`
- **原因**: 之前为空TODO，主站无法自动轮询从站数据
- **实现**: 按`startRegister/registerCount`配置读取保持寄存器

### 5. S7ServerController.h / S7ServerController.cpp
- **修改**:
  - 头文件新增`QMap<int, QByteArray> m_dbBuffers`数据缓冲区
  - 实现`registerDB()` - 分配内存并注册到Snap7
  - 实现`setDBData()` - 写入数据到缓冲区
  - 实现`getDBData()` - 从缓冲区读取数据
- **原因**: 之前三个方法都是空壳/TODO

### 6. S7ClientController.cpp
- **修改**: 实现`handlePollTimeout()`
- **原因**: 之前为空TODO，无法自动轮询PLC数据
- **实现**: 轮询DB1(0-140)状态区，通过dataRead信号通知

### 7. CMakeLists.txt (src/control/)
- 添加 TCPDataAdapter.cpp 和 TCPDataAdapter.h

### 8. main.cpp
- 添加`#include "control/TCPDataAdapter.h"`
- 创建TCPDataAdapter实例
- 绑定8个Modbus从站和8个S7服务器
- 连接所有数据管理器
- 注册到QML上下文（`tcpDataAdapter`）

## 安全机制
- 启动/停止皮带命令仅在**集控模式(workMode=3)**下允许
- 紧急停车不受工作模式限制
- 线圈使用**上升沿检测 + 自动清零**，防止PLC持续写1导致重复触发

## IEEE754浮点处理
- Modbus: 1个float = 2个16位寄存器 (HiWord在前, Big-Endian)
- S7: 1个REAL = 4字节 (Big-Endian)

## 后续工作
- Phase 2: QML从站标签页增加数据映射可视化
- Phase 3: QML主站标签页增加轮询数据展示
- Phase 4: 配置持久化和集成测试
