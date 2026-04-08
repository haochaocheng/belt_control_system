# Phase 7.48.88.92 导航焦点进入视图切换行与映射表实时刷新

## 修复日期
2026-04-08

## 问题列表

### 问题1：下键焦点跳过"参数配置/映射表"按钮直接进入端口号
**现象**：从TCP配置界面Tab栏按下键，焦点直接进入端口号输入框，没有经过"参数配置"和"映射表"视图切换按钮。

**根因**：`NavigationManager.moveInTabBar("Down")` 直接设置 `paramIndex = 0`（端口号），没有考虑视图切换按钮行的存在。

**修复方案**：
- NavigationManager 新增 `hasViewSwitchRow` 属性（默认false），TCP页面设为true
- `paramIndex = -1` 表示视图切换按钮行
- Tab栏按下键 → paramIndex=-1（视图切换按钮，橙色高亮）→ 再按下键 → paramIndex=0（端口号）
- 视图切换行按 Enter/左/右键 → 切换参数配置/映射表视图
- 视图切换行按上键 → 回到Tab栏

**键盘操作流程**：
```
Tab栏(B) → ↓ → 视图切换行(paramIndex=-1) → ↓ → 端口号(paramIndex=0) → ↓ → ...
                    ↑ → 回到Tab栏
                    Enter/←/→ → 切换视图
```

**修改文件**：
- `NavigationManager.qml` — 新增 hasViewSwitchRow 属性，修改 moveInTabBar/moveInParamArea
- `TCPControlPage.qml` — 设置 hasViewSwitchRow=true，Enter键处理 focusParamIndex=-1
- `TCPConfigPanel.qml` — 传递 focusSubArea 到4个Tab
- 4个Tab QML — 新增 focusSubArea 属性，视图切换按钮焦点橙色高亮

### 问题2：映射表/数据概览当前值不实时更新
**现象**：映射表显示的"当前值"列一直保持不变，不会随寄存器值变化而更新。

**根因**：`loadMapData()` / `loadPollConfig()` 只在以下时机调用一次：
- 组件初始化（Component.onCompleted）
- 映射类别/参数变更
- 视图切换时

之后无论寄存器值如何变化，QML中的 `currentMapData` / `pollDataList` 都是静态快照。

**修复方案**：在4个Tab QML中添加 Timer 定时刷新：
```qml
Timer {
    interval: 1000  // 1秒刷新一次
    running: root.viewMode === 1  // 仅数据视图可见时运行
    repeat: true
    onTriggered: root.loadMapData()  // 或 loadPollConfig()
}
```

**性能考虑**：Timer仅在映射表/数据概览视图可见时（viewMode===1）运行，切换回参数配置视图自动停止。

**修改文件**：4个Tab QML文件

## 涉及文件
- `src/qml/components/device_info/NavigationManager.qml` — hasViewSwitchRow, paramIndex=-1逻辑
- `src/qml/components/device_info/pages/TCPControlPage.qml` — hasViewSwitchRow=true, Enter处理
- `src/qml/components/device_info/pages/TCPConfigPanel.qml` — 传递focusSubArea
- `src/qml/components/device_info/pages/ModbusTCPMasterTab.qml` — 焦点高亮+Timer
- `src/qml/components/device_info/pages/ModbusTCPSlaveTab.qml` — 焦点高亮+Timer
- `src/qml/components/device_info/pages/S7MasterTab.qml` — 焦点高亮+Timer
- `src/qml/components/device_info/pages/S7SlaveTab.qml` — 焦点高亮+Timer
