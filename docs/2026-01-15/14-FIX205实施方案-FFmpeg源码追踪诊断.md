# FIX 100.205 实施方案 - FFmpeg 源码追踪诊断

**时间**: 2026-01-15 23:45（北京时间）
**目标**: 在 FFmpeg 源码中添加详细日志，追踪 `avcodec_open2()` 完整流程，确定 `X264_init()` 是否被调用
**原则**: 只添加诊断日志，不修改功能逻辑
**状态**: ✅ 代码已添加，增量编译完成，等待部署测试

---

## 背景

### FIX 100.204 的最终发现

**100% 确认**：
- PJSIP 调用 FFmpeg 的方式完全正确 ✅
- 编码器指针完全匹配（0x7fa6b6f770）✅
- 所有参数完全有效（width=640, height=480, bit_rate=800000）✅
- **问题确认在 FFmpeg `avcodec_open2()` 内部逻辑** ❌

**核心问题**：
- `avcodec_open2(enc_ctx, libx264)` 返回成功（err=0）
- 但**没有初始化** `enc_ctx->priv_data` (X264Context)
- 导致 `x4->enc = NULL` → 编码失败 (EINVAL)

**关键疑问**：
- ❓ `X264_init()` 是否被调用？
- ❓ 如果被调用，为什么 `x4->enc` 是 NULL？
- ❓ 如果未被调用，为什么 FFmpeg 会跳过初始化？

---

## FIX 100.205 诊断策略

### 完整诊断点列表

| 诊断点 | 位置 | 文件 | 时机 | 目的 |
|-------|------|------|------|------|
| **DIAG-A** | Line 134-146 | avcodec.c | `avcodec_open2()` 入口 | 记录函数入口参数 |
| **DIAG-B** | Line 211-219 | avcodec.c | `priv_data` 分配后 | 确认 priv_data 分配成功 |
| **DIAG-C** | Line 361-367 | avcodec.c | 调用 `codec->init` 前 | 准备调用初始化函数 |
| **DIAG-D** | Line 373-380 | avcodec.c | `codec->init` 返回后 | 记录初始化函数返回值 |
| **WARNING** | Line 387-392 | avcodec.c | `codec->init` 是 NULL | 检测编码器无 init 函数 |
| **DIAG-E** | Line 399-406 | avcodec.c | `avcodec_open2()` 退出 | 记录最终返回值和状态 |
| **DIAG-F** | Line 1163-1173 | libx264.c | `X264_init()` 入口 | 确认 X264_init 被调用 |
| **SUCCESS/ERROR** | Line 1542-1554 | libx264.c | `x264_encoder_open()` 后 | 记录编码器打开结果 |

**诊断流程**：
```
DIAG-A (入口)
    ↓
DIAG-B (分配 priv_data)
    ↓
DIAG-C (准备调用 init) ──→ WARNING (init 是 NULL？)
    ↓
DIAG-F (X264_init 入口)
    ↓
SUCCESS/ERROR (x264_encoder_open 结果)
    ↓
DIAG-D (init 返回)
    ↓
DIAG-E (退出)
```

---

## 修改内容

### 修改 1：avcodec.c - DIAG-A 入口日志（Line 134-146）

**文件**：`cross-compile/src/ffmpeg-rockchip-6.0/libavcodec/avcodec.c`

**位置**：`avcodec_open2()` 函数开头

```c
int attribute_align_arg avcodec_open2(AVCodecContext *avctx, const AVCodec *codec, AVDictionary **options)
{
    int ret = 0;
    AVCodecInternal *avci;
    const FFCodec *codec2;

    /* ✅ 2026-01-15 23:15 [FIX 100.205 DIAG-A] 记录 avcodec_open2() 入口 */
    fprintf(stderr, "\n========================================\n");
    fprintf(stderr, "[FIX 100.205 DIAG-A] avcodec_open2() ENTRY\n");
    fprintf(stderr, "========================================\n");
    fprintf(stderr, "  AVCodecContext: %p\n", (void*)avctx);
    fprintf(stderr, "  codec: %p\n", (void*)codec);
    if (codec) {
        fprintf(stderr, "  codec->name: %s\n", codec->name);
        fprintf(stderr, "  codec->id: %d\n", codec->id);
    }
    fprintf(stderr, "  avctx->priv_data: %p\n", (void*)avctx->priv_data);
    fprintf(stderr, "========================================\n\n");
    fflush(stderr);

    if (avcodec_is_open(avctx))
        return 0;

    // ... 原有代码继续 ...
}
```

