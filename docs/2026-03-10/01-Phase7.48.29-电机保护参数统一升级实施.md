# Phase 7.48.29 — 电机保护参数统一升级实施

**日期**：2026-03-10
**阶段**：Phase 7.48.29
**分支**：feature/hardware-video-codec
**依据**：docs/2026-03-09/06-Phase7.48.28-电机保护参数统一升级规划.md

---

## 一、概述

将电机控制页面从10个Tab升级到14个Tab，统一保护参数配置（从11个参数升级到24个参数），匹配AnalogInputPage的风格。

核心变更：
1. 创建统一的 `MotorProtectionTab.qml` 替代9个独立保护Tab文件
2. 数据库新增11个列（从19列扩展到30列）
3. 新增4种保护类型（堵转保护、起动超时、功率保护、三相不平衡）
4. 底部按钮（保存/删除/重置）内置于每个Tab

---

## 二、修改文件清单

| 序号 | 文件 | 操作 | 说明 |
|------|------|------|------|
| 1 | `src/control/DeviceConfigManager.cpp` | 修改 | 数据库迁移015 + saveMotorConfig扩展(27列) + initDefaultMotorConfigs(14个Tab) |
| 2 | `src/qml/components/device_info/pages/MotorProtectionTab.qml` | 新建 | 统一保护Tab组件（替代9个独立Tab） |
| 3 | `src/qml/components/device_info/pages/MotorConfigPanel.qml` | 修改 | Tab栏从10扩展到14 + StackLayout 13个统一Loader |
| 4 | `src/qml/components/device_info/pages/MotorControlPage.qml` | 修改 | tabNames数组扩展为14个 |
| 5 | `src/qml/CMakeLists.txt` | 修改 | 注册 MotorProtectionTab.qml |

---

## 三、数据库变更

### 3.1 Migration 015 — device_motor_config 表新增11列

```sql
ALTER TABLE device_motor_config ADD COLUMN module_type TEXT DEFAULT '模拟量模块1';
ALTER TABLE device_motor_config ADD COLUMN register_address INTEGER DEFAULT -1;
ALTER TABLE device_motor_config ADD COLUMN range_value REAL DEFAULT 100.0;
ALTER TABLE device_motor_config ADD COLUMN input_type TEXT DEFAULT '4-20mA电流型';
ALTER TABLE device_motor_config ADD COLUMN data_timeout REAL DEFAULT 2.0;
ALTER TABLE device_motor_config ADD COLUMN connection_timeout REAL DEFAULT 10.0;
ALTER TABLE device_motor_config ADD COLUMN play_mode TEXT DEFAULT 'count';
ALTER TABLE device_motor_config ADD COLUMN protection_level INTEGER DEFAULT 1;
ALTER TABLE device_motor_config ADD COLUMN sprinkler_enabled BOOLEAN DEFAULT 0;
ALTER TABLE device_motor_config ADD COLUMN filter_delay REAL DEFAULT 5.0;
ALTER TABLE device_motor_config ADD COLUMN use_text_to_speech BOOLEAN DEFAULT 0;
```

### 3.2 saveMotorConfig 扩展（16→27个绑定值）

新增列：module_type, register_address, range_value, input_type, data_timeout, connection_timeout, play_mode, protection_level, sprinkler_enabled, filter_delay, use_text_to_speech

### 3.3 initDefaultMotorConfigs 扩展（10→14个Tab）

新增4个Tab的默认值：

| Tab | 名称 | 单位 | 上限 | 下限 | 量程 | 输入类型 | 保护延时 | 过滤延时 | 保护级别 | 洒水 |
|-----|------|------|------|------|------|---------|---------|---------|---------|------|
| 1 | 电流保护 | A | 80 | 0 | 100 | 4-20mA电流型 | 30 | 5 | 3(预警+紧急停车) | 关 |
| 2 | 前轴承温度 | ℃ | 60 | 0 | 150 | PT100热电阻 | 50 | 10 | 3(预警+紧急停车) | 开 |
| 3 | 后轴承温度 | ℃ | 60 | 0 | 150 | PT100热电阻 | 50 | 10 | 3(预警+紧急停车) | 开 |
| 4 | A相绕组 | ℃ | 130 | 0 | 200 | PT100热电阻 | 50 | 10 | 3(预警+紧急停车) | 关 |
| 5 | B相绕组 | ℃ | 130 | 0 | 200 | PT100热电阻 | 50 | 10 | 3(预警+紧急停车) | 关 |
| 6 | C相绕组 | ℃ | 130 | 0 | 200 | PT100热电阻 | 50 | 10 | 3(预警+紧急停车) | 关 |
| 7 | 电机温度 | ℃ | 80 | 0 | 150 | PT100热电阻 | 50 | 10 | 2(预警+正常停车) | 开 |
| 8 | X轴振动 | mm/s | 7 | 0 | 20 | 4-20mA电流型 | 100 | 20 | 2(预警+正常停车) | 关 |
| 9 | Y轴振动 | mm/s | 7 | 0 | 20 | 4-20mA电流型 | 100 | 20 | 2(预警+正常停车) | 关 |
| 10 | 堵转保护 | A | 500 | 0 | 1000 | 4-20mA电流型 | 80 | 5 | 3(预警+紧急停车) | 关 |
| 11 | 起动超时 | A | 300 | 0 | 500 | 4-20mA电流型 | 300 | 10 | 3(预警+紧急停车) | 关 |
| 12 | 功率保护 | kW | 150 | 10 | 500 | 4-20mA电流型 | 100 | 20 | 2(预警+正常停车) | 关 |
| 13 | 三相不平衡 | % | 30 | 0 | 100 | 4-20mA电流型 | 100 | 20 | 2(预警+正常停车) | 关 |

