# AnalogInputPage 导航系统实施计划

**日期**: 2026-01-30
**任务编号**: FIX 100.300.105
**状态**: 🚧 进行中

---

## 🎯 目标

为模拟量输入页面（AnalogInputPage.qml）添加完整的导航系统,参考开关量输入页面（SwitchInputPage.qml）的实现。

---

## 📋 参考模板

**SwitchInputPage.qml** 已实现的功能：
1. ✅ 三区域导航（列表、参数、底部按钮）
2. ✅ 两列交叉导航（参数区域）
3. ✅ Qt 虚拟键盘集成
4. ✅ 焦点管理和指示器
5. ✅ 完整的键盘导航逻辑

---

## 📝 实施步骤

### Phase 1: 添加导航属性和焦点管理

**文件**: `src/qml/components/device_info/pages/AnalogInputPage.qml`

**需要添加的属性**:
```qml
// ✅ 2026-01-30 [修复]: 允许接收焦点，以便虚拟键盘关闭后焦点可以返回
focus: true
activeFocusOnTab: true

// ✅ 2026-01-30 [导航系统]: 导航焦点索引（从父对话框传递）
property int focusItemIndex: -1  // -1 表示无焦点
// ✅ 2026-01-30 [导航系统]: 导航子区域（0:列表 1:参数 2:底部按钮）
property int focusSubArea: 0  // 0:列表区域 1:参数区域 2:底部按钮区域
property int focusParamIndex: 0  // 参数区域焦点索引
property int focusButtonIndex: 0  // 底部按钮区域焦点索引

// ✅ 2026-01-30 [Qt 虚拟键盘]: 直接引用虚拟键盘
property var virtualKeyboard: null
```

### Phase 2: 为左侧列表添加焦点指示器

**修改位置**: ListView delegate (约第96-183行)

**需要添加**:
1. 中间属性 `isFocused`:
```qml
readonly property bool isFocused: (root.focusSubArea === 0 && root.focusItemIndex === index)
```

2. 焦点指示器边框:
```qml
border.color: isFocused ? "#2196F3" : "transparent"
border.width: isFocused ? 3 : 0
```

3. 背景图片状态:
```qml
source: isFocused ? "../../../images/bhNameBK1.png" : "../../../images/bhNameBK.png"
```

4. 文字样式:
```qml
font.weight: isFocused ? Font.Bold : Font.Normal
color: isFocused ? "#E0E0E0" : "#9E9E9E"
```

### Phase 3: 统计参数字段数量

**模拟量输入的参数字段**（两列布局）:

**左列**（索引 0, 2, 4, 6, 8, 10, 12）:
0. 保护名称 (TextField)
2. 模块类型 (ComboBox)
4. 寄存器地址 (SpinBox)
6. 通道编号 (SpinBox)
8. 保护延时 (SpinBox)
10. 报警级别 (ComboBox)
12. 备注 (TextField)

**右列**（索引 1, 3, 5, 7, 9, 11）:
1. 单位 (TextField)
3. 上限值 (SpinBox)
5. 下限值 (SpinBox)
7. 保护动作 (ComboBox)
9. 是否启用 (Switch)
11. 当前值显示 (只读)

**总计**: 13 个参数字段

### Phase 4: 为参数区域添加焦点指示器

**修改位置**: 每个参数输入控件的 Item 容器

**需要添加**（以保护名称为例，索引0）:
```qml
// 焦点指示器
Rectangle {
    anchors.fill: parent
    color: "transparent"
    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 0) ? "#2196F3" : "transparent"
    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 0) ? 3 : 0
    radius: 4
    z: 10
}
```

**需要为所有 13 个参数字段添加焦点指示器**。

### Phase 5: 添加底部按钮区域

**参考 SwitchInputPage 的底部按钮布局**:

```qml
// ========== 底部按钮区域 ==========
Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: 80
    color: "transparent"

    // 两行布局
    GridLayout {
        anchors.centerIn: parent
        columns: 2
        rows: 3
        columnSpacing: 20
        rowSpacing: 15

        // 第一行：添加输入、删除输入
        // 第二行：保存、删除、重置
    }
}
```

**按钮索引**:
- 0: 添加输入（第一行左）
- 1: 删除输入（第一行右）
- 2: 保存（第二行左）
- 3: 删除（第二行中）
- 4: 重置（第二行右）

### Phase 6: 添加导航函数

**需要添加的函数**:

1. **getParamFieldCount()**:
```qml
function getParamFieldCount() {
    // 返回参数区域的输入组件数量
    return 13  // 模拟量输入有13个参数字段
}
```

2. **triggerParamInput(paramIndex)**:
```qml
function triggerParamInput(paramIndex) {
    console.log("✅ [AnalogInputPage] 触发参数输入 - 索引:", paramIndex)

    // 根据索引获取对应的输入控件
    var inputField = null
    var inputMode = "numeric"  // 默认数字模式

    switch(paramIndex) {
    case 0:
        inputField = nameField           // 保护名称（TextField）
        inputMode = "chinese"            // 中文输入
        break
    case 1:
        inputField = unitField           // 单位（TextField）
        inputMode = "english"
        break
    // ... 其他字段
    }

    // 打开虚拟键盘
    if (virtualKeyboard && inputField) {
        console.log("✅ [AnalogInputPage] 打开 Qt 虚拟键盘 - 控件:", inputField, "模式:", inputMode)
        virtualKeyboard.openForField(inputField, function(newValue) {
            console.log("✅ [AnalogInputPage] 虚拟键盘输入完成:", newValue)
        }, inputMode, root)
    }
}
```

