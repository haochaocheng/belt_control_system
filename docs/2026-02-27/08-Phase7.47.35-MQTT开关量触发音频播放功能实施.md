# Phase 7.47.35 - MQTT开关量触发音频播放功能实施

**日期**: 2026-02-27
**阶段**: Phase 7.47.35
**任务**: 实现MQTT开关量输入触发音频播放功能

## 📋 任务概述

实现MQTT开关量输入模块的位变化监控，当检测到保护触发（位从0→1）时，自动生成对应的音频文件路径并播放保护报警音频。

## 🎯 实施目标

1. 创建音频文件路径映射器（AudioPathMapper）
2. 创建MQTT保护监控器（MqttProtectionMonitor）
3. 连接DIDataManager的bitChanged信号到音频播放系统
4. 支持多皮带、多保护类型的音频播放

## 📁 新增文件

### 1. AudioPathMapper.h/cpp
**路径**: `src/control/AudioPathMapper.h`, `src/control/AudioPathMapper.cpp`

**功能**:
- 根据引擎名称、模型名称、说话人ID、皮带编号、保护名称生成音频文件路径
- 路径格式：`{engine}-{model}-spk{id}/{belt}#PD/{protection}.wav`
- 示例：`paddlespeech-fastspeech2_csmsc-spk0/1#PD/急停保护.wav`
- 提供DI位索引到保护名称的映射（基于VoiceFileList.h）

**关键方法**:
```cpp
// 生成音频文件路径
QString getAudioPath(const QString &engineName,
                     const QString &modelName,
                     int speakerId,
                     int beltNumber,
                     const QString &protectionName) const;

// 使用当前TTS配置生成路径
QString getAudioPath(int beltNumber, const QString &protectionName) const;

// 根据DI位索引获取保护名称
QString getProtectionName(int bitIndex) const;
```

### 2. MqttProtectionMonitor.h/cpp
**路径**: `src/control/MqttProtectionMonitor.h`, `src/control/MqttProtectionMonitor.cpp`

**功能**:
- 监听DIDataManager的bitChanged信号
- 检测保护触发（位从0→1）
- 生成音频文件路径
- 调用CommonControl::playAudio()播放音频
- 支持皮带编号映射（模块索引→皮带编号）

**关键方法**:
```cpp
// 启动/停止监控
void start();
void stop();

// 设置皮带映射
void setBeltMapping(int moduleIndex, int beltNumber);

// DI位变化槽函数
void onBitChanged(int moduleIndex, int bitIndex, bool value);
```

## 🔧 修改文件

### 1. src/control/CMakeLists.txt
**修改内容**:
- 添加AudioPathMapper.cpp到CONTROL_SOURCES
- 添加MqttProtectionMonitor.cpp到CONTROL_SOURCES
- 添加AudioPathMapper.h到CONTROL_HEADERS
- 添加MqttProtectionMonitor.h到CONTROL_HEADERS

### 2. src/main/main.cpp
**修改内容**:
- 添加`#include "control/MqttProtectionMonitor.h"`
- 在MQTT_ENABLED块中创建MqttProtectionMonitor实例
- 启动监控器

**新增代码**:
```cpp
#ifdef MQTT_ENABLED
// ✅ 2026-02-27 [Phase 7.47.35]: 创建并启动MQTT保护监控器
MqttProtectionMonitor mqttProtectionMonitor(&diDataManager, &commonControl);
mqttProtectionMonitor.start();
logMessage("MQTT Protection Monitor started");
#endif
```

## 🔄 工作流程

```
MQTT DI模块 → DIDataManager → bitChanged信号 → MqttProtectionMonitor
                                                        ↓
                                                  AudioPathMapper
                                                        ↓
                                                  生成音频路径
                                                        ↓
                                                  CommonControl::playAudio()
                                                        ↓
                                                  播放保护报警音频
```

## 📊 保护名称映射

基于`VoiceFileList.h`中的`SwitchInputVoice::PROTECTION_ITEMS`，共33个保护项：

