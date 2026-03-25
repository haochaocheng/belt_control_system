# Phase 7.48.88.14 - 修复清除旧语音TypeError错误

## 日期
2026-03-25

## 问题描述
在语音管理界面点击"清除选中分类的旧语音"按钮时，日志报错：
```
TypeError: Property 'clearCategoryFiles' of object BatchAudioGenerator(0x7fd93382d0) is not a function
```

## 根因分析
- QML 中 `batchGenerator` 绑定的是 `batchGeneratorController`（main.cpp 第509行）
- `batchGeneratorController` 是 `BatchAudioGenerator` 类的实例
- `clearCategoryFiles()` 方法定义在 `TTSBatchGenerator` 中，而非 `BatchAudioGenerator`
- 因此 QML 调用 `batchGenerator.clearCategoryFiles(cats)` 时找不到该方法

## 修改方案
在 `BatchAudioGenerator` 类中添加 `clearCategoryFiles()` 方法，实现与 `TTSBatchGenerator` 相同的文件清除逻辑。

### 支持的10个分类
1. `switchInput` - 开关量输入保护（关键字匹配：急停、跑偏、撕裂等）
2. `analogInput` - 模拟量输入保护（关键字匹配：速度、电流、振动等）
3. `motor` - 电机保护（关键字匹配：号电机）
4. `brake` - 制动器保护（关键字匹配：号制动器）
5. `tension` - 张紧控制保护（关键字匹配：号张紧装置）
6. `linePosition` - 沿线点位保护（关键字匹配：号沿线）
7. `beltOperation` - 皮带操作状态（关键字匹配：启车、停车等）
8. `systemStatus` - 系统/通讯状态（关键字匹配：通信失败、终端离线等）
9. `systemSound` - 系统提示音（清除 system/ 目录所有音频）
10. `moduleStatus` - 模块在线状态（清除 Status/ 目录所有音频）

## 修改文件

| 文件 | 修改内容 |
|------|---------|
| `src/control/BatchAudioGenerator.h` | 声明 `Q_INVOKABLE int clearCategoryFiles(const QStringList &categories)` |
| `src/control/BatchAudioGenerator.cpp` | 实现 clearCategoryFiles()，支持10个分类的文件清除 |

## 验证方法
1. 打开语音管理 → 批量生成
2. 在"清除旧语音"区域勾选"皮带操作状态"
3. 点击"清除选中分类的旧语音"
4. 确认日志不再报 TypeError，显示"已删除 N 个旧语音文件"
