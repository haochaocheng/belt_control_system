# ✅ 2026-01-09 11:00 [调试工具] 容器内 GDB 调试脚本
# 目的：程序崩溃后，在容器内使用 GDB 定位崩溃点
# 问题：程序崩溃后容器自动停止，需要修改容器启动方式
# 方案：使用交互式容器运行 GDB

# PowerShell 7 UTF-8 强制配置
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

param(
    [string]$Device = "188"
)

# 设备配置（2026-01-09 更新）
$DeviceUser = "linaro"
$DevicePassword = "linaro"

switch -Regex ($Device) {
    "^188$" { $DeviceIP = "192.168.10.188" }
    "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$" { $DeviceIP = $Device }
    default {
        Write-Host "[错误] 无效的设备参数: $Device" -ForegroundColor Red
        Write-Host "使用方法: .\02-gdb-debug-in-container.ps1 188" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "容器内 GDB 调试" -ForegroundColor Cyan
Write-Host "目标设备: $DeviceIP" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: 检查容器是否存在
Write-Host "[1/4] 检查容器状态..." -ForegroundColor Green
$containerStatus = ssh -o StrictHostKeyChecking=no "${DeviceUser}@${DeviceIP}" "docker ps -a --filter name=belt-control-latest --format '{{.Status}}'"

if ([string]::IsNullOrEmpty($containerStatus)) {
    Write-Host "  ❌ 容器不存在，请先部署应用" -ForegroundColor Red
    exit 1
}

Write-Host "  容器状态: $containerStatus" -ForegroundColor Gray

# Step 2: 安装 GDB（如果需要）
Write-Host ""
Write-Host "[2/4] 检查并安装 GDB..." -ForegroundColor Green

$checkGdb = @"
if docker exec belt-control-latest which gdb > /dev/null 2>&1; then
    echo 'GDB_INSTALLED'
else
    echo 'GDB_NOT_FOUND'
fi
"@

$gdbStatus = ssh -o StrictHostKeyChecking=no "${DeviceUser}@${DeviceIP}" $checkGdb

if ($gdbStatus -match "GDB_NOT_FOUND") {
    Write-Host "  GDB 未安装，正在安装..." -ForegroundColor Yellow

    $installGdb = @"
docker exec belt-control-latest bash -c 'apt update && apt install -y gdb'
"@

    ssh -o StrictHostKeyChecking=no "${DeviceUser}@${DeviceIP}" $installGdb

    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ❌ GDB 安装失败" -ForegroundColor Red
        exit 1
    }

    Write-Host "  ✓ GDB 安装成功" -ForegroundColor Green
} else {
    Write-Host "  ✓ GDB 已安装" -ForegroundColor Green
}

# Step 3: 启用 core dump
Write-Host ""
Write-Host "[3/4] 配置 core dump..." -ForegroundColor Green

$enableCoreDump = @"
docker exec belt-control-latest bash -c 'ulimit -c unlimited && echo "✓ Core dump enabled"'
"@

ssh -o StrictHostKeyChecking=no "${DeviceUser}@${DeviceIP}" $enableCoreDump

# Step 4: 启动 GDB 调试会话
Write-Host ""
Write-Host "[4/4] 启动 GDB 调试会话..." -ForegroundColor Green
Write-Host ""
Write-Host "===============================================" -ForegroundColor Yellow
Write-Host "GDB 使用指南" -ForegroundColor Yellow
Write-Host "===============================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "常用命令:" -ForegroundColor Cyan
Write-Host "  run                运行程序" -ForegroundColor White
Write-Host "  bt                 查看堆栈（崩溃后）" -ForegroundColor White
Write-Host "  frame 0            切换到栈顶帧" -ForegroundColor White
Write-Host "  info locals        查看局部变量" -ForegroundColor White
Write-Host "  p variable         打印变量值" -ForegroundColor White
Write-Host "  list               查看源码（需要源文件）" -ForegroundColor White
Write-Host "  quit               退出 GDB" -ForegroundColor White
Write-Host ""
Write-Host "崩溃分析步骤:" -ForegroundColor Cyan
Write-Host "  1. (gdb) run                   # 运行程序" -ForegroundColor White
Write-Host "  2. [等待程序崩溃]" -ForegroundColor Gray
Write-Host "  3. (gdb) bt                    # 查看堆栈" -ForegroundColor White
Write-Host "  4. (gdb) frame 0               # 切换到崩溃位置" -ForegroundColor White
Write-Host "  5. (gdb) info locals           # 查看变量" -ForegroundColor White
Write-Host "  6. (gdb) p avframe             # 检查关键变量" -ForegroundColor White
Write-Host ""
Write-Host "===============================================" -ForegroundColor Yellow
Write-Host "按 Enter 键启动 GDB..." -ForegroundColor Yellow
Write-Host "===============================================" -ForegroundColor Yellow
Read-Host

# 启动 GDB
$gdbCommand = @"
docker exec -it belt-control-latest gdb /app/belt_control_system
"@

ssh -t -o StrictHostKeyChecking=no "${DeviceUser}@${DeviceIP}" $gdbCommand

Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host "GDB 会话结束" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
