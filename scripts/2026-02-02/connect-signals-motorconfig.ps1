# 批量为 MotorConfigPanel 中的所有 Tab Loader 添加信号连接
# 日期: 2026-02-02

$filePath = "e:\2025\3_gongkongji\belt_control_system\src\qml\components\device_info\pages\MotorConfigPanel.qml"

# 读取文件内容
$content = Get-Content $filePath -Raw -Encoding UTF8

# Tab Loader 列表
$loaders = @(
    @{ Id = "frontBearingTempLoader"; TabName = "FrontBearingTempTab"; Index = 2 }
    @{ Id = "rearBearingTempLoader"; TabName = "RearBearingTempTab"; Index = 3 }
    @{ Id = "phaseAWindingLoader"; TabName = "PhaseAWindingTab"; Index = 4 }
    @{ Id = "phaseBWindingLoader"; TabName = "PhaseBWindingTab"; Index = 5 }
    @{ Id = "phaseCWindingLoader"; TabName = "PhaseCWindingTab"; Index = 6 }
    @{ Id = "motorTempLoader"; TabName = "MotorTempTab"; Index = 7 }
    @{ Id = "xAxisVibrationLoader"; TabName = "XAxisVibrationTab"; Index = 8 }
    @{ Id = "yAxisVibrationLoader"; TabName = "YAxisVibrationTab"; Index = 9 }
)

foreach ($loader in $loaders) {
    $loaderId = $loader.Id
    $tabName = $loader.TabName
    $tabIndex = $loader.Index

    Write-Host "处理 $tabName ($loaderId) ..." -ForegroundColor Cyan

    # 检查是否已经有信号连接
    if ($content -match "$loaderId[\s\S]*?requestFocusParamIndex\.connect") {
        Write-Host "  ⏭️  $tabName 的信号连接已存在" -ForegroundColor Yellow
        continue
    }

    # 查找 Loader 的 onLoaded 块
    $pattern = "(id: $loaderId\s+active: root\.currentTabIndex === $tabIndex\s+source: `"$tabName\.qml`"\s+onLoaded: \{\s+if \(item\) \{\s+item\.motorIndex = root\.motorIndex\s+.*?item\.focusParamIndex = Qt\.binding\(function\(\) \{ return root\.focusParamIndex \}\)\s+item\.virtualKeyboard = Qt\.binding\(function\(\) \{ return root\.virtualKeyboard \}\)\s+)(\}\s+\})"

    # 替换为：添加信号连接
    $replacement = "`$1`n`n                        // ✅ 2026-02-02 [FIX 100.300.112.8.24.9]: 连接信号`n" +
                   "                        item.requestFocusParamIndex.connect(function(paramIndex) {`n" +
                   "                            console.log(`"✅ [MotorConfigPanel] 转发信号: requestFocusParamIndex(`" + paramIndex + `")`")`n" +
                   "                            root.requestFocusParamIndex(paramIndex)`n" +
                   "                        })`n                    `$2"

    $oldContent = $content
    $content = $content -replace $pattern, $replacement

    if ($content -ne $oldContent) {
        Write-Host "  ✅ 添加 $tabName 的信号连接" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  未找到匹配的 Loader 模式" -ForegroundColor Red
    }
}

# 保存文件
$content | Set-Content $filePath -Encoding UTF8 -NoNewline

Write-Host "`n✅ MotorConfigPanel.qml 修改完成！" -ForegroundColor Green
