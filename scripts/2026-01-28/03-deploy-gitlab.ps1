# GitLab 本地部署脚本
# 日期: 2026-01-28
# 功能: 自动部署本地 GitLab

# UTF-8 强制配置
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  GitLab 本地部署脚本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 步骤 1：创建目录结构
Write-Host "步骤 1: 创建目录结构..." -ForegroundColor Cyan

$gitlabDir = "D:\gitlab"
$dirs = @("config", "data", "logs", "backups", "runner-config")

# 创建主目录
if (-not (Test-Path $gitlabDir)) {
    New-Item -ItemType Directory -Path $gitlabDir -Force | Out-Null
    Write-Host "✅ 创建主目录：$gitlabDir" -ForegroundColor Green
} else {
    Write-Host "✅ 主目录已存在：$gitlabDir" -ForegroundColor Green
}

# 创建子目录
foreach ($dir in $dirs) {
    $path = Join-Path $gitlabDir $dir
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Write-Host "✅ 创建子目录：$dir" -ForegroundColor Green
    } else {
        Write-Host "✅ 子目录已存在：$dir" -ForegroundColor Green
    }
}

Write-Host ""

# 步骤 2：创建 docker-compose.yml
Write-Host "步骤 2: 创建 docker-compose.yml..." -ForegroundColor Cyan

$composeFile = Join-Path $gitlabDir "docker-compose.yml"
$composeContent = @"
version: '3.8'

services:
  gitlab:
    image: gitlab/gitlab-ce:latest
    container_name: gitlab
    restart: always
    hostname: 'gitlab.local'
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'http://localhost:8080'
        gitlab_rails['gitlab_shell_ssh_port'] = 2222

        # 时区设置
        gitlab_rails['time_zone'] = 'Asia/Shanghai'

        # 日志轮转配置
        logging['logrotate_frequency'] = "daily"
        logging['logrotate_rotate'] = 7
        logging['logrotate_size'] = "500M"

        # PostgreSQL 配置
        postgresql['max_connections'] = 200
        postgresql['shared_buffers'] = "256MB"

        # Redis 配置
        redis['maxmemory'] = "512mb"
        redis['maxmemory_policy'] = "allkeys-lru"

        # 上传文件大小限制
        gitlab_rails['max_attachment_size'] = 100

        # Git 垃圾回收
        gitlab_rails['git_gc_schedule'] = "0 2 * * *"

        # 备份配置
        gitlab_rails['backup_keep_time'] = 604800

        # 性能优化
        sidekiq['concurrency'] = 10
        puma['worker_processes'] = 2

        # 禁用不需要的功能
        gitlab_rails['usage_ping_enabled'] = false
        gitlab_rails['sentry_enabled'] = false
    ports:
      - '8080:80'
      - '8443:443'
      - '2222:22'
    volumes:
      - 'D:/gitlab/config:/etc/gitlab'
      - 'D:/gitlab/data:/var/opt/gitlab'
      - 'D:/gitlab/logs:/var/log/gitlab'
    shm_size: '256m'
    deploy:
      resources:
        limits:
          memory: 4G
        reservations:
          memory: 2G
"@

Set-Content -Path $composeFile -Value $composeContent -Encoding UTF8
Write-Host "✅ docker-compose.yml 创建成功" -ForegroundColor Green
Write-Host ""

# 步骤 3：检查 Docker 是否运行
Write-Host "步骤 3: 检查 Docker 状态..." -ForegroundColor Cyan

try {
    $dockerVersion = docker --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Docker 已安装：$dockerVersion" -ForegroundColor Green
    } else {
        Write-Host "❌ Docker 未安装或未运行" -ForegroundColor Red
        Write-Host "   请先安装并启动 Docker Desktop" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "❌ Docker 未安装或未运行" -ForegroundColor Red
    Write-Host "   请先安装并启动 Docker Desktop" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# 步骤 4：启动 GitLab
Write-Host "步骤 4: 启动 GitLab..." -ForegroundColor Cyan

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

# 步骤 5：等待 GitLab 启动
Write-Host "步骤 5: 等待 GitLab 启动（约 5-10 分钟）..." -ForegroundColor Cyan
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
