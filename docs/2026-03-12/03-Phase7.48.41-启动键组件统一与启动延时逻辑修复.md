# Phase 7.48.41 - 启动键组件统一+启动延时逻辑修复

**日期**: 2026-03-12 17:41 (北京时间)
**文件**: `src/qml/components/device_info/pages/BasicConfigTab.qml`

---

## 修复内容

### 问题1：启动键输入框格式不统一

**现象**: 启动键使用普通 `ComboBox`，与其他参数的 `CustomComboBox`/`CustomSpinBox` 风格不一致

**修复**: 从 `ComboBox` 改为 `DeviceInfo.CustomComboBox`，支持 `keyboardManager` 虚拟键盘集成

### 问题2：启动按钮点击后立即发送命令

**现象**: 点击启动按钮后，预警语音和MQTT启动命令同时执行，没有等待启动延时

**修复**:
- 新增 `startupDelayTimer` 计时器，interval = 启动延时（秒）
- 点击启动按钮流程改为：播放预警语音 → 启动延时计时 → 延时结束后发送MQTT命令 → 启动反馈超时检测
- `triggerParamInput` case 14（测试按钮）的启动逻辑也同步修改为延时流程
- 停止操作不受影响，仍然立即发送

---

## 影响范围

- 仅修改 `BasicConfigTab.qml` 一个文件
- 不涉及数据库变更
