# MotorControlPage 导航系统实施计划

**日期**: 2026-01-30
**任务编号**: FIX 100.300.106
**状态**: 🚧 进行中

---

## 🎯 目标

为电机控制页面（MotorControlPage.qml）添加完整的导航系统，参考 AnalogInputPage 的实现。

---

## 📋 当前结构分析

### MotorControlPage.qml
- **布局**: 左右分栏（Row）
- **左侧**: MyMotorListPanel（电机列表，240px宽）
- **右侧**: MotorConfigPanel（配置面板）

### MyMotorListPanel.qml
- **功能**: 显示 8 个电机的列表
- **当前导航**: 已有基本的键盘导航（上下键）
- **需要添加**: 焦点指示器

### MotorConfigPanel.qml
- **功能**: 显示电机配置（10 个 Tab）
- **当前导航**: 已有基本的键盘导航（左右键切换 Tab）
- **需要添加**:
  - 焦点指示器
  - 参数区域导航
  - Qt 虚拟键盘集成

---

## 📝 实施步骤

### Phase 1: 为 MotorControlPage 添加导航属性

**文件**: `src/qml/components/device_info/pages/MotorControlPage.qml`

**需要添加的属性**:
```qml
// ✅ 2026-01-30 [FIX 100.300.106]: 允许接收焦点
focus: true
activeFocusOnTab: true

// ✅ 2026-01-30 [FIX 100.300.106]: 导航焦点索引
property int focusItemIndex: -1  // -1 表示无焦点
property int focusSubArea: 0  // 0:电机列表区域 1:Tab区域 2:参数区域
property int focusTabIndex: 0  // Tab区域焦点索引
property int focusParamIndex: 0  // 参数区域焦点索引

// ✅ 2026-01-30 [FIX 100.300.106]: Qt 虚拟键盘引用
property var virtualKeyboard: null
```

### Phase 2: 为 MyMotorListPanel 添加焦点指示器

**文件**: `src/qml/components/device_info/pages/MyMotorListPanel.qml`

**需要添加**:
1. 接收父页面的焦点状态属性:
```qml
property int focusItemIndex: -1  // 从父页面传递
```

2. 为每个电机项添加焦点指示器:
```qml
// 焦点指示器
Rectangle {
    anchors.fill: parent
    color: "transparent"
    border.color: (focusItemIndex === index) ? "#2196F3" : "transparent"
    border.width: (focusItemIndex === index) ? 3 : 0
    radius: 4
    z: 10
}
```

### Phase 3: 为 MotorConfigPanel 添加 Tab 焦点指示器

**文件**: `src/qml/components/device_info/pages/MotorConfigPanel.qml`

**需要添加**:
1. 接收父页面的焦点状态属性:
```qml
property int focusSubArea: 0  // 从父页面传递
property int focusTabIndex: 0  // 从父页面传递
property int focusParamIndex: 0  // 从父页面传递
property var virtualKeyboard: null  // 从父页面传递
```

2. 为每个 Tab 按钮添加焦点指示器:
```qml
// 焦点指示器
Rectangle {
    anchors.fill: parent
    color: "transparent"
    border.color: (focusSubArea === 1 && focusTabIndex === index) ? "#2196F3" : "transparent"
    border.width: (focusSubArea === 1 && focusTabIndex === index) ? 3 : 0
    radius: 4
    z: 10
}
```

### Phase 4: 为参数区域添加焦点指示器

**需要修改的 Tab 文件**:
- BasicConfigTab.qml（基本配置）
- CurrentProtectionTab.qml（电流保护）
- 其他 8 个 Tab 文件

**修改方式**: 参考 AnalogInputPage 的焦点指示器实现，为每个参数字段添加焦点指示器。

### Phase 5: 添加导航函数

**文件**: `src/qml/components/device_info/pages/MotorControlPage.qml`

**需要添加的函数**:

1. **getParamFieldCount()**:
```qml
function getParamFieldCount() {
    // 根据当前 Tab 返回参数字段数量
    switch(motorConfigPanel.item.currentTabIndex) {
    case 0:  // 基本配置
        return 3  // 3 个 SpinBox
    case 1:  // 电流保护
        return 9  // 待确认
    // ... 其他 Tab
    default:
        return 0
    }
}
```

2. **triggerParamInput(paramIndex)**:
```qml
function triggerParamInput(paramIndex) {
    console.log("✅ [MotorControlPage] 触发参数输入 - 索引:", paramIndex)

    // 调用当前 Tab 的 triggerParamInput 函数
    var currentTab = motorConfigPanel.item.getCurrentTab()
    if (currentTab && typeof currentTab.triggerParamInput === "function") {
        currentTab.triggerParamInput(paramIndex)
    }
}
```

3. **triggerTabSwitch(tabIndex)**:
```qml
function triggerTabSwitch(tabIndex) {
    console.log("✅ [MotorControlPage] 切换 Tab - 索引:", tabIndex)
    motorConfigPanel.item.currentTabIndex = tabIndex
}
```

### Phase 6: 更新 DeviceSettingsDialog 集成

**文件**: `src/qml/components/device_info/DeviceSettingsDialog.qml`

**需要修改的地方**:

