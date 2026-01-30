# UTF-8 with BOM
# 修复Tab文件注释
# 2026-01-30

$ErrorActionPreference = "Stop"

$basePath = "e:\2025\3_gongkongji\belt_control_system\src\qml\components\device_info\pages"

$files = @(
    @{File='PhaseBWindingTab.qml'; Old='[B相绕组保护] 前轴承温度保护配置'; New='[B相绕组保护] B相绕组保护配置'},
    @{File='PhaseCWindingTab.qml'; Old='[C相绕组保护] 前轴承温度保护配置'; New='[C相绕组保护] C相绕组保护配置'},
    @{File='MotorTempTab.qml'; Old='[电机温度保护] 前轴承温度保护配置'; New='[电机温度保护] 电机温度保护配置'},
    @{File='XAxisVibrationTab.qml'; Old='[X轴振动保护] 前轴承温度保护配置'; New='[X轴振动保护] X轴振动保护配置'},
    @{File='YAxisVibrationTab.qml'; Old='[Y轴振动保护] 前轴承温度保护配置'; New='[Y轴振动保护] Y轴振动保护配置'}
)

Write-Host "开始修复注释..." -ForegroundColor Green

foreach ($f in $files) {
    $filePath = Join-Path $basePath $f.File
    $content = Get-Content $filePath -Raw -Encoding UTF8
    $content = $content -replace [regex]::Escape($f.Old), $f.New
    $content | Out-File -FilePath $filePath -Encoding UTF8 -NoNewline
    Write-Host "  ✓ 修复: $($f.File)" -ForegroundColor Green
}

Write-Host "`n所有注释修复完成!" -ForegroundColor Green
