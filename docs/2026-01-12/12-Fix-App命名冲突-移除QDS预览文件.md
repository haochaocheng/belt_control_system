# Fix: App.qml 命名冲突 - 移除 QDS 预览文件

**创建时间**：2026-01-12
**问题编号**：编译后运行错误
**状态**：✅ 已修复

---

## 📋 问题描述

### 错误现象

修复了 Input1 模块导入错误后，运行时出现新错误：

```
[WARNING] qrc:/qt/qml/BeltControlQml/main.qml:62:9: Cannot assign to non-existent property "anchors"
ERROR: No root objects loaded!
```

### 根本原因

**命名冲突**：CMakeLists.txt 中包含了两个 `App.qml` 文件：

1. **主应用的 App.qml**（正确）：
   ```
   src/qml/App.qml
   ```
   - 根对象：`Item`
   - 功能：主应用界面，包含 SwipeView、所有页面等

2. **QDS 项目的 App.qml**（不应包含）：
   ```
   src/qml/Input1/Input1Content/App.qml
   ```
   - 根对象：`Window`
   - 功能：仅用于 Qt Design Studio 中预览 Screen01.ui.qml

### 为什么会发生？

Qt QML 模块系统中，同名组件会产生冲突。当两个 `App.qml` 都在同一个模块（`BeltControlQml`）中时：

1. **编译时**：两个文件都被打包到 qrc 资源中
2. **运行时**：QML 引擎加载 `App` 组件时产生歧义
3. **结果**：加载了错误的 `App`（Input1Content/App.qml，根对象是 Window）
4. **错误**：`main.qml` 尝试在 Window 上设置 `anchors`，但 Window 没有 `anchors` 属性

### 文件对比

#### 主应用的 App.qml（应该使用的）

```qml
// src/qml/App.qml
import QtQuick 6.5
import QtQuick.Controls 6.5

Item {              // ← 根对象是 Item，有 anchors 属性
    id: app
    anchors.fill: parent

    SwipeView {
        // ... 所有页面
    }
}
```

#### QDS 预览的 App.qml（不应包含）

```qml
// src/qml/Input1/Input1Content/App.qml
import QtQuick
import Input1

Window {            // ← 根对象是 Window，没有 anchors 属性！
    width: mainScreen.width
    height: mainScreen.height
    visible: true
    title: "Input1"

    Screen01 {      // ← 仅用于 QDS 预览
        id: mainScreen
    }
}
```

---

## ✅ 解决方案

### 策略

**从应用中移除 `Input1/Input1Content/App.qml`**，因为：

1. **用途单一**：仅用于 Qt Design Studio 中预览 Screen01.ui.qml
2. **命名冲突**：与主应用的 App.qml 冲突
3. **不需要**：实际应用使用 Input1Page.qml 加载 Screen01.ui.qml

### 实施方法

#### CMakeLists.txt 修改

**修改前**：
```cmake
QML_FILES
    # ...
    pages/Input1Page.qml
    # 2026-01-12: Input1 模块 QML 文件已移到独立的 Input1 模块中（见文件末尾）
    # Input1/Input1Content/App.qml 和 Screen01.ui.qml 在主模块中
    Input1/Input1Content/App.qml        ← 移除这一行
    Input1/Input1Content/Screen01.ui.qml
```

**修改后**：
```cmake
QML_FILES
    # ...
    pages/Input1Page.qml
    # 2026-01-12: Input1 模块 QML 文件已移到独立的 Input1 模块中（见文件末尾）
    # Input1/Input1Content/Screen01.ui.qml 是实际的 UI 文件
    # Input1/Input1Content/App.qml 仅用于 QDS 预览，不包含在应用中
    Input1/Input1Content/Screen01.ui.qml
```

---

## 📊 技术细节

### QDS 项目文件结构

Qt Design Studio 项目包含两类文件：

1. **UI 文件**（.ui.qml）：
   - `Screen01.ui.qml` - 实际的设计界面
   - 可以在应用中使用

2. **启动文件**（App.qml）：
   - 用于在 QDS 中预览 UI 文件
   - 不应该包含在应用中

### 正确的集成方式

```
应用集成 QDS 设计：
  ├─ 包含：Screen01.ui.qml（UI 文件）
  ├─ 包含：images/*（资源文件）
  └─ 不包含：App.qml（QDS 预览文件）

QDS 预览：
  ├─ 打开：src/qml/Input1/Input1.qmlproject
  ├─ 使用：App.qml 启动 Screen01.ui.qml
  └─ 预览：实时查看设计效果
```

