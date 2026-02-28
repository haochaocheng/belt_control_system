# Phase 7.47.44 - 修复开关量保护参数设置界面5个问题

**创建时间**: 2026-02-28
**阶段**: Phase 7.47.44
**关联文件**:
- `src/qml/components/device_info/pages/SwitchInputPage.qml`

---

## 一、问题描述

用户反馈开关量保护参数设置界面（SwitchInputPage.qml）存在以下5个问题：

| 编号 | 问题 | 现象 |
|------|------|------|
| 问题1 | 保护名称输入框为空 | 打开界面时右侧保护名称字段默认为空，需手动点击才显示 |
| 问题2 | 模块类型选项过多 | 有6个选项：输入模块1-4、输出模块、主模块 |
| 问题3 | 寄存器地址不友好 | 显示底层寄存器数字，用户看不懂 |
| 问题4 | TTS文字输入框黑色+无默认值 | 颜色不可见，且字段始终为空 |
| 问题5 | 音频文件显示占位文字 | 显示"选择音频文件"而非实际文件名 |

---

## 二、根本原因分析

### 2.1 问题1和4的根本原因：loadProtectionData 函数中的 TypeError

`loadProtectionData` 函数引用了注释块（`/* */`）中的无效控件ID，导致运行时TypeError：

```javascript
// ❌ 这些ID在 /* */ 注释块内，实际不存在：
durationSpin.value = 50        // TypeError: durationSpin undefined
ttsRadio.checked = true        // TypeError: ttsRadio undefined
audioField.text = ""           // TypeError: audioField undefined
```

由于 `durationSpin.value = 50` 在 else 分支第5行抛出TypeError，后续的 `ttsTextField.text = ...` 从未被执行。

### 2.2 问题1的补充原因：Component.onCompleted 被禁用

`loadProtectionData(0)` 在 `Component.onCompleted` 中被注释掉，导致页面初始状态下所有字段为空。

### 2.3 问题2：模块类型与硬件不符

旧代码：`model: ["输入模块1", "输入模块2", "输入模块3", "输入模块4", "输出模块", "主模块"]`
实际硬件只有2个DI模块。

### 2.4 问题3：寄存器地址对用户无意义

寄存器地址是底层通信细节，与音频播放配置无关，应换成用户可理解的选项。

---

## 三、修复方案

### 3.1 问题1：恢复初始加载

```javascript
// Component.onCompleted 中恢复 Qt.callLater 初始加载
Qt.callLater(function() {
    if (digitalProtectionModel.count > 0) {
        loadProtectionData(0)
    }
})
```

### 3.2 问题2：简化模块类型

```javascript
// 旧值（6选项）
model: ["输入模块1", "输入模块2", "输入模块3", "输入模块4", "输出模块", "主模块"]

// ✅ 新值（2选项，与实际DI硬件一致）
model: ["开关量输入模块1", "开关量输入模块2"]

// ✅ 选模块时自动设置寄存器地址（隐藏细节）
onCurrentIndexChanged: {
    registerAddressSpin.value = (currentIndex === 0) ? 2 : 3
}
```

同步更新 ListModel：`moduleType: "输入模块1"` → `"开关量输入模块1"`

### 3.3 问题3：寄存器地址→音频来源选择

新增属性 `property int audioSourceMode: 0`，替换寄存器地址显示：

```qml
// [默认] 按钮 - 使用批量生成的标准音频
Button {
    text: "默认"
    checked: root.audioSourceMode === 0
    onClicked: root.audioSourceMode = 0
}
// [TTS合成] 按钮 - 使用TTS实时合成文字
Button {
    text: "TTS合成"
    checked: root.audioSourceMode === 1
    onClicked: root.audioSourceMode = 1
}
```

寄存器地址 SpinBox 改为隐藏（`visible: false`），由模块类型自动决定。

### 3.4 问题4：修复TTS文字字段

修复 `loadProtectionData` 中所有错误引用：

```javascript
// ❌ 旧代码（durationSpin在注释块中，TypeError）
durationSpin.value = 50
// ✅ 新代码
playDurationSpin.value = 50

// ❌ 旧代码（ttsRadio在注释块中，TypeError）
ttsRadio.checked = true
// ✅ 新代码
root.audioSourceMode = 0

// ❌ 旧代码（文字来源不准确）
ttsTextField.text = item.name + "保护报警"
// ✅ 新代码（与批量合成清单一致）
ttsTextField.text = getTtsDefaultText(item.name)
```

新增映射函数 `getTtsDefaultText()`：

| 保护名 | TTS文字 |
|--------|---------|
| 急停 | `1号皮带沿线急停保护` |
| 跑偏 | `1号皮带沿线跑偏保护` |
| 撕裂 | `1号皮带沿线撕裂保护` |
| 烟雾 | `1号皮带烟雾保护` |
| 温度 | `1号皮带温度保护` |
| 护网 | `1号皮带护网保护` |
| 堆煤 | `1号皮带堆煤保护` |
| 主机急停 | `1号皮带主机急停保护` |

同时修复 `ttsTextField` 控件属性：
```qml
inputMethodHints: Qt.ImhNone       // 允许中文输入（旧: Qt.ImhDigitsOnly）
placeholderTextColor: "#6E6E6E"    // 浅灰色占位（旧: 无设置，显示黑色）
```

### 3.5 问题5：音频文件显示实际文件名

修复 `audioField` → `audioFileField`（正确ID），新增映射函数 `getAudioFileName()`：

| 保护名 | 音频文件名 |
|--------|-----------|
| 急停 | `沿线急停.wav` |
| 跑偏 | `沿线跑偏.wav` |
| 撕裂 | `沿线撕裂.wav` |
| 烟雾 | `烟雾.wav` |
| 温度 | `温度.wav` |
| 护网 | `护网.wav` |
| 堆煤 | `堆煤.wav` |
| 主机急停 | `主机急停.wav` |

与 `AudioPathMapper::PROTECTION_NAME_MAP` 保持一致。

---

## 四、影响范围

| 组件 | 变化 |
|------|------|
| `SwitchInputPage.qml` | 主要修改文件 |
| `AudioPathMapper.cpp` | 无变化（映射表已在Phase 7.47.42修复） |
| 数据库字段 | 无变化（register_address仍保存，由模块类型自动计算） |

---

## 五、UI变化对比

### 修复前
```
[音频来源]: [寄存器地址: 2    ↑↓]   [TTS文字: (空)]
[通道编号]:                          [音频文件: 选择音频文件]
```

### 修复后
```
[音频来源]: [ 默认(选中) ] [ TTS合成 ]
[通道编号]:                          [音频文件: 沿线急停.wav]
```

当选择 [TTS合成] 时，第三行右侧显示 TTS文字输入框（默认值 "1号皮带沿线急停保护"）。

---

**参考文档**:
- [docs/2026-02-28/02-Phase7.47.42-废弃VoiceFileList统一音频文件命名.md](02-Phase7.47.42-废弃VoiceFileList统一音频文件命名.md)
- [docs/2026-02-24/01-TTS语音文件批量生成清单.md](../2026-02-24/01-TTS语音文件批量生成清单.md)
