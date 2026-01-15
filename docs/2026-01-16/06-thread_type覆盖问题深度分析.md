# thread_type 覆盖问题深度分析

**日期**: 2026-01-16 12:35
**问题**: PJSIP 设置 thread_type=0，但 FFmpeg 显示 active_thread_type=1
**关键**: 找到 thread_type 被覆盖的位置

---

## 执行摘要 ⭐

### 用户的正确洞察

> **"官方不可能有这样的 BUG，方向错误"**

用户完全正确：
1. ❌ 不应该修改 FFmpeg 源码
2. ❌ FFmpeg 的设计是对的
3. ✅ 问题出在 **PJSIP 的使用方式或时机不对**

### 问题分析

#### PJSIP 设置（Line 739-740）
```c
ctx->thread_count = 0;   // libx264 auto
ctx->thread_type = 0;    // 禁用 FFmpeg 帧级多线程
```

**设置时机**: `open_ffmpeg_codec()` 中，在 `avcodec_alloc_context3()` **之后**

**日志证据**:
```
12:27:30.983   ffmpeg_vid_codecs.c  .......   thread_count=0, thread_type=0
```

✅ PJSIP 确实设置了 `thread_type=0`

#### FFmpeg 实际行为（日志）
```
active_thread_type: 1  ← FF_THREAD_FRAME
```

❌ FFmpeg 还是启用了帧级多线程

---

## 1. thread_type 和 active_thread_type 的区别

### 1.1 定义（AVCodecContext）

```c
typedef struct AVCodecContext {
    // ...

    /**
     * 用户请求的线程类型
     * Set by user before avcodec_open2()
     */
    int thread_type;
#define FF_THREAD_FRAME   1  ///< Frame-level parallelism
#define FF_THREAD_SLICE   2  ///< Slice-level parallelism

    /**
     * FFmpeg 实际激活的线程类型
     * Set by FFmpeg during avcodec_open2()
     */
    int active_thread_type;

    // ...
} AVCodecContext;
```

### 1.2 关键区别

| 字段 | 设置者 | 时机 | 含义 |
|------|--------|------|------|
| `thread_type` | **用户** | avcodec_open2() **之前** | 用户**请求**的线程类型 |
| `active_thread_type` | **FFmpeg** | avcodec_open2() **期间** | FFmpeg **实际激活**的线程类型 |

---

## 2. avcodec_alloc_context3() 的默认值

### 2.1 可能的默认值设置

**假设**: `avcodec_alloc_context3()` 可能设置了 `thread_type` 的默认值

**验证方法**: 检查 FFmpeg 源码 `libavcodec/options.c` 或 `libavcodec/avcodec.c`

### 2.2 检查方法

```bash
# 搜索 thread_type 的默认值定义
grep -r "thread_type.*=" cross-compile/src/ffmpeg-rockchip-6.0/libavcodec/ | grep -v ".o:"
```

---

## 3. 关键问题：为什么 active_thread_type=1？

### 3.1 执行流程

```
PJSIP:
  1. avcodec_alloc_context3(libx264)
     └─ ctx->thread_type = ??? (默认值？)

  2. ctx->thread_type = 0  ← PJSIP 设置

  3. avcodec_open2(ctx, libx264, NULL)
     │
     ├─ ff_encode_preinit()
     │   └─ ff_frame_thread_encoder_init()
     │       ├─ 检查：avctx->thread_type & FF_THREAD_FRAME
     │       ├─ ⚠️ 如果 thread_type=0，应该直接返回
     │       └─ ❌ 但实际执行了，设置 active_thread_type=1
     │
     └─ ...
```

### 3.2 可能的原因

#### 原因 A: thread_type 在 avcodec_open2() 前被覆盖 ⭐

**位置**: 在 PJSIP 设置 `thread_type=0` **之后**，但在 `avcodec_open2()` **之前**

**可疑位置**:
1. `avcodec_alloc_context3()` 内部的延迟初始化
2. FFmpeg 内部的自动检测逻辑
3. AVOptions 的默认值应用

