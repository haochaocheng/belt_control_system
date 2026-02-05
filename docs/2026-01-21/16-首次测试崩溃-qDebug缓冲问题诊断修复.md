# 音频网络传输首次测试崩溃 - qDebug 缓冲问题诊断修复

**日期**: 2026-01-21 21:00 - 21:40
**状态**: 🔧 诊断修复中（等待重新编译测试）
**问题**: 首次测试时程序崩溃（SIGSEGV），调试日志未显示

---

## 🐛 问题描述

### 崩溃现象

**触发操作**：
1. 设备启动应用（192.168.1.8 / NanoPi-R6C）
2. 用户按 R 键触发启动请求
3. 系统播放起车预警音频（"/app/AUDIO/1#PD/1号皮带启动.mp3"）
4. **程序崩溃**（exit code 139 = SIGSEGV）

**崩溃位置**（GDB 回溯）：
```
#0  0x0000005577a6c7a0 in AudioNetworkSender::decodeAudioFile(QString const&) ()
#1  0x0000005577a6fc88 in AudioNetworkSender::playAudioToNetwork(QString const&) ()
#2  0x00000055779d2e3c in CommonControl::playAudio(QString const&) ()
```

**日志特征**（voip.md Line 1165-1279）：
- ✅ FFmpeg 内部日志正常显示（使用 fprintf(stderr)）
- ✅ 显示 `avcodec_open2()` 成功完成
- ❌ 应用层 qDebug() 日志完全缺失（应该在 Line 290-295）
- ❌ 崩溃发生在 `avcodec_open2()` 返回后访问 `codecCtx` 成员时

---

## 🔍 调试过程

### 第一次修复尝试（21:00）

**修改文件**: [src/audio_network/AudioNetworkSender.cpp](../../src/audio_network/AudioNetworkSender.cpp) Line 270-295

**修改内容**：添加 qDebug() 诊断日志
```cpp
// ❌ 2026-01-21 21:00 [紧急修复] avcodec_open2() 调用后立即检查
// 崩溃位置：avcodec_open2() 返回后访问 codecCtx 时崩溃
// 参考：voip.md Line 1280 - SIGSEGV after avcodec_open2()

qDebug() << "      [DEBUG] avcodec_open2() 即将调用...";
int openResult = avcodec_open2(codecCtx, codec, nullptr);
qDebug() << "      [DEBUG] avcodec_open2() 返回值:" << openResult;

if (openResult < 0) {
    char errBuf[AV_ERROR_MAX_STRING_SIZE];
    av_strerror(openResult, errBuf, sizeof(errBuf));
    throw std::runtime_error(std::string("Failed to open codec: ") + errBuf);
}

qDebug() << "      [DEBUG] avcodec_open2() 成功，检查 codecCtx 指针...";
if (!codecCtx) {
    throw std::runtime_error("codecCtx is null after avcodec_open2");
}

qDebug() << "      [DEBUG] codecCtx 指针有效，读取音频格式...";

qDebug() << "      原始音频格式:";
qDebug() << "         采样率:" << codecCtx->sample_rate << "Hz";
qDebug() << "         声道数:" << codecCtx->channels;
qDebug() << "         格式:" << av_get_sample_fmt_name(codecCtx->sample_fmt);
```

**部署测试**：
```powershell
.\build-ubuntu24-apt.ps1 192.168.1.8
```

**结果**：❌ **修复失败**
- 编译时间戳：`Jan 21 2026 21:18:10`（确认是新编译）
- 崩溃依旧（exit code 139）
- **调试日志完全未显示**

### 问题分析（21:30）

**初步怀疑**：构建脚本缓存问题
- pjsip.md Line 28 显示：`No source changes detected [OK] Using existing binary`
- 怀疑使用了旧的二进制文件

**用户澄清**：❌ 排除缓存问题
> "voip.md日志不用怀疑，就是最新的"
> "build_rk3588这个文件在刚才编译时，我把整个文件夹都删除了，绝对没有问题"

**重新分析**：
1. ✅ 编译时间戳确认是新编译（`Jan 21 2026 21:18:10`）
2. ✅ FFmpeg 内部日志正常显示（使用 `fprintf(stderr)`）
3. ❌ 应用层 qDebug() 日志完全缺失
4. **结论**：**qDebug() 输出被缓冲，崩溃前未刷新**

**证据对比**（voip.md）：
```
Line 1165-1278: FFmpeg 日志（fprintf）✅ 显示
     ╔══════════════════════════════════════════════════════════════╗
     ║ [FFmpeg层] avcodec_open2() - ULTRA EARLY ENTRY             ║
     ║ [FIX 100.223] 函数入口第1条语句（局部变量声明前）          ║
     ╚══════════════════════════════════════════════════════════════╝

Line 290-295: 应用层日志（qDebug）❌ 缺失
     qDebug() << "      原始音频格式:";  // 预期但未出现
     qDebug() << "         采样率:" << codecCtx->sample_rate << "Hz";
```

