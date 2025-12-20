# 诊断设备188上Docker容器问题
param(
    [string]$Device = "192.168.10.188"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "诊断设备 $Device 上的Docker容器状态" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`n[1] 检查所有Docker容器..." -ForegroundColor Yellow
ssh "linaro@${Device}" "sudo docker ps -a"

Write-Host "`n[2] 查看belt容器的日志..." -ForegroundColor Yellow
ssh "linaro@${Device}" "sudo docker logs belt 2>&1 | tail -50"

Write-Host "`n[3] 检查容器退出状态..." -ForegroundColor Yellow
ssh "linaro@${Device}" "sudo docker inspect belt --format='{{.State.Status}} - ExitCode: {{.State.ExitCode}}' 2>/dev/null || echo 'Container not found'"

Write-Host "`n[4] 检查Docker镜像..." -ForegroundColor Yellow
ssh "linaro@${Device}" "sudo docker images | grep belt"

Write-Host "`n[5] 系统资源检查..." -ForegroundColor Yellow
ssh "linaro@${Device}" "df -h / && echo '---' && free -h"

Write-Host "`n[6] 尝试手动运行容器（前台模式）..." -ForegroundColor Yellow
Write-Host "执行命令查看详细错误:" -ForegroundColor Gray
Write-Host "ssh linaro@$Device 'sudo docker run --rm belt:min'" -ForegroundColor Green

Write-Host "`n诊断完成！" -ForegroundColor Cyan