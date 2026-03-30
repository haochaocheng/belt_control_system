# Phase 7.48.88.73 - 统一4个设备面板启用开关命名与控件类型

## 日期
2026-03-30

## 提交信息
- **Commit**: `3f704b9`
- **类型**: refactor（重构）

## 问题描述
4个设备配置面板的启用开关命名和控件类型不统一：
- BasicConfigTab��使用 RadioButton（"投入"/"禁用"），标签"运行状态"
- BrakeConfigPanel：标签"制动器启用"
- TensionControlConfigPanel：标签"张紧启用"
- SprinklerConfigPanel：标签"启用状态"

## 修复方案
统一所有面板的启用开关：
- **标签名**：全部改为 **"是否启用"**
- **控件类型**：全部使用 **Switch**（开关）
- **数据库字段不变**：`running_state`（电机）/ `enabled`（其他），仅 UI 层统一

### 修改对照

| 面板 | 旧标签 | 旧控件 | 新标签 | 新控件 |
|------|--------|--------|--------|--------|
| BasicConfigTab | 运行状态 | RadioButton(投入/禁用) | 是否启用 | Switch |
| BrakeConfigPanel | 制动器启用 | Switch | 是否启用 | Switch |
| TensionControlConfigPanel | 张紧启用 | Switch | 是否启用 | Switch |
| SprinklerConfigPanel | 启用状态 | Switch | 是否启用 | Switch |

## 修改文件
| 文件 | 改动 |
|------|------|
| `BasicConfigTab.qml` | +27/-97，RadioButton→Switch，大幅简化代码 |
| `BrakeConfigPanel.qml` | +2/-2，标签改名 |
| `TensionControlConfigPanel.qml` | +2/-2，标签改名 |
| `SprinklerConfigPanel.qml` | +2/-2，标签改名 |
