# GitLab 镜像下载和部署脚本（使用国内镜像源）
# 日期: 2026-01-28
# 功能: 使用国内镜像源下载 GitLab 镜像并部署

# UTF-8 强制配置
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  GitLab 镜像下载和部署" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 配置国内镜像源
Write-Host "步骤 1: 配置 Docker 镜像源..." -ForegroundColor Cyan

$dockerConfigDir = "$env:USERPROFILE\.docker"
$dockerConfigFile = Join-Path $dockerConfigDir "daemon.json"

# 创建配置目录
if (-not (Test-Path $dockerConfigDir)) {
    New-Item -ItemType Directory -Path $dockerConfigDir -Force | Out-Null
}

# Docker 镜像源配置
$daemonConfig = @{
    "registry-mirrors" = @(
        "https://docker.m.daocloud.io",
        "https://docker.1panel.live",
        "https://hub.rat.dev"
    )
    "insecure-registries" = @()
} | ConvertTo-Json -Depth 10

Write-Host "配置内容：" -ForegroundColor Yellow
Write-Host $daemonConfig -ForegroundColor White
Write-Host ""

$confirm = Read-Host "是否配置 Docker 镜像源？(yes/no)"

if ($confirm -eq "yes") {
    Set-Content -Path $dockerConfigFile -Value $daemonConfig -Encoding UTF8
    Write-Host "✅ Docker 镜像源配置完成" -ForegroundColor Green
    Write-Host ""
    Write-Host "⚠️ 需要重启 Docker Desktop 才能生效" -ForegroundColor Yellow
    Write-Host "   1. 右键点击任务栏的 Docker 图标" -ForegroundColor White
    Write-Host "   2. 选择 'Quit Docker Desktop'" -ForegroundColor White
    Write-Host "   3. 重新启动 Docker Desktop" -ForegroundColor White
    Write-Host ""

    $restart = Read-Host "配置完成后，按回车继续..."
} else {
    Write-Host "⏭️ 跳过镜像源配置" -ForegroundColor Yellow
}

Write-Host ""

# 步骤 2：手动拉取 GitLab 镜像
Write-Host "步骤 2: 拉取 GitLab 镜像..." -ForegroundColor Cyan
Write-Host "⏳ 镜像大小约 3GB，下载需要一些时间" -ForegroundColor Yellow
Write-Host ""

try {
    # 尝试从 Docker Hub 拉取
    Write-Host "正在从 Docker Hub 拉取镜像..." -ForegroundColor Cyan
    docker pull gitlab/gitlab-ce:latest

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ GitLab 镜像下载成功" -ForegroundColor Green
    } else {
        Write-Host "❌ 镜像下载失败" -ForegroundColor Red
        Write-Host ""
        Write-Host "可能的原因：" -ForegroundColor Yellow
        Write-Host "1. 网络连接问题" -ForegroundColor White
        Write-Host "2. Docker Hub 访问受限" -ForegroundColor White
        Write-Host "3. 镜像源配置未生效" -ForegroundColor White
        Write-Host ""
        Write-Host "解决方案：" -ForegroundColor Cyan
        Write-Host "1. 确保 Docker Desktop 已重启" -ForegroundColor White
        Write-Host "2. 检查网络连接" -ForegroundColor White
        Write-Host "3. 稍后重试" -ForegroundColor White
        exit 1
    }
} catch {
    Write-Host "❌ 镜像下载失败：$($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# 步骤 3：启动 GitLab
Write-Host "步骤 3: 启动 GitLab..." -ForegroundColor Cyan

$gitlabDir = "D:\gitlab"
Set-Location $gitlabDir

try {
    docker-compose up -d
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ GitLab 容器启动成功" -ForegroundColor Green
    } else {
        Write-Host "❌ GitLab 容器启动失败" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ GitLab 容器启动失败：$($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# 步骤 4：等待 GitLab 启动
Write-Host "步骤 4: 等待 GitLab 启动（约 5-10 分钟）..." -ForegroundColor Cyan
Write-Host "⏳ 首次启动需要初始化数据库和配置，请耐心等待" -ForegroundColor Yellow
Write-Host ""

$maxWait = 600  # 最多等待 10 分钟
$waited = 0
$interval = 10

while ($waited -lt $maxWait) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8080" -TimeoutSec 5 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            Write-Host "✅ GitLab 启动成功！" -ForegroundColor Green
            break
        }
    } catch {
        # 继续等待
    }

    Write-Host "已等待 $waited 秒..." -ForegroundColor Yellow
    Start-Sleep -Seconds $interval
    $waited += $interval
}

Write-Host ""

if ($waited -ge $maxWait) {
    Write-Host "⚠️ 等待超时，GitLab 可能还在启动中" -ForegroundColor Yellow
    Write-Host "   请手动检查 GitLab 状态：" -ForegroundColor Yellow
    Write-Host "   docker-compose logs -f gitlab" -ForegroundColor White
    Write-Host ""
    Write-Host "   或访问：http://localhost:8080" -ForegroundColor White
} else {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  GitLab 部署成功！" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "下一步操作：" -ForegroundColor Cyan
    Write-Host "1. 访问：http://localhost:8080" -ForegroundColor White
    Write-Host "2. 设置管理员密码（至少 8 位）" -ForegroundColor White
    Write-Host "3. 使用 root 账户登录" -ForegroundColor White
    Write-Host "4. 创建项目：belt-control-system" -ForegroundColor White
    Write-Host ""
    Write-Host "然后运行：" -ForegroundColor Cyan
    Write-Host "  cd E:\2025\3_gongkongji\belt_control_system" -ForegroundColor White
    Write-Host "  git remote add gitlab http://localhost:8080/root/belt-control-system.git" -ForegroundColor White
    Write-Host "  git push gitlab main" -ForegroundColor White
}

Write-Host ""
Write-Host "查看日志：docker-compose -f D:\gitlab\docker-compose.yml logs -f" -ForegroundColor Cyan
Write-Host "停止 GitLab：docker-compose -f D:\gitlab\docker-compose.yml down" -ForegroundColor Cyan
Write-Host "重启 GitLab：docker-compose -f D:\gitlab\docker-compose.yml restart" -ForegroundColor Cyan
