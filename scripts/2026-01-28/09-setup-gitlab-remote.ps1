# GitLab 项目配置脚本
# 日期: 2026-01-28
# 功能: 配置本地 Git 仓库连接到 GitLab

# UTF-8 强制配置
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  配置 GitLab 远程仓库" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 检查当前目录
$currentDir = Get-Location
Write-Host "当前目录: $currentDir" -ForegroundColor Yellow
Write-Host ""

# 检查是否在 Git 仓库中
if (-not (Test-Path ".git")) {
    Write-Host "❌ 当前目录不是 Git 仓库！" -ForegroundColor Red
    Write-Host "   请先切换到项目目录：" -ForegroundColor Yellow
    Write-Host "   cd E:\2025\3_gongkongji\belt_control_system" -ForegroundColor White
    exit 1
}

Write-Host "✅ 当前目录是 Git 仓库" -ForegroundColor Green
Write-Host ""

# 检查是否已经添加了 gitlab 远程仓库
$existingRemotes = git remote -v 2>&1
if ($existingRemotes -match "gitlab") {
    Write-Host "⚠️ GitLab 远程仓库已存在" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "当前远程仓库：" -ForegroundColor Cyan
    git remote -v
    Write-Host ""

    $confirm = Read-Host "是否要删除并重新添加？(yes/no)"
    if ($confirm -eq "yes") {
        git remote remove gitlab
        Write-Host "✅ 已删除旧的 GitLab 远程仓库" -ForegroundColor Green
    } else {
        Write-Host "保持现有配置" -ForegroundColor Yellow
        exit 0
    }
}

# 添加 GitLab 远程仓库
Write-Host "正在添加 GitLab 远程仓库..." -ForegroundColor Yellow
git remote add gitlab http://localhost:8080/root/belt-control-system.git

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ GitLab 远程仓库添加成功！" -ForegroundColor Green
} else {
    Write-Host "❌ 添加失败" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "当前所有远程仓库：" -ForegroundColor Cyan
git remote -v

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  配置完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# 获取当前分支
$currentBranch = git branch --show-current

Write-Host "下一步操作：" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. 推送当前分支到 GitLab：" -ForegroundColor White
Write-Host "   git push gitlab $currentBranch" -ForegroundColor Yellow
Write-Host ""
Write-Host "2. 或推送所有分支：" -ForegroundColor White
Write-Host "   git push gitlab --all" -ForegroundColor Yellow
Write-Host ""
Write-Host "3. 推送所有标签：" -ForegroundColor White
Write-Host "   git push gitlab --tags" -ForegroundColor Yellow
Write-Host ""
Write-Host "4. 使用双重同步脚本：" -ForegroundColor White
Write-Host "   .\scripts\2026-01-28\04-dual-sync.ps1" -ForegroundColor Yellow
Write-Host ""
