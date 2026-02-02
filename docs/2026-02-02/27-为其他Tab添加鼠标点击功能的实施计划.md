# 为其他 Tab 添加鼠标点击功能的实施计划

**日期**: 2026-02-02
**任务编号**: FIX 100.300.112.8.24.9
**状态**: 🔄 实施中

---

## 🎯 目标

为其他 9 个 Tab 添加与 BasicConfigTab 一致的鼠标点击功能：
- 添加 `requestFocusParamIndex` 信号
- 为每个参数输入框添加 MouseArea
- 为每个参数输入框添加焦点指示器
- 在 MotorConfigPanel 中连接信号

---

## 📊 Tab 列表和参数数量

| Tab 名称 | 参数数量 | 索引范围 |
|---------|---------|---------|
| CurrentProtectionTab | 9 | 0-8 |
| FrontBearingTempTab | 9 | 0-8 |
| RearBearingTempTab | 9 | 0-8 |
| PhaseAWindingTab | 9 | 0-8 |
| PhaseBWindingTab | 9 | 0-8 |
| PhaseCWindingTab | 9 | 0-8 |
| MotorTempTab | 9 | 0-8 |
| XAxisVibrationTab | 9 | 0-8 |
| YAxisVibrationTab | 9 | 0-8 |

---

## 🔧 修改模板

### 1. 添加信号（每个 Tab）

```qml
// ✅ 2026-02-02 [FIX 100.300.112.8.24.8]: 信号 - 请求更新焦点索引
// 用于鼠标点击时通知父组件，避免直接赋值打破 Qt.binding
signal requestFocusParamIndex(int paramIndex)
```

### 2. 为每个参数添加 MouseArea（每个参数）

```qml
// 参数输入框容器
Item {
    Layout.column: 1
    Layout.row: 0
    Layout.fillWidth: true
    Layout.maximumWidth: 300
    implicitHeight: paramField.implicitHeight

    DeviceInfo.CustomSpinBox {
        id: paramField
        anchors.fill: parent
        // ... 其他属性 ...
    }

    // ✅ 2026-02-02 [FIX 100.300.112.8.24.8]: 鼠标点击发射信号
    MouseArea {
        anchors.fill: parent
        onClicked: function(mouse) {
            console.log("✅ [TabName] 鼠标点击参数X，发射信号: requestFocusParamIndex(X)")
            root.requestFocusParamIndex(X)  // X 是参数索引
            mouse.accepted = false
        }
    }

    // 焦点指示器
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: (root.focusParamIndex === X) ? "#2196F3" : "transparent"
        border.width: (root.focusParamIndex === X) ? 3 : 0
        radius: 4
        z: 1000
        enabled: false
    }
}
```

### 3. 在 MotorConfigPanel 连接信号（每个 Tab）

```qml
Loader {
    id: currentProtectionLoader
    active: root.currentTabIndex === 1
    source: "CurrentProtectionTab.qml"

    onLoaded: {
        if (item) {
            item.motorIndex = root.motorIndex
            item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
            item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })

            // ✅ 2026-02-02 [FIX 100.300.112.8.24.8]: 连接信号
            item.requestFocusParamIndex.connect(function(paramIndex) {
                console.log("✅ [MotorConfigPanel] 转发信号: requestFocusParamIndex(" + paramIndex + ")")
                root.requestFocusParamIndex(paramIndex)
            })
        }
    }
}
```

---

## 💡 实施策略

由于每个 Tab 有 9 个参数，手动添加会非常繁琐。建议采用以下策略：

### 方案 1：逐个 Tab 手动修改（推荐）
- 优点：可以仔细检查每个参数，确保正确
- 缺点：工作量大，耗时较长
- 适用：需要高质量保证的情况

### 方案 2：使用脚本批量生成（快速）
- 优点：快速完成，减少重复劳动
- 缺点：需要仔细验证生成的代码
- 适用：参数结构统一的情况

### 方案 3：先修改一个 Tab，测试通过后再批量修改
- 优点：平衡质量和效率
- 缺点：需要两轮修改
- 适用：当前情况（推荐）

---

## 📦 实施步骤

### Phase 1: 修改 CurrentProtectionTab（测试）

1. ✅ 添加 `requestFocusParamIndex` 信号
2. ⏳ 为 9 个参数添加 MouseArea 和焦点指示器
3. ⏳ 在 MotorConfigPanel 连接信号
4. ⏳ 在 QDS 中测试

### Phase 2: 批量修改其他 8 个 Tab

1. ⏳ 复制 CurrentProtectionTab 的修改模式
2. ⏳ 应用到其他 8 个 Tab
3. ⏳ 在 MotorConfigPanel 连接所有信号
4. ⏳ 全面测试

---

## 🔗 相关文档

- [25-FIX100.300.112.8.24.8-实施完成-修复MouseArea打破Qt绑定问题.md](./25-FIX100.300.112.8.24.8-实施完成-修复MouseArea打破Qt绑定问题.md)
- [26-鼠标点击后导航混乱问题-最终完成总结.md](./26-鼠标点击后导航混乱问题-最终完成总结.md)

---

**创建日期**: 2026-02-02
**状态**: 🔄 实施中
**编写人员**: Claude Sonnet 4.5
