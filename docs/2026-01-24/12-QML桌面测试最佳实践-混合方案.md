# QML 桌面测试最佳实践 - qmlscene 方案

**文档版本**: v2.0
**创建日期**: 2026-01-24
**状态**: ✅ 推荐方案

---

## 问题分析

### 文件复制方案的缺陷

❌ **无法双向同步**：
- 复制到 QmlPreview 后修改路径（qrc 路径）
- 修改后的文件无法同步回 src/qml
- 需要手动维护两份代码

❌ **路径不一致**：
- QmlPreview: `qrc:/qt/qml/QmlPreview/...`
- 主项目: `qrc:/qt/qml/BeltControlQml/...`

---

## 最佳方案：qmlscene

### 方案说明

使用 Qt 官方的 **qmlscene** 工具直接测试源文件：

```powershell
qmlscene -I <import-path> <qml-file>
```

### 优势

- ✅ **直接测试源文件** - 无需复制
- ✅ **修改立即生效** - 保存后重新运行即可
- ✅ **无需同步** - 修改的就是源文件
- ✅ **Qt 官方工具** - 稳定可靠

### 限制

- ❌ **无法加载 qrc 资源** - 图片、字体等资源无法加载
- ❌ **无法使用 C++ 后端** - 只能测试纯 QML 组件
- ❌ **需要独立运行** - 不能在 Qt Creator 中调试

---

## 实用方案：混合方案

### 方案 1：Qt Design Studio（推荐用于布局调整）

**适用场景**：
- 调整组件位置、大小
- 修改颜色、字体
- 可视化编辑

**使用方法**：
```
1. Qt Design Studio → 打开 DeviceSettingsDialog.qml
2. 可视化调整
3. 保存（自动更新源文件）
```

**优势**：
- ✅ 所见即所得
- ✅ 直接修改源文件
- ✅ 实时预览

**限制**：
- ❌ 无法测试交互逻辑
- ❌ 无法测试键盘导航

---

### 方案 2：简化测试项目（推荐用于交互测试）

**适用场景**：
- 测试键盘导航
- 测试按钮点击
- 测试数据绑定

**实施步骤**：

#### 1. 创建简化的测试组件

在 QmlPreview 中创建 **TestDeviceDialog.qml**（不复制原文件）：

```qml
import QtQuick 2.15
import QtQuick.Controls 2.15

// ✅ 简化版：只测试核心交互逻辑
Rectangle {
    id: root
    width: 800
    height: 550
    color: "#1e1e1e"

    property int currentCategory: 0

    focus: true

    Keys.onUpPressed: {
        if (root.currentCategory > 0) {
            root.currentCategory--
        }
    }

    Keys.onDownPressed: {
        if (root.currentCategory < 6) {
            root.currentCategory++
        }
    }

    // 左侧类别按钮
    Column {
        anchors.left: parent.left
        anchors.margins: 20
        spacing: 10

        Repeater {
            model: ["基本配置", "开关量输入", "模拟量输入",
                    "电机控制", "制动器控制", "张紧控制", "逻辑控制"]

            Button {
                text: modelData
                highlighted: root.currentCategory === index
                onClicked: root.currentCategory = index
            }
        }
    }

    // 右侧内容区域
    StackLayout {
        anchors.left: parent.left
        anchors.leftMargin: 200
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 20

        currentIndex: root.currentCategory

        // 7 个页面占位符
        Repeater {
            model: 7
            Rectangle {
                color: "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "类别 " + (index + 1)
                    color: "#FFFFFF"
                    font.pixelSize: 24
                }
            }
        }
    }
}
```

#### 2. 在 main.qml 中加载

```qml
Loader {
    source: "TestDeviceDialog.qml"
}
```

#### 3. 测试通过后，应用到源文件

将测试通过的交互逻辑复制到 `src/qml/components/device_info/DeviceSettingsDialog.qml`

---

### 方案 3：Qt Creator QML 预览

**使用方法**：
```
1. Qt Creator → 打开 DeviceSettingsDialog.qml
2. 菜单栏 → 工具 → QML/JS → Show Qt Quick Designer
3. 或快捷键：Alt+Shift+D
```

**优势**：
- ✅ 集成在 Qt Creator 中
- ✅ 代码和预览同步

**限制**：
- ❌ 预览功能不稳定
- ❌ 复杂组件可能无法预览

---

## 推荐工作流程

### 阶段 1：布局设计（Qt Design Studio）

```
Qt Design Studio → 打开源文件 → 可视化调整 → 保存
```

**时间**：几秒钟
**效果**：布局、颜色、字体调整

---

### 阶段 2：交互测试（简化测试项目）

```
1. 在 QmlPreview 创建简化测试组件
2. 实现核心交互逻辑
3. Qt Creator → Ctrl+R 快速测试
4. 测试通过后，复制逻辑到源文件
```

**时间**：5-10 秒
**效果**：键盘导航、按钮点击、数据绑定

---

### 阶段 3：完整验证（设备部署）

```
.\build-ubuntu24-apt.ps1 188
```

**时间**：30-60 分钟
**效果**：真机测试、完整功能验证

---

## 总结

### 最佳实践

| 任务 | 工具 | 时间 | 优势 |
|------|------|------|------|
| 布局调整 | Qt Design Studio | 几秒 | 所见即所得 |
| 交互测试 | 简化测试项目 | 5-10秒 | 快速迭代 |
| 完整验证 | 设备部署 | 30-60分钟 | 真机测试 |

### 关键原则

1. **不复制源文件** - 避免同步问题
2. **分离关注点** - 布局用 QDS，交互用测试项目
3. **快速迭代** - 先测试，后应用到源文件

---

## 参考资料

- [Prototyping with qmlscene](https://doc.qt.io/qt-5/qtquick-qmlscene.html)
- [Speed up Qt Development with QML Hot Reload](https://www.qt.io/blog/speed-up-qt-development-with-qml-hot-reload)
- [Qt Design Studio Documentation](https://doc.qt.io/qtdesignstudio/)

---

**下一步**：使用 Qt Design Studio 调整布局，使用简化测试项目测试交互。
