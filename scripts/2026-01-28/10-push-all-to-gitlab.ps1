# 推送所有内容到 GitLab
# 日期: 2026-01-28
# 功能: 将所有分支和标签推送到 GitLab

# UTF-8 强制配置
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  推送所有内容到 GitLab" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 切换到项目目录
Set-Location E:\2025\3_gongkongji\belt_control_system

# 显示当前分支
$currentBranch = git branch --show-current
Write-Host "当前分支: $currentBranch" -ForegroundColor Yellow
Write-Host ""

# 显示所有本地分支
Write-Host "本地分支：" -ForegroundColor Cyan
git branch
Write-Host ""

# 推送所有分支
Write-Host "步骤 1: 推送所有分支到 GitLab..." -ForegroundColor Yellow
git push gitlab --all

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ 所有分支推送成功！" -ForegroundColor Green
} else {
    Write-Host "❌ 分支推送失败" -ForegroundColor Red
    exit 1
}

Write-Host ""

# 推送所有标签
Write-Host "步骤 2: 推送所有标签到 GitLab..." -ForegroundColor Yellow
git push gitlab --tags

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ 所有标签推送成功！" -ForegroundColor Green
} else {
    Write-Host "⚠️ 标签推送失败（可能没有标签）" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  推送完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Host "推送的分支：" -ForegroundColor Cyan
git branch -a | Select-String "gitlab"

Write-Host ""
Write-Host "访问 GitLab 查看：http://localhost:8080/root/belt-control-system" -ForegroundColor Cyan
Write-Host ""
