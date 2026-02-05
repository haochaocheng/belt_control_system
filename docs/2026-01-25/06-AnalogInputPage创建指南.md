# AnalogInputPage.qml 创建指南

**日期**：2026-01-25
**版本**：Phase 3
**状态**：📋 待实施

---

## 📋 创建步骤

### 步骤 1：复制基础文件

```powershell
Copy-Item `
  "src\qml\components\device_info\pages\SwitchInputPage.qml" `
  "src\qml\components\device_info\pages\AnalogInputPage.qml"
```

### 步骤 2：修改文件头部注释

**位置**：第5行

**修改前**：
```qml
// ✅ 2026-01-25 [开关量输入页面] 左右分栏布局：左侧列表 + 右侧参数编辑
```

**修改后**：
```qml
// ✅ 2026-01-25 [模拟量输入页面] 左右分栏布局：左侧列表 + 右侧参数编辑
```

---

### 步骤 3：修改数据模型

**位置**：第15-26行

**修改前**：
```qml
// ========== 开关量保护模型 ==========
ListModel {
    id: digitalProtectionModel
    ListElement { name: "急停"; active: false; moduleType: "输入模块1"; registerAddress: 2; channelNumber: 0 }
    // ... 8个开关量保护
}
```

**修改后**：
```qml
// ========== 模拟量保护模型 ==========
ListModel {
    id: analogProtectionModel
    // 主要保护项
    ListElement { name: "速度"; value: 0.0; unit: "m/s"; active: false; moduleType: "模拟量模块1"; registerAddress: 5 }
    ListElement { name: "张力"; value: 0.0; unit: "T"; active: false; moduleType: "模拟量模块1"; registerAddress: 6 }
    ListElement { name: "红外温度一"; value: 0.0; unit: "℃"; active: false; moduleType: "模拟量模块1"; registerAddress: 7 }
    ListElement { name: "红外温度二"; value: 0.0; unit: "℃"; active: false; moduleType: "模拟量模块1"; registerAddress: 8 }
    ListElement { name: "电流一"; value: 0.0; unit: "A"; active: false; moduleType: "模拟量模块1"; registerAddress: 9 }
    ListElement { name: "电流二"; value: 0.0; unit: "A"; active: false; moduleType: "模拟量模块1"; registerAddress: 10 }
    ListElement { name: "电压"; value: 0.0; unit: "V"; active: false; moduleType: "模拟量模块1"; registerAddress: 11 }

    // 次要保护项
    ListElement { name: "1号电机温度"; value: 0.0; unit: "℃"; active: false; moduleType: "模拟量模块1"; registerAddress: 12 }
    ListElement { name: "2号电机温度"; value: 0.0; unit: "℃"; active: false; moduleType: "模拟量模块2"; registerAddress: 13 }
    ListElement { name: "1号电机X振动"; value: 0.0; unit: "mm/s"; active: false; moduleType: "模拟量模块2"; registerAddress: 14 }
    ListElement { name: "1号电机Y振动"; value: 0.0; unit: "mm/s"; active: false; moduleType: "模拟量模块2"; registerAddress: 15 }
    ListElement { name: "2号电机X振动"; value: 0.0; unit: "mm/s"; active: false; moduleType: "模拟量模块2"; registerAddress: 16 }
    ListElement { name: "2号电机Y振动"; value: 0.0; unit: "mm/s"; active: false; moduleType: "模拟量模块2"; registerAddress: 17 }
    ListElement { name: "1号电机第一项绕组"; value: 0.0; unit: "℃"; active: false; moduleType: "模拟量模块2"; registerAddress: 18 }
    ListElement { name: "1号电机第二项绕组"; value: 0.0; unit: "℃"; active: false; moduleType: "模拟量模块2"; registerAddress: 19 }
    ListElement { name: "1号电机第三项绕组"; value: 0.0; unit: "℃"; active: false; moduleType: "模拟量模块2"; registerAddress: 20 }
    ListElement { name: "2号电机第一项绕组"; value: 0.0; unit: "℃"; active: false; moduleType: "模拟量模块3"; registerAddress: 21 }
    ListElement { name: "2号电机第二项绕组"; value: 0.0; unit: "℃"; active: false; moduleType: "模拟量模块3"; registerAddress: 22 }
    ListElement { name: "2号电机第三项绕组"; value: 0.0; unit: "℃"; active: false; moduleType: "模拟量模块3"; registerAddress: 23 }
}
```

---

### 步骤 4：修改左侧列表标题

**位置**：第53行

**修改前**：
```qml
text: "开关量列表"
```

