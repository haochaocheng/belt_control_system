# 音频网络传输首次测试崩溃 - 使用 av_log() 诊断方案

**日期**: 2026-01-21 21:45 - 21:50
**状态**: 🔧 第三次修复尝试（使用 FFmpeg 原生日志）
**版本**: VERSION 2026-01-21-21:45

---

## 🐛 问题回顾

### 前两次修复尝试失败

**第一次尝试（21:00）**：使用 qDebug()
- **结果**: ❌ 日志未出现（qDebug() 缓冲问题）

**第二次尝试（21:30）**：使用 fprintf(stderr) + fflush()
- **结果**: ❌ 日志依旧未出现
- **编译确认**: pjsip.md Line 558 显示重新编译了 AudioNetworkSender.cpp
- **时间戳**: 编译时间戳未变化（Jan 21 2026 21:18:10）

### 核心矛盾

1. ✅ **pjsip.md Line 558 确认文件被重新编译**
2. ✅ **源码文件确实包含 fprintf() 代码**（已读取验证）
3. ❌ **voip.md 中完全没有 [APP-DEBUG] 日志**
4. ✅ **FFmpeg 内部日志正常显示**（fprintf(stderr) 在 avcodec.c 中工作正常）

**推断**: 可能是 Windows → Docker 文件系统挂载同步延迟，编译时读取的是旧文件内容。

---

## ✅ 第三次修复方案（当前）

### 核心策略

**不再依赖可能没有编译进去的代码，改用已确认工作的 FFmpeg 日志机制：**

```cpp
// ❌ 旧方案（fprintf）- 可能因文件同步延迟未编译进去
fprintf(stderr, "[APP-DEBUG] ...\n");
fflush(stderr);

// ✅ 新方案（av_log）- 使用 FFmpeg 原生日志（已确认工作）
av_log(nullptr, AV_LOG_ERROR, "[APP-TRACE] ...\n");
```

### 修改内容

**文件**: [src/audio_network/AudioNetworkSender.cpp](../../src/audio_network/AudioNetworkSender.cpp) Line 270-327

**关键特征**：
- **VERSION 标记**: `[APP-TRACE] avcodec_open2() 调用前 - VERSION 2026-01-21-21:45`
- **视觉边框**: 使用 `╔═══╗` 边框，易于在日志中识别
- **详细检查点**: 6 个关键检查点，精确定位崩溃

