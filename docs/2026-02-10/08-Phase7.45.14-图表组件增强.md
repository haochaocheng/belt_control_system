# Phase 7.45.14 - 图表组件增强

**日期**: 2026-02-10
**阶段**: Phase 7.45.14
**类型**: 新组件 + 优化
**状态**: ✅ 已完成

---

## 📋 任务目标

创建 SmoothLineChart 平滑折线图组件，并优化 MiniTrendChart 样式，统一应用 Theme 主题系统。

---

## ✅ 完成内容

### 1. 创建 SmoothLineChart.qml 组件

#### 组件特性
- **基于 Canvas 绘制**（轻量级，无需 QtCharts 依赖）
- **平滑曲线**（二次贝塞尔曲线）
- **渐变填充**（可选）
- **网格线显示**（可选）
- **数据点显示**（可选）
- **动画效果**（数据变化时平滑过渡）

#### 属性接口
```qml
// 数据属性
property var dataPoints: []  // 数据点数组
property real minValue: 0    // 最小值
property real maxValue: 100  // 最大值

// 样式属性
property color lineColor: Theme.accent
property color fillColor: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
property int lineWidth: 2

// 显示选项
property bool showFill: true
property bool showPoints: false
property bool showGrid: true
property int gridLines: 5

// 动画选项
property real animationProgress: 1.0
property bool animateOnDataChange: true
```

#### 使用示例
```qml
SmoothLineChart {
    width: 400
    height: 200
    dataPoints: [45, 48, 52, 50, 55, 58, 60, 62, 65, 63, 68, 70]
    minValue: 0
    maxValue: 100
    lineColor: Theme.accent
    showFill: true
    showGrid: true
    animateOnDataChange: true
}
```

#### 技术实现

**双 Canvas 分层**:
```qml
// 网格层（背景）
Canvas {
    id: gridCanvas
    // 绘制网格线
}

// 图表层（前景）
Canvas {
    id: chartCanvas
    // 绘制曲线和填充
}
```

**平滑曲线算法**（二次贝塞尔曲线）:
```javascript
// 计算控制点
var controlX = (current.x + next.x) / 2
var controlY = (current.y + next.y) / 2

// 绘制平滑曲线
ctx.quadraticCurveTo(current.x, current.y, controlX, controlY)
```

**数据归一化**:
```javascript
var range = maxValue - minValue
var normalizedValue = (dataPoint - minValue) / range
var y = height - (normalizedValue * height)
```

**动画效果**:
```qml
// 动画进度控制可见数据点数量
var visiblePoints = Math.ceil(coords.length * animationProgress)

Behavior on animationProgress {
    NumberAnimation {
        duration: Theme.animationDuration * 2  // 600ms
        easing.type: Theme.animationEasing
    }
}
```

### 2. 优化 MiniTrendChart.qml

#### 颜色替换
```qml
// 之前
property color lineColor: "#00d4ff"
property color fillColor: "#1a2f3e"
color: "#0a0f1e"
border.color: "#2a3f5f"
ctx.strokeStyle = "#2a3f5f"

// 现在
property color lineColor: Theme.accent
property color fillColor: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
color: Theme.primary
border.color: Theme.borderSecondary
ctx.strokeStyle = Theme.borderSecondary
```

#### 绘制优化
```qml
// 添加圆角端点和连接
ctx.lineCap = "round"
ctx.lineJoin = "round"

// 网格线透明度优化
ctx.globalAlpha = 0.3
```

#### 样式统一
```qml
// 边框宽度
border.width: 1 → Theme.borderWidthThin

// 圆角半径
radius: 3 → Theme.radiusSmall
```

---

## 📊 技术亮点

### 1. 二次贝塞尔曲线平滑算法

**原理**:
- 使用相邻两点的中点作为控制点
- 生成平滑的曲线过渡
- 比三次贝塞尔曲线更简单，性能更好

