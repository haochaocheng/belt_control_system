# 为 CurrentProtectionTab 批量添加 MouseArea 的脚本
# 日期: 2026-02-02

$filePath = "e:\2025\3_gongkongji\belt_control_system\src\qml\components\device_info\pages\CurrentProtectionTab.qml"

# 读取文件内容
$content = Get-Content $filePath -Raw -Encoding UTF8

# 参数名称映射
$paramNames = @{
    2 = "动作保护类型"
    3 = "故障保护类型"
    4 = "电流量程"
    5 = "电流上限"
    6 = "电流下限"
    7 = "输入点选择"
    8 = "过滤干扰延时"
}

# 为每个参数添加 MouseArea
foreach ($index in 2..8) {
    $paramName = $paramNames[$index]

    # 查找焦点指示器的位置
    $pattern = "(\s+)// 焦点指示器\s+Rectangle \{\s+anchors\.fill: parent\s+color: `"transparent`"\s+border\.color: \(root\.focusParamIndex === $index\)"

    # 替换为：MouseArea + 焦点指示器
    $replacement = "`$1// ✅ 2026-02-02 [FIX 100.300.112.8.24.9]: 鼠标点击发射信号`n" +
                   "`$1MouseArea {`n" +
                   "`$1    anchors.fill: parent`n" +
                   "`$1    onClicked: function(mouse) {`n" +
                   "`$1        console.log(`"✅ [CurrentProtectionTab] 鼠标点击$paramName，发射信号: requestFocusParamIndex($index)`")`n" +
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
}

# 同时修改 z 值从 10 到 1000
$content = $content -replace "z: 10(\s+)}", "z: 1000  // ✅ 从 10 增加到 1000`$1    enabled: false`$1}"

# 保存文件
$content | Set-Content $filePath -Encoding UTF8 -NoNewline

Write-Host "✅ CurrentProtectionTab.qml 修改完成"
