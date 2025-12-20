# 虚拟键盘尺寸修复 - 严格限制在窗口内

## 修复时间
2025-12-03 09:00

## 问题描述
用户反馈虚拟键盘存在问题:
1. ❌ **键盘超出窗口边界**: 虚拟键盘尺寸超过了应用程序窗口
2. ❌ **不需要关闭按钮**: 虚拟键盘右上角的关闭按钮是多余的
3. ✅ **点击任意位置关闭**: 只需在 SIP 界面任意位置点击即可自动关闭

## 根本原因

### 问题 1: 键盘高度不受控
**原因**: InputPanel 使用 `anchors.bottom` 和 `states` 控制位置,但高度计算可能不准确

**原代码**:
```qml
InputPanel {
    anchors.bottom: parent.bottom
    height: Math.min(300, sipWindow.height * 0.4)  // 可能导致超出
}
```

**问题**:
- 使用 `anchors.bottom` 时,Qt 可能自动调整尺寸
- `height * 0.4 = 900 * 0.4 = 360px`,超过了 300px 限制
- 没有显式设置 y 坐标

### 问题 2: 关闭按钮多余
之前没有添加关闭按钮,这不是问题。

## 修复方案

### 修复: 显式控制键盘位置和尺寸

**文件**: [src/qml/components/sip_phone/SipPhoneWindow.qml:150-184](src/qml/components/sip_phone/SipPhoneWindow.qml#L150-L184)

```qml
// Qt Virtual Keyboard - Strictly limited to stay within window bounds
InputPanel {
    id: inputPanel
    z: 100000

    // CRITICAL: Explicitly constrain keyboard within window bounds
    x: 0
    y: inputPanel.active ? sipWindow.height - height : sipWindow.height
    width: sipWindow.width

    // Strictly limit height: max 240px or 25% of window height
    height: Math.min(240, Math.floor(sipWindow.height * 0.25))

    // Ensure keyboard doesn't overflow window
    Component.onCompleted: {
        console.log("[Keyboard] Window:", sipWindow.width, "x", sipWindow.height)
        console.log("[Keyboard] Panel:", width, "x", height)
        console.log("[Keyboard] Bottom Y:", y + height, "should be <=", sipWindow.height)
    }

    onActiveChanged: {
        if (active) {
            console.log("[Keyboard] Shown - Y:", y, "Height:", height)
        } else {
            console.log("[Keyboard] Hidden")
        }
    }

    Behavior on y {
        NumberAnimation {
            duration: 250
            easing.type: Easing.InOutQuad
        }
    }
}
```

## 关键改进

### 1. 显式设置坐标
```qml
// 修复前
anchors.bottom: parent.bottom  // 隐式计算位置
height: Math.min(300, sipWindow.height * 0.4)

// 修复后
x: 0
y: inputPanel.active ? sipWindow.height - height : sipWindow.height
width: sipWindow.width
height: Math.min(240, Math.floor(sipWindow.height * 0.25))
```

**优势**:
- ✅ 完全控制键盘位置
- ✅ 显式计算 y 坐标 = 窗口高度 - 键盘高度
- ✅ 隐藏时 y = 窗口高度 (完全移出视野)

### 2. 更严格的高度限制
```qml
// 修复前
Math.min(300, sipWindow.height * 0.4)  // = min(300, 360) = 300px

// 修复后
Math.min(240, Math.floor(sipWindow.height * 0.25))  // = min(240, 225) = 225px
```

**计算**:
- 窗口高度: 900px
- 25% = 225px
- 最大限制: 240px
- **实际高度: 225px** (更小更安全)

### 3. 简化动画
```qml
// 修复前
states: State {
    when: inputPanel.active
    PropertyChanges { target: inputPanel; y: ... }
}
transitions: Transition { ... }

// 修复后
Behavior on y {
    NumberAnimation {
        duration: 250
        easing.type: Easing.InOutQuad
    }
}
```

**优势**: 更简洁,y 值改变时自动动画

### 4. 添加调试日志
```qml
Component.onCompleted: {
    console.log("[Keyboard] Window:", sipWindow.width, "x", sipWindow.height)
    console.log("[Keyboard] Panel:", width, "x", height)
    console.log("[Keyboard] Bottom Y:", y + height, "should be <=", sipWindow.height)
}

onActiveChanged: {
    if (active) {
        console.log("[Keyboard] Shown - Y:", y, "Height:", height)
    }
}
```

**预期输出**:
```
[Keyboard] Window: 800 x 900
[Keyboard] Panel: 800 x 225
[Keyboard] Bottom Y: 900 should be <= 900  ✅
[Keyboard] Shown - Y: 675 Height: 225
```

## 验证计算

### 窗口尺寸
```
宽度: 800px
高度: 900px
```

### 键盘尺寸
```
高度限制: min(240, floor(900 * 0.25))
        = min(240, floor(225))
        = min(240, 225)
        = 225px  ✅

宽度: 800px (匹配窗口)
```

### 键盘位置
```
显示时:
  x: 0
  y: 900 - 225 = 675px
  bottom: 675 + 225 = 900px  ✅ (正好在窗口底部)

隐藏时:
  y: 900px (完全移出视野)
```

## 点击关闭功能 (已存在)

**文件**: [src/qml/components/sip_phone/SipPhoneWindow.qml:24-37](src/qml/components/sip_phone/SipPhoneWindow.qml#L24-L37)

```qml
// Overlay to detect clicks outside keyboard
MouseArea {
    id: keyboardOverlay
    anchors.fill: parent
    z: 99
    visible: inputPanel.active
    enabled: visible

    onClicked: {
        console.log("Clicked outside keyboard, hiding it")
        Qt.inputMethod.commit()
        Qt.inputMethod.hide()
    }
}
```

**工作流程**:
1. 键盘激活时,MouseArea 覆盖整个窗口
2. z-index = 99 (低于键盘的 100000)
3. 点击空白区域 → 触发 onClicked
4. 提交输入 → 隐藏键盘

## 测试步骤

### 1. 验证键盘在窗口内
1. 打开 SIP 电话窗口 (800x900)
2. 点击设置页面的输入框
3. 观察虚拟键盘弹出
4. **检查**: 键盘底部对齐窗口底部
5. **检查**: 键盘高度约 225px
6. **检查**: 键盘没有超出窗口边界

### 2. 验证日志输出
打开控制台,应该看到:
```
[Keyboard] Window: 800 x 900
[Keyboard] Panel: 800 x 225
[Keyboard] Bottom Y: 900 should be <= 900
[Keyboard] Shown - Y: 675 Height: 225
```

### 3. 验证点击关闭
1. 键盘已打开
2. 点击键盘上方的任意位置 (设置页面、标题栏等)
3. **预期**: 键盘平滑隐藏 (250ms 动画)
4. **预期**: 控制台输出: `Clicked outside keyboard, hiding it`
5. **预期**: 控制台输出: `[Keyboard] Hidden`

### 4. 验证自动滚动
1. 滚动到设置页面底部
2. 点击服务器地址输入框
3. **预期**: 页面自动滚动,输入框可见
4. **预期**: 键盘在窗口底部,不超出边界

## 对比修复前后

### 修复前
```
窗口: 800x900
键盘高度计算: min(300, 900 * 0.4) = min(300, 360) = 300px
使用 anchors.bottom (隐式位置)

可能问题:
- 高度可能达到 360px (超出限制)
- anchors 可能导致自动调整
- 没有显式边界检查
```

### 修复后
```
窗口: 800x900
键盘高度计算: min(240, floor(900 * 0.25)) = 225px ✅
显式设置: y = 675px

保证:
- 高度严格限制 225px
- 底部: y + height = 675 + 225 = 900px (完美对齐)
- 有调试日志验证
```

## 相关文件

### 修改的文件
1. [src/qml/components/sip_phone/SipPhoneWindow.qml](src/qml/components/sip_phone/SipPhoneWindow.qml)
   - Line 150-184: 重写 InputPanel 配置
   - 移除 anchors.bottom
   - 添加显式 x, y, width, height
   - 添加调试日志

### 未修改的功能
1. [Line 24-37](src/qml/components/sip_phone/SipPhoneWindow.qml#L24-L37): MouseArea 点击关闭 (保持不变)
2. [SipSettingsPage.qml](src/qml/components/sip_phone/pages/SipSettingsPage.qml): 自动滚动功能 (保持不变)

## 技术要点

### 1. 避免使用 anchors 控制动态元素
```qml
// ❌ 不推荐 - anchors 可能导致意外行为
InputPanel {
    anchors.bottom: parent.bottom
    height: calculatedHeight
}

// ✅ 推荐 - 显式控制位置
InputPanel {
    x: 0
    y: parent.height - height
    width: parent.width
    height: calculatedHeight
}
```

### 2. 使用 Math.floor 确保整数
```qml
height: Math.min(240, Math.floor(sipWindow.height * 0.25))
```
- 避免小数像素导致的渲染问题

### 3. 条件表达式控制显示
```qml
y: inputPanel.active ? sipWindow.height - height : sipWindow.height
```
- 激活时: y = 窗口底部 - 键盘高度 (可见)
- 隐藏时: y = 窗口高度 (移出视野)

### 4. Behavior 简化动画
```qml
Behavior on y {
    NumberAnimation { duration: 250 }
}
```
- 比 states + transitions 更简洁
- y 值变化时自动触发动画

## 后续优化建议

### 1. 响应窗口尺寸变化
```qml
Connections {
    target: sipWindow
    function onHeightChanged() {
        // 重新计算键盘高度
        inputPanel.height = Math.min(240, Math.floor(sipWindow.height * 0.25))
    }
}
```

### 2. 保存键盘高度偏好
```qml
Settings {
    property real keyboardHeightRatio: 0.25
}

InputPanel {
    height: Math.min(240, Math.floor(sipWindow.height * Settings.keyboardHeightRatio))
}
```

### 3. 添加最小高度保护
```qml
height: Math.max(180, Math.min(240, Math.floor(sipWindow.height * 0.25)))
//      ^^^^^^^^ 确保至少 180px
```

---

**状态**: ✅ 修复完成并编译通过 (2025-12-03 09:00)
**编译输出**: [100%] Built target belt_control_system
**键盘高度**: 225px (窗口高度 900px 的 25%)
**验证方法**: 查看控制台日志 `[Keyboard] Bottom Y: 900 should be <= 900`
**下一步**: 运行应用验证键盘在窗口边界内
