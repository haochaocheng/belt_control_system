# 问题根本原因分析 - FocusScope 层级问题

**日期**: 2026-01-30
**问题编号**: FIX 100.300.104.6
**状态**: ✅ 已定位根本原因

---

## 🎯 问题根本原因

通过详细的调试日志，我们终于找到了问题的根本原因！

---

## 📊 日志分析

### 关键日志 1：对话框创建时

```
🔍 [Screen01] ========== 打开对话框 ==========
🔍 [Screen01] 对话框创建成功
🔍 [Screen01] dialog.parent === root: true
🔍 [Screen01] dialog.parent: Screen01_QMLTYPE_22(0x1f4bf181160)  ← 正确！
```

**结论**：对话框创建时，`dialog.parent` 确实是 `Screen01`。

### 关键日志 2：对话框关闭时

```
🔍 [DeviceSettingsDialog] ========== ESC 键关闭对话框 ==========
🔍 [DeviceSettingsDialog] 关闭前 - root.parent: QQuickFocusScope(0x1f4f6ed43a0)  ← 问题！
🔍 [DeviceSettingsDialog] 关闭前 - root.parent.activeFocus: true
...
🔍 [DeviceSettingsDialog] forceActiveFocus() 调用完成
🔍 [DeviceSettingsDialog] root.parent.activeFocus: true  ← 焦点返回到 FocusScope，不是 Screen01！
```

**结论**：在 DeviceSettingsDialog 内部，`root.parent` 不是 `Screen01`，而是 `QQuickFocusScope`！

---

## 🔍 层级结构分析

### DeviceSettingsDialog 的实际结构

```qml
Item {
    id: modalContainer  // 最外层容器

    MouseArea {
        id: modalOverlay  // 模态遮罩
    }

    FocusScope {
        id: dialogFocusScope  // ← 这是 root.parent！

        Rectangle {
            id: root  // ← 这是 DeviceSettingsDialog 的 root

            // 对话框内容...
        }
    }
}
```

### 父子关系

```
Screen01 (创建对话框的地方)
  └─ modalContainer (Item)
       └─ dialogFocusScope (FocusScope)  ← root.parent 指向这里！
            └─ root (Rectangle)  ← DeviceSettingsDialog 的 root
```

### 为什么 root.parent 是 FocusScope？

在 DeviceSettingsDialog.qml 中：

```qml
// 第 15 行
Item {
    id: modalContainer

    // 第 46 行
    FocusScope {
        id: dialogFocusScope

        // 第 54 行
        Rectangle {
            id: root  // ← 这是我们在 Keys.onEscapePressed 中使用的 root
            // ...
        }
    }
}
```

**关键点**：
- `root` 是 Rectangle，它的直接父容器是 `dialogFocusScope`（FocusScope）
- 当我们调用 `root.parent.forceActiveFocus()` 时，焦点返回到 `dialogFocusScope`
- `dialogFocusScope` 的父容器是 `modalContainer`
- `modalContainer` 的父容器才是 `Screen01`

---

## 🐛 为什么焦点没有返回到 Screen01？

### 焦点流向（实际情况）

```
对话框打开：
Screen01 (有焦点) → dialogFocusScope (有焦点) → root (有焦点)

对话框关闭（修复前）：
root.parent.forceActiveFocus()
↓
dialogFocusScope (有焦点) ← 焦点停在这里！
↓
Screen01 (无焦点) ← 导航键不起作用
```

### 为什么 dialogFocusScope 有焦点，但导航键不起作用？

1. `dialogFocusScope` 是 FocusScope，它本身不处理键盘事件
2. `dialogFocusScope` 内部的 `root` (Rectangle) 已经 `visible = false`
3. 焦点被"困"在 `dialogFocusScope` 中，无法传递到 Screen01
4. Screen01 没有焦点，所以导航键不起作用

---

## ✅ 解决方案

### 方案 1：保存 Screen01 的引用（推荐）

在 DeviceSettingsDialog 中添加一个属性来保存创建它的父容器：

```qml
Rectangle {
    id: root

    // ✅ 添加属性保存真正的父容器（Screen01）
    property var parentContainer: null

    Keys.onEscapePressed: {
        root.visible = false

        // 使用保存的父容器引用
        if (parentContainer) {
            parentContainer.forceActiveFocus()
        }
    }
}
```

在 Screen01.qml 中创建对话框时传递引用：

```qml
function openDeviceSettings() {
    var dialog = component.createObject(root, {
        parentContainer: root  // ← 传递 Screen01 的引用
    })
}
```

### 方案 2：使用 modalContainer.parent

```qml
Keys.onEscapePressed: {
    root.visible = false

    // modalContainer 是最外层容器，它的 parent 是 Screen01
    if (modalContainer.parent) {
        modalContainer.parent.forceActiveFocus()
    }
}
```

### 方案 3：重构 DeviceSettingsDialog 结构

移除 FocusScope，直接使用 Item：

```qml
Item {
    id: modalContainer

    MouseArea {
        id: modalOverlay
    }

    Rectangle {
        id: root  // ← 现在 root.parent 是 modalContainer

        Keys.onEscapePressed: {
            root.visible = false

            // modalContainer.parent 是 Screen01
            if (modalContainer.parent) {
                modalContainer.parent.forceActiveFocus()
            }
        }
    }
}
```

---

## 🎯 推荐方案

**推荐使用方案 1**：保存 Screen01 的引用

**理由**：
1. ✅ 最清晰明确：直接保存父容器引用
2. ✅ 不依赖层级结构：即使结构改变也能正常工作
3. ✅ 易于理解和维护
4. ✅ 不需要重构现有代码

---

## 📝 实施步骤

1. 在 DeviceSettingsDialog.qml 中添加 `parentContainer` 属性
2. 在所有关闭处使用 `parentContainer.forceActiveFocus()`
3. 在 Screen01.qml 的 `openDeviceSettings()` 中传递 `root` 引用
4. 测试验证

---

## 🎨 为什么之前的修复都失败了？

### FIX 100.300.104.3 - 添加 root.parent.forceActiveFocus()

```qml
Keys.onEscapePressed: {
    root.visible = false
    root.parent.forceActiveFocus()  // ← 焦点返回到 dialogFocusScope，不是 Screen01
}
```

**失败原因**：`root.parent` 是 `dialogFocusScope`，不是 `Screen01`。

### FIX 100.300.104.4 - 修改对话框父容器

```qml
var dialog = component.createObject(root, {})  // ← modalContainer.parent 是 Screen01
```

**失败原因**：虽然 `modalContainer.parent` 是 `Screen01`，但我们在关闭时使用的是 `root.parent`（dialogFocusScope），不是 `modalContainer.parent`。

---

## 🎯 总结

### 问题

- ❌ `root.parent` 是 `dialogFocusScope`（FocusScope），不是 `Screen01`
- ❌ 焦点返回到 `dialogFocusScope`，被"困"在 FocusScope 中
- ❌ Screen01 没有焦点，导航键不起作用

### 解决

- ✅ 保存 Screen01 的引用到 `parentContainer` 属性
- ✅ 关闭时使用 `parentContainer.forceActiveFocus()`
- ✅ 焦点正确返回到 Screen01

---

**完成日期**: 2026-01-30
**状态**: ✅ 已定位根本原因
**下一步**: 实施修复方案
