# GitLab 修改 root 密码脚本
# 日期: 2026-01-28
# 功能: 通过命令行修改 GitLab root 用户密码

# UTF-8 强制配置
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  GitLab 修改 root 密码" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 提示用户输入新密码
$newPassword = Read-Host "请输入新密码（至少 8 个字符）" -AsSecureString
$confirmPassword = Read-Host "请再次输入新密码确认" -AsSecureString

# 转换为明文进行比较
$newPasswordText = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($newPassword))
$confirmPasswordText = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($confirmPassword))

if ($newPasswordText -ne $confirmPasswordText) {
    Write-Host "❌ 两次输入的密码不一致！" -ForegroundColor Red
    exit 1
}

if ($newPasswordText.Length -lt 8) {
    Write-Host "❌ 密码长度必须至少 8 个字符！" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "正在修改密码..." -ForegroundColor Yellow

# 使用 GitLab Rails Console 修改密码
$command = @"
user = User.find_by(username: 'root')
user.password = '$newPasswordText'
user.password_confirmation = '$newPasswordText'
user.save!
puts 'Password changed successfully!'
"@

try {
    docker exec gitlab gitlab-rails runner "$command"

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ 密码修改成功！" -ForegroundColor Green
        Write-Host ""
        Write-Host "新的登录信息：" -ForegroundColor Cyan
        Write-Host "  用户名: root" -ForegroundColor White
        Write-Host "  密码: [您刚才设置的密码]" -ForegroundColor White
        Write-Host ""
        Write-Host "请使用新密码重新登录：http://localhost:8080" -ForegroundColor Cyan
    } else {
        Write-Host "❌ 密码修改失败" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ 密码修改失败：$($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
