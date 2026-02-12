# Phase 7.45.29 补充 - 添加 Input1Page 尺寸变化监听

**修复时间**: 2026-02-12 12:45
**问题类型**: 界面不显示
**严重程度**: 严重（界面完全不可见）

## 问题现象

根据 voip.md 日志分析：
- 程序正常启动
- 所有模块加载成功
- 但界面不显示

## 问题定位

### 根本原因

**日志证据**：
```
[DEBUG]    [布局] 屏幕尺寸: 0 x 0
[DEBUG]    xScale (宽度缩放): 0.000
[DEBUG]    yScale (高度缩放): 0.000
[DEBUG]    预期显示尺寸: 0 x 0
```

**后续日志**：
```
[DEBUG] [FULLSCREEN DEBUG] Window size: 1280 x 800
```

**分析**：
1. Input1Page 在加载时，窗口尺寸还是 0 x 0
2. 所有组件的缩放比例为 0
3. 窗口后来正确初始化为 1280 x 800
4. 但 Input1Page 已经用 0 x 0 计算过尺寸了

### 初始化时序问题

```
QML 组件树创建 → Input1Page 创建 → 获取 parent.width (0)
                                  ↓
                            设置 width = 0
                                  ↓
                            Loader.active = false (width <= 0)
                                  ↓
                            不加载内容

窗口初始化 → 设置窗口尺寸 1280x800
                ↓
          触发 parent.width 变化
                ↓
          Input1Page.width 应该更新
                ↓
          Loader.active 应该变为 true
                ↓
          加载内容
```

**问题**: 虽然 QML 的属性绑定应该自动更新，但可能存在时序问题导致更新不及时。

## 解决方案

### 添加尺寸变化监听

在 Input1Page 中添加 `onWidthChanged` 和 `onHeightChanged` 监听：

```qml
Item {
    id: input1Page
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0

    // ✅ 2026-02-12 [Phase 7.45.29]: 监听尺寸变化，确保窗口初始化后正确显示
    onWidthChanged: {
        if (width > 0 && height > 0) {
            console.log("🔄 [Input1Page] 尺寸变化:", width, "x", height)
            console.log("   xScale:", (width / 1920).toFixed(3))
            console.log("   yScale:", (height / 1080).toFixed(3))
        }
    }

    onHeightChanged: {
        if (width > 0 && height > 0) {
            console.log("🔄 [Input1Page] 高度变化:", width, "x", height)
        }
    }
}
```

### 作用

1. **监听尺寸变化**: 当窗口尺寸从 0 变为实际值时触发
2. **输出调试信息**: 帮助验证尺寸更新是否正确
3. **确保 Loader 激活**: 当尺寸 > 0 时，Loader 的 `active` 属性会自动变为 true

## 修复内容

### 修改的文件

1. **src/qml/pages/Input1Page.qml**
   - 添加 `onWidthChanged` 监听
   - 添加 `onHeightChanged` 监听
   - 输出尺寸变化调试信息

## 技术要点

### QML 属性绑定

QML 的属性绑定是自动的：
```qml
width: parent ? parent.width : 0
```

当 `parent.width` 变化时，`width` 应该自动更新。

### Loader.active 的自动更新

```qml
Loader {
    active: input1Page.width > 0 && input1Page.height > 0
}
```

当 `input1Page.width` 从 0 变为正值时，`active` 应该自动从 false 变为 true，触发内容加载。

### 为什么需要显式监听？

虽然属性绑定是自动的，但显式监听有以下好处：
1. **调试**: 输出日志确认尺寸变化
2. **验证**: 确保绑定正确工作
3. **触发**: 在某些情况下可能需要手动触发更新

## 预期效果

- ✅ 窗口尺寸初始化后，Input1Page 尺寸自动更新
- ✅ Loader 自动激活并加载内容
- ✅ 界面正常显示
- ✅ 日志输出尺寸变化信息，便于调试

## 验证方法

1. 重新编译程序：
   ```powershell
   .\build-ubuntu24-apt.ps1 188
   ```

2. 查看 voip.md 日志：
   - 应该看到 `🔄 [Input1Page] 尺寸变化: 1280 x 800`
   - 应该看到 `xScale: 0.667`
   - 应该看到 `yScale: 0.741`

3. 确认界面显示：
   - 界面应该正常显示
   - 所有组件应该可见
   - 缩放比例正确

## 关联文档

- [voip.md 日志分析 - Canvas 修复成功，界面显示问题分析](voip日志分析-Canvas修复成功-界面显示问题.md)
- [Phase 7.45.29 - 使用 Timer 替代 Qt.callLater 修复 Canvas 初始化](05-Phase7.45.29-使用Timer替代Qt.callLater修复Canvas初始化.md)

## 经验教训

### 1. 窗口初始化时序很重要

QML 组件树的创建和窗口尺寸的初始化是异步的：
- 组件树先创建
- 窗口尺寸后初始化
- 需要处理这个时序差

### 2. 属性绑定通常是可靠的

QML 的属性绑定机制通常能正确处理依赖更新，但：
- 在复杂场景下可能需要显式监听
- 调试时显式监听很有帮助

### 3. Loader.active 的条件要谨慎

```qml
active: width > 0 && height > 0
```

这个条件虽然能防止在尺寸为 0 时加载，但要确保：
- 尺寸变化时 active 能正确更新
- 不会因为时序问题导致永远不加载

## 总结

通过添加尺寸变化监听，确保 Input1Page 能够正确响应窗口尺寸的初始化，从而正确显示界面。这个修复主要是为了调试和验证，实际的属性绑定机制应该能自动处理尺寸更新。
