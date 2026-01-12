# Qt Design Studio 项目集成和自动同步方案

**创建时间**：2026-01-12
**QDS 项目路径**：`E:\2025\3_gongkongji\tp\qds\Input1`
**目标项目**：Belt Control System（皮带控制系统）
**集成目标**：作为第五个页面

---

## 📋 项目结构分析

### QDS 项目结构
```
E:\2025\3_gongkongji\tp\qds\Input1\
├── Input1Content/           # 主要内容目录
│   ├── App.qml             # QDS 项目入口
│   ├── Screen01.ui.qml     # 主界面（输入状态监控）
│   ├── images/             # 图片资源（SVG、PNG）
│   └── fonts/              # 字体资源
├── Input1/                  # 模块定义
│   ├── Constants.qml       # 常量定义
│   ├── EventListModel.qml  # 事件列表模型
│   └── qmldir              # 模块导入配置
├── Input1.qrc              # Qt 资源文件
└── Input1.qmlproject       # QDS 项目文件
```

### 当前项目结构
```
belt_control_system\
├── src\qml\
│   ├── App.qml             # 主应用入口
│   ├── main.qml            # Qt 窗口入口
│   ├── pages\              # 页面目录
│   │   ├── ControlPanel.qml        # 第1页：控制面板
│   │   ├── ParameterSettings.qml   # 第2页：参数设置
│   │   ├── AlarmPage.qml           # 第3页：报警页面
│   │   ├── DeviceOperationLog.qml  # 第4页：操作日志
│   │   └── [Input1Page.qml]        # 第5页：输入监控（待集成）
│   └── components\         # 组件目录
```

---

## 🎯 集成方案（三种方法）

### 方案A：符号链接（推荐）⭐⭐⭐⭐⭐

**优点**：
- ✅ QDS 修改立即生效，无需复制
- ✅ 单一数据源，避免不同步
- ✅ 节省磁盘空间

**缺点**：
- ⚠️ 需要管理员权限创建符号链接
- ⚠️ 删除链接可能影响源文件（需小心）

**实施步骤**：见下文"方案A实施"

---

### 方案B：文件监控同步（备选）⭐⭐⭐⭐

**优点**：
- ✅ 自动同步，无需手动操作
- ✅ 独立副本，删除不影响源文件
- ✅ 可添加自动处理逻辑（如路径修正）

**缺点**：
- ⚠️ 需要运行后台脚本
- ⚠️ 占用额外磁盘空间

**实施步骤**：见下文"方案B实施"

---

### 方案C：手动复制（不推荐）⭐⭐

**优点**：
- ✅ 简单直接

**缺点**：
- ❌ 每次修改后需手动复制
- ❌ 容易忘记同步
- ❌ 维护成本高

---

## 🚀 方案A：符号链接实施（推荐）

### 步骤1：创建符号链接

使用 PowerShell（管理员模式）创建符号链接：

```powershell
# 以管理员身份运行 PowerShell

# 1. 链接 QDS 内容目录到项目页面目录
New-Item -ItemType SymbolicLink `
    -Path "E:\2025\3_gongkongji\belt_control_system\src\qml\pages\Input1Content" `
    -Target "E:\2025\3_gongkongji\tp\qds\Input1\Input1Content"

# 2. 链接 QDS 模块目录
New-Item -ItemType SymbolicLink `
    -Path "E:\2025\3_gongkongji\belt_control_system\src\qml\pages\Input1" `
    -Target "E:\2025\3_gongkongji\tp\qds\Input1\Input1"

Write-Host "✅ 符号链接创建成功！" -ForegroundColor Green
```

**验证符号链接**：
```powershell
# 检查符号链接是否创建成功
Get-Item "E:\2025\3_gongkongji\belt_control_system\src\qml\pages\Input1Content" | Select-Object Target
Get-Item "E:\2025\3_gongkongji\belt_control_system\src\qml\pages\Input1" | Select-Object Target
```

---

### 步骤2：创建页面包装器

