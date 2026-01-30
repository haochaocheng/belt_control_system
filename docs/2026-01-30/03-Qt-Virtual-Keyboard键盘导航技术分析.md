# Qt Virtual Keyboard 键盘导航技术分析

**日期**: 2026-01-30
**状态**: ✅ 分析完成

---

## 🎯 核心发现

### 键盘导航模式

Qt Virtual Keyboard 使用一个 `navigationModeActive` 属性来控制键盘导航模式：

```qml
// Keyboard.qml:62
property bool navigationModeActive: false
```

### 导航光标

使用一个 `navigationCursor` 属性来跟踪当前焦点位置：

```qml
// Keyboard.qml (推断)
property point navigationCursor: Qt.point(-1, -1)
```

---

## 🔍 键盘导航实现原理

### 1. 导航模式激活

**触发条件**：
- 用户按下方向键（上下左右）
- 系统自动激活导航模式

**代码位置**：`Keyboard.qml:1092`
```qml
keyboard.navigationModeActive = true
```

### 2. 导航光标初始化

**首次导航时**，根据方向键确定初始光标位置：

```qml
// Keyboard.qml:1081-1092
if (!keyboard.navigationModeActive || keyboard.navigationCursor === Qt.point(-1, -1)) {
    if (dX > 0)
        navigationCursor = Qt.point(0, height / 2)      // 右键：从左边开始
    else if (dX < 0)
        navigationCursor = Qt.point(width, height / 2)  // 左键：从右边开始
    else if (dY > 0)
        navigationCursor = Qt.point(width / 2, 0)       // 下键：从上边开始
    else if (dY < 0)
        navigationCursor = Qt.point(width / 2, height)  // 上键：从下边开始
    else
        navigationCursor = Qt.point(width / 2, height / 2) // 默认：中心
    keyboard.navigationModeActive = true
}
```

### 3. 导航到下一个按键

**核心函数**：`navigateToNextKey(dX, dY, wrapEnabled)`

**参数**：
- `dX`: 水平方向（-1 = 左，1 = 右，0 = 不移动）
- `dY`: 垂直方向（-1 = 上，1 = 下，0 = 不移动）
- `wrapEnabled`: 是否允许循环（到达边界后回到另一边）

**代码位置**：`Keyboard.qml:1079-1102`

### 4. 查找下一个按键

**核心函数**：`nextKeyInNavigation(dX, dY, wrapEnabled)`

**算法**：
1. 从当前光标位置开始
2. 按照指定方向搜索最近的按键
3. 更新光标位置到新按键的中心
4. 返回找到的按键

---

## 🎨 视觉反馈

### 导航高亮

**组件**：`naviationHighlight`（注意：拼写错误，应该是 navigationHighlight）

**代码位置**：`Keyboard.qml:631`
```qml
visible: keyboard.navigationModeActive && highlightItem !== null && highlightItem !== keyboard
```

**功能**：
- 在导航模式下显示高亮框
- 高亮当前焦点的按键
- 提供视觉反馈

---

## 🔑 按键处理

### 方向键处理

**代码位置**：`Keyboard.qml:157-400`（`onNavigationKeyPressed` 函数）

**支持的按键**：
- `Qt.Key_Left`: 左键
- `Qt.Key_Right`: 右键
- `Qt.Key_Up`: 上键
- `Qt.Key_Down`: 下键
- `Qt.Key_Return` / `Qt.Key_Enter`: 确认键
- `Qt.Key_Escape`: 取消键

### 确认键处理

**代码位置**：`Keyboard.qml:382-410`（`Qt.Key_Return` 分支）

**功能**：
- 如果在导航模式下，"点击"当前高亮的按键
- 如果不在导航模式下，插入换行符

```qml
case Qt.Key_Return:
case Qt.Key_Enter:
    if (!keyboard.navigationModeActive)
        break
    // ... 处理按键点击
```

---

## 🎯 关键技术点

### 1. 焦点管理

**核心概念**：
- `activeKey`: 当前激活的按键
- `initialKey`: 导航开始时的按键
- `highlightItem`: 当前高亮的项目