**输出示例**：
```
========================================
[FIX 100.205 DIAG-A] avcodec_open2() ENTRY
========================================
  AVCodecContext: 0x7efc015280
  codec: 0x7fa6b6f770
  codec->name: libx264
  codec->id: 27
  avctx->priv_data: 0x7efc015640
========================================
```

---

### 修改 2：avcodec.c - DIAG-B priv_data 分配（Line 211-219）

**位置**：`priv_data` 分配后

```c
    } else {
        avctx->priv_data = NULL;
    }

    /* ✅ 2026-01-15 23:20 [FIX 100.205 DIAG-B] 记录 priv_data 分配 */
    fprintf(stderr, "\n[FIX 100.205 DIAG-B] priv_data allocated\n");
    fprintf(stderr, "  avctx->priv_data: %p\n", (void*)avctx->priv_data);
    if (codec2->priv_data_size > 0) {
        fprintf(stderr, "  size: %d bytes\n", codec2->priv_data_size);
    } else {
        fprintf(stderr, "  size: 0 (no priv_data needed)\n");
    }
    fflush(stderr);

    if ((ret = av_opt_set_dict(avctx, options)) < 0)
        goto free_and_end;
```

**输出示例**：
```
[FIX 100.205 DIAG-B] priv_data allocated
  avctx->priv_data: 0x7efc015640
  size: 288 bytes
```

---

### 修改 3：avcodec.c - DIAG-C/D init 调用（Line 360-393）

**位置**：`codec->init` 调用前后

```c
    if (!(avctx->active_thread_type & FF_THREAD_FRAME) ||
        avci->frame_thread_encoder) {
        if (codec2->init) {
            /* ✅ 2026-01-15 23:25 [FIX 100.205 DIAG-C] 准备调用 codec->init */
            fprintf(stderr, "\n[FIX 100.205 DIAG-C] About to call codec->init()\n");
            fprintf(stderr, "  codec->name: %s\n", codec->name);
            fprintf(stderr, "  codec2->init: %p\n", (void*)codec2->init);
            fprintf(stderr, "  avctx: %p\n", (void*)avctx);
            fprintf(stderr, "  avctx->priv_data: %p\n", (void*)avctx->priv_data);
            fflush(stderr);

            lock_avcodec(codec2);
            ret = codec2->init(avctx);
            unlock_avcodec(codec2);

            /* ✅ 2026-01-15 23:30 [FIX 100.205 DIAG-D] codec->init 返回 */
            fprintf(stderr, "\n[FIX 100.205 DIAG-D] codec->init() returned: %d\n", ret);
            if (ret < 0) {
                fprintf(stderr, "  ❌ ERROR: codec->init() failed!\n");
            } else {
                fprintf(stderr, "  ✅ SUCCESS: codec->init() succeeded\n");
            }
            fflush(stderr);

            if (ret < 0) {
                avci->needs_close = codec2->caps_internal & FF_CODEC_CAP_INIT_CLEANUP;
                goto free_and_end;
            }
        } else {
            /* ✅ 2026-01-15 23:35 [FIX 100.205 WARNING] codec->init 是 NULL */
            fprintf(stderr, "\n[FIX 100.205 WARNING] codec->init is NULL!\n");
            fprintf(stderr, "  codec->name: %s\n", codec->name);
            fprintf(stderr, "  This means the codec has no init function\n");
            fprintf(stderr, "  priv_data will NOT be initialized\n");
            fflush(stderr);
        }
        avci->needs_close = 1;
    }
```

**输出示例（成功场景）**：
```
[FIX 100.205 DIAG-C] About to call codec->init()
  codec->name: libx264
  codec2->init: 0x7fa6c12340
  avctx: 0x7efc015280
  avctx->priv_data: 0x7efc015640

[FIX 100.205 DIAG-D] codec->init() returned: 0
  ✅ SUCCESS: codec->init() succeeded
```

**输出示例（失败场景）**：
```
[FIX 100.205 WARNING] codec->init is NULL!
  codec->name: libx264
  This means the codec has no init function
  priv_data will NOT be initialized
```

---

### 修改 4：avcodec.c - DIAG-E 退出日志（Line 399-406）

**位置**：`avcodec_open2()` 返回前

