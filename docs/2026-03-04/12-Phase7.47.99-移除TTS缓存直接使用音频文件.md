# Phase 7.47.99 - 移除TTS缓存机制，直接使用预合成音频文件

## 日期
2026-03-04 22:40

## 需求描述
删除 AlarmPlaybackService 中的 TTS 缓存逻辑，保护触发时直接使用预合成的音频文件。

## 背景
早期设计中 AlarmPlaybackService 内置了 TTS 缓存机制：
- 启动时预缓存10个常用报警文本到 `/app/appdata/tts_cache/` 目录
- 播放时先查缓存（MD5哈希匹配），命中则用缓存文件，否则实时合成

现在项目已有完整的批量合成工具（Phase 7.47.3），所有音频文件预先生成在：
`/home/linaro/belt-control-data/audio/paddlespeech-fastspeech2_csmsc-spk0/{皮带号}#PD/`

TTS 缓存机制已冗余，且增加了启动时间（预缓存10个文本）。

## 修改内容

### AlarmPlaybackService.cpp
1. **handleNextPlayback()** - count 和 duration 两种模式的播放逻辑：
   - 旧：`useTextToSpeech ? playTtsText() : playAudioFile()`
   - 新：始终优先 `playAudioFile()`，文件不存在时才回退到实时 TTS
2. **playTtsText()** - 移除缓存查找逻辑：
   - 旧：查缓存 → 命中播放缓存文件 → 未命中实时合成
   - 新：直接实时 TTS 合成（仅作为回退方案）
3. **构造函数** - 注释掉 `initializeTtsCache()` 调用
4. **底部函数** - 注释掉 `initializeTtsCache()`、`getCachedTtsFile()`、`precacheTtsText()` 三个函数

### AlarmPlaybackService.h
- 注释掉缓存函数声明：`initializeTtsCache`、`getCachedTtsFile`、`precacheTtsText`
- 注释掉缓存成员变量：`m_ttsCache`、`m_ttsCacheDir`

## 新的播放流程
```
保护触发 → MqttProtectionMonitor → AlarmPlaybackService::playAlarm()
  → handleNextPlayback()
    → 1. 音频文件存在？→ playAudioFile(audioFile)  ← 主要路径
    → 2. 文件不存在且useTTS？→ playTtsText(ttsText)  ← 回退路径
    → 3. 都不满足？→ playAudioFile() 报错
```

## 修改文件

| 文件 | 修改内容 |
|------|----------|
| src/control/AlarmPlaybackService.cpp | 移除TTS缓存逻辑，优先使用音频文件 |
| src/control/AlarmPlaybackService.h | 注释掉缓存相关声明和成员变量 |
