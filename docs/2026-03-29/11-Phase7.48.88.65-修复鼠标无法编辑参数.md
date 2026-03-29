# Phase 7.48.88.65 - 修复鼠标无法编辑参数

## 修改日期
2026-03-29

## 问题描述
电机配置界面的所有输入框（SpinBox）只能通过键盘操作修改参数，鼠标点击无法进入编辑模式。

## 根因分析
每个输入框外层有 `MouseArea` 用于同步焦点索引，但使用了错误的事件模式：

```qml
// 旧代码（有问题）
MouseArea {
    anchors.fill: parent
    onClicked: function(mouse) {
        root.requestFocusParamIndex(N)
        mouse.accepted = false  // 在 onClicked 中太晚了
    }
}
```

`mouse.accepted = false` 在 `onClicked` 中设置**无效** — 因为 press/release 事件已经被 MouseArea 消费了，SpinBox 的 TextInput 收不到 press 事件，无法获得焦点。

而同文件中的反馈开关（useFeedbackSwitch）已经使用了正确模式：
```qml
MouseArea {
    propagateComposedEvents: true
    onPressed: function(mouse) {
        root.requestFocusParamIndex(N)
        mouse.accepted = false  // 在 onPressed 中有效
    }
}
```

## 修复方案
将所有 MouseArea 改��� `propagateComposedEvents: true` + `onPressed` 模式：
- **`propagateComposedEvents: true`**：允许组合事件（click）向下传递
- **`onPressed` + `mouse.accepted = false`**：在 press 阶段就放行，SpinBox 可以接收到完整的 press→release 事件流

## 修改的文件

### 1. `src/qml/components/device_info/pages/BasicConfigTab.qml`
- 修改10个 MouseArea：`onClicked` → `onPressed` + `propagateComposedEvents: true`
- 涉及：模块地址、输出通道、反馈通道、反馈延时、停止延时、运行状态等所有输入框

### 2. `src/qml/components/device_info/pages/MotorProtectionTab.qml`
- 修改21个 MouseArea：同上模式
- 涉及：所有保护参数输入框（电流、���度、振动等14个Tab共21个参数）

## 测试要点
1. 鼠标点击 SpinBox 数值区域 → 焦点蓝框出现 + TextInput 获得焦点
2. 鼠标点击 SpinBox 上下箭头 → 数值增减正常
3. 鼠标点击后可直接用物理键盘输入数字
4. 键盘导航仍然正常工作（不受影响）
