# QDS 项目直接集成方案 - 消除符号链接

**创建时间**：2026-01-12
**状态**：✅ 准备就绪
**优先级**：高

---

## 📋 问题背景

### 之前的问题

1. **符号链接在 Docker 容器中无法访问**
   - QDS 项目：`E:\2025\3_gongkongji\tp\qds\Input1`
   - 符号链接：`src/qml/pages/Input1` → 外部路径
   - Docker 只挂载项目根目录，无法访问符号链接目标

2. **中文文件名在 Linux 容器中无法识别**
   - CMake 报错：`Cannot find source file: .../传感器故障.svg`
   - Linux 容器编码问题

3. **文件名包含空格导致 CMake 截断**
   - `"591f887661e569e40a0f280feaf942c33ddd121328c7b-iqvDOE_fw1200 1.svg"`
   - CMake 在空格处截断文件名

---

## ✅ 新方案（推荐）

### 核心思路

**将 QDS 项目直接放在项目目录内，重命名所有中文文件为英文，完全消除符号链接**

### 优点

1. **无需符号链接**：QDS 项目在项目目录内，Docker 容器可以直接访问
2. **QDS 可以直接打开**：Qt Design Studio 可以打开 `src/qml/Input1` 项目
3. **文件名兼容**：英文文件名在所有平台都能正常工作
4. **编译简单**：无需预处理脚本（Prepare/Restore）

### 新的目录结构

```
E:\2025\3_gongkongji\belt_control_system\
├─ src\
│  └─ qml\
│     ├─ Input1\                    ← QDS 项目（直接在这里）
│     │  ├─ Input1\                 ← QDS 模块定义
│     │  │  ├─ Constants.qml
│     │  │  ├─ EventListModel.qml
│     │  │  └─ EventListSimulator.qml
│     │  └─ Input1Content\          ← QDS 设计文件
│     │     ├─ App.qml
│     │     ├─ Screen01.ui.qml
│     │     └─ images\              ← 图片资源（**全部英文文件名**）
│     │        ├─ path_1.svg
│     │        ├─ current_value.svg
│     │        └─ ... (53 个文件)
│     ├─ pages\                     ← 其他页面
│     │  ├─ Input1Page.qml          ← 入口页面
│     │  └─ ...
│     └─ CMakeLists.txt
```

---

## 🔧 实施步骤

### 第 1 步：确认 QDS 项目位置

**检查是否已经移动到项目目录**：

```powershell
Test-Path "E:\2025\3_gongkongji\belt_control_system\src\qml\Input1"
```

**如果返回 `True`**：已移动，继续下一步
**如果返回 `False`**：需要先移动 QDS 项目

**移动方法**（如需要）：
```powershell
# 复制 QDS 项目到项目目录
Copy-Item -Path "E:\2025\3_gongkongji\tp\qds\Input1" `
          -Destination "E:\2025\3_gongkongji\belt_control_system\src\qml\" `
          -Recurse -Force
```

---

### 第 2 步：执行文件名重命名

**运行重命名脚本**：

```powershell
.\scripts\2026-01-12\08-rename-chinese-to-english.ps1
```

**预期输出**：
```
========================================
  Input1 图片文件名中译英
========================================

📋 文件重命名计划（中文 → 英文）：

  ✓ 路径-1.svg
    → path_1.svg
  ✓ 路径-2.svg
    → path_2.svg
  ✓ 当前值.svg
    → current_value.svg
  ...（总共约 46 个文件）

========================================
重命名完成：
  ✅ 成功重命名: 46 个文件
========================================

📝 生成 CMakeLists.txt 资源列表...

========================================
复制以下内容到 src/qml/CMakeLists.txt 的 RESOURCES 部分：
========================================

    RESOURCES
        images/header.png
        sounds/ringtone.wav
        # 2026-01-12: Input1 模块资源文件（53 个图片）
        pages/Input1/Input1Content/images/15823432333.svg
        pages/Input1/Input1Content/images/dd.png
        pages/Input1/Input1Content/images/GSC10.svg
        pages/Input1/Input1Content/images/path_1.svg
        ... (省略其他文件)
