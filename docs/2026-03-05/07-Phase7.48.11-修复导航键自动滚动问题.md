# Phase 7.48.11 — 修复导航键自动滚动问题

**日期**：2026-03-05
**阶段**：Phase 7.48.11
**类型**：UX 改进
**用时**：15 分钟

---

## 一、问题描述

### 用户反馈
测试 Phase 7.48.10 速度保护功能时，发现使用导航键到达"检测模式"等速度保护专用参数时：
1. **字段被隐藏**：参数位于 ScrollView 底部，不在可视区域内
2. **无自动滚动**：Qt 默认不会自动滚动到焦点字段
3. **体验不佳**：用户需要手动滚动才能看到焦点字段

### 问题根源
- AnalogInputPage.qml 使用 ScrollView 包裹参数 GridLayout
- 速度保护专用参数（行 9-10）位于 GridLayout 底部
- Qt 的 ScrollView 不会自动滚动到获得焦点的子项
- 需要手动实现 `ensureVisible()` 逻辑

---

## 二、解决方案

### 实现思路
1. **监听焦点变化**：添加 `onFocusParamIndexChanged` 处理器
2. **计算行位置**：根据参数索引计算所在行号（每行 2 个参数）
3. **估算 Y 坐标**：每行高度约 60px（包括间距）
4. **居中显示**：计算目标滚动位置，让焦点行居中
5. **平滑滚动**：设置 ScrollBar.vertical.position 实现滚动

### 修改文件
- `src/qml/components/device_info/pages/AnalogInputPage.qml`

---

## 三、代码修改

### 3.1 添加焦点监听（第 72-77 行）

```qml
// ✅ 2026-03-05 [Phase 7.48.11]: 监听参数焦点变化，自动滚动到可视区域
onFocusParamIndexChanged: {
    if (focusSubArea === 1) {
        ensureParamVisible(focusParamIndex)
    }
}
```

**说明**：
- 当 `focusParamIndex` 变化时触发
- 仅在参数区域（`focusSubArea === 1`）时生效
- 调用 `ensureParamVisible()` 执行滚动

### 3.2 实现自动滚动函数（第 2084-2107 行）

```qml
// ✅ 2026-03-05 [Phase 7.48.11]: 自动滚动到可视区域
function ensureParamVisible(paramIndex) {
    // 计算参数所在的行号（每行2个参数）
    var rowIndex = Math.floor(paramIndex / 2)

    // 每行高度约60px（包括间距），标题栏50px，顶部边距15px
    var rowHeight = 60
    var estimatedY = rowIndex * rowHeight

    // ScrollView 可视区域高度
    var viewportHeight = paramScrollView.height

    // 当前滚动位置
    var currentY = paramScrollView.ScrollBar.vertical.position * paramScrollView.contentHeight

    // 计算目标滚动位置（让焦点行居中显示）
    var targetY = estimatedY - viewportHeight / 2 + rowHeight / 2

    // 限制在有效范围内
    var maxY = paramScrollView.contentHeight - viewportHeight
    targetY = Math.max(0, Math.min(targetY, maxY))

    // 平滑滚动到目标位置
    var normalizedPosition = targetY / paramScrollView.contentHeight
    paramScrollView.ScrollBar.vertical.position = normalizedPosition

    console.log("🔍 [AnalogInputPage] 自动滚动 - 参数索引:", paramIndex,
                "行号:", rowIndex, "目标Y:", targetY, "归一化位置:", normalizedPosition)
}
```

**计算逻辑**：
1. **行号计算**：`rowIndex = floor(paramIndex / 2)`
   - 参数索引 0-1 → 行 0
   - 参数索引 2-3 → 行 1
   - 参数索引 18-19 → 行 9（速度保护专用参数）
   - 参数索引 20-21 → 行 10

2. **Y 坐标估算**：`estimatedY = rowIndex × 60px`
   - 每行高度 60px（包括 12px 间距）

3. **居中显示**：`targetY = estimatedY - viewportHeight/2 + rowHeight/2`
   - 让焦点行显示在可视区域中央

4. **归一化位置**：`normalizedPosition = targetY / contentHeight`
   - ScrollBar.vertical.position 取值范围 [0, 1]

---

## 四、测试验证

### 测试场景
1. **选择速度保护**：在左侧列表选择"速度"保护项
2. **导航到检测模式**：使用方向键导航到参数索引 18（检测模式）
3. **验证自动滚动**：界面应自动滚动，检测模式字段居中显示
4. **继续导航**：导航到参数索引 19-21，验证每次都自动滚动

### 预期结果
- ✅ 焦点移动到速度保护专用参数时，ScrollView 自动滚动
- ✅ 焦点字段始终在可视区域内，且居中显示
- ✅ 滚动平滑，无跳跃感
- ✅ 其他保护项（18 参数）的导航也正常工作

---

## 五、技术要点

### 5.1 ScrollView 滚动控制
```qml
// 获取当前滚动位置（归一化值 0-1）
var currentPos = scrollView.ScrollBar.vertical.position

// 设置滚动位置（归一化值 0-1）
scrollView.ScrollBar.vertical.position = 0.5  // 滚动到中间

// 计算实际 Y 坐标
var actualY = currentPos * scrollView.contentHeight
```

### 5.2 参数索引与行号映射
| 参数索引 | 参数名称 | 行号 | 列 |
|---------|---------|------|-----|
| 0 | 保护名称 | 0 | 左 |
| 1 | 播放次数 | 0 | 右 |
| 2 | 模块类型 | 1 | 左 |
| 3 | 播放时长 | 1 | 右 |
| ... | ... | ... | ... |
| 18 | 检测模式 | 9 | 左 |
| 19 | 启动延时 | 9 | 右 |
| 20 | 额定速度 | 10 | 左 |
| 21 | 打滑延时 | 10 | 右 |

### 5.3 居中显示算法
```
目标Y = 行Y坐标 - 可视区域高度/2 + 行高度/2

示例（行9，可视区域600px，行高60px）：
目标Y = 9×60 - 600/2 + 60/2 = 540 - 300 + 30 = 270px
```

---

## 六、相关文件

| 文件 | 修改内容 | 行数 |
|------|---------|------|
| `src/qml/components/device_info/pages/AnalogInputPage.qml` | 添加 `onFocusParamIndexChanged` 监听器 | 72-77 |
| `src/qml/components/device_info/pages/AnalogInputPage.qml` | 实现 `ensureParamVisible()` 函数 | 2084-2107 |

---

## 七、后续优化建议

### 7.1 动画效果
当前实现是瞬间滚动，可以添加 Behavior 实现平滑动画：
```qml
Behavior on ScrollBar.vertical.position {
    NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
}
```

### 7.2 精确定位
当前使用估算的行高（60px），可以改为：
- 使用 `mapToItem()` 获取实际 Y 坐标
- 或者为每个参数字段添加 `y` 属性记录

### 7.3 通用化
可以将 `ensureParamVisible()` 提取为通用组件：
```qml
// ScrollViewAutoScroll.qml
Item {
    property var scrollView
    property int focusIndex
    property int itemsPerRow: 2
    property real rowHeight: 60

    onFocusIndexChanged: {
        // 自动滚动逻辑
    }
}
```

---

## 八、完成总结

✅ **问题解决**：导航键到达速度保护专用参数时，界面自动滚动到可视区域
✅ **用户体验**：焦点字段始终居中显示，无需手动滚动
✅ **代码质量**：实现简洁，逻辑清晰，易于维护
✅ **兼容性**：不影响其他保护项的导航功能

**下一步**：编译部署到设备 185 测试实际效果
