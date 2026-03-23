# Phase 7.48.84.4 - 设置12个设备卡片的独立名称

## 修改时间
2026-03-23 03:00 (北京时间)

## 问题描述
Screen01（input1页面）的12个设备卡片全部显示"设备 01"，没有分别显示各自的设备名称。

## 根因分析
`Screen01Form.ui.qml` 中12个 `MyIN_Data` 组件均未设置 `deviceName` 属性，全部使用 `MyIN_Data.ui.qml` 中的默认值：
```qml
property string deviceName: "设备 01"
```

由于 `.ui.qml` 是 Qt Design Studio 专用文件，不宜手动修改，应在 `Screen01.qml` 的初始化逻辑中动态设置。

## 修改内容

### Screen01.qml

在 `Component.onCompleted` 的 `Qt.callLater` 回调中，`updateSelection()` 之后、`setupMouseInteraction()` 之前，添加设备名称初始化：

```javascript
var deviceNames = [
    "1号皮带", "2号皮带", "3号皮带", "4号皮带",
    "5号皮带", "6号皮带", "7号皮带", "8号皮带",
    "转载机", "破碎机", "前刮板", "后刮板"
]
for (var j = 0; j < dataItems.length; j++) {
    if (dataItems[j]) {
        dataItems[j].deviceName = deviceNames[j]
    }
}
```

## 设备名称映射

| 卡片索引 | 设备名称 |
|----------|---------|
| 0 | 1号皮带 |
| 1 | 2号皮带 |
| 2 | 3号皮带 |
| 3 | 4号皮带 |
| 4 | 5号皮带 |
| 5 | 6号皮带 |
| 6 | 7号皮带 |
| 7 | 8号皮带 |
| 8 | 转载机 |
| 9 | 破碎机 |
| 10 | 前刮板 |
| 11 | 后刮板 |

## 修改文件清单

| 文件 | 修改内容 |
|------|---------|
| `src/qml/Input1/Input1Content/Screen01.qml` | Component.onCompleted中为12个卡片设置deviceName |

## Git 提交
- Commit: `9160efa`
- 信息: `fix: Phase 7.48.84.4 设置12个设备卡片的独立名称`
