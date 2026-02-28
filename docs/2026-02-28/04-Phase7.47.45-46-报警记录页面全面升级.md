# Phase 7.47.45-46 - 开关量保护UI美化 + 报警记录页面全面升级

**创建时间**: 2026-02-28
**阶段**: Phase 7.47.45 (SwitchInputPage uipro美化) + Phase 7.47.46 (报警记录页面重写)
**关联文件**:
- `src/qml/components/device_info/pages/SwitchInputPage.qml`
- `src/qml/pages/AlarmPage.qml`
- `src/main/main.cpp`

---

## 一、Phase 7.47.45 - SwitchInputPage uipro美化（上一Session完成）

### 1.1 音频来源按钮美化（Cyberpunk工业风）

**[默认]按钮（选中状态）**：
- 背景：深海军蓝 `#0d1b2e`
- 边框：青色 `#00d4ff`，宽度2px
- 顶部高光线：1px，颜色 `#00d4ff`
- LED指示点：青色 `#00d4ff` + 内部高亮 `#e0f7ff`
- 文字：青色 `#00d4ff`，Medium粗细

**[TTS合成]按钮（选中状态）**：
- 背景：深绿黑 `#0d2218`
- 边框：绿色 `#22C55E`，宽度2px
- 顶部高光线：1px，颜色 `#22C55E`
- LED指示点：绿色 `#22C55E` + 内部高亮 `#86EFAC`
- 文字：绿色 `#22C55E`，Medium粗细

**未选中状态**（两个按钮一致）：
- 背景：深灰 `#141920`
- 边框：石板灰 `#334155`，宽度1px
- LED点：暗灰 `#475569`
- 文字：灰色 `#9E9E9E`

### 1.2 TTS文字字段灰化（不隐藏）

| 状态 | 旧行为 | 新行为 |
|------|--------|--------|
| 默认模式 | `visible: false` 完全隐藏 | 始终显示，readOnly=true，颜色灰化，opacity=0.55 |
| TTS模式 | 显示，黑色背景不可见 | 正常显示，颜色 `#E0E0E0`，opacity=1.0 |

### 1.3 通道状态LED指示器（新增）

位置：保护延时行（row 4, col 2-3）

**uipro双环LED设计**：
- 外环：24x24px，脉冲闪烁动画（激活时）`SequentialAnimation on opacity`
- 内核：14x14px球体，内部3x3px高亮点
- 绿色（激活）：`#22C55E` / `#86EFAC`
- 灰色（正常）：`#475569` / `#64748B`

状态文字（双行）：
- 主文字：`"信号激活 (1)"` / `"正常监测 (0)"`
- 副文字：`"保护已触发"` / `"通道正常"`

---

## 二、Phase 7.47.46 - 报警记录页面全面升级

### 2.1 问题描述

| 旧问题 | 详情 |
|--------|------|
| 硬编码数据 | ListModel内有10条固定测试数据，非真实数据库 |
| 缺少列 | 无保护名称、无事件类型列 |
| 无筛选功能 | 所有按钮均为TODO |
| 使用Emoji | 📊🔄🗑️等emoji不适合工业界面 |
| 未连接数据库 | 底部显示"数据库连接: 未连接" |

### 2.2 修改1 - main.cpp：保护触发记录到报警历史

```cpp
// ✅ 2026-02-28 [Phase 7.47.46]: 连接保护触发信号到报警历史数据库
QObject::connect(&mqttProtectionMonitor, &MqttProtectionMonitor::protectionTriggered,
    [&alarmHistoryDB](int /*moduleIndex*/, int /*bitIndex*/, int beltNumber,
                      const QString &protectionName, const QString &/*audioPath*/) {
        QString protectionType = QString("%1号皮带").arg(beltNumber);
        alarmHistoryDB.saveAlarmTriggered(protectionName, protectionType, 0.0);
        qDebug() << "📝 [Main] 保护触发已记录到报警历史 -"
                 << protectionName << "皮带:" << beltNumber;
    });
```

**原理**：
- `MqttProtectionMonitor::protectionTriggered` 信号在DI位从0→1时发射
- Lambda回调调用 `alarmHistoryDB.saveAlarmTriggered(name, type, 0.0)`
- 保护类型字段存储 `"X号皮带"` 信息
- 不修改 MqttProtectionMonitor 类（零侵入）

