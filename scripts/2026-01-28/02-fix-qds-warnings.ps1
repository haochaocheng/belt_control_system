# 批量修复 QDS 警告脚本
# UTF-8 with BOM
$OutputEncoding = [System.Text.UTF8Encoding]::new($true)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "批量修复 QDS 警告" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$fixCount = 0

# ========================================
# 修复 1: ParameterSettings.qml - Anchor 错误
# ========================================
Write-Host "修复 1: ParameterSettings.qml - Anchor 错误" -ForegroundColor Yellow

$file = "src\qml\pages\ParameterSettings.qml"
if (Test-Path $file) {
    $content = Get-Content $file -Raw -Encoding UTF8

    # 修复 MouseArea anchor (第 373 行)
    # 将 anchors.top: header.bottom 改为 anchors.top: headerContainer.bottom
    $content = $content -replace 'anchors\.top:\s*header\.bottom', 'anchors.top: headerContainer.bottom  // FIX 100.300.61: 修复 anchor 目标'

    # 保存
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($file, $content, $utf8NoBom)
    Write-Host "  ✅ 修复 MouseArea anchor" -ForegroundColor Green
    $fixCount++
}

# ========================================
# 修复 2: ParameterSettings.qml - ColumnLayout anchor (第 160 行)
# ========================================
Write-Host ""
Write-Host "修复 2: ParameterSettings.qml - ColumnLayout anchor" -ForegroundColor Yellow

# 这个需要手动检查，因为不确定具体的 anchor 问题
Write-Host "  ⚠️ 需要手动检查第 160 行" -ForegroundColor Yellow

# ========================================
# 修复 3: ControlPanel.qml - ModuleConnectionPanel anchor (第 285 行)
# ========================================
Write-Host ""
Write-Host "修复 3: ControlPanel.qml - ModuleConnectionPanel anchor" -ForegroundColor Yellow

$file = "src\qml\pages\ControlPanel.qml"
if (Test-Path $file) {
    Write-Host "  ⚠️ 需要手动检查第 285 行" -ForegroundColor Yellow
}

# ========================================
# 修复 4: 添加 MockBackend 信号
# ========================================
Write-Host ""
Write-Host "修复 4: 添加 MockBackend 缺失的信号" -ForegroundColor Yellow

$file = "src\qml\MockBackend.qml"
if (Test-Path $file) {
    $content = Get-Content $file -Raw -Encoding UTF8

    # 检查是否已经有这些信号
    if ($content -notmatch "signal deviceStatusChanged") {
        # 在 commonControl 对象中添加信号
        $signalsToAdd = @"

        // FIX 100.300.61: 添加缺失的信号
        signal deviceStatusChanged(string deviceName, bool isRunning)
        signal protectionTriggered(string protectionType)
        signal protectionRestored(string protectionType)
"@

        # 在 commonControl 的最后一个属性后添加
        $content = $content -replace '(property\s+bool\s+isRunning:\s+false)', "`$1$signalsToAdd"

        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($file, $content, $utf8NoBom)
        Write-Host "  ✅ 添加 commonControl 信号" -ForegroundColor Green
        $fixCount++
    } else {
        Write-Host "  ⏭️  信号已存在" -ForegroundColor Gray
    }
}

# ========================================
# 修复 5: 添加 MockBackend 对象
# ========================================
Write-Host ""
Write-Host "修复 5: 添加 MockBackend 缺失的对象" -ForegroundColor Yellow

$file = "src\qml\MockBackend.qml"
if (Test-Path $file) {
    $content = Get-Content $file -Raw -Encoding UTF8

    # 添加 systemConfig 对象
    if ($content -notmatch "property\s+var\s+systemConfig") {
        $objectsToAdd = @"

    // FIX 100.300.61: 添加缺失的对象
    property var systemConfig: QtObject {
        property string deviceName: "模拟设备"
        property int baudRate: 9600
    }

    property var operationLogDB: QtObject {
        function getRecentLogs(count) {
            return []
        }
    }
"@

        # 在文件末尾的 } 前添加
        $content = $content -replace '(\}\s*)$', "$objectsToAdd`n`$1"

        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($file, $content, $utf8NoBom)
        Write-Host "  ✅ 添加 systemConfig 和 operationLogDB" -ForegroundColor Green
        $fixCount++
    } else {
        Write-Host "  ⏭️  对象已存在" -ForegroundColor Gray
    }
}

# ========================================
# 修复 6: 添加 OperationLogPanel 信号
# ========================================
Write-Host ""
Write-Host "修复 6: 添加 OperationLogPanel 缺失的信号" -ForegroundColor Yellow

$file = "src\qml\MockBackend.qml"
if (Test-Path $file) {
    $content = Get-Content $file -Raw -Encoding UTF8

    # 在 operationLogDB 中添加 logAdded 信号
    if ($content -match "property\s+var\s+operationLogDB" -and $content -notmatch "signal logAdded") {
        $content = $content -replace '(property\s+var\s+operationLogDB:\s+QtObject\s+\{)', @"
`$1
        signal logAdded(string message)
"@

        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($file, $content, $utf8NoBom)
        Write-Host "  ✅ 添加 logAdded 信号" -ForegroundColor Green
        $fixCount++
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "修复完成！" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✅ 自动修复: $fixCount 处" -ForegroundColor Green
Write-Host "⚠️  需要手动检查: 2 处" -ForegroundColor Yellow
Write-Host ""
Write-Host "下一步:" -ForegroundColor Yellow
Write-Host "1. 手动检查 ParameterSettings.qml 第 160 行" -ForegroundColor White
Write-Host "2. 手动检查 ControlPanel.qml 第 285 行" -ForegroundColor White
Write-Host "3. 在 QDS 中运行验证" -ForegroundColor White
Write-Host "4. 提交修改" -ForegroundColor White
