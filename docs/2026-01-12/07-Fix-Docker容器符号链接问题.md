# Fix: Docker 容器符号链接问题 - 编译前预处理

**创建时间**：2026-01-12
**补充修复**：06-Fix-Input1模块打包到qrc资源系统.md
**状态**：✅ 已修复

---

## 📋 问题描述

### 错误现象

在实施了将 Input1 模块文件添加到 CMakeLists.txt 后，编译时出现新错误：

```
CMake Error at /opt/qt-raspi/lib/cmake/Qt6Core/Qt6CoreMacros.cmake:1792 (target_sources):
  Cannot find source file:

    /workspace/src/qml/pages/Input1Content/images/15823432333.svg
```

### 根本原因

1. **符号链接在主机上**：
   ```
   E:\2025\3_gongkongji\belt_control_system\src\qml\pages\Input1
   └─ 符号链接 → E:\2025\3_gongkongji\tp\qds\Input1\Input1

   E:\2025\3_gongkongji\belt_control_system\src\qml\pages\Input1Content
   └─ 符号链接 → E:\2025\3_gongkongji\tp\qds\Input1\Input1Content
   ```

2. **Docker 容器挂载**：
   ```powershell
   # build-rk3588-fixed.ps1 只挂载项目根目录
   docker run -v "${ProjectRoot}:/workspace" ...
   ```

   - ✅ 挂载了：`E:\2025\3_gongkongji\belt_control_system → /workspace`
   - ❌ **未挂载**：`E:\2025\3_gongkongji\tp\qds\Input1`

3. **CMake 在容器内执行**：
   ```
   CMake 读取: /workspace/src/qml/pages/Input1Content/images/15823432333.svg
   ↓
   这是符号链接，指向: E:\2025\3_gongkongji\tp\qds\Input1\Input1Content\images\15823432333.svg
   ↓
   容器内没有挂载这个路径 → 找不到文件！
   ```

### 为什么会发生？

Windows 符号链接在 Docker 容器内仍然是符号链接，但目标路径在容器外部，导致 CMake 无法访问实际文件。

---

## ✅ 解决方案

### 策略

**编译前临时替换符号链接为实际文件，编译后恢复符号链接**

### 工作流程

```
编译前:
  符号链接 (Input1 → QDS 项目)
  ↓ Prepare
  实际文件副本
  ↓ 编译

编译后:
  实际文件副本
  ↓ Restore
  符号链接 (Input1 → QDS 项目) ← 恢复，继续实时同步
```

### 优点

1. **不修改 Docker 配置**：无需额外挂载路径
2. **保持符号链接**：编译后恢复，QDS 同步功能继续工作
3. **编译成功**：容器内可以访问所有需要的文件
4. **自动化**：集成到 build-ubuntu24-apt.ps1，无需手动操作

---

## 🔧 实现细节

### 1. 新建预处理脚本

**文件**：`scripts/2026-01-12/06-prepare-input1-for-compile.ps1`

**功能**：

#### Prepare 模式（编译前）

```powershell
.\06-prepare-input1-for-compile.ps1 -Action Prepare
```

**操作**：
1. 检查 `Input1` 和 `Input1Content` 是否为符号链接
2. 如果是符号链接：
   - 记录符号链接目标到备份文件 (`temp_input1_backup/Input1.target`)
   - 删除符号链接
   - 复制符号链接指向的实际文件到相同位置
3. 如果不是符号链接：跳过

**结果**：
```
src/qml/pages/Input1/         ← 实际文件目录（原来是符号链接）
src/qml/pages/Input1Content/  ← 实际文件目录（原来是符号链接）
temp_input1_backup/
  ├─ Input1.target           ← 保存原始符号链接目标
  └─ Input1Content.target    ← 保存原始符号链接目标
```

#### Restore 模式（编译后）

```powershell
.\06-prepare-input1-for-compile.ps1 -Action Restore
```

**操作**：
1. 读取备份的符号链接目标
2. 删除实际文件目录
3. 重新创建符号链接
4. 清理备份目录

**结果**：
```
src/qml/pages/Input1/         ← 符号链接（恢复）
src/qml/pages/Input1Content/  ← 符号链接（恢复）
temp_input1_backup/           ← 已删除
```

---

### 2. 修改 build-ubuntu24-apt.ps1

#### 修改位置：Step 1（交叉编译检查）

```powershell
if ($needCompile) {
    # 编译前准备 Input1 文件
    Write-Host "  Preparing Input1 files for compilation..." -ForegroundColor Yellow
    & "$ProjectRoot\scripts\2026-01-12\06-prepare-input1-for-compile.ps1" -Action Prepare
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Input1 preparation failed" -ForegroundColor Red
        exit 1
    }

    # 执行交叉编译
    & "$ProjectRoot\build-rk3588-fixed.ps1"
    $compileResult = $LASTEXITCODE

    # 编译后恢复 Input1 符号链接（无论编译成功与否）
    Write-Host "  Restoring Input1 symbolic links..." -ForegroundColor Yellow
    & "$ProjectRoot\scripts\2026-01-12\06-prepare-input1-for-compile.ps1" -Action Restore

    if ($compileResult -ne 0) {
        Write-Host "ERROR: Cross-compilation failed" -ForegroundColor Red
        exit 1
    }
}
```

