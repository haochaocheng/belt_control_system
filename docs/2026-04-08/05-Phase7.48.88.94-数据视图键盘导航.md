# Phase 7.48.88.94 数据视图键盘导航（类别切换+滚动）

## 修复日期
2026-04-08

## 问题列表

### 问题1：映射表/数据概览的类别按钮无法通过键盘切换
**现象**：进入映射表视图后，保持寄存器(4x)/输入寄存器(3x)/线圈(0x)/离散输入(1x) 等类别按钮只能触摸切换，无法通过键盘操作。

**修复方案**：
- 4个Tab QML各新增 `handleDataViewKey(direction)` 函数
- TCPControlPage在方向键处理前检查是否处于数据视图模式，如果是则委托给Tab处理
- 焦点在 `focusParamIndex >= 0` 且 `viewMode === 1` 时：
  - **左/右键**：循环切换类别（Modbus有4个类别，S7有2个DB）
  - 当前活跃类别按钮显示**橙色高亮边框**

### 问题2：映射表数据只能显示12条，无法通过键盘查看更多
**现象**：映射表只能显示有限条数的数据，超出屏幕的内容无法通过键盘滚动查看。

**修复方案**：
- `handleDataViewKey` 的上下键处理：
  - **下键**：Flickable 向下滚动 84px（约3行）
  - **上键**：Flickable 向上滚动 84px；当已在顶部时返回 false，让 NavigationManager 处理（回到视图切换行 paramIndex=-1）

## 键盘操作流程
```
Tab栏(B) → ↓ → 视图切换行(paramIndex=-1)
                    ↓ → 类别行(paramIndex=0, 数据视图模式下)
                            ←/→ → 切换类别（保持寄存器/输入寄存器/...）
                            ↓ → 滚动数据表向下
                            ↑ → 滚动数据表向上（到顶时回到视图切换行）
                    Enter → 切换参数配置/映射表视图
```

## 涉及文件
- `src/qml/components/device_info/pages/TCPControlPage.qml` — 新增 tryDataViewNavigation() 拦截函数
- `src/qml/components/device_info/pages/ModbusTCPMasterTab.qml` — handleDataViewKey + 类别高亮
- `src/qml/components/device_info/pages/ModbusTCPSlaveTab.qml` — handleDataViewKey + 类别高亮
- `src/qml/components/device_info/pages/S7MasterTab.qml` — handleDataViewKey + 类别高亮
- `src/qml/components/device_info/pages/S7SlaveTab.qml` — handleDataViewKey + 类别高亮
