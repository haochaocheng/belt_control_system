# Phase 7.48.88.44 - 修复张紧控制反馈tensionIndex不匹配

## 日期
2026-03-28

## 问题描述

用户在张紧控制配置界面关闭了"使用反馈"开关并保存，但运行时仍然启动反馈检测，超时后播放"张紧控制运行失败"音频。

### 日志证据

启动时：
```
[DEBUG] 📋 CommonControl: 设置设备反馈配置 - "张紧控制" 使用反馈: true 反馈通道: 0 延时: 10 秒
```

运行时：
```
[DEBUG]   🔍 启动反馈检测: "张紧控制"
[DEBUG] ⏰ CommonControl: 反馈超时 - "张紧控制"
[WARNING] ❌ CommonControl: 反馈失败 - "张紧控制" 通道 0 仍为0
[DEBUG] 🔊 CommonControl: 播放���行失败音频: "张紧控制运行失败.wav"
```

## 根因分析

`ParameterSettings.syncDeviceFeedbackConfigs()` 和 `TensionControlConfigPanel` 读写了**不同的数据库记录**：

| 组件 | tension_index | 说明 |
|------|--------------|------|
| `syncDeviceFeedbackConfigs()` | **0** | 启动时同步到CommonControl |
| `TensionControlConfigPanel` | **1** | 用户界面读写 |

### 数据库结构

`device_tension_config` 表有两条记录：
- `tension_index = 0`：张力传感器（TensionSensorConfigPanel）
- `tension_index = 1`：张紧控制（TensionControlConfigPanel）

### 问题链路

1. TensionControlPage 切换到"张紧控制"时，`currentControlIndex = 1`
2. TensionControlConfigPanel 的 `controlIndex` 绑定为 `1`
3. 用户修改 use_feedback 并保存 → 写入 `tension_index = 1`
4. 应用启动时 `syncDeviceFeedbackConfigs()` 调用 `loadTensionConfig(deviceId, 0)` → 读取 `tension_index = 0`
5. `tension_index = 0` 的 use_feedback 仍为 1（被迁移028设置，用户从未修改过这条记录）
6. CommonControl 启用反馈检测 → 超时 → 播放运行失败

## 修复方案

**文件**：`src/qml/pages/ParameterSettings.qml`

将 `syncDeviceFeedbackConfigs()` 中张紧控制的 tensionIndex 从 `0` 改为 `1`，与 TensionControlConfigPanel 的 controlIndex 一致。

```javascript
// 旧：var tensionCfg = deviceConfigMgr.loadTensionConfig(deviceId, 0)
// 新：
var tensionCfg = deviceConfigMgr.loadTensionConfig(deviceId, 1)  // 1=张紧控制
```

## 影响范围

- 修复张紧控制反馈开关设置不生效的问题
- 不影响张力传感器配置（tension_index=0）
- 不影响其他设备的反馈配置

## 验证要点

1. 关闭张紧控制反馈开关 → 保存 → 重启 → 启动日志应显示 `启用: false`
2. 启动序列中不再启动张紧反馈检测
3. 不播放"张紧控制运行失败"音频