### 2. 触摸和键盘切换

**触摸时禁用导航模式**：
```qml
// Keyboard.qml:1110
onPressed: (touchPoints) => {
    keyboard.navigationModeActive = false
    // ...
}
```

**原因**：触摸操作和键盘导航互斥

### 3. 候选词导航

**支持在候选词列表中导航**：
- 左右键在候选词间移动
- Enter 键选择当前候选词

**代码位置**：`Keyboard.qml:193-210`

---

## 📋 实施 CuteKeyboard 的关键步骤

### Phase 1: 添加导航模式属性

```qml
// 在 CuteKeyboard 主组件中添加
property bool navigationModeActive: false
property point navigationCursor: Qt.point(-1, -1)
property Item activeKey: null
property Item highlightItem: null
```

### Phase 2: 实现导航函数

```qml
function navigateToNextKey(dX, dY, wrapEnabled) {
    // 1. 初始化导航光标
    if (!navigationModeActive || navigationCursor === Qt.point(-1, -1)) {
        // 根据方向设置初始位置
        navigationModeActive = true
    }

    // 2. 查找下一个按键
    var nextKey = nextKeyInNavigation(dX, dY, wrapEnabled)

    // 3. 更新高亮
    if (nextKey) {
        highlightItem = nextKey
        return true
    }
    return false
}

function nextKeyInNavigation(dX, dY, wrapEnabled) {
    // 从当前光标位置搜索最近的按键
    // 返回找到的按键
}
```

### Phase 3: 添加键盘事件处理

```qml
Keys.onPressed: (event) => {
    switch (event.key) {
    case Qt.Key_Left:
        navigateToNextKey(-1, 0, false)
        event.accepted = true
        break
    case Qt.Key_Right:
        navigateToNextKey(1, 0, false)
        event.accepted = true
        break
    case Qt.Key_Up:
        navigateToNextKey(0, -1, false)
        event.accepted = true
        break
    case Qt.Key_Down:
        navigateToNextKey(0, 1, false)
        event.accepted = true
        break
    case Qt.Key_Return:
    case Qt.Key_Enter:
        if (navigationModeActive && highlightItem) {
            // 触发按键点击
            highlightItem.clicked()
            event.accepted = true
        }
        break
    case Qt.Key_Escape:
        navigationModeActive = false
        event.accepted = true
        break
    }
}
```

### Phase 4: 添加视觉高亮

```qml
Rectangle {
    id: navigationHighlight
    visible: navigationModeActive && highlightItem !== null
    color: "transparent"
    border.color: "#00ff00"  // 绿色高亮
    border.width: 3
    radius: 5

    // 跟随高亮项目的位置和大小
    x: highlightItem ? highlightItem.x : 0
    y: highlightItem ? highlightItem.y : 0
    width: highlightItem ? highlightItem.width : 0
    height: highlightItem ? highlightItem.height : 0

    Behavior on x { NumberAnimation { duration: 150 } }
    Behavior on y { NumberAnimation { duration: 150 } }
    Behavior on width { NumberAnimation { duration: 150 } }
    Behavior on height { NumberAnimation { duration: 150 } }
}
```

---

## 🎯 下一步行动

1. ✅ **Phase 1 完成**：研究 Qt Virtual Keyboard 的键盘导航实现
2. ⏭️ **Phase 2**：研究 Qt Virtual Keyboard 的 PinyinIME 实现
3. ⏭️ **Phase 3**：集成 CuteKeyboard 到项目
4. ⏭️ **Phase 4**：实现键盘导航功能
5. ⏭️ **Phase 5**：集成 PinyinIME 中文输入

---

## 📚 参考文件

- `libs/qtvirtualkeyboard-source/src/components/Keyboard.qml`
- `libs/qtvirtualkeyboard-source/src/components/BaseKey.qml`
- `libs/qtvirtualkeyboard-source/src/components/Key.qml`

---

**创建日期**: 2026-01-30
**状态**: ✅ 分析完成
**下一步**: 研究 PinyinIME 实现