**修改后**：
```qml
text: "模拟量列表"
```

---

### 步骤 5：修改列表引用

**位置**：第112-115行

**修改前**：
```qml
ListView {
    id: protectionListView
    model: digitalProtectionModel
    spacing: 6
```

**修改后**：
```qml
ListView {
    id: protectionListView
    model: analogProtectionModel
    spacing: 6
```

---

### 步骤 6：修改列表项显示（移除通道编号，添加单位）

**位置**：第157-162行

**修改前**：
```qml
// 通道编号
Text {
    text: "CH" + model.channelNumber
    font.pixelSize: 11
    color: root.currentProtectionIndex === index ? "#CCFFCC" : "#95a5a6"
}
```

**修改后**：
```qml
// 当前值和单位
Text {
    text: model.value.toFixed(1) + model.unit
    font.pixelSize: 11
    font.bold: true
    color: root.currentProtectionIndex === index ? "#CCFFCC" : "#00ff88"
}
```

---

### 步骤 7：修改模块类型ComboBox

**位置**：第274行

**修改前**：
```qml
model: ["输入模块1", "输入模块2", "输入模块3", "输入模块4", "输出模块", "主模块"]
```

**修改后**：
```qml
model: ["模拟量模块1", "模拟量模块2", "模拟量模块3", "模拟量模块4"]
```

---

### 步骤 8：修改寄存器地址自动设置

**位置**：第291-304行

**修改前**：
```qml
onCurrentTextChanged: {
    // 根据模块类型自动设置寄存器地址
    if (currentText === "输入模块1") {
        registerAddressSpin.value = 2
    } else if (currentText === "输入模块2") {
        registerAddressSpin.value = 3
    } // ...
}
```

**修改后**：
```qml
onCurrentTextChanged: {
    // 根据模块类型自动设置寄存器地址
    if (currentText === "模拟量模块1") {
        registerAddressSpin.value = 5
    } else if (currentText === "模拟量模块2") {
        registerAddressSpin.value = 13
    } else if (currentText === "模拟量模块3") {
        registerAddressSpin.value = 21
    } else if (currentText === "模拟量模块4") {
        registerAddressSpin.value = 29
    }
}
```

---

### 步骤 9：删除通道编号字段

**位置**：第348-385行

**删除整个 RowLayout**：
```qml
// 通道编号
RowLayout {
    Layout.fillWidth: true
    spacing: 10

    Text {
        text: "通道编号:"
        // ...
    }

    SpinBox {
        id: channelSpin
        // ...
    }
}
```

---

### 步骤 10：添加模拟量特有字段

**在删除通道编号的位置（第348行）添加以下字段**：