在项目中创建 `Input1Page.qml` 作为第五个页面：

**文件路径**：`src/qml/pages/Input1Page.qml`

```qml
// 文件: src/qml/pages/Input1Page.qml
// 描述: 输入监控页面（QDS 设计）
// 创建时间: 2026-01-12

import QtQuick 6.5
import QtQuick.Controls 6.5
import "../pages/Input1"        // 导入 QDS 模块（符号链接）

Item {
    id: input1Page
    anchors.fill: parent

    // 页面标题（可选，用于调试）
    property string pageTitle: "输入监控"

    // QDS 设计的主界面
    Screen01 {
        id: mainScreen
        anchors.fill: parent

        // 如果需要与后端数据绑定，在这里添加
        // 例如：
        // Connections {
        //     target: deviceManager
        //     function onDeviceStatusChanged(deviceId, status) {
        //         // 更新界面状态
        //     }
        // }
    }

    // 可选：添加返回按钮或其他控制
    // Button {
    //     text: "返回"
    //     anchors.top: parent.top
    //     anchors.left: parent.left
    //     onClicked: swipeView.currentIndex = 0
    // }
}
```

---

### 步骤3：在主应用中添加页面

修改 `src/qml/App.qml`，添加第五个页面：

```qml
// 在 SwipeView 中添加第五个页面
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
    }
}
```

---

### 步骤4：配置 QML 导入路径

修改 `CMakeLists.txt`，添加 QDS 模块导入路径：

```cmake
# 添加 QML 导入路径
set(QML_IMPORT_PATH
    "${CMAKE_CURRENT_SOURCE_DIR}/src/qml"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/qml/pages/Input1"  # QDS 模块路径
    CACHE STRING "" FORCE
)

# 如果使用 qt_add_qml_module（Qt 6）
qt_add_qml_module(belt_control_system
    URI BeltControl
    VERSION 1.0
    QML_FILES
        src/qml/main.qml
        src/qml/App.qml
        src/qml/pages/ControlPanel.qml
        src/qml/pages/ParameterSettings.qml
        src/qml/pages/AlarmPage.qml
        src/qml/pages/DeviceOperationLog.qml
        src/qml/pages/Input1Page.qml  # 新增
    RESOURCES
        # 添加 QDS 资源（如果需要）
        # src/qml/pages/Input1Content/images/*
)
```

---

### 步骤5：测试集成

```powershell
# 重新编译项目
.\build-ubuntu24-apt.ps1 188

# 运行应用，切换到第五个页面
# 使用左右箭头键或鼠标滑动
```

---

## 🔄 方案B：文件监控同步实施

如果无法使用符号链接（权限限制），使用文件监控脚本：

### 创建同步脚本

**文件路径**：`scripts/2026-01-12/01-sync-qds-input1.ps1`

