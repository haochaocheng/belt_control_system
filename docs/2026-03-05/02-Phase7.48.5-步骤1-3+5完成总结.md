# Phase 7.48.5 步骤1-3+5完成总结

## 时间
2026-03-05 10:30 (北京时间)

## 完成状态

✅ **步骤1**: 数据库迁移（DeviceConfigManager.cpp）
✅ **步骤2**: BatchAudioGenerator DEFS（8项→21项）
✅ **步骤3**: AudioPathMapper 模拟量映射
✅ **步骤5**: MqttProtectionMonitor 模拟量触发 + main.cpp连接
⏸️ **步骤4**: AnalogInputPage.qml 界面重构 — 推迟到 Phase 7.48.6

---

## 已完成功能

### 1. 数据库层（DeviceConfigManager.cpp）

**ALTER TABLE 新增3列**：
```sql
ALTER TABLE device_analog_protections ADD COLUMN data_timeout REAL DEFAULT 30.0;
ALTER TABLE device_analog_protections ADD COLUMN connection_timeout REAL DEFAULT 60.0;
ALTER TABLE device_analog_protections ADD COLUMN input_type TEXT DEFAULT '4-20mA';
```

**默认保护项扩展**：7项 → 21项
- 删除：电流一/电流二
- 改名：速度→速度超速、张力→张力上限、红外温度一→温度一、红外温度二→温度二、电压→电压过压
- 新增：低速打滑、张力下限、煤流、煤仓高度、电压欠压、温度、湿度、烟雾、气压、氧气、甲烷、一氧化碳、硫化氢、二氧化碳、风速、粉尘浓度

**saveAnalogProtection() 扩展**：16列 → 21列
- 新增字段：play_mode、protection_level、data_timeout、connection_timeout、input_type

### 2. 音频生成层（BatchAudioGenerator.cpp）

**DEFS 扩展**：8项 → 21项
- 改名6项：张力过大→张力上限、张力过小→张力下限、温度一过高→温度一、温度二过高→温度二、电压过高→电压过压、电压过低→电压欠压
- 新增13项：煤流、煤仓高度、温度、湿度、烟雾浓度、气压、氧气、甲烷、一氧化碳、硫化氢、二氧化碳、风速、粉尘浓度

**音频文件总数**：21项 × 8条皮带 = **168个音频文件**

### 3. 音频路径映射层（AudioPathMapper.h/.cpp）

**新增静态映射表**：`ANALOG_PROTECTION_AUDIO_MAP`
- 21项保护的 DB保护名 → 音频文件名映射
- 特殊映射：烟雾 → 烟雾浓度（DB名与文件名不同）

**新增方法**：
- `getAnalogAudioFileName(dbProtectionName)` — 静态方法，DB名→文件名
- `getAnalogAudioPath(beltNumber, dbProtectionName)` — 生成完整音频路径

### 4. 保护触发层（MqttProtectionMonitor.h/.cpp + main.cpp）

**新增 AI 支持**：
- 前向声明 `AIDataManager`
- 成员变量 `m_aiManager` 和 `m_aiBeltMapping`
- 方法 `setAIDataManager()` 和 `setAIBeltMapping()`

**新增槽函数 `onAIChannelChanged()`**：
```cpp
void onAIChannelChanged(int moduleIndex, int channelIndex, double adValue)
```

**触发逻辑**：
1. 接收 AIDataManager 的 channelChanged 信号
2. 查询该皮带的所有模拟量保护配置
3. AD值转工程量：`工程量 = 下限 + (AD值/65535) × 范围值`
4. 对比上下限阈值
5. 超限时通过 AlarmPlaybackService 触发报警

**main.cpp 连接**：
```cpp
mqttProtectionMonitor.setAIDataManager(&aiDataManager);
mqttProtectionMonitor.setAIBeltMapping(0, systemConfig.machineNumber());
QObject::connect(&aiDataManager, &AIDataManager::channelChanged,
                 &mqttProtectionMonitor, &MqttProtectionMonitor::onAIChannelChanged);
```

---

## 21项保护完整列表

