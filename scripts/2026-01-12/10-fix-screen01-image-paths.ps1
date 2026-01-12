# ===================================================================================
# 文件: scripts/2026-01-12/10-fix-screen01-image-paths.ps1
# 描述: 修复 Screen01.ui.qml 中的图片路径（中文/空格 → 英文）
# 创建时间: 2026-01-12
# 作者: Claude
# ===================================================================================

#Requires -Version 7
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

param(
    [string]$ProjectRoot = (Get-Location).Path
)

Write-Host "`n==================== 修复 Screen01.ui.qml 图片路径 ====================" -ForegroundColor Cyan

$Screen01Path = Join-Path $ProjectRoot "src\qml\Input1\Input1Content\Screen01.ui.qml"

if (-not (Test-Path $Screen01Path)) {
    Write-Host "❌ 错误: Screen01.ui.qml 不存在" -ForegroundColor Red
    exit 1
}

Write-Host "✓ 找到 Screen01.ui.qml: $Screen01Path" -ForegroundColor Green

# 路径替换映射表（与 08-rename-chinese-to-english.ps1 保持一致）
$pathMapping = @{
    # 路径相关
    '"images/路径-1.svg"' = '"images/path_1.svg"'
    '"images/路径-2.svg"' = '"images/path_2.svg"'
    '"images/路径.svg"' = '"images/path.svg"'
    '"images/路径背景.png"' = '"images/path_background.png"'

    # 标签和状态
    '"images/保护名称.svg"' = '"images/protection_name.svg"'
    '"images/输入类型.svg"' = '"images/input_type.svg"'
    '"images/当前值.svg"' = '"images/current_value.svg"'
    '"images/开关量.svg"' = '"images/switch_value.svg"'
    '"images/速度.svg"' = '"images/speed.svg"'
    '"images/故障.svg"' = '"images/fault.svg"'
    '"images/投入中，正在运行.svg"' = '"images/running_active.svg"'

    # 背景相关
    '"images/背景底部半透明.png"' = '"images/background_bottom_transparent.png"'
    '"images/整体上下半透明.png"' = '"images/background_full_transparent.png"'
    '"images/顶部半透明.png"' = '"images/background_top_transparent.png"'
    '"images/中上部情况背景.png"' = '"images/middle_top_status_bg.png"'
    '"images/中上部情况背景-两边.png"' = '"images/middle_top_status_bg_sides.png"'

    # 第二组1主框（8个PNG文件）
    '"images/第二组1主框-左上.png"' = '"images/group2_frame1_top_left.png"'
    '"images/第二组1主框-左中.png"' = '"images/group2_frame1_middle_left.png"'
    '"images/第二组1主框-左下.png"' = '"images/group2_frame1_bottom_left.png"'
    '"images/第二组1主框-中上.png"' = '"images/group2_frame1_top_center.png"'
    '"images/第二组1主框-中下.png"' = '"images/group2_frame1_bottom_center.png"'
    '"images/第二组1主框-右上.png"' = '"images/group2_frame1_top_right.png"'
    '"images/第二组1主框-右中.png"' = '"images/group2_frame1_middle_right.png"'
    '"images/第二组1主框-右下.png"' = '"images/group2_frame1_bottom_right.png"'

    # 第二组2主框（9个文件：1 SVG + 8 PNG）
    '"images/第二组2主框.svg"' = '"images/group2_frame2.svg"'
    '"images/第二组2主框-左上.png"' = '"images/group2_frame2_top_left.png"'
    '"images/第二组2主框-左中.png"' = '"images/group2_frame2_middle_left.png"'
    '"images/第二组2主框-左下.png"' = '"images/group2_frame2_bottom_left.png"'
    '"images/第二组2主框-上中.png"' = '"images/group2_frame2_top_center.png"'
    '"images/第二组2主框-下中.png"' = '"images/group2_frame2_bottom_center.png"'
    '"images/第二组2主框-右上.png"' = '"images/group2_frame2_top_right.png"'
    '"images/第二组2主框-右中.png"' = '"images/group2_frame2_middle_right.png"'
    '"images/第二组2主框-右下.png"' = '"images/group2_frame2_bottom_right.png"'

    # 第二组3主框（9个PNG文件）
    '"images/第二组3主框.png"' = '"images/group2_frame3.png"'
    '"images/第二组3主框左上.png"' = '"images/group2_frame3_top_left.png"'
    '"images/第二组3主框左中.png"' = '"images/group2_frame3_middle_left.png"'
    '"images/第二组3主框左下.png"' = '"images/group2_frame3_bottom_left.png"'
    '"images/第二组3主框中上.png"' = '"images/group2_frame3_top_center.png"'
    '"images/第二组3主框中下.png"' = '"images/group2_frame3_bottom_center.png"'
    '"images/第二组3主框右上.png"' = '"images/group2_frame3_top_right.png"'
    '"images/第二组3主框右中.png"' = '"images/group2_frame3_middle_right.png"'
    '"images/第二组3主框右下.png"' = '"images/group2_frame3_bottom_right.png"'

    # 传感器相关（10个SVG文件）
    '"images/传感器故障.svg"' = '"images/sensor_error.svg"'
    '"images/安全光幕.svg"' = '"images/safety_light_curtain.svg"'
    '"images/纠偏传感器.svg"' = '"images/deviation_correction_sensor.svg"'
    '"images/跑偏传感器.svg"' = '"images/deviation_sensor.svg"'
    '"images/超速传感器.svg"' = '"images/overspeed_sensor.svg"'
    '"images/零速传感器.svg"' = '"images/zero_speed_sensor.svg"'
    '"images/撕带传感器.svg"' = '"images/belt_tear_sensor.svg"'
    '"images/防滑传感器.svg"' = '"images/anti_slip_sensor.svg"'
    '"images/温度传感器.svg"' = '"images/temperature_sensor.svg"'
    '"images/烟雾传感器.svg"' = '"images/smoke_sensor.svg"'

    # 修复带空格的文件名
    '"images/591f887661e569e40a0f280feaf942c33ddd121328c7b-iqvDOE_fw1200 1.svg"' = '"images/figma_export_1.svg"'
    '"images/Rectangle 34624263.svg"' = '"images/rectangle_34624263.svg"'
    '"images/Rectangle 34624264.svg"' = '"images/rectangle_34624264.svg"'
    '"images/Rectangle 34624265.svg"' = '"images/rectangle_34624265.svg"'
    '"images/Rectangle 34624270.svg"' = '"images/rectangle_34624270.svg"'
    '"images/Rectangle 34624271.svg"' = '"images/rectangle_34624271.svg"'
}

# 读取文件内容
$content = Get-Content -Path $Screen01Path -Raw -Encoding UTF8

# 执行替换
$replacedCount = 0
foreach ($oldPath in $pathMapping.Keys) {
    $newPath = $pathMapping[$oldPath]
    $beforeCount = ([regex]::Matches($content, [regex]::Escape($oldPath))).Count
    if ($beforeCount -gt 0) {
        $content = $content -replace [regex]::Escape($oldPath), $newPath
        $replacedCount += $beforeCount
        Write-Host "  ✓ 替换 $oldPath → $newPath ($beforeCount 处)" -ForegroundColor Green
    }
}

if ($replacedCount -eq 0) {
    Write-Host "`n✓ 无需修复，所有路径已是正确的" -ForegroundColor Green
} else {
    # 保存修复后的文件
    Set-Content -Path $Screen01Path -Value $content -Encoding UTF8 -NoNewline
    Write-Host "`n✅ 修复完成！共替换 $replacedCount 处路径" -ForegroundColor Green
    Write-Host "  文件已更新: $Screen01Path" -ForegroundColor Cyan
}

Write-Host "`n========================================================================`n" -ForegroundColor Cyan
