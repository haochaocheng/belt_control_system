# QML 参数持久化集成指南

**日期**: 2026-02-02
**任务编号**: FIX 100.300.112.8.22 - Phase 3
**状态**: 📋 待实施

---

## 🎯 目标

为 MotorControlPage、BrakeControlPage、TensionControlPage 添加参数持久化功能，使用户修改的参数能够保存到数据库并在应用重启后正确加载。

---

## 📊 后端 API 已就绪

### 电机配置 API
```javascript
// 保存电机配置
deviceConfigMgr.saveMotorConfig(deviceId, motorIndex, tabIndex, config)

// 加载电机配置
var config = deviceConfigMgr.loadMotorConfig(deviceId, motorIndex, tabIndex)

// 加载电机所有Tab配置
var configs = deviceConfigMgr.loadAllMotorConfigs(deviceId, motorIndex)
```

### 制动器配置 API
```javascript
// 保存制动器配置
deviceConfigMgr.saveBrakeConfig(deviceId, brakeIndex, config)

// 加载制动器配置
var config = deviceConfigMgr.loadBrakeConfig(deviceId, brakeIndex)

// 加载所有制动器配置
var configs = deviceConfigMgr.loadAllBrakeConfigs(deviceId)
```

### 张紧控制配置 API
```javascript
// 保存张紧控制配置
deviceConfigMgr.saveTensionConfig(deviceId, tensionIndex, config)

// 加载张紧控制配置
var config = deviceConfigMgr.loadTensionConfig(deviceId, tensionIndex)

// 加载所有张紧控制配置
var configs = deviceConfigMgr.loadAllTensionConfigs(deviceId)
```

---

## 🔧 实施方案

### Phase 1: MotorControlPage 集成

#### 1.1 在 MotorControlPage.qml 中添加保存和加载函数

**文件**: `src/qml/components/device_info/pages/MotorControlPage.qml`

**位置**: 在文件末尾（Line 532 之后）添加以下函数

```qml
// ✅ 2026-02-02 [参数持久化]: 保存电机配置
function saveMotorConfig() {
    console.log("✅ [MotorControlPage] 保存电机配置 - 设备:", root.deviceId, "电机:", root.currentMotorIndex, "Tab:", root.focusTabIndex)

    // 获取当前 Tab 的参数
    var currentTab = motorConfigPanel.item ? motorConfigPanel.item.getCurrentTab() : null
    if (!currentTab) {
        console.log("⚠️ [MotorControlPage] 无法获取当前 Tab")
        return false
    }

    // 收集参数（根据不同 Tab 类型收集不同参数）
    var config = {}

    // 根据 Tab 索引确定 Tab 名称
    var tabNames = [
        "基本配置", "电流保护", "前轴承温度", "后轴承温度", "A相绕组",
        "B相绕组", "C相绕组", "电机温度", "X轴振动", "Y轴振动"
    ]
    config["tab_name"] = tabNames[root.focusTabIndex] || "未知Tab"

    // 调用 Tab 的 collectConfig() 方法收集参数
    if (typeof currentTab.collectConfig === "function") {
        var tabConfig = currentTab.collectConfig()
        // 合并 Tab 配置到主配置
        for (var key in tabConfig) {
            config[key] = tabConfig[key]
        }
    } else {
        console.log("⚠️ [MotorControlPage] 当前 Tab 不支持 collectConfig()")
        return false
    }

    // 保存到数据库
    var success = deviceConfigMgr.saveMotorConfig(
        root.deviceId,
        root.currentMotorIndex,
        root.focusTabIndex,
        config
    )

    if (success) {
        console.log("✅ [MotorControlPage] 保存成功")
    } else {
        console.log("❌ [MotorControlPage] 保存失败")
    }

    return success
}

// ✅ 2026-02-02 [参数持久化]: 加载电机配置
function loadMotorConfig() {
    console.log("✅ [MotorControlPage] 加载电机配置 - 设备:", root.deviceId, "电机:", root.currentMotorIndex, "Tab:", root.focusTabIndex)

    // 从数据库加载配置
    var config = deviceConfigMgr.loadMotorConfig(
        root.deviceId,
        root.currentMotorIndex,
        root.focusTabIndex
    )

    if (!config || Object.keys(config).length === 0) {
        console.log("⚠️ [MotorControlPage] 未找到配置，使用默认值")
        return false
    }

    // 获取当前 Tab
    var currentTab = motorConfigPanel.item ? motorConfigPanel.item.getCurrentTab() : null
    if (!currentTab) {
        console.log("⚠️ [MotorControlPage] 无法获取当前 Tab")
        return false
    }

    // 调用 Tab 的 applyConfig() 方法应用配置
    if (typeof currentTab.applyConfig === "function") {
        currentTab.applyConfig(config)
        console.log("✅ [MotorControlPage] 配置已应用")
    } else {
        console.log("⚠️ [MotorControlPage] 当前 Tab 不支持 applyConfig()")
        return false
    }

    return true
}
```

