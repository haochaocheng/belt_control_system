# 批量为所有保护 Tab 添加 MouseArea 的脚本
# 日期: 2026-02-02

$basePath = "e:\2025\3_gongkongji\belt_control_system\src\qml\components\device_info\pages"

# Tab 列表和参数名称映射
$tabs = @{
    "FrontBearingTempTab" = @{
        0 = "是否投入"
        1 = "报警类型"
        2 = "动作保护类型"
        3 = "故障保护类型"
        4 = "温度量程"
        5 = "温度上限"
        6 = "温度下限"
        7 = "输入点选择"
        8 = "过滤干扰延时"
    }
    "RearBearingTempTab" = @{
        0 = "是否投入"
        1 = "报警类型"
        2 = "动作保护类型"
        3 = "故障保护类型"
        4 = "温度量程"
        5 = "温度上限"
        6 = "温度下限"
        7 = "输入点选择"
        8 = "过滤干扰延时"
    }
    "PhaseAWindingTab" = @{
        0 = "是否投入"
        1 = "报警类型"
        2 = "动作保护类型"
        3 = "故障保护类型"
        4 = "温度量程"
        5 = "温度上限"
        6 = "温度下限"
        7 = "输入点选择"
        8 = "过滤干扰延时"
    }
    "PhaseBWindingTab" = @{
        0 = "是否投入"
        1 = "报警类型"
        2 = "动作保护类型"
        3 = "故障保护类型"
        4 = "温度量程"
        5 = "温度上限"
        6 = "温度下限"
        7 = "输入点选择"
        8 = "过滤干扰延时"
    }
    "PhaseCWindingTab" = @{
        0 = "是否投入"
        1 = "报警类型"
        2 = "动作保护类型"
        3 = "故障保护类型"
        4 = "温度量程"
        5 = "温度上限"
        6 = "温度下限"
        7 = "输入点选择"
        8 = "过滤干扰延时"
    }
    "MotorTempTab" = @{
        0 = "是否投入"
        1 = "报警类型"
        2 = "动作保护类型"
        3 = "故障保护类型"
        4 = "温度量程"
        5 = "温度上限"
        6 = "温度下限"
        7 = "输入点选择"
        8 = "过滤干扰延时"
    }
    "XAxisVibrationTab" = @{
        0 = "是否投入"
        1 = "报警类型"
        2 = "动作保护类型"
        3 = "故障保护类型"
        4 = "振动量程"
        5 = "振动上限"
        6 = "振动下限"
        7 = "输入点选择"
        8 = "过滤干扰延时"
    }
    "YAxisVibrationTab" = @{
        0 = "是否投入"
        1 = "报警类型"
        2 = "动作保护类型"
        3 = "故障保护类型"
        4 = "振动量程"
        5 = "振动上限"
        6 = "振动下限"
        7 = "输入点选择"
        8 = "过滤干扰延时"
    }
}

foreach ($tabName in $tabs.Keys) {
    $filePath = Join-Path $basePath "$tabName.qml"

    Write-Host "处理 $tabName.qml ..." -ForegroundColor Cyan

    # 读取文件内容
    $content = Get-Content $filePath -Raw -Encoding UTF8

    # 1. 添加信号声明（在 property var virtualKeyboard 之后）
    $signalPattern = "(property var virtualKeyboard: null.*?\n)"
    $signalReplacement = "`$1`n    // ✅ 2026-02-02 [FIX 100.300.112.8.24.9]: 信号 - 请求更新焦点索引`n    // 用于鼠标点击时通知父组件，避免直接赋值打破 Qt.binding`n    signal requestFocusParamIndex(int paramIndex)`n"

    if ($content -notmatch "signal requestFocusParamIndex") {
        $content = $content -replace $signalPattern, $signalReplacement
        Write-Host "  ✅ 添加信号声明" -ForegroundColor Green
    } else {
        Write-Host "  ⏭️  信号声明已存在" -ForegroundColor Yellow
    }

    # 2. 为每个参数添加 MouseArea
    $paramNames = $tabs[$tabName]

    foreach ($index in 0..8) {
        $paramName = $paramNames[$index]

        # 查找焦点指示器的位置
        $pattern = "(\s+)// 焦点指示器\s+Rectangle \{\s+anchors\.fill: parent\s+color: `"transparent`"\s+border\.color: \(root\.focusParamIndex === $index\)"

        # 检查是否已经有 MouseArea
        if ($content -match "鼠标点击$paramName.*requestFocusParamIndex\($index\)") {
            Write-Host "  ⏭️  参数 $index ($paramName) 的 MouseArea 已存在" -ForegroundColor Yellow
            continue
        }

        # 替换为：MouseArea + 焦点指示器
        $replacement = "`$1// ✅ 2026-02-02 [FIX 100.300.112.8.24.9]: 鼠标点击发射信号`n" +
                       "`$1MouseArea {`n" +
                       "`$1    anchors.fill: parent`n" +
                       "`$1    onClicked: function(mouse) {`n" +
                       "`$1        console.log(`"✅ [$tabName] 鼠标点击$paramName，发射信号: requestFocusParamIndex($index)`")`n" +
                       "`$1        root.requestFocusParamIndex($index)`n" +
                       "`$1        mouse.accepted = false`n" +
                       "`$1    }`n" +
                       "`$1}`n`n" +
                       "`$1// 焦点指示器`n" +
                       "`$1// ✅ 2026-02-02 [FIX 100.300.112.8.24.9]: 增加 z 值到 1000`n" +
                       "`$1Rectangle {`n" +
                       "`$1    anchors.fill: parent`n" +
                       "`$1    color: `"transparent`"`n" +
                       "`$1    border.color: (root.focusParamIndex === $index)"

        $content = $content -replace $pattern, $replacement
        Write-Host "  ✅ 添加参数 $index ($paramName) 的 MouseArea" -ForegroundColor Green
    }

    # 3. 修改 z 值从 10 到 1000
    $content = $content -replace "z: 10(\s+)}", "z: 1000  // ✅ 从 10 增加到 1000`$1    enabled: false`$1}"

    # 保存文件
    $content | Set-Content $filePath -Encoding UTF8 -NoNewline

    Write-Host "✅ $tabName.qml 修改完成`n" -ForegroundColor Green
}

Write-Host "`n✅ 所有 Tab 修改完成！" -ForegroundColor Green
