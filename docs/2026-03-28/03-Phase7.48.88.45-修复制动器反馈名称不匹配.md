# Phase 7.48.88.45 - 修复制动器反馈名称不匹配

## 日期
2026-03-28

## 问题描述

用户在制动器配置界面关闭了"使用松闸反馈"并保存，但运行时仍然启动反馈检测，超时后播放"运行失败"音频。

## 根因分析

`BrakeConfigPanel` 保存时同步到 CommonControl 使用的设备名称与 `ParameterSettings.syncDeviceFeedbackConfigs()` 启动同步使用的名称不一致：

| 组件 | brakeIndex=0 时设备名 | 说明 |
|------|---------------------|------|
| `ParameterSettings.syncDeviceFeedbackConfigs()` | **"1号制动器"** | 启动时同步到CommonControl |
| `BrakeConfigPanel` 保存同步 | **"抱闸"** | 用户保存时同步到CommonControl |
| 启动序列（LogicControlPanel） | **"1号制动器"** | 运行时查找反馈配置 |

### 问题链路

1. 应用启动 → `syncDeviceFeedbackConfigs()` 注册 `CommonControl["1号制动器"]` = `{useFeedback: true}`（DB中旧值）
2. 用户打开制动器配置 → 关闭松闸反馈 → 保存
3. `BrakeConfigPanel` 保存同步 → 注册 `CommonControl["抱闸"]` = `{useFeedback: false}`
4. 启动序列激活"1号制动器" → 查找 `CommonControl["1号制动器"]`（仍为 useFeedback=true）
5. 反馈检测启动 → 超时 → 播放运行失败音频

**根本原因**：CommonControl ��存在两条记录（"1号制动器"和"抱闸"），用户修改的是"抱闸"，但运行时检查的是"1号制动器"。

## 修复方案

**文件**：`src/qml/components/device_info/pages/BrakeConfigPanel.qml`

统一设备名称格式为"X号制动器"，与启动同步和启动序列一致：

```javascript
// 旧：var brakeName = root.brakeIndex === 0 ? "抱闸" : ((root.brakeIndex + 1) + "号制动器")
// 新：
var brakeName = (root.brakeIndex + 1) + "号制动器"  // 统一使用"X号制动器"格式
```

## 影响范围

- 修复制动器反馈开关设置不生效的问题
- brakeIndex=0 的制动器名称从"抱闸"统一为"1号制动器"
- 不影响UI显示（启动序列中仍显示"抱闸"，通过 LogicControlPanel 的 reverseMap/forwardMap 映射）

## 验证要点

1. 关闭1号制动器松闸反馈 → 保存 → 启动皮带 → 不应启动反馈检测
2. 日志中 `setDeviceFeedbackConfig` 应使用"1号制动器"而非"抱闸"
3. 不播放"运行失败"音频
