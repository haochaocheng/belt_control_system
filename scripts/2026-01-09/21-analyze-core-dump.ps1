# ============================================================
# 分析 Core Dump 崩溃堆栈
# ============================================================
#
# 用途：在容器崩溃后分析 Core Dump 文件
# 使用：.\21-analyze-core-dump.ps1 -IP "192.168.1.8" -User "pi"
#
# 前提：使用 start-with-coredump-v2.sh 启动容器
#       Core Dump 保存在 /tmp/belt-control-cores/
#
# 日期：2026-01-10 15:00
# ============================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$IP,

    [Parameter(Mandatory=$false)]
    [string]$User = "pi",

    [Parameter(Mandatory=$false)]
    [string]$Password = "pi"
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Core Dump 崩溃堆栈分析" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  IP: $IP" -ForegroundColor White
Write-Host "  User: $User" -ForegroundColor White
Write-Host ""

# ============================================================
# Step 1: 查找 Core Dump 文件
# ============================================================
Write-Host "[1/4] 查找 Core Dump 文件..." -ForegroundColor Green

$findCmd = @'
# 查找最新的 Core Dump
LATEST_CORE=$(ls -t /tmp/belt-control-cores/core.* 2>/dev/null | head -1)

if [ -z "$LATEST_CORE" ]; then
    echo "❌ 没有找到 Core Dump 文件"
    echo "   请确认："
    echo "   1. 程序已崩溃（exit code 139）"
    echo "   2. 使用 start-with-coredump-v2.sh 启动容器"
    echo "   3. ulimit -c unlimited 已设置"
    exit 1
fi

echo "✓ 找到 Core Dump: $LATEST_CORE"
ls -lh "$LATEST_CORE"
echo "$LATEST_CORE"
'@

$coreFile = ssh "$User@$IP" "$findCmd" 2>&1 | Select-Object -Last 1

if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ 未找到 Core Dump 文件" -ForegroundColor Red
    exit 1
}

Write-Host "  ✓ Core Dump: $coreFile" -ForegroundColor Green
Write-Host ""

# ============================================================
# Step 2: 启动 GDB 分析容器
# ============================================================
Write-Host "[2/4] 启动 GDB 分析容器..." -ForegroundColor Green

$gdbCmd = @"
# 停止旧的 GDB 容器
docker rm -f gdb-analyzer 2>/dev/null

# 启动 GDB 容器（挂载 Core Dump 目录和镜像）
docker run --rm -it \\
    --name gdb-analyzer \\
    -v /tmp/belt-control-cores:/cores:ro \\
    belt-control:v3.5-apt \\
    gdb /app/belt_control_system /cores/\$(basename $coreFile)
"@

Write-Host "  运行命令：" -ForegroundColor Gray
Write-Host "    docker run --rm -it belt-control:v3.5-apt gdb /app/belt_control_system /cores/..." -ForegroundColor Gray
Write-Host ""
Write-Host "  GDB 命令提示：" -ForegroundColor Yellow
Write-Host "    bt         - 显示崩溃堆栈" -ForegroundColor White
Write-Host "    bt full    - 显示完整堆栈（包含变量）" -ForegroundColor White
Write-Host "    info registers - 显示寄存器状态" -ForegroundColor White
Write-Host "    frame N    - 切换到第 N 帧" -ForegroundColor White
Write-Host "    info locals - 显示局部变量" -ForegroundColor White
Write-Host "    quit       - 退出 GDB" -ForegroundColor White
Write-Host ""
Write-Host "  按 Enter 开始..." -ForegroundColor Yellow
Read-Host

ssh -t "$User@$IP" "$gdbCmd"

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "✓ GDB 分析完成" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