```

---

### 第 3 步：删除旧的符号链接（如存在）

**检查是否存在符号链接**：

```powershell
Get-Item "E:\2025\3_gongkongji\belt_control_system\src\qml\pages\Input1" -ErrorAction SilentlyContinue | Select-Object LinkType, Target
```

**如果 LinkType 为 `SymbolicLink`**：删除符号链接

```powershell
# 删除旧的符号链接
Remove-Item "E:\2025\3_gongkongji\belt_control_system\src\qml\pages\Input1" -Force
Remove-Item "E:\2025\3_gongkongji\belt_control_system\src\qml\pages\Input1Content" -Force
```

---

### 第 4 步：更新 CMakeLists.txt

**修改路径前缀**：

之前使用 `pages/Input1Content/...`，现在改为 `Input1/Input1Content/...`

**编辑文件**：`src/qml/CMakeLists.txt`

**查找和替换**：

```cmake
# 旧的路径
pages/Input1/Constants.qml
pages/Input1/EventListModel.qml
pages/Input1/EventListSimulator.qml
pages/Input1Content/App.qml
pages/Input1Content/Screen01.ui.qml
pages/Input1Content/images/...

# 新的路径
Input1/Input1/Constants.qml
Input1/Input1/EventListModel.qml
Input1/Input1/EventListSimulator.qml
Input1/Input1Content/App.qml
Input1/Input1Content/Screen01.ui.qml
Input1/Input1Content/images/...
```

**完整示例**：

```cmake
qt_add_qml_module(BeltControlQml
    URI BeltControlQml
    VERSION 1.0
    QML_FILES
        main.qml
        App.qml
        # ... 其他页面
        pages/Input1Page.qml
        # 2026-01-12: Input1 模块 QML 文件（QDS 直接集成）
        Input1/Input1/Constants.qml
        Input1/Input1/EventListModel.qml
        Input1/Input1/EventListSimulator.qml
        Input1/Input1Content/App.qml
        Input1/Input1Content/Screen01.ui.qml
    RESOURCES
        images/header.png
        sounds/ringtone.wav
        # 2026-01-12: Input1 模块资源文件（53 个图片，全英文文件名）
        Input1/Input1Content/images/15823432333.svg
        Input1/Input1Content/images/dd.png
        Input1/Input1Content/images/GSC10.svg
        Input1/Input1Content/images/path_1.svg
        Input1/Input1Content/images/path_2.svg
        Input1/Input1Content/images/path.svg
        Input1/Input1Content/images/path_background.png
        Input1/Input1Content/images/protection_name.svg
        Input1/Input1Content/images/input_type.svg
        Input1/Input1Content/images/current_value.svg
        Input1/Input1Content/images/switch_value.svg
        Input1/Input1Content/images/speed.svg
        Input1/Input1Content/images/fault.svg
        Input1/Input1Content/images/running_active.svg
        Input1/Input1Content/images/background_bottom_transparent.png
        Input1/Input1Content/images/background_full_transparent.png
        Input1/Input1Content/images/background_top_transparent.png
        Input1/Input1Content/images/middle_top_status_bg.png
        Input1/Input1Content/images/middle_top_status_bg_sides.png
        Input1/Input1Content/images/group2_frame1_top_left.png
        Input1/Input1Content/images/group2_frame1_middle_left.png
        Input1/Input1Content/images/group2_frame1_bottom_left.png
        Input1/Input1Content/images/group2_frame1_top_center.png
        Input1/Input1Content/images/group2_frame1_bottom_center.png
        Input1/Input1Content/images/group2_frame1_top_right.png
        Input1/Input1Content/images/group2_frame1_middle_right.png
        Input1/Input1Content/images/group2_frame1_bottom_right.png
        Input1/Input1Content/images/group2_frame2.svg
        Input1/Input1Content/images/group2_frame2_base.svg
        Input1/Input1Content/images/group2_frame2_top_left.png
        Input1/Input1Content/images/group2_frame2_middle_left.png
        Input1/Input1Content/images/group2_frame2_bottom_left.png
        Input1/Input1Content/images/group2_frame2_top_center.png
        Input1/Input1Content/images/group2_frame2_bottom_center.png
        Input1/Input1Content/images/group2_frame2_top_right.png
        Input1/Input1Content/images/group2_frame2_middle_right.png
        Input1/Input1Content/images/group2_frame2_bottom_right.png
        Input1/Input1Content/images/group2_frame3.png
        Input1/Input1Content/images/group2_frame3_top_left.png
        Input1/Input1Content/images/group2_frame3_middle_left.png
        Input1/Input1Content/images/group2_frame3_bottom_left.png
        Input1/Input1Content/images/group2_frame3_top_center.png
        Input1/Input1Content/images/group2_frame3_bottom_center.png
        Input1/Input1Content/images/group2_frame3_top_right.png
        Input1/Input1Content/images/group2_frame3_middle_right.png
        Input1/Input1Content/images/group2_frame3_bottom_right.png
        Input1/Input1Content/images/figma_export_1.svg
        Input1/Input1Content/images/rectangle_34624263.svg
        Input1/Input1Content/images/rectangle_34624264.svg
        Input1/Input1Content/images/rectangle_34624265.svg
        Input1/Input1Content/images/rectangle_34624270.svg
        Input1/Input1Content/images/rectangle_34624271.svg
)
```

---

### 第 5 步：更新 Input1Page.qml

**修改 qrc 路径**：

**编辑文件**：`src/qml/pages/Input1Page.qml`

```qml
// 旧路径
source: "qrc:/qt/qml/BeltControlQml/pages/Input1Content/Screen01.ui.qml"

