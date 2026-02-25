# Phase 7.47.2 - 修复 BatchSynthesisDialog 未注册到 QML 模块

## 问题描述

设备运行时报错：
```
[WARNING] qrc:/qt/qml/BeltControlQml/pages/VoiceManagement.qml:466:5: BatchSynthesisDialog is not a type
ERROR: No root objects loaded!
```

## 原因分析

BatchSynthesisDialog.qml 文件已创建，但没有添加到 `src/qml/CMakeLists.txt` 的 QML_FILES 列表中，导致编译时未被包含到 QML 模块资源中。

## 解决方案

在 CMakeLists.txt 中添加 BatchSynthesisDialog.qml：

```cmake
pages/VoiceManagement.qml  # ✅ 2026-02-11 [Phase 7.45.22]: 语音管理页面
pages/BatchSynthesisDialog.qml  # ✅ 2026-02-25 [Phase 7.47.2]: 批量语音合成对话框
```

## 修改文件

- `src/qml/CMakeLists.txt` - 添加 BatchSynthesisDialog.qml 到 QML_FILES

## 验证方法

重新编译部署后，设备应能正常启动，不再报 `BatchSynthesisDialog is not a type` 错误。

---

**修复时间**: 2026-02-25 16:00
**Phase**: 7.47.2
