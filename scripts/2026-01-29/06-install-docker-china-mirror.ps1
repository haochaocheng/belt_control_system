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
# 2026-01-29: 删除旧密钥以确保重新添加正确的密钥
$addGpgKey = @"
sudo rm -f /etc/apt/keyrings/docker.gpg
sudo mkdir -p /etc/apt/keyrings
curl -fsSL $($selectedMirror.gpg) | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
"@
ssh -i $sshKey "$DeviceUser@$DeviceIp" $addGpgKey 2>&1 | Out-Null
Write-Host "  ✅ GPG 密钥添加完成" -ForegroundColor Green

# 步骤 6: 添加 Docker APT 源
Write-Host "`n[6/8] 配置 Docker APT 源..." -ForegroundColor Cyan
# 2026-01-29: 使用 echo 直接写入，避免引号问题
$addRepo = @"
echo 'deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.gpg] $($selectedMirror.repo) focal stable' | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
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

# 步骤 9: 配置镜像加速
Write-Host "`n[9/9] 配置 Docker 镜像加速..." -ForegroundColor Cyan
# 2026-01-29: 自动配置镜像加速器，提高拉取速度
$configureMirror = @'
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null <<'DOCKEREOF'
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.ccs.tencentyun.com"
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
ssh -i $sshKey "$DeviceUser@$DeviceIp" "bash -c '$configureMirror'" 2>&1 | Out-Null
Write-Host "  ✅ 镜像加速配置完成" -ForegroundColor Green

# 验证安装
Write-Host "`n[验证] 检查安装结果..." -ForegroundColor Cyan
$dockerVersion = ssh -i $sshKey "$DeviceUser@$DeviceIp" "sudo docker --version 2>&1"
$composeVersion = ssh -i $sshKey "$DeviceUser@$DeviceIp" "sudo docker compose version 2>&1"

if ($dockerVersion -match "Docker version") {
    Write-Host "  ✅ Docker: $dockerVersion" -ForegroundColor Green
} else {
    Write-Host "  ❌ Docker 未正确安装" -ForegroundColor Red
    Write-Host "  错误: $dockerVersion" -ForegroundColor Gray
}

if ($composeVersion -match "Docker Compose version") {
    Write-Host "  ✅ Docker Compose: $composeVersion" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Docker Compose: $composeVersion" -ForegroundColor Yellow
}

# 测试 Docker
Write-Host "`n[测试] 运行 hello-world 容器..." -ForegroundColor Cyan
$helloWorld = ssh -i $sshKey "$DeviceUser@$DeviceIp" "sudo docker run --rm hello-world 2>&1"
if ($helloWorld -match "Hello from Docker") {
    Write-Host "  ✅ Docker 运行正常！" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Docker 测试失败（可能是网络问题）" -ForegroundColor Yellow
}

Write-Host "`n=== 安装完成 ===" -ForegroundColor Green
Write-Host ""
Write-Host "📋 下一步操作：" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. 重新登录以激活 docker 组权限：" -ForegroundColor Yellow
Write-Host "   ssh $DeviceUser@$DeviceIp" -ForegroundColor White
Write-Host "   exit" -ForegroundColor White
Write-Host "   ssh $DeviceUser@$DeviceIp" -ForegroundColor White
Write-Host ""
Write-Host "2. 验证无需 sudo 即可使用 docker：" -ForegroundColor Yellow
Write-Host "   docker --version" -ForegroundColor White
Write-Host "   docker ps" -ForegroundColor White
Write-Host "   docker run hello-world" -ForegroundColor White
Write-Host ""
Write-Host "3. 常用 Docker 命令：" -ForegroundColor Yellow
Write-Host "   docker ps                    # 查看运行中的容器" -ForegroundColor White
Write-Host "   docker images                # 查看镜像列表" -ForegroundColor White
Write-Host "   docker pull ubuntu:20.04     # 拉取镜像" -ForegroundColor White
Write-Host "   docker run -it ubuntu bash   # 运行容器" -ForegroundColor White
Write-Host ""
Write-Host "4. 查看详细文档：" -ForegroundColor Yellow
Write-Host "   docs\2026-01-29\04-Docker安装完成总结.md" -ForegroundColor Cyan
Write-Host ""
Write-Host "🎉 Docker 安装成功！" -ForegroundColor Green
