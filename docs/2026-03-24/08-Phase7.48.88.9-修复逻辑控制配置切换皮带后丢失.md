# Phase 7.48.88.9 - 修复逻辑控制配置切换皮带后丢失

## 日期
2026-03-24

## 问题描述
打开1号皮带→设置逻辑控制→删除张紧控→保存；打开2号皮带→删除2号电机→保存；打开3号皮带→删除1号电机→保存。然后重新打开1号皮带，发现1、2、3号皮带的逻辑启动顺序全部恢复到默认配置。

## 根因分析

### 问题1：Component.onCompleted 用错误的 deviceId 加载
`LogicControlPanel.qml` 的 `property int deviceId: 1`（默认值）。组件创建时序：
1. `Component.onCompleted` 触发 → `loadFromConfig()` 用 `deviceId=1`（默认值）加载
2. `Loader.onLoaded` 触发 → `item.deviceId = root.deviceId`（正确值）
3. `onDeviceIdChanged` 触发 → `loadFromConfig()` 用正确的 deviceId 重新加载

对于1号皮带（deviceId=1），步骤2中 `item.deviceId` 从1设为1，**不触发 onDeviceIdChanged**，所以步骤3不执行。但步骤1已经用正确的 deviceId=1 加载了，表面上没问题。

**隐患**：对于2-8号皮带，步骤1会先用错误的 deviceId=1 加载1号皮带的数据到内存（虽然步骤3会覆盖，但增加了不必要的复杂性和潜在风险）。

### 问题2：saveToConfig 不检查返回值
`saveDeviceLogicConfig()` 返回 `bool`，但 QML 端不检查返回值。如果保存失败（数据库锁、磁盘满、SQL错误），用户仍看到"已保存"提示，但数据并未持久化。

### 问题3：缺乏诊断日志
保存和加载过程中没有打印关键数据（实际保存的JSON、从DB回读的值），无法通过日志定位是保存失败还是加载失败。

## 修复方案

### 1. Component.onCompleted 不再调用 loadFromConfig
将配置加载移到 `Loader.onLoaded`，确保 `deviceId` 已正确设置后再加载：

```qml
// LogicControlPanel.qml
Component.onCompleted: {
    // 不在这里调用loadFromConfig()，由Loader.onLoaded确保正确deviceId后加载
}

// DeviceSettingsDialog.qml - Loader.onLoaded
onLoaded: {
    if (item) {
        item.deviceId = root.deviceId
        item.loadFromConfig()        // 显式触发加载
        item.syncStateFromTracker()  // 同步运行时状态
    }
}
```

### 2. saveToConfig 增加回读验证
保存后立即回读数据库，验证数据是否真正持久化：

```qml
var success = deviceConfigMgr.saveDeviceLogicConfig(root.deviceId, config)
if (success) {
    var verify = deviceConfigMgr.loadDeviceLogicConfig(root.deviceId)
    if (verify["startup_sequence"] === startupJson) {
        console.log("✅ 保存并验证成功")
    } else {
        console.error("❌ 保存验证失败！")
    }
}
```

### 3. 增强诊断日志
- `loadFromConfig`: 打印 deviceId 和 DB 返回的原始值
- `saveToConfig`: 打印 deviceId 和待保存的 JSON
- `onDeviceIdChanged`: 打印变化后的 deviceId

## 修改文件
| 文件 | 修改内容 |
|------|---------|
| `LogicControlPanel.qml` | Component.onCompleted 移除 loadFromConfig + saveToConfig 增加回读验证 + loadFromConfig 增强日志 |
| `DeviceSettingsDialog.qml` | onLoaded 显式调用 loadFromConfig 和 syncStateFromTracker |

## 验证方法
1. 打开1号皮带→逻辑控制→删除张紧控→保存
2. 观察控制台日志：`💾 saveToConfig - deviceId: 1` 和 `✅ 保存并验证成功`
3. 打开2号皮带→逻辑控制→删除2号电机→保存
4. 观察控制台日志：`💾 saveToConfig - deviceId: 2`
5. 重新打开1号皮带→逻辑控制
6. 观察控制台日志：`📖 loadFromConfig - deviceId: 1` 和 `DB原始值: ["1号制动器","1号电机","2号电机"]`
7. 确认1号皮带显示保存后的序列（不含张紧控）
8. 如果仍显示默认值，检查控制台是否有 `❌` 错误日志
