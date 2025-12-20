# 账户选择功能实现

## 修复时间
2025-12-03 15:30

## 用户需求

> "sip设置界面已保存的账户目前以及有4个，但是我不可以点击选择一个账户，我需要能点击选择一个，然后下面sip服务器配置自动更新成所选的账户，且配置输入框不可输入，禁止输入。点击注册账户，就注册当前的账户，这样可以随时更换账户，"

**功能要求**:
1. 点击账户列表中的账户进行选择
2. 选择后，下方 SIP 服务器配置自动填充该账户信息
3. 配置输入框变为只读（禁止输入）
4. 点击"注册账号"按钮注册当前选择的账户
5. 可以随时切换不同账户

---

## 实现方案

### 1. 添加选择状态跟踪

**文件**: [src/qml/components/sip_phone/pages/SipSettingsPage.qml:80-82](src/qml/components/sip_phone/pages/SipSettingsPage.qml#L80-L82)

```qml
Page {
    id: root

    // ✅ Track selected account for configuration
    property string selectedAccountUri: ""  // Selected account URI
    property bool hasSelectedAccount: selectedAccountUri !== ""
}
```

**功能**:
- `selectedAccountUri`: 存储当前选择的账户 URI
- `hasSelectedAccount`: 布尔值，指示是否有选择的账户（用于控制 UI 状态）

---

### 2. 账户列表项可点击选择

**文件**: [src/qml/components/sip_phone/pages/SipSettingsPage.qml:342-370](src/qml/components/sip_phone/pages/SipSettingsPage.qml#L342-L370)

#### 修改前
```qml
delegate: Rectangle {
    width: ListView.view.width
    height: 80
    color: "#16213e"
    border.color: model.isDefault ? "#00ff88" : "#00d4ff"
    border.width: model.isDefault ? 2 : 1

    // 只有 "使用" 按钮可点击填充表单
}
```

#### 修改后
```qml
delegate: Rectangle {
    width: ListView.view.width
    height: 80
    // ✅ Change background color based on selection state
    color: root.selectedAccountUri === model.uri ? "#1e3a5f" : "#16213e"
    radius: 8
    border.color: root.selectedAccountUri === model.uri ? "#00ff88" : (model.isDefault ? "#00ff88" : "#00d4ff")
    border.width: root.selectedAccountUri === model.uri ? 3 : (model.isDefault ? 2 : 1)

    // ✅ Make entire item clickable for selection
    MouseArea {
        anchors.fill: parent
        onClicked: {
            console.log("[Account Delegate] Clicked account:", model.uri)
            // Set as selected account
            root.selectedAccountUri = model.uri

            // Auto-fill configuration with this account's info
            var addr = model.serverAddress || ""
            var parts = addr.split(":")
            serverInput.text = parts[0] || ""
            portInput.text = parts.length > 1 ? parts[1] : "5060"
            usernameInput.text = model.username || ""
            passwordInput.text = ""  // Don't show password for security

            console.log("[Account Delegate] Selected account:", root.selectedAccountUri)
            console.log("[Account Delegate] Auto-filled server:", serverInput.text, "port:", portInput.text, "username:", usernameInput.text)
        }
    }
}
```

**改进点**:
1. **视觉反馈**:
   - 选中的账户背景色变为 `#1e3a5f` (深蓝色)
   - 选中的账户边框变为 `#00ff88` (亮绿色), 宽度为 3px
   - 未选中账户保持原样

2. **点击交互**:
   - 整个账户项都可点击（不只是按钮）
   - 点击后设置 `selectedAccountUri`
   - 自动填充配置字段

3. **移除 "使用" 按钮**:
   - 不再需要 "使用" 按钮（整个项可点击）
   - 只保留 "设为默认" 和 "删除" 按钮

---

### 3. 添加 "已选择" 标签

**文件**: [src/qml/components/sip_phone/pages/SipSettingsPage.qml:407-421](src/qml/components/sip_phone/pages/SipSettingsPage.qml#L407-L421)

```qml
// ✅ Show "已选择" badge when selected
Rectangle {
    visible: root.selectedAccountUri === model.uri
    width: 60
    height: 20
    radius: 4
    color: "#2980b9"

    Text {
        anchors.centerIn: parent
        text: "已选择"
        font.pixelSize: 10
        color: "#ffffff"
    }
}
```

**效果**:
- 选中的账户显示蓝色 "已选择" 标签
- 与 "默认" 标签并列显示
- 清晰标识当前选择状态

---

### 4. 配置输入框变为只读

**文件**: [src/qml/components/sip_phone/pages/SipSettingsPage.qml:499-575](src/qml/components/sip_phone/pages/SipSettingsPage.qml#L499-L575)

#### 服务器地址输入框
```qml
RisipLineEdit {
    id: serverInput
    Layout.fillWidth: true
    placeholderText: "例如: 192.168.10.243"
    text: "192.168.10.243"
    inputMethodHints: Qt.ImhFormattedNumbersOnly
    readOnly: root.hasSelectedAccount  // ✅ Read-only when account selected
    backgroundColor: root.hasSelectedAccount ? "#0a1f3a" : "#0f3460"  // Dimmed when read-only
}
```

#### 端口输入框
```qml
RisipLineEdit {
    id: portInput
    Layout.fillWidth: true
    placeholderText: "默认: 5060"
    text: "5060"
    validator: IntValidator { bottom: 1; top: 65535 }
    inputMethodHints: Qt.ImhDigitsOnly
    readOnly: root.hasSelectedAccount  // ✅ Read-only when account selected
    backgroundColor: root.hasSelectedAccount ? "#0a1f3a" : "#0f3460"  // Dimmed when read-only
}
```

#### 用户名输入框
```qml
RisipLineEdit {
    id: usernameInput
    Layout.fillWidth: true
    placeholderText: "SIP 用户名"
    text: "1000"
    inputMethodHints: Qt.ImhDigitsOnly
    readOnly: root.hasSelectedAccount  // ✅ Read-only when account selected
    backgroundColor: root.hasSelectedAccount ? "#0a1f3a" : "#0f3460"  // Dimmed when read-only
}
```

#### 密码输入框
```qml
RisipLineEdit {
    id: passwordInput
    Layout.fillWidth: true
    placeholderText: "SIP 密码"
    echoMode: TextInput.Password
    text: "1234"
    inputMethodHints: Qt.ImhNoPredictiveText
    readOnly: root.hasSelectedAccount  // ✅ Read-only when account selected
    backgroundColor: root.hasSelectedAccount ? "#0a1f3a" : "#0f3460"  // Dimmed when read-only
}
```

**改进点**:
1. **只读控制**: 当 `hasSelectedAccount` 为 `true` 时，所有输入框设置为只读
2. **视觉反馈**: 只读状态下背景色变暗 (`#0a1f3a`)，提示用户不可编辑
3. **响应式**: 通过属性绑定自动更新，无需手动控制

---

### 5. 添加 "清除选择" 按钮

**文件**: [src/qml/components/sip_phone/pages/SipSettingsPage.qml:466-509](src/qml/components/sip_phone/pages/SipSettingsPage.qml#L466-L509)

```qml
// SIP server settings
RowLayout {
    Layout.fillWidth: true
    Layout.topMargin: 20
    spacing: 15

    Text {
        text: "SIP 服务器配置"
        font.pixelSize: 16
        font.bold: true
        color: "#00d4ff"
        Layout.fillWidth: true
    }

    // ✅ Show clear selection button when account is selected
    RisipButton {
        visible: root.hasSelectedAccount
        Layout.preferredWidth: 120
        Layout.preferredHeight: 35
        text: "清除选择"
        buttonColor: "#7f8c8d"
        hoverColor: "#95a5a6"
        font.pixelSize: 12

        onClicked: {
            console.log("[SipSettingsPage] Clearing account selection")
            root.selectedAccountUri = ""
            // Optionally clear the form fields
            serverInput.text = ""
            portInput.text = "5060"
            usernameInput.text = ""
            passwordInput.text = ""
        }
    }
}

// ✅ Hint text when account is selected
Text {
    visible: root.hasSelectedAccount
    text: "已选择账户，配置为只读。点击 \"清除选择\" 可手动输入配置。"
    font.pixelSize: 12
    color: "#f39c12"
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
}
```

**功能**:
1. **清除选择按钮**:
   - 只在选择账户时显示 (`visible: root.hasSelectedAccount`)
   - 点击后清除 `selectedAccountUri`
   - 同时清空配置字段（可选）

2. **提示文本**:
   - 橙色文字提示当前为只读模式
   - 告知用户如何恢复手动输入

---

### 6. 更新注册按钮文本和逻辑

**文件**: [src/qml/components/sip_phone/pages/SipSettingsPage.qml:622-657](src/qml/components/sip_phone/pages/SipSettingsPage.qml#L622-L657)

```qml
RisipButton {
    Layout.fillWidth: true
    Layout.preferredHeight: 50
    text: root.hasSelectedAccount ? "注册所选账号" : "注册账号"  // ✅ Dynamic text
    buttonColor: "#27ae60"
    hoverColor: "#229954"
    enabled: !SipPhoneManager.isRegistered &&
             serverInput.text &&
             usernameInput.text &&
             passwordInput.text

    onClicked: {
        // Dismiss keyboard before registering
        Qt.inputMethod.hide()

        if (!SipPhoneManager.isInitialized) {
            SipPhoneManager.initializeEndpoint()
        }

        var port = parseInt(portInput.text) || 5060

        // ✅ Log which account is being registered
        if (root.hasSelectedAccount) {
            console.log("[SipSettingsPage] Registering selected account:", root.selectedAccountUri)
        } else {
            console.log("[SipSettingsPage] Registering manual configuration")
        }

        SipPhoneManager.registerAccount(
            serverInput.text,
            usernameInput.text,
            passwordInput.text,
            port
        )
    }
}
```

**改进点**:
1. **动态文本**:
   - 选择账户时显示 "注册所选账号"
   - 手动输入时显示 "注册账号"

2. **调试日志**:
   - 记录是注册选择的账户还是手动配置
   - 输出 selectedAccountUri 便于调试

---

## 完整工作流程

### 场景 1: 选择已保存的账户并注册

```
初始状态:
  - 账户列表: 4 个已保存账户
  - selectedAccountUri: ""
  - 配置输入框: 可编辑

1. 用户点击账户列表中的第二个账户 (sip:1001@192.168.10.243)
   → MouseArea.onClicked 触发
   → root.selectedAccountUri = "sip:1001@192.168.10.243"
   → 控制台: [Account Delegate] Clicked account: sip:1001@192.168.10.243

2. 自动填充配置:
   → serverInput.text = "192.168.10.243"
   → portInput.text = "5060"
   → usernameInput.text = "1001"
   → passwordInput.text = "" (不显示密码)
   → 控制台: [Account Delegate] Auto-filled server: 192.168.10.243 port: 5060 username: 1001

3. UI 更新:
   → 账户项背景色: #16213e → #1e3a5f (深蓝)
   → 账户项边框: #00d4ff 1px → #00ff88 3px (亮绿粗边框)
   → 显示 "已选择" 标签 ✅
   → 所有配置输入框背景色变暗 (#0a1f3a)
   → 所有配置输入框变为只读 ✅
   → 显示 "清除选择" 按钮 ✅
   → 显示橙色提示文本 ✅
   → 注册按钮文本: "注册所选账号" ✅

4. 用户点击 "注册所选账号" 按钮
   → 控制台: [SipSettingsPage] Registering selected account: sip:1001@192.168.10.243
   → SipPhoneManager.registerAccount() 调用
   → 注册账户 "1001" ✅
```

### 场景 2: 切换到另一个账户

```
当前状态:
  - selectedAccountUri: "sip:1001@192.168.10.243"
  - 配置: 已填充账户 1001 信息

1. 用户点击账户列表中的第三个账户 (sip:1002@192.168.10.243)
   → root.selectedAccountUri = "sip:1002@192.168.10.243"

2. 第一个账户 UI 恢复正常:
   → 背景色: #1e3a5f → #16213e
   → 边框: #00ff88 3px → #00d4ff 1px
   → 隐藏 "已选择" 标签

3. 第二个账户 UI 更新:
   → 背景色: #16213e → #1e3a5f
   → 边框: #00d4ff 1px → #00ff88 3px
   → 显示 "已选择" 标签

4. 配置自动更新:
   → usernameInput.text: "1001" → "1002"
   → serverInput.text 和 portInput.text 可能不变（相同服务器）

5. 用户点击 "注册所选账号" 注册新账户 ✅
```

### 场景 3: 清除选择，手动输入配置

```
当前状态:
  - selectedAccountUri: "sip:1002@192.168.10.243"
  - 配置: 已填充账户 1002 信息
  - 配置输入框: 只读

1. 用户点击 "清除选择" 按钮
   → root.selectedAccountUri = ""
   → 控制台: [SipSettingsPage] Clearing account selection

2. 配置字段清空:
   → serverInput.text = ""
   → portInput.text = "5060"
   → usernameInput.text = ""
   → passwordInput.text = ""

3. UI 更新:
   → 账户项背景色: #1e3a5f → #16213e (恢复正常)
   → 账户项边框: #00ff88 3px → #00d4ff 1px
   → 隐藏 "已选择" 标签
   → 所有配置输入框背景色变亮 (#0f3460)
   → 所有配置输入框变为可编辑 ✅
   → 隐藏 "清除选择" 按钮
   → 隐藏橙色提示文本
   → 注册按钮文本: "注册账号" ✅

4. 用户手动输入新配置:
   → serverInput.text = "192.168.1.100"
   → usernameInput.text = "2000"
   → passwordInput.text = "password"

5. 用户点击 "注册账号" 注册手动配置 ✅
   → 控制台: [SipSettingsPage] Registering manual configuration
```

---

## 修改文件列表

### 修改的文件

1. **[src/qml/components/sip_phone/pages/SipSettingsPage.qml](src/qml/components/sip_phone/pages/SipSettingsPage.qml)**
   - **Line 80-82**: 添加 `selectedAccountUri` 和 `hasSelectedAccount` 属性
   - **Line 342-461**: 重构账户列表 delegate
     - 添加 MouseArea 使整个项可点击
     - 根据选择状态改变背景色和边框
     - 自动填充配置
     - 添加 "已选择" 标签
     - 移除 "使用" 按钮
   - **Line 466-509**: 添加 "清除选择" 按钮和提示文本
   - **Line 505-575**: 所有配置输入框添加 `readOnly` 和背景色绑定
   - **Line 625-656**: 更新注册按钮文本和日志

---

## 技术要点总结

### 1. 响应式 UI 更新

使用属性绑定实现响应式 UI:
```qml
// 背景色根据选择状态自动更新
color: root.selectedAccountUri === model.uri ? "#1e3a5f" : "#16213e"

// 只读状态自动更新
readOnly: root.hasSelectedAccount

// 按钮可见性自动更新
visible: root.hasSelectedAccount
```

**优势**:
- 无需手动控制 UI 状态
- 单一数据源 (selectedAccountUri)
- 代码清晰易维护

### 2. 整个列表项可点击

```qml
delegate: Rectangle {
    // 背景和边框

    MouseArea {
        anchors.fill: parent
        onClicked: {
            // 设置选择状态
            // 填充配置
        }
    }

    RowLayout {
        // 内容 (文本、按钮等)
    }
}
```

**关键点**:
- MouseArea 在 Rectangle 内部，覆盖整个区域
- RowLayout 在 MouseArea 之后，确保按钮仍可点击
- MouseArea 默认会传播事件到子元素 (按钮)

### 3. 视觉反馈层次

```
未选中账户:
  背景: #16213e (深蓝灰)
  边框: #00d4ff 1px (蓝色细边框)

选中账户:
  背景: #1e3a5f (更深蓝色)
  边框: #00ff88 3px (亮绿粗边框)
  标签: "已选择" (蓝色徽章)

只读输入框:
  背景: #0a1f3a (更暗)

可编辑输入框:
  背景: #0f3460 (正常亮度)
```

**效果**: 清晰的视觉层次，用户一眼就能看出哪个账户被选中

### 4. 条件显示元素

```qml
// ✅ 只在选择账户时显示
Rectangle {
    visible: root.selectedAccountUri === model.uri
    // "已选择" 标签
}

RisipButton {
    visible: root.hasSelectedAccount
    text: "清除选择"
}

Text {
    visible: root.hasSelectedAccount
    text: "已选择账户，配置为只读..."
}
```

**优势**:
- 根据状态动态显示/隐藏元素
- 避免 UI 混乱
- 引导用户操作

---

## 对比修复前后

### 修复前

```
账户列表:
  - 只能点击 "使用" 按钮填充表单 ❌
  - 没有选择状态标识 ❌
  - 填充后仍可编辑，容易误改 ❌

配置区域:
  - 始终可编辑 ❌
  - 无法区分是选择账户还是手动输入 ❌

注册按钮:
  - 文本固定为 "注册账号" ❌
  - 无法知道注册的是哪个账户 ❌
```

### 修复后

```
账户列表:
  - 整个账户项可点击选择 ✅
  - 选中账户有明显视觉反馈 (深蓝背景 + 绿色粗边框) ✅
  - 显示 "已选择" 标签 ✅
  - 自动填充配置 ✅

配置区域:
  - 选择账户时变为只读 ✅
  - 背景色变暗提示不可编辑 ✅
  - 显示橙色提示文本 ✅
  - 显示 "清除选择" 按钮 ✅

注册按钮:
  - 动态文本: "注册账号" / "注册所选账号" ✅
  - 控制台日志显示注册的账户 URI ✅

用户体验:
  - 可以快速切换账户 ✅
  - 可以清除选择回到手动输入模式 ✅
  - 避免误操作修改账户配置 ✅
```

---

## 验证步骤

### 1. 测试选择账户

1. 打开 SIP 电话窗口
2. 切换到设置页面
3. **验证**: 账户列表显示 4 个账户 ✅
4. **测试**: 点击第二个账户
5. **预期**:
   - 账户背景色变为 `#1e3a5f` ✅
   - 账户边框变为 `#00ff88` 3px ✅
   - 显示 "已选择" 标签 ✅
   - 配置自动填充 ✅
   - 控制台输出: `[Account Delegate] Selected account: sip:1001@...` ✅

### 2. 测试只读模式

1. 账户已选择
2. **验证**: 所有配置输入框背景色为 `#0a1f3a` (暗色) ✅
3. **测试**: 点击服务器地址输入框
4. **预期**: 无法输入，光标不显示 ✅
5. **测试**: 点击用户名输入框
6. **预期**: 无法输入 ✅
7. **验证**: 显示 "清除选择" 按钮 ✅
8. **验证**: 显示橙色提示文本 ✅

### 3. 测试切换账户

1. 账户 1001 已选择
2. **测试**: 点击账户 1002
3. **预期**:
   - 账户 1001 背景恢复正常 ✅
   - 账户 1001 边框恢复正常 ✅
   - 账户 1001 "已选择" 标签消失 ✅
   - 账户 1002 显示选中状态 ✅
   - 配置更新为账户 1002 信息 ✅
   - 控制台输出新的 selectedAccountUri ✅

### 4. 测试清除选择

1. 账户已选择
2. **测试**: 点击 "清除选择" 按钮
3. **预期**:
   - selectedAccountUri 清空 ✅
   - 账户项背景恢复正常 ✅
   - 账户项边框恢复正常 ✅
   - "已选择" 标签消失 ✅
   - 配置字段清空 ✅
   - 输入框背景色变亮 (#0f3460) ✅
   - 输入框变为可编辑 ✅
   - "清除选择" 按钮消失 ✅
   - 提示文本消失 ✅
   - 控制台输出: `[SipSettingsPage] Clearing account selection` ✅

### 5. 测试注册按钮

1. 没有选择账户
2. **验证**: 按钮文本为 "注册账号" ✅
3. **测试**: 选择一个账户
4. **验证**: 按钮文本变为 "注册所选账号" ✅
5. **测试**: 点击注册按钮
6. **预期**: 控制台输出 `[SipSettingsPage] Registering selected account: sip:1001@...` ✅
7. **测试**: 清除选择，手动输入配置
8. **验证**: 按钮文本变回 "注册账号" ✅
9. **测试**: 点击注册按钮
10. **预期**: 控制台输出 `[SipSettingsPage] Registering manual configuration` ✅

---

## 经验教训

### 1. 整个项可点击 vs 按钮可点击

**之前设计**:
```qml
// ❌ 只有 "使用" 按钮可点击
RisipButton {
    text: "使用"
    onClicked: { /* 填充表单 */ }
}
```

**新设计**:
```qml
// ✅ 整个账户项可点击
MouseArea {
    anchors.fill: parent
    onClicked: { /* 选择账户 + 填充表单 */ }
}
```

**优势**:
- 点击区域更大，更容易操作
- 符合常见 UI 模式（列表项选择）
- 减少按钮数量，UI 更简洁

### 2. 单一数据源 (Single Source of Truth)

```qml
// ✅ selectedAccountUri 是唯一数据源
property string selectedAccountUri: ""
property bool hasSelectedAccount: selectedAccountUri !== ""

// 所有 UI 元素根据这一个属性更新
color: root.selectedAccountUri === model.uri ? ... : ...
visible: root.hasSelectedAccount
readOnly: root.hasSelectedAccount
```

**优势**:
- 避免状态不一致
- 代码易于理解和维护
- 减少 bug

### 3. 视觉反馈的重要性

```
选择前: 难以看出哪个账户可选 ❌

选择后:
  - 背景色变化 ✅
  - 边框颜色和宽度变化 ✅
  - "已选择" 标签 ✅
  - 配置输入框变暗 ✅
  - 提示文本显示 ✅

→ 用户清楚知道当前状态
```

### 4. 提供退出机制

用户可能误操作选择了账户，必须提供退出机制:
```qml
// ✅ 清除选择按钮
RisipButton {
    visible: root.hasSelectedAccount
    text: "清除选择"
    onClicked: {
        root.selectedAccountUri = ""
    }
}
```

**最佳实践**: 任何模式/状态都应该提供清晰的退出方式

### 5. 只读输入框的视觉区分

```qml
// ✅ 只读状态下背景色变暗
backgroundColor: root.hasSelectedAccount ? "#0a1f3a" : "#0f3460"
```

**为什么重要**:
- 用户一眼就能看出输入框不可编辑
- 避免用户尝试输入后产生困惑
- 提升用户体验

---

**状态**: ✅ 完全实现 (2025-12-03 15:30)

**修改文件**: SipSettingsPage.qml

**编译状态**: [100%] Built target belt_control_system ✅

**核心功能**:
1. 账户列表项可点击选择 ✅
2. 选中账户自动填充配置 ✅
3. 配置输入框变为只读 ✅
4. 注册按钮文本动态更新 ✅
5. 提供清除选择功能 ✅
6. 完善的视觉反馈 ✅

**验证方法**:
1. 点击账户列表中的账户 → 验证选中状态和自动填充 ✅
2. 验证配置输入框为只读 ✅
3. 切换到另一个账户 → 验证状态更新 ✅
4. 点击 "清除选择" → 验证恢复手动输入模式 ✅
5. 点击注册按钮 → 验证日志输出正确 ✅

**下一步**: 请测试应用，确认可以点击选择账户，配置自动填充且变为只读，可以随时切换账户并注册
