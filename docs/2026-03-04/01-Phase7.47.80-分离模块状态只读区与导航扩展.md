# Phase 7.47.80 — 分离模块状态只读区 & 导航扩展

**日期**: 2026-03-04
**提交**: 待提交
**状态**: 已实施

---

## 问题描述

SwitchInputPage 中，「通道状态 LED」「MQTT服务状态」「模块状态」三个只读指示器
和参数输入框混排在同一个 GridLayout 里：

- 视觉上没有层次感，容易误导用户以为这些是可编辑字段
- 导航键无法到达「数据超时」「连接超时」两个 SpinBox（它们虽在 GridLayout 中，
  但未包含在 `getParamFieldCount()` 返回值内，无焦点高亮）
- Down 键在参数区内会直接跳到底部按钮，跳过了超时设置

---

## 根因

1. 通道状态/模块状态放在 GridLayout row4/row5 的右列（col 2-3），
   和保护延时/数据超时在同一行视觉层级
2. `getParamFieldCount()` 返回 9，不含数据超时(index 10)和连接超时(index 12)
3. DeviceSettingsDialog 的 `focusSubArea===1` Down 键处理直接跳按钮，
   不做同列 +2 步的索引导航

---

## 修复方案

### SwitchInputPage.qml

| 修改 | 详情 |
|------|------|
| 注释掉 GridLayout 中的通道状态 Text 标签 + `channelStatusItem` Item | 用 `/* ... */` 块注释包裹 |
| 注释掉 GridLayout 中的 `moduleStatusItem` Item | 同上 |
| 新增「模块状态（只读）」区域 | 在 ScrollView 结束后、底部分隔线前插入 |
| 数据超时 Item 加焦点高亮（index 10） | `border.color` 绑定 `focusParamIndex === 10` |
| 连接超时 Item 加焦点高亮（index 12） | 同上，绑定 `focusParamIndex === 12` |
| `getParamFieldCount()` → 返回 13 | 含占位索引 9/11 |
| 新增 `isInteractiveParam(index)` | 返回 false for 9/11（占位行） |
| `triggerParamInput()` 新增 case 9/10/11/12 | 9/11 直接 return，10→timeoutSpin，12→brokerTimeoutSpin |

#### 索引方案

```
0-8:  保护参数（保护名称、播放次数、模块类型、播放时长、
       寄存器地址、TTS文字、通道编号、音频文件、保护延时）
9:    占位（row4右列，通道状态已移出），isInteractiveParam=false
10:   数据超时 SpinBox，可导航
11:   占位（row5右列，模块状态已移出），isInteractiveParam=false
12:   连接超时 SpinBox，可导航
```

### DeviceSettingsDialog.qml

| 修改 | 详情 |
|------|------|
| Down 键（focusSubArea===1 else 分支）| 改为两列 +2 步导航，到末尾才跳按钮 |
| Right 键 | 切换到右列前调用 `isInteractiveParam()` 检查；若为占位则保持左列 |

---

## 导航路径（修复后）

```
保护延时(8) →[Down]→ 数据超时(10) →[Down]→ 连接超时(12) →[Down]→ 底部按钮
保护延时(8) →[Right]→ 占位9（跳过，保持在8）
数据超时(10) →[Right]→ 占位11（跳过，保持在10）
连接超时(12) →[Right]→ 无（paramCount=13，12+1=13不满足<13）→ 保持在12
```

---

## 视觉效果

- 参数输入区（GridLayout）只含可编辑字段
- 分隔线 + 「模块状态（只读）」标题将状态区与输入区隔开
- 通道状态 LED / MQTT服务状态 / 模块状态 三合一显示在分隔区内
- 底部按钮保持原位

---

## 涉及文件

| 文件 | 修改类型 |
|------|---------|
| `src/qml/components/device_info/pages/SwitchInputPage.qml` | 主要修改 |
| `src/qml/components/device_info/DeviceSettingsDialog.qml` | 导航逻辑修改 |
