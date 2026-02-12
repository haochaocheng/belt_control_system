# Phase 7.45.31 - 修复 QPainter 告警和界面不显示问题（实装版）

**修复时间**: 2026-02-12  
**问题类型**: SwipeView 布局冲突 + 虚拟键盘隐藏态绘制触发告警  
**严重程度**: 严重（页面布局异常、日志高频告警）

## 1. 问题现象

### 用户反馈
- 程序仍有大量 `QPainter::pen/strokePath: Painter not active`
- 页面显示异常（局部区域显示不完整）

### 日志证据（voip.md）
- `QML ... SwipeView has detected conflicting anchors. Unable to layout the item.`
- `root 尺寸: 700 × 1080`（页面宽度异常缩小）
- `QPainter::begin: Paint device returned engine == 0, type: 3`
- `QPainter::pen: Painter not active`

## 2. 根因分析

### 根因 A：SwipeView 子页根节点错误使用 `anchors.fill: parent`
- `SwipeView` 会自行管理子页几何。
- 子页根节点再设置 `anchors.fill` 会造成几何冲突，触发 `conflicting anchors`。
- 冲突后页面尺寸异常，放大后续绘制风险。

### 根因 B：InputPanel 隐藏态仍保持激活
- 虚拟键盘在 `visible=false` 时仍 `enabled=true`，仍可能触发内部绘制链。
- 在特定时序下会引出 `QPainter` 非激活告警。

## 3. 修复方案

### 修复 A：移除 6 个 SwipeView 子页根节点 `anchors.fill`
- 仅移除“页面根节点”上的 `anchors.fill`，内部布局保持不变。
- 由 `SwipeView` 负责子页尺寸管理，消除锚点冲突。

### 修复 B：Input1Page 缩放计算改为实时安全表达式
- 使用 `Math.max/min` 约束宽高，避免极端值导致缩放异常。
- 保留“尺寸就绪后激活 Loader”的机制。

### 修复 C：虚拟键盘仅在可见时激活
- `InputPanel.active = Qt.inputMethod.visible`
- `visible/enabled` 跟随 `active`，避免隐藏态绘制。

### 修复 D：增加构建标记
- 在 `main.qml` 启动日志输出固定 `BUILD MARKER`，用于确认设备运行包版本。

## 4. 修改文件清单

- `src/qml/pages/ControlPanel.qml`
- `src/qml/pages/DeviceMonitorPage.qml`
- `src/qml/pages/ParameterSettings.qml`
- `src/qml/pages/AlarmPage.qml`
- `src/qml/pages/DeviceOperationLog.qml`
- `src/qml/pages/VoiceManagement.qml`
- `src/qml/pages/Input1Page.qml`
- `src/qml/main.qml`

（同时保留本轮已做的告警收敛修复）
- `src/qml/components/sip_phone/pages/SipDialPage.qml`
- `src/qml/Input1/Input1Content/Screen01Form.ui.qml`
- `scripts/2026-02-12/03-quick-deploy-canvas-fix.ps1`

## 5. 验证要点

部署后先看日志：
1. 必须出现：`[BUILD MARKER] Phase7.45.31-SwipeViewRootAnchorFix-2026-02-12`
2. 不应再出现：`SwipeView has detected conflicting anchors`
3. `QPainter::pen: Painter not active` 应显著下降或归零

## 6. 备注

- 本次文档为“已落地代码”的实装记录，覆盖此前分析版本中的不一致描述。
- 若第 2 条已消失但第 3 条仍高频，下一步建议切换到“虚拟键盘模块隔离验证”路径继续定位。

