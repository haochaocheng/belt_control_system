# Phase 7.48.75 - 修复张紧控制导航与虚拟键盘滚动

## 修复日期
2026-03-22

## 问题描述

### 问题1：导航键不完整
TensionControlPage.qml 中从按钮区域按Up键返回参数区域时，张紧控制面板的最后索引设为5（旧的6参数布局），但Phase 7.48.74后已扩展为9个参数(0-8)。

### 问题2：虚拟键盘遮挡输入框
TensionSensorConfigPanel 和 TensionControlConfigPanel 都没有 ScrollView/Flickable 包裹，虚拟键盘弹出时底部输入框被遮挡。

### 问题3：按回车键无反应
在需要输入的参数上按Enter键时，没有弹出虚拟键盘（ensureVisible逻辑缺失）。

## 修改文件

### 1. TensionControlPage.qml (行246)
- 旧：`paramIndex = (root.currentControlIndex === 0) ? 14 : 5`
- 新：`paramIndex = (root.currentControlIndex === 0) ? 14 : 8`
- 原因：张紧控制参数从6个(0-5)扩展为9个(0-8)后，Up键返回的最后索引需要更新

### 2. TensionSensorConfigPanel.qml
1. **ScrollView 包裹**：在 ColumnLayout 外层添加 ScrollView，clip: true
2. **动态 contentHeight**：`contentArea.implicitHeight + (Qt.inputMethod.visible ? kbRect.height : 0)`
3. **ensureVisible 函数**：虚拟键盘弹出时自动滚动，使用与 BrakeConfigPanel 相同的算法：
   - 使用 `item.mapToItem(null, 0, 0)` 获取窗口绝对坐标
   - 始终用 `kbTop = screenHeight - kbRect.height` 计算键盘顶部
   - `safeBottom = kbTop - 60` 留出安全边距
4. **Connections 监听**：`Qt.inputMethod.onVisibleChanged` 自动触发 ensureVisible

### 3. TensionControlConfigPanel.qml
与 TensionSensorConfigPanel 相同的修改：
1. ScrollView 包裹
2. 动态 contentHeight
3. ensureVisible 函数
4. Connections 监听

## 参数索引（当前状态）

### 张力传感器 (15个参数, 0-14)
| 行 | 字段 |
|----|------|
| 0 | 名称(0) + 播放次数(1) |
| 1 | 模块类型(2) + 播放时长(3) |
| 2 | 通道号(4) + 上限值(5) |
| 3 | 下限值(6) + 量程(7) |
| 4 | 单位(8) + 输入类型(9) |
| 5 | 保护延时(10) + 保护级别(11) |
| 6 | TTS文本(12) + 音频文件(13) |
| 7 | 洒水编号(14) |

### 张紧控制 (9个参数, 0-8)
| 行 | 字段 |
|----|------|
| 0 | 张紧启用(0) + 输出通道(1) |
| 1 | 使用反馈(2) + 反馈通道(3) |
| 2 | 反馈超时(4) + 启动延时(5) |
| 3 | 停止延时(6) |
| 4 | 预警语音(7) |
| 5 | 失败语音(8) |

## 验证要点
1. 键盘导航覆盖所有参数（上下左右键）
2. 从按钮区域按Up键正确返回最后一个参数
3. 按Enter键在输入字段弹出虚拟键盘
4. 虚拟键盘弹出时底部输入框自动滚动可见
5. Switch字段Enter键切换开关
6. ComboBox字段Enter键打开下拉列表
