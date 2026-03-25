# Phase 7.48.88.16 - 虚拟键盘弹出时输入框自动滚动

## 日期
2026-03-25

## 问题描述
基本配置页面中，点击输入框弹出虚拟键盘后，输入框被键盘遮挡，用户看不到正在输入的内容。所有输入框都缺少自动滚动处理。

## 修改方案

### 1. BasicConfigPage.qml - ScrollView 改为 Flickable
- 原 `ScrollView` 不支持编程式滚动控制
- 改为 `Flickable`，添加 `ensureVisible(item)` 方法
- 计算逻辑：
  - 获取输入框在 Flickable 内容中的 Y 坐标
  - 获取虚拟键盘高度（`Qt.inputMethod.keyboardRectangle.height`）
  - 可见区域 = Flickable 高度 - 键盘高度
  - 若输入框底部超出可见区域 → 向上滚动
  - 若输入框顶部超出可见区域 → 向下滚动
- 使用 `NumberAnimation` 实现 300ms 平滑滚动
- 底部填充空间从 20px 增加到 350px，确保最后的输入框可以滚动到键盘上方

### 2. BasicParametersSection.qml - ParameterRow 触发滚动
- 新增 `property var flickableParent: null` 属性
- TextField 添加 `onActiveFocusChanged` 事件处理
- 获得焦点时调用 `flickableParent.ensureVisible(inputField)`
- 使用 `Qt.callLater()` 延迟执行，等待键盘弹出动画完成

### 3. BasicConfigPage.qml - 传递 Flickable 引用
- `basicParamsLoader.onLoaded` 中设置 `item.flickableParent = scrollView`
- `networkParamsLoader.onLoaded` 中同样传递（如果属性存在）

## 修改文件

| 文件 | 修改内容 |
|------|---------|
| `src/qml/components/device_info/pages/BasicConfigPage.qml` | ScrollView→Flickable、ensureVisible方法、传递flickable引用、增加底部填充 |
| `src/qml/components/parameter_settings/BasicParametersSection.qml` | 新增flickableParent属性、TextField.onActiveFocusChanged触发滚动 |

## 验证方法
1. 打开基本配置 → 基本参数设置
2. 点击底部的输入框（如"本机名称"）
3. 虚拟键盘弹出后，页面应自动向上滚动，使输入框显示在键盘上方
4. 切换到其他输入框时，页面应自动调整滚动位置