```powershell
#Requires -Version 7.0
# UTF-8 with BOM
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

<#
.SYNOPSIS
    自动同步 QDS Input1 项目到 Belt Control System
.DESCRIPTION
    监控 QDS 项目文件变化，自动复制到目标项目
.EXAMPLE
    .\01-sync-qds-input1.ps1 -Watch
#>

param(
    [switch]$Watch,      # 监控模式（持续运行）
    [switch]$Once        # 单次同步
)

# 配置路径
$QDS_PROJECT = "E:\2025\3_gongkongji\tp\qds\Input1"
$TARGET_PROJECT = "E:\2025\3_gongkongji\belt_control_system\src\qml\pages"

# 同步目录映射
$SYNC_MAPPINGS = @(
    @{
        Source = "$QDS_PROJECT\Input1Content"
        Target = "$TARGET_PROJECT\Input1Content"
    },
    @{
        Source = "$QDS_PROJECT\Input1"
        Target = "$TARGET_PROJECT\Input1"
    }
)

function Sync-QdsProject {
    Write-Host "🔄 开始同步 QDS 项目..." -ForegroundColor Cyan

    foreach ($mapping in $SYNC_MAPPINGS) {
        $source = $mapping.Source
        $target = $mapping.Target

        Write-Host "  📁 同步: $source -> $target"

        # 创建目标目录
        if (-not (Test-Path $target)) {
            New-Item -ItemType Directory -Path $target -Force | Out-Null
        }

        # 复制文件（保留时间戳）
        Copy-Item -Path "$source\*" -Destination $target -Recurse -Force

        Write-Host "  ✅ 完成" -ForegroundColor Green
    }

    Write-Host "✅ 同步完成！" -ForegroundColor Green
}

function Watch-QdsProject {
    Write-Host "👀 开始监控 QDS 项目变化..." -ForegroundColor Yellow
    Write-Host "按 Ctrl+C 停止监控" -ForegroundColor Gray

    # 创建文件监控器
    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $QDS_PROJECT
    $watcher.IncludeSubdirectories = $true
    $watcher.EnableRaisingEvents = $true

    # 定义事件处理
    $action = {
        $path = $Event.SourceEventArgs.FullPath
        $changeType = $Event.SourceEventArgs.ChangeType
        $timestamp = Get-Date -Format "HH:mm:ss"

        Write-Host "[$timestamp] 检测到变化: $changeType - $path" -ForegroundColor Yellow

        # 延迟同步（避免频繁触发）
        Start-Sleep -Seconds 1
        Sync-QdsProject
    }

    # 注册事件
    $handlers = @(
        Register-ObjectEvent -InputObject $watcher -EventName "Changed" -Action $action
        Register-ObjectEvent -InputObject $watcher -EventName "Created" -Action $action
        Register-ObjectEvent -InputObject $watcher -EventName "Deleted" -Action $action
        Register-ObjectEvent -InputObject $watcher -EventName "Renamed" -Action $action
    )

    try {
        # 首次同步
        Sync-QdsProject

        # 持续监控
        while ($true) {
            Start-Sleep -Seconds 1
        }
    }
    finally {
        # 清理事件处理器
        $handlers | ForEach-Object { Unregister-Event -SourceIdentifier $_.Name }
        $watcher.Dispose()
        Write-Host "监控已停止" -ForegroundColor Red
    }
}

# 主逻辑
if ($Watch) {
    Watch-QdsProject
}
elseif ($Once) {
    Sync-QdsProject
}
else {
    Write-Host "用法:" -ForegroundColor Yellow
    Write-Host "  .\01-sync-qds-input1.ps1 -Once   # 单次同步"
    Write-Host "  .\01-sync-qds-input1.ps1 -Watch  # 持续监控"
}
```

**使用方法**：

```powershell
# 单次同步
.\scripts\2026-01-12\01-sync-qds-input1.ps1 -Once

# 持续监控（在后台运行）
.\scripts\2026-01-12\01-sync-qds-input1.ps1 -Watch
```

---

## 📝 工作流程

### 日常开发流程

#### 1. 在 Qt Design Studio 中设计界面

```
1. 打开 QDS
2. 打开项目: E:\2025\3_gongkongji\tp\qds\Input1\Input1.qmlproject
3. 编辑 Screen01.ui.qml
4. 保存（Ctrl+S）
```

#### 2. 自动同步到项目（方案A）

```
✅ 无需操作！符号链接自动生效
```

#### 2. 自动同步到项目（方案B）

```
✅ 监控脚本自动检测并同步
```

#### 3. 测试效果

```powershell
# 重新编译（如果修改了 QML 结构）
.\build-ubuntu24-apt.ps1 188

# 或直接运行（如果只修改了 UI）
# QML 热重载会自动刷新界面
```

---

## ⚙️ 高级配置

### 1. 配置 QDS 导出设置

在 QDS 中配置导出选项：

```
文件 → 导出项目 → Qt Quick Application
- 目标目录: E:\2025\3_gongkongji\tp\qds\Input1
- 包含资源: ✅
- 生成 CMakeLists.txt: ❌（我们使用自己的）
```

### 2. 路径修正（如果需要）

