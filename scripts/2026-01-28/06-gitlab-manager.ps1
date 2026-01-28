# GitLab 日常管理脚本
# 日期: 2026-01-28
# 功能: GitLab 启动、停止、重启、状态查看

# UTF-8 强制配置
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$gitlabDir = "D:\gitlab"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  GitLab 管理脚本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 检查 GitLab 目录
if (-not (Test-Path $gitlabDir)) {
    Write-Host "❌ GitLab 目录不存在：$gitlabDir" -ForegroundColor Red
    exit 1
}

Set-Location $gitlabDir

# 显示菜单
Write-Host "请选择操作：" -ForegroundColor Cyan
Write-Host "1. 查看 GitLab 状态" -ForegroundColor White
Write-Host "2. 启动 GitLab" -ForegroundColor White
Write-Host "3. 停止 GitLab" -ForegroundColor White
Write-Host "4. 重启 GitLab" -ForegroundColor White
Write-Host "5. 查看日志" -ForegroundColor White
Write-Host "6. 访问 GitLab (打开浏览器)" -ForegroundColor White
Write-Host "7. 退出" -ForegroundColor White
Write-Host ""

$choice = Read-Host "请输入选项 (1-7)"

switch ($choice) {
    "1" {
        # 查看状态
        Write-Host "`n查看 GitLab 状态..." -ForegroundColor Cyan
        docker-compose ps
        Write-Host ""

        # 检查是否可以访问
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:8080" -TimeoutSec 5 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                Write-Host "✅ GitLab 运行正常，可以访问：http://localhost:8080" -ForegroundColor Green
            }
        } catch {
            Write-Host "⚠️ GitLab 容器运行中，但 Web 服务可能还在启动" -ForegroundColor Yellow
            Write-Host "   请稍等几分钟或查看日志" -ForegroundColor Yellow
        }
    }

    "2" {
        # 启动
        Write-Host "`n启动 GitLab..." -ForegroundColor Cyan
        docker-compose up -d

        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ GitLab 启动成功" -ForegroundColor Green
            Write-Host "⏳ 首次启动或重启后需要 2-5 分钟初始化" -ForegroundColor Yellow
            Write-Host "   访问：http://localhost:8080" -ForegroundColor Cyan
        } else {
            Write-Host "❌ GitLab 启动失败" -ForegroundColor Red
        }
    }

    "3" {
        # 停止
        Write-Host "`n停止 GitLab..." -ForegroundColor Cyan
        docker-compose down

        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ GitLab 已停止" -ForegroundColor Green
        } else {
            Write-Host "❌ GitLab 停止失败" -ForegroundColor Red
        }
    }

    "4" {
        # 重启
        Write-Host "`n重启 GitLab..." -ForegroundColor Cyan
        docker-compose restart

        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ GitLab 重启成功" -ForegroundColor Green
            Write-Host "⏳ 重启后需要 2-5 分钟初始化" -ForegroundColor Yellow
            Write-Host "   访问：http://localhost:8080" -ForegroundColor Cyan
        } else {
            Write-Host "❌ GitLab 重启失败" -ForegroundColor Red
        }
    }

    "5" {
        # 查看日志
        Write-Host "`n查看 GitLab 日志（按 Ctrl+C 退出）..." -ForegroundColor Cyan
        Write-Host ""
        docker-compose logs -f gitlab
    }

    "6" {
        # 打开浏览器
        Write-Host "`n打开 GitLab..." -ForegroundColor Cyan
        Start-Process "http://localhost:8080"
        Write-Host "✅ 已在浏览器中打开 GitLab" -ForegroundColor Green
    }

    "7" {
        # 退出
        Write-Host "`n退出" -ForegroundColor Yellow
        exit 0
    }

    default {
        Write-Host "`n❌ 无效的选项" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
