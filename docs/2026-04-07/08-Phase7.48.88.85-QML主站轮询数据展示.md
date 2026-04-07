# Phase 7.48.88.85 - QML主站轮询数据展示

## 日期
2026-04-07

## 概述
在QML主站标签页（ModbusTCPMasterTab、S7MasterTab）中增加轮询数据展示区域，使操作人员可以查看主站轮询配置和数据概览。

## 修改文件

### 1. ModbusTCPMasterTab.qml
- **新增属性**:
  - `portIndex: int` - 端口索引
  - `readMode: int` - 读取模式 (0=保持寄存器, 1=输入寄存器, 2=线圈, 3=离散输入)
  - `pollDataList: var` - 轮询数据列表
- **新增函数**: `loadPollConfig()` - 根据startRegister/registerCount/readMode生成轮询寄存器地址列表
- **新增UI**:
  - 分隔线 + "轮询数据概览"标题
  - 4个读取模式切换按钮
  - 轮询配置信息栏（目标IP、从站地址、寄存器范围、间隔）
  - 数据表格（地址、名称、类型、当前值）
  - 统计信息

### 2. S7MasterTab.qml
- **新增属性**:
  - `portIndex: int` - 端口索引
  - `pollDbNumber: int` - 轮询DB编号 (1=DB1状态区, 2=DB2控制区)
  - `pollDbStart/pollDbSize: int` - 轮询范围
  - `pollDataList: var` - 轮询数据列表
- **新增函数**: `loadPollConfig()` - 调用 `tcpDataAdapter.getS7DB1Map/getS7DB2Map` 获取映射数据
- **新增UI**:
  - 分隔线 + "S7 轮询数据概览"标题
  - 2个DB选择按钮（DB1状态区、DB2控制区）
  - 轮询配置信息栏（目标IP、Rack/Slot、DB范围、间隔）
  - 数据表格（偏移、长度、名称、当前值）
  - 统计信息

### 3. TCPConfigPanel.qml
- 传递 `currentPortIndex` 到 ModbusTCPMasterTab 和 S7MasterTab 的 `portIndex` 属性

## 当前值说明
当前值列显示"--"，表示未连接状态。连接后实时数据展示需要后续增加：
1. ModbusTCPMasterController.holdingRegistersRead 信号连接到QML属性
2. S7ClientController.dataRead 信号连接到QML属性
3. 定时刷新pollDataList中的value字段

## 后续工作
- Phase 5: 配置持久化（QSettings）和集成测试
- 实时数据刷新（连接主站信号到QML）
