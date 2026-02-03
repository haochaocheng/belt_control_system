# Qt虚拟键盘调试分析 - InputPanel.active不变化

**日期**: 2026-02-02
**状态**: 🔍 调试中

---

## 🔍 当前问题

### 日志分析

**Line 244-246**：
```
Debug: ✅ [CustomSpinBox] activateVirtualKeyboard() 调用
Debug:    - TextInput 获得焦点
Debug:    - 手动调用 Qt.inputMethod.show()
Debug: ✅ [导航] 触发参数输入 - 索引: 2
```

**缺失的日志**：
```
❌ ⌨️ [QDS InputPanel] Active changed: true
```

**说明**：
- ✅ `Qt.inputMethod.show()`被调用了
- ❌ `InputPanel.active`没有变为true
- ❌ 虚拟键盘没有显示

---

## 💡 可能的原因

### 原因1：Qt.inputMethod.show()在QDS预览模式下不工作

**QDS预览模式的限制**：
- QDS使用`qmlpuppet`进程运行QML
- 不是完整的Qt应用程序环境
- `Qt.inputMethod.show()`可能不会触发`InputPanel.active`

### 原因2：需要在main.cpp中设置环境变量

**Qt官方文档要求**：
```cpp
qputenv("QT_IM_MODULE", QByteArray("qtvirtualkeyboard"));
```

**问题**：
- QDS预览模式没有main.cpp
- 无法设置环境变量

### 原因3：InputPanel需要特殊配置

**Qt官方示例中的配置**：
```qml
Binding {
    target: InputContext
    property: "animating"
    value: inputPanelTransition.running
    restoreMode: Binding.RestoreBinding
}
```

**我们缺少**：
- InputContext绑定
- 可能需要其他配置

---

## 🔧 测试方案

### 方案1：直接测试Qt.inputMethod

**在main_qds.qml中添加测试按钮**：
```qml
Button {
    text: "测试虚拟键盘"
    onClicked: {
        console.log("🔍 测试虚拟键盘")
        console.log("   - Qt.inputMethod.visible:", Qt.inputMethod.visible)
        console.log("   - virtualKeyboard.active:", virtualKeyboard.active)
        Qt.inputMethod.show()
        console.log("   - 调用show()后 Qt.inputMethod.visible:", Qt.inputMethod.visible)
        console.log("   - 调用show()后 virtualKeyboard.active:", virtualKeyboard.active)
    }
}
```

### 方案2：使用TextField测试

**创建简单的TextField测试**：
```qml
TextField {
    id: testField
    width: 300
    height: 40
    placeholderText: "点击测试虚拟键盘"
    inputMethodHints: Qt.ImhDigitsOnly

    onActiveFocusChanged: {
        console.log("🔍 TextField activeFocus changed:", activeFocus)
        console.log("   - Qt.inputMethod.visible:", Qt.inputMethod.visible)
        console.log("   - virtualKeyboard.active:", virtualKeyboard.active)
    }
}
```

### 方案3：检查Qt版本和VirtualKeyboard模块

**可能的问题**：
- Qt 6.5.3的VirtualKeyboard模块可能有bug
- QDS预览模式可能不完全支持VirtualKeyboard

---

## 🎯 下一步行动

### 立即测试

1. 添加测试按钮到main_qds.qml
2. 点击按钮，查看日志
3. 确认Qt.inputMethod.show()是否真的被调用
4. 确认InputPanel.active是否变化

### 如果还是不工作

**可能需要回退到自定义虚拟键盘**：
- Qt官方虚拟键盘在QDS预览模式下可能不支持键盘导航
- 自定义虚拟键盘（QtVirtualKeyboardIntegration）是可靠的
- 用户之前说"Qt官方虚拟键盘在QDS能工作"，但可能指的是**鼠标点击**场景

---

**创建日期**: 2026-02-02
**状态**: 🔍 调试中
**编写人员**: Claude Sonnet 4.5
