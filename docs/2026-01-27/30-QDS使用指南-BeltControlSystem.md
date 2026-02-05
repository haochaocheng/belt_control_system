# Qt Design Studio 使用指南 - BeltControlSystem 项目

**项目文件**: `src/qml/BeltControlSystem.qmlproject`
**日期**: 2026-01-27
**状态**: ✅ 已修复 Input1 加载问题

## 🚀 快速开始

### 1. 打开项目

```
1. 启动 Qt Design Studio
2. File → Open Project
3. 选择: src\qml\BeltControlSystem.qmlproject
4. 等待项目加载完成
```

### 2. 验证 Input1 模块

**检查点**:
- ✅ 左侧组件库中应该显示 Input1Content 组件
- ✅ 打开 Screen01.qml 不应有错误
- ✅ 可以拖放 Back, Head, MyIN_Data 等组件

### 3. 开始设计

**推荐工作流**:
1. 在 QDS 中设计 UI（.ui.qml 文件）
2. 在代码编辑器中添加逻辑（.qml 文件）
3. 使用 QDS 预览效果

## 📁 项目结构

```
src/qml/
├── BeltControlSystem.qmlproject  ← 主项目文件
├── main_qds.qml                  ← QDS 入口（不依赖 C++）
├── Input1/
│   ├── Input1/
│   │   ├── qmldir                ✅ Input1 模块定义
│   │   └── Constants.qml
│   └── Input1Content/
│       ├── qmldir                ✅ Input1Content 模块定义（已修复）
│       ├── Back.ui.qml
│       ├── Head.ui.qml
│       ├── Screen01.qml
│       └── Screen01Form.ui.qml
├── components/
│   └── ...
└── pages/
    └── ...
```

## 🎨 可用组件

### Input1Content 模块

| 组件 | 文件 | 用途 |
|------|------|------|
| Back | Back.ui.qml | 背景组件 |
| Head | Head.ui.qml | 头部导航 |
| Head_MiddleMenu | Head_MiddleMenu.ui.qml | 头部菜单项 |
| MyIN_Data | MyIN_Data.ui.qml | 数据显示卡片 |
| MyIN_State | MyIN_State.ui.qml | 状态显示 |
| Screen01 | Screen01.qml | 主屏幕（带逻辑） |
| Screen01Form | Screen01Form.ui.qml | 主屏幕（纯 UI） |

### 使用示例

```qml
import QtQuick
import Input1
import Input1Content

Rectangle {
    width: 1920
    height: 1080

    // 背景
    Back {
        anchors.fill: parent
    }

    // 头部
    Head {
        anchors.top: parent.top
        width: parent.width
        height: 80
    }

    // 数据卡片
    MyIN_Data {
        x: 100
        y: 100
        width: 480
        height: 333
    }
}
```

## 🔧 常见问题

### 问题 1: Input1 模块加载失败

**症状**:
```
module "Input1Content" is not installed
```

**解决**:
✅ 已修复 - qmldir 文件已创建

**验证**:
```powershell
cat src\qml\Input1\Input1Content\qmldir
```

### 问题 2: 组件无法拖放

**原因**: QDS 缓存未更新

**解决**:
1. 关闭 QDS
2. 删除缓存：
   ```powershell
   cd src\qml
   rm .qmlproject.user*
   rm -r .qtc_clangd
   ```
3. 重新打开项目

### 问题 3: 预览显示错误

**原因**: 缺少 C++ 后端

**解决**: 使用 `main_qds.qml` 作为入口
- 这个文件不依赖 C++ 后端
- 使用 Mock 数据进行预览

### 问题 4: 图片无法显示

**原因**: 图片路径不正确

**检查**:
```qml
// ✅ 正确：相对于组件文件的路径
source: "images/IN_Data.png"

// ❌ 错误：绝对路径
source: "Input1Content/images/IN_Data.png"
```

## 📝 设计规范

### .ui.qml 文件规则

**只能包含**:
- 声明式 QML 代码
- 属性绑定
- States 和 Transitions

**不能包含**:
- JavaScript 函数
- 信号处理器（除了简单的属性赋值）
- 复杂的逻辑

**示例**:
```qml
// ✅ 正确的 .ui.qml
Rectangle {
    width: 1920
    height: 1080
    color: "#0a1628"

    property bool selected: false

    states: [
        State {
            name: "selected"
            when: selected
            PropertyChanges {
                target: rectangle
                color: "#1a2638"
            }
        }
    ]
}

// ❌ 错误的 .ui.qml
Rectangle {
    // ❌ 不能有 JavaScript 函数
    function updateColor() {
        color = "#1a2638"
    }

    // ❌ 不能有复杂的信号处理
    onClicked: {
        console.log("clicked")
        updateColor()
    }
}
```

### .qml 文件（包装器）

**用途**: 添加业务逻辑

**示例**:
```qml
// Screen01.qml - 包装器
import QtQuick

Item {
    property int selectedIndex: 0

    // 加载 UI 文件
    Screen01Form {
        id: form
        anchors.fill: parent
    }

    // 添加逻辑
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Up) {
            selectedIndex--
        }
    }
}
```

## 🎯 工作流程

### 1. 设计阶段（QDS）

```
1. 打开 Screen01Form.ui.qml
2. 使用设计器拖放组件
3. 调整布局和样式
4. 添加 states 和 transitions
5. 预览效果
```

### 2. 逻辑阶段（代码编辑器）

```
1. 打开 Screen01.qml
2. 添加属性和函数
3. 实现键盘导航
4. 连接信号和槽
5. 测试功能
```

### 3. 集成阶段

```
1. 在 main.qml 中使用 Screen01
2. 测试完整流程
3. 调试问题
4. 优化性能
```

## 📚 相关文档

- [29-FIX100.300.55-修复QDS加载Input1失败.md](29-FIX100.300.55-修复QDS加载Input1失败.md) - 问题修复详解
- [26-FIX100.300.54-添加键盘导航和选中状态.md](26-FIX100.300.54-添加键盘导航和选中状态.md) - 键盘导航实现
- [25-FIX100.300.53-Screen01重新设计3x4网格布局.md](25-FIX100.300.53-Screen01重新设计3x4网格布局.md) - 布局设计

## ✅ 检查清单

在开始设计前，确认：

- [ ] Qt Design Studio 已安装（版本 4.8+）
- [ ] 项目文件可以正常打开
- [ ] Input1Content 组件在组件库中可见
- [ ] Screen01.qml 可以正常打开
- [ ] 预览功能正常工作
- [ ] 图片资源可以正常显示

## 🚀 下一步

1. **打开 QDS**: 启动 Qt Design Studio
2. **加载项目**: 打开 BeltControlSystem.qmlproject
3. **验证修复**: 检查 Input1Content 组件是否可用
4. **开始设计**: 编辑 Screen01Form.ui.qml

如果遇到问题，参考 [29-FIX100.300.55-修复QDS加载Input1失败.md](29-FIX100.300.55-修复QDS加载Input1失败.md) 中的故障排查部分。