### 设备运行保护（10项）
1. 速度超速(m/s) 2. 低速打滑(m/s) 3. 张力上限(T) 4. 张力下限(T) 5. 煤流(t/h)
6. 煤仓高度(m) 7. 温度一(℃) 8. 温度二(℃) 9. 电压过压(V) 10. 电压欠压(V)

### 环境安全监测（8项）
11. 温度(℃) 12. 湿度(%RH) 13. 烟雾(mg/m³) 14. 气压(kPa) 15. 氧气(%O₂)
16. 甲烷(%CH₄) 17. 一氧化碳(ppm) 18. 硫化氢(ppm)

### 安规补充（3项）
19. 二氧化碳(%CO₂) 20. 风速(m/s) 21. 粉尘浓度(mg/m³)

---

## 触发规则

- **无优先级**：触发哪个，哪个直接报警
- **每条皮带独立配置**：环境安全监测参数与设备保护一样，按皮带独立设置
- **AD值转工程量**：线性映射公式 `工程量 = 下限 + (AD值/65535) × 范围值`
- **阈值判断**：工程量 > 上限 或 工程量 < 下限 时触发

---

## Git 提交记录

**提交1**（步骤1-3）：
```
71e6907d feat: Phase 7.48.5 步骤1-3 - 数据库+BatchAudio+AudioMapper扩展至21项
```

**提交2**（步骤5）：
```
518cf460 feat: Phase 7.48.5 步骤5 - MqttProtectionMonitor模拟量保护触发+main.cpp连接
```

**推送状态**：✅ 已推送到 GitLab

---

## 步骤4推迟原因

**AnalogInputPage.qml 界面重构**工作量巨大（约1400行代码）：
- ListModel：5项 → 21项
- 参数字段：14个 → 18个
- GridLayout 重构：7行 → 9行
- 新增只读区域：AD值、工程量、MQTT LED、模块状态LED
- 底部按钮：3个 → 2个
- 更新所有相关方法：getParamFieldCount()、triggerParamInput()、loadProtectionData()、saveProtectionData()

**决策**：
- 后端功能（数据库、音频生成、路径映射、保护触发）已完整
- QML界面作为独立的 **Phase 7.48.6** 实施
- 避免一次性修改过多导致难以调试

---

## 下一步工作

### Phase 7.48.6（待实施）
1. AnalogInputPage.qml 完整重构
2. 更新 ListModel 为21项保护
3. 重构 GridLayout 为18参数布局
4. 添加只读区域（AD值+工程量+状态LED）
5. 修改底部按钮为2个
6. 更新所有导航和保存加载方法

### 音频文件生成（待执行）
在设备上运行批量合成：
```bash
# 通过QML批量合成界面
# 勾选"模拟量输入"类别
# 选择皮带1-8
# 执行生成
# 预计168个音频文件（21项 × 8皮带）
```

---

## 技术要点

1. **SQL注释语法**：SQL字符串中必须使用 `--` 而非 `//`
2. **ALTER TABLE向后兼容**：对已存在列返回错误但不影响数据
3. **模拟量通道映射**：register_address 5-26 对应通道 0-21（偏移量5）
4. **AD值转工程量**：线性映射公式适用于4-20mA、0-5V、0-10V等信号类型
5. **音频路径生成**：模拟量使用 `getAnalogAudioPath()`，自动处理DB名→文件名映射

---

## 验证方法

### 数据库验证
```sql
-- 检查新列是否存在
PRAGMA table_info(device_analog_protections);

-- 检查默认保护项数量
SELECT COUNT(*) FROM device_analog_protections WHERE device_id=1;
-- 应返回21

-- 检查保护名称
SELECT protection_name FROM device_analog_protections WHERE device_id=1 ORDER BY id;
```

### 音频生成验证
```bash
# 在QML批量合成界面预览任务列表
# 应显示21项 × 8皮带 = 168个任务
```

### 保护触发验证
```bash
# 模拟AI通道数据超限
# 观察日志输出：
# - "📊 [MqttProtectionMonitor] AI通道变化"
# - "⚠️ [MqttProtectionMonitor] 模拟量保护触发"
# - "🔊 [MqttProtectionMonitor] 模拟量保护触发播放"
# - 音频播放
```
