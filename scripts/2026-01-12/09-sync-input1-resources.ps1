#Requires -Version 7.0
<#
.SYNOPSIS
    自动同步 Input1 资源文件到 CMakeLists.txt
.DESCRIPTION
    扫描 Input1/Input1Content/images 目录，自动生成 CMakeLists.txt 的 RESOURCES 列表
    QDS 设计修改后运行此脚本即可自动更新
.EXAMPLE
    .\09-sync-input1-resources.ps1
#>
param()

# UTF-8 with BOM
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

$ProjectRoot = "E:\2025\3_gongkongji\belt_control_system"
$ImagesDir = "$ProjectRoot\src\qml\Input1\Input1Content\images"
$CMakeListsPath = "$ProjectRoot\src\qml\CMakeLists.txt"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  同步 Input1 资源文件到 CMakeLists.txt" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 检查目录是否存在
if (-not (Test-Path $ImagesDir)) {
    Write-Host "❌ 错误：Input1 images 目录不存在：$ImagesDir" -ForegroundColor Red
    exit 1
}

# 扫描所有图片文件（排除 .txt 文件）
Write-Host "📋 扫描图片文件..." -ForegroundColor Yellow
$imageFiles = Get-ChildItem -Path $ImagesDir -File |
              Where-Object { $_.Extension -match '\.(svg|png|jpg|jpeg)$' } |
              Sort-Object Name

Write-Host "   找到 $($imageFiles.Count) 个图片文件" -ForegroundColor Green
Write-Host ""

# 生成 RESOURCES 列表
Write-Host "📝 生成 CMakeLists.txt 内容..." -ForegroundColor Yellow
Write-Host ""

$resourcesList = @"
    RESOURCES
        images/header.png
        sounds/ringtone.wav
        # 2026-01-12: Input1 模块资源文件（$($imageFiles.Count) 个图片，全英文文件名）
"@

foreach ($file in $imageFiles) {
    $resourcesList += "`n        Input1/Input1Content/images/$($file.Name)"
}

# 显示预览
Write-Host "========================================" -ForegroundColor Green
Write-Host "预览（复制以下内容到 CMakeLists.txt）：" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host $resourcesList -ForegroundColor White
Write-Host "    RESOURCE_PREFIX /qt/qml" -ForegroundColor White
Write-Host "    NO_PLUGIN_OPTIONAL" -ForegroundColor White
Write-Host ")" -ForegroundColor White
Write-Host ""

# 询问是否自动更新 CMakeLists.txt
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "是否自动更新 CMakeLists.txt？" -ForegroundColor Yellow
Write-Host "  [Y] 是（推荐）" -ForegroundColor Gray
Write-Host "  [N] 否（手动复制）" -ForegroundColor Gray
Write-Host ""
$choice = Read-Host "请选择 (Y/N)"

if ($choice -eq 'Y' -or $choice -eq 'y') {
    Write-Host ""
    Write-Host "🔧 自动更新 CMakeLists.txt..." -ForegroundColor Yellow

    # 读取 CMakeLists.txt
    $content = Get-Content -Path $CMakeListsPath -Raw

    # 查找 RESOURCES 部分的起始位置
    $resourcesStart = $content.IndexOf("    RESOURCES")
    if ($resourcesStart -eq -1) {
        Write-Host "❌ 错误：未找到 RESOURCES 部分" -ForegroundColor Red
        exit 1
    }

    # 查找 RESOURCES 部分的结束位置（RESOURCE_PREFIX）
    $resourcesEnd = $content.IndexOf("    RESOURCE_PREFIX", $resourcesStart)
    if ($resourcesEnd -eq -1) {
        Write-Host "❌ 错误：未找到 RESOURCE_PREFIX" -ForegroundColor Red
        exit 1
    }

    # 替换 RESOURCES 部分
    $before = $content.Substring(0, $resourcesStart)
    $after = $content.Substring($resourcesEnd)
    $newContent = $before + $resourcesList + "`n" + $after

    # 写回文件
    Set-Content -Path $CMakeListsPath -Value $newContent -Encoding UTF8 -NoNewline

    Write-Host "   ✅ CMakeLists.txt 已更新" -ForegroundColor Green
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
