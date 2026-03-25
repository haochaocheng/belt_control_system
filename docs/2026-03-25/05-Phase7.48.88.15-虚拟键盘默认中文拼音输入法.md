# Phase 7.48.88.15 - 虚拟键盘默认中文拼音输入法

## 日期
2026-03-25

## 问题描述
基本配置 → 基本参数设置 → "本机名称"输入框点击后弹出的虚拟键盘是英文键盘，应该弹出中文拼音输入法。

## 根因分析
- `main.cpp` 中设置了 `QT_IM_MODULE=qtvirtualkeyboard` 启用虚拟键盘
- 但未设置 `QT_VIRTUALKEYBOARD_LOCALE`，默认使用英文 (`en_US`)
- `BasicParametersSection.qml` 中 `keyboardMode: "chinese"` 已设置，对应 `inputMethodHints: Qt.ImhNone`
- `Qt.ImhNone` 只是不限制输入法类型，但不会主动切换到中文

## 修改方案
在 `main.cpp` 中添加环境变量设置虚拟键盘默认 locale 为中文：
```cpp
qputenv("QT_VIRTUALKEYBOARD_LOCALE", QByteArray("zh_CN"));
```

### 对其他输入框的影响
- **数字输入框**（keyboardMode="numeric"）：使用自定义数字面板 `numericKeyboardLayout`，不走 Qt InputPanel，**不受影响**
- **中文输入框**（keyboardMode="chinese"）：使用 Qt InputPanel，**默认显示中文拼音** ✅
- **英文输入框**（keyboardMode="english"）：`inputMethodHints` 设置了 `Qt.ImhNoPredictiveText | Qt.ImhPreferLowercase`，InputPanel 会切换到英文模式

## 修改文件

| 文件 | 修改内容 |
|------|---------|
| `src/main/main.cpp` | 添加 `QT_VIRTUALKEYBOARD_LOCALE=zh_CN` 环境变量 |
| `src/qml/VirtualKeyboardSettings.qml` | 更新注释说明 |

## 验证方法
1. 打开基本配置 → 基本参数设置
2. 点击"本机名称"输入框
3. 确认弹出的虚拟键盘是中文拼音输入法
4. 输入拼音如 "daxiang" → 候选词应显示"大巷"
5. 确认数字输入框（如皮带编号）仍显示数字键盘
