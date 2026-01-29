# UTF-8 with BOM
# 设置 SSH 免密登录到 RK3588 设备 (192.168.10.185)
# 创建时间: 2026-01-29

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$deviceIp = "192.168.10.185"
$deviceUser = "linaro"
$devicePassword = "linaro"
$publicKeyPath = "$env:USERPROFILE\.ssh\id_rsa_rk3588_185.pub"

Write-Host "=== 设置 SSH 免密登录 ===" -ForegroundColor Cyan
Write-Host "目标设备: $deviceUser@$deviceIp" -ForegroundColor Yellow

# 读取公钥内容
if (-not (Test-Path $publicKeyPath)) {
    Write-Host "错误: 公钥文件不存在: $publicKeyPath" -ForegroundColor Red
    exit 1
}

$publicKey = Get-Content $publicKeyPath -Raw
Write-Host "公钥内容已读取" -ForegroundColor Green

# 使用 plink 复制公钥到设备
Write-Host "`n正在将公钥复制到设备..." -ForegroundColor Yellow

# 创建临时脚本
$tempScript = @"
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo '$publicKey' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
echo 'SSH key added successfully'
"@

# 使用 ssh 命令（需要手动输入密码）
Write-Host "请输入设备密码: $devicePassword" -ForegroundColor Yellow
$tempScript | ssh "$deviceUser@$deviceIp" "bash -s"

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ SSH 免密登录设置成功！" -ForegroundColor Green
    Write-Host "现在可以使用以下命令免密登录:" -ForegroundColor Cyan
    Write-Host "  ssh -i ~/.ssh/id_rsa_rk3588_185 $deviceUser@$deviceIp" -ForegroundColor White
} else {
    Write-Host "`n❌ SSH 免密登录设置失败" -ForegroundColor Red
    exit 1
}
