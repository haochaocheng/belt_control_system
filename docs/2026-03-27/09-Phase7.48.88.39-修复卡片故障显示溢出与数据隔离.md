# Phase 7.48.88.39 - 修复卡片故障显示溢出与数据隔离

## 修改时间
2026-03-27

## 问题描述

Phase 7.48.88.38 新增允许运行和故障详情指示后，发现4个问题：

### 问题1：故障详情文字溢出卡片
故障数量多时，红色故障详情徽章超出卡片480px宽度。

### 问题2：故障详情显示多余前缀
故障详情显示"2号皮带"前缀，但卡片本身已标识皮带，无需重复。

### 问题3：设备名称显示（不重要）
显示"2号皮带"而非"1108顺槽皮带"，用户确认无关紧要，因为已不再显示皮带编号字符。

### 问题4：8个卡片显示相同数据
所有8个卡片都显示本机设备的DI开关量、故障状态、MQTT通信状态等数据，而不是只在对应的本机卡片上显示。

## 修复方案

### MyIN_Data.ui.qml - 故障徽章宽度限制（问题1）

故障详情徽章增加最大宽度限制和文字省略：
```qml
Rectangle {
    width: Math.min(faultDetailText.implicitWidth + 12, parent.width - x - 8)
    // ...
    Text {
        width: parent.width - 8
        elide: Text.ElideRight
        maximumLineCount: 1
    }
}
```

### Screen01.qml - 数据隔离到本机卡片（问题2、4）

#### updateFaultDisplay() - 仅更新本机卡片
- 通过 `getLocalDeviceId() - 1` 获取本机卡片索引
- 故障详情和允许运行仅设置到本机卡片
- 其他卡片保持默认值（allowRun=true, faultDetail=""）
- 故障设备名不再包含皮带编号前缀

#### onBitChanged() - DI开关量仅更新本机卡片
- 原：循环8个卡片全部更新 protectionBits
- 改：仅更新 `dataItems[localIdx]` 的 protectionBits

#### onModuleStatusChanged() - MQTT状态仅更新本机卡片
- 原：循环8个卡片全部更新 commOnline
- 改：仅更新 `dataItems[localIdx]` 的 commOnline

## 修改文件

| 文件 | 修改内容 |
|------|----------|
| `src/qml/Input1/Input1Content/MyIN_Data.ui.qml` | 故障徽章宽度限制 + 文字省略 |
| `src/qml/Input1/Input1Content/Screen01.qml` | DI/MQTT/故障显示数据隔离到本机卡片 |
