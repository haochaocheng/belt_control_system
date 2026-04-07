# Phase 7.48.88.80 - 修复电机配置面板状态监控不同步

## 修复时间
2026-04-07 11:44 (北京时间)

## 问题描述
Phase 7.48.88.79 修复了制动器/张紧/洒水的状态同步问题后，电机配置面板（BasicConfigTab）的状态监控仍不同步：
- 电机列表显示"运行中"
- BasicConfigTab 状态监控显示"已停止"

## 根因分析
BasicConfigTab 仍使用旧方案（3个 Connections 监听信号）：
1. `outputChannelSpin.onValueChanged` → 读取 `doDataManager.getDoState()`
2. `doDataManager.onDoStatesChanged` → 读取 `doDataManager.getDoState()`
3. `commonControl.onDeviceStatusChanged` → 匹配电机名更新状态

这3个 Connections 在 Loader 内不能可靠接收信号，与制动器/张紧/洒水面板之前遇到的问题相同。

## 修复方案
将 BasicConfigTab 统一为属性绑定模式：

### 数据流链路
```
DeviceSettingsDialog.motorRunningStates（全局 commonControl.onDeviceStatusChanged 维护）
  → MotorControlPage.motorRunningStates（Qt.binding）
    → MotorConfigPanel.motorRunningStates（Qt.binding，新增属性）
      → BasicConfigTab.motorRunningStates（Qt.binding，新增属性）
        → motorRunItem.motorIsOn = motorRunningStates[motorIndex]（直接绑定）
```

### 关键改动
- `motorRunItem.motorIsOn` 从 `false`（信号驱动赋值）改为声明式绑定：
  ```qml
  property bool motorIsOn: root.motorIndex >= 0 && root.motorIndex < root.motorRunningStates.length
    ? root.motorRunningStates[root.motorIndex] : false
  ```
- 删除3个 Connections 块和 Component.onCompleted 初始化代码

## 修改文件
| 文件 | 修改内容 |
|------|----------|
| `BasicConfigTab.qml` | 新增 `motorRunningStates` 属性，删除3个Connections，`motorIsOn` 改用属性绑定 |
| `MotorConfigPanel.qml` | 新增 `motorRunningStates` 属性，onLoaded 中传递到 BasicConfigTab |
| `MotorControlPage.qml` | onLoaded 中传递 `motorRunningStates` 到 MotorConfigPanel |

## 完成状态
至此，4个配置面板全部统一为属性绑定模式：

| 面板 | Phase | 状态 |
|------|-------|------|
| 制动器 (BrakeConfigPanel) | 7.48.88.79 | 已修复 |
| 张紧控制 (TensionControlConfigPanel) | 7.48.88.79 | 已修复 |
| 洒水控制 (SprinklerConfigPanel) | 7.48.88.79 | 已修复 |
| 电机 (BasicConfigTab) | 7.48.88.80 | 已修复 |

## 统计
- 3 files changed, 20 insertions(+), 49 deletions(-)

## Git 提交
- Commit: `d72d39e`
- 分支: `feature/hardware-video-codec`
