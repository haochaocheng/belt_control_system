# Phase 7.47.96 - 添加"保护级别"参数（下拉框选择）

## 日期
2026-03-04 21:30

## 需求描述
在开关量输入保护参数设置界面，新增"保护级别"下拉框参数，包含4个选项：
- **0** - 预警+紧急停车：需要预警并且紧急停车
- **1** - 预警+正常停车：需要预警并且正常停车（默认值）
- **2** - 仅预警不停车：需要预警但是不停车
- **3** - 不预警不停车：不预警也不停车

## 实现方案

### QML 界面（SwitchInputPage.qml）
- 新增 `property int protectionLevel: 1`（默认1=预警+正常停车）
- 在 row 6, col 0-1 位置添加 "保护级别:" 标签 + CustomComboBox 下拉框
  - 使用 `DeviceInfo.CustomComboBox`（与模块类型下拉框一致的控件）
  - model: `["预警+紧急停车", "预警+正常停车", "仅预警不停车", "不预警不停车"]`
- 焦点指示器：focusParamIndex === 12
- getParamFieldCount() 从 12 → 13
- triggerParamInput() 添加 case 12（Enter 键循环切换 0→1→2→3→0）
- saveProtectionData() 添加 `"protection_level": root.protectionLevel`
- loadProtectionData() 添加读取 protection_level 并设置 protectionLevel

### 数据库（DeviceConfigManager.cpp）
- ALTER TABLE 迁移：为 device_digital_protections 和 device_analog_protections 添加 protection_level 列
  - `protection_level INTEGER DEFAULT 1`
- saveDigitalProtection() INSERT 语句添加 protection_level 字段
- loadDigitalProtection() 使用 SELECT *，自动包含新列

### 参数布局（索引 0-12）
```
Row 0: 保护名称(0)    | 播放次数(1)
Row 1: 模块类型(2)    | 播放时长(3)
Row 2: 音频来源(4)    | TTS文字(5)
Row 3: 通道编号(6)    | 音频文件(7)
Row 4: 保护延时(8)    | 数据超时(9)
Row 5: 连接超时(10)   | 播放方式(11)
Row 6: 保护级别(12)   |
```

### 导航兼容
DeviceSettingsDialog.qml 的 Up/Down 键使用 `cIdx + 2`（同列下移），
getParamFieldCount 改为 13 后，左列导航自动扩展为 0→2→4→6→8→10→12→按钮。无需修改父组件。

## 修改文件

| 文件 | 修改内容 |
|------|----------|
| src/qml/components/device_info/pages/SwitchInputPage.qml | 新增保护级别 property + ComboBox UI + 导航 + 保存/加载 |
| src/control/DeviceConfigManager.cpp | ALTER TABLE 迁移 + INSERT 添加 protection_level 字段 |

## 不需要修改的文件
- `DeviceSettingsDialog.qml` - Up/Down 导航自动兼容（+2 步进）
- `MqttProtectionMonitor.cpp` - 后端保护级别逻辑待后续 Phase 实现

## 验证方法
1. 编译通过（QML 无语法错误）
2. 设备设置 → 开关量输入保护 → 选择一个保护项
3. 确认"保护级别"出现在"连接超时"下方（row 6, col 0-1）
4. 下拉框可展开，显示4个选项
5. 键盘 Enter 键可循环切换保护级别
6. 导航：从"连接超时"(10)按 Down → 到"保护级别"(12)
7. 保存后重新加载保护项，确认保护级别值保持