// 新路径
source: "qrc:/qt/qml/BeltControlQml/Input1/Input1Content/Screen01.ui.qml"
```

**完整文件示例**：

```qml
import QtQuick
import QtQuick.Controls
// 2026-01-12: Input1 模块文件已打包到 BeltControlQml 模块中

Item {
    // QDS 设计的主界面
    // 2026-01-12: 直接使用完整路径引用 Screen01.ui.qml（新路径）
    Loader {
        id: screenLoader
        anchors.fill: parent
        source: "qrc:/qt/qml/BeltControlQml/Input1/Input1Content/Screen01.ui.qml"

        onLoaded: {
            console.log("✅ Input1 Screen01 加载成功")
        }

        onStatusChanged: {
            if (screenLoader.status === Loader.Error) {
                console.error("❌ Input1 Screen01 加载失败")
                errorOverlay.visible = true
            }
        }
    }

    // 错误提示覆盖层
    Rectangle {
        id: errorOverlay
        anchors.fill: parent
        color: "#CC000000"
        visible: false

        Text {
            anchors.centerIn: parent
            text: "⚠️ Input1 模块加载失败\n请检查资源文件是否正确打包"
            color: "white"
            font.pixelSize: 24
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
```

---

### 第 6 步：删除不必要的预处理脚本调用

**编辑文件**：`build-ubuntu24-apt.ps1`

**删除以下代码**：

```powershell
# 2026-01-12: ❌ 删除（不再需要符号链接预处理）
# 编译前准备 Input1 文件
# Write-Host "  Preparing Input1 files for compilation..." -ForegroundColor Yellow
# & "$ProjectRoot\scripts\2026-01-12\06-prepare-input1-for-compile.ps1" -Action Prepare
# if ($LASTEXITCODE -ne 0) {
#     Write-Host "ERROR: Input1 preparation failed" -ForegroundColor Red
#     exit 1
# }

# & "$ProjectRoot\build-rk3588-fixed.ps1"
# $compileResult = $LASTEXITCODE

# 编译后恢复 Input1 符号链接（无论编译成功与否）
# Write-Host "  Restoring Input1 symbolic links..." -ForegroundColor Yellow
# & "$ProjectRoot\scripts\2026-01-12\06-prepare-input1-for-compile.ps1" -Action Restore

# if ($compileResult -ne 0) {
#     Write-Host "ERROR: Cross-compilation failed" -ForegroundColor Red
#     exit 1
# }
```

**替换为简单的编译调用**：

```powershell
# 2026-01-12: Input1 文件直接在项目目录，无需预处理
& "$ProjectRoot\build-rk3588-fixed.ps1"
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Cross-compilation failed" -ForegroundColor Red
    exit 1
}
```

---

### 第 7 步：测试编译

**完整编译和部署**：

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

[Docker 编译过程...]
-- Input1 模块已集成到 BeltControlQml 模块（58 个文件）
-- Configuring done (75.3s)
-- Generating done (18.8s)
-- Build files generated successfully
-- Build complete

  [OK] Cross-compilation complete

Step 2: Docker image build...
Step 3: Stopping existing container...
Step 4: Deploying to device...
Step 5: Starting container...

✅ Deployment complete!
```

---

### 第 8 步：验证运行

**SSH 连接到设备**：

```bash
ssh linaro@192.168.10.188
docker logs belt-control-ubuntu24 --tail 50 | grep -i "input1"
```

**预期日志**：

```
Input1Page 已加载
✅ Input1 Screen01 加载成功
```

---

## 🎯 核心变化总结

### 1. 目录结构

| 之前 | 现在 |
|------|------|
| `tp/qds/Input1` → 符号链接 → `src/qml/pages/Input1` | `src/qml/Input1`（直接在项目内） |

### 2. 文件名

| 之前 | 现在 |
|------|------|
| 中文文件名：`传感器故障.svg` | 英文文件名：`sensor_error.svg` |
| 带空格：`...fw1200 1.svg` | 无空格：`figma_export_1.svg` |

### 3. CMakeLists.txt 路径

| 之前 | 现在 |
|------|------|
| `pages/Input1/Constants.qml` | `Input1/Input1/Constants.qml` |
| `pages/Input1Content/Screen01.ui.qml` | `Input1/Input1Content/Screen01.ui.qml` |

### 4. Input1Page.qml 路径

| 之前 | 现在 |
|------|------|
| `qrc:/qt/qml/BeltControlQml/pages/Input1Content/Screen01.ui.qml` | `qrc:/qt/qml/BeltControlQml/Input1/Input1Content/Screen01.ui.qml` |

### 5. 构建流程

| 之前 | 现在 |
|------|------|
| Prepare → 编译 → Restore | 直接编译（无预处理） |

---

## 📝 重要说明

### QDS 同步功能

**✅ 仍然可用！**

Qt Design Studio 可以直接打开 `src/qml/Input1` 项目：

```
Qt Design Studio → 打开项目 → E:\2025\3_gongkongji\belt_control_system\src\qml\Input1\Input1.qmlproject
```

**修改和保存**：
- 在 QDS 中修改 `Screen01.ui.qml` 或图片资源
- 保存后自动更新到项目文件
- 重新编译即可生效

**注意**：
- 图片资源重命名后，需要在 QDS 中更新引用
- 如果 QDS 设计中使用了旧的中文文件名，需要手动替换为新的英文文件名

---

## 🔍 故障排查

### 问题 1：编译时找不到文件

**现象**：
```
CMake Error: Cannot find source file:
    src/qml/Input1/Input1/Constants.qml
```

**原因**：QDS 项目未移动到 `src/qml/Input1`

**解决**：
```powershell
# 确认项目位置
Test-Path "E:\2025\3_gongkongji\belt_control_system\src\qml\Input1"
# 如果返回 False，执行移动操作
```

---

### 问题 2：运行时加载失败

**现象**：
```
❌ Input1 Screen01 加载失败
```

**原因**：qrc 路径错误

**解决**：
```powershell
# 检查 Input1Page.qml 中的路径
Select-String -Path "src\qml\pages\Input1Page.qml" -Pattern "source:"
# 确保路径为：qrc:/qt/qml/BeltControlQml/Input1/Input1Content/Screen01.ui.qml
```

---

### 问题 3：QDS 中图片不显示

**现象**：QDS 设计器中图片加载失败

**原因**：QDS 文件中仍使用旧的中文文件名

**解决**：
1. 在 QDS 中打开 `Screen01.ui.qml`
2. 查找所有 `source: "images/旧文件名.svg"`
3. 替换为新的英文文件名：`source: "images/新文件名.svg"`
4. 保存

---

## 🎓 技术优势

### 1. 无符号链接依赖
- ✅ Docker 容器可以直接访问所有文件
- ✅ 无需挂载外部路径
- ✅ 跨平台兼容性好

### 2. 文件名规范
- ✅ 英文文件名在所有平台都能正常工作
- ✅ 无空格，CMake 解析无问题
- ✅ 语义化命名，易于维护

### 3. 构建简化
- ✅ 无需预处理脚本
- ✅ 无需 Prepare/Restore 操作
- ✅ 编译流程更直接

### 4. QDS 集成
- ✅ QDS 可以直接打开项目
- ✅ 修改后立即生效
- ✅ 无需额外同步操作

---

## ✅ 完成检查清单

执行每个步骤后，勾选对应的复选框：

- [ ] 第 1 步：确认 QDS 项目位置（`src/qml/Input1` 存在）
- [ ] 第 2 步：执行文件名重命名（46 个文件重命名成功）
- [ ] 第 3 步：删除旧的符号链接（如存在）
- [ ] 第 4 步：更新 CMakeLists.txt（路径前缀改为 `Input1/...`）
- [ ] 第 5 步：更新 Input1Page.qml（qrc 路径改为新路径）
- [ ] 第 6 步：删除预处理脚本调用（build-ubuntu24-apt.ps1 清理）
- [ ] 第 7 步：测试编译（编译成功，无错误）
- [ ] 第 8 步：验证运行（设备上日志显示 "✅ Input1 Screen01 加载成功"）

---

**创建者**：Claude
**文档版本**：1.0
**最后更新**：2026-01-12
