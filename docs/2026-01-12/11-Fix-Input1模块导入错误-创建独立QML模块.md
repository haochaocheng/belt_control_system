# Fix: Input1 模块导入错误 - 创建独立 QML 模块

**创建时间**：2026-01-12
**问题编号**：编译后运行错误
**状态**：✅ 已修复

---

## 📋 问题描述

### 错误现象

编译成功后，运行时出现错误：

```
[WARNING] qrc:/qt/qml/BeltControlQml/Input1/Input1Content/App.qml:2:1: module "Input1" is not installed
ERROR: No root objects loaded!
```

### 根本原因

1. **QDS 项目使用模块导入**：
   - `Screen01.ui.qml` 第 11 行：`import Input1`
   - `App.qml` 第 2 行：`import Input1`

2. **qmldir 文件定义了 Input1 模块**：
   ```qml
   // Input1/Input1/qmldir
   module Input1
   singleton Constants 1.0 Constants.qml
   EventListSimulator 1.0 EventListSimulator.qml
   EventListModel 1.0 EventListModel.qml
   ```

3. **但 CMakeLists.txt 将所有文件打包到 BeltControlQml 模块**：
   - `Constants.qml` 等文件在 `BeltControlQml` 模块中
   - 运行时找不到 "Input1" 模块

### 为什么会发生？

Qt Design Studio 生成的项目使用 `import Input1` 来导入模块内部的单例和组件。当我们将这些文件直接打包到 `BeltControlQml` 模块时，没有创建独立的 "Input1" 模块，导致运行时无法解析 `import Input1`。

---

## ✅ 解决方案

### 策略

**创建独立的 Input1 QML 模块**，让 `import Input1` 能正常工作。

### 模块架构

```
BeltControlQml 模块 (主模块)
  ├─ main.qml
  ├─ App.qml
  ├─ pages/*.qml
  ├─ components/*.qml
  ├─ Input1/Input1Content/App.qml         ← UI 文件
  ├─ Input1/Input1Content/Screen01.ui.qml ← UI 文件
  └─ Input1/Input1Content/images/*        ← 资源文件

Input1 模块 (独立子模块，URI: Input1)
  ├─ Constants.qml          ← 单例
  ├─ EventListModel.qml     ← 组件
  └─ EventListSimulator.qml ← 组件
```

### 工作原理

1. **Input1 模块提供基础设施**：
   - `Constants` 单例（宽度、高度、字体、颜色等）
   - `EventListModel` 和 `EventListSimulator` 组件

2. **BeltControlQml 模块包含 UI 文件**：
   - `Screen01.ui.qml` 使用 `import Input1` 导入 Constants
   - 资源文件（图片）在 BeltControlQml 中

3. **模块链接**：
   - `qml_module` (BeltControlQml) 链接 `input1_qml_module` (Input1)
   - 运行时 Input1 模块对 BeltControlQml 可见

---

## 🔧 实现细节

### CMakeLists.txt 修改

#### 1. 从 BeltControlQml 移除 Input1 基础文件

```cmake
QML_FILES
    # ...
    pages/Input1Page.qml
    # 2026-01-12: Input1 模块 QML 文件已移到独立的 Input1 模块中（见文件末尾）
    # Input1/Input1Content/App.qml 和 Screen01.ui.qml 在主模块中
    Input1/Input1Content/App.qml
    Input1/Input1Content/Screen01.ui.qml
    # ...
```

**移除的文件**：
- ~~`Input1/Input1/Constants.qml`~~
- ~~`Input1/Input1/EventListModel.qml`~~
- ~~`Input1/Input1/EventListSimulator.qml`~~

**保留的文件**：
- ✅ `Input1/Input1Content/App.qml`
- ✅ `Input1/Input1Content/Screen01.ui.qml`
- ✅ `Input1/Input1Content/images/*`（所有资源文件）

#### 2. 创建独立的 Input1 模块

在 CMakeLists.txt 末尾添加：

```cmake
# 2026-01-12: Input1 QML 模块（QDS 项目）
# 创建独立的 Input1 模块，使 Screen01.ui.qml 能够 import Input1
qt_add_qml_module(input1_qml_module
    URI Input1
    VERSION 1.0
    STATIC
    NO_PLUGIN
    NO_GENERATE_QMLTYPES
    QML_FILES
        Input1/Input1/Constants.qml
        Input1/Input1/EventListModel.qml
        Input1/Input1/EventListSimulator.qml
    RESOURCE_PREFIX /qt/qml
    OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Input1
)

# Input1 模块依赖
target_link_libraries(input1_qml_module PRIVATE
    Qt6::Qml
    Qt6::Quick
)

# 将 Input1 模块链接到主 qml_module
target_link_libraries(qml_module PRIVATE input1_qml_module)

message(STATUS "Input1 QML 模块已创建为独立模块")
```

**关键参数**：
- `URI Input1`：模块名称，对应 `import Input1`
- `STATIC`：静态链接
- `NO_PLUGIN`：不生成插件
- `RESOURCE_PREFIX /qt/qml`：资源前缀
- `OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Input1`：输出目录

