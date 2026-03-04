# Phase 7.47.98 - 修复 playDurationSpin/delaySpin 缺少 realValue 导致 DB 保存 0

## 日期
2026-03-04 22:20

## 问题描述
播放时长和保护延时两个 SpinBox 缺少 `realValue` 属性和格式化函数，导致：
1. `playDurationSpin.realValue` 为 `undefined` → DB 保存 `play_duration = 0`
2. `delaySpin.realValue` 为 `undefined` → DB 保存 `protection_delay = 0`
3. SpinBox 显示原始整数（如 "30"），而不是秒数（如 "3.0 秒"）

## 根因分析
Phase 7.47.44 重构时，将旧的 GridLayout 内的 SpinBox 替换为新的简化版本，
但遗漏了从旧版本复制 `realValue`、`textFromValue`、`valueFromText` 三个关键属性。

### 旧版本（在注释块中，有 realValue）
```qml
DeviceInfo.CustomSpinBox {
    id: delaySpin  // 或 playDurationSpin
    property int decimals: 1
    property real realValue: value / 10
    textFromValue: function(value, locale) { ... }
    valueFromText: function(text, locale) { ... }
}
```

### 当前活跃版本（缺失 realValue）
```qml
DeviceInfo.CustomSpinBox {
    id: playDurationSpin
    from: 1; to: 999; value: 10
    // ❌ 缺少 realValue, textFromValue, valueFromText！
}
```

## 修复
为 `playDurationSpin` 和 `delaySpin` 添加：
- `property real realValue: value / 10` → 正确的小数值（用于保存到DB）
- `textFromValue` → 显示 "3.0 秒" 格式
- `valueFromText` → 解析用户输入

## 影响
- DB 中已保存的 play_duration = 0 的记录，需要用户重新设置并保存
- 修复后，新保存的数据将正确存储实际秒数

## 修改文件

| 文件 | 修改内容 |
|------|----------|
| src/qml/components/device_info/pages/SwitchInputPage.qml | playDurationSpin 和 delaySpin 添加 realValue + 格式化 |

## 验证方法
1. 播放时长 SpinBox 显示 "3.0 秒" 格式（不是原始整数 "30"）
2. 保护延时 SpinBox 显示 "1.0 秒" 格式
3. 保存后 DB 中 play_duration 不再是 0
4. MqttProtectionMonitor 日志中 "时长" 不再为 0