```c
        avci->needs_close = 1;
    }

    ret=0;

    /* ✅ 2026-01-15 23:40 [FIX 100.205 DIAG-E] avcodec_open2() 退出 */
    fprintf(stderr, "\n========================================\n");
    fprintf(stderr, "[FIX 100.205 DIAG-E] avcodec_open2() EXIT\n");
    fprintf(stderr, "========================================\n");
    fprintf(stderr, "  Return value: %d\n", ret);
    fprintf(stderr, "  avctx->priv_data: %p\n", (void*)avctx->priv_data);
    fprintf(stderr, "========================================\n\n");
    fflush(stderr);

    if (av_codec_is_decoder(avctx->codec)) {
        // ... 后续代码 ...
    }
```

**输出示例**：
```
========================================
[FIX 100.205 DIAG-E] avcodec_open2() EXIT
========================================
  Return value: 0
  avctx->priv_data: 0x7efc015640
========================================
```

---

### 修改 5：libx264.c - DIAG-F 入口日志（Line 1163-1173）

**文件**：`cross-compile/src/ffmpeg-rockchip-6.0/libavcodec/libx264.c`

**位置**：`X264_init()` 函数开头

```c
static av_cold int X264_init(AVCodecContext *avctx)
{
    X264Context *x4 = avctx->priv_data;
    AVCPBProperties *cpb_props;
    int sw,sh;
    int ret;
    int delayed_frames;  /* ✅ 2026-01-15 01:55 [FIX 100.198] 移到函数开头声明（C90兼容）*/
    int all_zeroed;      /* ✅ 2026-01-15 01:55 [FIX 100.198] 移到函数开头声明（C90兼容）*/
    int i;               /* ✅ 2026-01-15 01:55 [FIX 100.198] for循环变量声明（C90兼容）*/

    /* ✅ 2026-01-15 23:45 [FIX 100.205 DIAG-F] X264_init 被调用 */
    fprintf(stderr, "\n========================================\n");
    fprintf(stderr, "[FIX 100.205 DIAG-F] X264_init() CALLED\n");
    fprintf(stderr, "========================================\n");
    fprintf(stderr, "  AVCodecContext: %p\n", (void*)avctx);
    fprintf(stderr, "  X264Context (priv_data): %p\n", (void*)x4);
    fprintf(stderr, "  width: %d, height: %d\n", avctx->width, avctx->height);
    fprintf(stderr, "  pix_fmt: %d\n", avctx->pix_fmt);
    fprintf(stderr, "  bit_rate: %lld\n", (long long)avctx->bit_rate);
    fprintf(stderr, "========================================\n\n");
    fflush(stderr);

    if (avctx->global_quality > 0)
        av_log(avctx, AV_LOG_WARNING, "-qscale is ignored, -crf is recommended.\n");

    // ... 原有初始化代码继续 ...
}
```

**输出示例**：
```
========================================
[FIX 100.205 DIAG-F] X264_init() CALLED
========================================
  AVCodecContext: 0x7efc015280
  X264Context (priv_data): 0x7efc015640
  width: 640, height: 480
  pix_fmt: 0
  bit_rate: 800000
========================================
```

---

### 修改 6：libx264.c - SUCCESS/ERROR 日志（Line 1542-1554）

**位置**：`x264_encoder_open()` 调用后

```c
    x4->params.b_annexb = 1;
    x4->params.b_repeat_headers = 1;
    av_log(avctx, AV_LOG_WARNING,
           "[FIX 68] Force Annex B format: b_annexb=1, b_repeat_headers=1 (override all settings)\n");

    x4->enc = x264_encoder_open(&x4->params);

    /* ✅ 2026-01-15 23:50 [FIX 100.205 SUCCESS/ERROR] 记录 x264_encoder_open 结果 */
    if (!x4->enc) {
        fprintf(stderr, "\n[FIX 100.205 ERROR] x264_encoder_open() failed!\n");
        fprintf(stderr, "  x4->enc: (nil)\n");
        fprintf(stderr, "  This will cause encoding to fail with EINVAL\n\n");
        fflush(stderr);
        return AVERROR_EXTERNAL;
    }

    fprintf(stderr, "\n[FIX 100.205 SUCCESS] x264_encoder_open() succeeded\n");
    fprintf(stderr, "  x4->enc: %p\n", (void*)x4->enc);
    fprintf(stderr, "  X264_init() completed successfully\n\n");
    fflush(stderr);

    if (avctx->flags & AV_CODEC_FLAG_GLOBAL_HEADER) {
        // ... 后续代码 ...
    }
```

