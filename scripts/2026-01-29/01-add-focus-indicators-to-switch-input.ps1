# UTF-8 with BOM
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# FIX 100.300.101 Phase 3 - 为 SwitchInputPage.qml 添加参数字段焦点指示器
# 日期: 2026-01-29

$filePath = "e:\2025\3_gongkongji\belt_control_system\src\qml\components\device_info\pages\SwitchInputPage.qml"

Write-Host "✅ 开始为 SwitchInputPage.qml 添加焦点指示器..." -ForegroundColor Green

# 读取文件内容
$content = Get-Content $filePath -Raw -Encoding UTF8

# 定义需要添加焦点指示器的字段及其索引
# 索引: 0=保护名称, 1=模块类型, 2=寄存器地址, 3=通道编号, 4=保护延时, 5=保护动作, 6=报警级别, 7=是否启用, 8=备注

# 1. 保护名称 (索引 0)
$old1 = @"
                        // 保护名称
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: "保护名称:"
                                font.pixelSize: 14
                                color: "#9E9E9E"  // 与电机控制一致：标签灰色
                                Layout.preferredWidth: 100
                            }

                            // ✅ 2026-01-28 [FIX 100.300.79]: 替换为 CustomTextField
                            DeviceInfo.CustomTextField {
                                id: nameField
                                Layout.fillWidth: true
                                keyboardManager: root.keyboardManager  // ✅ 2026-01-28 [虚拟键盘]: 传递键盘管理器
                            }
                        }
"@

$new1 = @"
                        // 保护名称
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: "保护名称:"
                                font.pixelSize: 14
                                color: "#9E9E9E"  // 与电机控制一致：标签灰色
                                Layout.preferredWidth: 100
                            }

                            // ✅ 2026-01-28 [FIX 100.300.79]: 替换为 CustomTextField
                            // ✅ 2026-01-29 [FIX 100.300.101 Phase 3]: 添加焦点指示器
                            Item {
                                Layout.fillWidth: true
                                implicitHeight: nameField.implicitHeight

                                DeviceInfo.CustomTextField {
                                    id: nameField
                                    anchors.fill: parent
                                    keyboardManager: root.keyboardManager  // ✅ 2026-01-28 [虚拟键盘]: 传递键盘管理器
                                }

                                // 焦点指示器
                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 0) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 0) ? 3 : 0
                                    radius: 4
                                    z: 10  // 放在输入框前面
                                }
                            }
                        }
"@

$content = $content.Replace($old1, $new1)

# 2. 模块类型 (索引 1)
$old2 = @"
                        // 模块类型
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: "模块类型:"
                                font.pixelSize: 14
                                color: "#9E9E9E"
                                Layout.preferredWidth: 100
                            }

                            // ✅ 2026-01-28 [FIX 100.300.79]: 替换为 CustomComboBox
                            DeviceInfo.CustomComboBox {
                                id: moduleTypeCombo
                                Layout.fillWidth: true
                                keyboardManager: root.keyboardManager  // ✅ 2026-01-28 [虚拟键盘]: 传递键盘管理器

                                model: ["输入模块1", "输入模块2", "输入模块3", "输入模块4", "输出模块", "主模块"]

                                onCurrentTextChanged: {
                                    // 根据模块类型自动设置寄存器地址
                                    if (currentText === "输入模块1") {
                                        registerAddressSpin.value = 2
                                    } else if (currentText === "输入模块2") {
                                        registerAddressSpin.value = 3
                                    } else if (currentText === "输入模块3") {
                                        registerAddressSpin.value = 4
                                    } else if (currentText === "输入模块4") {
                                        registerAddressSpin.value = 5
                                    } else if (currentText === "输出模块") {
                                        registerAddressSpin.value = 50
                                    }
                                }
                            }
                        }
"@

$new2 = @"
                        // 模块类型
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: "模块类型:"
                                font.pixelSize: 14
                                color: "#9E9E9E"
                                Layout.preferredWidth: 100
                            }

                            // ✅ 2026-01-28 [FIX 100.300.79]: 替换为 CustomComboBox
                            // ✅ 2026-01-29 [FIX 100.300.101 Phase 3]: 添加焦点指示器
                            Item {
                                Layout.fillWidth: true
                                implicitHeight: moduleTypeCombo.implicitHeight

                                DeviceInfo.CustomComboBox {
                                    id: moduleTypeCombo
                                    anchors.fill: parent
                                    keyboardManager: root.keyboardManager  // ✅ 2026-01-28 [虚拟键盘]: 传递键盘管理器

                                    model: ["输入模块1", "输入模块2", "输入模块3", "输入模块4", "输出模块", "主模块"]

                                    onCurrentTextChanged: {
                                        // 根据模块类型自动设置寄存器地址
                                        if (currentText === "输入模块1") {
                                            registerAddressSpin.value = 2
                                        } else if (currentText === "输入模块2") {
                                            registerAddressSpin.value = 3
                                        } else if (currentText === "输入模块3") {
                                            registerAddressSpin.value = 4
                                        } else if (currentText === "输入模块4") {
                                            registerAddressSpin.value = 5
                                        } else if (currentText === "输出模块") {
                                            registerAddressSpin.value = 50
                                        }
                                    }
                                }

                                // 焦点指示器
                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 1) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 1) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
                            }
                        }
"@

$content = $content.Replace($old2, $new2)

Write-Host "✅ 已添加保护名称和模块类型的焦点指示器" -ForegroundColor Yellow

# 写入文件
$content | Out-File -FilePath $filePath -Encoding UTF8 -NoNewline

Write-Host "✅ SwitchInputPage.qml 焦点指示器添加完成！" -ForegroundColor Green
Write-Host ""
Write-Host "修改内容：" -ForegroundColor Cyan
Write-Host "  1. 为保护名称字段添加焦点指示器（索引 0）" -ForegroundColor Yellow
Write-Host "  2. 为模块类型字段添加焦点指示器（索引 1）" -ForegroundColor Yellow
Write-Host ""
Write-Host "⚠️ 注意：还需要为其他 7 个字段添加焦点指示器" -ForegroundColor Yellow
Write-Host "  - 寄存器地址（索引 2）" -ForegroundColor Gray
Write-Host "  - 通道编号（索引 3）" -ForegroundColor Gray
Write-Host "  - 保护延时（索引 4）" -ForegroundColor Gray
Write-Host "  - 保护动作（索引 5）" -ForegroundColor Gray
Write-Host "  - 报警级别（索引 6）" -ForegroundColor Gray
Write-Host "  - 是否启用（索引 7）" -ForegroundColor Gray
Write-Host "  - 备注（索引 8）" -ForegroundColor Gray