**关键点**：
- **编译前**：Prepare（替换符号链接）
- **编译后**：Restore（恢复符号链接）
- **保存退出码**：使用 `$compileResult` 保存编译结果，确保 Restore 始终执行
- **错误处理**：即使编译失败，也会恢复符号链接

---

## 📊 执行流程

### 完整编译流程（包含 Input1 预处理）

```
./build-ubuntu24-apt.ps1 188
  ↓
Step 1: 交叉编译检查
  ↓
需要编译？ → 是
  ↓
📂 Preparing Input1 files...
  ├─ 检测到 Input1 符号链接
  ├─ 记录目标: E:\2025\3_gongkongji\tp\qds\Input1\Input1
  ├─ 删除符号链接
  └─ 复制实际文件 → src/qml/pages/Input1/

  ├─ 检测到 Input1Content 符号链接
  ├─ 记录目标: E:\2025\3_gongkongji\tp\qds\Input1\Input1Content
  ├─ 删除符号链接
  └─ 复制实际文件 → src/qml/pages/Input1Content/
  ↓
✅ 准备完成
  ↓
🏗️ 执行交叉编译（Docker 容器）
  ├─ CMake 配置
  ├─ 读取 Input1/Constants.qml ✅ 找到（实际文件）
  ├─ 读取 Input1Content/images/15823432333.svg ✅ 找到（实际文件）
  ├─ 编译 QML 模块
  └─ 链接二进制文件
  ↓
✅ 编译完成（或失败）
  ↓
📂 Restoring Input1 symbolic links...
  ├─ 读取目标: E:\2025\3_gongkongji\tp\qds\Input1\Input1
  ├─ 删除实际文件目录
  └─ 重新创建符号链接 → src/qml/pages/Input1/

  ├─ 读取目标: E:\2025\3_gongkongji\tp\qds\Input1\Input1Content
  ├─ 删除实际文件目录
  └─ 重新创建符号链接 → src/qml/pages/Input1Content/
  ↓
✅ 符号链接已恢复
  ↓
继续 Step 2-6（Docker 镜像构建和部署）
```

---

## 🎯 预期效果

### 编译时（Prepare 阶段）

```
========================================
  准备 Input1 文件用于编译
========================================

📂 处理 Input1 符号链接...
   复制文件: E:\2025\3_gongkongji\tp\qds\Input1\Input1 -> E:\2025\3_gongkongji\belt_control_system\src\qml\pages\Input1
   ✅ Input1 符号链接已替换为实际文件
📂 处理 Input1Content 符号链接...
   复制文件: E:\2025\3_gongkongji\tp\qds\Input1\Input1Content -> E:\2025\3_gongkongji\belt_control_system\src\qml\pages\Input1Content
   ✅ Input1Content 符号链接已替换为实际文件

✅ 准备完成，可以开始编译
```

### CMake 配置阶段（Docker 容器内）

```
-- Input1 模块已集成到 BeltControlQml 模块（58 个文件）
-- Checking Input1/Constants.qml... Found
-- Checking Input1Content/Screen01.ui.qml... Found
-- Checking Input1Content/images/15823432333.svg... Found
-- Checking Input1Content/images/... (省略 52 个文件)
-- Configuring done (75.3s)
-- Generating done (18.8s)
-- Build files generated successfully
```

### 编译后（Restore 阶段）

```
========================================
  恢复 Input1 符号链接
========================================

📂 恢复 Input1 符号链接...
   目标: E:\2025\3_gongkongji\tp\qds\Input1\Input1
   ✅ Input1 符号链接已恢复
📂 恢复 Input1Content 符号链接...
   目标: E:\2025\3_gongkongji\tp\qds\Input1\Input1Content
   ✅ Input1Content 符号链接已恢复

🧹 清理备份...
✅ 恢复完成
```

---

## 🧪 测试步骤

### 1. 验证符号链接状态

**编译前**：
```powershell
Get-Item E:\2025\3_gongkongji\belt_control_system\src\qml\pages\Input1 | Select-Object LinkType, Target

# 输出:
# LinkType      Target
# --------      ------
# SymbolicLink  E:\2025\3_gongkongji\tp\qds\Input1\Input1
```

**Prepare 后**：
```powershell
Get-Item E:\2025\3_gongkongji\belt_control_system\src\qml\pages\Input1 | Select-Object LinkType

# 输出:
# LinkType
# --------
#          (空，表示普通目录)
```