```cpp
// ❌ 2026-01-21 21:45 [紧急修复 v3] 使用 av_log() 确保日志输出
av_log(nullptr, AV_LOG_ERROR, "\n╔═══════════════════════════════════════════════════════════════╗\n");
av_log(nullptr, AV_LOG_ERROR, "║ [APP-TRACE] avcodec_open2() 调用前 - VERSION 2026-01-21-21:45 ║\n");
av_log(nullptr, AV_LOG_ERROR, "╠═══════════════════════════════════════════════════════════════╣\n");
av_log(nullptr, AV_LOG_ERROR, "║   codecCtx 指针: %p                                          ║\n", (void*)codecCtx);
av_log(nullptr, AV_LOG_ERROR, "║   codec 指针: %p                                             ║\n", (void*)codec);
av_log(nullptr, AV_LOG_ERROR, "║   codec->name: %s                                              ║\n", codec->name);
av_log(nullptr, AV_LOG_ERROR, "╚═══════════════════════════════════════════════════════════════╝\n");

int openResult = avcodec_open2(codecCtx, codec, nullptr);

av_log(nullptr, AV_LOG_ERROR, "\n╔═══════════════════════════════════════════════════════════════╗\n");
av_log(nullptr, AV_LOG_ERROR, "║ [APP-TRACE] avcodec_open2() 调用后                            ║\n");
av_log(nullptr, AV_LOG_ERROR, "╠═══════════════════════════════════════════════════════════════╣\n");
av_log(nullptr, AV_LOG_ERROR, "║   返回值: %d                                                  ║\n", openResult);
av_log(nullptr, AV_LOG_ERROR, "╚═══════════════════════════════════════════════════════════════╝\n");

// ... 错误处理 ...

av_log(nullptr, AV_LOG_ERROR, "\n╔═══════════════════════════════════════════════════════════════╗\n");
av_log(nullptr, AV_LOG_ERROR, "║ [APP-TRACE] 准备读取 codecCtx 成员                            ║\n");
av_log(nullptr, AV_LOG_ERROR, "╠═══════════════════════════════════════════════════════════════╣\n");
av_log(nullptr, AV_LOG_ERROR, "║   sizeof(AVCodecContext): %zu bytes                           ║\n", sizeof(AVCodecContext));
av_log(nullptr, AV_LOG_ERROR, "║   codecCtx 指针: %p                                          ║\n", (void*)codecCtx);

if (!codecCtx) {
    av_log(nullptr, AV_LOG_ERROR, "║   ❌ codecCtx is NULL!                                       ║\n");
    av_log(nullptr, AV_LOG_ERROR, "╚═══════════════════════════════════════════════════════════════╝\n");
    throw std::runtime_error("codecCtx is null after avcodec_open2");
}

av_log(nullptr, AV_LOG_ERROR, "║   ✅ codecCtx 指针有效                                        ║\n");
av_log(nullptr, AV_LOG_ERROR, "╠═══════════════════════════════════════════════════════════════╣\n");
av_log(nullptr, AV_LOG_ERROR, "║   尝试读取 sample_rate（offset 可能因版本而异）...           ║\n");
av_log(nullptr, AV_LOG_ERROR, "╚═══════════════════════════════════════════════════════════════╝\n");

// ❌ 2026-01-21 21:45 [安全访问] 使用 av_log 输出，避免崩溃时日志丢失
av_log(nullptr, AV_LOG_ERROR, "\n[APP] 原始音频格式:\n");
av_log(nullptr, AV_LOG_ERROR, "   采样率: %d Hz\n", codecCtx->sample_rate);
av_log(nullptr, AV_LOG_ERROR, "   声道数: %d\n", codecCtx->channels);
av_log(nullptr, AV_LOG_ERROR, "   格式: %s\n", av_get_sample_fmt_name(codecCtx->sample_fmt));
```

---

## 🎯 诊断检查点

修复后的日志将在 voip.md 中显示以下检查点：

| 检查点 | 日志内容 | 含义 |
|--------|---------|------|
| **#0** | `VERSION 2026-01-21-21:45` | **确认编译了新版本**（关键！） |
| **#1** | `[APP-TRACE] avcodec_open2() 调用前` | 进入 avcodec_open2() 前 |
| **#2** | `[APP-TRACE] avcodec_open2() 调用后` | avcodec_open2() 成功返回 |
| **#3** | `[APP-TRACE] 准备读取 codecCtx 成员` | 即将访问 codecCtx 字段 |
| **#4** | `sizeof(AVCodecContext): 944 bytes` | 结构体大小（用于版本诊断） |
| **#5** | `✅ codecCtx 指针有效` | codecCtx 非空 |
| **#6** | `尝试读取 sample_rate...` | 即将访问 codecCtx->sample_rate |
| **#7** | `采样率: 44100 Hz` | sample_rate 读取成功 |
| **#8** | `声道数: 2` | channels 读取成功 |
| **#9** | `格式: fltp` | sample_fmt 读取成功 |

### 崩溃位置判断规则

根据最后出现的检查点，判断崩溃位置：

| 最后显示的检查点 | 崩溃位置 | 可能原因 |
|-----------------|---------|---------|
| **无 VERSION** | 代码未编译进去 | 文件系统同步延迟 |
| **#1 未出现** | 函数入口前 | 不可能（已调用 playAudioToNetwork） |
| **#1 但无 #2** | avcodec_open2() 内部 | FFmpeg 库崩溃 |
| **#2 但无 #3** | 返回值检查时 | openResult 处理错误 |
| **#6 但无 #7** | 访问 sample_rate 时 | **FFmpeg 版本不匹配**（结构体布局错误） ⭐ |
| **#7 但无 #8** | 访问 channels 时 | channels 字段偏移量错误 |
| **#8 但无 #9** | 访问 sample_fmt 时 | sample_fmt 字段偏移量错误 |
| **#9 出现** | 后续代码（重采样器初始化） | 其他问题 |

---

