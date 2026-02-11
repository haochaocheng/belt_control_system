# Phase 7.45.18-20 - DeviceStatusPanel 图片背景和自定义输入框组件

## 修改时间
2026-02-11

## 修改概述
为 DeviceStatusPanel 添加图片背景，并创建自定义图片输入框组件替换原有的 Rectangle 输入框。

## 修改内容

### 1. DeviceStatusPanel 背景图片（Phase 7.45.18）

**问题**：
- 用户在 DeviceStatusPanel 中添加了背景图片 `info_lift.png`
- 原有的矩形边框和颜色不再需要
- 图片尺寸和原先的矩形尺寸不一致

**修改**：

**文件**：`src/qml/components/control_panel/DeviceStatusPanel.qml`

1. 将根元素从 `Rectangle` 改为 `Item`：
```qml
// 2026-02-11: 使用图片作为背景，图片包含标题栏和内容区域
Item {
    id: root
    width: 360  // 用户调整为 360
    height: 320

    // 背景图片 - 拉伸填充整个区域
    Image {
        id: backgroundImage
        anchors.fill: parent
        source: "../../images/info_lift.png"
        fillMode: Image.Stretch  // 拉伸模式填充整个面板
    }
}
```

2. 注释掉原有的矩形背景和边框：
```qml
// 2026-02-11: 注释掉原有的矩形背景和边框
// Rectangle {
//     id: root
//     width: 280
//     height: 320
//     color: "#dd1a2332"
//     radius: 10
//     border.color: "#00d4ff"
//     border.width: 2
// }
```

3. 调整内容区域布局，避开图片标题栏：
```qml
// 2026-02-11: 内容区域 - 从标题栏下方开始，避开图片的标题区域
ColumnLayout {
    anchors {
        left: parent.left
        right: parent.right
        top: parent.top
        bottom: parent.bottom
        leftMargin: 15
        rightMargin: 15
        topMargin: 50  // 增加顶部边距，避开图片的标题栏区域
        bottomMargin: 15
    }
    spacing: 10  // 减小间距以适应更紧凑的布局
}
```

4. 注释掉"设备信息"标题和分隔线（图片背景已包含）：
```qml
// 2026-02-11: 注释掉标题和分隔线，图片背景已包含
// // Title
// Text {
//     text: "设备信息"
//     font.pixelSize: 18
//     font.bold: true
//     color: "#00d4ff"
//     Layout.alignment: Qt.AlignHCenter
// }
```

**Git 提交**：
- `f4627b05` - Phase 7.45.18: DeviceStatusPanel 使用图片背景
- `11fcd020` - Phase 7.45.18.1: 调整布局适应图片尺寸

---

### 2. 增强同步脚本支持 src/qml/images（相关修改）

**文件**：`scripts/2026-01-12/09-sync-input1-resources.ps1`

**修改**：
1. 添加 `$QmlImagesDir` 变量指向 `src/qml/images` 目录
2. 扫描两个目录：`src/qml/images` 和 `Input1/Input1Content/images`
3. 自动去重，避免重复添加图片（如 header.png）
4. 生成的 RESOURCES 列表包含两个目录的所有图片

**关键代码**：
```powershell
# 2026-02-11: 扫描 src/qml/images 目录
$qmlImageFiles = Get-ChildItem -Path $QmlImagesDir -File |
                 Where-Object { $_.Extension -match '\.(svg|png|jpg|jpeg)$' } |
                 Sort-Object Name

# 添加 src/qml/images 目录的图片（不包含 header.png）
foreach ($file in $qmlImageFiles) {
    if ($file.Name -ne "header.png") {
        $resourcesList += "`n        images/$($file.Name)"
    }
}
```

**优点**：
- 用户可以随时在 `src/qml/images` 添加或删除图片
- 运行脚本自动同步到 CMakeLists.txt
- 不会重复添加已存在的图片

**Git 提交**：`a835dfd2` - feat: 增强同步脚本支持 src/qml/images 目录

---

### 3. 创建图片背景输入框组件（Phase 7.45.19）

**需求**：
使用 `src/qml/images` 目录下的 `input1.png` 和 `input2.png` 创建自定义输入框组件，替换 DeviceStatusPanel 中"模式"和"名称"后面的 Rectangle 输入框。

#### 3.1 创建 ImageInputField 组件

**文件**：`src/qml/components/control_panel/ImageInputField.qml`（新建）

**代码**：
```qml
import QtQuick 6.5
import QtQuick.Controls 6.5

