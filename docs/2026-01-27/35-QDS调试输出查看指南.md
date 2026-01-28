# QDS 调试输出查看指南

**日期**: 2026-01-27 23:30
**目的**: 在 Qt Design Studio 中查看 console.log() 调试输出
**适用版本**: Qt Design Studio 4.8+

## 🎯 核心问题

在 QDS 中运行 QML 时，`console.log()` 输出在哪里查看？

## ✅ 解决方案

### 方法 1: Application Output 面板（推荐）

**位置**: QDS 底部的 "Application Output" 面板

**步骤**:
1. 运行 QML 项目（点击 ▶️ 或按 Ctrl+R）
2. 查看底部的 **Application Output** 面板
3. 所有 `console.log()` 输出会显示在这里

**面板位置**:
```
Qt Design Studio 界面布局：
┌─────────────────────────────────────┐
│  菜单栏                              │
├─────────────────────────────────────┤
│  工具栏                              │
├──────────┬──────────────────────────┤
│          │                          │
│  组件库  │    设计区域              │
│          │                          │
├──────────┴──────────────────────────┤
│  Application Output 面板  ← 这里！   │
│  [console.log 输出显示在这里]        │
└─────────────────────────────────────┘
```

### 方法 2: 启用详细输出（如果看不到）

**步骤**:
1. 菜单栏 → **Edit** → **Preferences**
2. 左侧选择 **Build & Run** → **Application Output**
3. 确认以下选项已启用：
   - ✅ **Open pane when output arrives**
   - ✅ **Clear old output on a new run**
   - ✅ **Word-wrap output**
   - ✅ **Merge stderr and stdout**

**配置截图位置**:
```
Preferences
├── Build & Run
│   ├── General
│   ├── Kits
│   ├── Qt Versions
│   ├── Compilers
│   ├── Debuggers
│   └── Application Output  ← 点击这里
```

### 方法 3: 使用 QML Debugger（高级）

**启用步骤**:
1. 菜单栏 → **Debug** → **Start Debugging**（F5）
2. 在 **Debugger** 面板中查看输出
3. 可以设置断点和单步调试

**优点**:
- ✅ 可以设置断点
- ✅ 可以查看变量值
- ✅ 可以单步执行

**缺点**:
- ❌ 启动较慢
- ❌ 需要额外配置

## 📝 调试输出最佳实践

### 1. 使用带标签的 console.log

**推荐格式**:
```qml
console.log("[Screen01] 按键:", event.key, "焦点:", activeFocus)
console.log("[Screen01] selectedIndex 变化:", selectedIndex)
console.log("[Screen01] 组件", i, "selected:", item.selected)
```

**优点**:
- ✅ 容易识别输出来源
- ✅ 便于过滤和搜索
- ✅ 多个组件输出不会混淆

### 2. 使用不同的日志级别

```qml
// 普通信息
console.log("[Screen01] 组件加载完成")

// 警告信息
console.warn("[Screen01] 焦点丢失")

// 错误信息
console.error("[Screen01] 无法加载组件")

// 调试信息
console.debug("[Screen01] selectedIndex:", selectedIndex)
```

**输出效果**:
```
[INFO] [Screen01] 组件加载完成
[WARNING] [Screen01] 焦点丢失
[ERROR] [Screen01] 无法加载组件
[DEBUG] [Screen01] selectedIndex: 0
```

### 3. 使用 console.trace() 追踪调用栈

```qml
function updateSelection() {
    console.trace("[Screen01] updateSelection 调用栈")
    // ... 函数逻辑
}
```

**输出**:
```
[Screen01] updateSelection 调用栈
    at updateSelection (Screen01.qml:55)
    at onSelectedIndexChanged (Screen01.qml:66)
    at Keys.onPressed (Screen01.qml:92)
```

### 4. 使用 console.time() 测量性能

```qml
Component.onCompleted: {
    console.time("[Screen01] 初始化耗时")

    // 初始化逻辑
    updateSelection()
    root.forceActiveFocus()

    console.timeEnd("[Screen01] 初始化耗时")
}
```

**输出**:
```
[Screen01] 初始化耗时: 12.5ms
```

## 🔍 常见问题

### 问题 1: Application Output 面板不显示

**原因**: 面板被隐藏或最小化

**解决**:
1. 菜单栏 → **View** → **Output Panes** → **Application Output**
2. 或按快捷键 **Alt+3**
3. 或点击底部状态栏的 **Application Output** 按钮

### 问题 2: 输出太多，难以查找

**解决方案 1**: 使用搜索功能
```
1. 在 Application Output 面板中按 Ctrl+F
2. 输入搜索关键词（如 "[Screen01]"）
3. 使用 F3/Shift+F3 跳转到下一个/上一个匹配
```

**解决方案 2**: 清除旧输出
```
1. 右键点击 Application Output 面板
2. 选择 "Clear"
3. 或在 Preferences 中启用 "Clear old output on a new run"
```

**解决方案 3**: 使用过滤器
```
1. 在 Application Output 面板右上角点击过滤器图标
2. 选择要显示的消息类型：
   - ✅ Info
   - ✅ Warning
   - ✅ Error
   - ⬜ Debug（可选）
```

### 问题 3: 输出显示乱码

**原因**: 编码问题