## 🚀 执行步骤

### 用户需要手动执行

```powershell
# 重新编译和部署（确保文件系统同步）
.\build-ubuntu24-apt.ps1 192.168.1.8
```

### 预期结果

#### 情况 A：成功编译新版本（最佳情况）
voip.md 应该显示：
```
[APP-TRACE] avcodec_open2() 调用前 - VERSION 2026-01-21-21:45
```

如果看到这个 VERSION，说明：
- ✅ 新代码成功编译进去
- ✅ 可以根据后续日志精确定位崩溃点

#### 情况 B：依旧没有 VERSION（文件同步问题）
voip.md 依旧只有 FFmpeg 日志，没有 `[APP-TRACE]`

**解决方案**：
1. 手动删除 Docker 镜像缓存
2. 等待 10 秒让文件系统同步
3. 再次编译

#### 情况 C：VERSION 出现但崩溃在 #6-#7 之间
说明：
- ✅ 新代码成功编译
- ❌ **崩溃原因：访问 codecCtx->sample_rate 时段错误**
- 🔍 **根本原因：FFmpeg 版本不匹配，AVCodecContext 结构体布局不同**

**下一步修复**：
1. 检查编译时和运行时 FFmpeg 版本
2. 检查 AVCodecContext 结构体大小（从日志中获取）
3. 可能需要降级或升级 FFmpeg 库

---

## 📚 技术背景

### 为什么使用 av_log()？

**证据**：voip.md Line 1165-1277 显示 FFmpeg 内部日志正常输出

```c
// FFmpeg 源码（avcodec.c）使用 fprintf(stderr)
fprintf(stderr, "╔═══════════════════════════════════════════════════════════════╗\n");
fprintf(stderr, "║ [FFmpeg层] avcodec.c - avcodec_open2() 入口                  ║\n");
```

这些日志在 voip.md 中完整显示，说明：
- ✅ stderr 输出可以到达日志文件
- ✅ FFmpeg 日志机制工作正常

**我的新方案**：使用同样的 FFmpeg 日志机制（av_log），确保输出可见。

### av_log vs fprintf vs qDebug

| 方法 | 优点 | 缺点 | 本次测试结果 |
|------|------|------|------------|
| **qDebug()** | Qt 标准日志 | 有缓冲，崩溃时丢失 | ❌ 日志未出现 |
| **fprintf(stderr)** | 立即输出（with fflush） | 可能因文件同步延迟未编译进去 | ❌ 日志未出现（怀疑） |
| **av_log()** | FFmpeg 原生，已确认工作 | 需要 FFmpeg 日志级别配置 | ✅ 待测试（推荐） |

### FFmpeg 版本不匹配问题

**编译时 FFmpeg**：
- 路径：`cross-compile/src/ffmpeg-rockchip-6.0/`
- 版本：FFmpeg 6.0

**运行时 FFmpeg**：
- 路径：`docker/rk3588/ffmpeg60-libs/lib/libavcodec.so.60`
- 版本：FFmpeg 6.0（应该一致）

**如果版本不一致**：
- AVCodecContext 结构体布局可能不同
- sample_rate 字段偏移量错误
- 访问时读取到垃圾数据或越界 → SIGSEGV

**验证方法**：
- 对比 sizeof(AVCodecContext)
- 检查编译日志中的 FFmpeg 版本
- 检查运行时库版本：`ldd belt_control_system | grep avcodec`

---

## 🔗 相关文档

- **前一版诊断文档**：[16-首次测试崩溃-qDebug缓冲问题诊断修复.md](16-首次测试崩溃-qDebug缓冲问题诊断修复.md)
- **音频网络传输功能实施**：[15-音频网络传输功能完整实施总结.md](15-音频网络传输功能完整实施总结.md)
- **音频网络传输技术决策**：[04-音频网络传输方案技术决策.md](04-音频网络传输方案技术决策.md)

---

**创建时间**: 2026-01-21 21:50
**作者**: Claude AI
**状态**: 🔧 等待用户手动编译测试
**下一步**: 用户执行 `.\build-ubuntu24-apt.ps1 192.168.1.8`，查看 voip.md 是否出现 `VERSION 2026-01-21-21:45`
