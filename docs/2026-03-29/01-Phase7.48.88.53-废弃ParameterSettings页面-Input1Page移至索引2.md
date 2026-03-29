# Phase 7.48.88.53 - 废弃 ParameterSettings 页面，Input1Page 移至索引2

## 修改日期
2026-03-29

## 问题描述
ParameterSettings（参数设置）页面已不再使用，需要将其废弃，并将 Input1Page（12卡片监控界面）从 SwipeView 索引5移至 ParameterSettings 原来的索引2位置。

## 变更前 SwipeView 页面顺序
| 索引 | 页面 | 说明 |
|------|------|------|
| 0 | ControlPanel | 控制面板 |
| 1 | DeviceMonitorPage | 设备监控（数字孪生）|
| 2 | **ParameterSettings** | 参数设置（已废弃）|
| 3 | AlarmPage | 报警保护 |
| 4 | DeviceOperationLog | 设备运行日志 |
| 5 | **Input1Page** | 12卡片监控界面 |
| 6 | VoiceManagement | 语音管理 |

## 变更后 SwipeView 页面顺序
| 索引 | 页面 | 说明 |
|------|------|------|
| 0 | ControlPanel | 控制面板 |
| 1 | DeviceMonitorPage | 设备监控（数字孪生）|
| 2 | **Input1Page** | 12卡片监控界面（从索引5移至此处）|
| 3 | AlarmPage | 报警保护 |
| 4 | DeviceOperationLog | 设备运行日志 |
| 5 | VoiceManagement | 语音管理（从索引6降至索引5）|

## 修改的文件

### 1. `src/qml/pages/ParameterSettings.qml`
- 整个页面内容用 `/* */` 注释块包裹
- 保留空壳 `Item {}` 以维持结构兼容
- import 语句全部注释掉（仅保留 `import QtQuick 6.5`）

### 2. `src/qml/App.qml`
- **SwipeView 结构**：
  - 索引2位置：`ParameterSettings {}` → `Input1Page {}`
  - 索引5位置：移除原 `Input1Page {}`（已注释保留旧代码）
- **焦点管理**（onCurrentIndexChanged）：
  - `currentIndex === 5` → `currentIndex === 2`
  - `swipeView.itemAt(5)` → `swipeView.itemAt(2)`
- **键盘处理**（数字键1-8启停）：
  - `swipeView.currentIndex !== 5` → `swipeView.currentIndex !== 2`
- **页面注释**：
  - VoiceManagement 注释更新为 Page 6（从 Page 7 降序）

## 影响范围
- SwipeView 页面总数从 7 页减少为 6 页
- Input1Page 的 Head.ui.qml 内部菜单导航（currentPageIndex 0-4）**不受影响**（独立于 SwipeView）
- 键盘数字键1-8启停操作现在在索引2生效
- PageIndicator 自动适应（count 绑定 swipeView.count）

## 测试要点
1. 滑动到索引2确认显示12卡片界面
2. 数字键1-8在12卡片界面正常启停
3. 页面切换到12卡片时焦点正确恢复
4. Head 菜单内部导航正常工作
5. PageIndicator 显示6个点（非7个）