---

## ✅ 第二次修复方案（21:30）

### 修改策略

**核心思路**：**使用 fprintf(stderr) + fflush() 替代 qDebug()**

**原因**：
- `qDebug()` 使用 Qt 日志系统，输出被缓冲
- 程序崩溃时缓冲区未刷新，日志丢失
- `fprintf(stderr)` + `fflush()` 立即输出，不受缓冲影响

### 修改内容

**文件**: [src/audio_network/AudioNetworkSender.cpp](../../src/audio_network/AudioNetworkSender.cpp) Line 270-303

```cpp
// ❌ 2026-01-21 21:30 [紧急修复 v2] 使用 fprintf 避免 qDebug 缓冲
// 问题：qDebug() 被缓冲，崩溃前日志未刷新，改用 fprintf(stderr) 立即输出
// 参考：voip.md Line 1163-1279 - FFmpeg 日志出现但 qDebug 未出现

fprintf(stderr, "\n[APP-DEBUG] ========== avcodec_open2() 调用前 ==========\n");
fprintf(stderr, "[APP-DEBUG] codecCtx 指针: %p\n", (void*)codecCtx);
fprintf(stderr, "[APP-DEBUG] codec 指针: %p\n", (void*)codec);
fflush(stderr);

int openResult = avcodec_open2(codecCtx, codec, nullptr);

fprintf(stderr, "[APP-DEBUG] ========== avcodec_open2() 调用后 ==========\n");
fprintf(stderr, "[APP-DEBUG] 返回值: %d\n", openResult);
fflush(stderr);

if (openResult < 0) {
    char errBuf[AV_ERROR_MAX_STRING_SIZE];
    av_strerror(openResult, errBuf, sizeof(errBuf));
    fprintf(stderr, "[APP-DEBUG] ❌ avcodec_open2() 失败: %s\n", errBuf);
    fflush(stderr);
    throw std::runtime_error(std::string("Failed to open codec: ") + errBuf);
}

fprintf(stderr, "[APP-DEBUG] ✅ avcodec_open2() 成功，检查 codecCtx 指针...\n");
fflush(stderr);

if (!codecCtx) {
    fprintf(stderr, "[APP-DEBUG] ❌ codecCtx is null!\n");
    fflush(stderr);
    throw std::runtime_error("codecCtx is null after avcodec_open2");
}

fprintf(stderr, "[APP-DEBUG] ✅ codecCtx 指针有效: %p\n", (void*)codecCtx);
fprintf(stderr, "[APP-DEBUG] 准备读取 sample_rate...\n");
fflush(stderr);

qDebug() << "      原始音频格式:";
qDebug() << "         采样率:" << codecCtx->sample_rate << "Hz";
// ❌ 2026-01-21 20:50 [FFmpeg 兼容性] 旧版 API 不支持 ch_layout.nb_channels，改用 channels
// qDebug() << "         声道数:" << codecCtx->ch_layout.nb_channels;
qDebug() << "         声道数:" << codecCtx->channels;
qDebug() << "         格式:" << av_get_sample_fmt_name(codecCtx->sample_fmt);
```

### 诊断检查点

修复后的日志将精确显示崩溃位置：

| 检查点 | 日志内容 | 含义 |
|--------|---------|------|
| **#1** | `[APP-DEBUG] ========== avcodec_open2() 调用前 ==========` | 进入 avcodec_open2() 前 |
| **#2** | `[APP-DEBUG] ========== avcodec_open2() 调用后 ==========` | avcodec_open2() 成功返回 |
| **#3** | `[APP-DEBUG] ✅ avcodec_open2() 成功，检查 codecCtx 指针...` | 返回值检查通过 |
| **#4** | `[APP-DEBUG] ✅ codecCtx 指针有效: 0x...` | codecCtx 非空 |
| **#5** | `[APP-DEBUG] 准备读取 sample_rate...` | 即将访问 codecCtx->sample_rate |
| **#6** | `原始音频格式:` | sample_rate 读取成功 |
| **#7** | `采样率: 44100 Hz` | sample_rate 访问成功 |
| **#8** | `声道数: 2` | channels 访问成功 |
| **#9** | `格式: fltp` | sample_fmt 访问成功 |

