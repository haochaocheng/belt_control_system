# TCP配置界面连接状态修复与映射表读写区分

## 日期
2026-04-09

## 修改概述
修复TCP配置界面4个问题：连接状态显示不更新、映射表无读写区分、S7状态检测失败、Snap7测试说明。

## 问题清单与修复

### 问题1+3：Modbus/S7连接后仍显示"监听中"

**根因**：两个BUG叠加
1. `TCPDataAdapter::isPortRunning()`中检查S7用`property("isConnected")`，但`S7ServerController`只有`isRunning`属性，导致S7永远返回false
2. 连接状态栏文字是硬编码的switch/case，不读取后端实际状态

**修复**：
- `TCPDataAdapter.cpp` `isPortRunning()`：`property("isConnected")` → `property("isRunning")`
- `TCPDataAdapter.cpp` `getPortStatusText()`：同样修正S7属性名
- `TCPConfigPanel.qml` 连接状态栏：重构为定时调用`tcpDataAdapter.getPortStatusText()`获取实际状态文字，不再硬编码

### 问题2：映射表没有区分读状态和写控制区

**修复**：
- 映射类别按钮增加读写标签：离散输入/输入寄存器标记绿色"只读"，线圈/保持寄存器标记橙色"读写"
- 映射表新增"访问"列：只读条目显示绿色"R"，可写条目显示橙色"R/W"
- 表头和数据行列宽微调以容纳新列

### 问题4：Snap7 Client Demo测试说明

创建独立文档`03-Snap7-Client-Demo读写测试指南.md`，包含：
- 连接配置（IP/Rack/Slot）
- DB1状态区读取方法（Area=DB, DB#=1, 140字节）
- DB2控制区写入方法及7个常用测试操作
- DB1/DB2完整字节偏移表

## 修改文件

| 文件 | 修改内容 |
|------|---------|
| `src/control/TCPDataAdapter.cpp` | isPortRunning和getPortStatusText修正S7属性名isConnected→isRunning |
| `src/qml/components/device_info/pages/TCPConfigPanel.qml` | 连接状态栏重构为读取后端实际状态 |
| `src/qml/components/device_info/pages/ModbusTCPSlaveTab.qml` | 映射类别按钮添加只读/读写标签，表头+数据行新增"访问"列 |
| `docs/2026-04-09/03-Snap7-Client-Demo读写测试指南.md` | 新建测试文档 |