// Image-based Input Field Component
// 2026-02-11: 使用 input1.png 和 input2.png 作为背景的输入框组件
Item {
    id: root

    // 可配置属性
    property string text: ""
    property bool useSecondaryImage: false  // false: input1.png, true: input2.png
    property alias horizontalAlignment: textLabel.horizontalAlignment
    property alias font: textLabel.font
    property alias color: textLabel.color

    implicitWidth: 80
    implicitHeight: 28

    // 背景图片
    Image {
        id: backgroundImage
        anchors.fill: parent
        source: root.useSecondaryImage ? "../../images/input2.png" : "../../images/input1.png"
        fillMode: Image.Stretch
    }

    // 文本显示
    Text {
        id: textLabel
        anchors.centerIn: parent
        text: root.text
        font.pixelSize: 14
        font.bold: true
        color: "white"
    }
}
```

**特点**：
- 使用 `useSecondaryImage` 属性切换 input1.png（灰蓝色）和 input2.png（蓝色）
- 支持文本显示和样式自定义
- 图片拉伸填充整个区域

#### 3.2 在 DeviceStatusPanel 中使用新组件

**文件**：`src/qml/components/control_panel/DeviceStatusPanel.qml`

**修改前（模式输入框）**：
```qml
Rectangle {
    Layout.preferredWidth: 80
    Layout.preferredHeight: 28
    radius: 5
    color: getModeColor(root.operationMode)
    border.color: "#00d4ff"
    border.width: 1

    Text {
        anchors.centerIn: parent
        text: root.operationMode
        font.pixelSize: 14
        font.bold: true
        color: "white"
    }
}
```

**修改后**：
```qml
// 2026-02-11: 使用自定义图片输入框组件
ImageInputField {
    Layout.preferredWidth: 80
    Layout.preferredHeight: 28
    text: root.operationMode
    useSecondaryImage: false  // 使用 input1.png
}
```

**修改前（名称输入框）**：
```qml
Rectangle {
    Layout.preferredWidth: 80
    Layout.preferredHeight: 28
    radius: 5
    color: "#3498db"
    border.color: "#00d4ff"
    border.width: 1

    Text {
        anchors.centerIn: parent
        text: root.deviceName
        font.pixelSize: 14
        font.bold: true
        color: "white"
    }
}
```

**修改后**：
```qml
// 2026-02-11: 使用自定义图片输入框组件
ImageInputField {
    Layout.preferredWidth: 80
    Layout.preferredHeight: 28
    text: root.deviceName
    useSecondaryImage: true  // 使用 input2.png
}
```

#### 3.3 更新构建系统

**文件**：`src/qml/CMakeLists.txt`
```cmake
components/control_panel/DeviceStatusPanel.qml
components/control_panel/ImageInputField.qml  # 2026-02-11: 图片背景输入框组件
components/control_panel/ProtectionPanel.qml
```

**文件**：`src/qml/BeltControlSystem.qrc`
```xml
<file>components/control_panel/DeviceStatusPanel.qml</file>
<file>components/control_panel/ImageInputField.qml</file>
<file>components/control_panel/ModuleConnectionPanel.qml</file>
```

**Git 提交**：`145f4ebd` - feat: Phase 7.45.19 - 创建图片背景输入框组件

---

## 技术要点

### 1. QML Image fillMode
- **PreserveAspectFit**：保持图片宽高比，可能留白
- **Stretch**：拉伸填充，可能变形但无留白
- **PreserveAspectCrop**：保持宽高比，裁剪多余部分

选择 `Stretch` 是因为：
- 背景图片需要完全填充面板区域
- 图片本身设计为固定尺寸，拉伸变形不明显

### 2. 布局调整技巧
使用 `topMargin` 避开图片的标题栏区域：
```qml
anchors {
    topMargin: 50  // 标题栏约 40-50px
}
```

### 3. 组件化设计优点
- **复用性**：ImageInputField 可用于其他输入框
- **维护性**：修改组件样式，所有使用处自动更新
- **一致性**：统一的视觉风格

### 4. 属性别名（alias）的使用
```qml
property alias font: textLabel.font
property alias color: textLabel.color
```
允许外部直接访问和修改内部元素属性，增强组件灵活性。

---

## 相关文件

### 修改的文件
1. `src/qml/components/control_panel/DeviceStatusPanel.qml` - 添加背景图片，使用新组件
2. `src/qml/CMakeLists.txt` - 添加 ImageInputField.qml
3. `src/qml/BeltControlSystem.qrc` - 添加 ImageInputField.qml
4. `scripts/2026-01-12/09-sync-input1-resources.ps1` - 支持 src/qml/images 目录

### 新增的文件
1. `src/qml/components/control_panel/ImageInputField.qml` - 图片背景输入框组件
2. `src/qml/images/info_lift.png` - DeviceStatusPanel 背景图
3. `src/qml/images/input1.png` - 灰蓝色输入框背景
4. `src/qml/images/input2.png` - 蓝色输入框背景

---

## 测试建议

1. **QDS 预览测试**：
   - 打开 DeviceStatusPanel.qml 在 QDS 中预览
   - 检查背景图片是否正确显示
   - 检查模式和名称输入框是否使用图片背景

2. **运行时测试**：
   - 编译并运行应用程序
   - 检查 DeviceStatusPanel 显示效果
   - 验证数据绑定是否正常工作（模式、名称显示）

3. **响应式测试**：
   - 调整面板尺寸，检查图片拉伸效果
   - 验证内容区域布局是否正确

---

## 后续优化建议

1. **动态尺寸适配**：
   - 根据图片原始尺寸动态调整面板尺寸
   - 使用 `Image.sourceSize` 获取图片尺寸

2. **状态动画**：
   - 为输入框添加 hover/pressed 状态
   - 使用不同图片或透明度表示状态

3. **主题支持**：
   - 将图片路径配置化
   - 支持切换不同的主题图片

4. **性能优化**：
   - 使用 `Image.cache` 属性缓存图片
   - 考虑使用 `Image.asynchronous` 异步加载大图

---

## 版本历史

| 版本 | Git Commit | 描述 |
|------|-----------|------|
| Phase 7.45.18 | f4627b05 | DeviceStatusPanel 使用图片背景 |
| Phase 7.45.18.1 | 11fcd020 | 调整布局适应图片尺寸 |
| - | a835dfd2 | 增强同步脚本支持 src/qml/images 目录 |
| Phase 7.45.19 | 145f4ebd | 创建图片背景输入框组件 |
| Phase 7.45.19.1 | 38010055 | 修正 ImageInputField 为双图片叠加 |
| Phase 7.45.20 | 1e20c8e7 | 创建状态显示输入框组件 |

---

## Phase 7.45.19.1 - 修正双图片叠加（2026-02-11）

### 问题发现
之前理解错误，ImageInputField 应该同时使用两张图片叠加显示，而不是二选一。

### 修改内容

**修改前（错误理解）**：
```qml
// 使用 useSecondaryImage 属性选择使用哪张图片
Image {
    id: backgroundImage
    source: root.useSecondaryImage ? "../../images/input2.png" : "../../images/input1.png"
    fillMode: Image.Stretch
}
```

**修改后（正确实现）**：
```qml
// 底层背景图片 - input1.png
Image {
    id: backgroundImage1
    anchors.fill: parent
    source: "../../images/input1.png"
    fillMode: Image.Stretch
}

