# FIX 100.300.25.2 - 开关量列表背景图片States方式实现

**日期**: 2026-01-26
**类型**: UI优化
**文件**: `src/qml/components/device_info/pages/SwitchInputPage.qml`

## 问题描述

用户反馈：
- 当前使用三元表达式的方式在QDS预览中看不到背景图片
- 需要改用states方式实现状态切换

## 解决方案

### 1. 改用States方式

**之前的实现**（三元表达式）：
```qml
Image {
    anchors.fill: parent
    source: root.currentProtectionIndex === index
        ? "qrc:/qt/qml/BeltControlQml/images/bhNameBK1.png"
        : "qrc:/qt/qml/BeltControlQml/images/bhNameBK.png"
    fillMode: Image.Stretch
    z: -1
}
```

**现在的实现**（States方式）：
```qml
Image {
    id: backgroundImage
    anchors.fill: parent
    fillMode: Image.Stretch
    z: -1

    // 使用相对路径，便于QDS预览
    source: "../../images/bhNameBK.png"

    states: [
        State {
            name: "selected"
            when: root.currentProtectionIndex === index
            PropertyChanges {
                target: backgroundImage
                source: "../../images/bhNameBK1.png"
            }
        },
        State {
            name: "normal"
            when: root.currentProtectionIndex !== index
            PropertyChanges {
                target: backgroundImage
                source: "../../images/bhNameBK.png"
            }
        }
    ]
}
```

### 2. 路径改进

**之前**：使用qrc资源路径
```qml
source: "qrc:/qt/qml/BeltControlQml/images/bhNameBK.png"
```

**现在**：使用相对路径
```qml
source: "../../images/bhNameBK.png"
```

**路径说明**：
- 当前文件位置：`src/qml/components/device_info/pages/SwitchInputPage.qml`
- 图片位置：`src/qml/images/bhNameBK.png`
- 相对路径：`../../images/` （向上两级到src/qml，然后进入images）

## 优势对比

### States方式的优势

1. **更清晰的状态管理**
   - 明确定义了"selected"和"normal"两个状态
   - 状态切换逻辑一目了然

2. **更好的可维护性**
   - 状态定义集中，易于修改
   - 可以轻松添加更多状态（如hover、disabled等）

3. **更好的性能**
   - QML引擎对States有优化
   - 状态切换更流畅

4. **更好的调试体验**
   - 可以在QML调试器中看到当前状态
   - 便于排查状态切换问题

### 相对路径的优势

1. **QDS预览支持**
   - 相对路径在QDS中可以正确解析
   - qrc路径在QDS预览中可能不工作

2. **开发体验更好**
   - 在IDE中可以直接看到图片预览
   - 路径更直观，易于理解

3. **运行时兼容**
   - Qt会自动将相对路径转换为正确的资源路径
   - 不影响最终应用的运行

## 技术细节

### State定义

```qml
State {
    name: "selected"              // 状态名称
    when: condition               // 触发条件
    PropertyChanges {             // 属性变化
        target: backgroundImage   // 目标对象
        source: "path/to/image"   // 要改变的属性
    }
}
```

### 状态切换机制

- `when`条件为true时，自动切换到该状态
- 多个State的when条件互斥，确保只有一个状态激活
- 状态切换时，PropertyChanges自动应用

### 路径解析

QML中的相对路径：
- 相对于当前QML文件的位置
- `../` 表示上一级目录
- `../../` 表示上两级目录

## 验证清单

- [x] 代码修改完成
- [x] 使用States方式实现状态切换
- [x] 使用相对路径便于QDS预览
- [x] 保持z: -1确保图片在底层
- [x] 保持fillMode: Image.Stretch确保图片填充
- [ ] 在QDS中验证图片可见
- [ ] 在运行时验证状态切换正常

## 相关文件

- `src/qml/components/device_info/pages/SwitchInputPage.qml` - 主要修改文件
- `src/qml/images/bhNameBK.png` - 未选中状态背景图
- `src/qml/images/bhNameBK1.png` - 选中状态背景图

## 下一步

1. 在QDS中打开SwitchInputPage.qml验证图片显示
2. 运行应用验证状态切换是否正常
3. 如果需要，可以为AnalogInputPage.qml应用相同的改进
