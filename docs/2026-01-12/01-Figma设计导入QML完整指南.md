# Figma 设计导入 QML 完整指南

**创建时间**：2026-01-12
**Figma 文件路径**：`E:\2026\Figma 79大屏合集\追加包\20240903\产品相关或者包材标签.fig`

---

## 方法总览

| 方法 | 难度 | 保真度 | 维护成本 | 推荐场景 |
|------|------|--------|----------|----------|
| **方法1：导出图片资源** | ⭐ 简单 | 高 | 低 | 静态 UI、图标、背景 |
| **方法2：Figma to QML 插件** | ⭐⭐ 中等 | 中 | 中 | 复杂布局、动态 UI |
| **方法3：手动重建 UI** | ⭐⭐⭐ 困难 | 最高 | 高 | 完全定制、交互复杂 |

---

## 方法1：导出图片资源（推荐新手）

### 步骤1：在 Figma 中打开设计文件

1. 访问 [Figma 网页版](https://www.figma.com/) 或使用 Figma Desktop
2. 导入 `.fig` 文件：
   - 点击 **File → Open**
   - 选择 `E:\2026\Figma 79大屏合集\追加包\20240903\产品相关或者包材标签.fig`

### 步骤2：导出设计资源

#### 导出整个页面/画板
```
1. 选择要导出的 Frame（画板）
2. 右侧属性面板找到 "Export" 区域
3. 点击 "+" 添加导出配置：
   - 格式：PNG（推荐）或 SVG（矢量图）
   - 分辨率：@1x, @2x, @3x（适配不同 DPI）
4. 点击 "Export [Frame Name]"
```

#### 导出单个元素（图标、按钮等）
```
1. 选中单个图层
2. 使用快捷键：Ctrl + Shift + E（Windows）
3. 选择格式和分辨率后导出
```

### 步骤3：组织资源文件

在项目中创建资源目录：

```powershell
# 在项目根目录创建资源文件夹
New-Item -Path "resources/images" -ItemType Directory -Force
New-Item -Path "resources/qml" -ItemType Directory -Force
```

**推荐目录结构**：
```
belt_control_system/
├── resources/
│   ├── images/              # 图片资源
│   │   ├── backgrounds/     # 背景图
│   │   ├── icons/          # 图标
│   │   └── buttons/        # 按钮素材
│   ├── qml/                # QML 文件
│   │   ├── main.qml
│   │   └── components/     # 组件
│   └── qml.qrc             # Qt 资源文件
```

### 步骤4：在 QML 中引用图片

#### 创建 Qt 资源文件 (qml.qrc)

```xml
<!DOCTYPE RCC>
<RCC version="1.0">
    <qresource>
        <!-- 背景图 -->
        <file>images/backgrounds/main_bg.png</file>

        <!-- 图标 -->
        <file>images/icons/phone_icon.png</file>
        <file>images/icons/video_icon.png</file>

        <!-- 按钮 -->
        <file>images/buttons/call_button.png</file>
        <file>images/buttons/hangup_button.png</file>
    </qresource>
</RCC>
```

#### 在 QML 中使用图片

```qml
import QtQuick 2.15
import QtQuick.Window 2.15

Window {
    visible: true
    width: 1920
    height: 1080
    title: "Belt Control System"

    // 背景图
    Image {
        anchors.fill: parent
        source: "qrc:/images/backgrounds/main_bg.png"
        fillMode: Image.PreserveAspectCrop
    }

    // 按钮示例
    Rectangle {
        width: 200
        height: 80
        x: 100
        y: 100

        Image {
            anchors.fill: parent
            source: "qrc:/images/buttons/call_button.png"
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                console.log("呼叫按钮点击")
            }
        }
    }
}
```

---

## 方法2：Figma to QML 插件（推荐中级用户）

### 优点
- ✅ 自动生成 QML 布局代码
- ✅ 保留层次结构
- ✅ 快速原型开发

### 缺点
- ⚠️ 生成的代码需要手动优化
- ⚠️ 复杂交互需要手动实现
- ⚠️ 插件支持可能有限

### 使用步骤

#### 1. 安装 Figma 插件

在 Figma 中：
1. 打开 **Plugins → Browse plugins in Community**
2. 搜索 "**QML**" 或 "**Qt**"
3. 推荐插件：
   - **Figma to Code** (支持多种框架)
   - **Anima** (支持导出 HTML/CSS，可转换)

#### 2. 导出 QML 代码

```
1. 选择要导出的 Frame
2. 右键 → Plugins → [选择的插件]
3. 选择导出格式为 QML/Qt
4. 复制生成的代码
```

#### 3. 代码示例（自动生成）

```qml
// 自动生成的 QML（示例）
import QtQuick 2.15

Rectangle {
    id: mainContainer
    width: 1920
    height: 1080
    color: "#FFFFFF"

    // 标题文本
    Text {
        id: titleText
        x: 100
        y: 50
        text: "产品标签"
        font.pixelSize: 48
        font.family: "Arial"
        color: "#333333"
    }

    // 内容区域
    Rectangle {
        id: contentArea
        x: 100
        y: 150
        width: 1720
        height: 800
        color: "#F5F5F5"
        radius: 8
    }
}
```

#### 4. 优化生成的代码

**需要手动处理**：
- 响应式布局（使用 anchors 或 Layout）
- 交互逻辑（MouseArea、信号槽）
- 动画效果（Behavior、Transition）
- 数据绑定（property binding）

---

## 方法3：手动重建 UI（推荐高级用户）

### 适用场景
- 需要完全定制的交互逻辑
- 性能要求高的场景
- 需要数据绑定和状态管理

### 实现步骤

#### 1. 分析 Figma 设计

在 Figma 中查看设计规范：
- **尺寸**：选中元素查看 Width × Height
- **位置**：查看 X, Y 坐标
- **颜色**：点击填充色查看 HEX/RGB 值
- **字体**：查看字体家族、大小、行高
- **间距**：查看 Padding、Margin

#### 2. 创建 QML 组件

**示例：根据 Figma 设计创建呼叫按钮**

Figma 设计规范：
```
名称：呼叫按钮
尺寸：240 × 80 px
圆角：12 px
背景色：#4CAF50
文字：白色，24px，"开始通话"
```

QML 实现：
```qml
// CallButton.qml
import QtQuick 2.15

Rectangle {
    id: callButton
    width: 240
    height: 80
    radius: 12
    color: "#4CAF50"

    // 按下效果
    states: State {
        name: "pressed"
        when: mouseArea.pressed
        PropertyChanges {
            target: callButton
            color: "#45a049"
        }
    }

    // 文字
    Text {
        anchors.centerIn: parent
        text: "开始通话"
        font.pixelSize: 24
        font.family: "Microsoft YaHei"
        color: "#FFFFFF"
    }

    // 点击区域
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        onClicked: {
            // 触发通话逻辑
            console.log("开始通话")
        }
    }

    // 悬停效果
    transitions: Transition {
        ColorAnimation {
            duration: 200
        }
    }
}
```

#### 3. 在主界面中使用组件

```qml
// main.qml
import QtQuick 2.15
import QtQuick.Window 2.15

Window {
    visible: true
    width: 1920
    height: 1080

    // 背景
    Rectangle {
        anchors.fill: parent
        color: "#F0F0F0"
    }

    // 使用自定义按钮
    CallButton {
        x: 840  // 居中：(1920 - 240) / 2
        y: 500
    }
}
```

---

## 最佳实践建议

### 1. 混合使用多种方法

```
✅ 静态背景 → 导出 PNG
✅ 图标 → 导出 SVG（支持缩放）
✅ 布局框架 → 手写 QML
✅ 复杂组件 → 插件辅助 + 手动优化
```

### 2. 建立设计规范文档

从 Figma 提取：
- 颜色板：`#4CAF50`, `#2196F3`, `#F44336`
- 字体：Arial, Microsoft YaHei, 24px/48px
- 间距：8px, 16px, 24px
- 圆角：4px, 8px, 12px

在 QML 中统一定义：

```qml
// Theme.qml
pragma Singleton
import QtQuick 2.15

QtObject {
    // 颜色
    readonly property color primary: "#4CAF50"
    readonly property color secondary: "#2196F3"
    readonly property color danger: "#F44336"

    // 字体
    readonly property string fontFamily: "Microsoft YaHei"
    readonly property int fontSizeSmall: 16
    readonly property int fontSizeMedium: 24
    readonly property int fontSizeLarge: 48

    // 间距
    readonly property int spacingSmall: 8
    readonly property int spacingMedium: 16
    readonly property int spacingLarge: 24
}
```

### 3. 使用响应式布局

```qml
// 避免硬编码坐标
Rectangle {
    // ❌ 不推荐
    x: 100
    y: 200
    width: 300
    height: 100

    // ✅ 推荐
    anchors.centerIn: parent
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.topMargin: 50
    width: parent.width * 0.8
    height: 100
}
```

---

## 项目集成 Checklist

### 配置 CMakeLists.txt

```cmake
# 添加 Qt 资源文件
qt5_add_resources(QML_RESOURCES resources/qml.qrc)

# 添加到可执行文件
add_executable(belt_control_system
    src/main.cpp
    ${QML_RESOURCES}
)

# 链接 Qt 模块
target_link_libraries(belt_control_system
    Qt5::Core
    Qt5::Quick
    Qt5::Qml
)
```

### 在 C++ 中加载 QML

```cpp
// main.cpp
#include <QGuiApplication>
#include <QQmlApplicationEngine>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine;

    // 加载 QML 文件
    engine.load(QUrl(QStringLiteral("qrc:/qml/main.qml")));

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
```

---

## 常见问题

### Q1: `.fig` 文件无法在本地打开？
**A**: Figma 桌面版可以直接打开，网页版需要先导入文件。

### Q2: 导出的图片模糊？
**A**: 确保导出时选择 @2x 或 @3x 分辨率，适配高 DPI 屏幕。

### Q3: QML 中图片路径找不到？
**A**: 检查 `qml.qrc` 文件是否正确添加到 CMakeLists.txt，路径使用 `qrc:/` 前缀。

### Q4: 中文显示乱码？
**A**:
```qml
Text {
    text: "中文文字"
    font.family: "Microsoft YaHei"  // 指定支持中文的字体
}
```

---

## 下一步建议

1. **导出 Figma 设计资源**（PNG/SVG）
2. **创建 Qt 资源文件** (`resources/qml.qrc`)
3. **编写示例 QML 页面**验证集成
4. **逐步替换现有 UI**（如果有）

---

## 参考资料

- [Figma 导出指南](https://help.figma.com/hc/en-us/articles/360040028114-Guide-to-exports-in-Figma)
- [Qt QML 文档](https://doc.qt.io/qt-5/qtqml-index.html)
- [Qt Quick 控件](https://doc.qt.io/qt-5/qtquickcontrols-index.html)

---

**创建者**：Claude
**文档版本**：1.0
**最后更新**：2026-01-12
