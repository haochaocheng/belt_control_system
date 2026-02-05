# MyIN_Data 组件最终版本 - 纯声明式

**文档版本**: v1.0
**创建日期**: 2026-01-24
**状态**: 已完成

## 1. 组件特性

✅ **完全无 JavaScript** - 纯声明式 QML，完全兼容 Qt Design Studio
✅ **图片背景** - 使用 `images/IN_Data.png` 作为整个组件背景
✅ **设备名称** - 显示在组件顶部中间，白色文字带黑色描边

---

## 2. 组件代码

**文件路径**: `src/qml/Input1/Input1Content/MyIN_Data.ui.qml`

```qml
import QtQuick

// ✅ 2026-01-24 [设备信息界面重构] 设备信息卡片组件
// QDS 兼容：纯声明式 UI 定义，无 JavaScript
Rectangle {
    id: root

    // ========== 公开属性 ==========
    property string deviceName: ""              // 设备名称
    property string deviceId: ""                // 设备ID
    property bool isSelected: false             // 是否选中
    property bool isRunning: false              // 是否运行中
    property real speed: 0.0                    // 当前速度
    property string status: "停止"              // 状态文本

    // ========== 样式属性 ==========
    color: "transparent"                        // 透明背景

    // ========== 背景图片（填充整个组件）==========
    Image {
        id: backgroundImage
        anchors.fill: parent
        source: "images/IN_Data.png"
        fillMode: Image.Stretch
        smooth: true
    }

    // ========== 设备名称文本（顶部中间）==========
    Text {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 10
        text: deviceName
        font.pixelSize: 16
        font.bold: true
        color: "#FFFFFF"
        style: Text.Outline
        styleColor: "#000000"
    }
}
```

---

## 3. 使用方式

在 Screen01.ui.qml 中使用 12 个实例：

```qml
MyIN_Data {
    id: device1
    x: 40
    y: 110
    width: 280
    height: 180
    deviceName: "1号皮带"
    deviceId: "1"
}

MyIN_Data {
    id: device2
    x: 340
    y: 110
    width: 280
    height: 180
    deviceName: "2号皮带"
    deviceId: "2"
}

// ... 共 12 个设备
```

---

## 4. 布局规格

**设计尺寸**: 1920 x 1080

**单个组件**:
- 宽度: 280 px
- 高度: 180 px

**4x3 网格布局**:
- 第一行 Y: 110
- 第二行 Y: 310
- 第三行 Y: 510
- 列间距: 60 px (340-280=60)
- 行间距: 130 px (310-180=130)

**设备名称**:
- 位置: 顶部中间
- 上边距: 10 px
- 字体: 16px, 粗体
- 颜色: 白色 (#FFFFFF)
- 描边: 黑色 (#000000)

---

## 5. 技术亮点

### 5.1 QDS 完全兼容

✅ **无 JavaScript 代码**:
- 移除了所有条件表达式（`? :`）
- 移除了所有函数调用（`toFixed()`）
- 移除了所有 if 语句

✅ **纯声明式属性绑定**:
- 所有属性都是简单的值赋值
- 不使用复杂的表达式

### 5.2 图片背景

✅ **Image.Stretch 填充模式**:
- 图片拉伸填充整个组件
- 适应不同尺寸的组件

✅ **透明背景**:
- Rectangle 背景设为 transparent
- 只显示图片和文本

### 5.3 文本可见性

✅ **白色文字 + 黑色描边**:
- `style: Text.Outline`
- `styleColor: "#000000"`
- 确保在任何背景上都清晰可见

---

## 6. 预留属性

虽然当前版本不使用以下属性，但已预留供后续扩展：

```qml
property bool isSelected: false      // 是否选中（可用于边框高亮）
property bool isRunning: false       // 是否运行中（可用于状态指示）
property real speed: 0.0             // 当前速度（可用于数据显示）
property string status: "停止"       // 状态文本（可用于状态显示）
```

**后续扩展方向**:
- 在 Input1Page.qml 中添加交互逻辑
- 根据 isSelected 属性添加边框高亮
- 根据 isRunning 属性显示运行状态指示器
- 根据 speed 属性显示速度数据

---

## 7. 测试验证

### 7.1 QDS 兼容性测试

**测试步骤**:
1. 在 Qt Design Studio 中打开 `Screen01.ui.qml`
2. 验证不再出现 JavaScript 语法错误
3. 验证可以正常编辑和预览

**预期结果**:
- ✅ 不再出现 "Arbitrary functions and function calls" 错误
- ✅ QDS 可以正常打开和编辑文件
- ✅ 可以在 QDS 中可视化预览界面

### 7.2 运行时测试

**测试步骤**:
```powershell
.\build-ubuntu24-apt.ps1 188
```

**预期结果**:
- ✅ 第5个页面显示 12 个设备卡片
- ✅ 每个卡片显示背景图片
- ✅ 设备名称显示在顶部中间
- ✅ 文本清晰可见（白色描边效果）

---

## 8. 总结

### 8.1 实施成果

✅ **完全 QDS 兼容** - 无任何 JavaScript 代码
✅ **简洁设计** - 图片背景 + 顶部文本
✅ **易于维护** - 纯声明式，代码清晰
✅ **可扩展** - 预留属性供后续功能扩展

### 8.2 文件清单

**修改文件**:
- `src/qml/Input1/Input1Content/MyIN_Data.ui.qml` - 设备信息卡片组件
- `src/qml/Input1/Input1Content/Screen01.ui.qml` - 使用 12 个 MyIN_Data 实例

**未修改文件**:
- `src/control/DeviceInfoController.h/cpp` - 后端控制器（已创建，待使用）
- `src/qml/components/device_info/*` - 备用组件（已创建，待使用）

---

**文档结束**