#### 1.2 修改"保存"按钮的 onClicked 事件

**文件**: `src/qml/components/device_info/pages/MotorControlPage.qml`

**位置**: Line 401-404

**修改前**:
```qml
onClicked: {
    console.log("✅ [MotorControlPage] 保存")
    // TODO: 实现保存功能
}
```

**修改后**:
```qml
onClicked: {
    console.log("✅ [MotorControlPage] 保存")
    // ✅ 2026-02-02 [参数持久化]: 调用保存函数
    root.saveMotorConfig()
}
```

#### 1.3 在切换电机或Tab时自动加载配置

**文件**: `src/qml/components/device_info/pages/MotorControlPage.qml`

**位置**: 在 NavigationManager 的 onMotorListIndexChanged 和 onTabIndexChanged 中添加加载逻辑

**在 Line 71-75 的 onMotorListIndexChanged 中添加**:
```qml
onMotorListIndexChanged: {
    console.log("✅ [MotorControlPage] 电机列表索引变化:", motorListIndex)
    root.currentMotorIndex = motorListIndex
    root.focusItemIndex = motorListIndex
    // ✅ 2026-02-02 [参数持久化]: 切换电机时加载配置
    Qt.callLater(root.loadMotorConfig)
}
```

**在 Line 78-85 的 onTabIndexChanged 中添加**:
```qml
onTabIndexChanged: {
    console.log("✅ [MotorControlPage] Tab索引变化:", tabIndex, "参数区自动切换显示")
    root.focusTabIndex = tabIndex
    // 切换Tab时，参数区自动显示对应的参数
    if (motorConfigPanel.item) {
        motorConfigPanel.item.currentTabIndex = tabIndex
    }
    // ✅ 2026-02-02 [参数持久化]: 切换Tab时加载配置
    Qt.callLater(root.loadMotorConfig)
}
```

---

### Phase 2: 为每个 Tab 添加 collectConfig() 和 applyConfig() 方法

每个 Tab 组件（BasicConfigTab、CurrentProtectionTab 等）需要实现两个方法：

#### 2.1 collectConfig() 方法

**作用**: 收集当前 Tab 的所有参数值

**示例**（BasicConfigTab.qml）:
```qml
// ✅ 2026-02-02 [参数持久化]: 收集配置参数
function collectConfig() {
    var config = {}

    // 收集所有参数字段
    config["protection_name"] = nameField.text || ""
    config["protection_delay"] = delaySpin.value || 0
    config["upper_limit"] = upperLimitSpin.value || 0
    config["lower_limit"] = lowerLimitSpin.value || 0
    config["unit"] = unitCombo.currentText || ""
    config["voice_alarm_enabled"] = voiceAlarmCheck.checked || false
    config["voice_alarm_type"] = ttsRadio.checked ? "tts" : "audio"
    config["tts_text"] = ttsTextField.text || ""
    config["audio_file"] = audioFileField.text || ""
    config["play_count"] = playCountSpin.value || 1
    config["play_duration"] = playDurationSpin.value || 5

    console.log("✅ [BasicConfigTab] 收集配置:", JSON.stringify(config))
    return config
}
```

