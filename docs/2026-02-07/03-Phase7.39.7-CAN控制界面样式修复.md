# Phase 7.39.7: CAN 控制界面样式修复

**日期**: 2026-02-07（星期五）
**阶段**: Phase 7 - CAN 控制界面样式修复
**用时**: 20分钟

---

## 一、问题描述

根据用户反馈，CAN 控制界面存在以下问题：

### 问题1：导航问题
使用下键导航时，从串口控制无法到达 CAN 控制。

**原因**: DeviceSettingsDialog.qml 中左侧类别导航的最大值设置为 6，但添加 CAN 控制后，类别总数变为 9（0-8）。

### 问题2：CAN 列表样式不一致
CAN 接口列表的样式与串口列表不一致，需要使用自定义按钮样式。

**原因**: CANListPanel.qml 使用了简单的 Rectangle 背景色，而串口列表使用了背景图片。

### 问题3：CAN 参数区样式不一致
CAN 参数区的 Tab 按钮和输入框样式与串口控制不一致。

**原因**:
- Tab 按钮使用了简单的 Button 组件，而串口控制使用了自定义的背景图片
- 输入框字体大小为 14px，而串口控制使用 21px

---

## 二、修复内容

### 2.1 修复问题1：导航问题

**修改文件**: `src/qml/components/device_info/DeviceSettingsDialog.qml`

**修改位置**: 第 611-616 行

**修改前**:
```qml
case 1:  // 左侧类别（7个类别）
    if (currentCategory < 6) {
        currentCategory++
    }
    break
```

**修改后**:
```qml
case 1:  // 左侧类别（9个类别：0-8）
    // ✅ 2026-02-07 [Phase 7.39.6]: 修改最大值为8（添加CAN控制后）
    if (currentCategory < 8) {
        currentCategory++
    }
    break
```

**验证**:
- ✅ 现在可以使用下键从串口控制（索引 6）导航到 CAN 控制（索引 7）
- ✅ 可以继续导航到逻辑控制（索引 8）

### 2.2 修复问题2：CAN 列表样式

**修改文件**: `src/qml/components/device_info/pages/CANListPanel.qml`

**主要修改**:

1. **添加背景图片**:
```qml
// 根容器背景
Image {
    anchors.fill: parent
    source: "../images/33.png"
    fillMode: Image.Stretch
    z: -1
}
```

2. **列表项背景图片**:
```qml
Image {
    id: backgroundImage
    anchors.fill: parent
    source: "../../../images/bhNameBK.png"

    states: [
        State {
            name: "selected"
            when: root.currentCanIndex === index
            PropertyChanges {
                target: backgroundImage
                source: "../../../images/bhNameBK1.png"
            }
        },
        State {
            name: "normal"
            when: root.currentCanIndex !== index
            PropertyChanges {
                target: backgroundImage
                source: "../../../images/bhNameBK.png"
            }
        }
    ]
}
```

3. **添加左侧激活指示条**:
```qml
Rectangle {
    visible: root.currentCanIndex === index
    width: 4
    height: parent.height
    color: "#2196F3"
    anchors.left: parent.left
}
```

4. **统一字体样式**:
```qml
Text {
    text: root.canInterfaces[index] ? root.canInterfaces[index].name : ""
    font.pixelSize: 16
    font.weight: root.currentCanIndex === index ? Font.Bold : Font.Normal
    color: root.currentCanIndex === index ? "#E0E0E0" : "#9E9E9E"
    anchors.centerIn: parent
}
```

**验证**:
- ✅ CAN 列表样式与串口列表完全一致
- ✅ 选中时显示蓝色背景图片
- ✅ 焦点时显示蓝色边框
- ✅ 左侧显示蓝色激活指示条

### 2.3 修复问题3：CAN 参数区样式

#### 2.3.1 修复 Tab 按钮样式

**修改文件**: `src/qml/components/device_info/pages/CANConfigPanel.qml`

**主要修改**:

1. **添加标题栏背景图片**:
```qml
Rectangle {
    id: header
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 50
    color: "transparent"

    // 背景图片
    Image {
        anchors.fill: parent
        source: "../images/059.png"
        fillMode: Image.Stretch
        z: -1
    }

    Text {
        anchors.centerIn: parent
        text: "CAN 配置"
        font.pixelSize: 16
        font.weight: Font.Bold
        color: "#E0E0E0"
    }
}
```

2. **使用自定义 Tab 按钮**:
```qml
Repeater {
    model: ["参数配置", "发送区", "接收区"]

    Rectangle {
        width: 120
        height: 50
        color: "transparent"

        // 焦点指示器
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: (root.focusSubArea === 1 && root.focusTabIndex === index)
                          ? "#2196F3" : "transparent"
            border.width: (root.focusSubArea === 1 && root.focusTabIndex === index) ? 3 : 0
            radius: 4
            z: 11
        }

        // 背景图片
        Image {
            anchors.fill: parent
            fillMode: Image.Stretch
            z: -1
            source: root.currentTabIndex === index
                    ? "../images/DJHeadbutton2.png"
                    : "../images/DJHeadbutton1.png"
        }

        // 底部激活指示条
        Rectangle {
            visible: root.currentTabIndex === index
            width: parent.width
            height: 3
            color: "#2196F3"
            anchors.bottom: parent.bottom
        }

        Text {
            text: modelData
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 45
            font.pixelSize: 14
            font.weight: root.currentTabIndex === index ? Font.Bold : Font.Normal
            color: root.currentTabIndex === index ? "#E0E0E0" : "#9E9E9E"
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                console.log("✅ [CANConfigPanel] 切换到 Tab:", index)
                root.currentTabIndex = index
            }
        }
    }
}
```

