# 为 CurrentProtectionTab 修改参数控件类型
# 日期: 2026-02-02
# 任务: FIX 100.300.112.8.25

$filePath = "e:\2025\3_gongkongji\belt_control_system\src\qml\components\device_info\pages\CurrentProtectionTab.qml"

# 读取文件内容
$content = Get-Content $filePath -Raw -Encoding UTF8

Write-Host "开始修改 CurrentProtectionTab.qml ..." -ForegroundColor Cyan

# 1. 修改参数 4（电流量程）：CustomReadOnlyField → CustomSpinBox + 单位
Write-Host "  修改参数 4（电流量程）..." -ForegroundColor Yellow

$pattern4 = "// 电流量程输入（只读）\s+Item \{\s+Layout\.column: 1\s+Layout\.row: 2\s+Layout\.fillWidth: true\s+Layout\.maximumWidth: 300\s+implicitHeight: currentRangeField\.implicitHeight.*?DeviceInfo\.CustomReadOnlyField \{\s+id: currentRangeField\s+anchors\.fill: parent\s+text: `"0-100A`"\s+\}"

$replacement4 = @"
// ✅ 2026-02-02 [FIX 100.300.112.8.25]: 改为 CustomSpinBox，可输入数据，单位在外部
            // 电流量程输入（可输入，带单位）
            Item {
                Layout.column: 1
                Layout.row: 2
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: currentRangeRow.implicitHeight

                Row {
                    id: currentRangeRow
                    width: parent.width
                    height: 60
                    spacing: 5

                    DeviceInfo.CustomSpinBox {
                        id: currentRangeField
                        width: parent.width - 30
                        height: 60
                        from: 0
                        to: 1000
                        value: 100
                        keyboardManager: root.keyboardManager
                    }

                    Text {
                        text: "A"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
"@

$content = $content -replace $pattern4, $replacement4

# 2. 修改参数 5（电流上限）：CustomReadOnlyField → CustomSpinBox
Write-Host "  修改参数 5（电流上限）..." -ForegroundColor Yellow

$pattern5 = "DeviceInfo\.CustomReadOnlyField \{\s+width: parent\.width - 30\s+height: 60.*?text: `"80`"\s+\}"

$replacement5 = @"
DeviceInfo.CustomSpinBox {
                        id: currentUpperField
                        width: parent.width - 30
                        height: 60
                        from: 0
                        to: 1000
                        value: 80
                        keyboardManager: root.keyboardManager
                    }
"@

$content = $content -replace $pattern5, $replacement5

# 3. 修改参数 6（电流下限）：CustomReadOnlyField → CustomSpinBox
Write-Host "  修改参数 6（电流下限）..." -ForegroundColor Yellow

$pattern6 = "// 电流下限输入（只读，带单位）\s+Item \{.*?DeviceInfo\.CustomReadOnlyField \{\s+width: parent\.width - 30\s+height: 60.*?text: `"20`"\s+\}"

$replacement6 = @"
// ✅ 2026-02-02 [FIX 100.300.112.8.25]: 改为 CustomSpinBox，可输入数据
            // 电流下限输入（可输入，带单位）
            Item {
                Layout.column: 1
                Layout.row: 3
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: currentLowerRow.implicitHeight

                Row {
                    id: currentLowerRow
                    width: parent.width
                    height: 60
                    spacing: 5

                    DeviceInfo.CustomSpinBox {
                        id: currentLowerField
                        width: parent.width - 30
                        height: 60
                        from: 0
                        to: 1000
                        value: 20
                        keyboardManager: root.keyboardManager
                    }
"@

$content = $content -replace $pattern6, $replacement6

# 4. 修改参数 7（输入点选择）：CustomSpinBox → CustomComboBox
Write-Host "  修改参数 7（输入点选择）..." -ForegroundColor Yellow

$pattern7 = "DeviceInfo\.CustomSpinBox \{\s+id: inputPointField\s+anchors\.fill: parent\s+from: 0\s+to: 15\s+value: 0\s+keyboardManager: root\.keyboardManager\s+\}"

$replacement7 = @"
DeviceInfo.CustomComboBox {
                    id: inputPointField
                    anchors.fill: parent
                    model: ["AI0.0", "AI0.1", "AI0.2", "AI0.3", "AI0.4", "AI0.5", "AI0.6", "AI0.7",
                            "AI1.0", "AI1.1", "AI1.2", "AI1.3", "AI1.4", "AI1.5", "AI1.6", "AI1.7"]
                    currentIndex: 0
                    keyboardManager: root.keyboardManager
                }
"@

$content = $content -replace $pattern7, $replacement7

# 5. 修改参数 8（过滤干扰延时）：修改单位显示
Write-Host "  修改参数 8（过滤干扰延时）单位..." -ForegroundColor Yellow

$pattern8 = "Text \{\s+text: `"秒`"\s+font\.pixelSize: 21\s+color: `"#9E9E9E`"\s+anchors\.verticalCenter: parent\.verticalCenter\s+\}\s+\}\s+// ✅ 2026-02-02 \[FIX 100\.300\.112\.8\.24\.9\]: 鼠标点击发射信号\s+MouseArea \{\s+anchors\.fill: parent\s+onClicked: function\(mouse\) \{\s+console\.log\(`"✅ \[CurrentProtectionTab\] 鼠标点击过滤干扰延时"

$replacement8 = @"
Text {
                        text: "0.1秒"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // ✅ 2026-02-02 [FIX 100.300.112.8.24.9]: 鼠标点击发射信号
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [CurrentProtectionTab] 鼠标点击过滤干扰延时"
"@

$content = $content -replace $pattern8, $replacement8

# 保存文件
$content | Set-Content $filePath -Encoding UTF8 -NoNewline

Write-Host "✅ CurrentProtectionTab.qml 修改完成！" -ForegroundColor Green