#### 2.2 applyConfig() 方法

**作用**: 将配置参数应用到 UI 控件

**示例**（BasicConfigTab.qml）:
```qml
// ✅ 2026-02-02 [参数持久化]: 应用配置参数
function applyConfig(config) {
    console.log("✅ [BasicConfigTab] 应用配置:", JSON.stringify(config))

    // 应用所有参数字段
    if (config["protection_name"] !== undefined) {
        nameField.text = config["protection_name"]
    }
    if (config["protection_delay"] !== undefined) {
        delaySpin.value = config["protection_delay"]
    }
    if (config["upper_limit"] !== undefined) {
        upperLimitSpin.value = config["upper_limit"]
    }
    if (config["lower_limit"] !== undefined) {
        lowerLimitSpin.value = config["lower_limit"]
    }
    if (config["unit"] !== undefined) {
        // 查找 ComboBox 中的索引
        var index = unitCombo.find(config["unit"])
        if (index >= 0) {
            unitCombo.currentIndex = index
        }
    }
    if (config["voice_alarm_enabled"] !== undefined) {
        voiceAlarmCheck.checked = config["voice_alarm_enabled"]
    }
    if (config["voice_alarm_type"] !== undefined) {
        if (config["voice_alarm_type"] === "tts") {
            ttsRadio.checked = true
        } else {
            audioRadio.checked = true
        }
    }
    if (config["tts_text"] !== undefined) {
        ttsTextField.text = config["tts_text"]
    }
    if (config["audio_file"] !== undefined) {
        audioFileField.text = config["audio_file"]
    }
    if (config["play_count"] !== undefined) {
        playCountSpin.value = config["play_count"]
    }
    if (config["play_duration"] !== undefined) {
        playDurationSpin.value = config["play_duration"]
    }
}
```

#### 2.3 需要修改的 Tab 文件列表

1. **BasicConfigTab.qml** - 基本配置
2. **CurrentProtectionTab.qml** - 电流保护
3. **FrontBearingTempTab.qml** - 前轴承温度
4. **RearBearingTempTab.qml** - 后轴承温度
5. **APhaseWindingTab.qml** - A相绕组
6. **BPhaseWindingTab.qml** - B相绕组
7. **CPhaseWindingTab.qml** - C相绕组
8. **MotorTempTab.qml** - 电机温度
9. **XAxisVibrationTab.qml** - X轴振动
10. **YAxisVibrationTab.qml** - Y轴振动

**注意**: 每个 Tab 的参数字段可能不同，需要根据实际情况调整 collectConfig() 和 applyConfig() 方法。

---

### Phase 3: BrakeControlPage 集成

**文件**: `src/qml/components/device_info/pages/BrakeControlPage.qml`

**实施步骤**: 类似 MotorControlPage，添加以下函数：

