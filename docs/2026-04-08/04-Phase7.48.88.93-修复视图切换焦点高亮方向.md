# Phase 7.48.88.93 修复视图切换按钮焦点高亮方向

## 修复日期
2026-04-08

## 问题描述
**现象**：Modbus从站Tab中，键盘导航到视图切换行（paramIndex=-1）时，橙色焦点高亮在"映射表"按钮上，但界面实际显示的是参数配置区域；按Enter切换后，焦点高亮在"参数配置"按钮上，但界面显示映射表内容。焦点指示和实际视图内容始终相反。

**根因**：Phase 7.48.88.92 的焦点高亮逻辑写反了——橙色边框出现在**非活跃**按钮（viewMode !== X）上，而不是**当前活跃**按钮上。

**旧逻辑**（错误）：
```qml
// "参数配置"按钮 — viewMode不等于0时才显示橙色（即非活跃时高亮）
border.color: root.viewMode === 0 ? "#64B5F6" : (focused ? "#FF9800" : "#4a5068")
border.width: focused && root.viewMode !== 0 ? 3 : 1

// "映射表"按钮 — viewMode不等于1时才显示橙色（即非活跃时高亮）
border.color: root.viewMode === 1 ? "#64B5F6" : (focused ? "#FF9800" : "#4a5068")
border.width: focused && root.viewMode !== 1 ? 3 : 1
```

**新逻辑**（正确）：
```qml
// "参数配置"按钮 — viewMode等于0时，如果有焦点显示橙色，否则蓝色
border.color: focused && root.viewMode === 0 ? "#FF9800" : (root.viewMode === 0 ? "#64B5F6" : "#4a5068")
border.width: focused && root.viewMode === 0 ? 3 : 1

// "映射表"按钮 — viewMode等于1时，如果有焦点显示橙色，否则蓝色
border.color: focused && root.viewMode === 1 ? "#FF9800" : (root.viewMode === 1 ? "#64B5F6" : "#4a5068")
border.width: focused && root.viewMode === 1 ? 3 : 1
```

## 修复效果
- 焦点在视图切换行时，橙色高亮出现在**当前活跃**视图的按钮上
- viewMode=0 → "参数配置"按钮橙色高亮 → 界面显示参数配置 ✅ 一致
- viewMode=1 → "映射表"按钮橙色高亮 → 界面显示映射表 ✅ 一致

## 涉及文件
- `src/qml/components/device_info/pages/ModbusTCPSlaveTab.qml` — 焦点高亮条件修正
- `src/qml/components/device_info/pages/ModbusTCPMasterTab.qml` — 焦点高亮条件修正
- `src/qml/components/device_info/pages/S7MasterTab.qml` — 焦点高亮条件修正
- `src/qml/components/device_info/pages/S7SlaveTab.qml` — 焦点高亮条件修正