#### 原因 B: thread_type 在 avcodec_open2() 中被覆盖

**位置**: `avcodec_open2()` 内部，在 `ff_frame_thread_encoder_init()` 之前

**可疑位置**:
1. `ff_encode_preinit()` 中的参数调整
2. 编码器特定的默认值应用

#### 原因 C: PJSIP 设置未生效（时机问题）

**可能性**: PJSIP 设置 `thread_type=0` 的时机不对

**检查**: PJSIP 日志显示 `thread_type=0`，说明设置生效了

---

## 4. 验证方案

### 4.1 添加详细日志

**目的**: 追踪 `thread_type` 的变化过程

**修改位置 1**: `ffmpeg_vid_codecs.c` Line 739-740（PJSIP 设置后）

```c
ctx->thread_count = 0;
ctx->thread_type = 0;

PJ_LOG(1, (THIS_FILE, "   🔍 [DEBUG] AFTER PJSIP set:"));
PJ_LOG(1, (THIS_FILE, "      ctx->thread_type = %d", ctx->thread_type));
PJ_LOG(1, (THIS_FILE, "      ctx->active_thread_type = %d", ctx->active_thread_type));
PJ_LOG(1, (THIS_FILE, "      ctx->thread_count = %d", ctx->thread_count));
```

**修改位置 2**: `ffmpeg_vid_codecs.c` Line 2888（avcodec_open2 调用前）

```c
PJ_LOG(1, (THIS_FILE, "   🔍 [DEBUG] BEFORE avcodec_open2:"));
PJ_LOG(1, (THIS_FILE, "      ff->enc_ctx->thread_type = %d", ff->enc_ctx->thread_type));
PJ_LOG(1, (THIS_FILE, "      ff->enc_ctx->active_thread_type = %d", ff->enc_ctx->active_thread_type));
PJ_LOG(1, (THIS_FILE, "      ff->enc_ctx->thread_count = %d", ff->enc_ctx->thread_count));

err = AVCODEC_OPEN(ff->enc_ctx, ff->enc);

PJ_LOG(1, (THIS_FILE, "   🔍 [DEBUG] AFTER avcodec_open2:"));
PJ_LOG(1, (THIS_FILE, "      ff->enc_ctx->thread_type = %d", ff->enc_ctx->thread_type));
PJ_LOG(1, (THIS_FILE, "      ff->enc_ctx->active_thread_type = %d", ff->enc_ctx->active_thread_type));
PJ_LOG(1, (THIS_FILE, "      ff->enc_ctx->thread_count = %d", ff->enc_ctx->thread_count));
```

### 4.2 检查 avcodec_alloc_context3() 的默认值

**方法**: 在 `avcodec_alloc_context3()` 返回后立即打印

**修改位置**: `ffmpeg_vid_codecs.c` Line 2320-2325

```c
ff->enc_ctx = avcodec_alloc_context3(ff->enc);
if (ff->enc_ctx == NULL)
    goto on_error;

PJ_LOG(1, (THIS_FILE, "   🔍 [DEBUG] AFTER avcodec_alloc_context3:"));
PJ_LOG(1, (THIS_FILE, "      ff->enc_ctx->thread_type = %d", ff->enc_ctx->thread_type));
PJ_LOG(1, (THIS_FILE, "      ff->enc_ctx->thread_count = %d", ff->enc_ctx->thread_count));
```

---

## 5. 可能的解决方案

### 方案 A: 在 avcodec_open2() 前再次设置 ⭐

**原理**: 如果 thread_type 在中间被覆盖，在调用 avcodec_open2() 前再次设置

**修改位置**: `ffmpeg_vid_codecs.c` Line 2888（avcodec_open2 调用前）

