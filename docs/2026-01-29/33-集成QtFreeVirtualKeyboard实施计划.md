# 集成 QtFreeVirtualKeyboard 实施计划

**日期**: 2026-01-29
**目标**: 集成免费虚拟键盘，支持 QDS、Windows、RK3588

---

## 🎯 实施策略

### 方案：提取纯 QML 组件，移除插件依赖

**原理**：
- QtFreeVirtualKeyboard 的 UI 是纯 QML 实现
- 插件部分只是用于与 Qt 输入法系统集成
- 我们可以提取 QML 组件，直接在应用中使用
- 无需编译插件，纯 QML 实现

---

## 📋 实施步骤

### Phase 1：提取 QML 组件（30分钟）

**任务**：
1. ✅ 复制 QtFreeVirtualKeyboard 的 QML 文件到项目中
2. ✅ 移除对 `FreeVirtualKeyboard 1.0` 插件的依赖
3. ✅ 创建独立的键盘组件
4. ✅ 适配 Qt 6.5.3 语法

**文件清单**：
- `InputPanel.qml` - 主键盘面板
- `KeyButton.qml` - 按键组件
- `KeyModel.qml` - 键盘布局模型
- `KeyPopup.qml` - 字符预览弹窗
- `FontAwesome.otf` - 图标字体

---

### Phase 2：集成到项目（30分钟）

**任务**：
1. ✅ 替换 `EnhancedVirtualKeyboard.qml`
2. ✅ 适配 `VirtualKeyboardManager.qml`
3. ✅ 测试数字键盘模式
4. ✅ 测试英文键盘模式

---

### Phase 3：测试验证（30分钟）

**测试环境**：
1. ✅ QDS 预览
2. ✅ Windows 运行
3. ✅ RK3588 部署

---

## 🔧 技术实现

### 1. 移除插件依赖

**原始代码**（依赖插件）：
```qml
import FreeVirtualKeyboard 1.0

Item {
    onYChanged: InputEngine.setKeyboardRectangle(Qt.rect(x, y, width, height))

    Connections {
        target: InputEngine
        onInputModeChanged: {
            // ...
        }
    }
}
```

**修改后**（纯 QML）：
```qml
// 移除插件导入
// import FreeVirtualKeyboard 1.0

Item {
    // 添加自定义属性
    property var inputEngine: null
    property int inputMode: 0  // 0=Normal, 1=Numeric

    // 移除插件依赖的代码
    // onYChanged: InputEngine.setKeyboardRectangle(...)

    // 使用自定义逻辑
    onInputModeChanged: {
        // ...
    }
}
```

---

### 2. 适配 VirtualKeyboardManager

**集成方式**：
```qml
// VirtualKeyboardManager.qml
function openKeyboardForField(inputField, touchMode) {
    // 确定键盘模式
    var mode = determineKeyboardMode(inputField)

    // 设置键盘模式
    keyboardInstance.inputMode = (mode === "numeric") ? 1 : 0

    // 打开键盘
    keyboardInstance.visible = true
}
```

---

### 3. 键盘布局

**数字键盘**：
```
┌─────────────────────────┐
│ 1   2   3   4   5   6   │
│ 7   8   9   0   -   =   │
│ [   ]   ;   '   ,   .   │
│ [Hide] [Space] [Enter]  │
└─────────────────────────┘
```

**英文键盘**：
```
┌─────────────────────────────────┐
│ q w e r t y u i o p [ ] \       │
│ a s d f g h j k l ; '           │
│ [Shift] z x c v b n m , . [Del] │
│ [Hide] [123] [Space] [Enter]    │
└─────────────────────────────────┘
```

---

## 🎨 美化方案

### 颜色方案（工业控制风格）

```qml
// 背景色
property color backgroundColor: "#0a1628"        // 深蓝黑色
property color keyboardBackground: "#1a2332"    // 键盘背景

// 按键色
property color normalKeyColor: "#34495e"        // 普通按键
property color functionKeyColor: "#2c3e50"      // 功能键
property color pressedKeyColor: "#3d5a80"       // 按下状态

// 文字色
property color textColor: "#ecf0f1"             // 主文字
property color accentColor: "#00d4ff"           // 强调色
```

