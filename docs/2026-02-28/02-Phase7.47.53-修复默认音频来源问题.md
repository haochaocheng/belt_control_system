# 修复方案 - 默认音频来源问题

## 修复内容总结

### 代码修改

#### 1. 开关量保护初始化（src/control/DeviceConfigManager.cpp 第405行）
```cpp
// ✅ 2026-02-28 [Phase 7.47.53]: 修复 - 添加 use_text_to_speech = 0
// 旧代码：INSERT ... (device_id, protection_name, ..., tts_text) VALUES ...
// 新代码：INSERT ... (device_id, protection_name, ..., tts_text, use_text_to_speech) VALUES ..., 0)
```
**影响**：新建保护记录时显式设置 `use_text_to_speech = 0`（默认音频），而不依赖表的DEFAULT值

#### 2. 模拟量保护初始化（src/control/DeviceConfigManager.cpp 第458行）
```cpp
// ✅ 2026-02-28 [Phase 7.47.53]: 修复 - 添加 use_text_to_speech = 0
// 与开关量保护保持一致
```
**影响**：模拟量保护也默认为0（默认音频）

#### 3. 数据库迁移脚本增强（src/control/DeviceConfigManager.cpp 第304行）
```cpp
// ✅ 2026-02-28 [Phase 7.47.53]: 增强迁移脚本
// - 改为迁移001（开关量保护）、迁移002（模拟量保护）
// - 添加详细的日志输出，便于调试
// - 改进错误处理和检查逻辑
```
**影响**：历史数据也会被修复，所有旧的use_text_to_speech=1会改为0

---

## 修复流程

### 流程 A：重新初始化数据库（推荐）

#### 步骤 1：停止应用并清理数据库
```powershell
# 方式1：使用自动脚本
.\scripts\2026-02-28\01-cleanup-database-for-audiofix.ps1 185

# 方式2：手动执行
ssh linaro@192.168.10.185
docker stop belt-control-app 2>/dev/null || true
rm -f /home/linaro/belt-control-data/device_config.db
rm -f /home/linaro/belt-control-data/device_config.db-journal
exit
```

#### 步骤 2：重新编译和部署
```powershell
.\build-ubuntu24-apt.ps1 185
```

**此时发生的事**：
1. 编译新代码（包含修复）
2. 构建Docker镜像
3. 启动容器时：
   - 数据库不存在，会重新创建
   - `initDatabase()` → `createTables()` → `runMigrations()` → `initDefaultData()`
   - 新创建的所有保护记录都有 `use_text_to_speech = 0`
   - 迁移脚本执行（虽然无旧数据可修复，但会打印日志）

#### 步骤 3：验证日志
```bash
# 查看应用日志，搜索以下关键词：
# ✓ "✅ [DeviceConfigManager] 数据库初始化完成"
# ✓ "✅ [DeviceConfigManager] 迁移001: 重置 0 条开关量保护..."（0条是正常的，因为是新建）
# ✓ "✅ [DeviceConfigManager] 迁移002: 重置 0 条模拟量保护..."（0条是正常的）
```

---

## 验证清单

### ✅ 数据库层验证

```bash
# SSH连接到设备
ssh linaro@192.168.10.185

# 进入Docker容器
docker exec -it belt-control-app bash

# 查看数据库中的数据
sqlite3 /home/linaro/belt-control-data/device_config.db

# 验证开关量保护
sqlite> SELECT device_id, protection_name, use_text_to_speech FROM device_digital_protections LIMIT 5;
1|急停|0
1|跑偏|0
1|撕裂|0
1|烟雾|0
1|温度|0

# 验证模拟量保护
sqlite> SELECT device_id, protection_name, use_text_to_speech FROM device_analog_protections LIMIT 5;
1|速度|0
1|张力|0
1|红外温度一|0
1|红外温度二|0
1|电流一|0

# 验证没有任何use_text_to_speech=1的记录
sqlite> SELECT COUNT(*) FROM device_digital_protections WHERE use_text_to_speech = 1;
0

sqlite> SELECT COUNT(*) FROM device_analog_protections WHERE use_text_to_speech = 1;
0

# 验证迁移记录
sqlite> SELECT version FROM schema_migrations;
001_reset_audio_source_digital
002_reset_audio_source_analog

sqlite> .quit
```

### ✅ UI层验证

1. **打开"开关量输入"设置**
   - 选择任意皮带
   - 点击"急停"保护
   - 查看"音频来源"按钮
   - **预期**：`[默认]` 按钮被选中（深蓝背景 + 青色边框）

2. **选择"默认音频"并保存**
   - 点击 `[默认]` 按钮（如果已选，跳过）
   - 点击 `保存` 按钮
   - **预期**：弹出成功提示

3. **查看日志**
   - 打开voip.md日志窗口
   - 搜索"急停"
   - **预期**：`[DEBUG] 📋 [MqttProtectionMonitor] 保护 "急停" 音频来源: 默认(1#PD MP3)`
   - 而不是：`[DEBUG] 📋 [MqttProtectionMonitor] 保护 "急停" 音频来源: TTS合成`

### ✅ 功能层验证

