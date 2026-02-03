# Qt虚拟键盘正确使用方法分析

**日期**: 2026-02-02
**任务编号**: 分析报告
**状态**: ✅ 已完成

---

## 🎯 问题描述

用户指出：**我们选择的是自定义的虚拟键盘，不是Qt官方的虚拟键盘使用方法**

用户提供了Qt官方示例路径：`C:\Qt\Examples\Qt-6.5.3\virtualkeyboard\basic`

---

## 📋 当前架构分析

### 1. Qt虚拟键盘已启用

**文件**: `src/main/main.cpp`
**Line 75-76**:
```cpp
// Enable Qt Virtual Keyboard
qputenv("QT_IM_MODULE", QByteArray("qtvirtualkeyboard"));
```

✅ **Qt虚拟键盘已经正确启用**

### 2. 当前实现方式（自定义Popup）

**文件**: `src/qml/components/virtual_keyboard/QtVirtualKeyboardIntegration.qml`

**问题**：
- 创建了自定义的 Popup 包装 InputPanel
- 需要手动调用 `virtualKeyboard.openForField()`
- 增加了不必要的复杂性

**当前调用方式**：
```qml
// CurrentProtectionTab.qml
function triggerParamInput(paramIndex) {
    var inputField = countSettingField
    var inputMode = "numeric"

    // 手动打开虚拟键盘
    if (virtualKeyboard && inputField) {
        virtualKeyboard.openForField(inputField, function(newValue) {
            console.log("✅ [CurrentProtectionTab] 虚拟键盘输入完成:", newValue)
        }, inputMode, root)
    }
}
```

### 3. Qt官方的正确方式

**参考**: `C:\Qt\Examples\Qt-6.5.3\virtualkeyboard\basic\Basic.qml`

**关键点**：
1. **不需要Popup包装**
2. **不需要手动调用 openForField**
3. **只需要设置 inputMethodHints**
4. **Qt会自动显示虚拟键盘**

**Qt官方示例**：
```qml
TextField {
    id: digitsField
    width: parent.width
    placeholderText: "Digits only field"
    inputMethodHints: Qt.ImhDigitsOnly  // ✅ 只需要这一行
    enterKeyAction: EnterKeyAction.Next
    onAccepted: textArea.focus = true
}
```

**工作原理**：
1. TextField 获得焦点（点击或键盘导航）
2. Qt 检测到 `inputMethodHints: Qt.ImhDigitsOnly`
3. Qt 自动显示纯数字键盘
4. 用户输入完成后，键盘自动隐藏

---

## 🔍 Qt官方示例分析

### main.cpp

```cpp
int main(int argc, char *argv[])
{
    // ✅ 关键：启用Qt虚拟键盘
    qputenv("QT_IM_MODULE", QByteArray("qtvirtualkeyboard"));

    QGuiApplication app(argc, argv);
    QQuickView view(QString("qrc:/%2").arg(MAIN_QML));
    if (view.status() == QQuickView::Error)
        return -1;
    view.setResizeMode(QQuickView::SizeRootObjectToView);

    view.show();

    return app.exec();
}
```

### Basic.qml

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.VirtualKeyboard  // ✅ 导入虚拟键盘模块
import "content"

Rectangle {
    width: 1280
    height: 720
    color: "#F6F6F6"

    Column {
        TextField {
            width: parent.width
            placeholderText: "One line field"
            enterKeyAction: EnterKeyAction.Next
            onAccepted: passwordField.focus = true
        }

        TextField {
            id: phoneNumberField
            width: parent.width
            placeholderText: "Phone number field"
            inputMethodHints: Qt.ImhDialableCharactersOnly  // ✅ 电话号码键盘
            enterKeyAction: EnterKeyAction.Next
        }

        TextField {
            id: digitsField
            width: parent.width
            placeholderText: "Digits only field"
            inputMethodHints: Qt.ImhDigitsOnly  // ✅ 纯数字键盘
            enterKeyAction: EnterKeyAction.Next
        }
    }
}
```

### content/TextField.qml

```qml
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.VirtualKeyboard