// 顶层背景图片 - input2.png（叠加在 input1 上方）
Image {
    id: backgroundImage2
    anchors.fill: parent
    source: "../../images/input2.png"
    fillMode: Image.Stretch
}

// 文本显示（在最上层）
Text {
    id: textLabel
    anchors.centerIn: parent
    text: root.text
}
```

### 效果说明
- **input1.png** 作为底层背景（灰蓝色）
- **input2.png** 作为顶层背景（蓝色，叠加在 input1 上方）
- **文本** 显示在最上层
- 两张图片叠加形成最终的视觉效果

### DeviceStatusPanel 调用更新
```qml
// 修改前
ImageInputField {
    text: root.operationMode
    useSecondaryImage: false  // ❌ 不需要此属性
}

// 修改后
ImageInputField {
    text: root.operationMode  // ✅ 自动叠加两张图片
}
```

**Git 提交**：`38010055` - fix: Phase 7.45.19.1 - 修正 ImageInputField 为双图片叠加

---

## Phase 7.45.20 - 创建状态显示输入框组件（2026-02-11）

### 需求
为 DeviceStatusPanel 的"状态"显示区域创建专用的输入框组件，使用 infostate.png 作为背景图片。

### infostate.png 图片特点
- **尺寸**：278 x 66 像素（宽横向）
- **样式**：
  - 圆角边框
  - 左右两侧三角形装饰
  - 渐变蓝色背景
  - 适合显示较长的状态文本

### 创建 StateInputField 组件

**文件**：`src/qml/components/control_panel/StateInputField.qml`（新建）

```qml
import QtQuick 6.5
import QtQuick.Controls 6.5

