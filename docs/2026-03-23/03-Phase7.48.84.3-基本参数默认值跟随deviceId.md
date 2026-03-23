# Phase 7.48.84.3 - 基本参数默认值跟随deviceId

## 修改时间
2026-03-23 02:45 (北京时间)

## 问题描述
打开任意设备弹窗，本机设备下拉框已正确显示2号皮带（Phase 7.48.84.2 修复），但基本参数设置中"本机编号"始终显示1，"本机名称"始终显示"1号皮带"，没有跟随当前设备ID同步更新。

## 根因分析
`BasicConfigPage.qml` 的 `basicParams` 对象默认值硬编码为：
```javascript
basicParams: ({
    machineNumber: 1,           // 固定为1
    localDeviceName: "1号皮带",  // 固定为"1号皮带"
    ...
})
```

当数据库中没有该设备的保存记录时，`loadBasicParams()` 返回 false，显示这些硬编码默认值，而不是根据 `deviceId` 动态计算的值。

## 修改内容

### BasicConfigPage.qml

**1. 默认值改为动态绑定**：
```javascript
// 旧：machineNumber: 1, localDeviceName: "1号皮带"
// 新：
machineNumber: root.deviceId,
localDeviceName: root.deviceId + "号皮带",
```

**2. onDeviceIdChanged 先更新默认值**：
```javascript
onDeviceIdChanged: {
    // 先更新默认值，再加载数据库配置
    basicParams.machineNumber = root.deviceId
    basicParams.localDeviceName = root.deviceId + "号皮带"
    loadAllConfig()
}
```

## 修改文件清单

| 文件 | 修改内容 |
|------|---------|
| `src/qml/components/device_info/pages/BasicConfigPage.qml` | basicParams默认值改为动态跟随deviceId |

## Git 提交
- Commit: `52831b6`
- 信息: `fix: Phase 7.48.84.3 基本参数默认值跟随deviceId`
