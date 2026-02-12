# Phase 7.45.32 补充 - 修复控制面板图片不显示问题

**修复时间**: 2026-02-12 18:15
**问题类型**: CMakeLists.txt 资源配置缺失
**严重程度**: 低（控制面板图标不显示）

## 1. 问题现象

### voip.md 日志警告
```
Cannot open: qrc:/qt/qml/BeltControlQml/images/infostate.png
Cannot open: qrc:/qt/qml/BeltControlQml/images/input1.png
Cannot open: qrc:/qt/qml/BeltControlQml/images/input2.png
Cannot open: qrc:/qt/qml/BeltControlQml/images/info_lift.png
```

### 受影响的组件
- `StateInputField.qml` - 状态输入字段（控制面板）
- `ImageInputField.qml` - 图像输入字段（控制面板）
- `DeviceStatusPanel.qml` - 设备状态面板

## 2. 根因分析

### 问题原因
与 Phase 7.45.32 相同，这些图片**只在 BeltControlSystem.qrc 中定义**，但 **CMakeLists.txt 没有在 RESOURCES 部分包含**。

## 3. 解决方案

将 4 个缺失的图片添加到 CMakeLists.txt 的 RESOURCES 部分。

## 4. 修改文件

**文件**: `src/qml/CMakeLists.txt`

### 添加的图片（4 个）

| 图片路径 | 用途 | 使用组件 |
|----------|------|----------|
| `images/infostate.png` | 状态输入字段图标 | StateInputField.qml |
| `images/input1.png` | 输入字段图标 1 | ImageInputField.qml |
| `images/input2.png` | 输入字段图标 2 | ImageInputField.qml |
| `images/info_lift.png` | 设备状态面板图标 | DeviceStatusPanel.qml |

### 修改内容

在 RESOURCES 部分添加：
```cmake
images/infostate.png
images/input1.png
images/input2.png
images/info_lift.png
```

## 5. 完整的图片资源列表

截至 Phase 7.45.32 补充，CMakeLists.txt 中已添加的所有图片资源（共 17 个）：

**images/ 目录（9 个）**：
- `036.png` - 内容区域背景
- `dvList.png` - 类别按钮默认背景
- `dvList2.png` - 类别按钮选中背景
- `bhNameBK.png` - 列表项背景
- `bhNameBK1.png` - 列表项选中背景
- `infostate.png` - 状态输入字段图标
- `input1.png` - 输入字段图标 1
- `input2.png` - 输入字段图标 2
- `info_lift.png` - 设备状态面板图标

**components/device_info/images/ 目录（8 个）**：
- `deviceInfo40.png` - 对话框背景
- `351.png` - 顶部按钮栏背景
- `042.png` - 左侧按钮栏背景
- `034.png` - 输入框背景
- `059.png` - 配置面板背景
- `33.png` - 列表面板背景
- `DJHeadbutton1.png` - 电机配置按钮默认
- `DJHeadbutton2.png` - 电机配置按钮选中

## 6. 验证步骤

1. 编译部署到设备
2. 打开控制面板页面
3. 检查以下组件的图标是否正常显示：
   - 状态输入字段
   - 图像输入字段
   - 设备状态面板
4. 日志中不应再出现 `Cannot open: qrc:/qt/qml/BeltControlQml/images/...` 警告

## 7. 相关修复

- Phase 7.45.32: 修复设备设置对话框图片不显示问题（13 个图片）
- Phase 7.45.31: 修复 QPainter 警告和界面不显示问题
- Phase 7.45.30: 修复 Input1Page 尺寸无限循环
