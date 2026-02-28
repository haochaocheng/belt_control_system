# Phase 7.47.48 ~ 7.47.52 修复总结

**日期**: 2026-02-28
**阶段**: Phase 7.47.48 ~ Phase 7.47.52
**提交**: `84fb6e31` → `df3a27c1`

---

## Phase 7.47.48 - 报警记录页面不自动刷新

**问题**: 保护触发后 DB 写入成功，但 AlarmPage 不刷新，始终显示空列表
**根本原因**: `AlarmHistoryDatabase` 写入后无信号通知 QML，AlarmPage 只在 `Component.onCompleted` 加载一次

**修复**:
- `AlarmHistoryDatabase.h`: 新增 `signals: void alarmAdded()`
- `AlarmHistoryDatabase.cpp`: `saveAlarmTriggered()` / `saveAlarmRestored()` 成功后 `emit alarmAdded()`
- `AlarmPage.qml`: 新增 `Connections { target: alarmHistoryDB; function onAlarmAdded() { Qt.callLater(loadAlarms) } }`

---

## Phase 7.47.49 - 模块类型空白 + 默认音频路径

**任务1 - 模块类型 ComboBox 运行时为空**:
- 根本原因: 旧 DB 存 `"输入模块1"`，新 model 只有 `"开关量输入模块1/2"`，`indexOf` 返回 -1
- 修复: `loadProtectionData()` 加名称转换 + `indexOf < 0` 时回退到 0

**任务2 - 默认音频路径**:
- 根本原因: C++ 始终用 TTS 路径，未区分音频来源
- 修复: `AudioPathMapper` 新增 `getDefaultAudioPath()` + `getShortProtectionName()`；`MqttProtectionMonitor` 注入 `DeviceConfigManager` 查询 `use_text_to_speech`

---

## Phase 7.47.50 - 报警记录界面全面修复（5项）

| 问题 | 修复 |
|------|------|
| 序号正序（新记录序号小） | `i + 1` → `records.length - i` |
| 总记录数停留在11 | 新增 `countAllAlarms()` 查 DB 真实总数 |
| 急停/跑偏/撕裂过滤为空 | `onActivated` 加名称映射：急停→沿线急停等 |
| 主机急停文字截断 | 保护名称列宽 130→180，行高 46→66 |
| 文字过小 | 全部字体 ×1.5：13→20，12→18，14→21 |

---

## Phase 7.47.51 - 音频来源加载 === 严格比较类型不匹配

**问题**: 界面始终显示"默认"，但 DB 里是 `use_text_to_speech=1`
**根本原因**: `protection.use_text_to_speech === 1` 严格比较，`QVariantMap` 返回字符串 `"1"`，`"1" === 1 → false`
**修复**: `SwitchInputPage.qml` 第1744行 `=== 1` → `== 1`

---

## Phase 7.47.52 - 默认音频来源始终播放 TTS

**根本原因（三处）**:

| 位置 | 旧值 | 新值 |
|------|------|------|
| 建表 `use_text_to_speech DEFAULT` | `1` | `0` |
| `saveDigitalProtection()` 默认参数 | `true` | `false` |
| `MqttProtectionMonitor::useTTS` 初始值 | `true` | `false` |

**关键修复 - DB 迁移**:
- `DeviceConfigManager` 新增 `runMigrations()`
- 程序启动时自动执行迁移 `001_reset_audio_source`
- 将 DB 中所有 `use_text_to_speech=1` 重置为 `0`
- 用 `schema_migrations` 表记录已执行，防止重复执行
- **无需用户手动重新保存参数，部署后立即生效**

**修改文件**:
- `src/control/DeviceConfigManager.h` — 声明 `runMigrations()`
- `src/control/DeviceConfigManager.cpp` — 实现迁移 + 修改默认值
- `src/control/MqttProtectionMonitor.cpp` — `useTTS` 默认改为 `false`
- `src/qml/components/device_info/pages/SwitchInputPage.qml` — `=== 1` → `== 1`

---

## 提交记录

| 提交 | 说明 |
|------|------|
| `84fb6e31` | fix: Phase 7.47.48 - 修复报警记录页面不自动刷新 |
| `5bfe21e2` | fix: Phase 7.47.49 - 模块类型空白+默认音频路径修复 |
| `5b5bcd19` | feat: Phase 7.47.50 - 报警记录界面全面修复 |
| `3b5d15ab` | fix: Phase 7.47.51 - 修复音频来源加载时===严格比较类型不匹配 |
| `df3a27c1` | fix: Phase 7.47.52 - 修复默认音频来源始终播放TTS问题 |
