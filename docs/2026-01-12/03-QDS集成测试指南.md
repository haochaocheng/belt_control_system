# QDS Input1 项目集成测试指南

**创建时间**：2026-01-12
**目的**：验证 Qt Design Studio 项目是否正确集成到 Belt Control System

---

## 🧪 测试流程（4个步骤）

### 测试1：验证集成状态（必做）⭐⭐⭐⭐⭐

**目的**：检查文件、符号链接、模块配置是否正确

**执行命令**：
```powershell
.\scripts\2026-01-12\03-test-qds-integration.ps1
```

**预期结果**：
```
✅ 所有测试通过！(11/11)

📋 测试 1/5: 检查文件和目录
  ✅ QDS 项目目录
  ✅ QDS Screen01.ui.qml
  ✅ QDS 图片资源目录
  ✅ 项目 Input1Content 目录 [符号链接]
  ✅ 项目 Input1 模块目录 [符号链接]
  ✅ Input1Page.qml 包装器

📋 测试 2/5: 检查 QML 模块配置
  ✅ qmldir 文件

📋 测试 3/5: 检查图片资源
  ✅ 图片资源目录（47 个文件）

📋 测试 4/5: 检查 App.qml 集成
  ✅ 已集成

📋 测试 5/5: QML 语法检查
  ✅ 语法正常
```

**如果测试失败**：
- 按照脚本提示执行修复操作
- 参考：[02-QDS项目集成和自动同步方案.md](02-QDS项目集成和自动同步方案.md)

---

### 测试2：本地预览（可选）⭐⭐⭐

**目的**：使用 Qt QML 引擎快速预览界面

**前提条件**：
- 已安装 Qt 6
- `qml` 命令在系统 PATH 中

**执行命令**：
```powershell
.\scripts\2026-01-12\04-preview-qds-page.ps1
```

**预期结果**：
- 弹出 1920×1080 预览窗口
- 显示 QDS 设计的 Input1 界面
- 底部工具栏显示页面信息

**快捷键**：
- `F5`：重新加载页面
- `ESC`：退出预览

**如果无法运行**：
- 跳过此步骤，直接进行测试3
- 或使用 Qt Creator 打开生成的预览文件

---

### 测试3：在 App.qml 中添加第五个页面（必做）⭐⭐⭐⭐⭐

**文件路径**：`src/qml/App.qml`

**修改步骤**：

1. 打开 `src/qml/App.qml`
2. 找到 `SwipeView` 组件
3. 在现有4个页面后添加第五个页面

**修改前**：
```qml
SwipeView {
    id: swipeView
    anchors.fill: parent
    currentIndex: 0

    // 第1页：控制面板
    ControlPanel {
        motorRunning: app.motorRunning
        currentSpeed: app.currentSpeed
    }

    // 第2页：参数设置
    ParameterSettings {}

    // 第3页：报警页面
    AlarmPage {}

    // 第4页：操作日志
    DeviceOperationLog {}

    // ← 在这里添加第五个页面
}
```

**修改后**：
```qml
SwipeView {
    id: swipeView
    anchors.fill: parent
    currentIndex: 0

    // 第1页：控制面板
    ControlPanel {
        motorRunning: app.motorRunning
        currentSpeed: app.currentSpeed
    }

    // 第2页：参数设置
    ParameterSettings {}

    // 第3页：报警页面
    AlarmPage {}

    // 第4页：操作日志
    DeviceOperationLog {}

    // 第5页：输入监控（QDS 设计）✨ 新增
    Input1Page {
        id: input1Page
        isActive: swipeView.currentIndex === 4  // 页面激活状态
    }
}
```

4. 保存文件（`Ctrl + S`）

---

### 测试4：完整编译和设备部署（必做）⭐⭐⭐⭐⭐

**目的**：在实际设备上验证第五个页面

**执行命令**：
```powershell
.\build-ubuntu24-apt.ps1 188
```

**部署流程**：
1. 交叉编译应用程序
2. 构建 Docker 镜像
3. 部署到设备 192.168.10.188
4. 自动启动应用

**预期结果**：
- 编译成功，无错误
- 镜像构建成功
- 设备上应用正常启动
- 可以使用左右箭头键或滑动切换到第五个页面

**在设备上测试**：
```bash
# SSH 连接到设备
ssh linaro@192.168.10.188

# 查看日志
docker logs belt-control-ubuntu24 --tail 50

# 检查应用是否运行
docker ps | grep belt-control
```

---

## 🎯 完整测试步骤（推荐顺序）

### 步骤1：首次集成（二选一）

**方案A：使用符号链接（推荐）**
```powershell
# 以管理员身份运行
.\scripts\2026-01-12\01-create-qds-symlink.ps1
```

**方案B：使用文件监控**
```powershell
# 单次同步
.\scripts\2026-01-12\02-sync-qds-input1.ps1 -Once

# 或启动持续监控（在单独窗口运行）
.\scripts\2026-01-12\02-sync-qds-input1.ps1 -Watch
```

---

### 步骤2：验证集成

```powershell
# 运行集成测试
.\scripts\2026-01-12\03-test-qds-integration.ps1
```

**期望输出**：`✅ 所有测试通过！`

---