```qml
// 上限值
RowLayout {
    Layout.fillWidth: true
    spacing: 10

    Text {
        text: "上限值:"
        font.pixelSize: 13
        color: "#95a5a6"
        Layout.preferredWidth: 100
    }

    SpinBox {
        id: upperLimitSpin
        from: 0
        to: 100000
        value: 1000
        stepSize: 10
        editable: true
        Layout.fillWidth: true

        property int decimals: 1
        property real realValue: value / 10

        textFromValue: function(value, locale) {
            return Number(value / 10).toLocaleString(locale, 'f', 1)
        }

        valueFromText: function(text, locale) {
            return Number.fromLocaleString(locale, text) * 10
        }

        background: Rectangle {
            color: "#34495e"
            radius: 4
            border.color: upperLimitSpin.activeFocus ? "#3498db" : "#7f8c8d"
            border.width: 1
        }

        contentItem: TextInput {
            text: upperLimitSpin.textFromValue(upperLimitSpin.value, upperLimitSpin.locale)
            font.pixelSize: 12
            color: "#ecf0f1"
            horizontalAlignment: Qt.AlignHCenter
            verticalAlignment: Qt.AlignVCenter
            readOnly: !upperLimitSpin.editable
            validator: upperLimitSpin.validator
            inputMethodHints: Qt.ImhFormattedNumbersOnly
        }
    }
}

// 下限值
RowLayout {
    Layout.fillWidth: true
    spacing: 10

    Text {
        text: "下限值:"
        font.pixelSize: 13
        color: "#95a5a6"
        Layout.preferredWidth: 100
    }

    SpinBox {
        id: lowerLimitSpin
        from: 0
        to: 100000
        value: 0
        stepSize: 10
        editable: true
        Layout.fillWidth: true

        property int decimals: 1
        property real realValue: value / 10

        textFromValue: function(value, locale) {
            return Number(value / 10).toLocaleString(locale, 'f', 1)
        }

        valueFromText: function(text, locale) {
            return Number.fromLocaleString(locale, text) * 10
        }

        background: Rectangle {
            color: "#34495e"
            radius: 4
            border.color: lowerLimitSpin.activeFocus ? "#3498db" : "#7f8c8d"
            border.width: 1
        }

        contentItem: TextInput {
            text: lowerLimitSpin.textFromValue(lowerLimitSpin.value, lowerLimitSpin.locale)
            font.pixelSize: 12
            color: "#ecf0f1"
            horizontalAlignment: Qt.AlignHCenter
            verticalAlignment: Qt.AlignVCenter
            readOnly: !lowerLimitSpin.editable
            validator: lowerLimitSpin.validator
            inputMethodHints: Qt.ImhFormattedNumbersOnly
        }
    }
}

// 量程
RowLayout {
    Layout.fillWidth: true
    spacing: 10

    Text {
        text: "量程:"
        font.pixelSize: 13
        color: "#95a5a6"
        Layout.preferredWidth: 100
    }

    SpinBox {
        id: rangeSpin
        from: 1
        to: 100000
        value: 1000
        stepSize: 10
        editable: true
        Layout.fillWidth: true

        property int decimals: 1
        property real realValue: value / 10

        textFromValue: function(value, locale) {
            return Number(value / 10).toLocaleString(locale, 'f', 1)
        }

        valueFromText: function(text, locale) {
            return Number.fromLocaleString(locale, text) * 10
        }

        background: Rectangle {
            color: "#34495e"
            radius: 4
            border.color: rangeSpin.activeFocus ? "#3498db" : "#7f8c8d"
            border.width: 1
        }

        contentItem: TextInput {
            text: rangeSpin.textFromValue(rangeSpin.value, rangeSpin.locale)
            font.pixelSize: 12
            color: "#ecf0f1"
            horizontalAlignment: Qt.AlignHCenter
            verticalAlignment: Qt.AlignVCenter
            readOnly: !rangeSpin.editable
            validator: rangeSpin.validator
            inputMethodHints: Qt.ImhFormattedNumbersOnly
        }
    }
}

// 额定值
RowLayout {
    Layout.fillWidth: true
    spacing: 10

    Text {
        text: "额定值:"
        font.pixelSize: 13
        color: "#95a5a6"
        Layout.preferredWidth: 100
    }

    SpinBox {
        id: ratedValueSpin
        from: 0
        to: 100000
        value: 500
        stepSize: 10
        editable: true
        Layout.fillWidth: true

        property int decimals: 1
        property real realValue: value / 10

        textFromValue: function(value, locale) {
            return Number(value / 10).toLocaleString(locale, 'f', 1)
        }

        valueFromText: function(text, locale) {
            return Number.fromLocaleString(locale, text) * 10
        }

        background: Rectangle {
            color: "#34495e"
            radius: 4
            border.color: ratedValueSpin.activeFocus ? "#3498db" : "#7f8c8d"
            border.width: 1
        }

        contentItem: TextInput {
            text: ratedValueSpin.textFromValue(ratedValueSpin.value, ratedValueSpin.locale)
            font.pixelSize: 12
            color: "#ecf0f1"
            horizontalAlignment: Qt.AlignHCenter
            verticalAlignment: Qt.AlignVCenter
            readOnly: !ratedValueSpin.editable
            validator: ratedValueSpin.validator
            inputMethodHints: Qt.ImhFormattedNumbersOnly
        }
    }
}

// 单位
RowLayout {
    Layout.fillWidth: true
    spacing: 10

    Text {
        text: "单位:"
        font.pixelSize: 13
        color: "#95a5a6"
        Layout.preferredWidth: 100
    }

    ComboBox {
        id: unitCombo
        Layout.fillWidth: true

        model: ["m/s", "T", "℃", "kW", "A", "V", "MPa", "%", "mm/s"]
        editable: true
        currentIndex: 0

        background: Rectangle {
            color: "#34495e"
            radius: 4
            border.color: unitCombo.pressed ? "#3498db" : "#7f8c8d"
            border.width: 1
        }

        contentItem: TextInput {
            text: unitCombo.editable ? unitCombo.editText : unitCombo.displayText
            font.pixelSize: 12
            color: "#ecf0f1"
            verticalAlignment: Text.AlignVCenter
            leftPadding: 10
            readOnly: !unitCombo.editable
            selectByMouse: true
        }
    }
}

Rectangle {
    Layout.fillWidth: true
    height: 1
    color: "#00d4ff"
    opacity: 0.2
}
```

---

### 步骤 11：修改 loadProtectionData 函数

