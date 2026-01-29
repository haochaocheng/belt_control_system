# UTF-8 with BOM
# Docker 安装诊断脚本
# 创建时间: 2026-01-29
# 检查 Docker 安装状态和问题

param(
    [Parameter(Mandatory=$true)]
    [string]$DeviceIp,

    [string]$DeviceUser = "linaro"
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$sshKey = "$env:USERPROFILE\.ssh\id_rsa_rk3588_185"

Write-Host "=== Docker 安装诊断 ===" -ForegroundColor Cyan
Write-Host "目标设备: $DeviceUser@$DeviceIp`n" -ForegroundColor Yellow

# 检查 SSH 连接
Write-Host "[1] 检查 SSH 连接..." -ForegroundColor Cyan
$connected = ssh -i $sshKey -o ConnectTimeout=5 "$DeviceUser@$DeviceIp" "echo 'OK'" 2>&1
if ($connected -match "OK") {
    Write-Host "  ✅ SSH 连接正常" -ForegroundColor Green
} else {
    Write-Host "  ❌ SSH 连接失败" -ForegroundColor Red
    exit 1
}

# 检查 Docker 命令
Write-Host "`n[2] 检查 Docker 命令..." -ForegroundColor Cyan
$dockerCmd = ssh -i $sshKey "$DeviceUser@$DeviceIp" "which docker 2>&1"
if ($dockerCmd -match "/usr/bin/docker") {
    Write-Host "  ✅ Docker 命令存在: $dockerCmd" -ForegroundColor Green
} else {
    Write-Host "  ❌ Docker 命令不存在" -ForegroundColor Red
    Write-Host "  输出: $dockerCmd" -ForegroundColor Gray
}

# 检查 Docker 包
Write-Host "`n[3] 检查 Docker 包安装状态..." -ForegroundColor Cyan
$packages = ssh -i $sshKey "$DeviceUser@$DeviceIp" "dpkg -l | grep docker"
if ($packages) {
    Write-Host "  已安装的 Docker 相关包：" -ForegroundColor White
    $packages -split "`n" | ForEach-Object {
        Write-Host "    $_" -ForegroundColor Gray
    }
} else {
    Write-Host "  ❌ 未找到 Docker 相关包" -ForegroundColor Red
}

# 检查 Docker 服务
Write-Host "`n[4] 检查 Docker 服务状态..." -ForegroundColor Cyan
$serviceStatus = ssh -i $sshKey "$DeviceUser@$DeviceIp" "systemctl status docker 2>&1 | head -10"
Write-Host "  服务状态：" -ForegroundColor White
$serviceStatus -split "`n" | ForEach-Object {
    Write-Host "    $_" -ForegroundColor Gray
}

# 检查 Docker APT 源
Write-Host "`n[5] 检查 Docker APT 源..." -ForegroundColor Cyan
$aptSource = ssh -i $sshKey "$DeviceUser@$DeviceIp" "cat /etc/apt/sources.list.d/docker.list 2>&1"
if ($aptSource -match "docker") {
    Write-Host "  ✅ Docker APT 源已配置" -ForegroundColor Green
    Write-Host "  内容: $aptSource" -ForegroundColor Gray
} else {
    Write-Host "  ❌ Docker APT 源未配置" -ForegroundColor Red
}

# 检查 GPG 密钥
Write-Host "`n[6] 检查 Docker GPG 密钥..." -ForegroundColor Cyan
$gpgKey = ssh -i $sshKey "$DeviceUser@$DeviceIp" "ls -lh /etc/apt/keyrings/docker.gpg 2>&1"
if ($gpgKey -match "docker.gpg") {
    Write-Host "  ✅ GPG 密钥存在" -ForegroundColor Green
    Write-Host "  $gpgKey" -ForegroundColor Gray
} else {
    Write-Host "  ❌ GPG 密钥不存在" -ForegroundColor Red
}

# 检查网络连接
Write-Host "`n[7] 检查网络连接..." -ForegroundColor Cyan
$mirrors = @{
    "阿里云" = "https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg"
    "清华" = "https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu/gpg"
    "Docker官方" = "https://download.docker.com/linux/ubuntu/gpg"
}

foreach ($mirror in $mirrors.GetEnumerator()) {
    $test = ssh -i $sshKey "$DeviceUser@$DeviceIp" "curl -I -s --connect-timeout 3 $($mirror.Value) 2>&1 | head -1"
    if ($test -match "200|301|302") {
        Write-Host "  ✅ $($mirror.Key): 可访问" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $($mirror.Key): 无法访问" -ForegroundColor Red
        Write-Host "     响应: $test" -ForegroundColor Gray
    }
}

# 检查用户组
Write-Host "`n[8] 检查用户组..." -ForegroundColor Cyan
$groups = ssh -i $sshKey "$DeviceUser@$DeviceIp" "groups"
if ($groups -match "docker") {
    Write-Host "  ✅ 用户在 docker 组中" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  用户不在 docker 组中" -ForegroundColor Yellow
}
Write-Host "  用户组: $groups" -ForegroundColor Gray

# 检查最近的 APT 日志
Write-Host "`n[9] 检查最近的 APT 安装日志..." -ForegroundColor Cyan
$aptLog = ssh -i $sshKey "$DeviceUser@$DeviceIp" "grep -i docker /var/log/apt/history.log 2>&1 | tail -20"
if ($aptLog) {
    Write-Host "  最近的 Docker 相关操作：" -ForegroundColor White
    $aptLog -split "`n" | ForEach-Object {
        Write-Host "    $_" -ForegroundColor Gray
    }
} else {
    Write-Host "  未找到 Docker 相关的 APT 日志" -ForegroundColor Gray
}

# 总结和建议
Write-Host "`n=== 诊断总结 ===" -ForegroundColor Cyan
Write-Host ""

if ($dockerCmd -match "/usr/bin/docker") {
    Write-Host "✅ Docker 已安装" -ForegroundColor Green
    Write-Host ""
    Write-Host "建议操作：" -ForegroundColor Yellow
    Write-Host "1. 重新登录以激活 docker 组权限" -ForegroundColor White
    Write-Host "2. 运行: docker --version" -ForegroundColor White
} else {
    Write-Host "❌ Docker 未正确安装" -ForegroundColor Red
    Write-Host ""
    Write-Host "可能的原因：" -ForegroundColor Yellow

    if ($aptSource -notmatch "docker") {
        Write-Host "  • Docker APT 源未配置" -ForegroundColor White
    }

    if ($gpgKey -notmatch "docker.gpg") {
        Write-Host "  • GPG 密钥未添加" -ForegroundColor White
    }

    $canAccessMirror = $false
    foreach ($mirror in $mirrors.GetEnumerator()) {
        $test = ssh -i $sshKey "$DeviceUser@$DeviceIp" "curl -I -s --connect-timeout 3 $($mirror.Value) 2>&1 | head -1"
        if ($test -match "200|301|302") {
            $canAccessMirror = $true
            break
        }
    }

    if (-not $canAccessMirror) {
        Write-Host "  • 无法访问任何镜像源（网络问题）" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "建议解决方案：" -ForegroundColor Yellow

    if ($canAccessMirror) {
        Write-Host "1. 重新运行安装脚本（详细版本）：" -ForegroundColor White
        Write-Host "   .\scripts\2026-01-29\07-install-docker-verbose.ps1 $DeviceIp" -ForegroundColor Cyan
    } else {
        Write-Host "1. 检查设备网络连接" -ForegroundColor White
        Write-Host "2. 配置 HTTP 代理（如果有）" -ForegroundColor White
        Write-Host "3. 使用完全离线安装方法" -ForegroundColor White
        Write-Host "   参考: docs\2026-01-29\03-Docker安装网络问题解决方案.md" -ForegroundColor Cyan
    }
}

Write-Host ""
