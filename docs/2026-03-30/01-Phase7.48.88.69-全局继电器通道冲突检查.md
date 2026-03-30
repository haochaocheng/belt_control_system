# Phase 7.48.88.69 - 全局16通道继电器冲突检查

## 问题描述

输出通道修改时只检查同类型设备（如电机只检查电机之间），未检查制动器、张紧控制和洒水控制已占用的通道。导致：
- 电机可以"挤占"制动器的通道，用户不知情
- 不同设备类型之间通道冲突无提示
- 操作者容易误会，不了解通道已被其他类型设备占用

## 解决方案

### 核心设计：全局通道占用表

每个设备配置面板在保存前构建全局通道占用表，扫描所有4种设备类型的通道配置：

| 设备类型 | 实例数 | 通道键名 | 加载函数 |
|---------|--------|---------|---------|
| 电机 | 8 | `output_channel` | `loadMotorConfig(deviceId, i, 0)` |
| 制动器 | 8 | `release_output_channel` + `brake_output_channel` | `loadBrakeConfig(deviceId, j)` |
| 张紧 | 2 | `output_channel` | `loadTensionConfig(deviceId, k)` |
| 洒水 | 8 | `channel` | `loadSprinklerConfig(s+1)` (1-based) |

### 行为变化

**旧行为**：
- 电机之间通道冲突→自动释放被占用电机的通道
- 跨设备类型无任何检查

**新行为**：
- 修改通道时：实时提示该通道被哪个设备占用（含设备名称）
- 保存时：检查全局冲突，**阻止保存**并提示"请先释放原通道"
- 不再自动释放任何设备的通道（避免误操作）

### 提示信息示例

```
⚠ 通道 6 已被「1号制动器松闸」占用，请先释放原通道
⚠ 保存失败：通道 3 已被「3号电机」占用，请先释放原通道
```

## 修改文件

### 1. DeviceSettingsDialog.qml
- 添加 `buildGlobalChannelMap(excludeType, excludeIndex)` 全局通道占用表构建函数
- 添加 `checkGlobalChannelConflict(channel, excludeType, excludeIndex)` 全局冲突检查函数

### 2. MotorControlPage.qml
- `handleOutputChannelConflict()` 改为扫描所有设备类型
- 新增 `buildGlobalChannelMapForMotor()` 全局扫描函数
- 新增 `checkGlobalConflictBeforeSave()` 保存前阻止函数
- `releaseConflictingChannels()` 废弃（保留签名兼容）
- `saveMotorConfig()` 中添加保存前冲突检查

### 3. BrakeConfigPanel.qml
- 新增 `buildGlobalChannelMapForBrake()` 全局扫描函数
- `saveBrakeConfig()` 中添加松闸/抱闸通道全局冲突检查
- 额外检查松闸和抱闸通道不能相同
- 添加冲突提示 UI（橙色横幅）

### 4. TensionControlConfigPanel.qml
- 新增 `buildGlobalChannelMapForTension()` 全局扫描函数
- `saveTensionControlConfig()` 中添加保存前冲突检查
- 添加冲突提示 UI

### 5. SprinklerConfigPanel.qml
- 新增 `buildGlobalChannelMapForSprinkler()` 全局扫描函数
- `saveSprinklerConfig()` 中添加保存前冲突检查
- 添加冲突提示 UI

### Bug 修复
- 修复所有面板中 `loadSprinklerConfig(s)` 应为 `loadSprinklerConfig(s + 1)`（C++ 后端使用 1-based 索引）

## 日期
2026-03-30
