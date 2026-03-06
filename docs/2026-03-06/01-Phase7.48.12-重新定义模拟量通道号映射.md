# Phase 7.48.12 — 重新定义模拟量通道号映射

**日期**：2026-03-06
**阶段**：Phase 7.48.12
**类型**：配置修正
**用时**：30 分钟

---

## 一、问题描述

### 旧映射（Phase 7.48.8）
18项模拟量保护的 `register_address` 从5开始连续编号（5-22），全部归属"模拟量模块1"。
这不符合实际硬件：每个模拟量输入模块只有8个通道（0-7）。

### 新映射规则
- **模拟量模块1**：通道 0-7（前8项保护）
- **模拟量模块2**：通道 0-7（中间8项保护）
- **风速/粉尘浓度**：暂未分配（register_address = -1），后续可扩展到模拟量模块3

---

## 二、通道号映射表

| 序号 | 保护名称 | 模块 | 通道号 | 旧通道号 |
|------|---------|------|--------|---------|
| 1 | 速度 | 模拟量模块1 | 0 | 5 |
| 2 | 张力 | 模拟量模块1 | 1 | 6 |
| 3 | 煤流 | 模拟量模块1 | 2 | 7 |
| 4 | 煤仓高度 | 模拟量模块1 | 3 | 8 |
| 5 | 温度一 | 模拟量模块1 | 4 | 9 |
| 6 | 温度二 | 模拟量模块1 | 5 | 10 |
| 7 | 电压 | 模拟量模块1 | 6 | 11 |
| 8 | 温度 | 模拟量模块1 | 7 | 12 |
| 9 | 湿度 | 模拟量模块2 | 0 | 13 |
| 10 | 烟雾 | 模拟量模块2 | 1 | 14 |
| 11 | 气压 | 模拟量模块2 | 2 | 15 |
| 12 | 氧气 | 模拟量模块2 | 3 | 16 |
| 13 | 甲烷 | 模拟量模块2 | 4 | 17 |
| 14 | 一氧化碳 | 模拟量模块2 | 5 | 18 |
| 15 | 硫化氢 | 模拟量模块2 | 6 | 19 |
| 16 | 二氧化碳 | 模拟量模块2 | 7 | 20 |
| 17 | 风速 | 未分配 | -1 | 21 |
| 18 | 粉尘浓度 | 未分配 | -1 | 22 |

---

## 三、修改文件

### 3.1 DeviceConfigManager.cpp

**修改1**：结构体新增 `moduleType` 字段
```cpp
struct AnalogProtection {
    QString name;
    QString unit;
    QString moduleType;  // ✅ 新增
    int registerAddress;
    double upperLimit;
    double lowerLimit;
    double range;
    double rated;
};
```

**修改2**：18项保护重新分配模块和通道号
- 模拟量模块1通道0-7：速度/张力/煤流/煤仓高度/温度一/温度二/电压/温度
- 模拟量模块2通道0-7：湿度/烟雾/气压/氧气/甲烷/一氧化碳/硫化氢/二氧化碳
- 未分配：风速(-1)/粉尘浓度(-1)

**修改3**：INSERT 语句中 `"模拟量模块1"` 改为 `p.moduleType`

**修改4**：迁移005 — 修正现有设备的通道号和模块类型
- 遍历18项保护，逐条 UPDATE module_type 和 register_address
- 使用 schema_migrations 表记录版本 `005_fix_channel_mapping`

### 3.2 AnalogInputPage.qml

ListModel 的 `moduleType` 和 `registerAddress` 同步更新为新映射。

### 3.3 MqttProtectionMonitor.cpp

通道匹配逻辑重构：
```cpp
// 旧逻辑：regAddr - 5 = channelIndex
// 新逻辑：模块类型 + 通道号双重匹配
if (regAddr < 0) continue;  // 未分配跳过
QString expectedModule = (moduleIndex == 0) ? "模拟量模块1" : "模拟量模块2";
if (moduleType != expectedModule) continue;  // 模块不匹配
if (regAddr != channelIndex) continue;       // 通道号不匹配
```

---

## 四、数据库迁移005

```sql
-- 对每个保护项执行：
UPDATE device_analog_protections
SET module_type = ?, register_address = ?
WHERE protection_name = ?
```

迁移005确保已部署设备的数据库也更新为新的通道号映射。

---

## 五、完成总结

✅ 16路通道正确分配到2个模拟量模块（各8通道）
✅ 风速/粉尘浓度暂未分配，后续可随时修改
✅ 迁移005自动修正现有设备数据
✅ MqttProtectionMonitor 通道匹配改为模块+通道号双重匹配