**代码实现**:
```javascript
for (var k = 0; k < visiblePoints - 1; k++) {
    var curr = coords[k]
    var nxt = coords[k + 1]

    // 计算控制点（中点）
    var controlX = (curr.x + nxt.x) / 2
    var controlY = (curr.y + nxt.y) / 2

    // 绘制二次贝塞尔曲线
    ctx.quadraticCurveTo(curr.x, curr.y, controlX, controlY)
}
```

**效果对比**:
- **直线连接**: 折线图，有明显的折角
- **二次贝塞尔**: 平滑曲线，视觉更柔和

### 2. 双 Canvas 分层渲染

**优势**:
- **性能优化**: 网格线不需要频繁重绘
- **清晰分离**: 背景和前景独立管理
- **易于维护**: 修改网格不影响图表

**实现**:
```qml
// 背景层：网格线（静态）
Canvas {
    id: gridCanvas
    onPaint: {
        // 只在初始化和 showGrid 变化时绘制
    }
}

// 前景层：图表（动态）
Canvas {
    id: chartCanvas
    onPaint: {
        // 数据变化时重绘
    }
}
```

### 3. 动画进度控制

**原理**:
- 通过 `animationProgress` (0.0 ~ 1.0) 控制可见数据点数量
- 实现从左到右的绘制动画效果

**实现**:
```javascript
// 计算可见数据点数量
var visiblePoints = Math.ceil(coords.length * animationProgress)

// 只绘制可见部分
for (var j = 0; j < visiblePoints - 1; j++) {
    // 绘制曲线
}
```

**触发**:
```qml
onDataPointsChanged: {
    if (animateOnDataChange) {
        animationProgress = 0    // 重置
        animationProgress = 1.0  // 触发动画
    }
}
```

### 4. 自动数据归一化

**原理**:
- 将任意范围的数据映射到 Canvas 高度
- 自动适应不同的数据范围

**实现**:
```javascript
// 计算数据范围
var range = maxValue - minValue
if (range === 0) range = 1  // 防止除零

// 归一化到 0-1
var normalizedValue = (dataPoint - minValue) / range

// 映射到 Canvas 坐标（Y轴反转）
var y = height - (normalizedValue * height)
```

---

## 🎨 视觉效果对比

### SmoothLineChart vs MiniTrendChart

| 特性 | SmoothLineChart | MiniTrendChart |
|------|----------------|----------------|
| **用途** | 大型图表展示 | 小型趋势预览 |
| **尺寸** | 400x200+ | 200x60 |
| **曲线** | 平滑（贝塞尔） | 直线连接 |
| **网格** | 可配置（5线） | 固定（3线） |
| **动画** | 支持 | 不支持 |
| **数据点** | 可显示 | 始终显示 |
| **填充** | 可选 | 始终填充 |

### 使用场景

**SmoothLineChart**:
- ✅ 详细数据分析
- ✅ 趋势预测展示
- ✅ 多数据系列对比
- ✅ 需要交互的图表

**MiniTrendChart**:
- ✅ 仪表盘快速预览
- ✅ 实时数据监控
- ✅ 空间受限的场景
- ✅ 简单趋势展示

---

## 📈 性能优化

### 1. Canvas 缓存

**问题**: 频繁重绘导致性能下降

**解决**:
```qml
// 只在必要时重绘
onDataPointsChanged: {
    chartCanvas.requestPaint()
}

// 网格线只绘制一次
Component.onCompleted: {
    gridCanvas.requestPaint()
}
```

### 2. 数据点限制

**问题**: 数据点过多导致绘制缓慢

**解决**:
```qml
property int maxDataPoints: 20

function addDataPoint(value) {
    var newData = dataPoints.slice()
    newData.push(value)

    // 限制数据点数量
    if (newData.length > maxDataPoints) {
        newData.shift()  // 移除最旧的数据
    }

    dataPoints = newData
}
```

### 3. 动画优化

**问题**: 动画过于频繁影响性能

**解决**:
```qml
// 可选的动画开关
property bool animateOnDataChange: true

// 合理的动画时长
duration: Theme.animationDuration * 2  // 600ms
```