```qml
// ✅ 2026-02-02 [参数持久化]: 保存制动器配置
function saveBrakeConfig() {
    console.log("✅ [BrakeControlPage] 保存制动器配置 - 设备:", root.deviceId, "制动器:", root.currentBrakeIndex)

    // 收集参数
    var config = {}
    config["brake_name"] = brakeNameField.text || ""
    config["brake_delay"] = brakeDelaySpin.value || 0
    config["brake_force"] = brakeForceSpin.value || 0
    config["temperature_upper_limit"] = tempUpperLimitSpin.value || 80.0
    config["temperature_lower_limit"] = tempLowerLimitSpin.value || 0.0
    config["pressure_upper_limit"] = pressureUpperLimitSpin.value || 10.0
    config["pressure_lower_limit"] = pressureLowerLimitSpin.value || 0.0
    config["voice_alarm_enabled"] = voiceAlarmCheck.checked || false
    config["voice_alarm_type"] = ttsRadio.checked ? "tts" : "audio"
    config["tts_text"] = ttsTextField.text || ""
    config["audio_file"] = audioFileField.text || ""
    config["play_count"] = playCountSpin.value || 1
    config["play_duration"] = playDurationSpin.value || 5

    // 保存到数据库
    var success = deviceConfigMgr.saveBrakeConfig(
        root.deviceId,
        root.currentBrakeIndex,
        config
    )

    return success
}

// ✅ 2026-02-02 [参数持久化]: 加载制动器配置
function loadBrakeConfig() {
    console.log("✅ [BrakeControlPage] 加载制动器配置 - 设备:", root.deviceId, "制动器:", root.currentBrakeIndex)

    // 从数据库加载配置
    var config = deviceConfigMgr.loadBrakeConfig(
        root.deviceId,
        root.currentBrakeIndex
    )

    if (!config || Object.keys(config).length === 0) {
        console.log("⚠️ [BrakeControlPage] 未找到配置，使用默认值")
        return false
    }

    // 应用配置到 UI
    if (config["brake_name"] !== undefined) {
        brakeNameField.text = config["brake_name"]
    }
    if (config["brake_delay"] !== undefined) {
        brakeDelaySpin.value = config["brake_delay"]
    }
    if (config["brake_force"] !== undefined) {
        brakeForceSpin.value = config["brake_force"]
    }
    // ... 更多字段

    return true
}
```

**在切换制动器时自动加载配置**:
```qml
onCurrentBrakeIndexChanged: {
    console.log("✅ [BrakeControlPage] 制动器索引变化:", currentBrakeIndex)
    // ✅ 2026-02-02 [参数持久化]: 切换制动器时加载配置
    Qt.callLater(root.loadBrakeConfig)
}
```

---

### Phase 4: TensionControlPage 集成

**文件**: `src/qml/components/device_info/pages/TensionControlPage.qml`

**实施步骤**: 类似 BrakeControlPage，添加以下函数：

```qml
// ✅ 2026-02-02 [参数持久化]: 保存张紧控制配置
function saveTensionConfig() {
    console.log("✅ [TensionControlPage] 保存张紧控制配置 - 设备:", root.deviceId, "张紧装置:", root.currentTensionIndex)

    // 收集参数
    var config = {}
    config["tension_name"] = tensionNameField.text || ""
    config["tension_force"] = tensionForceSpin.value || 0
    config["position_upper_limit"] = posUpperLimitSpin.value || 100.0
    config["position_lower_limit"] = posLowerLimitSpin.value || 0.0
    config["pressure_upper_limit"] = pressureUpperLimitSpin.value || 10.0
    config["pressure_lower_limit"] = pressureLowerLimitSpin.value || 0.0
    config["temperature_upper_limit"] = tempUpperLimitSpin.value || 80.0
    config["temperature_lower_limit"] = tempLowerLimitSpin.value || 0.0
    config["voice_alarm_enabled"] = voiceAlarmCheck.checked || false
    config["voice_alarm_type"] = ttsRadio.checked ? "tts" : "audio"
    config["tts_text"] = ttsTextField.text || ""
    config["audio_file"] = audioFileField.text || ""
    config["play_count"] = playCountSpin.value || 1
    config["play_duration"] = playDurationSpin.value || 5

    // 保存到数据库
    var success = deviceConfigMgr.saveTensionConfig(
        root.deviceId,
        root.currentTensionIndex,
        config
    )

    return success
}

// ✅ 2026-02-02 [参数持久化]: 加载张紧控制配置
function loadTensionConfig() {
    console.log("✅ [TensionControlPage] 加载张紧控制配置 - 设备:", root.deviceId, "张紧装置:", root.currentTensionIndex)

    // 从数据库加载配置
    var config = deviceConfigMgr.loadTensionConfig(
        root.deviceId,
        root.currentTensionIndex
    )

    if (!config || Object.keys(config).length === 0) {
        console.log("⚠️ [TensionControlPage] 未找到配置，使用默认值")
        return false
    }

    // 应用配置到 UI
    if (config["tension_name"] !== undefined) {
        tensionNameField.text = config["tension_name"]
    }
    if (config["tension_force"] !== undefined) {
        tensionForceSpin.value = config["tension_force"]
    }
    // ... 更多字段

    return true
}
```

