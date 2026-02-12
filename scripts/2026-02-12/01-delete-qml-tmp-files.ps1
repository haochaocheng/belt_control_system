#!/usr/bin/env pwsh
# ========================================
# 删除 QML 临时文件脚本
# ========================================
# 创建时间: 2026-02-12
# 用途: 删除 src/qml 目录下所有 .tmp.* 临时文件
# 原因: 这些临时文件包含未修复的 Canvas 代码，导致编译时产生 QPainter 警告
# ========================================

# UTF-8 强制配置
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "删除 QML 临时文件" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$qmlPath = "e:\2025\3_gongkongji\belt_control_system\src\qml"

Write-Host "`n正在搜索临时文件..." -ForegroundColor Yellow
$tmpFiles = Get-ChildItem -Path $qmlPath -Filter "*.tmp.*" -Recurse

if ($tmpFiles.Count -eq 0) {
    Write-Host "✅ 没有找到临时文件" -ForegroundColor Green
    exit 0
}

Write-Host "找到 $($tmpFiles.Count) 个临时文件:" -ForegroundColor Yellow
foreach ($file in $tmpFiles) {
    Write-Host "  - $($file.FullName)" -ForegroundColor Gray
}

Write-Host "`n正在删除临时文件..." -ForegroundColor Yellow
foreach ($file in $tmpFiles) {
    try {
        Remove-Item -Path $file.FullName -Force
        Write-Host "✅ 已删除: $($file.Name)" -ForegroundColor Green
    } catch {
        Write-Host "❌ 删除失败: $($file.Name) - $_" -ForegroundColor Red
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "临时文件清理完成" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
