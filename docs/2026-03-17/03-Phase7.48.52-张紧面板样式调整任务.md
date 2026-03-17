# Phase 7.48.52 张紧面板样式调整任务

## 任务背景
根据用户需求，调整两个张紧面板的样式和参数排列顺序：
- **任务1**：TensionSensorConfigPanel 参照 AnalogInputPage 调整元素尺寸和参数排列顺序
- **任务2**：TensionControlConfigPanel 参照 BasicConfigTab 调整输入框尺寸和参数排列顺序

## 参考样式分析

### AnalogInputPage 样式特征
- **布局常量**：
  - 标签字体大小：14px
  - 标签颜色：#9E9E9E
  - 输入框宽度：120px
  - 标签宽度：130px
  - ComboBox宽度：160px
- **GridLayout**：4列布局（标签-控件-标签-控件）
- **间距**：columnSpacing: 8, rowSpacing: 8
- **标题栏**：高度50px，背景图片 "../images/059.png"
- **内容区域**：margins: 15, spacing: 12

### BasicConfigTab 样式特征
- **布局模式**：two-column（两列布局）
- **输入框样式**：
  - SpinBox 使用 DeviceInfo.CustomSpinBox
  - TextField 背景色：#3d4556，边框色：#556070
  - 字体大小：14px
  - 文字颜色：#E0E0E0
- **标签样式**：
  - 字体大小：14px
  - 颜色：#9E9E9E
- **按钮样式**：
  - 启动按钮：绿色 #27ae60（按下 #1e8449）
  - 停止按钮：红色 #F44336（按下 #C62828）
  - 重置按钮：灰色 #7f8c8d（按下 #5d6d7e）

## 实施计划

### 任务1：TensionSensorConfigPanel 样式调整

**当前问题**：
- 布局常量与 AnalogInputPage 不一致
- 参数排列顺序需要调整

**调整内容**：
1. 更新布局常量匹配 AnalogInputPage
2. 调整参数排列顺序（参照模拟量保护参数设置界面）
3. 统一输入框样式和尺寸

### 任务2：TensionControlConfigPanel 样式调整

**当前问题**：
- 输入框尺寸与 BasicConfigTab 不一致
- 参数排列顺序需要调整

**调整内容**：
1. 更新布局常量匹配 BasicConfigTab
2. 调整参数排列顺序（参照电机基本配置）
3. 统一输入框样式和尺寸
4. 确保按钮样式一致

## 下一步
开始实施任务1和任务2的代码修改。
