# 配置 Git 允许本地 HTTP 连接
# 日期: 2026-01-28
# 功能: 允许 Git 使用 HTTP 连接到本地 GitLab

# UTF-8 强制配置
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  配置 Git 允许本地 HTTP" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Set-Location E:\2025\3_gongkongji\belt_control_system

Write-Host "正在配置 Git Credential Manager..." -ForegroundColor Yellow
Write-Host ""

# 方法 1：为 localhost 允许 HTTP
Write-Host "步骤 1: 允许 localhost 使用 HTTP" -ForegroundColor Cyan
git config --global credential.http://localhost.provider generic

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ 配置成功" -ForegroundColor Green
} else {
    Write-Host "⚠️ 配置可能失败，继续尝试其他方法" -ForegroundColor Yellow
}

Write-Host ""

# 方法 2：允许不安全的 HTTP 仓库
Write-Host "步骤 2: 允许不安全的 HTTP 仓库" -ForegroundColor Cyan
git config --global credential.allowUnsafeRemotes true

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ 配置成功" -ForegroundColor Green
} else {
    Write-Host "⚠️ 配置可能失败" -ForegroundColor Yellow
}

Write-Host ""

# 方法 3：为本地仓库配置
Write-Host "步骤 3: 为当前仓库配置" -ForegroundColor Cyan
git config --local credential.http://localhost.provider generic

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ 配置成功" -ForegroundColor Green
} else {
    Write-Host "⚠️ 配置可能失败" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  配置完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Host "当前 Git 配置：" -ForegroundColor Cyan
git config --list | Select-String "credential"

Write-Host ""
Write-Host "现在可以推送到 GitLab 了：" -ForegroundColor Cyan
Write-Host "  .\scripts\2026-01-28\10-push-all-to-gitlab.ps1" -ForegroundColor Yellow
Write-Host ""
