# Phase 7.48.36 - 修复电机基本配置6个问题（硬件实测）

## 日期
2026-03-10

## 背景
在 Luckfox-Lyra-RK3506 设备（192.168.10.151）上实际测试电机控制功能后，发现6个问题需要修复。核心问题是 DO 模块（设备5）的状态数据未被订阅和解析，导致运行LED、反馈LED等功能无法工作。

## 问题清单

### 问题1：设备模块收到GPIO变化 ✅ 已确认正常
- 点击启动/停止按钮后，DO模块正确收到MQTT命令并执行GPIO操作
- 无需修复

### 问题2：运行状态LED一直显示"已停止"
- **原因**：BasicConfigTab 的 LED 通过 `diDataManager` 读取数据，但 DI 模块（模块0-1）只管理开关量输入，不包含 DO 模块的继电器输出状态。MQTTAutoManager 只连接了前4个模块（DI×2 + AI×2），DO 模块（模块4）从未被连接和订阅。
- **修复**：创建 DODataManager 类，MQTTAutoManager 连接模块4并订阅 `belt_control/do/module1/status`，LED 改用 `doDataManager.getDoState()` 读取。

### 问题3："使用反馈" Switch 无法修改
- **原因**：MouseArea 的 `onClicked` 中设置 `mouse.accepted = false` 太晚，press 事件已被 MouseArea 消费，Switch 无法接收到点击。
- **修复**：改用 `propagateComposedEvents: true` + `onPressed` 处理器，在 press 阶段就放行事件。

### 问题4：反馈启用但没有播放"运行失败"报警
- **原因**：缺少反馈超时检测逻辑。启动电机后没有计时器监控反馈是否在规定时间内到达。
- **修复**：新增 `waitingForFeedback` 属性和 `feedbackTimeoutTimer`，启动电机时开始计时，超时后通过 `commonControl.playAlarmByName()` 播放报警。

### 问题5：需要增加"运行反馈延时"参数
- **原因**：缺少可配置的反馈等待时间参数。
- **修复**：新增 `feedbackDelaySpin`（范围1-60秒，默认3秒），插入到 GridLayout 第4行，所有后续行号+1。

### 问题6：1-8号电机基本参数全部一样
- **原因**：(1) MotorConfigPanel 中 `item.motorIndex = root.motorIndex` 是赋值而非绑定，切换电机后 Tab 内的 motorIndex 不更新；(2) 数据库无配置时 applyConfig 未被调用，所有电机使用相同默认值。
- **修复**：(1) 改用 `Qt.binding(function() { return root.motorIndex })` 动态绑定；(2) 数据库无配置时应用基于 motorIndex 的默认配置。

## 修改文件清单

### 新建文件
| 文件 | 说明 |
|------|------|
| `src/mqtt/DODataManager.h` | DO模块数据管理器头文件 |
| `src/mqtt/DODataManager.cpp` | DO模块数据管理器实现 |

### 修改文件
| 文件 | 说明 |
|------|------|
| `src/mqtt/MQTTAutoManager.cpp` | 连接模块4、订阅DO状态主题、健康检查扩展到5个模块 |
| `src/mqtt/CMakeLists.txt` | 添加 DODataManager 源文件和头文件 |
| `src/main/main.cpp` | 创建 DODataManager 实例、连接信号、注册到 QML |
| `src/qml/components/device_info/pages/BasicConfigTab.qml` | LED数据源改用doDataManager、Switch修复、反馈延时、超时报警 |
| `src/qml/components/device_info/pages/MotorConfigPanel.qml` | motorIndex 改用 Qt.binding |
| `src/qml/components/device_info/pages/MotorControlPage.qml` | 数据库空时应用默认配置 |

## 技术要点

### 前后端分离架构
```
C++ 后端                          QML 前端
┌─────────────────┐              ┌──────────────────┐
│ DODataManager   │──注册到QML──→│ doDataManager     │
│  - doStates[]   │              │  .getDoState(ch)  │
│  - diFeedback[] │              │  .getFeedback(ch) │
│  - estop        │              │  .estop           │
└────────┬────────┘              └──────────────────┘
         │
┌────────┴────────┐
│ MQTTAutoManager │
│  模块4 = DO     │
│  订阅: belt_control/do/module1/status
└─────────────────┘
```

### DO模块MQTT消息格式
```json
{
  "module": 1, "type": "do", "timestamp": 1773131002,
  "data": {
    "do_states": [1,0,0,0,0,0,0,0],
    "do_byte": 1,
    "di_feedback": [1,0,0,0,0,0,0,0],
    "di_byte": 1,
    "estop": 0, "estop_raw": 0
  },
  "quality": "good"
}
```

### MouseArea 事件传播修复
```qml
// 旧代码（Switch无法点击）：
MouseArea {
    anchors.fill: parent
    onClicked: function(mouse) {
        root.requestFocusParamIndex(4)
        mouse.accepted = false  // 太晚，press已被消费
    }
}

// 新代码（Switch可以点击）：
MouseArea {
    anchors.fill: parent
    propagateComposedEvents: true
    onPressed: function(mouse) {
        root.requestFocusParamIndex(4)
        mouse.accepted = false  // 在press阶段放行
    }
}
```

## Git 提交
```
commit 95294d2
feat: Phase 7.48.36 新建DODataManager+修复电机基本配置6个问题
```

## 验证结果（设备日志）
- ✅ DO模块连接成功，订阅 `belt_control/do/module1/status`
- ✅ 启动/停止按钮发送MQTT命令正常
- ✅ 运行LED实时反映DO模块继电器状态
- ✅ 反馈LED实时反映DI反馈状态
- ✅ 切换电机时参数正确区分（output_channel = motorIndex）
