# Phase 7.48.28 - 洒水控制系统完整实现（8个独立洒水装置）

## 日期
2026-03-09

## 概述
实现完整的洒水控制系统，支持8个独立洒水装置，每个保护项可选择连接到特定洒水装置。包含数据库扩展、C++后端CRUD、QML洒水控制页面、导航集成、模拟量页面洒水选择下拉框、MQTT多洒水命令路由。

## 修改文件

### 1. 数据库层 - DeviceConfigManager
**文件**: `src/control/DeviceConfigManager.h`, `src/control/DeviceConfigManager.cpp`

- **扩展 `sprinkler_output_config` 表**：增加 `sprinkler_index`（1-8）和 `sprinkler_name` 列，UNIQUE索引
- **保护表增加 `sprinkler_index` 列**：`device_analog_protections` 和 `device_digital_protections` 都增加（0=无, 1-8=洒水1-8）
- **Migration 014**：初始化8个洒水默认配置 + 向后兼容（sprinkler_enabled=1 的记录自动设为 sprinkler_index=1）
- **新增3个方法**：`loadSprinklerConfig(int)`, `saveSprinklerConfig(int, QVariantMap)`, `loadAllSprinklerConfigs()`
- **更新 `saveAnalogProtection()`**：INSERT语句增加 `sprinkler_index` 列（28列）
- **更新 `saveDigitalProtection()`**：INSERT语句增加 `sprinkler_index` 列

### 2. QML 基础组件（3个新文件）
**SprinklerListPanel.qml** - 左侧面板，8个洒水项列表
- 背景图片 bhNameBK.png/bhNameBK1.png
- 焦点边框 #2196F3
- 从数据库加载启用/禁用状态

**SprinklerConfigPanel.qml** - 右侧配置面板
- 5个参数：洒水名称、启用状态、模块类型、通道号(0-7)、MQTT主题
- 保存/重置按钮
- 切换洒水时自动加载配置

**SprinklerControlPage.qml** - 主页面
- NavigationManager 3区域（列表、参数、按钮）
- 键盘导航 `handleKeyPress(direction)` 支持
- 双向焦点同步

### 3. CMakeLists.txt
**文件**: `src/qml/CMakeLists.txt`
- 注册3个新QML文件

### 4. DeviceSettingsDialog 导航集成
**文件**: `src/qml/components/device_info/DeviceSettingsDialog.qml`

- **导航模型**：新增"洒水控制"（索引6），位于"张紧控制"之后
- **索引重编号**：原6→7, 7→8, 8→9, 9→10（约99处引用）
- **新增 Loader**：`sprinklerControlPageLoader`
- **焦点同步 Connections**：双向同步（Dialog ↔ Page）
- **辅助函数更新**：getCurrentPage, getContentItemCount, getBottomButtons, 保存switch
- **键盘导航分发**：Up/Down/Left/Right 4个方向

### 5. AnalogInputPage 洒水选择
**文件**: `src/qml/components/device_info/pages/AnalogInputPage.qml`

- **新增 Row 12**：洒水选择下拉框（"无", "洒水1"-"洒水8"），仅当洒水使能开启时显示
- **loadProtectionData()**：加载 `sprinkler_index`
- **saveProtectionData()**：保存 `sprinkler_index`

### 6. MqttProtectionMonitor 多洒水路由
**文件**: `src/control/MqttProtectionMonitor.h`, `src/control/MqttProtectionMonitor.cpp`

- **成员变量**：
  - `m_sprinklerActive`: `bool` → `QMap<int, bool>`（key=sprinkler_index 1-8）
  - `m_sprinklerTriggerSources`: `QMap<QString, bool>` → `QMap<int, QMap<QString, bool>>`（外层key=sprinkler_index）
- **checkSprinklerActivation()**：读取保护的 `sprinkler_index`，按洒水索引追踪触发源
- **publishSprinklerCommand(int, bool)**：从 `loadSprinklerConfig(sprinklerIndex)` 获取独立配置（topic、channel）

## 数据库表结构变化

### sprinkler_output_config（扩展为8行）
| 列名 | 类型 | 说明 |
|------|------|------|
| sprinkler_index | INTEGER UNIQUE | 洒水索引（1-8） |
| sprinkler_name | TEXT | 洒水名称（洒水1-洒水8） |
| module_type | TEXT | 模块类型（继电器模块） |
| channel | INTEGER | 通道号（0-7） |
| mqtt_topic | TEXT | MQTT主题 |
| enabled | BOOLEAN | 启用状态 |

### 保护表新增列
| 列名 | 类型 | 说明 |
|------|------|------|
| sprinkler_index | INTEGER DEFAULT 0 | 0=无, 1-8=洒水1-8 |

## 导航索引映射（更新后）
| 索引 | 名称 | 备注 |
|------|------|------|
| 0 | 基本配置 | |
| 1 | 开关量输入 | |
| 2 | 模拟量输入 | |
| 3 | 电机控制 | |
| 4 | 制动器控制 | |
| 5 | 张紧控制 | |
| **6** | **洒水控制** | **新增** |
| 7 | 串口控制 | 原6 |
| 8 | CAN控制 | 原7 |
| 9 | TCP控制 | 原8 |
| 10 | MQTT控制 | 原9 |
| 11 | 逻辑控制 | 原10 |