| 位索引 | 保护名称 |
|--------|----------|
| 0 | 急停保护 |
| 1 | 拉绳保护 |
| 2 | 跑偏保护 |
| 3 | 打滑保护 |
| 4 | 堆煤保护 |
| 5 | 撕裂保护 |
| 6 | 烟雾保护 |
| 7 | 温度保护 |
| ... | ... |

## 🎵 音频文件路径示例

假设当前TTS配置：
- 引擎：paddlespeech
- 模型：fastspeech2_csmsc
- 说话人ID：0
- 皮带编号：1
- 保护：急停保护

生成的音频路径：
```
/app/audio/paddlespeech-fastspeech2_csmsc-spk0/1#PD/急停保护.wav
```

## 🔍 皮带映射配置

默认映射：
- 模块0（开关量输入1）→ 1号皮带
- 模块1（开关量输入2）→ 2号皮带

可通过`setBeltMapping()`方法修改映射关系。

## ✅ 测试方法

### 1. 准备音频文件
确保音频文件存在于正确的路径：
```bash
/app/audio/paddlespeech-fastspeech2_csmsc-spk0/1#PD/急停保护.wav
/app/audio/paddlespeech-fastspeech2_csmsc-spk0/1#PD/拉绳保护.wav
...
```

### 2. 触发MQTT DI输入
通过EMQX Dashboard或MQTT客户端发送消息：
```json
{
  "topic": "belt/di/module1",
  "payload": {
    "data": [1, 0, 0, 0, 0, 0, 0, 0]  // 第0位为1，触发急停保护
  }
}
```

### 3. 观察日志
查看日志输出，确认：
- DIDataManager解析数据成功
- MqttProtectionMonitor检测到位变化
- AudioPathMapper生成正确的音频路径
- CommonControl播放音频

### 4. 验证音频播放
确认扬声器输出保护报警音频。

## 📝 注意事项

1. **音频文件路径**：
   - 基础目录默认为`/app/audio`
   - 路径格式必须与批量生成的音频文件路径一致
   - 如果音频文件不存在，会在日志中输出警告

2. **位变化检测**：
   - 只处理位从0→1的变化（保护触发）
   - 位从1→0的变化（保护恢复）暂不处理

3. **皮带映射**：
   - 默认映射可能需要根据实际现场配置调整
   - 可通过QML或C++代码修改映射关系

4. **TTS配置**：
   - AudioPathMapper自动读取TTSConfigManager的当前配置
   - 确保TTS配置与批量生成音频时的配置一致

## 🚀 后续优化

1. **保护恢复处理**：
   - 添加位从1→0的处理逻辑
   - 播放保护恢复音频或停止报警音频

2. **音频文件检查**：
   - 启动时检查音频文件是否存在
   - 提供音频文件缺失报告

3. **QML界面集成**：
   - 添加保护监控状态显示
   - 提供皮带映射配置界面
   - 显示保护触发历史

4. **多引擎支持**：
   - 支持切换不同的TTS引擎
   - 自动适配不同引擎的音频文件路径

## 📚 参考文档

- [08-音频文件路径映射设计方案.md](./08-音频文件路径映射设计方案.md)
- [VoiceFileList.h](../../src/control/tts/VoiceFileList.h)
- [DIDataManager.h](../../src/mqtt/DIDataManager.h)
- [CommonControl.h](../../src/control/CommonControl.h)

## ✅ 完成标志

- [x] 创建AudioPathMapper类
- [x] 创建MqttProtectionMonitor类
- [x] 更新CMakeLists.txt
- [x] 集成到main.cpp
- [x] 创建实施文档
- [ ] 测试MQTT DI触发音频播放
- [ ] 验证多皮带、多保护类型场景

## 🎉 总结

本次实施完成了MQTT开关量输入触发音频播放的核心功能，实现了从DI位变化检测到音频播放的完整流程。用户现在可以通过MQTT发送开关量数据，系统会自动检测保护触发并播放对应的报警音频。

下一步需要进行实际测试，验证功能是否正常工作，并根据测试结果进行优化和调整。
