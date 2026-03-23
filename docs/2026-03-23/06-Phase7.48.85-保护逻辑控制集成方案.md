# Phase 7.48.85 - 保护逻辑控制集成方案

## 修改时间
2026-03-23 (北京时间)

## 背景
当前系统已实现各类保护的检测和报警播放（通过 MqttProtectionMonitor），但保护触发后**仅播放音频报警**，并未执行实际的停车控制动作。数据库中已有 `protection_level` 字段（0=紧急停车, 1=正常停车, 2=仅预警, 3=不处理），但该字段未被用于触发控制逻辑。

## 问题描述
1. 保护触发时只播放报警音频，不执行停车
2. 启动/停止的触发源仅限于 R/S 键
3. 缺少主站通讯失败、紧急停车等远程停车源
4. 无法区分紧急停车和正常停车

## 设计方案

### 新增 ProtectionLogicController 类
独立的保护逻辑控制器，接收保护触发信号，根据 `protection_level` 执行控制动作：

```
保护触发信号（来自多个源）
    ↓
ProtectionLogicController
    ├─ level=0 → emergencyStop（跳过停车音频，直接停止序列）
    ├─ level=1 → normalStop（播放停车音频 + 停止序列）
    ├─ level=2 → 仅报警（已由 AlarmPlaybackService 处理）
    └─ level=3 → 不处理
```

### 停车源分类（12个，含4个预留）

| 编号 | 停车源 | 类型 | 来源 |
|------|--------|------|------|
| 0 | R/S键手动控制 | 手动 | QML键盘事件 |
| 1 | 开关量保护 | 自动 | MqttProtectionMonitor.onBitChanged |
| 2 | 模拟量保护 | 自动 | MqttProtectionMonitor.onAIChannelChanged |
| 3 | 电机保护 | 自动 | MqttProtectionMonitor.onMotorRegisterReceived |
| 4 | CS沿线点位 | 自动 | MqttProtectionMonitor.onCSBitChanged |
| 5 | 张紧控制 | 自动 | 张紧传感器超限 |
| 6 | 主站通讯失败 | 自动 | MQTT连接断开超时 |
| 7 | 主站紧急停车 | 远程 | MQTT主题接收 |
| 8-11 | 预留 | 占位 | 未定义 |

### CommonControl 新增紧急停车方法
```cpp
void CommonControl::emergencyStopBelt(int beltNumber)
{
    m_isFaultStop = true;   // 标记故障停车（跳过停车音频）
    stopBelt(beltNumber);   // 复用现有停止逻辑
}
```

### stopBelt 内部新增故障停车分支
```cpp
// 故障停车跳过停车音频，直接执行停止序列
if (m_isFaultStop) {
    m_isFaultStop = false;
    stopDeviceSequence();
    return;
}
```

### MqttProtectionMonitor 新增信号
```cpp
// 保护动作信号（携带 protection_level）
void protectionActionRequired(int beltNumber, const QString &protectionName,
                               int protectionLevel, int source);
void protectionActionCleared(int beltNumber, const QString &protectionName, int source);
```

在 onBitChanged、onAIChannelChanged、onMotorRegisterReceived、onCSBitChanged 中：
- 保护触发时 → emit protectionActionRequired
- 保护恢复时 → emit protectionActionCleared

### 防重复停车机制
- `m_beltStopped[beltNumber]` 标志
- 同一皮带多个保护同时触发，只执行一次停车
- 所有保护恢复后才清除停车标志

## 修改文件清单

| 文件 | 修改类型 | 修改内容 |
|------|---------|---------|
| `src/control/ProtectionLogicController.h` | 新增 | 保护逻辑控制器头文件 |
| `src/control/ProtectionLogicController.cpp` | 新增 | 保护逻辑控制器实现 |
| `src/control/CommonControl.h` | 修改 | 新增 emergencyStopBelt() 声明 |
| `src/control/CommonControl.cpp` | 修改 | 新增 emergencyStopBelt() + stopBelt 故障分支 |
| `src/control/MqttProtectionMonitor.h` | 修改 | 新增 protectionActionRequired/Cleared 信号 |
| `src/control/MqttProtectionMonitor.cpp` | 修改 | 4个处理函数中 emit 新信号 |
| `src/main/main.cpp` | 修改 | 创建 ProtectionLogicController 并连接信号 |
| `src/control/CMakeLists.txt` | 修改 | 添加新文件到编译列表 |

## 数据流

```
保护触发前：
DI/AI/Motor/CS → MqttProtectionMonitor → AlarmPlaybackService → 播放音频 ✅

保护触发后（新增）：
DI/AI/Motor/CS → MqttProtectionMonitor → protectionActionRequired信号
    → ProtectionLogicController.onProtectionTriggered()
    → 检查 protection_level
    → level=0: CommonControl.emergencyStopBelt()
    → level=1: CommonControl.stopBelt()
    → level=2: 不停车（仅报警）
    → level=3: 不处理
```

## 验证方法
1. 编译通过（Docker交叉编译）
2. protection_level=0：保护触发 → 跳过停车音频 → 直接停止序列
3. protection_level=1：保护触发 → 播放停车音频 → 停止序列
4. protection_level=2：保护触发 → 仅报警，不停车
5. protection_level=3：保护触发 → 什么都不做
6. enabled=0：保护不触发任何动作
7. 同一皮带多个保护同时触发，只执行一次停车
