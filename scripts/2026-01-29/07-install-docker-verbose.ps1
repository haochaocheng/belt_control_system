# UTF-8 with BOM
# Docker 安装脚本 - 使用国内镜像源（详细版本）
# 创建时间: 2026-01-29
# 显示完整的安装过程和错误信息

param(
    [Parameter(Mandatory=$true)]
    [string]$DeviceIp,

    [string]$DeviceUser = "linaro",

    [ValidateSet("aliyun", "tsinghua", "ustc")]
    [string]$Mirror = "aliyun"
)

$ErrorActionPreference = "Continue"
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

Write-Host "=== Docker 安装（国内镜像源 - 详细版本） ===" -ForegroundColor Cyan
Write-Host "目标设备: $DeviceUser@$DeviceIp" -ForegroundColor Yellow
Write-Host "镜像源: $($selectedMirror.name)`n" -ForegroundColor Yellow

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

# 步骤 3: 检查网络连接
Write-Host "`n[3/9] 检查网络连接..." -ForegroundColor Cyan
$networkTest = ssh -i $sshKey "$DeviceUser@$DeviceIp" "curl -I -s --connect-timeout 5 $($selectedMirror.gpg) | head -1"
if ($networkTest -match "200|301|302") {
    Write-Host "  ✅ 可以访问镜像源" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  无法访问镜像源，可能会安装失败" -ForegroundColor Yellow
    Write-Host "  响应: $networkTest" -ForegroundColor Gray
}

# 步骤 4: 更新系统包
Write-Host "`n[4/9] 更新系统包..." -ForegroundColor Cyan
ssh -i $sshKey "$DeviceUser@$DeviceIp" "sudo apt update"
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✅ 系统包更新完成" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  系统包更新有警告" -ForegroundColor Yellow
}

# 步骤 5: 安装依赖
Write-Host "`n[5/9] 安装必要的依赖..." -ForegroundColor Cyan
ssh -i $sshKey "$DeviceUser@$DeviceIp" "sudo apt install -y ca-certificates curl gnupg lsb-release"
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✅ 依赖安装完成" -ForegroundColor Green
} else {
    Write-Host "  ❌ 依赖安装失败" -ForegroundColor Red
    exit 1
}

# 步骤 6: 添加 Docker GPG 密钥
Write-Host "`n[6/9] 添加 Docker GPG 密钥..." -ForegroundColor Cyan
$addGpgKey = @"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL $($selectedMirror.gpg) | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "GPG key added"
"@
$gpgResult = ssh -i $sshKey "$DeviceUser@$DeviceIp" $addGpgKey
Write-Host "  $gpgResult" -ForegroundColor Gray
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✅ GPG 密钥添加完成" -ForegroundColor Green
} else {
    Write-Host "  ❌ GPG 密钥添加失败" -ForegroundColor Red
    exit 1
}

# 步骤 7: 添加 Docker APT 源
Write-Host "`n[7/9] 配置 Docker APT 源..." -ForegroundColor Cyan
$addRepo = @"
echo \"deb [arch=`$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] $($selectedMirror.repo) `$(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt update
"@
ssh -i $sshKey "$DeviceUser@$DeviceIp" $addRepo
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✅ Docker APT 源配置完成" -ForegroundColor Green
} else {
    Write-Host "  ❌ Docker APT 源配置失败" -ForegroundColor Red
    exit 1
}

# 步骤 8: 安装 Docker Engine
Write-Host "`n[8/9] 安装 Docker Engine..." -ForegroundColor Cyan
Write-Host "  这可能需要几分钟，请耐心等待..." -ForegroundColor Yellow
Write-Host "  正在安装..." -ForegroundColor Gray
ssh -i $sshKey "$DeviceUser@$DeviceIp" "sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✅ Docker Engine 安装完成" -ForegroundColor Green
} else {
    Write-Host "  ❌ Docker Engine 安装失败" -ForegroundColor Red
    Write-Host "`n  请检查上面的错误信息" -ForegroundColor Yellow
    exit 1
}

# 步骤 9: 启动 Docker 服务
Write-Host "`n[9/9] 启动 Docker 服务..." -ForegroundColor Cyan
$startDocker = @"
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $DeviceUser
echo "Docker service started"
"@
$startResult = ssh -i $sshKey "$DeviceUser@$DeviceIp" $startDocker
Write-Host "  $startResult" -ForegroundColor Gray
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✅ Docker 服务已启动" -ForegroundColor Green
} else {
    Write-Host "  ❌ Docker 服务启动失败" -ForegroundColor Red
    exit 1
}

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
    Write-Host "  ⚠️  Docker 测试失败" -ForegroundColor Yellow
    Write-Host "  输出: $helloWorld" -ForegroundColor Gray
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
Write-Host "3. 配置镜像加速（可选，提高拉取速度）：" -ForegroundColor Yellow
Write-Host "   sudo mkdir -p /etc/docker" -ForegroundColor White
Write-Host "   sudo nano /etc/docker/daemon.json" -ForegroundColor White
Write-Host ""
Write-Host "   添加以下内容：" -ForegroundColor Gray
Write-Host '   {' -ForegroundColor Gray
Write-Host '     "registry-mirrors": [' -ForegroundColor Gray
Write-Host '       "https://docker.mirrors.ustc.edu.cn",' -ForegroundColor Gray
Write-Host '       "https://hub-mirror.c.163.com"' -ForegroundColor Gray
Write-Host '     ]' -ForegroundColor Gray
Write-Host '   }' -ForegroundColor Gray
Write-Host ""
Write-Host "   然后重启 Docker：" -ForegroundColor Gray
Write-Host "   sudo systemctl restart docker" -ForegroundColor White
Write-Host ""
Write-Host "4. 常用 Docker 命令：" -ForegroundColor Yellow
Write-Host "   docker ps                    # 查看运行中的容器" -ForegroundColor White
Write-Host "   docker images                # 查看镜像列表" -ForegroundColor White
Write-Host "   docker pull ubuntu:20.04     # 拉取镜像" -ForegroundColor White
Write-Host "   docker run -it ubuntu bash   # 运行容器" -ForegroundColor White
Write-Host ""
Write-Host "🎉 Docker 安装成功！" -ForegroundColor Green
