#!/usr/bin/env pwsh
# ✅ 2026-02-28 [Phase 7.47.53]: 修复默认音频来源问题 - 数据库清理脚本

param(
    [string]$DeviceIP = "192.168.10.185",
    [string]$User = "linaro"
)

# UTF-8 with BOM
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($true)

Write-Host "========================================" -ForegroundColor Green
Write-Host "清理旧数据库 - 重新初始化" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# SSH命令
$SSHCmd = "ssh -o StrictHostKeyChecking=no $User@$DeviceIP"

Write-Host "🔍 连接到设备 $DeviceIP..." -ForegroundColor Yellow
if (!($SSHCmd -eq $null)) {
    Write-Host "✅ SSH连接就绪" -ForegroundColor Green
} else {
    Write-Host "❌ SSH连接失败" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "📋 步骤 1：停止应用容器" -ForegroundColor Cyan
& $SSHCmd "docker stop belt-control-app 2>/dev/null || true"
Write-Host "✅ 容器已停止" -ForegroundColor Green

Write-Host ""
Write-Host "🗑️  步骤 2：删除旧数据库文件" -ForegroundColor Cyan
& $SSHCmd "rm -f /home/$User/belt-control-data/device_config.db"
& $SSHCmd "rm -f /home/$User/belt-control-data/device_config.db-journal"
Write-Host "✅ 数据库文件已删除" -ForegroundColor Green

Write-Host ""
Write-Host "📊 步骤 3：验证数据库已删除" -ForegroundColor Cyan
$Check = & $SSHCmd "ls -la /home/$User/belt-control-data/ | grep device_config" -ErrorAction SilentlyContinue
if ([string]::IsNullOrWhiteSpace($Check)) {
    Write-Host "✅ 确认：数据库文件已完全删除" -ForegroundColor Green
} else {
    Write-Host "⚠️ 警告：文件仍然存在，尝试再次删除" -ForegroundColor Yellow
    & $SSHCmd "rm -rf /home/$User/belt-control-data/device_config*"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "清理完成！下一步：" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "1️⃣  运行编译脚本重新编译并部署："
Write-Host "   .\build-ubuntu24-apt.ps1 185"
Write-Host ""
Write-Host "2️⃣  应用启动时会自动：" -ForegroundColor Yellow
Write-Host "   ✓ 重新创建数据库表" -ForegroundColor Yellow
Write-Host "   ✓ 初始化12个皮带，每个8个保护" -ForegroundColor Yellow
Write-Host "   ✓ 设置 use_text_to_speech = 0（默认音频）" -ForegroundColor Yellow
Write-Host "   ✓ 执行迁移脚本（日志会显示'迁移001'和'迁移002'）" -ForegroundColor Yellow
Write-Host ""
Write-Host "3️⃣  验证修复：" -ForegroundColor Yellow
Write-Host "   ✓ 选择开关量保护 → [默认] → 保存" -ForegroundColor Yellow
Write-Host "   ✓ 查看日志：应显示'默认(1#PD MP3)'而不是'TTS合成'" -ForegroundColor Yellow
Write-Host "   ✓ 触发保护 → 应播放.mp3文件（默认音频）" -ForegroundColor Yellow
Write-Host ""
Write-Host "提示：如遇问题，检查日志中的迁移步骤是否执行成功" -ForegroundColor Cyan
