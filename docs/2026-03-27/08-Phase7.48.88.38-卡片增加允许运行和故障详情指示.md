# Phase 7.48.88.38 - 卡片增加允许运行和故障详情指示

## 修改时间
2026-03-27

## 问题描述

Input1 卡片界面只显示急停、跑偏等 DI 开关量保护状态，当显示"故障"时无法直接看到是哪个设备的什么故障。用户需要：
1. **允许运行**指示：所有保护正常且无故障时显示绿色"允许"，否则红色"禁止"
2. **故障详情**指示：故障时显示具体故障设备名（如"张紧控制运行失败"），无故障时隐藏

## 修改方案

### MyIN_Data.ui.qml（卡片组件）

新增属性：
- `allowRun: bool` - 允许运行状态（无故障+无保护触发=true）
- `faultDetail: string` - 故障详情文字（空=无故障，隐藏）

statusRow 新增两个徽章：
- **第4元素**：允许运行徽章（绿色"允许" / 红色"禁止"）
- **第5元素**：故障详情徽章（红色闪烁，仅故障时显示）

### Screen01.qml（数据绑定层）

- 新增 `runtimeTracker` Connections 监听 `isFaultChanged` 和 `faultDevicesChanged`
- `updateFaultDisplay()` 函数：故障列表 → 卡片 faultDetail 文字
- DI `onBitChanged` 中同步更新 `allowRun`
- F键复位时更新 `allowRun`

### 允许运行逻辑

```
allowRun = !runtimeTracker.isFault && (protectionBits === 0)
```

即：无设备运行故障 + 无 DI 保护触发 = 允许运行

## 修改文件

| 文件 | 修改内容 |
|------|---------|
| `src/qml/Input1/Input1Content/MyIN_Data.ui.qml` | 新增 allowRun/faultDetail 属性 + 两个徽章 |
| `src/qml/Input1/Input1Content/Screen01.qml` | 新增 runtimeTracker 绑定 + DI/F键联动更新 |
