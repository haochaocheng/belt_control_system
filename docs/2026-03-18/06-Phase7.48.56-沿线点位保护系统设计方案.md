# Phase 7.48.56 - 沿线点位保护系统设计方案

## 日期：2026-03-18

## Context

皮带控制系统需要支持沿线急停、沿线跑偏、沿线撕裂三种保护，每种保护最多64个独立点位（可配置1-64）。数据来源为CS模块（模块索引5=CS1，6=CS2），已有MQTT接入。

## 模块索引分配

| 索引 | 模块 | MQTT主题 |
|------|------|----------|
| 0 | DI模块1 | belt_control/di/module1/status |
| 1 | DI模块2 | belt_control/di/module2/status |
| 2 | AI模块1 | belt_control/ai/module1/status |
| 3 | AI模块2 | belt_control/ai/module2/status |
| 4 | DO模块1 | belt_control/do/module1/status |
| 5 | CS模块1 | belt_control/cs/module1/status |
| 6 | CS模块2 | belt_control/cs/module2/status |

## MQTT协议

### 主题
```
belt_control/cs/module1/status   → CS1状态上报（3种保护×64点位）
belt_control/cs/module1/control  → CS1控制命令
```

### 数据格式
```json
{
  "estop": [255, 0, 0, 0, 0, 0, 0, 0],
  "deviation": [0, 0, 0, 0, 0, 0, 0, 0],
  "tear": [0, 0, 0, 0, 0, 0, 0, 0],
  "timestamp": 1234567890
}
```
- 每个字段8字节=64bit，data[0] bit0=1号点位
- bit=1 触发（故障），bit=0 正常

## 实施任务

### 任务1：CSDataManager（C++后端）
- 新增 `src/mqtt/CSDataManager.h/cpp`
- 管理3种保护×64bit，解析合并JSON
- 信号：`bitChanged(int protType, int pointIndex, bool value)`

### 任务2：MQTTAutoManager 集成
- 模块5=CS1，模块6=CS2
- 订阅 `belt_control/cs/module{1,2}/status`
- 轮询读取命令

### 任务3：数据库迁移027
- 192条默认记录（3种×64点位）
- channel_number编码：急停0-63，跑偏100-163，撕裂200-263

### 任务4：LinePositionPage.qml 界面
- 独立大类（类别9），与开关量输入平级
- 左侧3分组×64点位列表，右侧参数面板

### 任务5：MqttProtectionMonitor 集成
- 监听CSDataManager.bitChanged
- 触发音频播放

### 任务6：DeviceSettingsDialog 导航
### 任务7：QML注册+CMake+qrc
