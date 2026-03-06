# Phase 7.48.13 — 模拟量界面5项修复

**日期**：2026-03-06
**阶段**：Phase 7.48.13
**类型**：界面修复 + 数据清理
**用时**：60 分钟

---

## 一、问题列表

| 序号 | 问题描述 | 严重程度 |
|------|---------|---------|
| 1+2 | 保护列表排序不合理，设备端显示风速/粉尘浓度在最前面 | 中 |
| 3 | 模块类型ComboBox显示4个旧选项（输入模块1-4/输出模块/主模块） | 中 |
| 4 | LED指示灯与开关量不一致（静态绿色，无动画/状态切换） | 低 |
| 4-AD | AD值一直为0，工程量显示0.00 | 高 |
| 5 | 音频文件路径显示黑色"音频文件路径（只读）"，不随音频来源变化 | 中 |
| 追加 | 设备残留旧拆分保护项（速度超速/低速打滑/张力上限等） | 高 |

---

## 二、修复方案

### 2.1 问题1+2：保护列表排序

**根因**：
- QML ListModel 按模块+通道号排列，常用项不在顶部
- DB查询 `ORDER BY register_address` 导致 register_address=-1 的风速/粉尘浓度排最前

**修复**：
- ListModel 重排序：速度→张力→温度一→温度二→温度→湿度→甲烷→粉尘浓度→其余
- initDefaultAnalogProtections 数组同步重排序
- DB查询改为 `ORDER BY id`（保持插入顺序）

### 2.2 问题3：模块类型ComboBox

**根因**：ComboBox model 仍为旧的6个选项

**修复**：改为 `["模拟量模块1", "模拟量模块2"]`，删除旧的 onCurrentTextChanged 自动设置寄存器地址逻辑

### 2.3 问题4-LED：LED指示灯

**根因**：使用静态绿色 Rectangle，无动画、无状态切换、无 mqttAutoManager 连接

**修复**：重构为与开关量 SwitchInputPage 完全一致的样式：
- 外环动画（SequentialAnimation 呼吸效果）
- 内核 + 高亮点
- 状态颜色切换（绿色=在线，红色=离线，青色=模块在线，黄色=模块无响应）
- 连接 mqttAutoManager.healthStatus（模拟量模块1→索引2，模拟量模块2→索引3）

### 2.4 问题4-AD：AD值为0

**根因**：只有 adValueText 和 engineeringValueText 的定义，没有任何数据更新逻辑

**修复**：
- 添加 Connections 监听 `aiDataManager.onChannelChanged` 信号
- 匹配当前选中保护项的模块和通道号
- 实时更新 AD 值和工程量（工程量 = 下限 + AD/65535 × 量程）
- 添加 `refreshADValue()` 函数，切换保护项时主动刷新

### 2.5 问题5：音频文件路径

**根因**：audioField 使用静态黑色占位文字，无 getAudioFileName 函数

**修复**：
- 添加 `getAudioFileName(protectionName)` 函数（default→.mp3，tts→.wav）
- 添加 `onAudioSourceModeChanged` 处理器，切换音频来源时自动更新
- audioField 占位文字改为"未配置音频文件"，颜色改为 #E0E0E0
- loadProtectionData 中使用 getAudioFileName 生成默认文件名

### 2.6 追加：旧拆分保护项残留

**根因**：迁移003在早期版本执行时还没有删除拆分项的逻辑，后来代码更新但迁移已标记为"已执行"

**修复**：添加迁移006，删除旧拆分保护项（速度超速/低速打滑/张力上限/张力下限/电压过压/电压欠压）

---

## 三、修改文件

| 文件 | 修改内容 |
|------|---------|
| `src/qml/.../AnalogInputPage.qml` | ListModel重排序、ComboBox更新、LED重构、AD值更新、音频路径更新 |
| `src/control/DeviceConfigManager.cpp` | ORDER BY id、数组重排序、迁移006 |

---

## 四、数据库迁移006

```sql
DELETE FROM device_analog_protections
WHERE protection_name IN ('速度超速', '低速打滑', '张力上限', '张力下限', '电压过压', '电压欠压')
```

---

## 五、完成总结

✅ 保护列表按常用优先排序（速度/张力/温度一/温度二/温度/湿度/甲烷/粉尘浓度）
✅ 模块类型ComboBox更新为2个选项
✅ LED指示灯与开关量完全一致（动画+状态颜色+文字）
✅ AD值和工程量实时更新
✅ 音频文件路径根据音频来源自动变化
✅ 迁移006清理旧拆分保护项
