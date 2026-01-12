#Requires -Version 7.0
<#
.SYNOPSIS
    将 Input1 项目的中文文件名重命名为英文
.DESCRIPTION
    根据中文文件名的实际意思，翻译成对应的英文文件名
    适用于 QDS 项目直接放在项目目录的场景
.EXAMPLE
    .\08-rename-chinese-to-english.ps1
#>
param()

# UTF-8 with BOM
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

$ImagesDir = "E:\2025\3_gongkongji\belt_control_system\src\qml\Input1\Input1Content\images"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Input1 图片文件名中译英" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 中文到英文的映射表（根据实际意思翻译）
# 2026-01-12: 根据实际扫描的文件名更新
$renameMap = @{
    # 路径相关
    "路径-1.svg" = "path_1.svg"
    "路径-2.svg" = "path_2.svg"
    "路径.svg" = "path.svg"
    "路径背景.png" = "path_background.png"

    # 标签和状态
    "保护名称.svg" = "protection_name.svg"
    "输入类型.svg" = "input_type.svg"
    "当前值.svg" = "current_value.svg"
    "开关量.svg" = "switch_value.svg"
    "速度.svg" = "speed.svg"
    "故障.svg" = "fault.svg"
    "投入中，正在运行.svg" = "running_active.svg"

    # 背景相关
    "背景底部半透明.png" = "background_bottom_transparent.png"
    "整体上下半透明.png" = "background_full_transparent.png"
    "顶部半透明.png" = "background_top_transparent.png"
    "中上部情况背景.png" = "middle_top_status_bg.png"
    "中上部情况背景-两边.png" = "middle_top_status_bg_sides.png"

    # 第二组1主框（9个PNG文件）
    "第二组1主框-左上.png" = "group2_frame1_top_left.png"
    "第二组1主框-左中.png" = "group2_frame1_middle_left.png"
    "第二组1主框-左下.png" = "group2_frame1_bottom_left.png"
    "第二组1主框-中上.png" = "group2_frame1_top_center.png"
    "第二组1主框-中下.png" = "group2_frame1_bottom_center.png"
    "第二组1主框-右上.png" = "group2_frame1_top_right.png"
    "第二组1主框-右中.png" = "group2_frame1_middle_right.png"
    "第二组1主框-右下.png" = "group2_frame1_bottom_right.png"

    # 第二组2主框（10个文件：2个SVG + 8个PNG）
    "第二组2主框.svg" = "group2_frame2.svg"
    "第二组2主框-底层.svg" = "group2_frame2_base.svg"
    "第二组2主框-左上.png" = "group2_frame2_top_left.png"
    "第二组2主框-左中.png" = "group2_frame2_middle_left.png"
    "第二组2主框-左下.png" = "group2_frame2_bottom_left.png"
    "第二组2主框-上中.png" = "group2_frame2_top_center.png"
    "第二组2主框-下中.png" = "group2_frame2_bottom_center.png"
    "第二组2主框-右上.png" = "group2_frame2_top_right.png"
    "第二组2主框-右中.png" = "group2_frame2_middle_right.png"
    "第二组2主框-右下.png" = "group2_frame2_bottom_right.png"

    # 第二组3主框（9个PNG文件）
    "第二组3主框.png" = "group2_frame3.png"
    "第二组3主框左上.png" = "group2_frame3_top_left.png"
    "第二组3主框左中.png" = "group2_frame3_middle_left.png"
    "第二组3主框左下.png" = "group2_frame3_bottom_left.png"
    "第二组3主框中上.png" = "group2_frame3_top_center.png"
    "第二组3主框中下.png" = "group2_frame3_bottom_center.png"
    "第二组3主框右上.png" = "group2_frame3_top_right.png"
    "第二组3主框右中.png" = "group2_frame3_middle_right.png"
    "第二组3主框右下.png" = "group2_frame3_bottom_right.png"

    # 修复带空格的文件名
    "591f887661e569e40a0f280feaf942c33ddd121328c7b-iqvDOE_fw1200 1.svg" = "figma_export_1.svg"
    "Rectangle 34624263.svg" = "rectangle_34624263.svg"
    "Rectangle 34624264.svg" = "rectangle_34624264.svg"
    "Rectangle 34624265.svg" = "rectangle_34624265.svg"
    "Rectangle 34624270.svg" = "rectangle_34624270.svg"
    "Rectangle 34624271.svg" = "rectangle_34624271.svg"
}

Write-Host "📋 文件重命名计划（中文 → 英文）：" -ForegroundColor Yellow
Write-Host ""

$renamedCount = 0
$notFoundCount = 0

foreach ($oldName in $renameMap.Keys) {
    $newName = $renameMap[$oldName]
    $oldPath = Join-Path $ImagesDir $oldName
    $newPath = Join-Path $ImagesDir $newName

    if (Test-Path $oldPath) {
        Write-Host "  ✓ $oldName" -ForegroundColor Green
        Write-Host "    → $newName" -ForegroundColor Gray

        # 执行重命名
        Move-Item -Path $oldPath -Destination $newPath -Force
        $renamedCount++
    } else {
        Write-Host "  ✗ $oldName (文件不存在)" -ForegroundColor Yellow
        $notFoundCount++
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "重命名完成：" -ForegroundColor White
Write-Host "  ✅ 成功重命名: $renamedCount 个文件" -ForegroundColor Green
if ($notFoundCount -gt 0) {
    Write-Host "  ⚠️ 文件不存在: $notFoundCount 个" -ForegroundColor Yellow
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 生成更新后的文件列表（用于 CMakeLists.txt）
Write-Host "📝 生成 CMakeLists.txt 资源列表..." -ForegroundColor Yellow
Write-Host ""

$allFiles = Get-ChildItem -Path $ImagesDir -File | Sort-Object Name

Write-Host "========================================" -ForegroundColor Green
Write-Host "复制以下内容到 src/qml/CMakeLists.txt 的 RESOURCES 部分：" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "    RESOURCES" -ForegroundColor White
Write-Host "        images/header.png" -ForegroundColor White
Write-Host "        sounds/ringtone.wav" -ForegroundColor White
Write-Host "        # 2026-01-12: Input1 模块资源文件（$($allFiles.Count) 个图片）" -ForegroundColor White

foreach ($file in $allFiles) {
    Write-Host "        pages/Input1Content/images/$($file.Name)" -ForegroundColor White
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "✅ 完成！现在可以更新 CMakeLists.txt 并编译" -ForegroundColor Green
Write-Host ""
