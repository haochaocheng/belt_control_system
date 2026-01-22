# ========================================
# 验证组播地址计算逻辑
# ========================================
# 日期: 2026-01-22 11:00
# 目的: 验证从本地 IP 计算组播地址的逻辑是否正确
# 参考: 音频模块要求 DIP[2] = tnet->ConfigMsg.lip[2]
# ========================================

# UTF-8 with BOM 编码声明
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "组播地址计算逻辑验证" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# ========== 1. 获取本地 IP 地址 ==========
Write-Host "[1/4] 获取本地 IP 地址..." -ForegroundColor Yellow

$localIPs = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
    $_.IPAddress -notlike "127.*" -and  # 排除回环地址
    $_.IPAddress -notlike "169.254.*"   # 排除自动配置地址
}

Write-Host "   找到 $($localIPs.Count) 个 IPv4 地址：" -ForegroundColor Green

foreach ($ip in $localIPs) {
    Write-Host "   - $($ip.IPAddress) (接口: $($ip.InterfaceAlias))" -ForegroundColor Gray
}

# 优先选择 192.168.x.x 网段
$targetIP = $localIPs | Where-Object { $_.IPAddress -like "192.168.*" } | Select-Object -First 1

if (-not $targetIP) {
    # 如果没有 192.168.x.x，选择第一个非回环地址
    $targetIP = $localIPs | Select-Object -First 1
}

$localIPStr = $targetIP.IPAddress
Write-Host "`n   ✅ 选择本地 IP: $localIPStr" -ForegroundColor Green

# ========== 2. 解析 IP 地址各字节 ==========
Write-Host "`n[2/4] 解析 IP 地址各字节..." -ForegroundColor Yellow

$ipBytes = $localIPStr.Split('.')

if ($ipBytes.Count -ne 4) {
    Write-Host "   ❌ IP 地址格式错误！" -ForegroundColor Red
    exit 1
}

Write-Host "   IP 地址字节数组：" -ForegroundColor Gray
Write-Host "      IP[0] = $($ipBytes[0])" -ForegroundColor Gray
Write-Host "      IP[1] = $($ipBytes[1])" -ForegroundColor Gray
Write-Host "      IP[2] = $($ipBytes[2]) ← 用于组播地址计算" -ForegroundColor Cyan
Write-Host "      IP[3] = $($ipBytes[3])" -ForegroundColor Gray

$thirdByte = [int]$ipBytes[2]
Write-Host "`n   ✅ 第3字节（IP[2]）= $thirdByte" -ForegroundColor Green

# ========== 3. 计算组播地址 ==========
Write-Host "`n[3/4] 计算组播地址..." -ForegroundColor Yellow

$multicastAddr = "224.1.$thirdByte.1"
$multicastPort = 8800

Write-Host "   音频模块计算规则：DIP[2] = tnet->ConfigMsg.lip[2]" -ForegroundColor Gray
Write-Host "   组播地址格式：224.1.{IP[2]}.1" -ForegroundColor Gray
Write-Host "`n   ✅ 计算结果：" -ForegroundColor Green
Write-Host "      组播地址: $multicastAddr" -ForegroundColor Cyan
Write-Host "      组播端口: $multicastPort" -ForegroundColor Cyan

# ========== 4. 生成 Wireshark 过滤器 ==========
Write-Host "`n[4/4] 生成 Wireshark 过滤器..." -ForegroundColor Yellow

$wiresharkFilter = "ip.dst == $multicastAddr && udp.port == $multicastPort"

Write-Host "   ✅ Wireshark 过滤器：" -ForegroundColor Green
Write-Host "      $wiresharkFilter" -ForegroundColor Cyan

# ========== 验证总结 ==========
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "验证总结" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "✅ 本地 IP: $localIPStr" -ForegroundColor Green
Write-Host "✅ 第3字节: $thirdByte" -ForegroundColor Green
Write-Host "✅ 组播地址: $multicastAddr`:$multicastPort" -ForegroundColor Green
Write-Host "✅ Wireshark 过滤器: $wiresharkFilter" -ForegroundColor Green

# ========== 对比测试 ==========
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "对比测试" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "旧版（错误）:" -ForegroundColor Red
Write-Host "   组播地址: 224.1.1.1:8800" -ForegroundColor Red
Write-Host "   问题: 第3字节固定为 1，不匹配音频模块期望" -ForegroundColor Red

Write-Host "`n新版（正确）:" -ForegroundColor Green
Write-Host "   组播地址: $multicastAddr`:$multicastPort" -ForegroundColor Green
Write-Host "   优势: 动态计算，自动匹配音频模块期望" -ForegroundColor Green

# ========== 测试不同 IP 的计算结果 ==========
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "测试不同 IP 的计算结果" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$testIPs = @(
    "192.168.1.100",
    "192.168.10.188",
    "192.168.50.88",
    "10.0.2.15"
)

foreach ($testIP in $testIPs) {
    $testBytes = $testIP.Split('.')
    $testThirdByte = $testBytes[2]
    $testMulticast = "224.1.$testThirdByte.1"

    Write-Host "IP: $testIP → 组播地址: $testMulticast" -ForegroundColor Gray
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "✅ 验证完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
