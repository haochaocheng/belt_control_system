# QDS 与主项目同步工作流程指南

**创建时间**：2026-01-12
**适用场景**：在 Qt Design Studio 中修改 Input1 设计后同步到主项目
**状态**：✅ 可用

---

## 📋 核心原理

### ✅ 已实现：QDS 和主项目使用同一份文件！

```
项目结构：
E:\2025\3_gongkongji\belt_control_system\src\qml\Input1\
  ├─ Input1.qmlproject         ← QDS 项目文件
  ├─ Input1/                   ← 模块定义（Constants.qml 等）
  │  ├─ Constants.qml          ← 单例（宽度、高度、颜色等）
  │  ├─ EventListModel.qml
  │  └─ qmldir                 ← 模块注册文件
  └─ Input1Content/            ← UI 和资源
     ├─ App.qml                ← QDS 预览文件（不打包到应用）
     ├─ Screen01.ui.qml        ← **主 UI 文件**（QDS 和主项目共用）
     └─ images/                ← **图片资源**（QDS 和主项目共用）
        ├─ path_1.svg
        ├─ background_top_transparent.png
        └─ ... (53 个图片)
```

**关键点**：
- ✅ QDS 和主项目使用 **同一份 Screen01.ui.qml**
- ✅ QDS 和主项目使用 **同一个 images/ 目录**
- ✅ **无需复制或移动文件**，修改即时生效

---

## 🚀 完整工作流

### 方案 A：只修改布局（最简单）

```bash
# 1. 在 QDS 中修改
Qt Design Studio → 打开 Input1.qmlproject → 修改 Screen01.ui.qml → 保存

# 2. 直接编译
.\build-ubuntu24-apt.ps1 188
```

**无需任何同步脚本！** ✅

---

### 方案 B：添加/删除图片（需要同步）

```bash
# 1. 在 QDS 中修改
Qt Design Studio → 打开 Input1.qmlproject → 添加/删除图片 → 保存

# 2. 一键同步（推荐）
.\scripts\2026-01-12\11-sync-qds-to-project.ps1

# 3. 编译
.\build-ubuntu24-apt.ps1 188
```

**或者分步执行**：
```powershell
# 2.1 同步图片资源列表
.\scripts\2026-01-12\09-sync-input1-resources.ps1

# 2.2 修复图片路径（如果是中文名）
.\scripts\2026-01-12\10-fix-screen01-image-paths.ps1

# 3. 编译
.\build-ubuntu24-apt.ps1 188
```

---

### 方案 C：使用中文文件名（不推荐）

如果您在 QDS 中添加了中文命名的图片，需要重命名为英文：

```powershell
# 1. 手动重命名图片文件（中文 → 英文）
# 例如：传感器故障.svg → sensor_error.svg

# 2. 在 QDS 中重新关联图片（指向新文件名）

# 3. 一键同步
.\scripts\2026-01-12\11-sync-qds-to-project.ps1

# 4. 编译
.\build-ubuntu24-apt.ps1 188
```

**为什么不推荐中文**：
- ❌ Linux Docker 容器可能不支持中文文件名
- ❌ CMake 可能解析错误
- ❌ 增加维护复杂度

---

## 📊 各脚本功能说明

### 1. `09-sync-input1-resources.ps1` - 同步图片资源列表

**功能**：
- 扫描 `Input1Content/images/` 目录中的所有图片
- 自动更新 `src/qml/CMakeLists.txt` 中的 `RESOURCES` 列表

**何时运行**：
- ✅ 添加了新图片
- ✅ 删除了图片
- ✅ 重命名了图片
- ❌ 只修改 Screen01.ui.qml 布局（不需要）

**执行方式**：
```powershell
.\scripts\2026-01-12\09-sync-input1-resources.ps1
```

**输出示例**：
```
==================== 同步 Input1 资源文件 ====================
✓ 找到 53 个图片文件
  CMakeLists.txt RESOURCES 列表已更新
✅ 同步完成！
========================================================================
```

---

### 2. `10-fix-screen01-image-paths.ps1` - 修复图片路径