### QML 组件命名规则

- **文件名 = 组件名**：`App.qml` → `App` 组件
- **唯一性**：同一模块内不能有同名组件
- **导入**：`import BeltControlQml` 后可使用 `App` 组件

---

## 🎯 预期效果

### 编译时

```
-- Input1 QML 模块已创建为独立模块
-- Configuring done
-- Generating done
-- Build complete
```

### 运行时

```
All control modules created
Setting context properties...
Context properties set
Loading QML from: qrc:/qt/qml/BeltControlQml/main.qml

Input1Page 已加载
✅ Input1 Screen01 加载成功
```

**无错误**，主应用的 `App.qml` 正确加载，`anchors` 属性正常工作。

---

## 🧪 测试步骤

### 1. 清理并重新编译

```powershell
Remove-Item build_rk3588 -Recurse -Force -ErrorAction SilentlyContinue
.\build-ubuntu24-apt.ps1 188
```

### 2. 验证运行

SSH 连接到设备：

```bash
ssh linaro@192.168.10.188
docker logs belt-control-ubuntu24 --tail 100
```

**预期输出**：
- ✅ 无 "Cannot assign to non-existent property" 错误
- ✅ 应用正常启动
- ✅ Input1Page 正确加载

### 3. 验证 QDS 预览仍然工作

在 Qt Design Studio 中：

1. 打开项目：`src/qml/Input1/Input1.qmlproject`
2. 运行预览（使用 App.qml 启动）
3. 验证：Screen01.ui.qml 在 QDS 中正常显示

**结果**：✅ QDS 预览功能不受影响（App.qml 仍在文件系统中，只是不打包到应用）

---

## 📝 相关文件

### 修改的文件

1. [src/qml/CMakeLists.txt](../../src/qml/CMakeLists.txt)
   - 移除 `Input1/Input1Content/App.qml`

### 保留但不打包的文件

1. [src/qml/Input1/Input1Content/App.qml](../../src/qml/Input1/Input1Content/App.qml)
   - 文件仍存在于文件系统
   - Qt Design Studio 仍可使用
   - 不打包到应用 qrc 资源中

### 参考文档

1. [11-Fix-Input1模块导入错误-创建独立QML模块.md](11-Fix-Input1模块导入错误-创建独立QML模块.md)
2. [10-实施完成总结-QDS直接集成.md](10-实施完成总结-QDS直接集成.md)

---

## 🔍 故障排查

### 问题 1：QDS 预览不工作

**现象**：Qt Design Studio 中无法预览 Screen01.ui.qml

**原因**：误删了 App.qml 文件

**解决**：
```bash
# 检查文件是否存在
ls src/qml/Input1/Input1Content/App.qml
# 如果不存在，从 QDS 重新生成项目
```

---

### 问题 2：仍然报错 "Cannot assign to anchors"

**原因**：构建缓存未清理

**解决**：
```powershell
# 完全清理构建
Remove-Item build_rk3588 -Recurse -Force -ErrorAction SilentlyContinue
# 重新编译
.\build-ubuntu24-apt.ps1 188
```

---

## 🎓 技术总结

### 关键发现

1. **QDS 文件分类**：
   - UI 文件（.ui.qml）→ 应用中使用
   - 预览文件（App.qml）→ 仅 QDS 使用

2. **命名冲突**：
   - QML 模块内组件名必须唯一
   - 文件名决定组件名
   - 同名文件会产生歧义

3. **Window vs Item**：
   - Window：顶层窗口，无 anchors 属性
   - Item：布局元素，有 anchors 属性

### 最佳实践

1. **QDS 集成**：
   - 只打包 UI 文件和资源文件
   - 预览文件保留在文件系统，不打包

2. **组件命名**：
   - 避免同名组件
   - 使用有意义的名称
   - 遵循 Qt 命名规范

3. **目录组织**：
   ```
   src/qml/
   ├─ App.qml                    ← 主应用
   ├─ Input1/
   │  ├─ Input1/                 ← 模块基础设施
   │  │  ├─ Constants.qml
   │  │  └─ qmldir
   │  └─ Input1Content/          ← UI 和资源
   │     ├─ App.qml              ← QDS 预览（不打包）
   │     ├─ Screen01.ui.qml      ← UI 文件（打包）
   │     └─ images/*             ← 资源（打包）
   └─ pages/
      └─ Input1Page.qml          ← 应用入口
   ```

---

**创建者**：Claude
**文档版本**：1.0
**最后更新**：2026-01-12
