# Phase 7.48.88.79 - 修复配置面板状态监控不同步

## 修复时间
2026-04-07 11:01 (北京时间)

## 问题描述
Phase 7.48.88.78 统一样式后，3个配置面板（制动器/张紧/洒水）的状态监控LED不会实时更新：
- 列表面板显示"运行中"
- 配置面板状态监控显示"已停止"

## 根因分析
配置面板使用 `Connections` 监听 `doDataManager.doStatesChanged` 和 `commonControl.deviceStatusChanged` 信号，但这些组件通过 `Loader` 加载，Loader 内的 Connections 不能可靠接收全局信号。

## 修复方案
改用属性绑定模式（Property Binding Pattern）：
1. 每个 ConfigPanel 新增 `xxxRunningStates` 数组属性
2. 父页面（ControlPage）在 Loader.onLoaded 中通过 `Qt.binding()` 传递 `runningStates`
3. ConfigPanel 内 LED 的 `isOn` 直接绑定 `runningStates[index]`
4. 数据源统一由 `DeviceSettingsDialog` 维护（全局 `commonControl.onDeviceStatusChanged` 监听）

### 数据流
```
DeviceSettingsDialog.xxxRunningStates（全局维护）
  → XxxControlPage.xxxRunningStates（Qt.binding）
    → XxxConfigPanel.xxxRunningStates（Qt.binding）
      → LED.isOn = xxxRunningStates[index]
```

## 修改文件
| 文件 | 修改内容 |
|------|----------|
| `BrakeConfigPanel.qml` | 添加 `brakeRunningStates` 属性，LED 改用属性绑定 |
| `BrakeControlPage.qml` | onLoaded 中传递 `brakeRunningStates` |
| `TensionControlConfigPanel.qml` | 添加 `tensionRunningStates` 属性，LED 改用属性绑定 |
| `TensionControlPage.qml` | onLoaded 中传递 `tensionRunningStates` |
| `SprinklerConfigPanel.qml` | 添加 `sprinklerRunningStates` 属性，LED 改用属性绑定 |
| `SprinklerControlPage.qml` | onLoaded 中传递 `sprinklerRunningStates` |

## 测试结果
- 制动器配置面板：状态同步正常
- 张紧控制配置面板：状态同步正常
- 洒水配置面板：状态同步正常
- 电机配置面板：仍不同步（未在此次修复范围内，见 Phase 7.48.88.80）

## 统计
- 6 files changed, 24 insertions(+), 117 deletions(-)

## Git 提交
- Commit: `76c12b5`
- 分支: `feature/hardware-video-codec`