**输出示例（成功）**：
```
[FIX 100.205 SUCCESS] x264_encoder_open() succeeded
  x4->enc: 0x7efc680000
  X264_init() completed successfully
```

**输出示例（失败）**：
```
[FIX 100.205 ERROR] x264_encoder_open() failed!
  x4->enc: (nil)
  This will cause encoding to fail with EINVAL
```

---

## 编译和部署

### 方法 1：增量编译 FFmpeg（推荐，2-5 分钟）

```powershell
# 用户已执行完成
.\scripts\2026-01-15\incremental-compile-libx264-new.ps1
```

**输出**：
- ✅ `docker/rk3588/ffmpeg60-libs/opt/ffmpeg-rockchip/lib/libavcodec.so.60.31.102` (12.2 MB, 10:27:46)

### 方法 2：完整构建部署

```powershell
# 正在执行中
.\build-ubuntu24-apt.ps1 188
```

**预计耗时**：15-20 分钟（检测到 FFmpeg 库更新，强制重新链接应用）

---

## 预期测试结果分析

### 场景 A：X264_init() 被调用且成功（70% 概率）⭐

**日志序列**：
```
[DIAG-A] avcodec_open2() ENTRY (avctx: 0x..., codec: libx264)
[DIAG-B] priv_data allocated (0x..., 288 bytes)
[DIAG-C] About to call codec->init() (libx264)
[DIAG-F] X264_init() CALLED ✅
[SUCCESS] x264_encoder_open() succeeded (x4->enc: 0x...) ✅
[DIAG-D] codec->init() returned: 0 ✅
[DIAG-E] avcodec_open2() EXIT (ret: 0)

[编码时 - FIX 100.202]
[FIX 100.202] X264Context initialized! ✅
  x4->enc: 0x... (valid) ✅
  reordered_opaque: 0x... (valid) ✅
```

**结论**：
- ✅ X264_init() 被调用且成功
- ✅ x4->enc 有效
- ✅ 编码应该成功！

**问题**：
- ❓ 为什么之前测试时 `x4->enc` 是 NULL？
- 可能原因：
  1. PJSIP 使用了错误的 AVCodecContext 实例（不是 FFmpeg 初始化的那个）
  2. FFmpeg 在某些情况下会创建多个实例，PJSIP 使用了未初始化的那个
  3. 内存已被破坏或覆盖

**下一步**：
- 对比 DIAG-F 中的 `avctx` 和 FIX 100.204 中的 `ff->enc_ctx`
- 验证它们是否是同一个指针

---

### 场景 B：X264_init() 未被调用（25% 概率）

**日志序列**：
```
[DIAG-A] avcodec_open2() ENTRY (avctx: 0x..., codec: libx264)
[DIAG-B] priv_data allocated (0x..., 288 bytes)
[DIAG-C] About to call codec->init() (libx264)
[DIAG-D] codec->init() returned: 0 ✅ (但没有 DIAG-F！) ❌
[DIAG-E] avcodec_open2() EXIT (ret: 0)
```

**或**：
```
[DIAG-A] avcodec_open2() ENTRY
[DIAG-B] priv_data allocated
[WARNING] codec->init is NULL! ❌
[DIAG-E] avcodec_open2() EXIT (ret: 0)
```

**结论**：
- ❌ X264_init() 未被调用
- ❌ priv_data 未初始化
- ❌ x4->enc 仍然是 NULL

**原因猜测**：
1. **FFmpeg 版本特定 Bug**：
   - FFmpeg 6.0 在某些条件下不调用 codec->init
   - 需要检查 FFmpeg 官方 Issue Tracker

2. **FFmpeg 内部条件判断**：
   - `!(avctx->active_thread_type & FF_THREAD_FRAME)` 条件不满足
   - 导致跳过了 `codec->init` 调用

3. **codec->init 指针是 NULL**：
   - libx264 编码器注册时 init 函数未设置（极不可能）

**下一步**：
- 添加更多日志追踪 `avctx->active_thread_type` 和 `avci->frame_thread_encoder`
- 检查 FFmpeg 官方 Bug 报告
- 考虑降级到 FFmpeg 5.1 或升级到 FFmpeg 7.0

---

### 场景 C：X264_init() 被调用但失败（5% 概率）

