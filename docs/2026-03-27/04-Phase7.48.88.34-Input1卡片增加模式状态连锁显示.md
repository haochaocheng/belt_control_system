# Phase 7.48.88.34 - Input1卡片增加模式/状态/连锁三个显示元素

## 修改时间
2026-03-27

## 需求描述

在 Input1 界面前8个皮带卡片的 statusRow 区域增加3个状态显示元素：
1. **状态** - 故障/运行/启动（原有指示灯+文字，保留不变）
2. **模式** - 检修/就地（新增徽章，来自 systemConfig.workMode）
3. **连锁状态** - 连锁/解锁（新增徽章，由工作模式决定）

## 修改内容

### 卡片组件 MyIN_Data.ui.qml

1. **新增属性**：`workMode`（int，默认1=就地）、`interlockActive`（bool，默认true=连锁）
2. **扩展 statusRow**：从 `[指示灯+状态文字]` 改为 `[指示灯+状态] [模式徽章] [连锁徽章]` 三栏

### 数据绑定 Screen01.qml

1. **applyDeviceMetadata()** 中为前8个卡片设置 workMode 和 interlockActive
2. **新增 Connections** 监听 systemConfig.workModeChanged 信号，实时更新所有卡片

## 颜色方案

| 元素 | 正常状态 | 特殊状态 |
|------|----------|----------|
| 模式 | 绿(#22C55E) 就地 | 琥珀(#F59E0B) 检修 |
| 连锁 | 蓝(#3B82F6) 连锁 | 红(#EF4444) 解锁 |
| 状态 | 已有 statusColor() | 绿/红/琥珀 三级 |

## 连锁逻辑

- 检修模式(workMode=0) → 解锁（红色，表示风险）
- 就地/点动/集控模式 → 连锁（蓝色，表示安全）

## 修改文件

| 文件 | 修改内容 |
|------|----------|
| `src/qml/Input1/Input1Content/MyIN_Data.ui.qml` | 新增 workMode/interlockActive 属性；statusRow 扩展为三栏徽章布局 |
| `src/qml/Input1/Input1Content/Screen01.qml` | applyDeviceMetadata 绑定 workMode；新增 Connections 监听模式变化 |