```c
/* ✅ 2026-01-16 12:40 [FIX 100.215 - 强制 thread_type=0]
 * 问题：thread_type 在某个时间点被覆盖（从 0 变成默认值）
 * 解决：在 avcodec_open2() 前再次强制设置 thread_type=0
 * 原理：确保 FFmpeg 在初始化时读取到正确的 thread_type 值
 */
if (ff->enc && (pj_ansi_strstr(ff->enc->name, "libx264") != NULL ||
                pj_ansi_strstr(ff->enc->name, "x264") != NULL)) {
    PJ_LOG(1, (THIS_FILE, "   ⚠️ [FIX 100.215] Forcing thread_type=0 before avcodec_open2"));
    ff->enc_ctx->thread_type = 0;
    ff->enc_ctx->thread_count = 0;
}

err = AVCODEC_OPEN(ff->enc_ctx, ff->enc);
```

### 方案 B: 使用 AVDictionary 传递参数 ⭐⭐

**原理**: 通过 avcodec_open2() 的第三个参数传递线程选项

**修改位置**: `ffmpeg_vid_codecs.c` Line 2888

```c
/* ✅ 2026-01-16 12:40 [FIX 100.215 - 使用 AVDictionary 传递线程参数]
 * 问题：直接设置 thread_type 可能被 FFmpeg 默认值覆盖
 * 解决：使用 AVDictionary 传递选项，优先级更高
 * 参考：FFmpeg 官方文档推荐的方式
 */
AVDictionary *opts = NULL;
if (ff->enc && (pj_ansi_strstr(ff->enc->name, "libx264") != NULL ||
                pj_ansi_strstr(ff->enc->name, "x264") != NULL)) {
    PJ_LOG(1, (THIS_FILE, "   ⚠️ [FIX 100.215] Using AVDictionary to set thread options"));
    av_dict_set_int(&opts, "threads", 0, 0);          // thread_count=0 (auto)
    av_dict_set_int(&opts, "thread_type", 0, 0);      // thread_type=0 (禁用帧级多线程)
}

err = avcodec_open2(ff->enc_ctx, ff->enc, &opts);

if (opts) {
    av_dict_free(&opts);
}
```

**注意**: 这个方法在 FIX 100.212 中尝试过，导致崩溃。需要检查是否使用了正确的 API。

### 方案 C: 修改 libx264 encoder 的默认选项

**原理**: 修改 libx264.c 的默认参数，禁用帧级多线程

**优势**: ❌ 需要修改 FFmpeg 源码（用户反对）

**不推荐**

---

## 6. 下一步行动

### 优先级 1: 添加详细日志验证 ⭐⭐⭐

**目的**: 确认 thread_type 何时被覆盖

**步骤**:
1. 添加 Section 4.1 的所有日志
2. 重新编译 PJSIP
3. 部署测试
4. 查看日志中 thread_type 的变化过程

### 优先级 2: 尝试方案 A（在 avcodec_open2 前再次设置）⭐⭐

**理由**:
- 简单直接
- 不需要修改 FFmpeg
- 如果 thread_type 被覆盖，这个方法可以恢复

### 优先级 3: 如果方案 A 失败，尝试方案 B（AVDictionary）⭐

**注意**:
- FIX 100.212 使用 av_opt_set_int() 崩溃
- 方案 B 使用 av_dict_set_int()，可能更安全
- 需要确保参数名正确

---

## 7. 用户反馈的启示

### 用户的正确性

1. ✅ **"不要随便修改 FFmpeg 源码"**
   - FFmpeg 是成熟项目，经过千万次测试
   - 我们的用例不是独特的
   - 问题一定在使用方式上

2. ✅ **"官方不可能有这样的 BUG"**
   - FFmpeg 的帧级多线程是设计特性，不是 BUG
   - 正确的做法是禁用帧级多线程，或正确使用 API

3. ✅ **"方向错误"**
   - 不应该强制编码器初始化
   - 应该找到为什么 `thread_type=0` 不生效

### 正确的调查方向

1. ✅ 追踪 `thread_type` 的赋值过程
2. ✅ 找到被覆盖的时间点和位置
3. ✅ 确保 PJSIP 的设置在正确的时机、使用正确的方式

---

**下一步**: 添加详细日志，验证 thread_type 的变化过程