**功能**：
- 自动将 Screen01.ui.qml 中的中文/空格路径替换为英文路径
- 使用映射表（46 种旧路径 → 新路径）

**何时运行**：
- ✅ QDS 重新导出了 Screen01.ui.qml（重新生成文件）
- ✅ QDS 添加了中文命名的图片
- ❌ 只手动修改 Screen01.ui.qml（不需要）

**执行方式**：
```powershell
.\scripts\2026-01-12\10-fix-screen01-image-paths.ps1
```

**输出示例**：
```
==================== 修复 Screen01.ui.qml 图片路径 ====================
✓ 找到 Screen01.ui.qml
  ✓ 替换 "images/顶部半透明.png" → "images/background_top_transparent.png" (1 处)
  ✓ 替换 "images/Rectangle 34624270.svg" → "images/rectangle_34624270.svg" (12 处)
  ... (共 30 种路径)
✅ 修复完成！共替换 115 处路径
========================================================================
```

---

### 3. `11-sync-qds-to-project.ps1` - 一键同步（推荐）

**功能**：
- 自动执行脚本 1 和脚本 2
- 一键完成所有同步工作

**何时运行**：
- ✅ 在 QDS 中修改后，准备编译前

**执行方式**：
```powershell
.\scripts\2026-01-12\11-sync-qds-to-project.ps1
```

**输出示例**：
```
==================== QDS 同步到主项目 ====================

Step 1: 同步图片资源列表...
（执行 09-sync-input1-resources.ps1）

Step 2: 修复图片路径...
（执行 10-fix-screen01-image-paths.ps1）

✅ QDS 同步完成！可以运行编译脚本了：
  .\build-ubuntu24-apt.ps1 188
========================================================================
```

---

## 🎯 常见场景详解

### 场景 1：修改按钮位置

```bash
# 在 QDS 中
1. 打开 Input1.qmlproject
2. 选中 Screen01.ui.qml
3. 拖动按钮到新位置
4. 保存 (Ctrl+S)

# 在 PowerShell 中
.\build-ubuntu24-apt.ps1 188
```

**无需同步脚本！** ✅

---

### 场景 2：添加新传感器图标

```bash
# 在 QDS 中
1. 打开 Input1.qmlproject
2. 导入新图片 `new_sensor.svg` 到 images/
3. 拖动图片到 Screen01.ui.qml
4. 保存

# 在 PowerShell 中
.\scripts\2026-01-12\11-sync-qds-to-project.ps1  # 同步
.\build-ubuntu24-apt.ps1 188                      # 编译
```

---

### 场景 3：删除不用的传感器

```bash
# 在 QDS 中
1. 打开 Input1.qmlproject
2. 删除 Screen01.ui.qml 中的传感器元素
3. 保存

# 手动删除图片文件
删除 src\qml\Input1\Input1Content\images\old_sensor.svg

# 在 PowerShell 中
.\scripts\2026-01-12\11-sync-qds-to-project.ps1  # 同步
.\build-ubuntu24-apt.ps1 188                      # 编译
```

---

### 场景 4：重新设计整个界面

```bash
# 在 QDS 中
1. 打开 Input1.qmlproject
2. 大幅修改 Screen01.ui.qml
3. 添加多个新图片
4. 保存

# 在 PowerShell 中（保险起见，完整同步）
.\scripts\2026-01-12\11-sync-qds-to-project.ps1  # 同步
.\build-ubuntu24-apt.ps1 188                      # 编译
```

---

## 🔍 故障排查

### 问题 1：编译时提示图片文件找不到

**现象**：
```
CMake Error: Cannot find source file:
  /workspace/src/qml/Input1/Input1Content/images/new_sensor.svg
```

**原因**：CMakeLists.txt 中的 RESOURCES 列表没有更新

**解决**：
```powershell
# 重新同步资源列表
.\scripts\2026-01-12\09-sync-input1-resources.ps1

# 重新编译
.\build-ubuntu24-apt.ps1 188
```

---

### 问题 2：界面上图片不显示

**现象**：应用运行正常，但某些图片不显示

**原因 1**：Screen01.ui.qml 中的路径是旧的（中文或空格）

