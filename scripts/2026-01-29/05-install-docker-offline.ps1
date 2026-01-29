# UTF-8 with BOM
# Docker 离线安装脚本 - 使用便捷脚本方法
# 创建时间: 2026-01-29
# 适用于无法访问 Docker 官方源的情况

param(
    [Parameter(Mandatory=$true)]
    [string]$DeviceIp,

    [string]$DeviceUser = "linaro"
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$sshKey = "$env:USERPROFILE\.ssh\id_rsa_rk3588_185"

Write-Host "=== Docker 离线安装（便捷脚本方法） ===" -ForegroundColor Cyan
Write-Host "目标设备: $DeviceUser@$DeviceIp`n" -ForegroundColor Yellow

# 检查 SSH 密钥
if (-not (Test-Path $sshKey)) {
    Write-Host "❌ SSH 密钥不存在: $sshKey" -ForegroundColor Red
    exit 1
}

# 步骤 1: 检查设备连接
Write-Host "[1/5] 检查设备连接..." -ForegroundColor Cyan
try {
    $result = ssh -i $sshKey -o ConnectTimeout=5 "$DeviceUser@$DeviceIp" "echo 'Connected'" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "连接失败"
    }
    Write-Host "  ✅ 设备连接正常" -ForegroundColor Green
} catch {
    Write-Host "  ❌ 无法连接到设备" -ForegroundColor Red
    exit 1
}

# 步骤 2: 下载 Docker 便捷安装脚本
Write-Host "`n[2/5] 下载 Docker 便捷安装脚本..." -ForegroundColor Cyan
Write-Host "  使用国内镜像源..." -ForegroundColor Yellow

$downloadScript = @'
# 尝试多个镜像源
MIRRORS=(
    "https://get.docker.com"
    "https://mirrors.aliyun.com/docker-ce/linux/static/stable/aarch64/"
)

for mirror in "${MIRRORS[@]}"; do
    echo "尝试从 $mirror 下载..."
    if curl -fsSL "$mirror" -o /tmp/get-docker.sh 2>/dev/null; then
        echo "✅ 下载成功"
        exit 0
    fi
done

echo "❌ 所有镜像源都无法访问"
exit 1
'@

$result = ssh -i $sshKey "$DeviceUser@$DeviceIp" "bash -c '$downloadScript'"
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ 下载失败，设备可能无法访问互联网" -ForegroundColor Red
    Write-Host "`n建议：" -ForegroundColor Yellow
    Write-Host "  1. 检查设备网络连接" -ForegroundColor White
    Write-Host "  2. 配置 HTTP 代理" -ForegroundColor White
    Write-Host "  3. 使用完全离线安装方法（见文档）" -ForegroundColor White
    exit 1
}
Write-Host "  ✅ 脚本下载完成" -ForegroundColor Green

# 步骤 3: 执行安装脚本
Write-Host "`n[3/5] 执行 Docker 安装..." -ForegroundColor Cyan
Write-Host "  这可能需要几分钟，请耐心等待..." -ForegroundColor Yellow

$installScript = @'
cd /tmp
sudo sh get-docker.sh
'@

ssh -i $sshKey "$DeviceUser@$DeviceIp" "bash -c '$installScript'"
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ 安装失败" -ForegroundColor Red
    exit 1
}
Write-Host "  ✅ Docker 安装完成" -ForegroundColor Green

# 步骤 4: 启动服务
Write-Host "`n[4/5] 启动 Docker 服务..." -ForegroundColor Cyan
$startScript = @'
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
'@

ssh -i $sshKey "$DeviceUser@$DeviceIp" "bash -c '$startScript'"
Write-Host "  ✅ Docker 服务已启动" -ForegroundColor Green

# 步骤 5: 验证安装
Write-Host "`n[5/5] 验证安装..." -ForegroundColor Cyan
$dockerVersion = ssh -i $sshKey "$DeviceUser@$DeviceIp" "sudo docker --version"
Write-Host "  Docker: $dockerVersion" -ForegroundColor White

Write-Host "`n=== 安装完成 ===" -ForegroundColor Green
Write-Host ""
Write-Host "⚠️  重要提示：" -ForegroundColor Yellow
Write-Host "  1. 用户 '$DeviceUser' 已添加到 docker 组" -ForegroundColor White
Write-Host "  2. 需要注销并重新登录，才能无需 sudo 使用 docker 命令" -ForegroundColor White
Write-Host ""
Write-Host "验证安装：" -ForegroundColor Cyan
Write-Host "  ssh -i $sshKey $DeviceUser@$DeviceIp" -ForegroundColor White
Write-Host "  sudo docker run hello-world" -ForegroundColor White
Write-Host ""
Write-Host "🎉 Docker 安装成功！" -ForegroundColor Green
