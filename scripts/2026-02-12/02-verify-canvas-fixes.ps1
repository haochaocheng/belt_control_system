#!/usr/bin/env pwsh
# ========================================
# 验证 Canvas 修复脚本
# ========================================
# 创建时间: 2026-02-12
# 用途: 验证所有 Canvas 组件是否都添加了尺寸检查
# ========================================

# UTF-8 强制配置
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "验证 Canvas 修复" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$qmlPath = "e:\2025\3_gongkongji\belt_control_system\src\qml"

# 查找所有包含 Canvas 的文件
Write-Host "`n正在搜索包含 Canvas 的文件..." -ForegroundColor Yellow
$canvasFiles = Get-ChildItem -Path $qmlPath -Filter "*.qml" -Recurse |
    Select-String -Pattern "Canvas\s*\{" |
    Select-Object -ExpandProperty Path |
    Sort-Object -Unique

Write-Host "找到 $($canvasFiles.Count) 个包含 Canvas 的文件`n" -ForegroundColor Green

$unfixedCanvasCount = 0
$totalCanvasCount = 0

foreach ($file in $canvasFiles) {
    $relativePath = $file.Replace("$qmlPath\", "")
    Write-Host "检查文件: $relativePath" -ForegroundColor Cyan

    # 读取文件内容
    $content = Get-Content -Path $file -Raw

    # 查找所有 onPaint 块
    $onPaintMatches = [regex]::Matches($content, 'onPaint:\s*\{[^}]*\}', [System.Text.RegularExpressions.RegexOptions]::Singleline)

    foreach ($match in $onPaintMatches) {
        $totalCanvasCount++
        $onPaintBlock = $match.Value

        # 检查是否包含尺寸检查
        if ($onPaintBlock -match 'if\s*\(\s*width\s*<=\s*0\s*\|\|\s*height\s*<=\s*0\s*\)\s*return') {
            Write-Host "  ✅ Canvas #${totalCanvasCount} 已修复" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Canvas #${totalCanvasCount} 未修复" -ForegroundColor Red
            Write-Host "     代码片段: $($onPaintBlock.Substring(0, [Math]::Min(100, $onPaintBlock.Length)))..." -ForegroundColor Gray
            $unfixedCanvasCount++
        }
    }

    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "验证结果" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "总 Canvas 数量: $totalCanvasCount" -ForegroundColor Yellow
Write-Host "已修复: $($totalCanvasCount - $unfixedCanvasCount)" -ForegroundColor Green
Write-Host "未修复: $unfixedCanvasCount" -ForegroundColor $(if ($unfixedCanvasCount -eq 0) { "Green" } else { "Red" })

if ($unfixedCanvasCount -eq 0) {
    Write-Host "`n✅ 所有 Canvas 都已修复！" -ForegroundColor Green
} else {
    Write-Host "`n❌ 还有 $unfixedCanvasCount 个 Canvas 未修复！" -ForegroundColor Red
}
