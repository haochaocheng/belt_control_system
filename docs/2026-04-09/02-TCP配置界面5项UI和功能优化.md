# TCP配置界面5项UI和功能优化

## 日期
2026-04-09

## 修改概述
根据TCP配置界面截图反馈，修复5个UI和功能问题。

## 问题清单与修复

### 问题1：端口连接状态显示缺失
**问题**：整个布局没有显示端口连接状态，无法区分主站和从站。
**修复**：在TCPConfigPanel.qml的Tab栏下方新增36px高的连接状态栏，包含：
- 左侧：运行状态指示灯（绿色=运行中，灰色=未启动）
- 中间：连接状态文字，根据当前Tab类型区分显示：
  - Modbus主站：`Modbus主站 · 运行中 · 轮询目标设备`
  - Modbus从站：`Modbus从站 · 监听中 · 等待外部设备连接`
  - S7主站：`S7主站 · 运行中 · 连接目标PLC`
  - S7从站：`S7从站 · 监听中 · 等待PLC连接`
- 右侧：端口信息（端口号）
- 每2秒定时刷新状态

### 问题2：参数配置未应用到实际功能
**问题**：参数配置区的端口号、从站地址、最大连接数等参数是QML本地状态，未绑定到后端ModbusTCPSlaveController。
**修复**：
- TCPDataAdapter.h/cpp新增6个Q_INVOKABLE方法：
  - `getModbusSlavePort()`/`setModbusSlavePort()` — 读写端口号
  - `getModbusSlaveAddress()`/`setModbusSlaveAddress()` — 读写从站地址
  - `getModbusMaxConnections()`/`setModbusMaxConnections()` — 读写最大连接数
  - `getPortStatusText()` — 获取端口状态文字
- ModbusTCPSlaveTab.qml参数属性改为从后端读取初始值
- SpinBox的onValueChanged回调增加写回后端逻辑
- 状态字段改为只读，反映实际运行状态
- 新增2秒定时器刷新运行状态

### 问题3：S7主站和S7从站Tab文字被遮挡
**问题**：Tab按钮只有110px宽，文字左对齐+15px边距导致S7文字与背景图片重叠。
**修复**：文字从左对齐改为`anchors.centerIn: parent`居中显示，字体大小13→14px。

### 问题4：Tab按钮宽度不足
**问题**：110px宽度不够容纳中文Tab标签。
**修复**：宽度从110px增加到143px（110 × 1.3倍）。

### 问题5：底部两个按钮冗余
**问题**：底部"打开连接"和"关闭连接"两个按钮占用90px空间。
**修复**：
- 合并为单个切换按钮，根据端口运行状态自动切换文字和颜色：
  - 未运行：绿色按钮"打开连接"
  - 运行中：红色按钮"关闭连接"
- 按钮区高度从90px缩减到60px
- NavigationManager按钮区最大索引从2限制为0

## 修改文件

| 文件 | 修改内容 |
|------|---------|
| `src/qml/components/device_info/pages/TCPConfigPanel.qml` | Tab宽度110→143, 文字居中, 新增连接状态栏 |
| `src/qml/components/device_info/pages/TCPControlPage.qml` | 底部2按钮→1个切换按钮, 高度90→60 |
| `src/qml/components/device_info/pages/ModbusTCPSlaveTab.qml` | 参数绑定后端, 状态只读, 状态刷新定时器 |
| `src/qml/components/device_info/NavigationManager.qml` | 按钮区最大索引2→0 |
| `src/control/TCPDataAdapter.h` | 新增6个端口配置读写方法 |
| `src/control/TCPDataAdapter.cpp` | 实现端口配置读写和状态文字方法 |

## 验证方法
1. 启动应用，进入TCP控制页面
2. 确认Tab按钮文字居中显示，S7主站/从站文字完整可见
3. 确认Tab栏下方显示连接状态栏
4. 点击底部切换按钮，确认按钮文字和颜色随状态变化
5. 修改端口号/从站地址参数后，确认日志输出写回后端的消息
