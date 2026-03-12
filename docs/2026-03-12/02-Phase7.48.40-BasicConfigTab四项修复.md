# Phase 7.48.40 - BasicConfigTab 四项修复

**日期**: 2026-03-12 17:26 (北京时间)
**文件**: `src/qml/components/device_info/pages/BasicConfigTab.qml`

---

## 修复内容

### 问题1：所有电机运行状态LED显示一致

**现象**: 只启动1号电机，但所有电机的运行状态LED都显示"运行中"

**根因**: 运行状态LED仅在 `doDataManager.doStatesChanged` 信号触发时更新。切换电机Tab时，新加载的组件不会主动读取当前DO通道状态，且通道值变化时也不会刷新。

**修复**:
- 新增 `outputChannelSpin.onValueChanged` Connections，通道值变化时刷新LED
- 新增 `Component.onCompleted` 初始化时读取当前DO状态

### 问题2：预警语音/失败语音输入框格式不统一

**现象**: 预警语音和失败语音使用普通 `TextField`，与模块地址等其他输入框组件风格不一致

**修复**: 从 `TextField` 改为 `DeviceInfo.CustomTextField`，支持 `keyboardManager` 虚拟键盘集成

### 问题3：音频来源选择框风格不统一

**现象**: 音频来源使用 `ComboBox` 下拉框，与 AnalogInputPage 的音频来源双按钮风格不一致

**修复**: 改为 RowLayout + 两个 checkable Button（"默认"/"TTS"），参照 AnalogInputPage 的 ButtonGroup 风格：
- 默认按钮：深蓝背景 + 青色边框 + 顶部青色高亮线
- TTS按钮：深绿背景 + 绿色边框 + 顶部绿色高亮线
- 保留 `audioSourceCombo` 兼容Item，确保 collectConfig/applyConfig/buildAudioPath 引用不变

### 问题4：修改日志记录

创建本文档记录所有修改内容。

---

## 影响范围

- 仅修改 `BasicConfigTab.qml` 一个文件
- 不涉及数据库变更
- 不影响其他Tab或页面
