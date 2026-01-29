# ✅ 2026-01-29 等待 GitLab 启动并推送代码
# 用途：GitLab 容器启动需要时间，此脚本等待服务就绪后推送代码
# 使用：.\scripts\2026-01-29\01-wait-and-push-gitlab.ps1

# UTF-8 强制配置
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "等待 GitLab 启动并推送代码" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 检查 GitLab 容器状态
Write-Host "1. 检查 GitLab 容器状态..." -ForegroundColor Yellow
$gitlabContainer = docker ps --filter "name=gitlab" --format "{{.Status}}"
if (-not $gitlabContainer) {
    Write-Host "   ❌ GitLab 容器未运行" -ForegroundColor Red
    Write-Host "   请先启动 GitLab 容器" -ForegroundColor Yellow
    exit 1
}
Write-Host "   ✅ GitLab 容器状态: $gitlabContainer" -ForegroundColor Green
Write-Host ""

# 等待 GitLab 服务就绪
Write-Host "2. 等待 GitLab 服务就绪..." -ForegroundColor Yellow
Write-Host "   GitLab 启动需要 2-3 分钟，请耐心等待..." -ForegroundColor Gray

$maxAttempts = 60  # 最多等待 5 分钟（60 × 5 秒）
$attempt = 0
$gitlabReady = $false

while ($attempt -lt $maxAttempts) {
    $attempt++

    # 检查健康状态
    $healthStatus = docker inspect --format='{{.State.Health.Status}}' gitlab 2>$null

    if ($healthStatus -eq "healthy") {
        Write-Host "   ✅ GitLab 服务已就绪（健康检查通过）" -ForegroundColor Green
        $gitlabReady = $true
        break
    }

    # 显示进度
    $elapsed = $attempt * 5
    Write-Host "   ⏳ 等待中... ($elapsed 秒) - 状态: $healthStatus" -ForegroundColor Gray
    Start-Sleep -Seconds 5
}

if (-not $gitlabReady) {
    Write-Host "   ⚠️ GitLab 启动超时（5 分钟）" -ForegroundColor Yellow
    Write-Host "   您可以稍后手动推送：git push gitlab feature/hardware-video-codec" -ForegroundColor Gray
    exit 1
}

Write-Host ""

# 检查远程仓库配置
Write-Host "3. 检查远程仓库配置..." -ForegroundColor Yellow
$gitlabRemote = git remote get-url gitlab 2>$null
if (-not $gitlabRemote) {
    Write-Host "   ❌ GitLab 远程仓库未配置" -ForegroundColor Red
    exit 1
}
Write-Host "   ✅ GitLab URL: $gitlabRemote" -ForegroundColor Green
Write-Host ""

# 推送到 GitLab
Write-Host "4. 推送代码到 GitLab..." -ForegroundColor Yellow
try {
    $currentBranch = git branch --show-current
    Write-Host "   当前分支: $currentBranch" -ForegroundColor Gray

    git push gitlab $currentBranch 2>&1 | ForEach-Object {
        Write-Host "   $_" -ForegroundColor Gray
    }

    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ 推送成功" -ForegroundColor Green
    } else {
        Write-Host "   ❌ 推送失败（退出码: $LASTEXITCODE）" -ForegroundColor Red
        Write-Host ""
        Write-Host "可能的原因：" -ForegroundColor Yellow
        Write-Host "1. GitLab 仓库不存在 - 请先在 GitLab 创建仓库" -ForegroundColor Gray
        Write-Host "2. 需要认证 - 请检查 GitLab 用户名和密码" -ForegroundColor Gray
        Write-Host "3. 权限不足 - 请检查 GitLab 用户权限" -ForegroundColor Gray
        exit 1
    }
} catch {
    Write-Host "   ❌ 推送失败: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✅ 完成" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