**日志序列**：
```
[DIAG-A] avcodec_open2() ENTRY
[DIAG-B] priv_data allocated
[DIAG-C] About to call codec->init()
[DIAG-F] X264_init() CALLED ✅
[ERROR] x264_encoder_open() failed! ❌
  x4->enc: (nil)
[DIAG-D] codec->init() returned: -542398533 (AVERROR_EXTERNAL) ❌
[DIAG-E] avcodec_open2() EXIT (ret: -542398533)
```

**结论**：
- ✅ X264_init() 被调用
- ❌ x264_encoder_open() 失败
- ❌ avcodec_open2() 应该返回错误（不是 0）

**问题**：
- ❓ 为什么 PJSIP 的 FIX 100.204 显示 `err=0`？
- 可能原因：PJSIP 错误处理有问题

**下一步**：
- 检查 x264_encoder_open() 失败的原因
- 检查 x264 参数设置是否正确

---

## 关键对比分析

### 对比点 1：AVCodecContext 指针

**PJSIP FIX 100.204**：
```
ff->enc_ctx: 0x7efc015280
ff->enc_ctx->priv_data: 0x7efc015640
```

**FFmpeg DIAG-A**：
```
AVCodecContext: 0x???????
priv_data: 0x???????
```

**如果匹配**：
- ✅ PJSIP 和 FFmpeg 使用同一个 AVCodecContext
- ✅ 证明 FFmpeg 确实在这个实例上调用（或未调用）X264_init()

**如果不匹配**：
- ❌ FFmpeg 创建了新的 AVCodecContext
- ❌ PJSIP 使用的是旧的、未初始化的实例
- ✅ 这解释了为什么 x4->enc 是 NULL

---

### 对比点 2：时间序列

**预期完整日志序列**：
```
03:41:51.403  [PJSIP] Before avcodec_open2() (FIX 100.204 DIAG-D)
03:41:51.403  [FFmpeg] DIAG-A: avcodec_open2() ENTRY
03:41:51.403  [FFmpeg] DIAG-B: priv_data allocated
03:41:51.403  [FFmpeg] DIAG-C: About to call codec->init()
03:41:51.403  [FFmpeg] DIAG-F: X264_init() CALLED
03:41:51.404  [FFmpeg] SUCCESS: x264_encoder_open() succeeded
03:41:51.404  [FFmpeg] DIAG-D: codec->init() returned: 0
03:41:51.404  [FFmpeg] DIAG-E: avcodec_open2() EXIT (ret: 0)
03:41:51.404  [PJSIP] After avcodec_open2() (FIX 100.204 DIAG-E)
03:41:51.404  [PJSIP] Success! (FIX 100.204 verification)

03:41:52.328  [PJSIP] Before avcodec_send_frame() (FIX 100.204 DIAG-B)
03:41:52.328  [FFmpeg] setup_frame() (FIX 100.202)
03:41:52.328  [FFmpeg] X264Context initialized! x4->enc valid!
03:41:52.328  [PJSIP] Encoding success!
```

**如果缺少 DIAG-F**：
```
03:41:51.403  [FFmpeg] DIAG-C: About to call codec->init()
03:41:51.403  [FFmpeg] DIAG-D: returned 0 (但没有 DIAG-F！)
```
→ 证明 X264_init() 未被调用

---

## 技术细节

### fprintf vs av_log

**为什么使用 fprintf(stderr)**：
- ✅ 立即输出，不受 FFmpeg 日志级别限制
- ✅ 确保所有诊断信息都被记录
- ✅ 容易区分（DIAG 标签）

**av_log 的问题**：
- ❌ 可能被日志级别过滤
- ❌ 输出格式复杂，难以搜索

### fflush(stderr) 的重要性

**为什么需要 fflush**：
- ✅ 确保日志立即写入（避免崩溃时丢失）
- ✅ 保证日志时间序列正确
- ✅ 在多线程环境下减少日志交错

---

## 下一步调查方向（如果 X264_init 未被调用）

### 方向 1：检查 FFmpeg 线程模式

**可能原因**：`!(avctx->active_thread_type & FF_THREAD_FRAME)` 条件不满足

**调查方法**：
- 在 DIAG-C 之前添加日志：
  ```c
  fprintf(stderr, "  active_thread_type: %d\n", avctx->active_thread_type);
  fprintf(stderr, "  FF_THREAD_FRAME: %d\n", FF_THREAD_FRAME);
  fprintf(stderr, "  frame_thread_encoder: %d\n", avci->frame_thread_encoder);
  ```