### 2.3 修改2 - AlarmPage.qml：完整重写

#### 新增表格列结构

| 列 | 宽度 | 内容 |
|----|------|------|
| # | 50px | 行序号 |
| 日期 | 115px | yyyy-MM-dd |
| 时间 | 100px | HH:mm:ss |
| 保护名称 | 130px | 急停/跑偏/撕裂... |
| 事件 | 96px | 红色Badge"保护触发"/绿色Badge"保护恢复" |
| 详情 | fill | protectionType 或 "触发值: x.xx" |

#### 筛选功能

**日期快速筛选**（互斥按钮）：
- `[全部]` → `queryAlarmHistory(500, 0)` (ORDER BY timestamp DESC)
- `[今日]` → `queryAlarmByDateRange(今日00:00, 今日23:59)`
- `[近7天]` → `queryAlarmByDateRange(7天前, 现在)`

**保护名称筛选**（ComboBox）：
- 选项：全部保护 / 急停 / 跑偏 / 撕裂 / 烟雾 / 温度 / 护网 / 堆煤 / 主机急停
- 使用 `queryAlarmByProtection(name, 500)`
- 选择名称时自动清除日期筛选
- 使用 `onActivated`（不用 `onCurrentIndexChanged`），避免初始化时重复触发

#### 统计信息（标题栏右侧）

- 今日报警计数 badge（有报警时红色闪烁LED + 红色文字）
- 总记录数 badge（青色）

#### 视觉风格变化

| 旧设计 | 新设计 |
|--------|--------|
| 深蓝 `#1a1a2e` | 深黑 `#0d1117` |
| Emoji按钮 | 纯文字样式按钮（无emoji） |
| 单色调行背景 | 触发行红色调 / 恢复行绿色调 |
| 无左侧指示条 | 左侧彩色竖条（3px，红/绿） |
| 无空数据提示 | 空数据占位图（三行示意图标） |
| 无实时排序 | DB层 ORDER BY timestamp DESC，最新在顶 |

#### 行背景色规则

```qml
color: {
    if (isTriggered) {   // eventType === "triggered"
        return (index % 2 === 0) ? "#160808" : "#1a0a0a"   // 红色调
    } else {              // eventType === "restored"
        return (index % 2 === 0) ? "#08120a" : "#0a150c"   // 绿色调
    }
}
```

---

## 三、任务3：排序方式（最新在顶）

**无需额外修改**，`AlarmHistoryDatabase::queryAlarmHistory()` 已实现：

```sql
SELECT * FROM alarm_history ORDER BY timestamp DESC LIMIT ? OFFSET ?
```

QML层调用 `queryAlarmHistory(500, 0)` 即自动获得最新在顶的排序。

---

## 四、影响范围

| 文件 | 变化 |
|------|------|
| `src/main/main.cpp` | 新增 `protectionTriggered → saveAlarmTriggered` 连接 |
| `src/qml/pages/AlarmPage.qml` | 完整重写（660行→486行，更精简） |
| `src/qml/components/device_info/pages/SwitchInputPage.qml` | uipro按钮美化 + LED状态指示 |
| `src/control/AlarmHistoryDatabase.h/.cpp` | 无变化 |
| `src/control/MqttProtectionMonitor.h/.cpp` | 无变化 |

---

## 五、使用说明

### 触发流程（设备端）
1. MQTT DI模块报告位变化（0→1）
2. `DIDataManager::bitChanged` 信号
3. `MqttProtectionMonitor::onBitChanged` 处理 → 发射 `protectionTriggered`
4. main.cpp lambda → `alarmHistoryDB.saveAlarmTriggered(name, type, 0.0)`
5. 用户打开报警记录页面 → 点击"刷新" → 查看最新记录

### Windows模拟测试（无MQTT硬件）
可在 QML 控制台或按钮中手动调用：
```javascript
alarmHistoryDB.saveAlarmTriggered("急停", "1号皮带", 0.0)
alarmHistoryDB.saveAlarmTriggered("跑偏", "1号皮带", 0.0)
// 打开报警记录页面点击刷新即可看到记录
```