1. **触发保护**
   - 在MQTT监控中模拟DI位变化（0 → 1）
   - 设置"1号皮带"的"急停"保护

2. **验证日志**
   ```
   [DEBUG] 🚨 [MqttProtectionMonitor] 检测到DI位变化:
   [DEBUG]    模块索引: 0
   [DEBUG]    位索引: 0
   [DEBUG]    位值: 1
   [DEBUG]    对应皮带: 1 号
   [DEBUG]    保护名称: "沿线急停"
   [DEBUG] 📋 [MqttProtectionMonitor] 保护 "沿线急停" 音频来源: 默认(1#PD MP3)  ← ✅ 关键
   [DEBUG] 🎵 [AudioPathMapper] 生成音频路径: "/home/linaro/belt-control-data/audio/1#PD/沿线急停.mp3"
                                                                        ↑ .mp3不是.wav
   ```

3. **验证播放**
   - 应该听到 `.mp3` 文件（1#PD预置）
   - 不应该听到 `.wav` 文件（TTS合成）
   - 文件名应该是：`沿线急停.mp3`（而不是`沿线急停.wav`）

---

## 流程 B：修复已有数据（无需重建数据库）

如果不想删除现有数据库和配置，可以直接执行SQL修复：

```bash
# 方式1：在Docker容器内执行
docker exec -it belt-control-app bash
sqlite3 /home/linaro/belt-control-data/device_config.db << EOF

-- 修复开关量保护
UPDATE device_digital_protections SET use_text_to_speech = 0 WHERE use_text_to_speech = 1;
SELECT changes() as 'Fixed digital protections';

-- 修复模拟量保护
UPDATE device_analog_protections SET use_text_to_speech = 0 WHERE use_text_to_speech = 1;
SELECT changes() as 'Fixed analog protections';

-- 标记迁移已执行
INSERT OR IGNORE INTO schema_migrations (version) VALUES ('001_reset_audio_source_digital');
INSERT OR IGNORE INTO schema_migrations (version) VALUES ('002_reset_audio_source_analog');

-- 验证结果
SELECT COUNT(*) as 'Digital with use_tts=1' FROM device_digital_protections WHERE use_text_to_speech = 1;
SELECT COUNT(*) as 'Analog with use_tts=1' FROM device_analog_protections WHERE use_text_to_speech = 1;
EOF
```

---

## 问题排查指南

### 日志中看到"TTS合成"怎么办？

1. **检查迁移是否执行**
   ```bash
   docker exec -it belt-control-app tail -50 /var/log/app.log | grep -i "迁移"
   ```
   - ✅ 正常：看到"迁移001"和"迁移002"的日志
   - ❌ 异常：看不到迁移日志

2. **检查数据库中的数据**
   ```bash
   docker exec -it belt-control-app sqlite3 /home/linaro/belt-control-data/device_config.db \
     "SELECT COUNT(*) FROM device_digital_protections WHERE use_text_to_speech = 1;"
   ```
   - ✅ 结果为0：数据已修复
   - ❌ 结果> 0：数据未修复，需要执行流程B

3. **检查代码修改是否编译进去**
   ```bash
   # 重新完整编译（清除缓存）
   rm -rf build_rk3588
   rm -rf docker/rk3588/build_temp
   .\build-ubuntu24-apt.ps1 185
   ```

### 仍然没有解决怎么办？

1. **验证修改是否保存到文件**
   ```bash
   grep -n "use_text_to_speech, 0" src/control/DeviceConfigManager.cpp
   # 应该在第407行左右（开关量）和第461行左右（模拟量）看到
   ```

2. **清理所有缓存重新编译**
   ```bash
   docker system prune -af  # 删除所有Docker镜像和容器
   .\build-ubuntu24-apt.ps1 185
   ```

3. **手动检查Docker镜像**
   ```bash
   docker inspect belt-control-app 2>/dev/null | grep -i mtime  # 查看镜像创建时间
   # 如果时间不是最新的，说明镜像没有更新，需要重新编译
   ```

---

## 时间记录

| 阶段 | 内容 | 预计时间 |
|-----|------|--------|
| 代码修改 | DeviceConfigManager.cpp 修复 | ✅ 已完成 |
| 数据库清理 | 删除旧数据库 | 1分钟 |
| 编译部署 | build-ubuntu24-apt.ps1 185 | 5-10分钟 |
| 验证数据库 | SQL查询验证 | 1分钟 |
| 验证UI | 检查音频来源按钮状态 | 2分钟 |
| 验证功能 | 触发保护并检查日志 | 3分钟 |
| **总计** | | **12-17分钟** |

---

## 后续预防

### 编码规范
1. **显式指定所有DEFAULT字段** - 不要依赖表定义的DEFAULT值
2. **字段顺序保持一致** - INSERT语句的字段顺序应与表定义一致
3. **添加详细的迁移日志** - 便于调试和验证

### 数据库版本管理
- 使用 `schema_migrations` 表记录所有数据库迁移
- 每个迁移都应该有清晰的日志输出
- 迁移应该幂等（重复执行不会产生副作用）

---

## Phase标记
- **Phase 7.47.53**：修复默认音频来源问题
- **相关PRs**：Phase 7.47.44, 7.47.49, 7.47.52
