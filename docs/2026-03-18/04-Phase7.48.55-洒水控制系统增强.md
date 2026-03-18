# Phase 7.48.55 - 洒水控制系统增强

## 日期：2026-03-18

## 修改内容

### 任务1：洒水初始配置 - 只有洒水1启用

**问题**：8个洒水装置默认全部启用（enabled=1），实际只需洒水1启用。

**修复**：
- `DeviceConfigManager.cpp`：新增迁移025，`UPDATE sprinkler_output_config SET enabled = 0 WHERE sprinkler_index > 1`
- 已有数据库中洒水2-8自动禁用

### 任务2：开关量输入增加超温洒水功能

**问题**：开关量输入的烟雾/温度保护没有洒水配置UI，数据库已有 sprinkler_enabled/sprinkler_index 字段但无对应控件。

**修复**：
- `SwitchInputPage.qml`：GridLayout 保护级别(row 6)后新增 row 7-8：
  - Row 7 左列：超温洒水使能 Switch（paramIndex 13）
  - Row 7 右列：洒水选择 CustomComboBox ["洒水1"~"洒水8"]（paramIndex 14）
  - Row 8 左列：洒水延时 CustomSpinBox 0-300秒（paramIndex 15）
- `DeviceConfigManager.cpp`：新增迁移026，device_digital_protections 表添加 sprinkler_delay 列（DEFAULT 30）
- 加载/保存函数支持 sprinkler_enabled / sprinkler_index / sprinkler_delay 字段
- getParamFieldCount 从13更新为16
- triggerParamInput 新增 case 13/14/15

### 任务3：洒水配置界面增加启动/停止按钮

**问题**：洒水配置界面缺少手动控制按钮，无法手动测试洒水。

**修复**：
- `SprinklerConfigPanel.qml`：通道号下方新增分隔线和手动控制区域
  - 启动按钮（绿色）：发送 `{"cmd":"write", "channel":N, "value":1}` 到 `belt_control/relay/module1/control`
  - 停止按钮（红色）：发送 `{"cmd":"write", "channel":N, "value":0}`
  - 直接控制，无延时、无预警、无反馈

## 涉及文件

| 文件 | 修改内容 |
|------|----------|
| `src/control/DeviceConfigManager.cpp` | 迁移025（洒水2-8禁用）+ 迁移026（sprinkler_delay列） |
| `src/qml/components/device_info/pages/SwitchInputPage.qml` | 超温洒水UI（3个参数）+ 加载/保存/导航 |
| `src/qml/components/device_info/pages/SprinklerConfigPanel.qml` | 启动/停止按钮 + MQTT命令发送 |

## 后续任务

- `MqttProtectionMonitor.cpp`：实现洒水延时定时器逻辑（所有触发源恢复后延时N秒再停止洒水）