**Restore 后**：
```powershell
Get-Item E:\2025\3_gongkongji\belt_control_system\src\qml\pages\Input1 | Select-Object LinkType, Target

# 输出:
# LinkType      Target
# --------      ------
# SymbolicLink  E:\2025\3_gongkongji\tp\qds\Input1\Input1
```

### 2. 完整编译测试

```powershell
# 清理旧构建
Remove-Item build_rk3588 -Recurse -Force -ErrorAction SilentlyContinue

# 完整编译和部署
.\build-ubuntu24-apt.ps1 188
```

**预期输出**：
```
Step 1: Cross-compilation check...
  Binary not found, compilation required

  Running cross-compilation with GLIBC fix (32 threads)...

  Preparing Input1 files for compilation...
  ✅ Input1 符号链接已替换为实际文件
  ✅ Input1Content 符号链接已替换为实际文件

  ✅ 准备完成，可以开始编译

[Docker 编译过程...]
-- Input1 模块已集成到 BeltControlQml 模块（58 个文件）
-- Configuring done
-- Generating done
-- Build complete

  Restoring Input1 symbolic links...
  ✅ Input1 符号链接已恢复
  ✅ Input1Content 符号链接已恢复

  ✅ 恢复完成

  [OK] Cross-compilation complete

[继续 Docker 镜像构建和部署...]
```

### 3. QDS 同步测试

**编译后，验证 QDS 同步仍然有效**：

1. 在 Qt Design Studio 中打开 `E:\2025\3_gongkongji\tp\qds\Input1` 项目
2. 修改 `Screen01.ui.qml`（例如：改变一个文本）
3. 保存（Ctrl+S）
4. 检查项目中的文件是否同步更新：
   ```powershell
   Get-Content E:\2025\3_gongkongji\belt_control_system\src\qml\pages\Input1Content\Screen01.ui.qml
   # 应该看到刚才的修改
   ```

**结果**：✅ 符号链接恢复后，QDS 修改实时同步到项目

---

## 🔍 故障排查

### 问题1：Prepare 后符号链接仍然存在

**检查**：
```powershell
Get-Item src\qml\pages\Input1 | Select-Object LinkType
# 如果显示 SymbolicLink，说明 Prepare 失败
```

**可能原因**：
- PowerShell 权限不足（需要管理员权限删除符号链接）
- 符号链接目标不存在

**解决**：
```powershell
# 以管理员身份运行 PowerShell
# 手动执行 Prepare
.\scripts\2026-01-12\06-prepare-input1-for-compile.ps1 -Action Prepare
```

---

### 问题2：编译失败后符号链接未恢复

**现象**：编译失败，但 Input1 目录变成普通目录

**原因**：脚本在 Restore 前被中断（例如 Ctrl+C）

**解决**：
```powershell
# 手动恢复符号链接
.\scripts\2026-01-12\06-prepare-input1-for-compile.ps1 -Action Restore
```

---

### 问题3：Restore 后 QDS 同步不工作

**检查**：
```powershell
Get-Item src\qml\pages\Input1 | Select-Object LinkType, Target
```

**可能原因**：
- 符号链接目标路径错误
- 备份文件损坏

**解决**：
```powershell
# 删除错误的符号链接
Remove-Item src\qml\pages\Input1 -Force
Remove-Item src\qml\pages\Input1Content -Force

# 重新创建正确的符号链接
.\scripts\2026-01-12\01-create-qds-symlink.ps1
```

---

## 📝 相关文件

### 新建的文件

1. [scripts/2026-01-12/06-prepare-input1-for-compile.ps1](../../scripts/2026-01-12/06-prepare-input1-for-compile.ps1) - 预处理脚本

### 修改的文件

1. [build-ubuntu24-apt.ps1](../../build-ubuntu24-apt.ps1) - 集成预处理调用

### 参考文档

1. [06-Fix-Input1模块打包到qrc资源系统.md](06-Fix-Input1模块打包到qrc资源系统.md) - 主修复文档

---

## 🎓 技术总结

### 符号链接 vs Docker 容器

| 方面 | 符号链接 | Docker 容器内 |
|------|---------|--------------|
| **可见性** | 主机可见 | 需挂载目标路径 |
| **跟随** | CMake/编译器自动跟随 | **不跟随**（目标路径未挂载） |
| **解决方案** | 临时替换为实际文件 | 或挂载所有相关路径 |

### 最佳实践

1. **跨容器构建**：
   - 符号链接指向的路径必须在容器内可访问
   - 或者编译前将符号链接替换为实际文件

2. **构建脚本设计**：
   - 使用 `$compileResult` 保存编译结果
   - 确保清理操作（Restore）始终执行
   - 即使编译失败，也要恢复符号链接

3. **自动化原则**：
   - 预处理和恢复集成到构建脚本
   - 用户无需手动操作
   - 错误处理完善

---

**创建者**：Claude
**文档版本**：1.0
**最后更新**：2026-01-12
