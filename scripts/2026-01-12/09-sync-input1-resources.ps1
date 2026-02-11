#Requires -Version 7.0
<#
.SYNOPSIS
    自动同步 Input1 资源文件和 QML 组件到 CMakeLists.txt
.DESCRIPTION
    1. 扫描 Input1/Input1Content/images 目录，自动生成 CMakeLists.txt 的 RESOURCES 列表
    2. 扫描 Input1/Input1Content/*.ui.qml 文件，自动生成 CMakeLists.txt 的 QML_FILES 列表
    QDS 设计修改后运行此脚本即可自动更新
.EXAMPLE
    .\09-sync-input1-resources.ps1
.NOTES
    2026-01-19: 增强版 - 添加 QML 组件自动检测功能（方案1：简单扫描所有 .ui.qml）
#>
param()

# UTF-8 with BOM
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

$ProjectRoot = "E:\2025\3_gongkongji\belt_control_system"
$Input1ContentDir = "$ProjectRoot\src\qml\Input1\Input1Content"
$ImagesDir = "$Input1ContentDir\images"
$QmlImagesDir = "$ProjectRoot\src\qml\images"  # 2026-02-11: 添加 src/qml/images 目录
$CMakeListsPath = "$ProjectRoot\src\qml\CMakeLists.txt"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  同步 Input1 资源和组件到 CMakeLists.txt" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 检查目录是否存在
if (-not (Test-Path $Input1ContentDir)) {
    Write-Host "❌ 错误：Input1Content 目录不存在：$Input1ContentDir" -ForegroundColor Red
    exit 1
}

# ============================================================
# 第一步：扫描 QML 组件文件（.ui.qml）
# ============================================================
Write-Host "📋 [步骤 1/2] 扫描 QML 组件文件..." -ForegroundColor Yellow

# 扫描所有 .ui.qml 文件（递归）
$qmlFiles = Get-ChildItem -Path $Input1ContentDir -Filter "*.ui.qml" -Recurse |
            Where-Object {
                # 排除 App.qml（QDS 预览专用，不需要在应用中使用）
                $_.Name -ne "App.ui.qml"
            } |
            Sort-Object Name

Write-Host "   找到 $($qmlFiles.Count) 个 QML 组件文件" -ForegroundColor Green

# 生成 QML_FILES 列表（相对于 src/qml/ 的路径）
$qmlFilesList = ""
foreach ($file in $qmlFiles) {
    # 计算相对路径：Input1/Input1Content/xxx.ui.qml
    $relativePath = $file.FullName.Replace("$ProjectRoot\src\qml\", "").Replace("\", "/")
    $qmlFilesList += "        $relativePath`n"
}

# 移除最后的换行符
$qmlFilesList = $qmlFilesList.TrimEnd("`n")

Write-Host ""

# ============================================================
# 第二步：扫描图片资源文件
# ============================================================
Write-Host "📋 [步骤 2/2] 扫描图片资源文件..." -ForegroundColor Yellow

# 2026-02-11: 扫描 Input1/Input1Content/images 目录
if (-not (Test-Path $ImagesDir)) {
    Write-Host "⚠️ 警告：Input1 images 目录不存在，跳过图片扫描" -ForegroundColor Yellow
    $input1ImageFiles = @()
} else {
    $input1ImageFiles = Get-ChildItem -Path $ImagesDir -File |
                        Where-Object { $_.Extension -match '\.(svg|png|jpg|jpeg)$' } |
                        Sort-Object Name
    Write-Host "   找到 $($input1ImageFiles.Count) 个 Input1 图片文件" -ForegroundColor Green
}

# 2026-02-11: 扫描 src/qml/images 目录
if (-not (Test-Path $QmlImagesDir)) {
    Write-Host "⚠️ 警告：src/qml/images 目录不存在，跳过图片扫描" -ForegroundColor Yellow
    $qmlImageFiles = @()
} else {
    $qmlImageFiles = Get-ChildItem -Path $QmlImagesDir -File |
                     Where-Object { $_.Extension -match '\.(svg|png|jpg|jpeg)$' } |
                     Sort-Object Name
    Write-Host "   找到 $($qmlImageFiles.Count) 个 src/qml/images 图片文件" -ForegroundColor Green
}

Write-Host ""

# ============================================================
# 生成 CMakeLists.txt 内容
# ============================================================
Write-Host "📝 生成 CMakeLists.txt 内容..." -ForegroundColor Yellow
Write-Host ""

# 2026-02-11: 生成 RESOURCES 列表，包含 src/qml/images 和 Input1/Input1Content/images
$resourcesList = @"
    RESOURCES
"@

# 2026-02-11: 添加 src/qml/images 目录的图片（不包含 header.png，因为下面会单独添加）
foreach ($file in $qmlImageFiles) {
    if ($file.Name -ne "header.png") {
        $resourcesList += "`n        images/$($file.Name)"
    }
}

# 添加固定的资源文件
$resourcesList += "`n        images/header.png"
$resourcesList += "`n        sounds/ringtone.wav"

# 添加 Input1 模块资源文件
$resourcesList += "`n        # 2026-01-12: Input1 模块资源文件（$($input1ImageFiles.Count) 个图片，全英文文件名）"
foreach ($file in $input1ImageFiles) {
    $resourcesList += "`n        Input1/Input1Content/images/$($file.Name)"
}

$totalImageCount = $qmlImageFiles.Count + $input1ImageFiles.Count

# ============================================================
# 显示预览
# ============================================================
Write-Host "========================================" -ForegroundColor Green
Write-Host "预览 - QML 组件列表（共 $($qmlFiles.Count) 个）：" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "    QML_FILES" -ForegroundColor White
Write-Host "        ... (其他文件)" -ForegroundColor DarkGray
Write-Host "        # 2026-01-19: Input1 模块 QML 组件（$($qmlFiles.Count) 个，自动检测）" -ForegroundColor White
Write-Host $qmlFilesList -ForegroundColor White
Write-Host ""

Write-Host "========================================" -ForegroundColor Green
Write-Host "预览 - 图片资源列表（共 $totalImageCount 个）：" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host $resourcesList -ForegroundColor White
Write-Host "    RESOURCE_PREFIX /qt/qml" -ForegroundColor White
Write-Host "    NO_PLUGIN_OPTIONAL" -ForegroundColor White
Write-Host ")" -ForegroundColor White
Write-Host ""

# ============================================================
# 询问是否自动更新 CMakeLists.txt
# ============================================================
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "是否自动更新 CMakeLists.txt？" -ForegroundColor Yellow
Write-Host "  [Y] 是（推荐）" -ForegroundColor Gray
Write-Host "  [N] 否（手动复制）" -ForegroundColor Gray
Write-Host ""
$choice = Read-Host "请选择 (Y/N)"

if ($choice -eq 'Y' -or $choice -eq 'y') {
    Write-Host ""
    Write-Host "🔧 自动更新 CMakeLists.txt..." -ForegroundColor Yellow

    # 读取 CMakeLists.txt（逐行读取，保留原始格式）
    $lines = Get-Content -Path $CMakeListsPath
    $newLines = [System.Collections.ArrayList]::new()

    $inQmlFilesSection = $false
    $qmlFilesSectionStart = $false
    $skipInput1Lines = $false
    $qmlFilesInserted = $false

    $inResourcesSection = $false
    $resourcesSectionFound = $false

    # 逐行处理
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        # ============================================================
        # 处理 QML_FILES 部分
        # ============================================================
        if ($line -match '^\s*QML_FILES\s*$') {
            $inQmlFilesSection = $true
            $qmlFilesSectionStart = $true
            [void]$newLines.Add($line)
            Write-Host "   ✅ 找到 QML_FILES 部分（行 $($i+1)）" -ForegroundColor Gray
            continue
        }

        # 检测到 Input1 QML 文件区域开始
        if ($inQmlFilesSection -and $line -match '^\s*#.*Input1.*模块') {
            $skipInput1Lines = $true
            # 插入新的注释和 QML 文件列表
            [void]$newLines.Add("        # 2026-01-19: Input1 模块 QML 组件（$($qmlFiles.Count) 个，自动检测）")
            $qmlFilesList -split "`n" | ForEach-Object { [void]$newLines.Add($_) }
            $qmlFilesInserted = $true
            Write-Host "   ✅ 插入 $($qmlFiles.Count) 个 Input1 QML 组件" -ForegroundColor Gray
            continue
        }

        # 跳过旧的 Input1 QML 文件行
        if ($skipInput1Lines -and $line -match '^\s*Input1/Input1Content/.*\.ui\.qml') {
            continue
        }

        # 检测到非 Input1 行，结束跳过
        if ($skipInput1Lines -and $line -notmatch '^\s*Input1/' -and $line -notmatch '^\s*$') {
            $skipInput1Lines = $false
            $inQmlFilesSection = $false
        }

        # ============================================================
        # 处理 RESOURCES 部分
        # ============================================================
        if ($line -match '^\s*RESOURCES\s*$') {
            $inResourcesSection = $true
            $resourcesSectionFound = $true
            # 替换整个 RESOURCES 部分
            $resourcesList -split "`n" | ForEach-Object { [void]$newLines.Add($_) }
            Write-Host "   ✅ 替换 RESOURCES 部分（行 $($i+1)）" -ForegroundColor Gray
            continue
        }

        # 跳过旧的 RESOURCES 内容（直到 RESOURCE_PREFIX）
        if ($inResourcesSection -and $line -notmatch '^\s*RESOURCE_PREFIX') {
            continue
        }

        # 遇到 RESOURCE_PREFIX，结束 RESOURCES 替换
        if ($inResourcesSection -and $line -match '^\s*RESOURCE_PREFIX') {
            $inResourcesSection = $false
        }

        # 保留其他所有行
        [void]$newLines.Add($line)
    }

    # 验证是否成功插入
    if (-not $qmlFilesInserted) {
        Write-Host "   ⚠️ 警告：未找到 Input1 QML 组件插入位置" -ForegroundColor Yellow
        Write-Host "   请手动将以下内容添加到 QML_FILES 部分：" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "        # 2026-01-19: Input1 模块 QML 组件（$($qmlFiles.Count) 个，自动检测）" -ForegroundColor White
        Write-Host $qmlFilesList -ForegroundColor White
    }

    if (-not $resourcesSectionFound) {
        Write-Host "   ❌ 错误：未找到 RESOURCES 部分" -ForegroundColor Red
        exit 1
    }

    # 写回文件（UTF-8 without BOM）
    $newContent = $newLines -join "`n"
    [System.IO.File]::WriteAllText($CMakeListsPath, $newContent, [System.Text.UTF8Encoding]::new($false))

    Write-Host ""
    Write-Host "   ✅ CMakeLists.txt 已更新" -ForegroundColor Green
    Write-Host "      - 更新了 $($qmlFiles.Count) 个 QML 组件" -ForegroundColor Gray
    Write-Host "      - 更新了 $totalImageCount 个图片资源（src/qml/images: $($qmlImageFiles.Count), Input1: $($input1ImageFiles.Count)）" -ForegroundColor Gray
    Write-Host ""
    Write-Host "下一步：运行编译" -ForegroundColor Yellow
    Write-Host "  .\build-ubuntu24-apt.ps1 188" -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "   ℹ️ 已取消自动更新，请手动复制上面的内容到 CMakeLists.txt" -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✅ 完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
