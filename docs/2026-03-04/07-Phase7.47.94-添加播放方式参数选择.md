# Phase 7.47.94 - 添加"播放方式"参数（按次数/按时长选择）

## 日期
2026-03-04 20:30

## 需求描述
开关量输入保护参数列表中已有"播放次数"和"播放时长"两个参数，但程序运行保护时只播放一遍，
没有选择任何一个作为标准。需要增加"播放方式"可选参数，让用户选择保护触发时按次数还是按时长播放。

## 实现方案

### QML 界面（SwitchInputPage.qml）
- 新增 `property int playModeSelection: 0`（0=按次数, 1=按时长）
- 在 row 5, col 2-3 位置添加 "播放方式:" 标签 + Cyberpunk 工业风按钮组
  - [按次数] 按钮：青色高亮 #00d4ff（与"默认"音频来源一致）
  - [按时长] 按钮：橙色高亮 #F59E0B（区分于音频来源的绿色）
- 焦点指示器：focusParamIndex === 11
- getParamFieldCount() 从 11 → 12
- triggerParamInput() 添加 case 11（Enter 键直接切换播放方式）
- saveProtectionData() 添加 `"play_mode"` 字段
- loadProtectionData() 添加读取 play_mode 并设置 playModeSelection

### 数据库（DeviceConfigManager.cpp）
- ALTER TABLE 迁移：为 device_digital_protections 和 device_analog_protections 添加 play_mode 列
- saveDigitalProtection() INSERT 语句添加 play_mode 字段
- loadDigitalProtection() 使用 SELECT *，自动包含新列

### 参数布局（索引 0-11）
```
Row 0: 保护名称(0)    | 播放次数(1)
Row 1: 模块类型(2)    | 播放时长(3)
Row 2: 音频来源(4)    | TTS文字(5)
Row 3: 通道编号(6)    | 音频文件(7)
Row 4: 保护延时(8)    | 数据超时(9)
Row 5: 连接超时(10)   | 播放方式(11)
```

### 导航兼容
DeviceSettingsDialog.qml 的 Up/Down 键使用 `cIdx + 2`（同列下移），
getParamFieldCount 改为 12 后，右列导航自动扩展为 1→3→5→7→9→11→按钮。无需修改父组件。

## 修改文件

| 文件 | 修改内容 |
|------|---------|
| src/qml/components/device_info/pages/SwitchInputPage.qml | 新增播放方式 UI 控件、导航、保存/加载 |
| src/control/DeviceConfigManager.cpp | ALTER TABLE 迁移 + INSERT 添加 play_mode 字段 |

## 不需要修改的文件
- `ProtectionConfig.h` - 已有 playMode 字段
- `AlarmPlaybackService.h/cpp` - 已实现按次数/按时长逻辑
- `DeviceSettingsDialog.qml` - Up/Down 导航自动兼容（+2 步进）

## 验证方法
1. 编译通过（QML 无语法错误）
2. 设备设置 → 开关量输入保护 → 选择一个保护项
3. 确认"播放方式"出现在"连接超时"右边（row 5, col 2-3）
4. 点击"按次数"/"按时长"按钮可以切换，高亮跟随
5. 键盘导航：从"数据超时"(9)按 Down → 到"播放方式"(11)
6. 键盘 Enter 键可切换播放方式
7. 保存后重新加载保护项，确认播放方式值保持
