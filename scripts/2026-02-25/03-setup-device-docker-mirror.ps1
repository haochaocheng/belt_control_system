# ✅ 2026-02-25 15:10: 配置设备 Docker 镜像加速器
# 用途：解决设备无法访问 Docker Hub 的问题

$DeviceIP = "192.168.10.185"
$DeviceUser = "linaro"

Write-Host "配置设备 $DeviceIP 的 Docker 镜像加速器..." -ForegroundColor Cyan

$ConfigCmd = @'
sudo mkdir -p /etc/docker && \
echo '{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ]
}' | sudo tee /etc/docker/daemon.json && \
sudo systemctl daemon-reload && \
sudo systemctl restart docker && \
echo "Docker 镜像加速器配置完成"
'@

ssh "${DeviceUser}@${DeviceIP}" $ConfigCmd

Write-Host ""
Write-Host "配置完成，重新运行构建脚本：" -ForegroundColor Green
Write-Host "  .\scripts\2026-02-25\02-simple-device-build.ps1" -ForegroundColor Yellow
