# Phase 7.48.88.35 - 移除 OutputDevicePanel 并修复反馈配置名称不匹配

## 修改时间
2026-03-27

## 问题描述

### 问题1：张紧控制反馈未检测（设备名称不匹配）

**现象**：张紧控制配置界面"使用反馈"已开启，但运行时反馈检测从未触发。

**根因**：
- `OutputDevicePanel.qml` 硬编码设备名为 `"张紧"`
- `syncDeviceFeedbackConfigs()` 用 `"张紧"` 作为 key 注册到 `m_deviceFeedbackConfigs`
- 启动序列中设备名为 `"张紧控制"`（来自 LogicControlPanel）
- `m_deviceFeedbackConfigs.contains("张紧控制")` → **false** → 反馈检测从未启动

同样的问题也影响制动器：`"抱闸"` vs `"1号制动器"`。

### 问题2：制动器配置加载失败 WARNING

**现象**：`[WARNING] 加载设备 2 制动器 0 配置失败`

**根因**：设备2号从未在制动器配置面板保存过配置，`device_brake_config` 表中无对应行。

**后果**：不影响功能，使用默认延时参数。只需在设备设置中为该设备保存制动器配置即可消除。

## 修复方案

### OutputDevicePanel 已过时，整体移除

`OutputDevicePanel.qml` 是旧的输出设备管理面板，定义了16个硬编码设备。现在这些配置已分散到各独立面板：逻辑控制、电机控制、制动器控制、张紧控制、洒水控制。

### 重写 syncDeviceFeedbackConfigs()

不再从 `OutputDevicePanel.getAllDevices()` 读取设备列表，改为直接从数据库按设备类型读取。设备名称与启动序列完全一致：

| 旧名称（OutputDevicePanel） | 新名称（启动序列） | 数据来源 |
|---------------------------|------------------|---------|
| "张紧" | "张紧控制" | device_tension_config |
| "抱闸" | "1号制动器"~"8号制动器" | device_brake_config |
| "1号电机" | "1号电机"~"8号电机" | device_motor_config |
| "洒水" | "洒水1"~"洒水8" | sprinkler_output_config |

## 修改文件

| 文件 | 修改内容 |
|------|----------|
| `src/qml/pages/ParameterSettings.qml` | 移除 OutputDevicePanel/OutputDeviceSettingsPopup 实例化和 import；重写 syncDeviceFeedbackConfigs() |
| `src/qml/CMakeLists.txt` | 移除两个文件的注册 |
| `src/control/DeviceDatabase.cpp` | 更新注释（移除 OutputDevicePanel 引用） |
| `src/qml/components/control_panel/OutputDevicePanel.qml` | 删除 |
| `src/qml/components/control_panel/OutputDeviceSettingsPopup.qml` | 删除 |
