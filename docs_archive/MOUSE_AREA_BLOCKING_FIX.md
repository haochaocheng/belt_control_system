# MouseArea 拦截点击事件修复

## 修复时间
2025-12-03 09:05

## 问题描述
用户反馈:
1. ❌ 打开应用后点击任何位置都会触发 "Clicked outside keyboard" 日志
2. ❌ 除了部分按键,所有交互都失效
3. ❌ 滑动操作失效

**日志输出**:
```
[DEBUG] Clicked outside keyboard at y: 652.6666666666666
[DEBUG] Clicked outside keyboard at y: 627.3333333333333
[DEBUG] Clicked outside keyboard at y: 646
...
```

## 根本原因

### 问题: 使用了错误的可见性条件

**错误代码** ([SipPhoneWindow.qml:29](src/qml/components/sip_phone/SipPhoneWindow.qml#L29)):
```qml
MouseArea {
    id: keyboardOverlay
    visible: inputPanel.active  // ❌ 错误!
    enabled: visible
}
```

**问题分析**:
1. `inputPanel.active` 可能始终为 `true`
2. InputPanel 是一个组件,不是 Loader
3. `active` 属性不等于 "键盘是否可见"
4. 导致 MouseArea 一直启用,拦截所有事件

### 正确的属性

Qt 提供了专门的 API 来检查虚拟键盘是否可见:
```qml
Qt.inputMethod.visible  // ✅ 正确的属性
```

**文档**:
- `Qt.inputMethod.visible` - 返回虚拟键盘当前是否可见
- `InputPanel.active` - 组件是否激活(不等于可见性)

## 修复方案

### 修复: 使用 Qt.inputMethod.visible

**文件**: [src/qml/components/sip_phone/SipPhoneWindow.qml:24-41](src/qml/components/sip_phone/SipPhoneWindow.qml#L24-L41)

```qml
// Overlay to detect clicks outside keyboard - only when keyboard is visible
MouseArea {
    id: keyboardOverlay
    anchors.fill: parent
    z: 99
    visible: Qt.inputMethod.visible  // ✅ 修复: 使用正确的属性
    enabled: visible

    onVisibleChanged: {
        console.log("[Overlay] Visible:", visible, "Keyboard visible:", Qt.inputMethod.visible)
    }

    onClicked: {
        console.log("[Overlay] Clicked outside keyboard, hiding it")
        Qt.inputMethod.commit()
        Qt.inputMethod.hide()
    }
}
```

**关键改变**:
```qml
// 修复前
visible: inputPanel.active  // ❌

// 修复后
visible: Qt.inputMethod.visible  // ✅
```

## 工作原理

### 修复前的问题流程
```
1. 应用启动
2. InputPanel 组件创建 → inputPanel.active = true (?)
3. MouseArea visible = true → 一直可见
4. MouseArea 拦截所有点击
5. 所有交互失效 ❌
```

### 修复后的正确流程
```
1. 应用启动
2. 键盘未显示 → Qt.inputMethod.visible = false
3. MouseArea visible = false → 禁用
4. 点击正常传递到下层组件 ✅

--- 用户点击输入框 ---

5. 键盘显示 → Qt.inputMethod.visible = true
6. MouseArea visible = true → 启用
7. 点击空白区域 → 触发 onClicked → 隐藏键盘 ✅
```

## 验证步骤

### 1. 测试正常点击
1. 启动应用
2. 打开 SIP 电话窗口
3. 点击各个标签 (拨号、历史、联系人、设置)
4. **预期**: 标签正常切换
5. **预期**: 控制台无 "[Overlay]" 相关日志

### 2. 测试滑动
1. 切换到设置页面
2. 滚动内容区域
3. **预期**: 滚动正常工作
4. **预期**: 无干扰

### 3. 测试键盘显示
1. 点击设置页面的输入框 (账号/密码/服务器)
2. **预期**: 虚拟键盘弹出
3. **预期**: 控制台输出: `[Overlay] Visible: true Keyboard visible: true`

### 4. 测试点击关闭键盘
1. 键盘已显示
2. 点击键盘上方的空白区域
3. **预期**: 键盘隐藏
4. **预期**: 控制台输出: `[Overlay] Clicked outside keyboard, hiding it`
5. **预期**: 控制台输出: `[Overlay] Visible: false Keyboard visible: false`

## 调试日志说明

### 新增的调试日志
```qml
onVisibleChanged: {
    console.log("[Overlay] Visible:", visible, "Keyboard visible:", Qt.inputMethod.visible)
}
```

**预期输出**:

**应用启动时**:
```
[Overlay] Visible: false Keyboard visible: false
```

**点击输入框时**:
```
[Overlay] Visible: true Keyboard visible: true
```

**点击空白区域后**:
```
[Overlay] Clicked outside keyboard, hiding it
[Overlay] Visible: false Keyboard visible: false
```

## 对比主界面的实现

### 主界面 (main.qml)
```qml
Loader {
    id: keyboardLoader
    active: Qt.inputMethod.visible  // ✅ 使用 Qt.inputMethod.visible

    sourceComponent: Item {
        InputPanel {
            id: inputPanel
        }
    }
}

MouseArea {
    visible: inputPanel.active  // ⚠️ 这里可以用,因为在 Loader 内
}
```

**为什么主界面可以用 inputPanel.active?**
- 主界面使用 Loader,只有在 `Qt.inputMethod.visible = true` 时才加载
- 此时 inputPanel 确实 active
- 但我们直接创建 InputPanel,不在 Loader 中,所以不能用 active

### SIP 窗口 (SipPhoneWindow.qml)
```qml
InputPanel {
    id: inputPanel
    // 直接创建,没有 Loader
}

MouseArea {
    visible: Qt.inputMethod.visible  // ✅ 必须用 Qt.inputMethod.visible
}
```

## 相关文件

### 修改的文件
1. [src/qml/components/sip_phone/SipPhoneWindow.qml](src/qml/components/sip_phone/SipPhoneWindow.qml)
   - Line 29: 修改 `visible: inputPanel.active` → `visible: Qt.inputMethod.visible`
   - Line 32-34: 添加调试日志

### 参考文档
1. Qt Documentation: `Qt.inputMethod.visible`
2. Qt Documentation: `InputPanel`
3. [main.qml](src/qml/main.qml) - 主界面的实现 (使用 Loader)

## 技术要点

### 1. InputPanel.active vs Qt.inputMethod.visible

```qml
// InputPanel.active
// - 表示组件是否激活
// - 对于直接创建的 InputPanel,可能始终为 true
// - 不可靠

// Qt.inputMethod.visible
// - 表示虚拟键盘是否实际显示
// - Qt 框架管理,可靠
// - 推荐使用 ✅
```

### 2. MouseArea 的 z-index

```qml
MouseArea {
    z: 99
}

InputPanel {
    z: 100000
}
```

- Overlay 必须在键盘下方 (z < 100000)
- 否则会拦截键盘的点击

### 3. enabled vs visible

```qml
MouseArea {
    visible: Qt.inputMethod.visible
    enabled: visible  // 只有可见时才启用
}
```

- `visible: false` 不显示,但可能仍接收事件
- `enabled: false` 完全禁用事件处理
- 两者结合确保不拦截事件

## 经验教训

### 1. 不同的 QML 组件有不同的 active 语义
- Loader.active - 是否加载组件
- InputPanel.active - 可能不等于可见性
- 使用专门的 API 更可靠

### 2. 调试 MouseArea 问题
添加日志帮助诊断:
```qml
MouseArea {
    onVisibleChanged: console.log("Visible:", visible)
    onEnabledChanged: console.log("Enabled:", enabled)
    onClicked: console.log("Clicked at:", mouse.x, mouse.y)
}
```

### 3. 参考官方文档和示例
- 检查 Qt 文档中推荐的用法
- 对比官方示例代码
- 理解每个属性的准确含义

## 后续优化建议

### 1. 添加更详细的状态日志
```qml
InputPanel {
    onActiveChanged: {
        console.log("[InputPanel] active:", active)
    }
}

Connections {
    target: Qt.inputMethod
    function onVisibleChanged() {
        console.log("[Qt.inputMethod] visible:", Qt.inputMethod.visible)
    }
}
```

### 2. 添加键盘显示动画开始/结束回调
```qml
InputPanel {
    onYChanged: {
        if (y === sipWindow.height - height) {
            console.log("[Keyboard] Fully shown")
        } else if (y === sipWindow.height) {
            console.log("[Keyboard] Fully hidden")
        }
    }
}
```

### 3. 考虑使用 Loader 包装 InputPanel
```qml
Loader {
    active: Qt.inputMethod.visible
    sourceComponent: InputPanel { ... }
}
```
- 只在需要时创建键盘
- 节省资源
- 与主界面实现一致

---

**状态**: ✅ 修复完成并编译通过 (2025-12-03 09:05)
**编译输出**: [100%] Built target belt_control_system
**关键改变**: `inputPanel.active` → `Qt.inputMethod.visible`
**验证方法**: 点击任意位置应该正常工作,只有键盘显示时 overlay 才激活
**下一步**: 测试应用,确认点击和滑动恢复正常
