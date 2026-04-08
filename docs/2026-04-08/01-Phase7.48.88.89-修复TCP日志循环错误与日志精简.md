# Phase 7.48.88.89 - 修复TCP日志循环错误与日志精简

## 日期
2026-04-08

## 概述
修复voip.md输出日志中大量重复WARNING/DEBUG日志的问题。日志中存在315,000+条WARNING和44,000+条DEBUG，
主要来源是寄存器操作失败和逐条操作日志。

## 问题分析

### 问题1：寄存器设置失败 (315,000+ WARNING)
- **现象**：离散输入地址147-363、输入寄存器地址0-61全部设置失败
- **根因1**：`startPortServices()` 中 `initializePort()` 在 `startServer()` 之后调用，
  但Qt要求 `setMap()` 必须在 `connectDevice()` 之前
- **根因2**：`onSyncTimer()` 遍历所有8个端口，但只有端口0已初始化/启动

### 问题2：逐条操作日志 (44,000+ DEBUG)
- **现象**：每个寄存器读写操作都打印DEBUG日志
- **根因**：300+寄存器 × 10Hz同步 = 3000条/秒

### 问题3：S7 DB1未注册
- **现象**：S7数据块DB1未注册导致写入失败
- **根因**：与问题1相同，`registerDB()` 在 `startServer()` 之后调用

## 修改文件

### 1. TCPDataAdapter.cpp

#### startPortServices() - 调整初始化顺序
- **修改前**：先启动服务器，再初始化寄存器空间
- **修改后**：先初始化寄存器空间（setMap/registerDB），再启动服务器（connectDevice）
- 同时修复S7 DB的注册时序

#### onSyncTimer() - 端口过滤
- **修改前**：遍历所有8端口，无条件同步
- **修改后**：仅同步已连接的端口
  - Modbus从站：检查 `isConnected()`
  - S7服务器：检查 `property("isConnected")`

### 2. ModbusTCPSlaveController.cpp

#### 日志精简（约15个方法）
- `setHoldingRegister`：移除逐条WARNING和DEBUG
- `setInputRegister`：移除逐条WARNING和DEBUG
- `setCoil`：移除逐条WARNING和DEBUG
- `setDiscreteInput`：移除逐条WARNING和DEBUG
- 所有批量set方法：移除WARNING
- 所有get方法：移除WARNING
- `handleDataWritten`：移除逐次日志，保留信号转发
- `handleStateChanged`：仅保留连接/断开事件日志

## 预期效果
- WARNING日志：从315,000+条/次 → 接近0（仅在真正错误时打印）
- DEBUG日志：从44,000+条/次 → 仅保留启动/停止/连接状态变化
- 日志量减少约99.9%

## 测试方法
1. 部署后观察控制台输出，确认无大量重复WARNING
2. 使用Modbus TCP客户端连接端口502，验证寄存器读取正确
3. 观察S7服务器DB1数据正常

## Phase 完成状态
- [x] 修复startPortServices初始化顺序
- [x] 修复onSyncTimer端口过滤
- [x] 精简ModbusTCPSlaveController日志
- [x] S7 DB注册时序修复
