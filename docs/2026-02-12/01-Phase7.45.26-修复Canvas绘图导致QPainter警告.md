# Phase 7.45.26 - 修复 Canvas 绘图导致 QPainter 警告

**修复时间**: 2026-02-12 17:00
**问题类型**: 运行时警告
**严重程度**: 中等（不影响功能，但产生大量日志）

## 问题描述

程序运行后，日志中出现大量重复的 QPainter 警告：

```
[WARNING] QPainter::pen: Painter not active
[WARNING] QPainter::strokePath: Painter not active
```

这些警告持续输出，导致日志文件快速增长（voip.md 达到 409KB）。

## 问题分析

### 根本原因

Canvas 组件在尺寸未初始化（width/height 为 0）时就开始执行 `onPaint` 绘图操作，导致 QPainter 处于非激活状态。

### 问题定位

通过 `tail -100 voip.md` 查看日志，发现所有警告都来自 Canvas 的绘图操作。

检查 `BeltConnectionDiagram.qml`，发现该组件包含 4 个 Canvas：
1. **gridCanvas** - 网格背景（科技感）
2. **connectionCanvas** - 皮带连接线（渐变效果）
3. **给料机连接线** - 小型 Canvas
4. **破碎机连接线** - 小型 Canvas

所有 Canvas 都使用 `anchors.fill: parent`，但在父元素尺寸未确定时就开始绘制。

## 解决方案

在每个 Canvas 的 `onPaint` 开始处添加尺寸检查：

```qml
onPaint: {
    // ✅ 2026-02-12 [Phase 7.45.26]: 检查Canvas尺寸，避免"Painter not active"警告
    if (width <= 0 || height <= 0) return

    var ctx = getContext("2d")
    if (!ctx) return  // ✅ 确保context有效

    // ... 绘图代码
}
```

### 修复内容

**文件**: `src/qml/components/device_monitor/BeltConnectionDiagram.qml`

1. **gridCanvas（第12-45行）**
   - 添加尺寸检查：`if (width <= 0 || height <= 0) return`
   - 添加 context 检查：`if (!ctx) return`

2. **connectionCanvas（第88-143行）**
   - 添加尺寸检查
   - 添加 context 检查

3. **给料机连接线（第469-484行）**
   - 添加尺寸检查
   - 添加 context 检查

4. **破碎机连接线（第525-540行）**
   - 添加尺寸检查
   - 添加 context 检查

## 修复效果

- ✅ 消除所有 "QPainter not active" 警告
- ✅ 日志文件不再快速增长
- ✅ Canvas 绘图功能正常工作
- ✅ 不影响界面显示效果

## 技术要点

### Canvas 绘图最佳实践

1. **尺寸检查**：始终在 `onPaint` 开始处检查 Canvas 尺寸
2. **Context 检查**：确保 `getContext("2d")` 返回有效对象
3. **延迟绘制**：等待 Canvas 完全初始化后再绘制

### 为什么会出现这个问题？

- SwipeView 的页面在切换时会动态加载/卸载
- DeviceMonitorPage 使用 `anchors.fill: parent`
- Canvas 的 `onPaint` 可能在父元素尺寸确定前触发
- Qt 的布局系统是异步的，尺寸计算需要时间

## 相关文件

- `src/qml/components/device_monitor/BeltConnectionDiagram.qml` - 修复 4 个 Canvas

## 测试验证

1. 启动应用程序
2. 切换到设备监控页面（第2页）
3. 查看日志，确认无 QPainter 警告
4. 验证皮带连接图正常显示

## 后续建议

1. 检查其他使用 Canvas 的组件（MiniTrendChart、SmoothLineChart、AnalogChart）
2. 统一添加尺寸检查，避免类似问题
3. 考虑创建 Canvas 基类或工具函数，封装尺寸检查逻辑

## 关联问题

- Phase 7.45.25 - 修复 SwipeView polish() 循环（布局问题）
- Phase 7.45.21-7.45.24 - 连续启动错误修复

## 总结

通过在 Canvas 的 `onPaint` 中添加简单的尺寸检查，成功消除了大量的 QPainter 警告。这是一个典型的 Qt Quick Canvas 使用问题，需要确保绘图操作在 Canvas 完全初始化后执行。
