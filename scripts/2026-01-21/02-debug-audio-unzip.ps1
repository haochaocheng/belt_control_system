#Requires -Version 7.0
<#
.SYNOPSIS
    调试音频文件解压问题
.DESCRIPTION
    测试 unzip 解压流程，找出文件丢失的原因
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$DeviceIP
)

# UTF-8 with BOM
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# 扩展 IP 地址
if ($DeviceIP -match '^\d{1,3}$') {
    $DeviceIP = "192.168.10.$DeviceIP"
}

$DeviceUser = "linaro"
$AudioSourceDir = "E:\2025\3_gongkongji\belt_control_system\AUDIO"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  音频解压调试" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: 创建测试 zip
Write-Host "[1/5] 创建测试 zip..." -ForegroundColor Yellow
$zipFilePath = Join-Path $env:TEMP "test-audio-debug.zip"
Compress-Archive -Path $AudioSourceDir -DestinationPath $zipFilePath -CompressionLevel Fastest -Force
$zipSize = [math]::Round((Get-Item $zipFilePath).Length / 1MB, 2)
Write-Host "  ✅ 测试 zip: ${zipSize} MB" -ForegroundColor Green
Write-Host ""

# Step 2: 上传到设备
Write-Host "[2/5] 上传到设备..." -ForegroundColor Yellow
$remoteZipPath = "/tmp/test-audio-debug.zip"
scp $zipFilePath "${DeviceUser}@${DeviceIP}:${remoteZipPath}"
Write-Host "  ✅ 上传完成" -ForegroundColor Green
Write-Host ""

# Step 3: 测试解压（详细模式）
Write-Host "[3/5] 测试解压..." -ForegroundColor Yellow

$debugScript = @"
#!/bin/bash
set -x  # 开启调试输出

echo "Step 1: 检查 zip 文件"
ls -lh ${remoteZipPath}

echo ""
echo "Step 2: 测试解压（不覆盖，只列出内容）"
unzip -l ${remoteZipPath} | head -20

echo ""
echo "Step 3: 创建临时测试目录"
rm -rf /tmp/audio-test
mkdir -p /tmp/audio-test

echo ""
echo "Step 4: 解压到测试目录"
unzip -q ${remoteZipPath} -d /tmp/audio-test/

echo ""
echo "Step 5: 检查解压结果"
echo "目录结构:"
ls -la /tmp/audio-test/

echo ""
echo "文件数量:"
find /tmp/audio-test -type f | wc -l

echo ""
echo "前10个文件:"
find /tmp/audio-test -type f | head -10

echo ""
echo "Step 6: 检查 AUDIO 目录"
if [ -d "/tmp/audio-test/AUDIO" ]; then
    echo "✅ AUDIO 目录存在"
    ls -la /tmp/audio-test/AUDIO/ | head -10
    echo "AUDIO 目录下的文件数:"
    find /tmp/audio-test/AUDIO -type f | wc -l
else
    echo "❌ AUDIO 目录不存在"
fi

echo ""
echo "Step 7: 清理"
rm -rf /tmp/audio-test
rm -f ${remoteZipPath}
"@

$tempScript = Join-Path $env:TEMP "debug-audio.sh"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($tempScript, $debugScript, $utf8NoBom)

scp $tempScript "${DeviceUser}@${DeviceIP}:/tmp/debug-audio.sh" | Out-Null
ssh "${DeviceUser}@${DeviceIP}" "bash /tmp/debug-audio.sh"

Remove-Item $tempScript -Force
Remove-Item $zipFilePath -Force

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ 调试完成" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
