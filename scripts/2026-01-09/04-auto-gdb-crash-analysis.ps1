# ✅ 2026-01-09 11:30 [自动调试] GDB 自动崩溃分析
# 目的：自动运行程序，捕获崩溃堆栈，无需人工交互
# 输出：崩溃位置、堆栈信息、变量值

# PowerShell 7 UTF-8 强制配置
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

param(
    [string]$Device = "188"
)

$ProjectRoot = $PSScriptRoot | Split-Path | Split-Path

# 设备配置
$DeviceUser = "linaro"

switch -Regex ($Device) {
    "^188$" { $DeviceIP = "192.168.10.188" }
    "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$" { $DeviceIP = $Device }
    default {
        Write-Host "[错误] 无效的设备参数: $Device" -ForegroundColor Red
        exit 1
    }
}

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "GDB 自动崩溃分析" -ForegroundColor Cyan
Write-Host "目标设备: $DeviceIP" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: 检查容器状态
Write-Host "[1/5] 检查容器状态..." -ForegroundColor Green
# ✅ 2026-01-09 11:50 修正容器名：belt-control-latest → belt-control-app
$containerCheck = ssh -o StrictHostKeyChecking=no "$DeviceUser@$DeviceIP" "docker ps -a --filter name=belt-control-app --format '{{.Status}}'"

if ([string]::IsNullOrEmpty($containerCheck)) {
    Write-Host "  ❌ 容器不存在" -ForegroundColor Red
    exit 1
}

Write-Host "  容器状态: $containerCheck" -ForegroundColor Gray

# Step 2: 安装 GDB
Write-Host ""
Write-Host "[2/5] 检查并安装 GDB..." -ForegroundColor Green

# ✅ 2026-01-09 11:50 修正容器名
# ✅ 2026-01-09 11:52 修正 PowerShell 重定向语法冲突
$checkGdb = 'docker exec belt-control-app which gdb'
ssh -o StrictHostKeyChecking=no "$DeviceUser@$DeviceIP" "$checkGdb" 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "  正在安装 GDB..." -ForegroundColor Gray
    $installGdb = "docker exec belt-control-app bash -c 'apt update -qq && apt install -y -qq gdb'"
    ssh -o StrictHostKeyChecking=no "$DeviceUser@$DeviceIP" "$installGdb" 2>&1 | Out-Null
    Write-Host "  ✓ GDB 安装完成" -ForegroundColor Green
} else {
    Write-Host "  ✓ GDB 已安装" -ForegroundColor Green
}

# Step 3: 创建 GDB 命令文件
Write-Host ""
Write-Host "[3/5] 准备 GDB 分析脚本..." -ForegroundColor Green

# 创建临时 GDB 命令文件
$gdbCmdFile = "$env:TEMP\gdb_commands_$Device.txt"
$gdbCommands = @"
set pagination off
set logging file /tmp/gdb_output.txt
set logging on

run

bt
frame 0
info locals
info registers

set logging off
quit
"@

$gdbCommands | Out-File -FilePath $gdbCmdFile -Encoding ASCII -NoNewline

# 上传到设备
# ✅ 2026-01-09 11:52 修正 PowerShell 重定向语法
scp -o StrictHostKeyChecking=no $gdbCmdFile "$DeviceUser@${DeviceIP}:/tmp/gdb_commands.txt" 2>&1 | Out-Null

Write-Host "  ✓ GDB 脚本已准备" -ForegroundColor Green

# Step 4: 运行 GDB
Write-Host ""
Write-Host "[4/5] 运行 GDB 分析（等待程序崩溃，约30秒）..." -ForegroundColor Green
Write-Host ""

# ✅ 2026-01-09 11:50 修正容器名
# ✅ 2026-01-09 11:52 修正 PowerShell 重定向语法冲突
$gdbRunScript = "docker exec belt-control-app bash -c 'ulimit -c unlimited && timeout 30 gdb -batch -x /tmp/gdb_commands.txt /app/belt_control_system'"

$gdbOutput = ssh -o StrictHostKeyChecking=no "$DeviceUser@$DeviceIP" "$gdbRunScript" 2>&1

# 同时获取日志文件
$gdbLogCmd = 'docker exec belt-control-app cat /tmp/gdb_output.txt'
$gdbLogOutput = ssh -o StrictHostKeyChecking=no "$DeviceUser@$DeviceIP" "$gdbLogCmd" 2>&1

# Step 5: 分析和保存结果
Write-Host ""
Write-Host "[5/5] 分析崩溃原因..." -ForegroundColor Green
Write-Host ""

# 保存输出到本地
$logDir = "$ProjectRoot\docs\log"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$gdbLogFile = "$logDir\gdb_crash_$timestamp.log"

# ✅ 2026-01-09 11:55 简化字符串拼接，避免 here-string 语法问题
$fullOutput = "===============================================`n"
$fullOutput += "GDB 实时输出`n"
$fullOutput += "===============================================`n`n"
$fullOutput += "$gdbOutput`n`n"
$fullOutput += "===============================================`n"
$fullOutput += "GDB 日志文件内容`n"
$fullOutput += "===============================================`n`n"
$fullOutput += "$gdbLogOutput`n"

$fullOutput | Out-File -FilePath $gdbLogFile -Encoding UTF8

# 显示结果
Write-Host "===============================================" -ForegroundColor Yellow
Write-Host "GDB 崩溃分析结果" -ForegroundColor Yellow
Write-Host "===============================================" -ForegroundColor Yellow
Write-Host ""

if ($gdbOutput) {
    Write-Host $gdbOutput
}

if ($gdbLogOutput) {
    Write-Host ""
    Write-Host "--- GDB 日志文件 ---" -ForegroundColor Gray
    Write-Host $gdbLogOutput
}

Write-Host ""
Write-Host "===============================================" -ForegroundColor Yellow
Write-Host ""

# 简单分析
Write-Host "📊 自动分析：" -ForegroundColor Cyan
Write-Host ""

$combinedOutput = "$gdbOutput`n$gdbLogOutput"

if ($combinedOutput -match "Segmentation fault|SIGSEGV") {
    Write-Host "  ❌ 崩溃类型: 段错误 (SIGSEGV)" -ForegroundColor Red

    if ($combinedOutput -match "#0\s+(.+)") {
        Write-Host "  📍 崩溃位置: $($matches[1])" -ForegroundColor Yellow
    }

    if ($combinedOutput -match "null pointer|Cannot access memory|0x0+\s") {
        Write-Host "  💡 可能原因: 空指针访问" -ForegroundColor Magenta
    }

    if ($combinedOutput -match "avframe") {
        Write-Host "  💡 相关变量: avframe" -ForegroundColor Magenta
    }

} elseif ($combinedOutput -match "exited normally|exited with code 0") {
    Write-Host "  ✅ 程序正常退出（未崩溃）" -ForegroundColor Green
} elseif ($combinedOutput -match "timeout|Timeout") {
    Write-Host "  ⚠ 程序运行超时（可能未崩溃）" -ForegroundColor Yellow
} else {
    Write-Host "  ⚠ 未检测到明确的崩溃信号" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host "分析完成" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""
Write-Host "详细日志已保存到:" -ForegroundColor Cyan
Write-Host "  $gdbLogFile" -ForegroundColor White
Write-Host ""

# 清理临时文件
Remove-Item -Path $gdbCmdFile -Force -ErrorAction SilentlyContinue