如果 QDS 项目使用相对路径导入资源，可能需要修正：

**创建路径适配器**：`src/qml/pages/Input1Adapter.qml`

```qml
pragma Singleton
import QtQuick 6.5

QtObject {
    // 资源路径前缀
    readonly property string imagePrefix: "../pages/Input1Content/images/"

    // 辅助函数：获取完整路径
    function getImagePath(imageName) {
        return imagePrefix + imageName
    }
}
```

### 3. 数据绑定

在 `Input1Page.qml` 中绑定后端数据：

```qml
Screen01 {
    // 假设 QDS 中有一个 Text 元素 id 为 text1
    // Component.onCompleted: {
    //     // 绑定设备状态
    //     text1.text = Qt.binding(function() {
    //         return deviceManager.getDeviceStatus("GSC10")
    //     })
    // }
}
```

---

## 🔍 故障排查

### 问题1：符号链接创建失败

**错误信息**：`New-Item : 拒绝访问`

**解决方法**：
```powershell
# 1. 以管理员身份运行 PowerShell
# 2. 启用开发者模式（Windows 10/11）
#    设置 → 更新和安全 → 开发者选项 → 开发者模式
```

### 问题2：QML 导入失败

**错误信息**：`module "Input1" is not installed`

**解决方法**：
```qml
// 检查 qmldir 文件是否存在
// Input1/qmldir 内容示例：
module Input1
singleton Constants 1.0 Constants.qml
EventListModel 1.0 EventListModel.qml
```

### 问题3：图片资源找不到

**错误信息**：`Cannot open: qrc:/images/xxx.png`

**解决方法**：
```cmake
# 在 CMakeLists.txt 中添加资源
qt_add_resources(belt_control_system "input1_resources"
    PREFIX "/Input1"
    BASE "src/qml/pages/Input1Content"
    FILES
        src/qml/pages/Input1Content/images/*.png
        src/qml/pages/Input1Content/images/*.svg
)
```

---

## 📊 方案对比总结

| 特性 | 方案A：符号链接 | 方案B：文件监控 | 方案C：手动复制 |
|------|----------------|----------------|----------------|
| **同步速度** | ⚡ 实时 | ⚡ 1-2秒延迟 | 🐌 手动 |
| **操作复杂度** | ⭐⭐ | ⭐⭐⭐ | ⭐ |
| **维护成本** | ⭐ 低 | ⭐⭐ 中 | ⭐⭐⭐ 高 |
| **数据安全** | ⚠️ 单一源 | ✅ 独立副本 | ✅ 独立副本 |
| **磁盘占用** | ✅ 无额外占用 | ⚠️ 双倍占用 | ⚠️ 双倍占用 |
| **权限要求** | ⚠️ 管理员 | ✅ 普通用户 | ✅ 普通用户 |
| **推荐度** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ |

---

## 🎯 推荐方案

### 开发环境：方案A（符号链接）

- ✅ 实时同步，无延迟
- ✅ 单一数据源，避免冲突
- ✅ QDS 和项目完全同步

### 生产环境：方案B（文件监控）或手动复制

- ✅ 独立副本，更安全
- ✅ 不依赖符号链接
- ✅ 便于版本控制

---

## 📚 参考资料

- [Qt Design Studio 文档](https://doc.qt.io/qtdesignstudio/)
- [QML 模块导入](https://doc.qt.io/qt-6/qtqml-modules-topic.html)
- [Windows 符号链接](https://learn.microsoft.com/zh-cn/windows/win32/fileio/symbolic-links)
- [PowerShell FileSystemWatcher](https://learn.microsoft.com/en-us/dotnet/api/system.io.filesystemwatcher)

---

## ✅ 下一步行动

1. **选择集成方案**（推荐方案A）
2. **执行集成脚本**
3. **创建 Input1Page.qml 包装器**
4. **修改 App.qml 添加第五个页面**
5. **测试并验证**

---

**创建者**：Claude
**文档版本**：1.0
**最后更新**：2026-01-12
