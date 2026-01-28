# 等待 GitLab 启动脚本
# 日期: 2026-01-28
# 功能: 等待 GitLab web 服务启动

# UTF-8 强制配置
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "等待 GitLab 启动..." -ForegroundColor Yellow
Write-Host ""

$maxWait = 300  # 最多等待 5 分钟
$waited = 0
$interval = 15

while ($waited -lt $maxWait) {
    Write-Host "已等待 $waited 秒..." -ForegroundColor Cyan

    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8080" -TimeoutSec 5 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Host ""
            Write-Host "✅ GitLab 启动成功！" -ForegroundColor Green
            Write-Host "访问：http://localhost:8080" -ForegroundColor Cyan
            exit 0
        }
    } catch {
        # 继续等待
    }

    Start-Sleep -Seconds $interval
    $waited += $interval
}

Write-Host ""
Write-Host "⚠️ 等待超时" -ForegroundColor Yellow
Write-Host "请手动检查 GitLab 状态：" -ForegroundColor Yellow
Write-Host "  docker exec gitlab gitlab-ctl status" -ForegroundColor White
Write-Host "  docker exec gitlab tail -50 /var/log/gitlab/puma/puma_stdout.log" -ForegroundColor White