---

## 四、MotorProtectionTab.qml 设计

### 4.1 对外属性

```qml
property int tabIndex                    // Tab索引（1-13）
property string protectionName           // 保护名称
property string defaultUnit              // 默认单位
property real defaultUpperLimit          // 默认上限
property real defaultLowerLimit          // 默认下限
property real defaultRange               // 默认量程
property string defaultInputType         // 默认输入类型
property int defaultProtectionDelay      // 默认保护延时
property int defaultFilterDelay          // 默认过滤干扰延时
property int defaultProtectionLevel      // 默认保护级别
property bool defaultSprinklerEnabled    // 默认洒水使能
property int motorIndex                  // 电机索引
property int focusParamIndex: 0          // 焦点索引
property var virtualKeyboard: null       // 虚拟键盘
```

### 4.2 参数布局（GridLayout 4列，11行）

| 行 | 左列标签 | 左列控件 | 右列标签 | 右列控件 |
|----|---------|---------|---------|---------|
| 0 | 保护名称 | Text(只读) | 播放次数 | SpinBox |
| 1 | 模块类型 | ComboBox | 播放时长 | SpinBox(0.1秒) |
| 2 | 音频来源 | ButtonGroup(默认/TTS) | TTS文字 | TextField |
| 3 | 通道编号 | SpinBox(-1~7) | 音频文件 | TextField(只读) |
| 4 | 上限值 | SpinBox | 保护延时 | SpinBox(0.1秒) |
| 5 | 下限值 | SpinBox | 过滤干扰延时 | SpinBox(0.1秒) |
| 6 | 单位 | ComboBox | 数据超时 | SpinBox(秒) |
| 7 | 量程 | SpinBox | 连接超时 | SpinBox(秒) |
| 8 | 输入类型 | ComboBox(含PT100) | 保护级别 | ComboBox |
| 9 | 播放方式 | ButtonGroup | 洒水使能 | Switch |
| 10 | 保护启用 | Switch | — | — |

### 4.3 底部按钮

- 保存（绿色 #27ae60）
- 删除（红色 #e74c3c）— 恢复默认值
- 重置（灰色 #7f8c8d）— 重新加载数据库值

### 4.4 必须实现的函数接口

```javascript
function collectConfig()          // 收集所有参数为 QVariantMap
function applyConfig(config)      // 从 QVariantMap 应用参数到控件
function getParamFieldCount()     // 返回可导航参数数量（22个）
function triggerParamInput(index) // 触发指定参数的输入
function saveConfig()             // 内部保存
function loadConfig()             // 内部加载
```

---

## 五、MotorConfigPanel.qml 变更

### 5.1 Tab栏模型
从10个扩展到14个：
```javascript
["基本配置", "电流保护", "前轴承温度", "后轴承温度", "A相绕组", "B相绕组", "C相绕组", "电机温度", "X轴振动", "Y轴振动", "堵转保护", "起动超时", "功率保护", "三相不平衡"]
```

### 5.2 StackLayout
- Tab 0: 保留 BasicConfigTab.qml
- Tab 1-13: 全部使用 MotorProtectionTab.qml，通过属性传入不同默认值

### 5.3 getCurrentTab()
扩展 switch 到 case 13

---

## 六、废弃文件（保留但不再引用）

| 原文件 | 说明 |
|--------|------|
| CurrentProtectionTab.qml | → 被 MotorProtectionTab 替代 |
| FrontBearingTempTab.qml | → 被 MotorProtectionTab 替代 |
| RearBearingTempTab.qml | → 被 MotorProtectionTab 替代 |
| PhaseAWindingTab.qml | → 被 MotorProtectionTab 替代 |
| PhaseBWindingTab.qml | → 被 MotorProtectionTab 替代 |
| PhaseCWindingTab.qml | → 被 MotorProtectionTab 替代 |
| MotorTempTab.qml | → 被 MotorProtectionTab 替代 |
| XAxisVibrationTab.qml | → 被 MotorProtectionTab 替代 |
| YAxisVibrationTab.qml | → 被 MotorProtectionTab 替代 |

---

## 七、实施顺序

1. DeviceConfigManager.cpp — 数据库迁移015 + saveMotorConfig扩展 + initDefaultMotorConfigs扩展
2. 创建 MotorProtectionTab.qml — 统一保护Tab组件
3. 修改 MotorConfigPanel.qml — 14个Tab + 统一Loader
4. 修改 MotorControlPage.qml — tabNames扩展
5. CMakeLists.txt — 注册新文件
6. 编译验证 + Git提交
