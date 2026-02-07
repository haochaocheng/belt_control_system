# Phase 7.39.11 Fix: 修复CAN控制右键导航问题

**日期**: 2026-02-07（星期五）
**阶段**: Phase 7 - CAN 控制右键导航修复
**用时**: 30分钟

---

## 一、问题描述

用户反馈：测试完成pjsip.md，问题依然存在，从CAN0无法跳转到参数配置tab按钮。

**测试日志分析**：
```
391: Debug: ✅ [导航] 右键 - 当前区域: 1
392: Debug: ?? [CAN控制同步] onCurrentFocusAreaChanged - currentFocusArea: 2
393: Debug: ✅ [CAN控制同步] 焦点进入内容区域 - 设置 focusSubArea=0, focusItemIndex= 0
```

**关键发现**：
- 按右键时，DeviceSettingsDialog 的导航逻辑先处理了
- 直接将 `currentFocusArea` 从 1（类别区域）改为 2（内容区域）
- CANControlPage 的键盘事件处理器根本没有被调用
- CANControlPage 的 NavigationManager 没有机会执行

---

## 二、问题根因

### 2.1 代码分析

**DeviceSettingsDialog.qml 的 Keys.onRightPressed**（第940-1109行）：

```qml
Keys.onRightPressed: function(event) {
    // ... 电机控制、制动器控制、张紧控制的特殊处理 ...

    // ✅ 串口控制页面有特殊处理（第1008-1035行）
    var isSerialPortControlPage = (currentCategory === 6)
    if (isSerialPortControlPage) {
        var serialPage = serialPortControlPageLoader.item
        if (serialPage && serialPage.navigationManager) {
            serialPage.navigationManager.handleDirectionKey("Right")
            event.accepted = true
            return
        }
    }

    // ❌ CAN控制页面（类别7）没有特殊处理！
    // 直接走到默认逻辑（第979-980行）：
    case 1:  // 左侧类别 → 右侧内容
        currentFocusArea = 2
}
```

### 2.2 问题原因

1. **串口控制（类别6）有特殊处理**：调用 NavigationManager.handleDirectionKey("Right")
2. **CAN控制（类别7）没有特殊处理**：走默认逻辑，直接改变 currentFocusArea
3. **导致**：CANControlPage 的 NavigationManager 根本没有被调用

---

## 三、修复内容

### 3.1 添加 CAN 控制页面的特殊处理

**修改文件**: `src/qml/components/device_info/DeviceSettingsDialog.qml`

**修改位置**: 第 1037-1063 行

**添加内容**:
```qml
// ✅ 2026-02-07 [Phase 7.39.11 Fix]: CAN控制页面使用 NavigationManager
var isCANControlPage = (currentCategory === 7)  // CAN控制类别
console.log("🔍 [CAN控制导航] isCANControlPage:", isCANControlPage)

if (isCANControlPage) {
    var canPage = canControlPageLoader.item
    if (canPage && canPage.navigationManager) {
        // 检查当前Tab是否有自定义导航
        if (typeof canPage.getCurrentTab === "function") {
            var currentTab = canPage.getCurrentTab()
            if (currentTab && typeof currentTab.handleDirectionKey === "function") {
                console.log("✅ [CAN控制导航] 右键 - 调用自定义导航")
                var handled = currentTab.handleDirectionKey("Right")
                if (handled) {
                    event.accepted = true
                    return
                }
            }
        }

        // 如果没有自定义导航或自定义导航返回false，使用NavigationManager
        console.log("🔍 [CAN控制导航] 右键 - 调用 NavigationManager.handleDirectionKey")
        canPage.navigationManager.handleDirectionKey("Right")
        event.accepted = true
        return
    }
}
```

### 3.2 修复逻辑

1. **判断是否是 CAN 控制页面**：`currentCategory === 7`
2. **获取 CANControlPage 实例**：`canControlPageLoader.item`
3. **检查是否有 NavigationManager**：`canPage.navigationManager`
4. **支持自定义导航**：检查 `getCurrentTab()` 和 `handleDirectionKey()`
5. **调用 NavigationManager**：`navigationManager.handleDirectionKey("Right")`
6. **阻止事件传播**：`event.accepted = true; return`

---

## 四、导航流程

### 4.1 修复前的流程

```
用户按右键
    ↓
DeviceSettingsDialog.Keys.onRightPressed
    ↓
没有 CAN 控制的特殊处理
    ↓
走默认逻辑：currentFocusArea = 2
    ↓
❌ CANControlPage.NavigationManager 没有被调用
    ↓
❌ 焦点直接跳到内容区域，但没有正确的导航逻辑
```

