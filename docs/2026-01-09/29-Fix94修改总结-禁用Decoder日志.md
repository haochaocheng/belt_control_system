# Fix 94: 禁用 Decoder 详细日志防止崩溃

**日期**: 2026-01-09 13:25
**版本**: CODE_VERSION 94
**修改文件**: `cross-compile/src/pjproject-2.16/pjmedia/src/pjmedia-codec/ffmpeg_vid_codecs.c`

---

## 📋 修改概述

基于 Fix 93 Core Dump 分析结果,实施 Fix 94:
- **目标**: 禁用 **Decoder** 中的所有详细日志
- **原因**: Core Dump 显示崩溃在 `ffmpeg_codec_decode_whole()` 函数的日志打印时
- **策略**: 与 Fix 93 一致,注释掉可能导致崩溃的日志

---

## 🔍 根本原因分析

### Core Dump 证据

```
#0  __strlen_generic()           ← strlen() 崩溃
#1  __printf_buffer()             ← printf 处理
#2  __vsnprintf_internal()        ← vsnprintf
#3  ___vsnprintf_chk()            ← 安全检查
#4  pj_log()                      ← PJSIP 日志
#5  pj_log_3()                    ← PJSIP 日志
#6  ffmpeg_codec_decode_whole()  ← **Decoder 函数 (崩溃来源)**
```

### 寄存器状态

```
x21 = 0xffffffffb00f36f8  ← 无效地址 (负数)
```

### 结论

**PJ_LOG() 传递了无效字符串指针** → `strlen()` 崩溃

---

## 🛠️ 修改内容

### 1. 更新版本号 (Line 48-51)

```c
/* ✅ 2026-01-09 13:25 [修复 94] 版本号更新 */
#define CODE_VERSION 94
#define CODE_DATE "2026-01-09 13:25"
#define CODE_DESCRIPTION "Fix 94: Disable detailed decoder logs to prevent crash"
```

### 2. 注释 [CODE-VERSION] 日志 (Line 3311-3326)

**位置**: `ffmpeg_codec_decode_whole()` 函数入口

**原代码**:
```c
static pj_bool_t version_printed = PJ_FALSE;
if (!version_printed) {
    PJ_LOG(3,(THIS_FILE, "🔍 [CODE-VERSION] %d - %s (%s)",
              CODE_VERSION, CODE_DESCRIPTION, CODE_DATE));
    version_printed = PJ_TRUE;
}
```

**修改后**:
```c
/* ✅ 2026-01-09 13:25 [修复 94] 注释掉 decoder 版本日志
 * 原因：Core Dump 显示崩溃在 decoder 日志打印时 (__strlen_generic)
 * 堆栈：__strlen → __printf_buffer → pj_log() → ffmpeg_codec_decode_whole()
 * 寄存器 x21 = 0xffffffffb00f36f8 (无效地址)
 * 策略：禁用所有 decoder 详细日志,减少崩溃风险
 * 详细：docs/2026-01-09/28-Fix93崩溃Core-Dump分析.md
 */
/*
static pj_bool_t version_printed = PJ_FALSE;
if (!version_printed) {
    PJ_LOG(3,(THIS_FILE, "🔍 [CODE-VERSION] %d - %s (%s)",
              CODE_VERSION, CODE_DESCRIPTION, CODE_DATE));
    version_printed = PJ_TRUE;
}
*/
```

### 3. 注释 [DEBUG-VERSION] 日志 (Line 3385-3389)

**位置**: FFmpeg 6.0+ 分支,`avcodec_receive_frame()` 之后

**原代码**:
```c
PJ_LOG(3,(THIS_FILE, "🔍 [DEBUG-VERSION] FFmpeg 6.0+ branch, receive_frame err=%d, format=%d",
          err, avframe.format));
```

