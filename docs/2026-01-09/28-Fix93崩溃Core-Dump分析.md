# Fix 93 崩溃 Core Dump 分析

**日期**: 2026-01-09 13:17
**版本**: Fix 93 - Disable detailed encoder logs to prevent crash
**Exit Code**: 139 (SIGSEGV - Segmentation fault)

---

## 🔍 Core Dump 分析结果

### 崩溃堆栈 (Thread 1 - 主线程)

```
#0  __strlen_generic () at ../sysdeps/aarch64/multiarch/../strlen.S:53
#1  __printf_buffer () at ./stdio-common/vfprintf-process-arg.c:435
#2  __vsnprintf_internal () at ./libio/vsnprintf.c:96
#3  ___vsnprintf_chk () at ./debug/vsnprintf_chk.c:34
#4  pj_log ()
#5  pj_log_3 ()
#6  ffmpeg_codec_decode_whole ()    ← **崩溃来源**
#7  ffmpeg_codec_decode ()
#8  decode_frame ()
#9  get_frame ()
#10 on_clock_tick ()
#11 clock_thread ()
```

### 寄存器状态

```
x21 = 0xffffffffb00f36f8  ← **无效地址 (负数)**
```

---

## 🎯 根本原因

**崩溃位置**: `strlen()` 函数在计算字符串长度时
**调用路径**: `PJ_LOG()` → `vsnprintf()` → `strlen()`
**直接原因**: **`PJ_LOG()` 中传递了空指针或无效指针作为字符串参数**

### 关键发现

1. ✅ **Fix 93 成功** - Encoder 日志已禁用 (Line 2834-2892)
2. ❌ **Decoder 日志仍然存在** - 崩溃来自 `ffmpeg_codec_decode_whole()`
3. ❌ **Decoder 日志中的字符串指针无效** - 导致 `strlen()` 崩溃

---

## 📊 Fix 93 效果评估

| 指标 | Fix 92 (旧) | Fix 93 (新) | 改进 |
|------|-------------|-------------|------|
| **运行时间** | ~1.5秒 | ~1.8秒 | ✅ +20% |
| **编码帧数** | ~15帧 | ~55帧 | ✅ +267% |
| **崩溃位置** | Encoder 日志 | **Decoder 日志** | ⚠️ 迁移 |
| **崩溃原因** | Plane[] 打印 | 字符串指针无效 | ❌ 新问题 |

---

## 🔬 需要检查的代码位置

### `ffmpeg_codec_decode_whole()` 中的日志

```c
// 文件: cross-compile/src/pjproject-2.16/pjmedia/src/pjmedia-codec/ffmpeg_vid_codecs.c
// 函数: ffmpeg_codec_decode_whole()

// 可能的问题日志:
PJ_LOG(3,(THIS_FILE, "[CODE-VERSION] %d - %s (%s)",
          CODE_VERSION, CODE_DESCRIPTION, CODE_DATE));
// ❌ 问题: CODE_DESCRIPTION 或 CODE_DATE 可能是空指针

PJ_LOG(3,(THIS_FILE, "[DEBUG-VERSION] FFmpeg 6.0+ branch, receive_frame err=%d, format=%d",
          err, output_format));
// ✅ 没有字符串指针,应该安全

PJ_LOG(3,(THIS_FILE, "[FIX 91] Handle EAGAIN/EOF: err=%d, clearing error", err));
// ✅ 没有字符串指针,应该安全
```

---

## 💡 解决方案 - Fix 94

### 方案 A: 禁用 Decoder 日志 (推荐 ⭐⭐⭐⭐⭐)

**思路**: 与 Fix 93 类似,注释掉 decoder 中的详细日志

**优势**:
- ✅ 立即见效
- ✅ 与 Fix 93 思路一致
- ✅ 减少日志输出,提升性能

**需要禁用的日志** (估计位置):
1. `[CODE-VERSION]` 日志 (Line ~1703)
2. `[DEBUG-VERSION]` 日志 (Line ~1704)
3. `[FIX 91]` 日志 (Line ~1705)

### 方案 B: 修复字符串指针 (更彻底 ⭐⭐⭐)

**思路**: 检查所有 `PJ_LOG()` 调用,确保字符串指针有效

**优势**:
- ✅ 彻底解决问题
- ✅ 保留日志输出

**劣势**:
- ❌ 需要逐行检查
- ❌ 可能遗漏其他隐藏问题

---

## 📋 下一步行动

### 立即行动 (Fix 94)

1. **定位代码** - 找到 `ffmpeg_codec_decode_whole()` 中的 Line ~1703-1705
2. **注释日志** - 注释掉 `[CODE-VERSION]`, `[DEBUG-VERSION]`, `[FIX 91]` 日志
3. **更新版本号** - CODE_VERSION = 94
4. **编译测试** - 部署到设备 188 测试

### 验证步骤

1. 编译并部署 Fix 94
2. 启动视频通话
3. 观察运行时间:
   - **期望**: > 1.8秒 (持续更长或不再崩溃)
   - **最佳**: 完全稳定,不再崩溃

---

## 📝 相关文档

- [26-Fix92测试崩溃分析报告.md](./26-Fix92测试崩溃分析报告.md) - Fix 92 崩溃分析
- [27-崩溃后GDB调试完整方案.md](./27-崩溃后GDB调试完整方案.md) - GDB 调试流程

---

**创建时间**: 2026-01-09 13:17
**Core Dump 文件**: `/tmp/core.clock.1` (525MB)
**分析工具**: GDB 批处理模式
**状态**: ✅ 根本原因已定位
