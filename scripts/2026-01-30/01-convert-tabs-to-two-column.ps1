# UTF-8 with BOM
# 批量将Tab文件从单列布局转换为两列布局
# 2026-01-30

$ErrorActionPreference = "Stop"

# 定义文件映射
$files = @(
    @{Name='PhaseAWindingTab'; Title='A相绕组保护'; LogName='PhaseAWindingTab'},
    @{Name='PhaseBWindingTab'; Title='B相绕组保护'; LogName='PhaseBWindingTab'},
    @{Name='PhaseCWindingTab'; Title='C相绕组保护'; LogName='PhaseCWindingTab'},
    @{Name='MotorTempTab'; Title='电机温度保护'; LogName='MotorTempTab'},
    @{Name='XAxisVibrationTab'; Title='X轴振动保护'; LogName='XAxisVibrationTab'},
    @{Name='YAxisVibrationTab'; Title='Y轴振动保护'; LogName='YAxisVibrationTab'}
)

$basePath = "e:\2025\3_gongkongji\belt_control_system\src\qml\components\device_info\pages"

Write-Host "开始批量转换Tab文件为两列布局..." -ForegroundColor Green

foreach ($file in $files) {
    $filePath = Join-Path $basePath "$($file.Name).qml"
    Write-Host "处理: $($file.Name).qml ($($file.Title))..." -ForegroundColor Cyan

    # 读取模板文件(使用 FrontBearingTempTab.qml 作为模板)
    $templatePath = Join-Path $basePath "FrontBearingTempTab.qml"
    $content = Get-Content $templatePath -Raw -Encoding UTF8

    # 替换标题注释
    $content = $content -replace '\[前轴承温度保护\]', "[$($file.Title)]"

    # 替换日志中的标识符
    $content = $content -replace 'FrontBearingTempTab', $file.LogName

    # 写入文件
    $content | Out-File -FilePath $filePath -Encoding UTF8 -NoNewline

    Write-Host "  ✓ 完成: $($file.Name).qml" -ForegroundColor Green
}

Write-Host "`n所有文件转换完成!" -ForegroundColor Green
Write-Host "已转换的文件:" -ForegroundColor Yellow
$files | ForEach-Object { Write-Host "  - $($_.Name).qml" -ForegroundColor White }
