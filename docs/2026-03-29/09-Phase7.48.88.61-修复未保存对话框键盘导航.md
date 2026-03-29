# Phase 7.48.88.61 - 修复未保存对话框键盘导航

## 修改日期
2026-03-29

## 问题描述
当电机控制有未保存修改时，切换类别会弹出"保存/放弃"对话框。但此时按左右键，焦点不在对话框按钮上，而是仍然在电机配置区域内导航。

**期望行为**：对话框弹出后，所有键盘操作应被对话框拦截，左右键在"保存"和"放弃"按钮间切换，Enter触发当前按钮，Esc放弃修改。

## 根因分析
1. `dialogFocusItem` 接到第一次左右按键后，把焦点转给按钮（`dialogSaveBtn.focus = true`）
2. 按钮本身没有 `Keys.onLeftPressed/onRightPressed` 处理器
3. 键盘事件通过QML事件冒泡机制向上传播到 `root`
4. `root.Keys.onLeftPressed/onRightPressed`（电机配置导航逻辑）拦截了事件
5. 结果：对话框打开时按键仍操作底层电机配置

## 修复方案

### 1. root 键盘处理器顶部拦截（双保险）
在 `root` 的全部6个 `Keys.*` 处理器顶部添加对话框可见性检查：

```qml
// 在 Keys.onUpPressed / onDownPressed / onLeftPressed / onRightPressed / onReturnPressed / onEscapePressed 顶部
if (unsavedChangesDialog.visible) { event.accepted = true; return }
```

### 2. 按钮键盘导航
给两个按钮分别添加完整的键盘事件处理：

| 按键 | 保存按钮 | 放弃按钮 |
|------|----------|----------|
| Left/Right | 切换到对方 | 切换到对方 |
| Enter | 执行保存 | 执行放弃 |
| Esc | 执行放弃 | 执行放弃 |
| Up/Down | 拦截不传播 | 拦截不传播 |

## 修改的文件

### `src/qml/components/device_info/DeviceSettingsDialog.qml`
- `Keys.onUpPressed`：顶部添加 `unsavedChangesDialog.visible` 拦截
- `Keys.onDownPressed`：顶部添加 `unsavedChangesDialog.visible` 拦截
- `Keys.onLeftPressed`：顶部添加 `unsavedChangesDialog.visible` 拦截
- `Keys.onRightPressed`：顶部添加 `unsavedChangesDialog.visible` 拦截
- `Keys.onReturnPressed`：顶部添加 `unsavedChangesDialog.visible` 拦截
- `Keys.onEscapePressed`：顶部添加 `unsavedChangesDialog.visible` 拦截
- `dialogSaveBtn`：添加 Keys 处理器（Left/Right/Enter/Esc/Up/Down）
- `dialogDiscardBtn`：添加 Keys 处理器（Left/Right/Enter/Esc/Up/Down）

## 测试要点
1. 修改电机参数 → 切换到其他类别 → 弹出对话框
2. ���右键在"保存"和"放弃"按钮间切换（蓝色边框跟随）
3. Enter键触发当前高亮按钮的操作
4. Esc键执行放弃操作
5. 上下键不会穿透到底层导航
6. 对话框关闭后，键盘导航恢复正常