**解决**：
```powershell
# 修复路径
.\scripts\2026-01-12\10-fix-screen01-image-paths.ps1

# 重新编译
.\build-ubuntu24-apt.ps1 188
```

**原因 2**：图片文件名大小写不匹配（Windows 不区分，Linux 区分）

**解决**：
```bash
# 检查实际文件名
ls src\qml\Input1\Input1Content\images\

# 修改 Screen01.ui.qml 中的路径，确保大小写一致
```

---

### 问题 3：应用卡死（polish() 循环）

**现象**：
```
[WARNING] QML ListView: possible QQuickItem::polish() loop
（无限重复）
```

**原因**：Screen01.ui.qml 中引用了不存在的图片文件

**解决**：
```powershell
# 1. 修复路径
.\scripts\2026-01-12\10-fix-screen01-image-paths.ps1

# 2. 验证无旧路径残留
pwsh.exe -Command "Select-String -Path 'src\qml\Input1\Input1Content\Screen01.ui.qml' -Pattern '顶部半透明|Rectangle 34624|路径-'"

# 3. 重新编译
.\build-ubuntu24-apt.ps1 188
```

---

## 📝 最佳实践

### 1. 图片命名规范

**推荐**：
```
sensor_error.svg           ✅ 英文 + 下划线
path_background.png        ✅ 英文 + 下划线
group2_frame1_top_left.png ✅ 英文 + 下划线 + 语义清晰
```

**避免**：
```
传感器故障.svg              ❌ 中文
background top.png         ❌ 空格
Rectangle 34624270.svg     ❌ 空格 + 无意义名称
new image.svg              ❌ 空格
```

### 2. 修改后立即同步

```bash
# 每次在 QDS 中修改后
1. 保存 (Ctrl+S)
2. 立即运行：.\scripts\2026-01-12\11-sync-qds-to-project.ps1
3. 编译测试
```

**不要积累多次修改再同步**，否则难以定位问题。

### 3. Git 提交

```bash
# QDS 修改后
git add src/qml/Input1/
git commit -m "QDS: 添加新传感器图标"
```

---

## 🎓 技术总结

### 为什么可以做到"直接修改 QDS → 更新主项目"？

1. **文件共享**：
   - QDS 项目在 `src/qml/Input1`
   - 主项目的 CMakeLists.txt 引用 `src/qml/Input1`
   - **同一份文件，无需复制**

2. **CMake 智能检测**：
   - 修改 Screen01.ui.qml → CMake 检测到变化 → 重新编译
   - 添加图片 → 运行同步脚本 → CMake 更新资源列表

3. **QRC 资源系统**：
   - 所有图片打包到 qrc 资源中
   - qrc 路径：`qrc:/qt/qml/BeltControlQml/Input1/Input1Content/images/xxx.png`
   - QML 引用：`source: "images/xxx.png"`（相对路径）

### 为什么需要同步脚本？

1. **09-sync-input1-resources.ps1**：
   - CMake 需要显式列出所有资源文件
   - 添加/删除图片后，CMakeLists.txt 的 RESOURCES 列表需要更新
   - 手动维护容易遗漏

2. **10-fix-screen01-image-paths.ps1**：
   - QDS 可能生成中文或带空格的路径
   - Linux Docker 容器不支持
   - 自动替换为英文路径

3. **11-sync-qds-to-project.ps1**：
   - 一键执行上述两个脚本
   - 简化工作流

---

## 🔄 未来改进

### 自动监控文件变化

```powershell
# 监控 Input1Content/images/ 目录
# 文件变化时自动运行同步脚本
FileSystemWatcher → 检测变化 → 自动同步
```

### 集成到 VSCode

```json
// .vscode/tasks.json
{
  "tasks": [
    {
      "label": "QDS 同步",
      "type": "shell",
      "command": ".\\scripts\\2026-01-12\\11-sync-qds-to-project.ps1",
      "group": "build"
    }
  ]
}
```

按 `Ctrl+Shift+B` → 选择 "QDS 同步"

---

**创建者**：Claude
**文档版本**：1.0
**最后更新**：2026-01-12
