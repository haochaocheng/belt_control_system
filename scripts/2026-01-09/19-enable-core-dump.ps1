# ============================================================
# 启用 Core Dump 捕获
# ============================================================
#
# 用途：配置设备以捕获崩溃 Core Dump，用于调试 SIGSEGV 崩溃
# 使用：.\19-enable-core-dump.ps1 -IP "192.168.1.8" -User "pi" -Password "pi"
#
# 日期：2026-01-10 14:10
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
Write-Host "启用 Core Dump 捕获" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  IP: $IP" -ForegroundColor White
Write-Host "  User: $User" -ForegroundColor White
Write-Host ""

# ============================================================
# Step 1: 配置宿主机 Core Dump
# ============================================================
Write-Host "[1/3] 配置宿主机 Core Dump..." -ForegroundColor Green

$hostCmd = @'
# 配置 Core Dump 路径
sudo sh -c 'echo "/tmp/core.%e.%p" > /proc/sys/kernel/core_pattern'
sudo sysctl -w kernel.core_pattern=/tmp/core.%e.%p

# 验证配置
echo "Core dump pattern: $(cat /proc/sys/kernel/core_pattern)"
'@

ssh "$User@$IP" "$hostCmd"

Write-Host "  ✓ 宿主机 Core Dump 配置完成" -ForegroundColor Green
Write-Host ""

# ============================================================
# Step 2: 修改容器启动脚本
# ============================================================
Write-Host "[2/3] 修改容器启动脚本..." -ForegroundColor Green

$modifyScript = @'
# 备份原始脚本
if [ ! -f ~/run-ubuntu24-apt.sh.backup ]; then
    cp ~/run-ubuntu24-apt.sh ~/run-ubuntu24-apt.sh.backup
    echo "✓ 原始脚本已备份"
else
    echo "✓ 备份已存在，跳过"
fi

# 检查是否已经添加了 --ulimit
if grep -q "\-\-ulimit core=" ~/run-ubuntu24-apt.sh; then
    echo "✓ --ulimit core 参数已存在，跳过"
else
    # 在 --privileged 后添加 --ulimit core=-1
    sed -i 's/--privileged \\/--privileged \\\n    --ulimit core=-1 \\/' ~/run-ubuntu24-apt.sh
    echo "✓ 已添加 --ulimit core=-1 参数"
fi

# 显示修改后的相关行
echo ""
echo "修改后的启动参数："
grep -A 2 "privileged" ~/run-ubuntu24-apt.sh
'@

ssh "$User@$IP" "$modifyScript"

Write-Host "  ✓ 容器启动脚本修改完成" -ForegroundColor Green
Write-Host ""

# ============================================================
# Step 3: 清理旧 Core Dump
# ============================================================
Write-Host "[3/3] 清理旧 Core Dump 文件..." -ForegroundColor Green

$cleanCmd = @'
# 删除旧的 Core Dump 文件
OLD_CORES=$(find /tmp -name "core.*" 2>/dev/null | wc -l)
if [ "$OLD_CORES" -gt 0 ]; then
    sudo rm -f /tmp/core.*
    echo "✓ 已删除 $OLD_CORES 个旧 Core Dump 文件"
else
    echo "✓ 没有旧 Core Dump 文件"
fi
'@

ssh "$User@$IP" "$cleanCmd"

Write-Host "  ✓ 清理完成" -ForegroundColor Green
Write-Host ""

# ============================================================
# 完成
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "✓ Core Dump 捕获配置完成" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "接下来的步骤：" -ForegroundColor Yellow
Write-Host "  1. 重启容器：" -ForegroundColor White
Write-Host "     ssh $User@$IP '~/run-ubuntu24-apt.sh'" -ForegroundColor Gray
Write-Host "  2. 触发崩溃（拨打视频电话）" -ForegroundColor White
Write-Host "  3. 查找 Core Dump：" -ForegroundColor White
Write-Host "     ssh $User@$IP 'ls -lh /tmp/core.*'" -ForegroundColor Gray
Write-Host "  4. 分析 Core Dump（使用 scripts/2026-01-09/20-analyze-core-dump.ps1）" -ForegroundColor White
Write-Host ""