**在切换张紧装置时自动加载配置**:
```qml
onCurrentTensionIndexChanged: {
    console.log("✅ [TensionControlPage] 张紧装置索引变化:", currentTensionIndex)
    // ✅ 2026-02-02 [参数持久化]: 切换张紧装置时加载配置
    Qt.callLater(root.loadTensionConfig)
}
```

---

## 🎯 验证方法

### 测试步骤

#### 1. 编译和部署
```powershell
.\build-ubuntu24-apt.ps1 188
```

#### 2. 测试电机配置保存和加载
1. 打开设备设置对话框
2. 切换到"电机控制"类别
3. 选择一个电机（例如：1号电机）
4. 切换到一个Tab（例如：基本配置）
5. 修改参数（例如：保护名称、上限值、下限值）
6. 点击"保存"按钮
7. **验证**：应该看到日志输出 "✅ [MotorControlPage] 保存成功" ✅
8. 切换到另一个电机，再切换回来
9. **验证**：修改的参数应该被正确加载 ✅
10. 关闭应用，重新启动
11. **验证**：参数应该被持久化保存 ✅

#### 3. 测试制动器配置保存和加载
类似电机配置测试步骤。

#### 4. 测试张紧控制配置保存和加载
类似电机配置测试步骤。

---

## 💡 技术要点

### 1. Qt.callLater() 的使用
- 在切换电机/Tab时使用 `Qt.callLater(root.loadMotorConfig)` 延迟加载配置
- 原因：确保 UI 组件已经完全切换完成后再加载配置
- 避免在组件切换过程中访问未初始化的控件

### 2. collectConfig() 和 applyConfig() 的设计
- **collectConfig()**: 从 UI 控件收集参数值，返回 QVariantMap
- **applyConfig()**: 将参数值应用到 UI 控件
- 每个 Tab 组件独立实现这两个方法，保持模块化

### 3. 参数字段的默认值
- 使用 `|| 默认值` 语法提供默认值
- 例如：`config["protection_delay"] = delaySpin.value || 0`
- 确保即使控件未初始化也能返回有效值

### 4. 错误处理
- 检查 `deviceConfigMgr` 是否已定义
- 检查配置是否为空（`Object.keys(config).length === 0`）
- 检查 Tab 组件是否支持 collectConfig/applyConfig 方法
- 使用 console.log 输出详细的调试信息

---

## 📊 实施优先级

### 高优先级（必须实现）
1. ✅ MotorControlPage 的 saveMotorConfig() 和 loadMotorConfig() 函数
2. ✅ BasicConfigTab 的 collectConfig() 和 applyConfig() 方法
3. ✅ 修改"保存"按钮的 onClicked 事件
4. ✅ 在切换电机/Tab时自动加载配置

### 中优先级（建议实现）
1. ⏳ 其他9个 Tab 的 collectConfig() 和 applyConfig() 方法
2. ⏳ BrakeControlPage 的保存和加载功能
3. ⏳ TensionControlPage 的保存和加载功能

### 低优先级（可选实现）
1. ⏳ 添加"重置"按钮功能（恢复默认配置）
2. ⏳ 添加"删除"按钮功能（删除当前配置）
3. ⏳ 添加配置导入/导出功能

---

## 🔗 相关文档

- [07-FIX100.300.112.8.22-实现电机制动器张紧控制参数持久化.md](./07-FIX100.300.112.8.22-实现电机制动器张紧控制参数持久化.md)
- [DeviceConfigManager.h](../../src/control/DeviceConfigManager.h)
- [DeviceConfigManager.cpp](../../src/control/DeviceConfigManager.cpp)
- [MotorControlPage.qml](../../src/qml/components/device_info/pages/MotorControlPage.qml)
- [BasicConfigTab.qml](../../src/qml/components/device_info/pages/BasicConfigTab.qml)

---

**创建日期**: 2026-02-02
**状态**: 📋 指南完成，待实施
**编写人员**: Claude Sonnet 4.5
