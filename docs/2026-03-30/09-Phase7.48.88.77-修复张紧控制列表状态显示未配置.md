# Phase 7.48.88.77 - 修复张紧控制列表状态显示"未配置"

## 日期
2026-03-30

## 提交信息
- **类型**: fix（修复）

## 问题描述
张紧控制列表中，张力传感器和张紧控制的状态始终显示"未配置"（灰色LED），即使配置面板中输出通道已设置为0。

**根因**：
1. `TensionControlPage.loadAllTensionStatuses()` 中调用了 `deviceConfigMgr.loadTensionSensorConfig()`，但此方法在 `DeviceConfigManager` C++ 后端 **根本不存在**
2. QML 中调用不存在的 Q_INVOKABLE 方法会抛出 `TypeError`，导致整个函数中断
3. `root.tensionStatusList` 永远不会被填充（保持默认空数组 `[]`），两个条目都显示"未配置"
4. 额外问题：即使函数不中断，sensor 配置使用的 key `"channel"` 也不匹配数据库列名 `"channel_number"`

## 修复方案

### 修改文件
| 文件 | 改动 |
|------|------|
| `TensionControlPage.qml` | 修复 `loadAllTensionStatuses()` |

### 具体修改
1. **index 0（张力传感器）**：
   - `deviceConfigMgr.loadTensionSensorConfig(deviceId)` → `deviceConfigMgr.loadTensionConfig(deviceId, 0)`
   - key `"sensor_enabled"` → `"enabled"`（匹配数据库列名）
   - key `"channel"` → `"channel_number"`（匹配数据库列名）
2. **index 1（张紧控制）**：代码本身正确，但因 index 0 的 TypeError 导致函数中断，从未执行到此处

### 数据说明
张力传感器和张紧控制配置都存储在同一个 `device_tension_config` 表中：
- `tension_index = 0` → 张力传感器
- `tension_index = 1` → 张紧控制

使用统一的 `loadTensionConfig(deviceId, tensionIndex)` 即可加载两者的配置。

## 影响范围
- 修复张紧控制列表面板中两个条目的状态显示
- 不影响配置面板的功能
- 不影响其他设备类别（电机/制动器/洒水）
