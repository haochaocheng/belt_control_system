# UTF-8 with BOM
# Docker 安装脚本 - 使用国内镜像源
# 创建时间: 2026-01-29
# 适用于无法访问 Docker 官方源的情况

param(
    [Parameter(Mandatory=$true)]
    [string]$DeviceIp,

    [string]$DeviceUser = "linaro",

    [ValidateSet("aliyun", "tsinghua", "ustc")]
    [string]$Mirror = "aliyun"
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$sshKey = "$env:USERPROFILE\.ssh\id_rsa_rk3588_185"

# 镜像源配置
$mirrors = @{
    "aliyun" = @{
        "name" = "阿里云"
        "gpg" = "https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg"
        "repo" = "https://mirrors.aliyun.com/docker-ce/linux/ubuntu"
    }
    "tsinghua" = @{
        "name" = "清华大学"
        "gpg" = "https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu/gpg"
        "repo" = "https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu"
    }
    "ustc" = @{
        "name" = "中国科技大学"
        "gpg" = "https://mirrors.ustc.edu.cn/docker-ce/linux/ubuntu/gpg"
        "repo" = "https://mirrors.ustc.edu.cn/docker-ce/linux/ubuntu"
    }
}

$selectedMirror = $mirrors[$Mirror]

Write-Host "=== Docker 安装（国内镜像源） ===" -ForegroundColor Cyan
Write-Host "目标设备: $DeviceUser@$DeviceIp" -ForegroundColor Yellow
Write-Host "镜像源: $($selectedMirror.name)`n" -ForegroundColor Yellow

# 检查 SSH 密钥
if (-not (Test-Path $sshKey)) {
    Write-Host "❌ SSH 密钥不存在: $sshKey" -ForegroundColor Red
    Write-Host "请先运行: .\scripts\2026-01-29\01-setup-ssh-key.ps1" -ForegroundColor Yellow
    exit 1
}

# 步骤 1: 检查设备连接
Write-Host "[1/8] 检查设备连接..." -ForegroundColor Cyan
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

# 步骤 2: 检查系统信息
Write-Host "`n[2/8] 检查系统信息..." -ForegroundColor Cyan
$sysInfo = ssh -i $sshKey "$DeviceUser@$DeviceIp" "uname -m && lsb_release -ds"
Write-Host "  系统: $($sysInfo -split "`n" | Select-Object -Last 1)" -ForegroundColor White
Write-Host "  架构: $($sysInfo -split "`n" | Select-Object -First 1)" -ForegroundColor White

# 步骤 3: 更新系统包
Write-Host "`n[3/8] 更新系统包..." -ForegroundColor Cyan
ssh -i $sshKey "$DeviceUser@$DeviceIp" "sudo apt update" 2>&1 | Out-Null
Write-Host "  ✅ 系统包更新完成" -ForegroundColor Green

# 步骤 4: 安装依赖
Write-Host "`n[4/8] 安装必要的依赖..." -ForegroundColor Cyan
$installDeps = "sudo apt install -y ca-certificates curl gnupg lsb-release"
ssh -i $sshKey "$DeviceUser@$DeviceIp" $installDeps 2>&1 | Out-Null
Write-Host "  ✅ 依赖安装完成" -ForegroundColor Green

# 步骤 5: 添加 Docker GPG 密钥
Write-Host "`n[5/8] 添加 Docker GPG 密钥..." -ForegroundColor Cyan
$addGpgKey = @"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL $($selectedMirror.gpg) | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
"@
ssh -i $sshKey "$DeviceUser@$DeviceIp" $addGpgKey 2>&1 | Out-Null
Write-Host "  ✅ GPG 密钥添加完成" -ForegroundColor Green

# 步骤 6: 添加 Docker APT 源
Write-Host "`n[6/8] 配置 Docker APT 源..." -ForegroundColor Cyan
$addRepo = @"
echo \"deb [arch=`$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] $($selectedMirror.repo) `$(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
"@
ssh -i $sshKey "$DeviceUser@$DeviceIp" $addRepo 2>&1 | Out-Null
Write-Host "  ✅ Docker APT 源配置完成" -ForegroundColor Green

# 步骤 7: 安装 Docker Engine
Write-Host "`n[7/8] 安装 Docker Engine..." -ForegroundColor Cyan
Write-Host "  这可能需要几分钟..." -ForegroundColor Yellow
$installDocker = "sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
ssh -i $sshKey "$DeviceUser@$DeviceIp" $installDocker 2>&1 | Out-Null
Write-Host "  ✅ Docker Engine 安装完成" -ForegroundColor Green

# 步骤 8: 启动 Docker 服务
Write-Host "`n[8/8] 启动 Docker 服务..." -ForegroundColor Cyan
$startDocker = @"
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $DeviceUser
"@
ssh -i $sshKey "$DeviceUser@$DeviceIp" $startDocker 2>&1 | Out-Null
Write-Host "  ✅ Docker 服务已启动" -ForegroundColor Green

# 验证安装
Write-Host "`n[验证] 检查安装结果..." -ForegroundColor Cyan
$dockerVersion = ssh -i $sshKey "$DeviceUser@$DeviceIp" "sudo docker --version"
$composeVersion = ssh -i $sshKey "$DeviceUser@$DeviceIp" "sudo docker compose version"
Write-Host "  Docker: $dockerVersion" -ForegroundColor White
Write-Host "  Docker Compose: $composeVersion" -ForegroundColor White

Write-Host "`n=== 安装完成 ===" -ForegroundColor Green
Write-Host ""
Write-Host "⚠️  重要提示：" -ForegroundColor Yellow
Write-Host "  1. 用户 '$DeviceUser' 已添加到 docker 组" -ForegroundColor White
Write-Host "  2. 需要注销并重新登录，才能无需 sudo 使用 docker 命令" -ForegroundColor White
Write-Host "  3. 或者在 SSH 会话中运行: newgrp docker" -ForegroundColor White
Write-Host ""
Write-Host "验证安装：" -ForegroundColor Cyan
Write-Host "  ssh -i $sshKey $DeviceUser@$DeviceIp" -ForegroundColor White
Write-Host "  sudo docker run hello-world" -ForegroundColor White
Write-Host ""
Write-Host "配置镜像加速（可选）：" -ForegroundColor Cyan
Write-Host "  sudo mkdir -p /etc/docker" -ForegroundColor White
Write-Host "  sudo nano /etc/docker/daemon.json" -ForegroundColor White
Write-Host ""
Write-Host "🎉 Docker 安装成功！" -ForegroundColor Green