// Large Image-based Input Field Component for Status Display
// 2026-02-11: 使用 infostate.png 作为背景的宽输入框组件
Item {
    id: root

    // 可配置属性
    property string text: ""
    property alias horizontalAlignment: textLabel.horizontalAlignment
    property alias font: textLabel.font
    property alias color: textLabel.color

    implicitWidth: 278
    implicitHeight: 66

    // 背景图片 - infostate.png
    Image {
        id: backgroundImage
        anchors.fill: parent
        source: "../../images/infostate.png"
        fillMode: Image.Stretch
    }

    // 文本显示（在图片上方）
    Text {
        id: textLabel
        anchors.centerIn: parent
        text: root.text
        font.pixelSize: 16
        font.bold: true
        color: "white"
    }
}
```

### 在 DeviceStatusPanel 中使用

**修改前**：
```qml
Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: 40
    radius: 5
    color: getDetailedStatusColor()
    border.color: "#00d4ff"
    border.width: 2

    SequentialAnimation on opacity {
        running: root.isRunning && !root.isFault
        loops: Animation.Infinite
        NumberAnimation { to: 0.7; duration: 800 }
        NumberAnimation { to: 1.0; duration: 800 }
    }

    Text {
        anchors.centerIn: parent
        text: root.detailedStatus
        font.pixelSize: 16
        font.bold: true
        color: "white"
    }

    Image {
        id: infostate
        x: 0
        y: 0
        width: 278
        height: 66
        source: "../../images/infostate.png"
        fillMode: Image.PreserveAspectFit
    }
}
```

**问题**：
- Rectangle 和 Image 混合使用，层次不清
- Image 可能覆盖文本
- Rectangle 的颜色和边框不需要了

**修改后**：
```qml
// 2026-02-11: 使用 StateInputField 组件（infostate.png 背景）
StateInputField {
    Layout.preferredWidth: 278
    Layout.preferredHeight: 66
    text: root.detailedStatus

    // 根据状态添加动画效果
    SequentialAnimation on opacity {
        running: root.isRunning && !root.isFault
        loops: Animation.Infinite
        NumberAnimation { to: 0.7; duration: 800 }
        NumberAnimation { to: 1.0; duration: 800 }
    }
}
```

**优点**：
- 结构清晰，层次分明
- 图片作为背景，文本显示在上方
- 保留了动画效果
- 代码简洁

### 更新构建系统

**CMakeLists.txt**：
```cmake
components/control_panel/ImageInputField.qml  # 2026-02-11: 图片背景输入框组件
components/control_panel/StateInputField.qml  # 2026-02-11: 状态显示输入框组件
```

**BeltControlSystem.qrc**：
```xml
<file>components/control_panel/ImageInputField.qml</file>
<file>components/control_panel/StateInputField.qml</file>
```

### 对比：三种输入框组件

| 组件 | 图片 | 尺寸 | 用途 |
|------|------|------|------|
| **ImageInputField** | input1.png + input2.png 叠加 | 80 x 28 | 模式、名称输入框 |
| **StateInputField** | infostate.png | 278 x 66 | 状态显示输入框 |

**设计原则**：
- 小输入框（80x28）：使用 ImageInputField
- 大输入框（278x66）：使用 StateInputField
- 根据图片样式和尺寸选择合适的组件

**Git 提交**：`1e20c8e7` - feat: Phase 7.45.20 - 创建状态显示输入框组件

---

## 总结

本次修改实现了以下功能：
1. ✅ DeviceStatusPanel 使用图片背景
2. ✅ 创建可复用的图片背景输入框组件
3. ✅ 替换原有的 Rectangle 输入框
4. ✅ 更新构建系统和资源同步脚本
5. ✅ 保持原有功能和数据绑定

用户体验提升：
- 更美观的视觉效果
- 统一的设计风格
- 灵活的组件化设计
