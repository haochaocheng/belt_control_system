# 自动化 GitHub 同步配置脚本
# 日期: 2026-01-28
# 功能: 配置每小时自动同步到 GitHub

# UTF-8 强制配置
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  GitHub 自动同步配置" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 脚本路径
$syncScript = "E:\2025\3_gongkongji\belt_control_system\scripts\2026-01-28\01-safe-github-sync.ps1"

# 检查脚本是否存在
if (-not (Test-Path $syncScript)) {
    Write-Host "❌ 同步脚本不存在：$syncScript" -ForegroundColor Red
    Write-Host "   请先确保脚本文件存在" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ 同步脚本存在：$syncScript" -ForegroundColor Green
Write-Host ""

# 询问用户选择同步频率
Write-Host "请选择同步频率：" -ForegroundColor Cyan
Write-Host "1. 每小时同步（推荐）" -ForegroundColor White
Write-Host "2. 每天同步（凌晨 2 点）" -ForegroundColor White
Write-Host "3. 每 30 分钟同步" -ForegroundColor White
Write-Host "4. 取消配置" -ForegroundColor White
Write-Host ""

$choice = Read-Host "请输入选项 (1-4)"

switch ($choice) {
    "1" {
        # 每小时同步
        Write-Host "`n配置每小时自动同步..." -ForegroundColor Cyan

        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
            -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$syncScript`""

        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1)

        $settings = New-ScheduledTaskSettingsSet `
            -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries `
            -StartWhenAvailable `
            -RunOnlyIfNetworkAvailable

        Register-ScheduledTask -TaskName "GitHub-HourlySync" `
            -Action $action `
            -Trigger $trigger `
            -Settings $settings `
            -Description "每小时自动同步代码到 GitHub" `
            -Force | Out-Null

        Write-Host "✅ 已创建计划任务：GitHub-HourlySync" -ForegroundColor Green
        Write-Host "   同步频率：每小时" -ForegroundColor Green
        Write-Host "   下次运行：$(Get-Date -Date (Get-Date).AddHours(1) -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Green
    }

    "2" {
        # 每天同步
        Write-Host "`n配置每天自动同步..." -ForegroundColor Cyan

        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
            -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$syncScript`""

        $trigger = New-ScheduledTaskTrigger -Daily -At "02:00"

        $settings = New-ScheduledTaskSettingsSet `
            -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries `
            -StartWhenAvailable `
            -RunOnlyIfNetworkAvailable

        Register-ScheduledTask -TaskName "GitHub-DailySync" `
            -Action $action `
            -Trigger $trigger `
            -Settings $settings `
            -Description "每天凌晨 2 点自动同步代码到 GitHub" `
            -Force | Out-Null

        Write-Host "✅ 已创建计划任务：GitHub-DailySync" -ForegroundColor Green
        Write-Host "   同步频率：每天凌晨 2:00" -ForegroundColor Green
        Write-Host "   下次运行：明天 02:00:00" -ForegroundColor Green
    }

    "3" {
        # 每 30 分钟同步
        Write-Host "`n配置每 30 分钟自动同步..." -ForegroundColor Cyan

        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
            -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$syncScript`""

        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 30)

        $settings = New-ScheduledTaskSettingsSet `
            -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries `
            -StartWhenAvailable `
            -RunOnlyIfNetworkAvailable

        Register-ScheduledTask -TaskName "GitHub-HalfHourlySync" `
            -Action $action `
            -Trigger $trigger `
            -Settings $settings `
            -Description "每 30 分钟自动同步代码到 GitHub" `
            -Force | Out-Null

        Write-Host "✅ 已创建计划任务：GitHub-HalfHourlySync" -ForegroundColor Green
        Write-Host "   同步频率：每 30 分钟" -ForegroundColor Green
        Write-Host "   下次运行：$(Get-Date -Date (Get-Date).AddMinutes(30) -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Green
    }

    "4" {
        Write-Host "`n已取消配置" -ForegroundColor Yellow
        exit 0
    }

    default {
        Write-Host "`n❌ 无效的选项" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  配置完成" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 显示管理命令
Write-Host "管理命令：" -ForegroundColor Cyan
Write-Host ""
Write-Host "查看任务：" -ForegroundColor Yellow
Write-Host "  Get-ScheduledTask | Where-Object {`$_.TaskName -like '*GitHub*'}" -ForegroundColor White
Write-Host ""
Write-Host "手动运行任务：" -ForegroundColor Yellow
Write-Host "  Start-ScheduledTask -TaskName 'GitHub-HourlySync'" -ForegroundColor White
Write-Host ""
Write-Host "禁用任务：" -ForegroundColor Yellow
Write-Host "  Disable-ScheduledTask -TaskName 'GitHub-HourlySync'" -ForegroundColor White
Write-Host ""
Write-Host "启用任务：" -ForegroundColor Yellow
Write-Host "  Enable-ScheduledTask -TaskName 'GitHub-HourlySync'" -ForegroundColor White
Write-Host ""
Write-Host "删除任务：" -ForegroundColor Yellow
Write-Host "  Unregister-ScheduledTask -TaskName 'GitHub-HourlySync' -Confirm:`$false" -ForegroundColor White
Write-Host ""

# 询问是否立即测试
Write-Host "是否立即测试同步？(yes/no)" -ForegroundColor Cyan
$test = Read-Host

if ($test -eq "yes") {
    Write-Host "`n正在测试同步..." -ForegroundColor Cyan
    & $syncScript
} else {
    Write-Host "`n配置完成！任务将在下次计划时间自动运行。" -ForegroundColor Green
}
