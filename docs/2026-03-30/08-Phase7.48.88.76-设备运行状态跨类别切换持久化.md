# Phase 7.48.88.76 - 设备运行状态跨类别切换持久化

## 日期
2026-03-30

## 提交信息
- **类型**: fix（修复）

## 问题描述
设备配置对话框中，4个设备列表（电机/制动器/张紧/洒水）的运行状态LED在切换类别后丢失：

**复现步骤**：
1. 打开电机控制（类别3），设备运行中显示"运行中"绿色闪烁LED
2. 切换到制动器控制（类别4）
3. 再切回电机控制（类别3）
4. **问题**：所有电机LED恢复为默认状态（"未配置"灰色），"运行中"丢失

**根因**：
- `DeviceSettingsDialog` 使用 `Loader + active` 模式管理页面
- `active: root.currentCategory === 3` 为 false 时��Loader 完全销毁页面组件
- 各页面的 `runningStates` 属性和 `Connections` 随组件销毁而丢失
- 重新加载时 `runningStates` 重置为 `[false, false, ...]` 默认值
- `Component.onCompleted` 只能恢复数据库状态（statusList），无法恢复实时运行状态

## 修复方案

### 核心思路
将运行状态属性和信号监听从各子页面**提升到 DeviceSettingsDialog 层级**，利用 Dialog 在对话框打开期间持续存在的特性实现状态持久化。

### 数据流变化

**修复前**（各页面独立监听，切换即丢失）：
```
commonControl.deviceStatusChanged
    → MotorControlPage.motorRunningStates（切换时销毁）
    → MyMotorListPanel.motorRunningStates
    → LED显示
```

**修复后**（Dialog层级统一监听，持久化）：
```
commonControl.deviceStatusChanged
    → DeviceSettingsDialog.motorRunningStates（持久化）
    → Qt.binding() → MotorControlPage.motorRunningStates
    → Qt.binding() → MyMotorListPanel.motorRunningStates
    → LED显示
```

### 修改内容

#### 1. DeviceSettingsDialog.qml（+70行）
- 添加4个运行状态属性：
  - `motorRunningStates: [false×8]`
  - `brakeRunningStates: [false×8]`
  - `tensionRunningStates: [false×2]`
  - `sprinklerRunningStates: [false×8]`
- 添加统一的 `Connections` 块监听 `commonControl.deviceStatusChanged`
  - 用 regex 匹配设备名："X号电机"/"X号制动器"/"X号洒水"
  - 精确匹配："张力传感器"/"张紧控制"
- 在4个 Loader 的 `onLoaded` 中添加 `Qt.binding()` 传递运行状态

#### 2. MotorControlPage.qml（注释 onDeviceStatusChanged）
- 保留 `onBeltRunningChanged`（运行中参数冻结功能）
- 注释掉 `onDeviceStatusChanged`（已由 Dialog 统一处理）

#### 3. BrakeControlPage.qml（注释整个 Connections）
- 整个 `Connections` 块注释掉（只有 `onDeviceStatusChanged`）

#### 4. TensionControlPage.qml（注释整个 Connections）
- 整个 `Connections` 块注释掉

#### 5. SprinklerControlPage.qml（注释整个 Connections）
- 整个 `Connections` 块注释掉

## 修改文件
| 文件 | 改动 |
|------|------|
| `DeviceSettingsDialog.qml` | +70，运行状态属性+统一Connections+4个Loader绑定 |
| `MotorControlPage.qml` | 注释 onDeviceStatusChanged，保留 onBeltRunningChanged |
| `BrakeControlPage.qml` | 注释 Connections 块 |
| `TensionControlPage.qml` | 注释 Connections 块 |
| `SprinklerControlPage.qml` | 注释 Connections 块 |

## 影响范围
- 不影响数据库状态加载（statusList 仍在各页面 `Component.onCompleted` 中加载）
- 不影响运行中参数冻结（`onBeltRunningChanged` 保留在各 ConfigPanel 中）
- 不影响 LED 显示逻辑（ListPanel 代码不变）