**位置**：第810-853行

**修改前**：
```qml
function loadProtectionData(index) {
    // ... 开关量加载逻辑
    var protection = deviceConfigMgr.loadDigitalProtection(root.deviceId, item.name)
    // ...
    channelSpin.value = protection.channel_number
}
```

**修改后**：
```qml
function loadProtectionData(index) {
    if (index < 0 || index >= analogProtectionModel.count) {
        return
    }

    var item = analogProtectionModel.get(index)

    // ✅ 2026-01-25 [数据库集成] 从数据库加载完整的保护参数
    var protection = deviceConfigMgr.loadAnalogProtection(root.deviceId, item.name)

    if (protection && protection.protection_name) {
        // 从数据库加载完整参数
        nameField.text = protection.protection_name
        moduleTypeCombo.currentIndex = moduleTypeCombo.model.indexOf(protection.module_type)
        registerAddressSpin.value = protection.register_address
        upperLimitSpin.value = protection.upper_limit * 10
        lowerLimitSpin.value = protection.lower_limit * 10
        rangeSpin.value = protection.range_value * 10
        ratedValueSpin.value = protection.rated_value * 10
        unitCombo.currentIndex = unitCombo.model.indexOf(protection.unit)
        delaySpin.value = protection.protection_delay * 10
        playCountSpin.value = protection.play_count
        durationSpin.value = protection.play_duration * 10
        ttsRadio.checked = protection.use_text_to_speech === 1
        fileRadio.checked = protection.use_text_to_speech === 0
        ttsTextField.text = protection.tts_text || (item.name + "保护报警")
        audioField.text = protection.audio_file || ""

        console.log("✅ [AnalogInputPage] 从数据库加载完整参数:", item.name)
    } else {
        // 数据库中没有，使用ListModel中的基本数据
        nameField.text = item.name
        moduleTypeCombo.currentIndex = moduleTypeCombo.model.indexOf(item.moduleType)
        registerAddressSpin.value = item.registerAddress
        upperLimitSpin.value = 1000
        lowerLimitSpin.value = 0
        rangeSpin.value = 1000
        ratedValueSpin.value = 500
        unitCombo.currentIndex = unitCombo.model.indexOf(item.unit)

        // 设置默认值
        delaySpin.value = 10
        playCountSpin.value = 3
        durationSpin.value = 50
        ttsRadio.checked = true
        ttsTextField.text = item.name + "保护报警"
        audioField.text = ""

        console.log("⚠️ [AnalogInputPage] 数据库中没有详细参数，使用默认值:", item.name)
    }
}
```

---

### 步骤 12：修改 saveProtectionData 函数

**位置**：第855-890行

**修改前**：
```qml
function saveProtectionData() {
    // ...
    digitalProtectionModel.setProperty(...)
    // ...
    var protection = {
        "protection_name": nameField.text,
        "channel_number": channelSpin.value,
        // ...
    }
    deviceConfigMgr.saveDigitalProtection(root.deviceId, protection)
}
```

**修改后**：
```qml
function saveProtectionData() {
    if (root.currentProtectionIndex < 0 || root.currentProtectionIndex >= analogProtectionModel.count) {
        return
    }

    // 更新ListModel
    analogProtectionModel.setProperty(root.currentProtectionIndex, "name", nameField.text)
    analogProtectionModel.setProperty(root.currentProtectionIndex, "moduleType", moduleTypeCombo.currentText)
    analogProtectionModel.setProperty(root.currentProtectionIndex, "registerAddress", registerAddressSpin.value)
    analogProtectionModel.setProperty(root.currentProtectionIndex, "unit", unitCombo.currentText)

    console.log("✅ 保存保护数据到内存:", nameField.text)

    // ✅ 2026-01-25 [数据库集成] 保存到数据库
    var protection = {
        "protection_name": nameField.text,
        "module_type": moduleTypeCombo.currentText,
        "register_address": registerAddressSpin.value,
        "upper_limit": upperLimitSpin.realValue,
        "lower_limit": lowerLimitSpin.realValue,
        "range_value": rangeSpin.realValue,
        "rated_value": ratedValueSpin.realValue,
        "unit": unitCombo.editable ? unitCombo.editText : unitCombo.displayText,
        "protection_delay": delaySpin.realValue,
        "play_count": playCountSpin.value,
        "play_duration": durationSpin.realValue,
        "use_text_to_speech": ttsRadio.checked,
        "tts_text": ttsTextField.text,
        "audio_file": audioField.text
    }

    if (deviceConfigMgr.saveAnalogProtection(root.deviceId, protection)) {
        console.log("✅ [AnalogInputPage] 保存到数据库成功:", nameField.text)
    } else {
        console.error("❌ [AnalogInputPage] 保存到数据库失败:", nameField.text)
    }
}
```

