# Phase 7.48.88.86 - TCP端口服务启停与自动启动

## 日期
2026-04-07

## 概述
实现TCP端口服务的启动/停止控制、运行状态指示、自动启动功能，使系统达到可测试状态。

## 修改文件

### 1. TCPDataAdapter.h
- 新增4个 `Q_INVOKABLE` 方法声明：
  - `startPortServices(int portIndex)` - 启动指定端口的Modbus从站和S7服务器
  - `stopPortServices(int portIndex)` - 停止指定端口的服务
  - `isPortRunning(int portIndex)` - 查询端口运行状态
  - `autoStart()` - 自动启动端口0并开启数据同步

### 2. TCPDataAdapter.cpp
- **startPortServices()**: 初始化端口寄存器空间 → 启动Modbus从站 → 启动S7服务器 → 启用同步定时器
- **stopPortServices()**: 停止Modbus从站 → 停止S7服务器
- **isPortRunning()**: 检查Modbus从站或S7服务器的 `isConnected` 属性
- **autoStart()**: 调用 `startPortServices(0)` 实现开机自动启动端口0

### 3. TCPControlPage.qml
- "打开连接"按钮：调用 `tcpDataAdapter.startPortServices(currentPortIndex)`
- "关闭连接"按钮：调用 `tcpDataAdapter.stopPortServices(currentPortIndex)`
- 替换了原有的 TODO 占位代码

### 4. main.cpp
- 在数据管理器连接完成后调用 `tcpDataAdapter.autoStart()`
- 实现系统启动时自动初始化端口0的TCP服务

### 5. TCPListPanel.qml
- 端口列表项增加运行状态指示圆点：
  - 绿色(#4CAF50) = 端口运行中
  - 灰色(#757575) = 端口未启动
- 通过 `tcpDataAdapter.isPortRunning(index)` 查询实时状态

## 服务启动流程
```
autoStart()
  └─ startPortServices(0)
       ├─ initializePort(0)          # 初始化寄存器空间
       ├─ modbusSlave.startServer()  # 启动Modbus TCP从站(端口502)
       ├─ s7Server.startServer()     # 启动S7服务器
       └─ setSyncEnabled(true)       # 启动100ms同步定时器
```

## 测试方法
1. 启动应用，确认端口0自动启动（列表显示绿色指示）
2. 使用Modbus TCP客户端工具连接 `设备IP:502`，读取离散输入和输入寄存器
3. 在TCP控制页面切换端口，点击"打开连接"/"关闭连接"测试手动控制
4. 观察端口列表的状态指示器是否正确反映运行状态

## Phase 完成状态
- [x] TCPDataAdapter 服务启停方法
- [x] QML按钮绑定实际服务调用
- [x] 自动启动端口0
- [x] 端口运行状态可视化指示