**如果 `active_thread_type & FF_THREAD_FRAME` 为真**：
- FFmpeg 使用帧线程模式
- `codec->init` 在另一个线程中调用
- 需要在 `ff_frame_thread_encoder_init()` 中添加日志

---

### 方向 2：检查 FFmpeg 版本特定 Bug

**操作**：
1. 搜索 FFmpeg 官方 Issue Tracker：
   - 关键词：`avcodec_open2`, `priv_data not initialized`, `libx264`
   - 版本：FFmpeg 6.0, 6.1

2. 查看 FFmpeg Changelog：
   - 6.0 → 6.1 → 7.0 的修复记录

**如果找到相关 Bug**：
- 升级 FFmpeg 到修复版本
- 或应用官方 Patch

---

### 方向 3：强制调用 X264_init()（最后手段）

**在 PJSIP 中添加临时修复**：

```c
/* ✅ 2026-01-16 00:00 [FIX 100.206] 强制初始化 X264Context */
if (ff->enc && strcmp(ff->enc->name, "libx264") == 0) {
    X264Context *x4 = (X264Context*)ff->enc_ctx->priv_data;

    if (!x4 || !x4->enc) {
        PJ_LOG(1,(THIS_FILE, "⚠️ Forcing X264_init()..."));

        /* 声明 FFmpeg 内部函数 */
        extern int X264_init(AVCodecContext *avctx);

        int init_ret = X264_init(ff->enc_ctx);
        if (init_ret < 0) {
            PJ_LOG(1,(THIS_FILE, "❌ Forced init failed: %d", init_ret));
            status = PJMEDIA_CODEC_EFAILED;
            goto on_error;
        }

        PJ_LOG(1,(THIS_FILE, "✅ Forced init succeeded!"));
    }
}
```

**问题**：
- ❌ 破坏了 FFmpeg 的封装
- ❌ 版本兼容性差
- ⚠️ 但可能是唯一的临时解决方案

---

## 总结

### ✅ FIX 100.205 的成就

1. **完整的诊断覆盖**：
   - ✅ avcodec_open2() 完整流程（DIAG-A/B/C/D/E）
   - ✅ X264_init() 调用检测（DIAG-F）
   - ✅ x264_encoder_open() 结果（SUCCESS/ERROR）
   - ✅ codec->init 为 NULL 的检测（WARNING）

2. **预期结果**：
   - 95%+ 概率找到为什么 X264_init() 未被调用
   - 或确认 X264_init() 被调用但 PJSIP 使用了错误的实例

3. **下一步明确**：
   - 根据日志结果决定修复方向
   - 修改 FFmpeg 或修改 PJSIP 或升级 FFmpeg 版本

### 🎯 测试计划

**部署后**：
1. 拨打视频通话
2. 查找所有 `[FIX 100.205]` 日志
3. 按时间序列排列
4. 对比 PJSIP FIX 100.204 日志
5. 确定根本原因

**预期结果**：
- 日志会清楚显示 `X264_init()` 是否被调用
- 如果被调用，`x4->enc` 的值是什么
- 如果未被调用，为什么 FFmpeg 跳过了初始化

---

## 参考文档

- [docs/2026-01-15/13-FIX204测试结果-排除PJSIP侧问题.md](13-FIX204测试结果-排除PJSIP侧问题.md) - FIX 100.204 结果
- [docs/2026-01-15/12-FIX204实施方案-PJSIP编码器验证和修复.md](12-FIX204实施方案-PJSIP编码器验证和修复.md) - FIX 100.204 方案
- [docs/2026-01-15/11-修复方案深度对比-最小FFmpeg修改.md](11-修复方案深度对比-最小FFmpeg修改.md) - 方案对比
- `cross-compile/src/ffmpeg-rockchip-6.0/libavcodec/avcodec.c` Line 134-406: FIX 100.205 诊断代码
- `cross-compile/src/ffmpeg-rockchip-6.0/libavcodec/libx264.c` Line 1163-1554: FIX 100.205 诊断代码

---

**实施时间**：2026-01-15 23:45 - 00:30（45 分钟）
**代码变更**：2 个文件，8 个诊断点
**FFmpeg 编译**：增量编译完成（2-5 分钟）
**部署状态**：正在进行中

✅ **FIX 100.205 准备完成，等待测试结果！**
