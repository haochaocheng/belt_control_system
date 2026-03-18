# Phase 7.48.53 - 张紧控制语音播放和配置保存功能修复

## 日期：2026-03-18

## 修复内容

### 1. 张紧启动预警和运行失败语音生成分类错误

**问题**：张紧启动预警和运行失败语音放在 `generateBeltOperationTasks`（beltOperation 分类），但 QML 界面只有 `tension` 分类复选框，导致勾选"张紧控制保护"时不会生成这两种语音。

**修复**：
- `BatchAudioGenerator.cpp`：将张紧启动预警和运行失败语音生成逻辑从 `generateBeltOperationTasks` 移到 `generateTensionTasks`
- `BatchSynthesisDialog.qml`：文件数计算从 `10 * beltCount * tensionCount` 修正为 `5 * beltCount * tensionCount`（3保护+1启动+1失败）

### 2. 张紧运行失败TTS文本缺少皮带号

**问题**：TTS文本为 `"%1号张紧运行失败"`，播放时只说"1号张紧运行失败"，缺少皮带号。

**修复**：
- `BatchAudioGenerator.cpp`：TTS文本改为 `"%1号皮带%2号张紧运行失败"`
- `TensionControlConfigPanel.qml`：TTS回退文本同步修改为包含皮带号和张紧编号

### 3. 张紧控制配置保存功能未实现

**问题**：
- `DeviceSettingsDialog.qml` 保存按钮 case 5（张紧控制）是空 TODO
- `TensionControlConfigPanel.qml` 调用的函数名 `saveTensionControlConfig`/`loadTensionControlConfig` 与 C++ 后端实际函数名 `saveTensionConfig`/`loadTensionConfig` 不匹配
- 参数数量不匹配：QML 传 2 个参数，C++ 需要 3 个（含 tensionIndex）
- 字段名 `tension_enabled` 与 C++ 的 `enabled` 不匹配
- 数据库表缺少 `startup_delay` 和 `audio_source` 列

**修复**：
- `DeviceSettingsDialog.qml`：case 5 实现调用 `saveTensionControlConfig()`
- `TensionControlConfigPanel.qml`：
  - 修正函数名和参数匹配 C++ 后端
  - 保存前先加载已有配置再合并，避免覆盖传感器面板字段
  - 字段名 `tension_enabled` 改为 `enabled`
- `DeviceConfigManager.cpp`：
  - 新增迁移 022 添加 `startup_delay` 和 `audio_source` 列
  - `saveTensionConfig` 新增两个字段的绑定
  - 同步更新建表语句和迁移 021 重建表语句

### 4. 设备文件清理

- 删除设备上 16 个错误的张紧运行失败 wav 文件（TTS文本缺少皮带号）
- 删除后从本地 AUDIO 文件夹恢复 8 个默认 mp3 文件

## 涉及文件

| 文件 | 修改内容 |
|------|---------|
| `src/control/BatchAudioGenerator.cpp` | 张紧语音生成移至tension分类，修复TTS文本 |
| `src/qml/pages/BatchSynthesisDialog.qml` | 文件数计算修正 |
| `src/qml/components/device_info/DeviceSettingsDialog.qml` | case 5 保存功能实现 |
| `src/qml/components/device_info/pages/TensionControlConfigPanel.qml` | 保存/加载函数修正，字段名修正 |
| `src/control/DeviceConfigManager.cpp` | 迁移022，saveTensionConfig新增字段 |

## Git 提交

- `1242fd5` - 张紧启动预警+运行失败语音移至tension分类生成
- `a9626a2` - 修复张紧运行失败语音缺少皮带号+删除设备旧文件
- `c5300bf` - 修复张紧控制配置保存功能