---

## 📊 技术细节

### QML 模块系统工作原理

1. **模块注册**：
   ```cmake
   qt_add_qml_module(input1_qml_module
       URI Input1  # 定义模块 URI
       ...
   )
   ```

2. **qmldir 文件**：
   ```qml
   // Input1/Input1/qmldir（由 QDS 生成）
   module Input1
   singleton Constants 1.0 Constants.qml
   EventListSimulator 1.0 EventListSimulator.qml
   EventListModel 1.0 EventListModel.qml
   ```

3. **运行时导入**：
   ```qml
   // Screen01.ui.qml
   import Input1  // 导入 Input1 模块

   Rectangle {
       width: Constants.width   // 使用 Constants 单例
       height: Constants.height
   }
   ```

### 模块解析路径

运行时 QML 引擎搜索模块的路径：
```
qrc:/qt/qml/Input1/   ← Input1 模块
qrc:/qt/qml/BeltControlQml/   ← BeltControlQml 模块
```

### Constants 单例

```qml
// Input1/Input1/Constants.qml
pragma Singleton
import QtQuick

QtObject {
    readonly property int width: 1920
    readonly property int height: 1080
    readonly property color backgroundColor: "#EAEAEA"
    // ...
}
```

**使用**：
```qml
import Input1

Rectangle {
    width: Constants.width   // 直接使用单例
}
```

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
Input1Page 已加载
✅ Input1 Screen01 加载成功
```

**无错误**，`import Input1` 正常解析。

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
docker logs belt-control-ubuntu24 --tail 50 | grep -i "input1"
```

**预期输出**：
```
Input1Page 已加载
✅ Input1 Screen01 加载成功
```

### 3. 界面功能测试

- 启动应用
- 切换到第 5 个页面（Input1Page）
- 验证：
  - ✅ Screen01.ui.qml 界面正确显示
  - ✅ 所有图片资源加载正常
  - ✅ Constants 单例工作正常（宽度、高度、颜色等）
  - ✅ 无加载错误或警告

---

## 📝 相关文件

### 修改的文件

1. [src/qml/CMakeLists.txt](../../src/qml/CMakeLists.txt)
   - 从 BeltControlQml 移除 Input1 基础文件
   - 添加独立的 Input1 QML 模块

### 保持不变的文件

1. [src/qml/Input1/Input1/qmldir](../../src/qml/Input1/Input1/qmldir) - QDS 生成，保持不变
2. [src/qml/Input1/Input1/Constants.qml](../../src/qml/Input1/Input1/Constants.qml) - 单例定义
3. [src/qml/Input1/Input1Content/Screen01.ui.qml](../../src/qml/Input1/Input1Content/Screen01.ui.qml) - UI 文件
4. [src/qml/Input1/Input1Content/App.qml](../../src/qml/Input1/Input1Content/App.qml) - QDS 启动文件

### 参考文档

1. [10-实施完成总结-QDS直接集成.md](10-实施完成总结-QDS直接集成.md)
2. [09-QDS项目直接集成方案-消除符号链接.md](09-QDS项目直接集成方案-消除符号链接.md)

---

## 🔍 故障排查

### 问题 1：仍然报错 "module 'Input1' is not installed"

**原因**：Input1 模块未正确构建

**检查**：
```cmake
# 确认 CMakeLists.txt 末尾有 Input1 模块定义
message(STATUS "Input1 QML 模块已创建为独立模块")
```

**解决**：
```powershell
# 清理构建缓存
Remove-Item build_rk3588 -Recurse -Force -ErrorAction SilentlyContinue
.\build-ubuntu24-apt.ps1 188
```

---

### 问题 2：编译错误 "duplicate symbol"

**原因**：同一个文件被添加到多个模块

**检查**：
```cmake
# 确保 Constants.qml 只在 Input1 模块中
# BeltControlQml 模块不应包含 Input1/Input1/*.qml
```

---

## 🎓 技术总结

### 关键发现

1. **QDS 项目依赖模块系统**：
   - `import Input1` 不是可选的
   - 必须创建独立的 Input1 模块

2. **模块分离的好处**：
   - 清晰的模块边界
   - QDS 设计文件保持不变
   - 便于 QDS 实时预览和编辑

3. **qmldir 的重要性**：
   - 定义模块接口
   - 注册单例和组件
   - 必须与 CMakeLists.txt 保持一致

### 最佳实践

1. **QDS 集成**：
   - 保持 QDS 生成的 qmldir 文件不变
   - 创建独立的 QML 模块
   - 不要修改 `import` 语句

2. **模块组织**：
   - 基础设施（Constants, Models）→ 独立模块
   - UI 文件和资源 → 主模块
   - 模块间通过链接关联

3. **构建系统**：
   - 使用 `qt_add_qml_module` 创建模块
   - 正确设置 `URI` 和 `VERSION`
   - 使用 `target_link_libraries` 链接模块

---

**创建者**：Claude
**文档版本**：1.0
**最后更新**：2026-01-12