### 4.2 修复后的流程

```
用户按右键
    ↓
DeviceSettingsDialog.Keys.onRightPressed
    ↓
检测到 CAN 控制页面（currentCategory === 7）
    ↓
调用 canPage.navigationManager.handleDirectionKey("Right")
    ↓
NavigationManager.handleDirectionKey("Right")
    ↓
NavigationManager.moveInMotorList("Right")
    ↓
检查 skipTabArea = false
    ↓
✅ switchToArea(areaTabBar)
    ↓
✅ 焦点正确跳转到 Tab 栏区域
```

---

## 五、验证方法

### 5.1 测试步骤

1. 进入 CAN 控制页面（类别7）
2. 焦点在 CAN0 上（列表区域）
3. 按右键
4. 查看控制台日志

### 5.2 预期日志

```
✅ [导航] 右键 - 当前区域: 1
🔍 [CAN控制导航] isCANControlPage: true
🔍 [CAN控制导航] 右键 - 调用 NavigationManager.handleDirectionKey
🔍 [NavigationManager.moveInMotorList] 开始处理
  - direction: Right
  - motorListIndex: 0
  - lastMotorIndex: 1
  - skipTabArea: false
  - currentArea: A
🔍 [NavigationManager.moveInMotorList] 处理右键
  - skipTabArea: false
✅ [NavigationManager] 从列表跳转到Tab导航区
  - 目标区域: areaTabBar
  - 当前 tabIndex: 0
🔍 [NavigationManager.switchToArea] 开始切换
  - 当前区域: A
  - 目标区域: B
✅ [NavigationManager] 切换区域: A → B
✅ [CANControlPage] 区域变化: B
  → 切换到Tab栏区域
```

### 5.3 预期结果

- ✅ 焦点从 CAN0 跳转到"参数配置"Tab按钮
- ✅ Tab按钮显示蓝色边框焦点指示器
- ✅ 可以继续使用左右键在 Tab 之间导航

---

## 六、修改文件清单

| 文件 | 修改内容 | 行数变化 |
|------|---------|---------|
| `src/qml/components/device_info/DeviceSettingsDialog.qml` | 添加 CAN 控制页面的右键导航处理 | +28 |

---

## 七、技术要点

### 7.1 为什么需要特殊处理？

**问题**：
- DeviceSettingsDialog 是全局导航管理器
- 不同页面有不同的导航逻辑
- 有些页面使用 NavigationManager（电机控制、串口控制、CAN控制）
- 有些页面使用简单的 focusSubArea（开关量输入、模拟量输入）

**解决**：
- 对于使用 NavigationManager 的页面，需要在 DeviceSettingsDialog 中添加特殊处理
- 调用页面的 NavigationManager.handleDirectionKey()
- 让页面自己处理导航逻辑

### 7.2 参考串口控制的实现

**串口控制的特殊处理**（第1008-1035行）：
```qml
var isSerialPortControlPage = (currentCategory === 6)
if (isSerialPortControlPage) {
    var serialPage = serialPortControlPageLoader.item
    if (serialPage && serialPage.navigationManager) {
        serialPage.navigationManager.handleDirectionKey("Right")
        event.accepted = true
        return
    }
}
```

**CAN控制的特殊处理**（完全一致）：
```qml
var isCANControlPage = (currentCategory === 7)
if (isCANControlPage) {
    var canPage = canControlPageLoader.item
    if (canPage && canPage.navigationManager) {
        canPage.navigationManager.handleDirectionKey("Right")
        event.accepted = true
        return
    }
}
```

### 7.3 为什么之前的修复没有生效？

**Phase 7.39.11 的修复**：
- 添加了 `lastMotorIndex` 属性
- 修改了 `moveInMotorList()` 函数
- 设置了 `lastMotorIndex = 1`

**但是**：
- 这些修复都在 NavigationManager 内部
- 如果 NavigationManager 根本没有被调用，这些修复就不会生效
- 需要先确保 DeviceSettingsDialog 正确调用 NavigationManager

---

## 八、下一步计划

### 功能测试（必须）
1. 测试 CAN0 按右键是否跳转到"参数配置"Tab
2. 测试完整的导航流程
3. 验证调试日志是否正确输出

### 其他方向键测试（可选）
1. 测试上键、下键、左键是否也需要类似的修复
2. 检查其他使用 NavigationManager 的页面是否有类似问题

---

**编写人员**: Claude Sonnet 4.5
**审核状态**: ✅ 已完成
**最后更新**: 2026-02-07
