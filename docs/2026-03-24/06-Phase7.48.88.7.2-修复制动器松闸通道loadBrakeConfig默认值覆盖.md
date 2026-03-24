# Phase 7.48.88.7.2 - 修复制动器松闸通道loadBrakeConfig默认值覆盖

## 日期
2026-03-24

## 问题描述
制动器配置界面中，松闸输出通道和抱闸输出通道始终显示为0，即使QML声明的默认值已在Phase 7.48.88.7中修正为正确值。

## 根因分析
BrakeConfigPanel.qml中存在两层默认值：

1. **QML声明默认值**（第153行）- 已正确修改：
   ```qml
   value: root.brakeIndex < 5 ? root.brakeIndex + 6 : -1
   ```

2. **loadBrakeConfig()重置默认值**（第541-542行）- 未同步修改：
   ```qml
   releaseOutputChannelSpin.value = 0  // ← 硬编码为0，覆盖了QML默认值
   brakeOutputChannelSpin.value = 0    // ← 硬编码为0
   ```

**执行顺序**：
1. QML组件创建 → SpinBox value = brakeIndex + 6（正确）
2. Component.onCompleted → loadBrakeConfig()
3. loadBrakeConfig()先重置所有值为0（覆盖了正确默认值）
4. 从数据库加载 → 数据库值也是0（migration 035未执行）
5. 最终显示0

## 修复方案

修改 `loadBrakeConfig()` 的默认重置值，与QML声明保持一致：

```qml
// 旧代码
releaseOutputChannelSpin.value = 0
brakeOutputChannelSpin.value = 0

// 新代码
releaseOutputChannelSpin.value = root.brakeIndex < 5 ? root.brakeIndex + 6 : -1
brakeOutputChannelSpin.value = -1
```

## 修改文件
| 文件 | 修改内容 |
|------|---------|
| `src/qml/components/device_info/pages/BrakeConfigPanel.qml` | loadBrakeConfig()默认值与QML声明同步 |

## 通道分配表（最终确认）
| DO通道 | 设备 | 默认值公式 |
|--------|------|-----------|
| 0 | 张紧控制 | 固定0 |
| 1-5 | 电机1-5 | motorIndex + 1 |
| 6-10 | 制动器1-5松闸 | brakeIndex + 6 |
| 11-15 | 洒水1-5 | sprinklerIndex + 11 |
| -1 | 电机6-8/制动器6-8/洒水6-8 | 不使用 |

## 经验教训
QML中如果存在loadConfig()类函数会先重置再加载，则**两处默认值必须保持一致**：
- SpinBox声明中的 `value:` 属性
- loadConfig()中的重置赋值

只修改一处会导致另一处覆盖正确值。
