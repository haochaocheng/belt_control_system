# Phase 7.48.87 - 故障警告弹窗赛博朋克科技风重设计 + 键盘操作支持

## 修改时间
2026-03-24 (北京时间)

## 问题描述

### 问题1：弹窗视觉风格缺乏科技感
- 故障警告弹窗（faultWarningDialog）和保护未恢复弹窗（protectionNotClearedDialog）使用简单的暗色背景 + 红/橙边框
- 缺少工业控制系统应有的科技感和视觉冲击力

### 问题2：弹窗仅支持鼠标操作
- 弹窗的"确认"和"OK"按钮只能通过鼠标点击
- 工业触摸屏场景下可能没有鼠标，需要键盘操作支持

## 修复方案

### 修复1：赛博朋克工业科技风重设计

两个弹窗统一采用以下设计元素：

| 设计元素 | 实现方式 |
|---------|---------|
| 脉冲发光边框 | `SequentialAnimation` 控制 `glowOpacity` 在 0.4~1.0 间循环 |
| 三层边框 | 外层发光(margins:-4) + 主边框(border:2) + 内层细线(margins:6) |
| 角标装饰 | 四角各 2 个 Rectangle 组成 L 形角标（20px 长） |
| 扫描线效果 | `NumberAnimation` 控制 scanLineY 从上到下循环移动 |
| 菱形警告图标 | Rectangle rotation:45 + 内部脉冲填充块 |
| 等宽字体 | Consolas 字体 + 英文标题 + 字母间距 |
| 脉冲状态指示灯 | 故障列表每行前方 8px 圆点，跟随 glowOpacity 脉冲 |

**故障警告弹窗（红色主题）**：
- 主色：`#ff4757`（红色）
- 背景：`#0a0e14`（深黑）
- 标题：`FAULT WARNING / 设备故障警告`
- 脉冲周期：800ms

**保护未恢复弹窗（橙色主题）**：
- 主色：`#ffa502`（橙色）
- 背景：`#0a0e14`（深黑）
- 标题：`PROTECTION ACTIVE / 保护未恢复 — 无法复位`
- 脉冲周期：1000ms

### 修复2：键盘操作支持

| 按键 | 功能 |
|------|------|
| Enter / Return | 确认并关闭弹窗 |
| Space | 确认并关闭弹窗 |
| Escape | 关闭弹窗 |

实现方式：
1. 移除 `standardButtons: Dialog.Ok`，改为自定义 footer 按钮
2. `onOpened` 中 `forceActiveFocus()` 到确认按钮
3. `Keys.onPressed` 捕获 Enter/Space/Escape 键
4. 按钮 `activeFocus` 状态有明显视觉反馈（加粗边框 + 高亮背景）
5. 按钮下方显示 `[Enter]` 键盘提示（仅焦点时可见）

## 修改文件

| 文件 | 修改内容 |
|------|---------|
| `src/qml/App.qml` | 重设计 faultWarningDialog + protectionNotClearedDialog |

## 验证方法
1. 按R键（有故障时）→ 弹出红色科技风故障警告弹窗，边框脉冲发光
2. 按F键（有未恢复保护时）→ 弹出橙色科技风保护未恢复弹窗
3. 弹窗打开后按 Enter/Space → 弹窗关闭
4. 弹窗打开后按 Escape → 弹窗关闭
5. 确认按钮有焦点高亮边框和 [Enter] 提示文字
6. 扫描线从上到下平滑移动
7. 角标四角 L 形装饰可见
