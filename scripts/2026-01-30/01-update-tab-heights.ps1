# ✅ 2026-01-30 [FIX 100.300.106.7]: 批量修改 Tab 文件的参数字段高度从 40 改为 60
# UTF-8 with BOM
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$basePath = "e:\2025\3_gongkongji\belt_control_system\src\qml\components\device_info\pages"

$files = @(
    "BasicConfigTab.qml",
    "CurrentProtectionTab.qml",
    "FrontBearingTempTab.qml",
    "RearBearingTempTab.qml",
    "PhaseAWindingTab.qml",
    "PhaseBWindingTab.qml",
    "PhaseCWindingTab.qml",
    "MotorTempTab.qml",
    "XAxisVibrationTab.qml",
    "YAxisVibrationTab.qml"
)

Write-Host "========== 开始批量修改 Tab 文件高度 ==========" -ForegroundColor Cyan

foreach ($file in $files) {
    $filePath = Join-Path $basePath $file

    if (Test-Path $filePath) {
        Write-Host "`n处理文件: $file" -ForegroundColor Yellow

        # 读取文件内容
        $content = Get-Content $filePath -Raw -Encoding UTF8

        # 替换所有 Layout.preferredHeight: 40 为 60（添加注释）
        $newContent = $content -replace 'Layout\.preferredHeight: 40', 'Layout.preferredHeight: 60  // ✅ 2026-01-30 [FIX 100.300.106.7]: 统一输入框高度为 60（参考 CustomReadOnlyField）'

        # 写回文件
        [System.IO.File]::WriteAllText($filePath, $newContent, [System.Text.Encoding]::UTF8)

        Write-Host "✅ 已修改: $file" -ForegroundColor Green
    } else {
        Write-Host "❌ 文件不存在: $file" -ForegroundColor Red
    }
}

Write-Host "`n========== 修改完成 ==========" -ForegroundColor Cyan
Write-Host "已修改 $($files.Count) 个文件" -ForegroundColor Green
