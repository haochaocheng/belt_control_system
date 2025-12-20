# Fix Docker Registry Configuration
# Remove invalid mirror and use Docker Hub directly

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "修复 Docker 镜像源配置" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "当前问题: Docker 配置的镜像源 docker.mirrors.ustc.edu.cn 无法访问" -ForegroundColor Yellow
Write-Host ""

Write-Host "解决方案:" -ForegroundColor Yellow
Write-Host "  1. 打开 Docker Desktop" -ForegroundColor White
Write-Host "  2. 点击右上角 设置 图标(齿轮)" -ForegroundColor White
Write-Host "  3. 进入 Docker Engine 选项卡" -ForegroundColor White
Write-Host "  4. 找到配置中的 'registry-mirrors' 部分" -ForegroundColor White
Write-Host "  5. 删除或注释掉无效的镜像源" -ForegroundColor White
Write-Host ""

Write-Host "配置示例 (移除或注释镜像源):" -ForegroundColor Yellow
Write-Host @"
{
  "builder": {
    "gc": {
      "defaultKeepStorage": "20GB",
      "enabled": true
    }
  },
  "experimental": false
}
"@ -ForegroundColor Gray
Write-Host ""

Write-Host "或者使用可用的镜像源(如果需要):" -ForegroundColor Yellow
Write-Host @"
{
  "builder": {
    "gc": {
      "defaultKeepStorage": "20GB",
      "enabled": true
    }
  },
  "experimental": false,
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://docker.1panel.live"
  ]
}
"@ -ForegroundColor Gray
Write-Host ""

Write-Host "配置修改后需要:" -ForegroundColor Yellow
Write-Host "  6. 点击 Apply & restart 按钮" -ForegroundColor White
Write-Host "  7. 等待 Docker Desktop 重启完成" -ForegroundColor White
Write-Host ""

Write-Host "按任意键继续,等您修改完成后..." -ForegroundColor Green
$null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
