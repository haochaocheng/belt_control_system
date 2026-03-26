# Phase 7.48.88.28 - 批量TTS生成/清除支持按设备选择

## 日期
2026-03-26

## 修改概述

将批量生成和清除旧语音的"皮带数量"SpinBox（只能选1~N连续设备）改为8个独立CheckBox，支持选择性地只对特定设备进行生成或清除操作。

## 问题

原有设计中，"皮带数量"SpinBox只能设置1到8的连续范围，无法：
- 只操作3#和5#设备
- 跳过已经生成好的设备
- 只清除某个设备的旧语音

## 方案

C++ 后端（`BatchAudioGenerator`）已按 `m_beltNumbers` 数组遍历设备文件夹，无需修改。只需QML端传入正确的设备选择。

### 修改内容

**文件**: `src/qml/pages/BatchSynthesisContent.qml`

1. **新增 `beltChecked` 属性**：`[true,true,true,true,true,true,true,true]`，每个元素对应1#~8#设备
2. **新增辅助函数**：`setAllBelts(checked)`、`getSelectedBeltNumbers()`
3. **替换UI控件**：SpinBox → 8个CheckBox + 全选/清空按钮
4. **修改 `buildConfig()`**：`beltNumbers = getSelectedBeltNumbers()` 替代连续数组
5. **修改 `calculateTotalFiles()`**：`beltCount = getSelectedBeltNumbers().length`
6. **修改持久化**：`saveBatchConfig()` 用 `JSON.stringify(beltChecked)`，`loadBatchConfig()` 用 `JSON.parse()`
7. **修改自动保存**：`onBeltCheckedChanged: saveBatchConfig()` 替代旧 Connections

## 修改文件清单

| 文件 | 修改内容 |
|------|---------|
| `src/qml/pages/BatchSynthesisContent.qml` | 8个独立设备CheckBox + 全选/清空 + buildConfig/calculateTotalFiles/持久化适配 |
