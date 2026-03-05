# Phase 7.48.5 - 模拟量保护扩展至21项实施计划

## 时间
2026-03-05 09:10 (北京时间)

## 背景

基于两份已审核确认的规划文档：
- **16-开关量与模拟量音频文件对应关系.md**（8项审核全部确认）：21项保护、无优先级、每皮带独立
- **15-模拟量输入保护参数布局规划.md**（4项确认全部完成）：18参数布局、只读区、2按钮

当前代码状态：DB默认7项保护、BatchAudio 8项DEFS、QML 14参数、AI触发未连接。

---

## 实施步骤

### 步骤1: 数据库迁移（DeviceConfigManager.cpp）

**修改内容**：
1. 追加3条 ALTER TABLE（data_timeout/connection_timeout/input_type）在行199附近
2. `initDefaultAnalogProtections()`：7项 → 21项，删除电流一/电流二，改名5项
3. `runMigrations()` 添加迁移003：旧设备补充缺失保护项 + UPDATE旧名 + DELETE电流
4. `saveAnalogProtection()`：16列 → 19列（+data_timeout/connection_timeout/input_type）

**验证**：编译通过 + 日志确认21项初始化

---

### 步骤2: BatchAudioGenerator DEFS（BatchAudioGenerator.cpp）

**修改内容**：
- `generateAnalogInputTasks()` 行390-399：8项DEFS → 21项
- 改名6项（张力过大→张力上限、温度一过高→温度一、电压过高→电压过压等）
- 新增13项（煤流/煤仓高度/温度/湿度/烟雾浓度/气压/氧气/甲烷/一氧化碳/硫化氢/二氧化碳/风速/粉尘浓度）

**验证**：编译通过 + 批量生成预览显示168个任务

---

### 步骤3: AudioPathMapper 模拟量映射（AudioPathMapper.h/.cpp）

**修改内容**：
- 新增 `ANALOG_PROTECTION_AUDIO_MAP`（DB保护名→音频文件名，21条映射）
- 新增 `getAnalogAudioPath(beltNumber, protectionName)` 方法
- 注意烟雾→烟雾浓度的映射（DB名与文件名不同）

**验证**：编译通过

---

### 步骤4: AnalogInputPage.qml 界面重构

**修改内容**（工作量最大）：
1. ListModel：旧保护列表 → 21项
2. 新属性：audioSourceMode/playModeSelection/protectionLevel/inputType
3. GridLayout 重构为9行（Row 0-3与开关量一致，Row 4-8模拟量特有）
4. RadioButton → 按钮组（音频来源）
5. 新增控件：数据超时SpinBox/连接超时SpinBox/播放方式按钮组/输入类型下拉框/保护级别下拉框
6. 只读区：AD值文本框/工程量文本框/MQTT LED/模块状态LED
7. 底部3按钮 → 2按钮（添加保护项+删除保护项）
8. `getParamFieldCount()` → 18
9. `loadProtectionData()`/`saveProtectionData()` 新增字段
10. `triggerParamInput()` 14个case → 18个case

**验证**：编译通过 + 界面显示21项保护 + 18参数导航正常 + 保存加载正常

---

### 步骤5: 模拟量保护触发（MqttProtectionMonitor.h/.cpp + main.cpp）

**修改内容**：
1. MqttProtectionMonitor 新增 `onAIChannelChanged(moduleIndex, channelIndex, data)` 槽
2. 逻辑：channelChanged → 查DB保护配置 → AD值转工程量 → 比较上下限 → 超限触发AlarmPlaybackService
3. main.cpp 连接 `aiDataManager.channelChanged` → `mqttProtectionMonitor.onAIChannelChanged`

**验证**：模拟量数据超阈值 → 日志显示触发 → 音频播放

---

### 步骤6: 编译部署 + 批量生成音频

```powershell
.\build-ubuntu24-apt.ps1 185
```
设备上运行批量合成：21项 × 8皮带 = 168个音频文件

---

## 执行顺序

步骤1 → 步骤2 → 步骤3 →（编译验证）→ 步骤4 → 步骤5 →（编译部署）→ 步骤6

步骤1/2/3相互独立可并行。步骤4依赖1。步骤5依赖1+3。

## 21项保护完整列表

### 设备运行保护（10项）
1. 速度超速(m/s) 2. 低速打滑(m/s) 3. 张力上限(T) 4. 张力下限(T) 5. 煤流(t/h)
6. 煤仓高度(m) 7. 温度一(℃) 8. 温度二(℃) 9. 电压过压(V) 10. 电压欠压(V)

### 环境安全监测（8项）
11. 温度(℃) 12. 湿度(%RH) 13. 烟雾(mg/m³) 14. 气压(kPa) 15. 氧气(%O₂)
16. 甲烷(%CH₄) 17. 一氧化碳(ppm) 18. 硫化氢(ppm)

### 安规补充（3项）
19. 二氧化碳(%CO₂) 20. 风速(m/s) 21. 粉尘浓度(mg/m³)

## 关键文件

| 文件 | 步骤 |
|------|------|
| `src/control/DeviceConfigManager.cpp` | 1 |
| `src/control/BatchAudioGenerator.cpp` | 2 |
| `src/control/AudioPathMapper.h/.cpp` | 3 |
| `src/qml/components/device_info/pages/AnalogInputPage.qml` | 4 |
| `src/control/MqttProtectionMonitor.h/.cpp` | 5 |
| `src/main/main.cpp` | 5 |
