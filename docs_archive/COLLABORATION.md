# 团队协作开发指南

## 项目结构

```
src/qml/
├── main.qml                        # 应用入口 [Team Lead]
├── App.qml                         # 主应用容器 [Team Lead]
├── pages/                          # 页面目录
│   ├── ControlPanel.qml           # 控制面板集成 [Team Lead]
│   ├── ParameterSettings.qml      # 参数设置页 [Developer E]
│   └── AlarmPage.qml              # 报警页面 [Developer D]
└── components/                     # 可复用组件目录
    ├── Header.qml                 # 头部组件 [Team Lead]
    ├── Footer.qml                 # 底部组件 [Team Lead]
    ├── TabBar.qml                 # 标签栏 [Team Lead]
    ├── SpeedControlPanel.qml      # 速度控制面板 [Developer A]
    ├── MotorControlPanel.qml      # 电机控制面板 [Developer B]
    ├── RuntimeInfoPanel.qml       # 运行时信息面板 [Developer C]
    └── AlarmSummaryPanel.qml      # 报警摘要面板 [Developer D]
```

## 开发者职责分工

### Team Lead（集成负责人）
- **负责文件**: main.qml, App.qml, ControlPanel.qml, Header.qml, Footer.qml, TabBar.qml
- **职责**:
  - 整体架构设计
  - 组件集成与协调
  - 代码审查
  - 解决组件间冲突

### Developer A（速度控制模块）
- **负责文件**: components/SpeedControlPanel.qml
- **职责**:
  - 速度滑块UI
  - 速度显示
  - 速度控制逻辑
- **接口**:
  ```qml
  // Properties
  property real speedValue: 2.5
  property real minSpeed: 0.0
  property real maxSpeed: 5.0

  // Signals
  signal speedChanged(real newSpeed)

  // Functions
  function setSpeed(speed)
  function resetSpeed()
  ```

### Developer B（电机控制模块）
- **负责文件**: components/MotorControlPanel.qml
- **职责**:
  - 电机启停按钮
  - 紧急停止按钮
  - 电机状态管理
- **接口**:
  ```qml
  // Properties
  property bool motorRunning: false

  // Signals
  signal motorStarted()
  signal motorStopped()
  signal emergencyStopPressed()

  // Functions
  function stopMotor()
  function startMotor()
  ```

### Developer C（运行时信息模块）
- **负责文件**: components/RuntimeInfoPanel.qml
- **职责**:
  - 运行状态显示
  - 速度显示
  - 运行时间显示
- **接口**:
  ```qml
  // Properties
  property bool isRunning: false
  property real currentSpeed: 0.0
  property string runTime: "00:00:00"

  // Functions
  function updateRuntime(hours, minutes, seconds)
  ```

### Developer D（报警模块）
- **负责文件**: components/AlarmSummaryPanel.qml, pages/AlarmPage.qml
- **职责**:
  - 报警摘要显示
  - 报警历史页面
  - 报警管理逻辑
- **接口**:
  ```qml
  // Properties
  property int alarmCount: 0
  property string alarmMessage: "No Alarms"
  property string alarmLevel: "Info"

  // Signals
  signal alarmClicked()

  // Functions
  function setAlarm(count, message, level)
  function clearAlarms()
  ```

### Developer E（参数设置模块）
- **负责文件**: pages/ParameterSettings.qml
- **职责**:
  - 参数列表显示
  - 参数编辑
  - 参数保存与重置

## 组件通信规范

### 1. 属性绑定（Property Binding）
父组件 → 子组件传递数据
```qml
SpeedControlPanel {
    speedValue: root.currentSpeed  // 父组件传递数据给子组件
}
```

### 2. 信号槽机制（Signal/Slot）
子组件 → 父组件通知事件
```qml
MotorControlPanel {
    onMotorStarted: {
        // 父组件处理子组件事件
        root.motorRunning = true
    }
}
```

### 3. 函数调用（Function Call）
父组件 → 子组件执行操作
```qml
speedControl.resetSpeed()  // 父组件调用子组件函数
```

## 开发流程

### 1. 接口定义阶段
- Team Lead 定义组件接口（properties, signals, functions）
- 所有开发者 review 接口设计
- 确认接口无冲突后，各自开始开发

### 2. 独立开发阶段
- 每个开发者在自己的文件中独立开发
- 遵循已定义的接口规范
- 提交代码前自测组件功能

### 3. 集成测试阶段
- Team Lead 集成所有组件
- 测试组件间通信
- 修复集成问题

### 4. 代码审查阶段
- Team Lead 审查代码质量
- 开发者互相 review 代码
- 合并到主分支

## Git 协作流程

### 分支策略
```
main (主分支)
├── feature/speed-control      (Developer A)
├── feature/motor-control      (Developer B)
├── feature/runtime-info       (Developer C)
├── feature/alarm-module       (Developer D)
└── feature/parameter-settings (Developer E)
```

### 提交规范
```
feat: 添加速度控制面板
fix: 修复电机启停逻辑
docs: 更新组件接口文档
refactor: 重构报警显示逻辑
```

## 编码规范

### 命名规范
- 组件文件: PascalCase (例: SpeedControlPanel.qml)
- 组件 id: camelCase (例: speedControl)
- 属性: camelCase (例: motorRunning)
- 信号: camelCase + 动词 (例: speedChanged)
- 函数: camelCase + 动词 (例: setSpeed)

### 注释规范
```qml
// Component: Speed Control Panel
// Developer: Team Member A
// Last Updated: 2025-01-15
// Description: Controls belt speed with slider

// Public properties
property real speedValue: 2.5  // Current speed in m/s

// Public signals
signal speedChanged(real newSpeed)  // Emitted when speed changes

// Public functions
function setSpeed(speed) {  // Set speed programmatically
    speedSlider.value = speed
}
```

## 测试规范

### 单元测试（每个开发者负责）
- 测试组件独立功能
- 测试属性绑定
- 测试信号触发
- 测试函数调用

### 集成测试（Team Lead 负责）
- 测试组件间通信
- 测试数据流转
- 测试边界情况

## 常见问题

### Q: 如何避免文件冲突？
A: 每个开发者只修改自己负责的文件，不要修改他人的文件。

### Q: 如何添加新的接口？
A: 先在团队会议中讨论，Team Lead 批准后才能添加。

### Q: 组件间如何通信？
A: 使用属性绑定、信号槽、函数调用三种方式，参考"组件通信规范"。

### Q: 遇到接口不满足需求怎么办？
A: 联系 Team Lead，讨论修改接口设计。

## 联系方式

- Team Lead: xxx@example.com
- Developer A: xxx@example.com
- Developer B: xxx@example.com
- Developer C: xxx@example.com
- Developer D: xxx@example.com
- Developer E: xxx@example.com
