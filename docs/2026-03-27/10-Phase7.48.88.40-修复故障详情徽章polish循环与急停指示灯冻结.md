# Phase 7.48.88.40 - 修复故障详情徽章polish循环与急停指示灯冻结

## 修改时间
2026-03-27

## 问题描述

### 问题1：急停保护触发后，2号设备卡片急停指示灯未变红
触发急停保护后，保护指示灯应该变红，但界面无响应。

### 问题2：大量 `QML Row: possible QQuickItem::polish() loop` 警告
日志持续输出 MyIN_Data.ui.qml:191 的 polish() 循环警告，一秒数百条。

## 根因分析

两个问题同一根因：**故障详情徽章的宽度绑定存在循环依赖**。

故障详情徽章（statusRow 第5元素）的宽度绑定：
```qml
width: Math.min(faultDetailText.implicitWidth + 12, parent.width - x - 8)
```

- `x` 是徽章在 Row 中的位置 → 取决于 Row 布局（即所有子元素宽度之和）
- 徽章的 `width` 又影响 Row 布局 → 影响 `x`
- **循环依赖** → Row 无限调用 polish() → UI 冻结

### 时序

1. 急停 DI 位变化 → `onBitChanged` 正确设置 `protectionBits`
2. `DeviceRuntimeTracker` 记录故障 `"2号皮带 急停"`
3. `updateFaultDisplay()` 设置 `faultDetail = "2号皮带 急停"`
4. 故障徽章 `visible: true` → 宽度绑定触发 → **polish() 死循环**
5. UI 冻结 → 急停指示灯颜色变化无法渲染

### 附带问题：故障详情仍包含皮带号前缀

`runtimeTracker.faultDevices` 中存储的是 `"2号皮带 急停"` 格式，需要去除 `"N号皮带 "` 前缀。

## 修复方案

### MyIN_Data.ui.qml - 使用固定最大宽度

```qml
// 旧代码（循环依赖）：
width: Math.min(faultDetailText.implicitWidth + 12, parent.width - x - 8)

// 新代码（固定最大宽度180px）：
width: Math.min(faultDetailText.implicitWidth + 12, 180)
```

### Screen01.qml - 去除故障设备名中的皮带号前缀

```javascript
var cleanList = []
for (var fi = 0; fi < faultList.length; fi++) {
    var name = faultList[fi].replace(/^\d+号皮带\s*/, "")
    if (name !== "") cleanList.push(name)
}
var faultText = cleanList.length > 0 ? cleanList.join(" ") : ""
```

## 修改文件

| 文件 | 修改内容 |
|------|----------|
| `src/qml/Input1/Input1Content/MyIN_Data.ui.qml` | 故障徽章宽度改为固定最大值180px |
| `src/qml/Input1/Input1Content/Screen01.qml` | updateFaultDisplay() 去除"N号皮带"前缀 |
