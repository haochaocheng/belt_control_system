# Phase 7.48.88.75 - 张紧控制+洒水控制列表动态状态显示+制动器间距微调

## 日期
2026-03-30

## 提交信息
- **Commit**: `c21f44b`
- **类型**: feat（新功能）

## 问题描述
继 Phase 7.48.88.74 制动器列表完成后，张紧控制列表和洒水控制列表仍使用硬编码状态：
- TensionControlListPanel：固定显示"投入"
- SprinklerListPanel：固定显示"待配置"（虽有 `updateSprinklerStatus` 但仅更新文本，无LED颜色变化和动画）

另外，制动器列表名称文字与背景图片边缘重叠需要微调。

## 修复方案

### 1. 张紧控制列表
- **TensionControlListPanel**：移除 ListModel 中的 `status` 字段，添加 `tensionStatusList`/`tensionRunningStates` 属性，动态LED+状态文字
- **TensionControlPage**：
  - `loadAllTensionStatuses()` 分别加载张力传感器（`loadTensionSensorConfig`，字段 `sensor_enabled`/`channel`）和张紧控制（`loadTensionConfig`，字段 `enabled`/`output_channel`）
  - `Connections` 监听 `commonControl.deviceStatusChanged`，匹配"张力传感器"/"张紧控制"设备名

### 2. 洒水控制列表
- **SprinklerListPanel**：移除 ListModel 中的 `status` 字段和旧 `updateSprinklerStatus()` 函数，添加 `sprinklerStatusList`/`sprinklerRunningStates` 属性，动态LED+状态文字
- **SprinklerControlPage**：
  - `loadAllSprinklerStatuses()` 加载8个洒水配置（`loadSprinklerConfig(i+1)`，洒水索引从1开始，字段 `enabled`/`channel`）
  - `Connections` 监听信号，regex 匹配"X号洒水"

### 3. 制动器间距微调
- BrakeListPanel 名称偏移 `horizontalCenterOffset: -20` → `-12`，减少与背景菱形边缘重叠

### 统一状态模式（4个列表面板）
| 面板 | 状态来源 | 数据库函数 |
|------|----------|------------|
| MyMotorListPanel | MotorControlPage | `loadMotorConfig(deviceId, i)` |
| BrakeListPanel | BrakeControlPage | `loadBrakeConfig(deviceId, i)` |
| TensionControlListPanel | TensionControlPage | `loadTensionSensorConfig` / `loadTensionConfig` |
| SprinklerListPanel | SprinklerControlPage | `loadSprinklerConfig(i+1)` |

所有面板统一使用：运行中(亮绿闪烁) / 已停止(绿) / 禁用(红) / 未配置(暗灰)

## 修改文件
| 文件 | 改动 |
|------|------|
| `TensionControlListPanel.qml` | +61/-4，硬编码"投入"→动态LED |
| `TensionControlPage.qml` | +59，加载函数+信号监听+数据绑定 |
| `SprinklerListPanel.qml` | +83/-8，硬编码"待配置"→动态LED，移除旧函数 |
| `SprinklerControlPage.qml` | +44，加载函数+信号监听+数据绑定 |
| `BrakeListPanel.qml` | +15/-2，名称偏移微调 |