**解决**:
1. 确保 QML 文件使用 UTF-8 编码
2. 菜单栏 → **Edit** → **Preferences** → **Text Editor** → **Behavior**
3. 设置 **Default encoding** 为 **UTF-8**

### 问题 4: 运行时没有任何输出

**可能原因**:
1. ❌ 程序启动失败
2. ❌ QML 文件有语法错误
3. ❌ console.log 代码未执行

**调试步骤**:
```
1. 检查 Application Output 是否有错误信息
2. 检查 Issues 面板（Alt+1）是否有编译错误
3. 在 Component.onCompleted 中添加测试输出：
   Component.onCompleted: {
       console.log("=== 组件已加载 ===")
   }
4. 如果仍无输出，尝试重启 QDS
```

## 📊 输出示例

### 正常运行的输出

```
Starting E:\2025\3_gongkongji\belt_control_system\src\qml\main_qds.qml...
QML debugging is enabled. Only use this in a safe environment.
[INFO] [Screen01] 组件加载完成，dataItems: 12
[INFO] [Screen01] updateSelection，selectedIndex: 0
[INFO] [Screen01] 组件 0 selected: true
[INFO] [Screen01] 组件 1 selected: false
[INFO] [Screen01] 组件 2 selected: false
...
[INFO] [Screen01] activeFocus: true
```

### 键盘导航的输出

```
[INFO] [Screen01] 按键: 16777235 焦点: true
[INFO] [Screen01] 索引: 0 → 4
[INFO] [Screen01] updateSelection，selectedIndex: 4
[INFO] [Screen01] 组件 0 selected: false
[INFO] [Screen01] 组件 4 selected: true
[INFO] [Screen01] selectedIndex 变化: 4
```

### 错误输出

```
[ERROR] file:///E:/2025/3_gongkongji/belt_control_system/src/qml/Input1/Input1Content/Screen01.qml:37:5: Screen01Form is not defined
[WARNING] QQmlApplicationEngine failed to load component
[ERROR] No root objects loaded!
```

## 🎯 调试工作流程

### 1. 添加调试输出

```qml
Item {
    id: root

    Component.onCompleted: {
        console.log("[Screen01] ✅ 组件加载完成")
        console.log("[Screen01] 📊 dataItems 数量:", screen01Form.dataItems.length)
    }

    onActiveFocusChanged: {
        console.log("[Screen01] 🎯 焦点状态:", activeFocus ? "获得" : "失去")
    }

    Keys.onPressed: function(event) {
        console.log("[Screen01] ⌨️ 按键:", event.key, "焦点:", activeFocus)
    }
}
```

### 2. 运行并观察输出

```
1. 点击 ▶️ 运行
2. 查看 Application Output 面板
3. 观察输出顺序和内容
4. 确认逻辑是否按预期执行
```

### 3. 根据输出调整代码

**示例 1**: 发现焦点问题
```
输出: [Screen01] 🎯 焦点状态: 失去
      [Screen01] ⌨️ 按键: 16777235 焦点: false

分析: 按键时焦点已丢失
解决: 添加 MouseArea 点击获取焦点
```

**示例 2**: 发现组件未更新
```
输出: [Screen01] 索引: 0 → 4
      [Screen01] 组件 4 selected: false  ← 应该是 true

分析: updateSelection() 未正确执行
解决: 检查 dataItems 数组是否正确
```

### 4. 移除调试输出（可选）

**生产环境**:
```qml
// 方法 1: 注释掉
// console.log("[Screen01] 调试信息")

// 方法 2: 使用条件编译
readonly property bool debugMode: false

Component.onCompleted: {
    if (debugMode) {
        console.log("[Screen01] 调试信息")
    }
}
```

## 📚 参考资料

- [Qt Design Studio - Application Output View](https://doc.qt.io/qtdesignstudio/creator-reference-application-output-view.html)
- [Qt Documentation - Debugging QML Applications](https://doc.qt.io/qt-5/qtquick-debugging.html)
- [Qt Forum - Application Output not Visible](https://forum.qt.io/topic/130217/application-output-not-visible-in-qt-design-studio)

## ✅ 检查清单

在开始调试前，确认：

- [ ] Application Output 面板已打开（Alt+3）
- [ ] Preferences 中已启用 "Open pane when output arrives"
- [ ] QML 文件使用 UTF-8 编码
- [ ] console.log() 语句已添加到关键位置
- [ ] 使用了带标签的输出格式（如 "[Screen01]"）
- [ ] 运行项目后可以看到输出

## 🎯 总结

| 项目 | 说明 |
|------|------|
| **输出位置** | 底部 Application Output 面板 |
| **快捷键** | Alt+3 打开面板 |
| **推荐格式** | `console.log("[组件名] 信息")` |
| **搜索** | Ctrl+F 在输出中搜索 |
| **清除** | 右键 → Clear |
| **过滤** | 右上角过滤器图标 |

**下一步**: 在 Screen01.qml 中添加调试输出，运行 QDS，查看 Application Output 面板的输出。

Sources:
- [Qt Design Studio Documentation 4.8.1](https://doc.qt.io/qtdesignstudio/creator-reference-application-output-view.html)
- [Qt Documentation - Debugging QML Applications](https://doc.qt.io/qt-5/qtquick-debugging.html)
- [Qt Forum - Application Output not Visible in Qt Design Studio](https://forum.qt.io/topic/130217/application-output-not-visible-in-qt-design-studio)
