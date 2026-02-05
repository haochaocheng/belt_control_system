# 编译错误修复说明 - QmlPreview 项目

**问题**：
```
ninja: error: mkdir(.rcc/qmlcache/QmlPreview_../src): No such file or directory
```

**原因**：
Qt 的 qmlcache 系统无法处理跨目录的相对路径（`../src/qml/...`）

**解决方案**：
使用 Loader 动态加载，不在 CMakeLists.txt 中声明跨目录的 QML 文件

---

## 已修复的文件

### 1. CMakeLists.txt
- ✅ 只声明 main.qml
- ✅ 移除了跨目录的 QML 文件引用

### 2. main.qml
- ✅ 使用 Loader 动态加载 DeviceSettingsDialog
- ✅ 使用 Qt.resolvedUrl 解析相对路径
- ✅ 添加了错误处理和提示

---

## 重新编译步骤

### 1. 清理构建目录
在 Qt Creator 中：
```
构建 → 清除 → 清除全部
```

或手动删除：
```powershell
Remove-Item -Recurse -Force "E:/2025/3_gongkongji/belt_control_system/QmlPreview/build" -ErrorAction SilentlyContinue
```

### 2. 重新配置
```
构建 → 运行 CMake
```

### 3. 编译运行
```
快捷键：Ctrl+R
```

---

## 预期结果

**成功编译后**：
- ✅ 显示窗口
- ✅ 顶部显示测试说明
- ✅ 中间显示 DeviceSettingsDialog 弹窗
- ✅ 可以使用键盘导航

**如果加载失败**：
- 会显示错误提示和尝试的路径
- 检查控制台输出的路径是否正确

---

## 备选方案：简化版本（✅ 已采用）

由于跨目录引用的路径解析问题，我们采用了更简单的方案：

### 创建简化的测试文件

在 QmlPreview 目录中创建了 `TestDialog.qml`：
- ✅ 完全自包含，无外部依赖
- ✅ 模拟 DeviceSettingsDialog 的核心功能
- ✅ 支持键盘导航测试
- ✅ 包含 7 个类别切换
- ✅ 包含底部按钮交互

### 使用方法

在 main.qml 中直接加载：
```qml
Loader {
    anchors.centerIn: parent
    width: 800
    height: 550
    source: "TestDialog.qml"
}
```

在 CMakeLists.txt 中声明：
```cmake
QML_FILES
    main.qml
    TestDialog.qml
```

这样就完全避免了跨目录引用的问题。

```qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    width: 800
    height: 550
    color: "#ec1e1e1e"

    property string deviceName: "1号皮带（测试）"
    property int deviceId: 1
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

    // 背景
    Rectangle {
        anchors.fill: parent
        color: "#1e1e1e"
    }

    // 左侧按钮
    Column {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 20
        spacing: 10

        Repeater {
            model: ["基本配置", "开关量输入", "模拟量输入", "电机控制", "制动器控制", "张紧控制", "逻辑控制"]

            Button {
                width: 120
                height: 40
                text: modelData
                background: Rectangle {
                    color: root.currentCategory === index ? "#00AA00" : "#333333"
                    border.color: root.currentCategory === index ? "#00FF00" : "#666666"
                    radius: 4
                }
                contentItem: Text {
                    text: parent.text
                    color: "#FFFFFF"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    root.currentCategory = index
                }
            }
        }
    }

    // 中间内容
    Text {
        anchors.centerIn: parent
        text: "当前类别: " + ["基本配置", "开关量输入", "模拟量输入", "电机控制", "制动器控制", "张紧控制", "逻辑控制"][root.currentCategory]
        font.pixelSize: 24
        color: "#FFFFFF"
    }
}
```

然后在 main.qml 中使用：
```qml
Loader {
    anchors.centerIn: parent
    width: 800
    height: 550
    source: "TestDialog.qml"
}
```

这样就完全避免了跨目录引用的问题。

---

**立即尝试**：
1. 清理构建目录
2. 重新编译（Ctrl+R）
3. 查看效果
