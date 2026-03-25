# Phase 7.48.88.19-20 - TTS自定义皮带名称与启动语音修复

## 日期
2026-03-25

## 问题描述

### 问题1：TTS批量生成未使用自定义皮带名称（Phase 7.48.88.19）
用户在基本参数设置中将2号设备的本机名称设置为"1109顺槽皮带"，但批量生成TTS语音时，音频内容仍为"2号皮带启动，请注意安全"，未替换为自定义名称。

**根本原因**：
1. **SystemConfig启动未同步**：`SystemConfig` 从 `config.ini` 加载 `machineNumber` 和 `localDeviceName`，但 config.ini 可能与 SQLite 中的配置不一致（用户修改后未同步到 config.ini，或之前版本无同步代码）
2. **BatchSynthesisContent.qml 只读 systemConfig**：构建 `beltNames` 映射时只从全局 `systemConfig` 读取，不直接读 SQLite
3. **中文数字不匹配**：皮带启动TTS文本用中文数字（"二号皮带准备启动"），但替换逻辑只搜索阿拉伯数字（"2号皮带"），导致替换失败

### 问题2：皮带启动语音缺少"请"字（Phase 7.48.88.20）
TTS文本模板为"X号皮带准备启动，注意安全"，缺少"请"字。电机和张紧的模板都有"请注意安全"，唯独皮带启动遗漏。

### 问题3：编译错误 - generateSwitchInputTasks函数签名丢失
Phase 7.48.88.18 添加皮带名称替换代码时，意外删除了 `generateSwitchInputTasks` 的函数签名，导致编译失败。

## 修复方案

### 修复1：启动时从SQLite同步到SystemConfig（main.cpp）
在 `DeviceRoleManager` 和 `DeviceConfigManager` 初始化后，从 SQLite 读取当前设备的 `machineNumber` 和 `localDeviceName`，同步到 `SystemConfig` 并持久化到 config.ini。

### 修复2：BatchSynthesisContent.qml 优先从SQLite读取
构建 `beltNames` 时，优先从 `deviceConfigMgr`（SQLite）+ `deviceRoleManager.localDeviceId` 读取，不再只依赖 `systemConfig`。

### 修复3：替换逻辑增加中文数字匹配
后处理替换同时搜索阿拉伯数字格式（"2号皮带"）和中文数字格式（"二号皮带"）。

### 修复4：补全"请"字
`"%1号皮带准备启动，注意安全"` → `"%1号皮带准备启动，请注意安全"`

### 修复5：恢复函数签名
恢复 `generateSwitchInputTasks` 的函数签名。

## 修改文件

| 文件 | 修改内容 |
|------|---------|
| `src/main/main.cpp` | 启动时从SQLite同步machineNumber/localDeviceName到SystemConfig |
| `src/control/BatchAudioGenerator.cpp` | 恢复函数签名 + 中文数字替换 + "请注意安全"修复 + 删除残留代码 |
| `src/qml/pages/BatchSynthesisContent.qml` | beltNames优先从SQLite读取 |

## 验证方法
1. 设置2号设备本机名称为"1109顺槽皮带"并保存
2. 重新部署后，批量生成皮带操作状态语音
3. 确认TTS文本为"1109顺槽皮带准备启动，请注意安全"
4. 确认音频播放内容包含"请注意安全"