**修改后**:
```c
/* ✅ 2026-01-09 13:25 [修复 94] 注释掉 DEBUG-VERSION 日志（已禁用）*/
/*
PJ_LOG(3,(THIS_FILE, "🔍 [DEBUG-VERSION] FFmpeg 6.0+ branch, receive_frame err=%d, format=%d",
          err, avframe.format));
*/
```

### 4. 注释 [FIX 91] EAGAIN 日志 (Line 3482-3483)

**位置**: EAGAIN 错误处理分支

**原代码**:
```c
} else if (err == AVERROR(EAGAIN) || err == AVERROR_EOF) {
    PJ_LOG(3,(THIS_FILE, "🔍 [FIX 91] Handle EAGAIN/EOF: err=%d, clearing error", err));
    err = 0;
    got_picture = PJ_FALSE;
}
```

**修改后**:
```c
} else if (err == AVERROR(EAGAIN) || err == AVERROR_EOF) {
    /* ✅ 2026-01-09 13:25 [修复 94] 注释掉 FIX 91 日志（已禁用）*/
    // PJ_LOG(3,(THIS_FILE, "🔍 [FIX 91] Handle EAGAIN/EOF: err=%d, clearing error", err));
    err = 0;
    got_picture = PJ_FALSE;
}
```

### 5. 注释所有 `av_get_pix_fmt_name()` 日志

**风险点**: `av_get_pix_fmt_name()` 可能返回 NULL,且被调用两次

#### 5.1 [FIX 90] 转换成功日志 (Line 3426-3431)

```c
/* ✅ 2026-01-09 13:25 [修复 94] 注释掉使用 av_get_pix_fmt_name() 的日志（已禁用）*/
/*
PJ_LOG(3,(THIS_FILE, "✅ [FIX 90] DRM_PRIME → %s conversion SUCCESS",
          av_get_pix_fmt_name(sw_frame->format) ?
          av_get_pix_fmt_name(sw_frame->format) : "unknown"));
*/
```

#### 5.2 FFmpeg 6.0+ 分支 Corrected 日志 (Line 3467-3473)

```c
/* ✅ 2026-01-09 13:25 [修复 94] 注释掉使用 av_get_pix_fmt_name() 的日志（已禁用）*/
/*
PJ_LOG(3,(THIS_FILE, "   Corrected: err=0, got_picture=TRUE, format=%d (%s)",
          avframe.format,
          av_get_pix_fmt_name(avframe.format) ?
          av_get_pix_fmt_name(avframe.format) : "unknown"));
*/
```

#### 5.3 [FIX 89] 转换成功日志 (Line 3533-3538)

```c
/* ✅ 2026-01-09 13:25 [修复 94] 注释掉使用 av_get_pix_fmt_name() 的日志（已禁用）*/
/*
PJ_LOG(3,(THIS_FILE, "✅ [FIX 89] DRM_PRIME → %s conversion SUCCESS",
          av_get_pix_fmt_name(sw_frame->format) ?
          av_get_pix_fmt_name(sw_frame->format) : "unknown"));
*/
```

#### 5.4 FFmpeg 52.72+ 分支 Corrected 日志 (Line 3564-3570)

```c
/* ✅ 2026-01-09 13:25 [修复 94] 注释掉使用 av_get_pix_fmt_name() 的日志（已禁用）*/
/*
PJ_LOG(3,(THIS_FILE, "   Corrected: err=0, got_picture=TRUE, format=%d (%s)",
          avframe.format,
          av_get_pix_fmt_name(avframe.format) ?
          av_get_pix_fmt_name(avframe.format) : "unknown"));
*/
```

#### 5.5 [FIX 86] 转换成功日志 (Line 3684-3690)

```c
/* ✅ 2026-01-09 13:25 [修复 94] 注释掉使用 av_get_pix_fmt_name() 的日志（已禁用）*/
/*
PJ_LOG(3,(THIS_FILE, "✅ [FIX 86] Converted to format: %d (%s)",
          avframe.format,
          av_get_pix_fmt_name(avframe.format) ? av_get_pix_fmt_name(avframe.format) : "unknown"));
PJ_LOG(3,(THIS_FILE, "   Frame dimensions: %dx%d", avframe.width, avframe.height));
*/
```

