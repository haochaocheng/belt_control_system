# Phase 7.48.88 - 速度保护下限误报 + 弹窗Enter键修复 + 提示文字优化

## 修改时间
2026-03-24 (北京时间)

## 问题描述

### 问题1：速度保护启动延时感觉很长
- 日志显示 `速度保护延时中: 24.183 / 30 秒`
- `speed_start_delay = 30.0`（数据库默认值），加上打滑延时 `slip_delay = 10.0`
- 总等待时间可达 40 秒，用户感觉过长
- **说明**：延时计时器本身是准确的（QElapsedTimer），时间参数可在模拟量保护配置界面调整

### 问题2：速度保护 "低于下限" 误报 — 工程量 0.5 <= 0.5
- 数据库中速度保护 `lower_limit = 0.5`（传感器4-20mA量程下限）
- 工程量公式：`engineeringValue = lowerLimit + (adValue / 65535) × rangeValue`
- 当 adValue = 0 时：`engineeringValue = 0.5 + 0 = 0.5`
- 下限检查：`lowerLimit > 0 && engineeringValue <= lowerLimit` → `0.5 > 0 && 0.5 <= 0.5` → **触发**
- **根因**：`lower_limit` 既是传感器量程下限（工程量转换基准），又被当作保护报警阈值，设计冲突

### 问题3：弹窗只有Space键能关闭，Enter键不能关闭
- QML Button 默认只响应 Space 键触发 `clicked`，不响应 Enter/Return
- `Keys.onPressed` 放在 Dialog 上，但焦点在 Button，事件不传播到 Dialog
- 弹窗提示文字只说"按F键复位"，未告知如何关闭弹窗

## 修复方案

### 修复1：速度保护 "limit" 模式只检查上限
**文件**：`src/control/MqttProtectionMonitor.cpp`

在速度保护特殊处理块中，"limit" 模式设置 `speedHandled = true`，只检查上限：
```cpp
if (detectMode == "limit") {
    speedHandled = true;  // 不再 fallthrough 到通用上下限检查
    if (engineeringValue >= upperLimit) {
        exceeded = true;
        limitDirection = AudioPathMapper::UpperLimit;
    }
    // 不检查下限：lower_limit 是量程下限，不是报警阈值
}
```

**原理**：
- `lower_limit = 0.5` 是传感器量程下限（4-20mA映射的最小值），不是保护报警阈值
- 低速保护应使用 "percent" 模式（额定速度百分比检测）
- "limit" 模式只关注超速（超上限）

### 修复2：弹窗 Enter 键支持
**文件**：`src/qml/App.qml`

将 `Keys.onPressed` 从 Dialog 移到 Button 上：
```qml
Button {
    id: faultConfirmBtn
    ...
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter ||
            event.key === Qt.Key_Escape || event.key === Qt.Key_Space) {
            faultWarningDialog.close()
            event.accepted = true
        }
    }
}
```

### 修复3：弹窗提示文字优化
- 故障警告弹窗：`"按 Enter / Space 关闭此弹窗，然后按 F 键复位"`
- 保护未恢复弹窗：`"按 Enter / Space 关闭此弹窗，等待保护恢复后再按 F 键"`
- 按钮下方提示：`"[Enter / Space 关闭]"`

## 修改文件

| 文件 | 修改内容 |
|------|---------|
| `src/control/MqttProtectionMonitor.cpp` | 速度保护 "limit" 模式 speedHandled=true，只检查上限 |
| `src/qml/App.qml` | Keys.onPressed 移到 Button + 提示文字优化 |

## 关于延时参数
`speed_start_delay` 和 `slip_delay` 是数据库配置值，可在模拟量保护设置界面调整：
- `speed_start_delay`：电机启动后延时检测（默认30秒）
- `slip_delay`：低速打滑持续时间阈值（默认10秒，仅 percent 模式）

## 验证方法
1. 电机运行后速度 ≈ 0 → **不再**触发"低于下限"报警
2. 电机运行后速度超过 upper_limit → 正常触发"超上限"报警
3. 弹窗打开后按 Enter → 弹窗关闭
4. 弹窗打开后按 Space → 弹窗关闭
5. 弹窗打开后按 Escape → 弹窗关闭
6. 弹窗提示文字正确显示"按 Enter / Space 关闭此弹窗"