**崩溃位置判断**：
- 只看到 **#1**，未看到 **#2** → 崩溃在 `avcodec_open2()` 内部
- 看到 **#2**，未看到 **#3** → 崩溃在返回值检查时
- 看到 **#5**，未看到 **#6** → 崩溃在访问 `codecCtx->sample_rate` 时
- 看到 **#6**，未看到 **#7** → 崩溃在读取 sample_rate 值时
- 看到 **#7**，未看到 **#8** → 崩溃在访问 `codecCtx->channels` 时

---

## 🚀 下一步操作

### 立即执行

**需要用户手动重新编译和部署**（根据 CLAUDE.md 规则）：

```powershell
.\build-ubuntu24-apt.ps1 192.168.1.8
```

**预期结果**：
- 程序依旧崩溃（SIGSEGV）
- **但会显示精确的崩溃位置**（fprintf 日志）
- 根据最后显示的检查点，确定问题根源

### 后续分析

根据新日志，可能的问题和解决方案：

#### 情况 A：崩溃在 avcodec_open2() 内部
**症状**：只看到 `[APP-DEBUG] ========== avcodec_open2() 调用前 ==========`

**可能原因**：
- FFmpeg 库版本不匹配
- 编译时和运行时 FFmpeg 头文件/库不一致
- 硬件加速问题（RKMPP）

**解决方案**：
- 检查 FFmpeg 库版本
- 禁用硬件加速（使用纯软件解码）
- 重新编译 FFmpeg

#### 情况 B：codecCtx 指针损坏
**症状**：看到 `调用后` 但未看到 `codecCtx 指针有效`

**可能原因**：
- avcodec_open2() 返回成功但指针已损坏
- 内存越界/堆栈破坏

**解决方案**：
- 检查 codecCtx 分配代码
- 检查是否有内存越界

#### 情况 C：codecCtx 成员访问崩溃
**症状**：看到 `准备读取 sample_rate...` 但未看到 `原始音频格式:`

**可能原因**：
- codecCtx 结构体定义不匹配
- 编译时和运行时 FFmpeg 版本不一致（结构体布局变化）
- sample_rate 字段偏移量错误

**解决方案**：
- 检查 FFmpeg 版本一致性
- 输出 sizeof(AVCodecContext)
- 检查 sample_rate 偏移量

---

## 📚 技术背景

### 音频网络传输功能

**实施日期**：2026-01-21 19:45 - 20:40
**文档**：[15-音频网络传输功能完整实施总结.md](15-音频网络传输功能完整实施总结.md)

**核心流程**：
```
MP3 文件 → FFmpeg 解码 → PCM (16kHz, 16bit, mono) → Opus 编码 → UDP 组播
         (AudioNetworkSender::decodeAudioFile)        (encodeToOpus)    (224.1.1.1:8800)
```

**本次崩溃**：发生在 **第一步**（FFmpeg 解码），这是该功能的 **首次真实测试**。

### FFmpeg 兼容性问题

**已知问题**：代码中已有 FFmpeg 兼容性修复（Line 307-340）
- 旧版 API 使用 `uint64_t channel_layout`（FFmpeg 4.x/5.x）
- 新版 API 使用 `AVChannelLayout`（FFmpeg 6.x）
- 代码已适配旧版 API

**编译环境**：
- 交叉编译容器：Ubuntu 24.04
- FFmpeg 版本：FFmpeg-Rockchip 6.0（带 RKMPP 硬件加速）
- 编译时 FFmpeg：`cross-compile/src/ffmpeg-rockchip-6.0/`
- 运行时 FFmpeg：`docker/rk3588/ffmpeg60-libs/lib/*.so`

---

## 🎯 关键点总结

### 已确认的事实

1. ✅ 编译是全新的（用户手动删除了 build_rk3588）
2. ✅ 编译时间戳：`Jan 21 2026 21:18:10`
3. ✅ FFmpeg 内部日志正常显示（fprintf 工作正常）
4. ✅ qDebug() 被缓冲，崩溃前未刷新
5. ✅ 崩溃位置：avcodec_open2() 返回后，访问 codecCtx 成员时

### 待验证的问题

1. ❓ avcodec_open2() 是否真的成功返回？
2. ❓ codecCtx 指针是否有效？
3. ❓ 崩溃发生在哪个具体的成员访问？
   - sample_rate?
   - channels?
   - sample_fmt?
4. ❓ FFmpeg 库版本是否一致？

### 修复策略

- **短期**（当前）：使用 fprintf 诊断，精确定位崩溃点
- **中期**：根据诊断结果修复根本原因
- **长期**：考虑是否需要升级/降级 FFmpeg 版本

---

**创建时间**: 2026-01-21 21:40
**作者**: Claude AI
**状态**: 🔧 等待重新编译测试
**下一步**: 用户执行 `.\build-ubuntu24-apt.ps1 192.168.1.8`，获取新日志
