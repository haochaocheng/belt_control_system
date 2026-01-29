# UTF-8 with BOM
# SSH 连接问题诊断和修复脚本
# 创建时间: 2026-01-29

param(
    [Parameter(Mandatory=$true)]
    [string]$DeviceIp
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "=== SSH 连接问题诊断 ===" -ForegroundColor Cyan
Write-Host "目标设备: $DeviceIp`n" -ForegroundColor Yellow

# 步骤 1: 测试网络连接
Write-Host "[1] 测试网络连接..." -ForegroundColor Cyan
$pingResult = Test-Connection -ComputerName $DeviceIp -Count 3 -Quiet
if ($pingResult) {
    Write-Host "  ✅ 网络连接正常" -ForegroundColor Green
} else {
    Write-Host "  ❌ 网络连接失败" -ForegroundColor Red
    Write-Host "  请检查：" -ForegroundColor Yellow
    Write-Host "    1. 设备是否开机" -ForegroundColor White
    Write-Host "    2. 网络线是否连接" -ForegroundColor White
    Write-Host "    3. IP 地址是否正确" -ForegroundColor White
    exit 1
}

# 步骤 2: 测试 SSH 端口
Write-Host "`n[2] 测试 SSH 端口 (22)..." -ForegroundColor Cyan
$tcpClient = New-Object System.Net.Sockets.TcpClient
try {
    $tcpClient.Connect($DeviceIp, 22)
    $tcpClient.Close()
    Write-Host "  ✅ SSH 端口 22 可访问" -ForegroundColor Green
} catch {
    Write-Host "  ❌ SSH 端口 22 无法访问" -ForegroundColor Red
    Write-Host "  可能原因：" -ForegroundColor Yellow
    Write-Host "    1. SSH 服务未运行" -ForegroundColor White
    Write-Host "    2. 防火墙阻止了连接" -ForegroundColor White
    Write-Host "    3. SSH 服务配置错误" -ForegroundColor White
    Write-Host ""
    Write-Host "  建议操作：" -ForegroundColor Yellow
    Write-Host "    1. 物理访问设备（连接显示器和键盘）" -ForegroundColor White
    Write-Host "    2. 登录设备" -ForegroundColor White
    Write-Host "    3. 检查 SSH 服务状态：sudo systemctl status sshd" -ForegroundColor White
    Write-Host "    4. 启动 SSH 服务：sudo systemctl start sshd" -ForegroundColor White
    Write-Host "    5. 设置开机自启：sudo systemctl enable sshd" -ForegroundColor White
    exit 1
}

# 步骤 3: 测试 SSH 连接
Write-Host "`n[3] 测试 SSH 连接..." -ForegroundColor Cyan
$sshTest = ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no linaro@$DeviceIp "echo 'OK'" 2>&1
if ($sshTest -match "OK") {
    Write-Host "  ✅ SSH 连接成功" -ForegroundColor Green
} else {
    Write-Host "  ❌ SSH 连接失败" -ForegroundColor Red
    Write-Host "  错误信息：" -ForegroundColor Yellow
    Write-Host "    $sshTest" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  可能原因：" -ForegroundColor Yellow
    Write-Host "    1. SSH 密钥认证失败" -ForegroundColor White
    Write-Host "    2. 用户名或密码错误" -ForegroundColor White
    Write-Host "    3. SSH 服务配置问题" -ForegroundColor White
}

# 步骤 4: 检查 SSH 密钥
Write-Host "`n[4] 检查 SSH 密钥..." -ForegroundColor Cyan
$sshKeys = @(
    "$env:USERPROFILE\.ssh\id_rsa",
    "$env:USERPROFILE\.ssh\id_rsa_rk3588_185"
)

foreach ($key in $sshKeys) {
    if (Test-Path $key) {
        Write-Host "  ✅ 找到密钥: $key" -ForegroundColor Green

        # 测试使用此密钥连接
        $keyTest = ssh -i $key -o ConnectTimeout=5 -o StrictHostKeyChecking=no linaro@$DeviceIp "echo 'OK'" 2>&1
        if ($keyTest -match "OK") {
            Write-Host "    ✅ 此密钥可以连接" -ForegroundColor Green
        } else {
            Write-Host "    ❌ 此密钥无法连接" -ForegroundColor Red
        }
    }
}

Write-Host "`n=== 诊断完成 ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "如果 SSH 端口无法访问，请按以下步骤操作：" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. 物理访问设备（连接显示器和键盘）" -ForegroundColor White
Write-Host ""
Write-Host "2. 登录设备（用户名: linaro，密码: linaro）" -ForegroundColor White
Write-Host ""
Write-Host "3. 检查 SSH 服务状态：" -ForegroundColor White
Write-Host "   sudo systemctl status sshd" -ForegroundColor Cyan
Write-Host "   sudo systemctl status ssh" -ForegroundColor Cyan
Write-Host ""
Write-Host "4. 启动 SSH 服务：" -ForegroundColor White
Write-Host "   sudo systemctl start sshd" -ForegroundColor Cyan
Write-Host "   或" -ForegroundColor Gray
Write-Host "   sudo systemctl start ssh" -ForegroundColor Cyan
Write-Host ""
Write-Host "5. 设置开机自启：" -ForegroundColor White
Write-Host "   sudo systemctl enable sshd" -ForegroundColor Cyan
Write-Host "   或" -ForegroundColor Gray
Write-Host "   sudo systemctl enable ssh" -ForegroundColor Cyan
Write-Host ""
Write-Host "6. 检查防火墙：" -ForegroundColor White
Write-Host "   sudo ufw status" -ForegroundColor Cyan
Write-Host "   sudo ufw allow 22/tcp" -ForegroundColor Cyan
Write-Host ""
Write-Host "7. 重启网络服务：" -ForegroundColor White
Write-Host "   sudo systemctl restart networking" -ForegroundColor Cyan
Write-Host ""
