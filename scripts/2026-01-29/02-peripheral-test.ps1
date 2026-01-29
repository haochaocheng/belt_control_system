# UTF-8 with BOM
# RK3588 工控机外设测试脚本
# 创建时间: 2026-01-29
# 设备: 192.168.10.185

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$deviceIp = "192.168.10.185"
$deviceUser = "linaro"
$sshKey = "$env:USERPROFILE\.ssh\id_rsa_rk3588_185"

Write-Host "=== RK3588 工控机外设测试 ===" -ForegroundColor Cyan
Write-Host "设备: $deviceUser@$deviceIp`n" -ForegroundColor Yellow

# 步骤 1: 设置 SSH 免密登录
Write-Host "[步骤 1] 设置 SSH 免密登录..." -ForegroundColor Cyan
$publicKey = Get-Content "$sshKey.pub" -Raw

$setupKeyScript = @"
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo '$publicKey' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
sort -u ~/.ssh/authorized_keys -o ~/.ssh/authorized_keys
echo 'SSH key setup completed'
"@

try {
    $result = $setupKeyScript | ssh -o StrictHostKeyChecking=no "$deviceUser@$deviceIp" "bash -s" 2>&1
    Write-Host "✅ SSH 免密登录设置完成" -ForegroundColor Green
} catch {
    Write-Host "⚠ SSH 密钥设置可能需要手动输入密码" -ForegroundColor Yellow
}

# 步骤 2: 收集系统信息
Write-Host "`n[步骤 2] 收集系统基本信息..." -ForegroundColor Cyan

$testScript = @'
#!/bin/bash
echo "=== 系统基本信息 ==="
echo "内核版本:"
uname -a
echo ""
echo "操作系统:"
cat /etc/os-release | grep -E "PRETTY_NAME|VERSION"
echo ""
echo "CPU 信息:"
lscpu | grep -E "Architecture|Model name|CPU\(s\)"
echo ""

echo "=== CAN 总线检测 ==="
echo "CAN 内核模块:"
lsmod | grep can || echo "未加载 CAN 模块"
echo ""
echo "CAN 网络接口:"
ip link show | grep can || echo "未找到 CAN 接口"
echo ""
echo "CAN 设备节点:"
ls -l /dev/can* 2>/dev/null || echo "未找到 /dev/can* 设备节点"
echo ""
echo "检查 SocketCAN 支持:"
ls -l /sys/class/net/ | grep can || echo "未找到 CAN 网络设备"
echo ""

echo "=== 串口 (COM) 检测 ==="
echo "串口设备:"
ls -l /dev/ttyS* /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || echo "未找到串口设备"
echo ""
echo "串口详细信息:"
dmesg | grep -i "tty\|serial\|uart" | tail -20
echo ""

echo "=== GPIO 检测 ==="
echo "GPIO 控制器:"
ls -l /sys/class/gpio/ 2>/dev/null || echo "未找到 GPIO 控制器"
echo ""
echo "GPIO 芯片:"
ls -l /dev/gpiochip* 2>/dev/null || echo "未找到 GPIO 芯片设备"
echo ""
echo "GPIO 工具检查:"
which gpiodetect gpioinfo 2>/dev/null || echo "未安装 libgpiod 工具"
echo ""
if command -v gpiodetect &> /dev/null; then
    echo "GPIO 芯片列表:"
    gpiodetect
    echo ""
fi
if command -v gpioinfo &> /dev/null; then
    echo "GPIO 引脚信息:"
    gpioinfo | head -50
    echo ""
fi

echo "=== 设备树信息 ==="
echo "设备树兼容性:"
cat /proc/device-tree/compatible 2>/dev/null || echo "无法读取设备树"
echo ""
echo "设备树 CAN 节点:"
find /proc/device-tree -name "*can*" 2>/dev/null || echo "未找到 CAN 设备树节点"
echo ""

echo "=== 内核配置检查 ==="
echo "CAN 相关配置:"
zcat /proc/config.gz 2>/dev/null | grep -E "CONFIG_CAN|CONFIG_SERIAL|CONFIG_GPIO" || echo "无法读取内核配置"
echo ""

echo "=== 已安装的相关工具 ==="
echo "CAN 工具:"
which candump cansend canconfig ip 2>/dev/null || echo "未安装 can-utils"
echo ""
echo "串口工具:"
which minicom screen setserial 2>/dev/null || echo "未安装串口工具"
echo ""
echo "GPIO 工具:"
which gpiodetect gpioinfo gpioget gpioset 2>/dev/null || echo "未安装 libgpiod-tools"
echo ""

echo "=== 测试完成 ==="
'@

Write-Host "正在执行外设检测..." -ForegroundColor Yellow
$testResult = $testScript | ssh -i $sshKey "$deviceUser@$deviceIp" "bash -s"

# 保存测试结果
$outputDir = "e:\2025\3_gongkongji\belt_control_system\docs\2026-01-29"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$outputFile = Join-Path $outputDir "peripheral-test-raw-output.txt"
$testResult | Out-File -FilePath $outputFile -Encoding UTF8

Write-Host "`n✅ 测试完成！" -ForegroundColor Green
Write-Host "原始输出已保存到: $outputFile" -ForegroundColor Cyan
Write-Host "`n测试结果预览:" -ForegroundColor Yellow
Write-Host $testResult

Write-Host "`n下一步: 分析测试结果并生成报告..." -ForegroundColor Cyan