### 步骤3：修改 App.qml

按照"测试3"的说明，在 `src/qml/App.qml` 中添加第五个页面。

---

### 步骤4：本地预览（可选）

```powershell
# 如果安装了 Qt 6
.\scripts\2026-01-12\04-preview-qds-page.ps1
```

---

### 步骤5：完整部署

```powershell
# 编译和部署到设备
.\build-ubuntu24-apt.ps1 188
```

---

### 步骤6：设备上验证

1. **启动应用**（已自动启动）

2. **切换到第五个页面**：
   - 使用左右箭头键：按 4 次右箭头键
   - 或使用鼠标滑动

3. **检查界面**：
   - 是否显示 QDS 设计的输入监控界面？
   - 图片资源是否正确加载？
   - 布局是否正确？

---

## 🐛 故障排查

### 问题1：测试脚本报错 "不存在"

**现象**：
```
❌ 项目 Input1Content 目录 [不存在]
❌ 项目 Input1 模块目录 [不存在]
```

**原因**：
- 未创建符号链接
- 或未执行文件同步

**解决方法**：
```powershell
# 方法1：创建符号链接（推荐）
.\scripts\2026-01-12\01-create-qds-symlink.ps1

# 方法2：执行单次同步
.\scripts\2026-01-12\02-sync-qds-input1.ps1 -Once
```

---

### 问题2：App.qml 报错 "module Input1 is not installed"

**现象**：
编译时报错，提示找不到 Input1 模块

**原因**：
- QML 导入路径未配置
- qmldir 文件不存在

**解决方法**：

1. 检查 `src/qml/pages/Input1/qmldir` 是否存在
   ```powershell
   Get-Content src\qml\pages\Input1\qmldir
   ```

2. 确认 `CMakeLists.txt` 中配置了导入路径：
   ```cmake
   set(QML_IMPORT_PATH
       "${CMAKE_CURRENT_SOURCE_DIR}/src/qml"
       "${CMAKE_CURRENT_SOURCE_DIR}/src/qml/pages/Input1"
       CACHE STRING "" FORCE
   )
   ```

---

### 问题3：设备上界面显示不正常

**现象**：
- 第五个页面空白
- 图片不显示
- 布局错乱

**排查步骤**：

1. **检查日志**：
   ```bash
   ssh linaro@192.168.10.188
   docker logs belt-control-ubuntu24 --tail 100 | grep -i "input1\|error\|warning"
   ```

2. **检查文件是否打包**：
   ```bash
   # 在容器内检查
   docker exec -it belt-control-ubuntu24 ls -la /app/src/qml/pages/
   ```

3. **检查资源文件**：
   ```bash
   docker exec -it belt-control-ubuntu24 ls -la /app/src/qml/pages/Input1Content/images/
   ```

---

### 问题4：修改 QDS 后不同步

**现象**：
在 Qt Design Studio 中保存修改后，应用中没有变化

**原因**：
- 符号链接失效
- 文件监控脚本未运行

**解决方法**：

**方案A（符号链接）**：
```powershell
# 重新创建符号链接
.\scripts\2026-01-12\01-create-qds-symlink.ps1
```

**方案B（文件监控）**：
```powershell
# 确认监控脚本正在运行
Get-Process | Where-Object { $_.CommandLine -like "*02-sync-qds-input1*" }

# 如果未运行，启动监控
.\scripts\2026-01-12\02-sync-qds-input1.ps1 -Watch
```

**方案C（手动同步）**：
```powershell
# 执行单次同步
.\scripts\2026-01-12\02-sync-qds-input1.ps1 -Once

# 重新编译部署
.\build-ubuntu24-apt.ps1 188
```

---

## 📊 测试检查清单

使用以下清单确保所有步骤完成：

- [ ] **步骤1**：创建符号链接或执行文件同步
- [ ] **步骤2**：运行集成测试脚本（`03-test-qds-integration.ps1`）
- [ ] **步骤3**：所有测试项通过
- [ ] **步骤4**：在 `App.qml` 中添加 `Input1Page`
- [ ] **步骤5**：（可选）本地预览成功
- [ ] **步骤6**：完整编译无错误
- [ ] **步骤7**：部署到设备成功
- [ ] **步骤8**：设备上可以切换到第五个页面
- [ ] **步骤9**：第五个页面界面显示正常
- [ ] **步骤10**：在 QDS 中修改后自动同步

---

## 🎓 日常开发测试流程

### 每次修改 QDS 设计后：

```powershell
# 1. 在 QDS 中保存修改（Ctrl+S）

# 2. 验证同步（可选）
.\scripts\2026-01-12\03-test-qds-integration.ps1

# 3. 快速预览（可选）
.\scripts\2026-01-12\04-preview-qds-page.ps1

# 4. 完整部署测试
.\build-ubuntu24-apt.ps1 188
```

---

## 📚 参考文档

- [QDS项目集成和自动同步方案](02-QDS项目集成和自动同步方案.md)
- [Figma设计导入QML完整指南](01-Figma设计导入QML完整指南.md)
- [Qt Design Studio 官方文档](https://doc.qt.io/qtdesignstudio/)

---

**创建者**：Claude
**文档版本**：1.0
**最后更新**：2026-01-12