---

## 📁 文件结构

```
src/qml/components/virtual_keyboard/
├── FreeVirtualKeyboard/              # 新增目录
│   ├── InputPanel.qml                # 主键盘面板
│   ├── KeyButton.qml                 # 按键组件
│   ├── KeyModel.qml                  # 键盘布局模型
│   ├── KeyPopup.qml                  # 字符预览弹窗
│   ├── FontAwesome.otf               # 图标字体
│   └── qmldir                        # QML 模块定义
├── EnhancedVirtualKeyboard.qml       # 保留（备份）
├── VirtualKeyboardManager.qml        # 修改（适配新键盘）
├── NumericKeyboard.qml               # 保留（备份）
└── EnglishKeyboard.qml               # 保留（备份）
```

---

## ⚠️ 关键修改点

### 1. 移除 InputEngine 依赖

**原始代码**：
```qml
Connections {
    target: InputEngine
    onInputModeChanged: {
        pimpl.symbolModifier = ((InputEngine.inputMode == InputEngine.Numeric)
                             || (InputEngine.inputMode == InputEngine.Dialable))
    }
}
```

**修改为**：
```qml
property int inputMode: 0  // 0=Normal, 1=Numeric

onInputModeChanged: {
    pimpl.symbolModifier = (inputMode === 1)
    if (pimpl.symbolModifier) {
        pimpl.shiftModifier = false
    }
}
```

---

### 2. 字符输入处理

**原始代码**（使用插件）：
```qml
KeyButton {
    onClicked: {
        InputEngine.sendKey(text)  // 插件方法
    }
}
```

**修改为**（直接输入）：
```qml
KeyButton {
    property var targetField: null

    onClicked: {
        if (targetField) {
            if (targetField.hasOwnProperty("text")) {
                targetField.text += text
            } else if (targetField.hasOwnProperty("value")) {
                targetField.value = parseInt(targetField.value.toString() + text)
            }
        }
    }
}
```

---

## 🧪 测试计划

### 测试 1：QDS 预览

**步骤**：
1. 启动 QDS
2. 打开设备设置对话框
3. 按回车键弹出键盘
4. 验证键盘显示正常

**预期结果**：
- ✅ 键盘正常显示
- ✅ 按键布局正确
- ✅ 字体图标显示

---

### 测试 2：Windows 运行

**步骤**：
1. 编译 Windows 版本
2. 运行应用
3. 测试虚拟键盘功能

**预期结果**：
- ✅ 键盘正常弹出
- ✅ 输入功能正常
- ✅ 字符预览弹窗正常

---

### 测试 3：RK3588 部署

**步骤**：
1. 交叉编译
2. 部署到设备
3. 测试触摸输入

**预期结果**：
- ✅ 键盘正常显示
- ✅ 触摸输入正常
- ✅ 性能流畅

---

## 🎯 成功标准

### 功能要求

1. ✅ **QDS 显示**：在 Qt Design Studio 中正常预览
2. ✅ **Windows 运行**：在 Windows 上正常运行
3. ✅ **RK3588 部署**：在 RK3588 设备上正常运行
4. ✅ **数字键盘**：支持数字输入
5. ✅ **英文键盘**：支持英文输入
6. ✅ **字符预览**：按键时显示字符预览
7. ✅ **完全免费**：无需购买许可证

### 性能要求

1. ✅ 键盘弹出速度 < 300ms
2. ✅ 按键响应时间 < 100ms
3. ✅ 内存占用 < 10MB

---

## 📝 下一步行动

### 立即开始

**我现在就开始实施**：

1. **Phase 1**：提取 QML 组件（30分钟）
   - 复制文件到项目
   - 移除插件依赖
   - 适配 Qt 6.5.3

2. **Phase 2**：集成到项目（30分钟）
   - 修改 VirtualKeyboardManager
   - 测试基本功能

3. **Phase 3**：测试验证（30分钟）
   - QDS 预览测试
   - Windows 运行测试

---

**预计总时间**：1.5 小时

**成本**：**完全免费** 🆓

**结果**：美观、免费、跨平台的虚拟键盘 ✨

---

**准备好了吗？我现在就开始实施！** 🚀