---

### 步骤 13：修改 Component.onCompleted

**位置**：第892-924行

**修改前**：
```qml
Component.onCompleted: {
    console.log("✅ [SwitchInputPage] 开始加载设备", deviceId, "的开关量保护配置")
    var protections = deviceConfigMgr.loadAllDigitalProtections(deviceId)
    // ...
    digitalProtectionModel.clear()
    digitalProtectionModel.append({
        name: p.protection_name,
        channelNumber: p.channel_number
    })
}
```

**修改后**：
```qml
Component.onCompleted: {
    console.log("✅ [AnalogInputPage] 开始加载设备", deviceId, "的模拟量保护配置")

    var protections = deviceConfigMgr.loadAllAnalogProtections(deviceId)
    console.log("✅ [AnalogInputPage] 从数据库加载了", protections.length, "个保护项")

    if (protections.length > 0) {
        // 清空现有模型
        analogProtectionModel.clear()

        // 加载数据库中的配置
        for (var i = 0; i < protections.length; i++) {
            var p = protections[i]
            analogProtectionModel.append({
                name: p.protection_name,
                value: p.current_value || 0.0,
                unit: p.unit,
                active: p.active === 1,
                moduleType: p.module_type,
                registerAddress: p.register_address
            })
        }

        console.log("✅ [AnalogInputPage] 数据库配置加载完成")
    } else {
        console.log("⚠️ [AnalogInputPage] 数据库中没有配置，使用默认配置")
    }

    // 加载第一个保护项的详细参数
    if (analogProtectionModel.count > 0) {
        loadProtectionData(0)
    }
}
```

---

## ✅ 完成后的步骤

### 1. 添加到 CMakeLists.txt

**文件**：`src/qml/CMakeLists.txt`

**位置**：第68行后

**添加**：
```cmake
# ✅ 2026-01-25 [FIX 100.306]: 开关量输入页面
components/device_info/pages/SwitchInputPage.qml
# ✅ 2026-01-25 [FIX 100.308]: 模拟量输入页面
components/device_info/pages/AnalogInputPage.qml
```

### 2. 集成到 DeviceSettingsDialog.qml

**文件**：`src/qml/components/device_info/DeviceSettingsDialog.qml`

**位置**：第319行后（开关量输入页面之后）

**添加**：
```qml
// 2: 模拟量输入
// ✅ 2026-01-25 [FIX 100.308]: 使用 AnalogInputPage 组件
Loader {
    id: analogInputPageLoader
    active: root.currentCategory === 2  // 仅在选中时加载
    source: "pages/AnalogInputPage.qml"

    onLoaded: {
        if (item) {
            console.log("✅ [DeviceSettingsDialog] AnalogInputPage 加载成功")
            item.deviceId = root.deviceId
            item.deviceName = root.deviceName
        }
    }

    onStatusChanged: {
        if (analogInputPageLoader.status === Loader.Error) {
            console.error("❌ [DeviceSettingsDialog] AnalogInputPage 加载失败")
        }
    }
}
```

### 3. 编译测试

```powershell
# 清理缓存
Remove-Item -Recurse -Force build_rk3588

# 重新编译
.\build-ubuntu24-apt.ps1 188
```

---

## 📊 预期结果

编译成功后，应该看到：

```
[DEBUG] ✅ [DeviceSettingsDialog] AnalogInputPage 加载成功
[DEBUG] ✅ [AnalogInputPage] 开始加载设备 X 的模拟量保护配置
[DEBUG] ✅ [AnalogInputPage] 从数据库加载了 7 个保护项
[DEBUG] ✅ [AnalogInputPage] 数据库配置加载完成
```

---

## 🎯 关键修改点总结

1. **数据模型**：`digitalProtectionModel` → `analogProtectionModel`（19个保护项）
2. **数据库调用**：
   - `loadAllDigitalProtections` → `loadAllAnalogProtections`
   - `saveDigitalProtection` → `saveAnalogProtection`
   - `loadDigitalProtection` → `loadAnalogProtection`
3. **字段变化**：
   - 删除：通道编号（channelNumber）
   - 添加：上限值、下限值、量程、额定值、单位
4. **模块类型**：`输入模块1-4` → `模拟量模块1-4`
5. **寄存器地址**：2-5 → 5-29

---

**创建时间**：2026-01-25
**文档版本**：1.0
