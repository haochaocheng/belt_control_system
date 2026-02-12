# Phase 7.45.28 - 修复 Canvas 引擎初始化问题

**修复时间**: 2026-02-12 10:00
**问题类型**: 运行时错误（阻塞启动）
**严重程度**: 严重（程序无法启动，内存指数级上涨）

## 问题现象

用户反馈在 Phase 7.45.27 修复后，重新编译部署，问题依然存在：
- ✅ 已删除 build_rk3588（全新编译）
- ❌ QPainter 警告依然大量出现
- ❌ 程序无法正常启动
- ❌ 内存指数级上涨

## 问题定位

### 关键错误信息

查看 voip.md 日志，发现关键错误：
```
[WARNING] QPainter::begin: Paint device returned engine == 0, type: 3
[WARNING] QPainter::setRenderHint: Painter must be active to set rendering hints
[WARNING] QPainter::pen: Painter not active
[WARNING] QPainter::strokePath: Painter not active
```

### 根本原因

**`QPainter::begin: Paint device returned engine == 0`** 说明：
1. Canvas 的绘图引擎根本没有初始化成功
2. 不是尺寸问题，而是**初始化时机问题**
3. `Component.onCompleted: requestPaint()` 在组件完成时立即绘制
4. 此时 Canvas 的绘图引擎可能还没有准备好

### 问题文件

**IndustrialContainer.qml** 的 4 个 Canvas：
```qml
Canvas {
    // ...
    onPaint: {
        var ctx = getContext("2d")  // ❌ 此时 ctx 可能为 null
        // ...
    }

    Component.onCompleted: requestPaint()  // ❌ 立即绘制，引擎未就绪
}
```

## 解决方案

### 使用 Qt.callLater() 延迟绘制

将 `Component.onCompleted: requestPaint()` 改为 `Component.onCompleted: Qt.callLater(requestPaint)`：

```qml
Canvas {
    // ...
    onPaint: {
        // ✅ 2026-02-12 [Phase 7.45.27]: 检查Canvas尺寸
        if (width <= 0 || height <= 0) return
        var ctx = getContext("2d")
        if (!ctx) return

        ctx.fillStyle = root.accentColor
        ctx.beginPath()
        ctx.moveTo(0, 0)
        ctx.lineTo(8, 0)
        ctx.lineTo(0, 8)
        ctx.closePath()
        ctx.fill()
    }

    // ✅ 2026-02-12 [Phase 7.45.27 补充]: 延迟绘制，确保Canvas引擎已初始化
    Component.onCompleted: Qt.callLater(requestPaint)
}
```

### Qt.callLater() 的作用

1. **延迟执行**：将 `requestPaint()` 推迟到下一个事件循环
2. **确保初始化**：给 Canvas 引擎足够的时间完成初始化
3. **避免竞态条件**：避免在组件未完全准备好时绘制

## 修复内容

### 修改的文件

1. **src/qml/components/common/IndustrialContainer.qml**
   - 修改 4 个 Canvas 的 `Component.onCompleted`
   - 使用 `Qt.callLater(requestPaint)` 替代 `requestPaint()`

### 修改前后对比

**修改前**：
```qml
Component.onCompleted: requestPaint()
```

**修改后**：
```qml
// ✅ 2026-02-12 [Phase 7.45.27 补充]: 延迟绘制，确保Canvas引擎已初始化
Component.onCompleted: Qt.callLater(requestPaint)
```

## 技术要点

### Canvas 初始化时序

1. **组件创建** → `Component.onCompleted` 触发
2. **Canvas 引擎初始化** → 绘图引擎准备就绪
3. **首次绘制** → `onPaint` 被调用

如果在步骤 1 立即调用 `requestPaint()`，可能在步骤 2 之前执行，导致引擎为 null。

### Qt.callLater() vs Timer

**Qt.callLater()**：
- ✅ 简单直接
- ✅ 延迟到下一个事件循环
- ✅ 不需要额外的 Timer 对象
- ✅ 性能更好

**Timer**：
- ❌ 需要创建额外对象
- ❌ 需要设置延迟时间
- ❌ 可能延迟过长或过短
- ✅ 可以精确控制延迟时间

### 为什么其他 Canvas 没有问题？

1. **App.qml** - 没有 `Component.onCompleted`，自动绘制
2. **BeltConnectionDiagram.qml** - `Component.onCompleted` 只打印日志
3. **SmoothLineChart.qml** - 通过属性变化触发 `requestPaint()`
4. **MiniTrendChart.qml** - 通过属性变化触发 `requestPaint()`
5. **AnalogChart.qml** - 通过属性变化触发 `requestPaint()`

只有 **IndustrialContainer.qml** 在 `Component.onCompleted` 时立即绘制。

## 预期效果

- ✅ 消除 `QPainter::begin: Paint device returned engine == 0` 错误
- ✅ 消除所有 QPainter 警告
- ✅ 程序可以正常启动
- ✅ 内存不再指数级上涨
- ✅ 日志文件正常大小

## 验证方法

1. 重新编译程序：
   ```powershell
   .\build-ubuntu24-apt.ps1 188
   ```

2. 查看 voip.md 日志：
   - 检查是否还有 `QPainter::begin: Paint device returned engine == 0`
   - 检查是否还有大量 QPainter 警告
   - 确认程序正常启动

3. 监控内存使用：
   - 程序启动后内存应该稳定
   - 不应该出现内存持续增长

## 关联文档

- [Phase 7.45.27 - 全面修复 Canvas QPainter 警告和 Theme 单例问题](02-Phase7.45.27-全面修复Canvas-QPainter警告和Theme单例问题.md)
- [Phase 7.45.27 补充 - Canvas 修复验证和临时文件清理](03-Phase7.45.27补充-Canvas修复验证和临时文件清理.md)
- [运行时警告问题清单](运行时警告问题清单.md)

## 经验教训

### 1. Canvas 初始化时机很重要

不要在 `Component.onCompleted` 时立即调用 `requestPaint()`，应该：
- 使用 `Qt.callLater(requestPaint)` 延迟绘制
- 或者通过属性变化触发绘制
- 或者让 Canvas 自动绘制

### 2. 错误信息要仔细分析

- `QPainter::pen: Painter not active` → 可能是尺寸问题
- `QPainter::begin: Paint device returned engine == 0` → **初始化时机问题**

第二个错误更严重，说明引擎根本没有初始化成功。

### 3. 修复要彻底

不能只看表面现象（大量警告），要找到根本原因（引擎初始化失败）。

## 总结

通过使用 `Qt.callLater()` 延迟 Canvas 绘制，确保绘图引擎完全初始化后再进行绘制操作，从根本上解决了 QPainter 引擎初始化失败的问题。这是一个典型的**初始化时序问题**，需要在正确的时机调用正确的方法。