---

## 📊 修改统计

| 修改类型 | 数量 | 行号范围 |
|---------|------|---------|
| **版本号更新** | 1 | Line 48-51 |
| **注释 VERSION 日志** | 1 | Line 3311-3326 |
| **注释 DEBUG 日志** | 1 | Line 3385-3389 |
| **注释 EAGAIN 日志** | 1 | Line 3482-3483 |
| **注释 pix_fmt_name 日志** | 5 | Line 3426-3690 |
| **总计** | **9 处修改** | |

---

## 🎯 预期效果

### 与 Fix 93 对比

| 指标 | Fix 92 | Fix 93 | Fix 94 (预期) |
|------|--------|--------|--------------|
| **Encoder 日志** | ✅ 启用 | ❌ 禁用 | ❌ 禁用 |
| **Decoder 日志** | ✅ 启用 | ✅ 启用 | ❌ **禁用** |
| **运行时间** | ~1.5秒 | ~1.8秒 | **> 2秒 或不再崩溃** |
| **编码帧数** | ~15帧 | ~55帧 | **> 60帧 或稳定运行** |
| **崩溃位置** | Encoder | Decoder | **无崩溃 (目标)** |

### 三种可能结果

1. **✅ 最佳结果**: 不再崩溃,视频通话稳定运行
   - **说明**: 日志打印导致的崩溃问题已完全解决
   - **下一步**: 验证硬件解码功能,开始性能优化

2. **⚠️ 中间结果**: 运行时间延长 (> 2秒),但仍然崩溃
   - **说明**: 日志不是唯一问题,还有其他根本原因
   - **下一步**: 使用 Core Dump 分析新的崩溃堆栈

3. **❌ 最差结果**: 立即崩溃 (< 1秒)
   - **说明**: 问题不在日志,而在核心解码逻辑
   - **下一步**: 回滚到 Fix 91,重新分析根本原因

---

## 📝 验证清单

### 编译前验证

- [x] 版本号已更新: CODE_VERSION 94
- [x] Encoder 日志已禁用 (Fix 93)
- [x] Decoder 日志已禁用 (Fix 94)
- [x] Fix 91 EAGAIN 处理逻辑保留 (只注释日志)
- [x] Fix 92 内存管理代码保留 (av_frame_move_ref)

### 编译部署

```powershell
# 完整编译和部署
.\build-ubuntu24-apt.ps1 188
```

### 测试步骤

1. **启动程序**
2. **建立视频通话**
3. **观察运行时间**:
   - < 1秒: ❌ 问题恶化
   - 1-2秒: ⚠️ 小幅改善
   - > 2秒: ✅ 显著改善
   - 不崩溃: ✅✅✅ 完全解决!
4. **如果崩溃**: 执行 `07-analyze-core-dump.ps1 188`

### Core Dump 准备

```powershell
# 已在容器中设置 Core Dump (2026-01-09 13:17)
# 如果需要重新设置:
.\scripts\2026-01-09\06-setup-core-dump.ps1 188
```

---

## 🔗 相关文档

- [28-Fix93崩溃Core-Dump分析.md](./28-Fix93崩溃Core-Dump分析.md) - Core Dump 分析报告
- [26-Fix92测试崩溃分析报告.md](./26-Fix92测试崩溃分析报告.md) - Fix 92 崩溃分析
- [27-崩溃后GDB调试完整方案.md](./27-崩溃后GDB调试完整方案.md) - GDB 调试流程

---

**创建时间**: 2026-01-09 13:25
**修改文件**: 1 个 (`ffmpeg_vid_codecs.c`)
**修改行数**: 9 处
**状态**: ✅ 代码修改完成,待编译测试