---

## 🔧 集成到项目

### 1. 注册组件

**qmldir**:
```
SmoothLineChart 1.0 SmoothLineChart.qml
```

### 2. 添加到资源文件

**BeltControlSystem.qrc**:
```xml
<file>components/device_monitor/SmoothLineChart.qml</file>
```

### 3. 使用组件

**导入**:
```qml
import "../components/device_monitor"
```

**使用**:
```qml
SmoothLineChart {
    Layout.fillWidth: true
    height: 200
    dataPoints: productionData
    lineColor: Theme.accent
    showGrid: true
}
```

---

## 📝 修改文件清单

### 新建文件
1. `src/qml/components/device_monitor/SmoothLineChart.qml` - 平滑折线图组件

### 修改文件
1. `src/qml/components/device_monitor/MiniTrendChart.qml` - 优化样式
2. `src/qml/components/device_monitor/qmldir` - 注册新组件
3. `src/qml/BeltControlSystem.qrc` - 添加到资源文件

### 修改统计
- **新增代码**: 196 行（SmoothLineChart）
- **优化代码**: 11 行修改，7 行删除（MiniTrendChart）

---

## 🎯 下一步计划

### Phase 5: 高级效果（明天完成）
- [ ] 创建 ShaderProgressBar.qml（Shader 动画进度条）
- [ ] 创建 ResponsiveLayout.qml（响应式布局）
- [ ] 添加粒子效果
- [ ] 添加 3D 效果

### Phase 6: 全面应用（后天完成）
- [ ] 应用 Theme 到其他页面
- [ ] 优化 BeltConnectionDiagram 配色
- [ ] 优化 CircularProgress 动画
- [ ] 全面测试和性能优化

---

## ✅ 验证结果

### 编译验证
- ✅ QML 语法正确
- ✅ Canvas API 正常工作
- ✅ Theme 导入成功
- ✅ 动画效果流畅

### 视觉验证
- ✅ 曲线平滑（贝塞尔效果）
- ✅ 网格线清晰
- ✅ 填充渐变自然
- ✅ 动画过渡流畅

### 性能验证
- ✅ 绘制性能良好
- ✅ 动画不卡顿
- ✅ 内存占用正常

---

## 📚 参考资料

### 学习来源
1. **QDashBoard TrendChartView** - QtCharts 实现方式
2. **Canvas API** - HTML5 Canvas 绘图技术
3. **贝塞尔曲线** - 平滑曲线算法

### 相关文档
- [Phase 7.45.13 - 应用 Theme 主题系统](./07-Phase7.45.13-应用Theme主题系统到DeviceMonitorPage.md)
- [QML 参考项目学习总结](./06-QML参考项目学习总结.md)
- [DeviceMonitorPage 改进计划](./05-DeviceMonitorPage改进计划.md)

---

## 💡 关键学习总结

### 1. Canvas 绘图技巧
- 使用 `clearRect` 清除画布
- 使用 `beginPath` 开始新路径
- 使用 `quadraticCurveTo` 绘制平滑曲线
- 使用 `closePath` 闭合路径

### 2. 贝塞尔曲线原理
- 二次贝塞尔曲线需要 1 个控制点
- 控制点决定曲线的弯曲程度
- 使用中点作为控制点可以生成平滑过渡

### 3. 动画设计模式
- 使用 `Behavior on` 实现自动动画
- 使用进度值控制绘制范围
- 合理设置动画时长（600ms）

### 4. 性能优化策略
- 分层渲染（静态 + 动态）
- 按需重绘（requestPaint）
- 数据点限制（maxDataPoints）

---

**创建日期**: 2026-02-10
**完成时间**: 2026-02-10
**Git 提交**:
- 643c5521 - "feat: Phase 7.45.14 - 创建 SmoothLineChart 平滑折线图组件"
- e7c12bfa - "refactor: Phase 7.45.14 - 优化 MiniTrendChart 样式"
**用时**: 约 30 分钟
