# Phase 7.48.26 — 洒水使能 + 模拟量通道自定义

**日期**：2026-03-09
**阶段**：Phase 7.48.26
**分支**：feature/hardware-video-codec

---

## 概述

本次实现两个功能：
1. **洒水使能**：模拟量/开关量保护触发时，可选联动洒水功能（通过MQTT继电器模块输出）
2. **通道自定义**：允许用户修改模拟量保护的通道映射（模块类型 + 通道号），支持"未分配"选项

---

## 任务一：洒水使能

### 功能说明

- 每个AI/DI保护项新增 `sprinkler_enabled` 字段（数据库 + QML界面）
- 默认启用洒水的保护项：
  - **模拟量**：烟雾、温度一、温度二、温度
  - **开关量**：烟雾、温度
- 洒水输出配置（全局唯一）：
  - 模块类型：继电器模块
  - 通道：7
  - MQTT Topic：`belt_control/relay/module1/control`
- 多保护触发时，洒水持续激活；所有触发源恢复后才关闭洒水

### 数据库变更

#### 新增列
```sql
ALTER TABLE device_analog_protections ADD COLUMN sprinkler_enabled BOOLEAN DEFAULT 0;
ALTER TABLE device_digital_protections ADD COLUMN sprinkler_enabled BOOLEAN DEFAULT 0;
```

#### 新增表
```sql
CREATE TABLE IF NOT EXISTS sprinkler_output_config (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    module_type TEXT DEFAULT '继电器模块',
    channel INTEGER DEFAULT 7,
    mqtt_topic TEXT DEFAULT 'belt_control/relay/module1/control',
    enabled BOOLEAN DEFAULT 1,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 迁移（migration 013）
- 模拟量保护：烟雾/温度一/温度二/温度 → `sprinkler_enabled = 1`
- 开关量保护：烟雾/温度 → `sprinkler_enabled = 1`
- 初始化洒水输出配置记录

### MQTT命令格式

```json
{
    "cmd": "write",
    "channel": 7,
    "value": 1,
    "timestamp": 1709123456
}
```

- `value=1`：启动洒水
- `value=0`：停止洒水

### 洒水控制逻辑

```
保护触发 → 查询 sprinkler_enabled
  ├─ enabled=1 → 加入触发源Map → 发布洒水启动命令
  └─ enabled=0 → 不处理

保护恢复 → 从触发源Map移除
  ├─ 还有其他触发源 → 洒水保持
  └─ 所有触发源恢复 → 发布洒水停止命令
```

---

## 任务二：模拟量通道自定义

### 功能说明

- `moduleTypeCombo` 新增 "未分配" 选项
- 选择"未分配"时通道自动设为 -1 并禁用通道选择器
- 保存时进行重复通道校验（警告但允许保存）

### 通道修改后果分析

| 后果 | 影响 | 处理方式 |
|------|------|---------|
| 活跃报警 | key是 `belt:protName`（与通道无关） | 自愈：新通道数据到来后自动判断 |
| 历史记录 | 使用 protection_name | 无影响 |
| 边沿触发状态 | key = `belt:protName` | 无影响 |
| 洒水触发源 | key = `belt:protName` | 无影响 |
| AD实时显示 | moduleType+registerAddress | 保存后更新ListModel |
| 重复通道 | 两个保护指向同一通道 | 保存时警告 |

---

## 修改文件

| 文件 | 修改内容 |
|------|---------|
| `src/control/DeviceConfigManager.cpp` | DB schema + migration 013 + save/load更新 + 洒水配置API |
| `src/control/DeviceConfigManager.h` | 新增 loadSprinklerOutputConfig/saveSprinklerOutputConfig 声明 |
| `src/control/MqttProtectionMonitor.h` | MQTTController成员 + 洒水状态 + 方法声明 |
| `src/control/MqttProtectionMonitor.cpp` | 洒水控制逻辑 + DI恢复处理 + AI触发/恢复调用 |
| `src/main/main.cpp` | 注入 MQTTController 到 MqttProtectionMonitor |
| `src/qml/.../AnalogInputPage.qml` | 洒水使能开关 + "未分配"通道 + 重复校验 |

---

## 测试要点

1. **洒水使能开关**
   - 编辑模拟量保护项，洒水使能开关显示/保存正确
   - 默认值：烟雾/温度一/温度二/温度=开启，其余=关闭

2. **洒水触发**
   - 烟雾超限 → 洒水启动
   - 烟雾恢复 → 若无其他触发源 → 洒水停止
   - 烟雾+温度同时超限 → 烟雾恢复 → 洒水保持 → 温度恢复 → 洒水停止

3. **通道自定义**
   - 选择"未分配"后通道设为-1，通道选择器禁用
   - 保存两个保护到相同通道 → 控制台显示警告
   - 修改通道后AD值显示切换到新通道数据

4. **数据库迁移**
   - 老数据库升级后烟雾/温度保护自动启用洒水
   - 洒水输出配置表自动创建和初始化
