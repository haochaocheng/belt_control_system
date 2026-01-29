# UTF-8 with BOM
# Docker 远程安装脚本 - 从 Windows 远程安装到 RK3588 设备
# 创建时间: 2026-01-29

param(
    [Parameter(Mandatory=$true)]
    [string]$DeviceIp,

    [string]$DeviceUser = "linaro",

    [switch]$ConfigureMirror
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$sshKey = "$env:USERPROFILE\.ssh\id_rsa_rk3588_185"

Write-Host "=== Docker 远程安装 ===" -ForegroundColor Cyan
Write-Host "目标设备: $DeviceUser@$DeviceIp`n" -ForegroundColor Yellow

# 检查 SSH 密钥
if (-not (Test-Path $sshKey)) {
    Write-Host "❌ SSH 密钥不存在: $sshKey" -ForegroundColor Red
    Write-Host "请先运行: .\scripts\2026-01-29\01-setup-ssh-key.ps1" -ForegroundColor Yellow
    exit 1
}

# 步骤 1: 检查设备连接
Write-Host "[1/9] 检查设备连接..." -ForegroundColor Cyan
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
Write-Host "`n[2/9] 检查系统信息..." -ForegroundColor Cyan
$sysInfo = ssh -i $sshKey "$DeviceUser@$DeviceIp" "uname -m && lsb_release -ds"
Write-Host "  系统: $($sysInfo -split "`n" | Select-Object -Last 1)" -ForegroundColor White
Write-Host "  架构: $($sysInfo -split "`n" | Select-Object -First 1)" -ForegroundColor White

# 步骤 3: 检查是否已安装 Docker
Write-Host "`n[3/9] 检查 Docker 安装状态..." -ForegroundColor Cyan
$dockerInstalled = ssh -i $sshKey "$DeviceUser@$DeviceIp" "which docker 2>/dev/null"
if ($dockerInstalled) {
    $dockerVersion = ssh -i $sshKey "$DeviceUser@$DeviceIp" "docker --version"
    Write-Host "  ⚠️  Docker 已安装: $dockerVersion" -ForegroundColor Yellow
    $continue = Read-Host "  是否要重新安装？(y/N)"
    if ($continue -ne "y" -and $continue -ne "Y") {
        Write-Host "  安装已取消" -ForegroundColor Yellow
        exit 0
    }
} else {
    Write-Host "  ℹ️  Docker 未安装" -ForegroundColor White
}

# 步骤 4: 更新系统包
Write-Host "`n[4/9] 更新系统包..." -ForegroundColor Cyan
ssh -i $sshKey "$DeviceUser@$DeviceIp" "sudo apt update" | Out-Null
Write-Host "  ✅ 系统包更新完成" -ForegroundColor Green

# 步骤 5: 安装依赖
Write-Host "`n[5/9] 安装必要的依赖..." -ForegroundColor Cyan
$installDeps = @"
sudo apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
"@
ssh -i $sshKey "$DeviceUser@$DeviceIp" $installDeps | Out-Null
Write-Host "  ✅ 依赖安装完成" -ForegroundColor Green

# 步骤 6: 添加 Docker GPG 密钥和 APT 源
Write-Host "`n[6/9] 配置 Docker APT 源..." -ForegroundColor Cyan
# 2026-01-29: 修复 PowerShell here-string 中的命令替换问题
# 使用单引号 here-string 避免 PowerShell 解释 $() 语法
$setupRepo = @'
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
'@
ssh -i $sshKey "$DeviceUser@$DeviceIp" $setupRepo | Out-Null
Write-Host "  ✅ Docker APT 源配置完成" -ForegroundColor Green

# 步骤 7: 安装 Docker Engine
Write-Host "`n[7/9] 安装 Docker Engine..." -ForegroundColor Cyan
Write-Host "  这可能需要几分钟..." -ForegroundColor Yellow
$installDocker = @"
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
"@
ssh -i $sshKey "$DeviceUser@$DeviceIp" $installDocker | Out-Null
Write-Host "  ✅ Docker Engine 安装完成" -ForegroundColor Green

# 步骤 8: 启动 Docker 服务
Write-Host "`n[8/9] 启动 Docker 服务..." -ForegroundColor Cyan
# 2026-01-29: 使用字符串拼接避免变量替换问题
$startDocker = @"
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $DeviceUser
"@
ssh -i $sshKey "$DeviceUser@$DeviceIp" $startDocker | Out-Null
Write-Host "  ✅ Docker 服务已启动" -ForegroundColor Green

# 步骤 9: 验证安装
Write-Host "`n[9/9] 验证安装..." -ForegroundColor Cyan
$dockerVersion = ssh -i $sshKey "$DeviceUser@$DeviceIp" "sudo docker --version"
$composeVersion = ssh -i $sshKey "$DeviceUser@$DeviceIp" "sudo docker compose version"
Write-Host "  Docker: $dockerVersion" -ForegroundColor White
Write-Host "  Docker Compose: $composeVersion" -ForegroundColor White

# 可选：配置镜像加速
if ($ConfigureMirror) {
    Write-Host "`n[额外] 配置 Docker 镜像加速..." -ForegroundColor Cyan
    # 2026-01-29: 使用单引号 here-string 避免转义问题
    $configureMirror = @'
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null <<'DOCKEREOF'
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
DOCKEREOF
sudo systemctl daemon-reload
sudo systemctl restart docker
'@
    # 2026-01-29: 修复 SSH 命令参数传递问题，使用 bash -c 包装
    ssh -i $sshKey "$DeviceUser@$DeviceIp" "bash -c '$configureMirror'" | Out-Null
    Write-Host "  ✅ 镜像加速配置完成" -ForegroundColor Green
}

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
Write-Host "🎉 Docker 安装成功！" -ForegroundColor Green
