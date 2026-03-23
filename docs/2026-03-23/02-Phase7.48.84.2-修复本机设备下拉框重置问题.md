# Phase 7.48.84.2 - 修复本机设备下拉框重置问题

## 修改时间
2026-03-23 02:30 (北京时间)

## 问题描述
打开2号设备弹窗，将"本机设备"改成2号皮带，关闭弹窗后打开3号设备弹窗，"本机设备"下拉框重新显示1号皮带。关闭后再次打开2号设备弹窗，仍显示1号皮带。

**用户操作复现**：
1. 打开2号设备 → 将本机设备改为2号皮带 → 关闭
2. 打开3号设备 → 本机设备显示1号皮带（期望：2号皮带）
3. 再打开2号设备 → 还是1号皮带（配置已被重置）

## 根因分析

每次打开设备弹窗时，`BasicConfigPage.qml` 组件重新创建，两个 ComboBox 的初始化流程导致配置被覆盖：

```
1. 组件创建 → localDeviceSelector.currentIndex: 0（默认值）
2. onCurrentIndexChanged 触发 → setLocalDeviceId(1) → 重置回1号皮带
3. Component.onCompleted 运行 → 但已经太晚，配置已被步骤2重置
```

**同样的问题也影响角色选择器**：如果用户设置为"主站"（index=1），下次打开弹窗时默认值 index=0 会触发 `setStationRole("standalone")`，重置角色。

## 修改内容

### BasicConfigPage.qml

**1. 添加初始化保护标志**：
```qml
// ✅ 2026-03-23 [Phase 7.48.84.2]: 初始化保护标志
property bool __initialized: false
```

**2. 角色选择器 onCurrentIndexChanged 添加保护**：
- 旧：`if (typeof deviceRoleManager !== 'undefined')`
- 新：`if (root.__initialized && typeof deviceRoleManager !== 'undefined')`

**3. 本机设备选择器 onCurrentIndexChanged 添加保护**：
- 旧：`if (currentIndex >= 0 && typeof deviceRoleManager !== 'undefined')`
- 新：`if (root.__initialized && currentIndex >= 0 && typeof deviceRoleManager !== 'undefined')`

**4. Component.onCompleted 回显+解锁**：
```qml
Component.onCompleted: {
    loadAllConfig()

    if (typeof deviceRoleManager !== 'undefined') {
        // 回显角色下拉框
        var roleMap = {"standalone": 0, "master": 1, "sub": 2}
        stationRoleSelector.currentIndex = roleMap[deviceRoleManager.stationRole]

        // ✅ Phase 7.48.84.2: 回显本机设备下拉框
        localDeviceSelector.currentIndex = deviceRoleManager.localDeviceId - 1
    }

    // ✅ Phase 7.48.84.2: 初始化完成后才允许onChange生效
    root.__initialized = true
}
```

## 修复原理

| 阶段 | 旧行为 | 新行为 |
|------|--------|--------|
| 组件创建 | ComboBox默认值触发onChange，重置配置 | `__initialized=false`，onChange被跳过 |
| onCompleted | 只回显角色，不回显本机设备 | 两个下拉框都从deviceRoleManager回显 |
| onCompleted结束 | 无 | 设置`__initialized=true`，解锁onChange |
| 用户操作 | 正常 | 正常（`__initialized=true`） |

## 修改文件清单

| 文件 | 修改内容 |
|------|---------|
| `src/qml/components/device_info/pages/BasicConfigPage.qml` | 添加__initialized保护标志+回显本机设备下拉框 |

## Git 提交
- Commit: `38847f8`
- 信息: `fix: Phase 7.48.84.2 修复本机设备下拉框重置问题`
