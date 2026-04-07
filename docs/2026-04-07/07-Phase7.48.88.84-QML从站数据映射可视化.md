# Phase 7.48.88.84 - QML从站数据映射可视化

## 日期
2026-04-07

## 概述
在QML从站标签页（ModbusTCPSlaveTab、S7SlaveTab）中增加数据映射可视化表格，使操作人员可以直观查看每个端口的寄存器/数据块映射关系。

## 修改文件

### 1. ModbusTCPSlaveTab.qml
- **新增属性**:
  - `portIndex: int` - 端口索引，用于查询对应端口的映射数据
  - `mapCategory: int` - 映射类别 (0=离散输入, 1=输入寄存器, 2=线圈, 3=保持寄存器)
  - `currentMapData: var` - 当前映射数据列表
- **新增函数**: `loadMapData()` - 调用 `tcpDataAdapter.getDiscreteInputMap/getInputRegisterMap/getCoilMap/getHoldingRegisterMap`
- **新增UI**:
  - 分隔线 + "寄存器映射表"标题
  - 4个类别切换按钮：离散输入(1x)、输入寄存器(3x)、线圈(0x)、保持寄存器(4x)
  - 表头：地址、名称、类型、数据来源
  - Repeater数据列表（交替行颜色）
  - 统计信息："共 N 条映射"

### 2. S7SlaveTab.qml
- **新增属性**:
  - `portIndex: int` - 端口索引
  - `mapCategory: int` - 映射类别 (0=DB1状态区, 1=DB2控制区)
  - `currentMapData: var` - 当前映射数据列表
- **新增函数**: `loadMapData()` - 调用 `tcpDataAdapter.getS7DB1Map/getS7DB2Map`
- **新增UI**:
  - 分隔线 + "S7 数据块映射表"标题
  - 2个类别切换按钮：DB1 状态区(256B)、DB2 控制区(64B)
  - 表头：偏移、长度、名称、类型/说明
  - Repeater数据列表（交替行颜色）
  - 统计信息："共 N 条映射"

### 3. TCPConfigPanel.qml
- 传递 `currentPortIndex` 到 S7SlaveTab 的 `portIndex` 属性（通过Qt.binding）
- ModbusTCPSlaveTab 的 portIndex 在上一阶段已添加

### 4. TCPControlPage.qml
- 传递 `currentPortIndex` 到 TCPConfigPanel（上一阶段已添加）

## 数据流
```
TCPControlPage.currentPortIndex
  → TCPConfigPanel.currentPortIndex (Qt.binding)
    → ModbusTCPSlaveTab.portIndex (Qt.binding)
    → S7SlaveTab.portIndex (Qt.binding)
      → loadMapData() → tcpDataAdapter.getXxxMap(portIndex)
        → currentMapData → Repeater 渲染映射表格
```

## 后续工作
- Phase 3: QML主站标签页增加轮询数据展示
- Phase 4: 配置持久化和集成测试