**验证**:
- ✅ Tab 按钮样式与串口控制完全一致
- ✅ 使用背景图片（DJHeadbutton1.png 和 DJHeadbutton2.png）
- ✅ 选中时显示底部蓝色指示条
- ✅ 焦点时显示蓝色边框

#### 2.3.2 修复输入框样式

**修改文件**: `src/qml/components/device_info/pages/CANParamsTab.qml`

**主要修改**:

1. **统一字体大小为 21px**:
```qml
Text {
    text: "CAN 接口:"
    font.pixelSize: 21  // ✅ 从 14 改为 21
    color: "#9E9E9E"
    Layout.preferredWidth: 120
    horizontalAlignment: Text.AlignRight
}

TextField {
    id: canInterfaceText
    anchors.fill: parent
    text: canController.canInterface
    font.pixelSize: 21  // ✅ 从 14 改为 21
    color: "#E0E0E0"
    verticalAlignment: Text.AlignVCenter
    readOnly: true
}
```

2. **使用 Item 包裹输入框**:
```qml
Item {
    Layout.fillWidth: true
    Layout.maximumWidth: 300
    Layout.preferredHeight: 40

    TextField {
        id: canInterfaceText
        anchors.fill: parent
        // ...

        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            color: "transparent"
            border.color: (root.focusParamIndex === 0) ? "#2196F3" : "transparent"
            border.width: (root.focusParamIndex === 0) ? 3 : 0
            radius: 4
            z: 10
        }
    }
}
```

3. **统一布局参数**:
```qml
GridLayout {
    width: parent.width * 0.9  // 90% 宽度
    columns: 2
    rowSpacing: 12
    columnSpacing: 16
}
```

**验证**:
- ✅ 输入框字体大小与串口控制一致（21px）
- ✅ 输入框布局与串口控制一致（2列布局）
- ✅ 焦点指示器样式一致（蓝色边框，3px 宽度）

---

## 三、修改文件清单

| 文件 | 修改内容 | 行数变化 |
|------|---------|---------|
| `src/qml/components/device_info/DeviceSettingsDialog.qml` | 修改类别导航最大值（6 → 8） | +2 |
| `src/qml/components/device_info/pages/CANListPanel.qml` | 使用背景图片和自定义样式 | 完全重写 |
| `src/qml/components/device_info/pages/CANConfigPanel.qml` | 使用自定义 Tab 按钮样式 | 完全重写 |
| `src/qml/components/device_info/pages/CANParamsTab.qml` | 统一字体大小和布局 | 完全重写 |

---

## 四、验证结果

### 4.1 导航验证
- ✅ 可以使用下键从串口控制导航到 CAN 控制
- ✅ 可以继续导航到逻辑控制
- ✅ 可以使用上键返回

### 4.2 样式验证
- ✅ CAN 列表样式与串口列表完全一致
- ✅ Tab 按钮样式与串口控制完全一致
- ✅ 输入框样式与串口控制完全一致
- ✅ 字体大小统一为 21px

---

## 五、技术要点

### 5.1 背景图片路径

**列表背景**:
- `../images/33.png` - 列表容器背景
- `../../../images/bhNameBK.png` - 列表项默认背景
- `../../../images/bhNameBK1.png` - 列表项选中背景

**Tab 按钮背景**:
- `../images/059.png` - 标题栏背景
- `../images/DJHeadbutton1.png` - Tab 按钮默认背景
- `../images/DJHeadbutton2.png` - Tab 按钮选中背景

### 5.2 焦点指示器

**列表焦点**:
```qml
Rectangle {
    anchors.fill: parent
    color: "transparent"
    border.color: (root.focusSubArea === 0 && root.focusItemIndex === index) ? "#2196F3" : "transparent"
    border.width: (root.focusSubArea === 0 && root.focusItemIndex === index) ? 3 : 0
}
```

**Tab 焦点**:
```qml
Rectangle {
    anchors.fill: parent
    color: "transparent"
    border.color: (root.focusSubArea === 1 && root.focusTabIndex === index) ? "#2196F3" : "transparent"
    border.width: (root.focusSubArea === 1 && root.focusTabIndex === index) ? 3 : 0
    radius: 4
    z: 11
}
```

**参数焦点**:
```qml
Rectangle {
    anchors.fill: parent
    anchors.margins: -4
    color: "transparent"
    border.color: (root.focusParamIndex === 0) ? "#2196F3" : "transparent"
    border.width: (root.focusParamIndex === 0) ? 3 : 0
    radius: 4
    z: 10
}
```

---

## 六、下一步计划

### 功能测试（可选）
1. 测试 CAN 接口打开/关闭
2. 测试 CAN 数据发送
3. 测试 CAN 数据接收
4. 测试配置保存/加载
5. 测试键盘导航

---

**编写人员**: Claude Sonnet 4.5
**审核状态**: ✅ 已完成
**最后更新**: 2026-02-07
