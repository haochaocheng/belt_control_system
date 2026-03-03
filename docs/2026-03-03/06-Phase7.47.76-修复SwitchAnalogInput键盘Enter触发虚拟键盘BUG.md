# Phase 7.47.76 - 修复 SwitchInputPage/AnalogInputPage 键盘 Enter 无法触发底部按钮

**日期**: 2026-03-03
**提交**: `b8341f73`
**问题**: 开关量输入/模拟量输入界面，键盘 Enter 键按下后弹出虚拟键盘而非触发底部按钮
**修改文件**:
- `src/qml/components/device_info/pages/SwitchInputPage.qml`
- `src/qml/components/device_info/pages/AnalogInputPage.qml`
- `src/qml/components/device_info/DeviceSettingsDialog.qml`

---

## 一、根因分析

### 1.1 focusSubArea 值不一致

`DeviceSettingsDialog.qml` 的 Enter 键路由逻辑基于 `focusSubArea` 值：

```javascript
if (currentPage.focusSubArea === 2) {
    // → triggerParamInput()（弹出虚拟键盘）
} else if (currentPage.focusSubArea === 3) {
    // → triggerButton()（触发底部按钮）
}
```

各页面 focusSubArea 定义对比：

| 页面 | =0 | =1 | =2 | =3 |
|------|----|----|----|----|
| MotorControlPage | 列表 | Tab | 参数 | **按钮** ✅ |
| SwitchInputPage（修复前） | 列表 | 参数 | **按钮** ❌ | 不存在 |
| AnalogInputPage（修复前） | 列表 | 参数 | **按钮** ❌ | 不存在 |
| SwitchInputPage（修复后） | 列表 | 参数 | — | **按钮** ✅ |
| AnalogInputPage（修复后） | 列表 | 参数 | — | **按钮** ✅ |

### 1.2 双重 Bug

1. **Enter 键路由错误**：`focusSubArea=2` 路由到 `triggerParamInput()`（虚拟键盘），而不是 `triggerButton()`
2. **无法导航到按钮区**：Down 键在参数区末尾没有代码将 `focusSubArea` 设为按钮区值，导致按钮区完全无法通过键盘访问

---

## 二、修复内容

### 2.1 SwitchInputPage.qml

- 属性注释：`2:底部按钮区域` → `3:底部按钮区域`
- 10 处按钮高亮判断：`root.focusSubArea === 2 && root.focusButtonIndex` → `=== 3`

### 2.2 AnalogInputPage.qml

- 属性注释：同上
- 6 处按钮高亮判断：`root.focusSubArea === 2 && root.focusButtonIndex` → `=== 3`

### 2.3 DeviceSettingsDialog.qml（4处）

**变更 A** — Down 键 `focusSubArea===1` "其他页面" 末尾，添加 else 子句：
```javascript
} else {
    // 参数区域下键 → 进入底部按钮区域
    currentPage.focusSubArea = 3
    currentPage.focusButtonIndex = 0
}
```

**变更 B** — Up 键 `focusSubArea===2` "其他页面" else 块：注释掉（成为死代码）

**变更 C** — Up 键 `focusSubArea===3` 块末尾，添加 else 处理其他页面按钮区上键导航：
```javascript
} else {
    // 其他页面（开关量/模拟量）：按钮区上键导航
    // 第二行 → 第一行 / 第一行 → 返回参数区域（focusSubArea=1）
    ...
}
```

**变更 D** — Down 键 `focusSubArea===2` "其他页面"按钮导航：注释掉，移至 `focusSubArea===3` else 块：
```javascript
} else {
    // 其他页面：按钮区下键导航（第一行 → 第二行）
    ...
}
```

---

## 三、Enter 键路由（无需修改）

修复后 `focusSubArea===3` 自动覆盖所有三个页面：

```
MotorControlPage：  focusSubArea=3 → triggerButton() ✅（已有，不变）
SwitchInputPage：   focusSubArea=3 → triggerButton() ✅（修复后）
AnalogInputPage：   focusSubArea=3 → triggerButton() ✅（修复后）
```

---

## 四、键盘导航路径（修复后）

```
SwitchInputPage / AnalogInputPage：

  ① 列表区（focusSubArea=0）
       → [Right] →
  ② 参数区（focusSubArea=1）
       → [Down] →  ← ✅ 新增：之前无此路径
  ③ 按钮区（focusSubArea=3）
       → [Enter] → triggerButton()  ← ✅ 修复：之前触发虚拟键盘
       → [Up] → 返回参数区（focusSubArea=1）  ← ✅ 完整
```

---

## 五、文件修改清单

| 文件 | 修改内容 |
|------|---------|
| `SwitchInputPage.qml` | 注释更新；10处 `=== 2` → `=== 3`（按钮区高亮）|
| `AnalogInputPage.qml` | 注释更新；6处 `=== 2` → `=== 3`（按钮区高亮）|
| `DeviceSettingsDialog.qml` | 4处导航逻辑修改（A/B/C/D）|
