# Phase 7.48.77 - 修复张力控制回车键不响应

## 修复日期
2026-03-22

## 问题描述

在张力传感器界面按回车键时，日志输出"当前页面未实现 triggerInputItem 方法"，没有任何反应。

### 根因分析

1. **TensionControlPage 使用3区域模式**（0=列表, 1=参数, 2=按钮），但 DeviceSettingsDialog 的回车键处理只适配了4区域模式（0=列表, 1=Tab, 2=参数, 3=按钮）

2. **方法调用链断裂**：
   - DeviceSettingsDialog 检查 `focusSubArea === 2` 才调用 `triggerParamInput`
   - 但张力控制的参数区域是 `focusSubArea === 1`
   - 所以进入了 else 分支，调用 `triggerContentItem` → `triggerInputItem`
   - TensionControlPage 没有 `triggerInputItem` 方法 → 警告信息

3. **缺少转发函数**：TensionControlPage 没有 `triggerParamInput` 和 `triggerButton` 转发函数（BrakeControlPage 有）

### 影响范围
| focusSubArea | 3区域(张力) | 4区域(电机/制动) | DeviceSettingsDialog判断 |
|:---:|:---:|:---:|:---:|
| 0 | 列表 | 列表 | triggerInputItem |
| 1 | **参数** | Tab | → 走else分支（错误！） |
| 2 | **按钮** | 参数 | → triggerParamInput（错误！） |
| 3 | - | 按钮 | triggerButton |

## 修改文件

### 1. TensionControlPage.qml
添加两个转发函数（参照 BrakeControlPage 的实现）：

- **triggerParamInput(paramIndex)**：转发到 `tensionControlConfigPanel.item.triggerParamInput(paramIndex)`
- **triggerButton(buttonIndex)**：转发到 `tensionControlConfigPanel.item.triggerButton(buttonIndex)`

### 2. DeviceSettingsDialog.qml (回车键处理)
在 `focusSubArea === 2`（4区域参数）判断之前，添加3区域模式的判断：

```javascript
// 3区域参数区域：focusSubArea===1 且 focusParamIndex>=0 且有triggerParamInput
if (currentPage.focusSubArea === 1 && currentPage.focusParamIndex >= 0
    && typeof currentPage.triggerParamInput === "function") {
    currentPage.triggerParamInput(currentPage.focusParamIndex)
}

// 3区域按钮区域：focusSubArea===2 且 focusButtonIndex>=0 且 focusParamIndex===-1
else if (currentPage.focusSubArea === 2 && currentPage.focusButtonIndex >= 0
    && currentPage.focusParamIndex === -1 && typeof currentPage.triggerButton === "function") {
    currentPage.triggerButton(currentPage.focusButtonIndex)
}

// 原有的4区域参数区域处理
else if (currentPage.focusSubArea === 2) { ... }
```

**判断条件说明**：
- 使用 `focusParamIndex >= 0` 区分参数区域 vs 非参数区域
- 使用 `focusParamIndex === -1` 区分3区域按钮 vs 4区域参数
- 4区域模式（电机/制动器）在focusSubArea=1时，focusParamIndex=-1，不会误触发

## 验证要点
1. 张力传感器界面，回车键触发参数输入（ComboBox循环、SpinBox虚拟键盘）
2. 张力传感器界面，按钮区域回车键触发启动/停止
3. 电机控制界面回车键行为不变
4. 制动器控制界面回车键行为不变
5. 洒水控制等其他页面不受影响
