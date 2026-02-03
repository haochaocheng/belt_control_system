# UTF-8 BOM
# 设置Qt Virtual Keyboard环境变量
# 用途：让Qt Design Studio的qmlpuppet能够使用Qt官方虚拟键盘

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "设置Qt Virtual Keyboard环境变量" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 检查当前环境变量
$currentValue = [System.Environment]::GetEnvironmentVariable("QT_IM_MODULE", "User")
Write-Host "当前用户环境变量 QT_IM_MODULE: $currentValue" -ForegroundColor Yellow
Write-Host ""

# 设置用户环境变量
Write-Host "正在设置用户环境变量..." -ForegroundColor Green
[System.Environment]::SetEnvironmentVariable("QT_IM_MODULE", "qtvirtualkeyboard", "User")

# 验证设置
$newValue = [System.Environment]::GetEnvironmentVariable("QT_IM_MODULE", "User")
Write-Host "新的用户环境变量 QT_IM_MODULE: $newValue" -ForegroundColor Green
Write-Host ""

if ($newValue -eq "qtvirtualkeyboard") {
    Write-Host "Success! Environment variable set successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Close Qt Design Studio (if running)" -ForegroundColor Yellow
    Write-Host "2. Reopen Qt Design Studio" -ForegroundColor Yellow
    Write-Host "3. Run QML Runtime" -ForegroundColor Yellow
    Write-Host "4. Test virtual keyboard" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Expected result:" -ForegroundColor Cyan
    Write-Host "- Qt.inputMethod.visible should be true" -ForegroundColor Yellow
    Write-Host "- virtualKeyboard.active should be true" -ForegroundColor Yellow
    Write-Host "- Virtual keyboard should appear" -ForegroundColor Yellow
} else {
    Write-Host "Failed to set environment variable!" -ForegroundColor Red
}

Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
