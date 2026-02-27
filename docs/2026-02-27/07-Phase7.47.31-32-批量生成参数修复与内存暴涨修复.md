# Phase 7.47.31~32 - 批量生成参数修复+滑块修复+内存暴涨修复

> 日期：2026-02-27
> 涉及 Phase：7.47.31、7.47.32

---

## 一、问题清单

| # | 问题 | 根因 | 修复 |
|---|------|------|------|
| 1 | 批量生成两个模型都失败 | TTSConfigManager 的 speakerId/rate/volume 等方法未标记 Q_INVOKABLE，QML 调用返回 undefined | 所有 getter/setter 添加 Q_INVOKABLE |
| 2 | 语速/音量滑块无法拖动 | Qt6 中 Slider handle 需要 implicitWidth/implicitHeight 做命中测试 | handle 添加 implicitWidth: 20, implicitHeight: 20 |
| 3 | 批量生成使用硬编码参数 | speakerId=21, rate=1.0, volume=0.8 写死在代码中 | 从 TTSConfig 读取保存的参数 |
| 4 | DIDataManager 日志重复 624 次 | "缺少data字段" 每次 MQTT 消息都打印 | 改为只打印一次 |
| 5 | PaddleSpeech 内存暴涨 3.9GB | 切换模型时创建新 TTSExecutor 不释放旧的 | 模型没变跳过初始化 + del旧executor + gc.collect() |

---

## 二、修改文件

### Phase 7.47.31

| 文件 | 修改内容 |
|------|---------|
| TTSConfigManager.h | 所有 getter/setter 添加 Q_INVOKABLE（speakerId/setSpeakerId/rate/setRate/volume/setVolume/sampleRate/setSampleRate/loadConfig/saveConfig/modelIndex/setModelIndex/modelPath/setModelPath） |
| TTSConfigSection.qml | rateSlider 和 volumeSlider 的 handle 添加 implicitWidth: 20, implicitHeight: 20 |
| BatchAudioGenerator.h | FileTask 和 EngineConfig 添加 rate/volume 字段 |
| BatchAudioGenerator.cpp | setConfig 解析 rate/volume；executeTask 使用 task.rate/volume 替代硬编码；所有 generate*Tasks 传递 rate/volume |
| BatchSynthesisContent.qml | buildConfig 从 TTSConfig.speakerId/rate/volume 读取参数；outputFolder 动态使用当前 speakerId |
| DIDataManager.cpp | "缺少data字段" 警告改为 static bool 控制只打印一次 |

### Phase 7.47.32

| 文件 | 修改内容 |
|------|---------|
| paddle_tts_service.py | initialize_paddlespeech: 模型没变跳过初始化；切换时 del 旧 executor + gc.collect() |

---

## 三、设备内存状态（修复前）

```
进程                    RSS        占比
PaddleSpeech           3.9GB      48.8%
belt_control_system    479MB       5.9%
sherpa_tts_service     288MB       3.5%
容器总计               4.2GB      54.8%
```

---

## 四、Git 提交

- `efd63c5e` - fix: Phase 7.47.31 - 批量生成使用语音管理界面参数+修复滑块无法拖动
- `36be4fd6` - fix: Phase 7.47.31 - 修复TTSConfigManager Q_INVOKABLE缺失+DIDataManager日志抑制
- `55da193c` - fix: Phase 7.47.32 - 修复PaddleSpeech切换模型内存暴涨(3.9GB)