1. **motorControlPageLoader 的 onLoaded**（约第1078-1086行）:
```qml
onLoaded: {
    if (item) {
        console.log("✅ [DeviceSettingsDialog] MotorControlPage 加载成功")
        item.deviceId = root.deviceId
        item.deviceName = root.deviceName
        // ✅ 2026-01-30 [FIX 100.300.106]: 传递虚拟键盘引用
        item.virtualKeyboard = qtVirtualKeyboard

        // ✅ 2026-01-30 [FIX 100.300.106]: 设置初始焦点状态
        if (root.currentFocusArea === 2 && root.currentCategory === 3) {
            item.focusSubArea = 0  // 默认焦点在电机列表区域
            item.focusItemIndex = root.currentContentItemIndex
        }
    }
}
```

2. **添加 Connections**（参考 analogInputPageLoader）:
```qml
Connections {
    target: root
    enabled: motorControlPageLoader.item !== null

    function onCurrentFocusAreaChanged() {
        if (motorControlPageLoader.item && root.currentCategory === 3) {
            if (root.currentFocusArea === 2) {
                // 焦点进入内容区域，默认在电机列表区域
                motorControlPageLoader.item.focusSubArea = 0
                motorControlPageLoader.item.focusItemIndex = root.currentContentItemIndex
            } else {
                // 焦点离开内容区域，清除焦点
                motorControlPageLoader.item.focusItemIndex = -1
            }
        }
    }

    function onCurrentCategoryChanged() {
        if (motorControlPageLoader.item) {
            if (root.currentFocusArea === 2 && root.currentCategory === 3) {
                // 切换到电机控制类别，设置焦点
                motorControlPageLoader.item.focusSubArea = 0
                motorControlPageLoader.item.focusItemIndex = root.currentContentItemIndex
            } else {
                // 切换到其他类别，清除焦点
                motorControlPageLoader.item.focusItemIndex = -1
            }
        }
    }

    function onCurrentContentItemIndexChanged() {
        if (motorControlPageLoader.item &&
            root.currentFocusArea === 2 &&
            root.currentCategory === 3) {
            // 在电机列表中导航
            motorControlPageLoader.item.focusItemIndex = root.currentContentItemIndex
        }
    }
}
```

3. **更新 getContentItemCount**（约第1205行）:
```qml
case 3:  // 电机控制
    return 8  // ✅ 2026-01-30 [FIX 100.300.106]: 8个电机
```

4. **更新 getCurrentPage**（约第1279行）:
```qml
case 3:
    return motorControlPageLoader.item
```

---

## 🔍 关键技术点

### 1. 三区域导航系统

**区域定义**:
- `focusSubArea === 0`: 电机列表区域（左侧）
- `focusSubArea === 1`: Tab 区域（顶部 Tab 栏）
- `focusSubArea === 2`: 参数区域（当前 Tab 的参数编辑）

**导航流程**:
1. 打开对话框 → 焦点在左侧类别列表
2. 右键 → 焦点进入电机列表（电机列表区域）
3. 右键 → 焦点进入 Tab 区域（第一个 Tab）
4. 下键 → 焦点进入参数区域（第一个参数）
5. 上/下键 → 在参数间移动
6. 回车键 → 打开虚拟键盘或触发操作
7. ESC 键 → 关闭虚拟键盘，焦点返回参数区域
8. ESC 键 → 关闭对话框，焦点返回主界面

### 2. 焦点指示器

**视觉效果**:
- 蓝色边框（#2196F3）
- 边框宽度：3px
- 圆角：4px
- z-index：10（确保在最上层）

**三种状态**:
1. 电机列表焦点：`focusSubArea === 0 && focusItemIndex === index`
2. Tab 焦点：`focusSubArea === 1 && focusTabIndex === index`
3. 参数焦点：`focusSubArea === 2 && focusParamIndex === index`

### 3. Qt 虚拟键盘集成

**输入模式**:
- `chinese`: 中文输入（电机名称、备注）
- `english`: 英文输入（单位）
- `numeric`: 数字输入（所有 SpinBox）

---

## 📊 预期效果

### 导航流程

1. **打开对话框** → 焦点在左侧类别列表
2. **右键** → 焦点进入电机列表（电机列表区域）
   - 蓝色边框高亮当前选中电机
   - 背景图片切换为 bhNameBK1.png
   - 文字加粗显示
3. **右键** → 焦点进入 Tab 区域（第一个 Tab）
   - 蓝色边框高亮当前 Tab
4. **下键** → 焦点进入参数区域（第一个参数）
   - 蓝色边框高亮当前参数字段
5. **上/下键** → 在参数间移动
   - 焦点指示器跟随移动
6. **回车键** → 打开虚拟键盘
   - 根据字段类型自动选择输入模式
7. **ESC 键** → 关闭虚拟键盘
   - 焦点返回参数区域
8. **ESC 键** → 关闭对话框
   - 焦点返回主界面 Screen01

### 焦点指示器效果

- **蓝色边框**（3px）：清晰标识当前焦点位置
- **背景高亮**：电机列表项选中时背景图片切换
- **文字加粗**：焦点项文字加粗显示
- **平滑过渡**：焦点切换时视觉效果流畅

---

## 🎯 下一步

1. ✅ 创建实施计划文档
2. ⏳ Phase 1: 为 MotorControlPage 添加导航属性
3. ⏳ Phase 2: 为 MyMotorListPanel 添加焦点指示器
4. ⏳ Phase 3: 为 MotorConfigPanel 添加 Tab 焦点指示器
5. ⏳ Phase 4: 为参数区域添加焦点指示器
6. ⏳ Phase 5: 添加导航函数
7. ⏳ Phase 6: 更新 DeviceSettingsDialog 集成
8. ⏳ 测试验证
9. ⏳ 创建完成总结文档

---

**创建日期**: 2026-01-30
**状态**: 🚧 进行中
