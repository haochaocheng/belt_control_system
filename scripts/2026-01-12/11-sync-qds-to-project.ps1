# ===================================================================================
# 文件: scripts/2026-01-12/11-sync-qds-to-project.ps1
# 描述: QDS 修改后一键同步到主项目（扫描图片 + 修复路径）
# 创建时间: 2026-01-12
# 作者: Claude
# ===================================================================================

#Requires -Version 7
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

param(
    [string]$ProjectRoot = (Get-Location).Path
)

Write-Host "`n==================== QDS 同步到主项目 ====================" -ForegroundColor Cyan

# Step 1: 同步图片资源列表
Write-Host "`nStep 1: 同步图片资源列表..." -ForegroundColor Yellow
& "$ProjectRoot\scripts\2026-01-12\09-sync-input1-resources.ps1"
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ 资源同步失败" -ForegroundColor Red
    exit 1
}

# Step 2: 修复图片路径
Write-Host "`nStep 2: 修复图片路径..." -ForegroundColor Yellow
& "$ProjectRoot\scripts\2026-01-12\10-fix-screen01-image-paths.ps1"
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ 路径修复失败" -ForegroundColor Red
    exit 1
}

Write-Host "`n✅ QDS 同步完成！可以运行编译脚本了：" -ForegroundColor Green
Write-Host "  .\build-ubuntu24-apt.ps1 188" -ForegroundColor Cyan

Write-Host "`n========================================================================`n" -ForegroundColor Cyan