3. **triggerButton(buttonIndex)**:
```qml
function triggerButton(buttonIndex) {
    console.log("✅ [AnalogInputPage] 触发底部按钮 - 索引:", buttonIndex)

    switch(buttonIndex) {
    case 0:  // 添加输入
        console.log("✅ [AnalogInputPage] 触发：添加输入")
        // TODO: 实现添加输入功能
        break
    case 1:  // 删除输入
        console.log("✅ [AnalogInputPage] 触发：删除输入")
        // TODO: 实现删除输入功能
        break
    case 2:  // 保存
        console.log("✅ [AnalogInputPage] 触发：保存")
        saveProtectionData()
        break
    case 3:  // 删除
        console.log("✅ [AnalogInputPage] 触发：删除")
        // TODO: 实现删除功能
        break
    case 4:  // 重置
        console.log("✅ [AnalogInputPage] 触发：重置")
        // TODO: 实现重置功能
        break
    }
}
```

### Phase 7: 更新 DeviceSettingsDialog

**文件**: `src/qml/components/device_info/DeviceSettingsDialog.qml`

**需要修改的地方**:

1. **analogInputPageLoader 的 onLoaded**（约第1001-1016行）:
```qml
onLoaded: {
    if (item) {
        console.log("✅ [DeviceSettingsDialog] AnalogInputPage 加载成功")
        item.deviceId = root.deviceId
        item.deviceName = root.deviceName
        // ✅ 2026-01-30 [导航系统]: 传递虚拟键盘引用
        item.virtualKeyboard = qtVirtualKeyboard

        // ✅ 2026-01-30 [导航系统]: 设置初始焦点状态
        if (root.currentFocusArea === 2 && root.currentCategory === 2) {
            item.focusSubArea = 0  // 默认焦点在列表区域
            item.focusItemIndex = root.currentContentItemIndex
        }
    }
}
```

2. **添加 Connections**（参考 switchInputPageLoader）:
```qml
Connections {
    target: root
    enabled: analogInputPageLoader.item !== null

    function onCurrentFocusAreaChanged() {
        if (analogInputPageLoader.item && root.currentCategory === 2) {
            if (root.currentFocusArea === 2) {
                // 焦点进入内容区域，默认在列表区域
                analogInputPageLoader.item.focusSubArea = 0
                analogInputPageLoader.item.focusItemIndex = root.currentContentItemIndex
            } else {
                // 焦点离开内容区域，清除焦点
                analogInputPageLoader.item.focusItemIndex = -1
            }
        }
    }

    function onCurrentCategoryChanged() {
        if (analogInputPageLoader.item) {
            if (root.currentFocusArea === 2 && root.currentCategory === 2) {
                // 切换到模拟量输入类别，设置焦点
                analogInputPageLoader.item.focusSubArea = 0
                analogInputPageLoader.item.focusItemIndex = root.currentContentItemIndex
            } else {
                // 切换到其他类别，清除焦点
                analogInputPageLoader.item.focusItemIndex = -1
            }
        }
    }

    function onCurrentContentItemIndexChanged() {
        if (analogInputPageLoader.item &&
            root.currentFocusArea === 2 &&
            root.currentCategory === 2) {
            // 在模拟量列表中导航
            analogInputPageLoader.item.focusItemIndex = root.currentContentItemIndex
        }
    }
}
```

3. **更新 getContentItemCount**（约第1196-1215行）:
```qml
case 2:  // 模拟量输入
    return 5  // 5个模拟量保护项
```

4. **更新 getCurrentPage**（约第1268-1288行）:
```qml
case 2:
    return analogInputPageLoader.item
```

---

## 🔍 关键技术点

### 1. 两列交叉导航

**索引映射**:
- 左列：0, 2, 4, 6, 8, 10, 12（偶数索引）
- 右列：1, 3, 5, 7, 9, 11（奇数索引）

**导航逻辑**:
- 上/下键：同列移动（索引 ±2）
- 左/右键：切换列（索引 ±1）

### 2. 焦点指示器

**三种状态**:
1. 列表区域焦点：`focusSubArea === 0 && focusItemIndex === index`
2. 参数区域焦点：`focusSubArea === 1 && focusParamIndex === index`
3. 底部按钮焦点：`focusSubArea === 2 && focusButtonIndex === index`

### 3. 虚拟键盘集成

**输入模式**:
- `chinese`: 中文输入（保护名称、备注）
- `english`: 英文输入（单位）
- `numeric`: 数字输入（SpinBox）

---

## 📊 预期效果

### 导航流程

1. **打开对话框** → 焦点在左侧类别列表
2. **右键** → 焦点进入模拟量列表（列表区域）
3. **右键** → 焦点进入参数区域（左列第一个参数）
4. **上/下键** → 在同列参数间移动
5. **左/右键** → 在两列间切换
6. **回车键** → 打开虚拟键盘
7. **ESC 键** → 关闭虚拟键盘，焦点返回参数区域
8. **下键到底** → 进入底部按钮区域
9. **ESC 键** → 关闭对话框，焦点返回主界面

### 焦点指示器

- **蓝色边框**（3px）：当前焦点位置
- **背景高亮**：列表项选中状态
- **文字加粗**：焦点项文字加粗

---

## 🎯 下一步

1. ✅ 创建实施计划文档
2. ⏳ 逐步实施修改
3. ⏳ 测试验证
4. ⏳ 创建完成总结文档

---

**创建日期**: 2026-01-30
**状态**: 🚧 进行中

