# Fix: Input1Page QML 模块导入错误修复

**问题时间**：2026-01-12
**错误信息**：`Input1Page is not a type`
**根本原因**：QML 引擎无法找到 Input1 模块

---

## 🐛 问题描述

编译部署后，应用启动失败，日志显示：

```
[WARNING] qrc:/qt/qml/BeltControlQml/App.qml:193:9: Input1Page is not a type
ERROR: No root objects loaded!
Application exited with code: 255
```

**根本原因**：
1. Input1Page.qml 中的导入路径不正确
2. CMakeLists.txt 中未包含 Input1Page.qml
3. QML 引擎导入路径未配置 Input1 模块目录

---

## ✅ 修复方案

### 修改1：Input1Page.qml 导入路径

**文件**：`src/qml/pages/Input1Page.qml`

**修改前**：
```qml
import "../pages/Input1"        // ❌ 相对路径在运行时无法解析
```

**修改后**：
```qml
import Input1        // ✅ 使用模块名导入
```

---

### 修改2：CMakeLists.txt 添加 QML 文件

**文件**：`src/qml/CMakeLists.txt`

**修改前**：
```cmake
QML_FILES
    main.qml
    App.qml
    pages/ControlPanel.qml
    pages/ParameterSettings.qml
    pages/AlarmPage.qml
    pages/DeviceOperationLog.qml
```

**修改后**：
```cmake
QML_FILES
    main.qml
    App.qml
    pages/ControlPanel.qml
    pages/ParameterSettings.qml
    pages/AlarmPage.qml
    pages/DeviceOperationLog.qml
    pages/Input1Page.qml  # ← 新增
```

---

### 修改3：CMakeLists.txt 配置导入路径

**文件**：`src/qml/CMakeLists.txt`

**在文件末尾添加**：
```cmake
# 添加 QML 导入路径，用于 Input1 模块（QDS 集成）
# 2026-01-12: 添加 Input1 模块导入路径
set(QML_IMPORT_PATH "${CMAKE_CURRENT_SOURCE_DIR}/pages" CACHE STRING "" FORCE)
message(STATUS "QML Import Path: ${QML_IMPORT_PATH}")
```

---

### 修改4：main.cpp 添加运行时导入路径

**文件**：`src/main/main.cpp`

**修改前**：
```cpp
// 添加QML导入路径
logMessage("Adding QML import path...");
engine.addImportPath("qrc:/qt/qml");
logMessage("QML import path added");
```

**修改后**：
```cpp
// 添加QML导入路径
logMessage("Adding QML import path...");
engine.addImportPath("qrc:/qt/qml");
// 2026-01-12: 添加 Input1 模块导入路径（QDS 集成）
engine.addImportPath("qrc:/qt/qml/BeltControlQml/pages");
engine.addImportPath("/app/src/qml/pages");  // Docker 容器内的路径
logMessage("QML import path added");
```

---

## 📋 修改文件清单

| 文件 | 修改类型 | 说明 |
|------|---------|------|
| `src/qml/pages/Input1Page.qml` | 修改 | 修正 import 路径 |
| `src/qml/CMakeLists.txt` | 修改 | 添加 QML 文件和导入路径 |
| `src/main/main.cpp` | 修改 | 添加运行时导入路径 |

---

## 🧪 验证步骤

### 1. 重新编译

```powershell
.\build-ubuntu24-apt.ps1 188
```

### 2. 检查日志

预期在启动日志中看到：

```
Adding QML import path...
QML import path added
Loading QML from: qrc:/qt/qml/BeltControlQml/main.qml
Object created callback: obj=...
```

**不应该看到**：
```
❌ Input1Page is not a type
❌ ERROR: No root objects loaded!
```

### 3. 测试第五个页面

1. 应用正常启动
2. 按右箭头键 4 次切换到第5页
3. 应显示 QDS 设计的输入监控界面

---

## 🔍 技术细节

### QML 模块解析机制

Qt QML 引擎按以下顺序查找模块：

1. **QML 导入路径**（`engine.addImportPath()`）
2. **qmldir 文件**（定义模块结构）
3. **模块文件**（Constants.qml, Screen01.ui.qml 等）

**Input1 模块结构**：
```
src/qml/pages/Input1/
├── qmldir                    # 模块定义文件
├── Constants.qml             # 单例常量
├── EventListModel.qml        # 事件列表模型
└── EventListSimulator.qml    # 事件模拟器
```

**qmldir 内容**：
```
module Input1
singleton Constants 1.0 Constants.qml
EventListSimulator 1.0 EventListSimulator.qml
EventListModel 1.0 EventListModel.qml
```

### 符号链接处理

由于 Input1 和 Input1Content 是符号链接，CMake 在编译时可能无法正确识别。因此我们采用以下策略：

1. **编译时**：只在 CMakeLists.txt 中包含 Input1Page.qml
2. **运行时**：通过导入路径加载 Input1 模块的其他文件

这样既利用了符号链接的实时同步优势，又避免了 CMake 的符号链接处理问题。

---

## 🎯 工作流程验证

修复后的完整工作流程：

```
1. 在 QDS 中编辑 Screen01.ui.qml
   ↓ 保存（Ctrl+S）
2. ✅ 自动同步（符号链接）
   src/qml/pages/Input1Content/Screen01.ui.qml
   ↓
3. 重新编译
   .\build-ubuntu24-apt.ps1 188
   ↓
4. QML 引擎加载顺序：
   - 加载 App.qml
   - 解析 Input1Page {}
   - 查找 Input1Page.qml → ✅ 找到（在 QML_FILES 中）
   - 加载 Input1Page.qml
   - 解析 import Input1 → ✅ 找到（在导入路径中）
   - 加载 Screen01.ui.qml → ✅ 成功
```

---

## 📚 相关文档

- [QDS项目集成和自动同步方案](02-QDS项目集成和自动同步方案.md)
- [QDS集成测试指南](03-QDS集成测试指南.md)
- [Qt QML 模块文档](https://doc.qt.io/qt-6/qtqml-modules-topic.html)

---

**修复者**：Claude
**文档版本**：1.0
**修复时间**：2026-01-12 21:30