Controls.TextField {
    id: control
    color: "#2B2C2E"
    selectionColor: Qt.rgba(0.0, 0.0, 0.0, 0.15)
    selectedTextColor: color
    selectByMouse: true
    font.pixelSize: Qt.application.font.pixelSize * 2

    property int enterKeyAction: EnterKeyAction.None
    readonly property bool enterKeyEnabled: enterKeyAction === EnterKeyAction.None || acceptableInput || inputMethodComposing

    // ✅ 关键：设置 EnterKeyAction
    EnterKeyAction.actionId: control.enterKeyAction
    EnterKeyAction.enabled: control.enterKeyEnabled

    background: Rectangle {
        color: "#FFFFFF"
        border.width: 1
        border.color: control.activeFocus ? "#5CAA15" : "#BDBEBF"
    }
}
```

---

## 📊 两种方式对比

| 特性 | 自定义Popup方式（当前） | Qt官方方式（推荐） |
|------|------------------------|-------------------|
| **复杂度** | 高（需要Popup、openForField） | 低（只需设置inputMethodHints） |
| **代码量** | 多（300+ 行QML） | 少（1行属性） |
| **维护性** | 差（自定义逻辑多） | 好（Qt官方维护） |
| **兼容性** | 可能有问题 | 完全兼容 |
| **自动化** | 需要手动调用 | 自动显示/隐藏 |
| **键盘类型** | 需要手动切换 | Qt自动选择 |

---

## ✅ 正确的实现方式

### 1. 移除自定义Popup

**删除或禁用**：
- `src/qml/components/virtual_keyboard/QtVirtualKeyboardIntegration.qml`
- `src/qml/components/virtual_keyboard/NumericKeyboard.qml`

### 2. 修改 CustomSpinBox

**文件**: `src/qml/components/device_info/CustomSpinBox.qml`

**当前 Line 68**:
```qml
inputMethodHints: Qt.ImhFormattedNumbersOnly
```

**修改为**:
```qml
inputMethodHints: Qt.ImhDigitsOnly  // ✅ 纯数字键盘
```

### 3. 移除手动调用

**文件**: `src/qml/components/device_info/pages/CurrentProtectionTab.qml`

**删除 triggerParamInput() 中的虚拟键盘调用**:
```qml
function triggerParamInput(paramIndex) {
    switch(paramIndex) {
    case 0:  // 是否投入（CustomComboBox）
        enabledField.currentIndex = (enabledField.currentIndex + 1) % enabledField.model.length
        break
    case 2:  // 次数设置（CustomSpinBox）
        if (alarmTypeField.currentIndex === 0) {
            countSettingField.forceActiveFocus()  // ✅ 只需要设置焦点
            // ❌ 删除：virtualKeyboard.openForField(...)
        }
        break
    // ... 其他case
    }
}
```

### 4. 确保 TextField 正确配置

**所有数字输入字段**：
```qml
TextField {
    inputMethodHints: Qt.ImhDigitsOnly  // ✅ 纯数字键盘
    selectByMouse: true

    // 可选：Enter键行为
    Keys.onReturnPressed: {
        // 处理Enter键
    }
}
```

**所有文本输入字段**：
```qml
TextField {
    inputMethodHints: Qt.ImhNoPredictiveText  // ✅ 标准键盘
    selectByMouse: true
}
```

---

## 🎯 Qt.ImhDigitsOnly 的作用

**Qt.ImhDigitsOnly** 是Qt提供的输入法提示标志：

1. **自动选择键盘布局**：
   - Qt的InputPanel会根据这个标志自动选择数字键盘布局
   - 隐藏字母键盘和其他非数字按键

2. **跨平台一致性**：
   - 在不同平台（Windows、Linux、Android、iOS）上都能正确显示数字键盘
   - Qt会根据平台特性自动适配

3. **用户体验**：
   - 用户不需要手动切换键盘布局
   - 直接显示数字键盘，提高输入效率

### 其他可用的输入法提示

| 标志 | 说明 | 键盘布局 |
|------|------|---------| | `Qt.ImhDigitsOnly` | 只允许数字 | 数字键盘（0-9、.、-） |
| `Qt.ImhFormattedNumbersOnly` | 格式化数字 | 数字键盘（0-9、.、-、,） |
| `Qt.ImhDialableCharactersOnly` | 电话号码 | 电话键盘（0-9、+、-、#、*） |
| `Qt.ImhNoPredictiveText` | 禁用预测文本 | 标准键盘 |
| `Qt.ImhPreferLowercase` | 优先小写 | 小写字母键盘 |
| `Qt.ImhPreferUppercase` | 优先大写 | 大写字母键盘 |
| `Qt.ImhNone` | 无限制 | 标准键盘 |

---

## 💡 为什么Qt官方方式更好？

### 1. 简单性

**自定义方式**：
```qml
// 需要创建Popup
Popup {
    id: virtualKeyboard
    // 300+ 行代码
}

// 需要手动调用
function triggerParamInput(paramIndex) {
    virtualKeyboard.openForField(inputField, callback, mode, parent)
}
```

**Qt官方方式**：
```qml
// 只需要一行
TextField {
    inputMethodHints: Qt.ImhDigitsOnly
}
```

### 2. 自动化

**自定义方式**：
- 需要手动检测焦点
- 需要手动打开/关闭键盘
- 需要手动管理键盘状态

**Qt官方方式**：
- Qt自动检测焦点
- Qt自动显示/隐藏键盘
- Qt自动管理键盘状态

### 3. 兼容性

**自定义方式**：
- 可能与Qt更新不兼容
- 可能与其他组件冲突
- 需要自己维护

**Qt官方方式**：
- Qt官方维护
- 完全兼容Qt生态
- 自动适配平台

---

## 📦 实施建议

### 立即修改

1. **修改 CustomSpinBox.qml**:
   - Line 68: `inputMethodHints: Qt.ImhDigitsOnly`

2. **修改 CurrentProtectionTab.qml**:
   - 删除 `virtualKeyboard.openForField()` 调用
   - 只保留 `inputField.forceActiveFocus()`

3. **测试**:
   - 点击数字输入框
   - 检查是否自动弹出纯数字键盘

### 后续优化

1. **移除自定义Popup**:
   - 删除 `QtVirtualKeyboardIntegration.qml`
   - 删除 `NumericKeyboard.qml`

2. **统一所有输入字段**:
   - 所有数字输入：`Qt.ImhDigitsOnly`
   - 所有文本输入：`Qt.ImhNoPredictiveText`

---

## 🔗 相关文档

- Qt官方文档：[Qt Virtual Keyboard](https://doc.qt.io/qt-6/qtvirtualkeyboard-index.html)
- Qt官方示例：`C:\Qt\Examples\Qt-6.5.3\virtualkeyboard\basic`
- [40-FIX100.300.112.8.25.7-使用自定义NumericKeyboard.md](./40-FIX100.300.112.8.25.7-使用自定义NumericKeyboard.md)
- [41-FIX100.300.112.8.25.7.1-使用参数设置界面纯数字键盘设计.md](./41-FIX100.300.112.8.25.7.1-使用参数设置界面纯数字键盘设计.md)

---

**创建日期**: 2026-02-02
**状态**: ✅ 已完成
**编写人员**: Claude Sonnet 4.5
