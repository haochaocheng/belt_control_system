# libx264 崩溃真正根因 - x264_encoder_maximum_delayed_frames 可能返回 0

**时间**: 2026-01-15 22:30
**状态**: 🔍 源码分析完成
**发现**: 问题可能在 `reordered_opaque` 数组大小计算

---

## 🔍 源码分析结果

### 崩溃调用链
```
第一帧编码 → X264_frame() → opaque_uninit(opaque)
  → av_buffer_unref(&opaque->frame_opaque_ref)
    → buffer_replace() → 访问 b->refcount → ❌ SIGSEGV
```

### 关键代码位置

#### 1. 编码器初始化 (libx264.c:1246-1292)
```c
// Line 1246: 创建编码器
x4->enc = x264_encoder_open(&x4->params);
if (!x4->enc)
    return AVERROR_EXTERNAL;

// ... 省略 30 行 ...

// Line 1286: 计算 reordered_opaque 数组大小
x4->nb_reordered_opaque = x264_encoder_maximum_delayed_frames(x4->enc) + 17;

// Line 1287-1288: 分配并初始化数组为 0
x4->reordered_opaque = av_calloc(x4->nb_reordered_opaque,
                                  sizeof(*x4->reordered_opaque));
if (!x4->reordered_opaque) {
    x4->nb_reordered_opaque = 0;  // ⚠️ 失败时设为 0
    return AVERROR(ENOMEM);
}
```

#### 2. 第一帧编码 (libx264.c:459-506)
```c
static int X264_frame(AVCodecContext *ctx, AVPacket *pkt,
                      const AVFrame *frame, int *got_packet)
{
    X264Context *x4 = ctx->priv_data;
    x264_nal_t *nal;
    int nnal, i, ret;
    x264_picture_t pic_out = {0};
    int pict_type;
    int64_t wallclock = 0;
    X264Opaque *opaque;

    x264_picture_init(&pic);

    // Line 471: 获取当前 reordered_opaque 槽位
    opaque = &x4->reordered_opaque[x4->next_reordered_opaque];

    // ... 设置 pic ...

    // Line 506: ⚠️ 崩溃点！
    opaque_uninit(opaque);  // 调用 av_buffer_unref(&opaque->frame_opaque_ref)

    // ...
}
```

#### 3. opaque_uninit() (libx264.c:149-153)
```c
static void opaque_uninit(X264Opaque *o)
{
    av_buffer_unref(&o->frame_opaque_ref);  // ⚠️ 这里崩溃
    memset(o, 0, sizeof(*o));
}
```

#### 4. av_buffer_unref() (buffer.c:139-145)
```c
void av_buffer_unref(AVBufferRef **buf)
{
    if (!buf || !*buf)  // ✅ 检查 NULL
        return;

    buffer_replace(buf, NULL);  // → 调用 buffer_replace
}
```

#### 5. buffer_replace() (buffer.c:119-137)
```c
static void buffer_replace(AVBufferRef **dst, AVBufferRef **src)
{
    AVBuffer *b;

    if (!src || !*src) {
        av_freep(dst);
        return;
    }
    b = (*src)->buffer;  // ✅ src 不为 NULL

    // ...

    if (*dst) {
        AVBuffer *b = (*dst)->buffer;  // ⚠️ 访问 dst 指向的内存

        **dst = **src;
        av_freep(src);
    } else
        av_freep(dst);

    // Line 129: ⚠️ 崩溃点！访问 b->refcount
    if (atomic_fetch_sub_explicit(&b->refcount, 1, memory_order_acq_rel) == 1) {
        // b->free below might already free the structure containing *b
        int free_avbuffer = !(b->flags_internal & BUFFER_FLAG_NO_FREE);
        b->free(b->opaque, b->data);
        if (free_avbuffer)
            av_free(b);
    }
}
```

---

## 💡 问题假设

### 假设 A：`nb_reordered_opaque = 0` 导致数组越界
**可能性**: ⭐⭐⭐⭐⭐ (极高)

**推理**：
1. `x264_encoder_maximum_delayed_frames(x4->enc)` 可能返回 **负数**（例如 -17）
2. 计算结果：`nb_reordered_opaque = -17 + 17 = 0`
3. `av_calloc(0, sizeof(...))` 返回什么？
   - 某些实现返回 NULL
   - 某些实现返回有效但大小为 0 的指针
4. 如果返回 NULL → Line 1289-1292 检测到并返回 ENOMEM
5. **如果返回非 NULL 的小指针** → 后续访问 `x4->reordered_opaque[0]` 越界！

**为什么我们的设置可能导致返回 0？**

根据 libx264.c:964-967，FFmpeg 会使用 `avctx->gop_size` 和 `avctx->max_b_frames`：
```c
if (avctx->gop_size >= 0)
    x4->params.i_keyint_max = avctx->gop_size;
if (avctx->max_b_frames >= 0)
    x4->params.i_bframe = avctx->max_b_frames;
```

我们的 FIX 100.194/195 设置：
- `ctx->gop_size = 300`
- `ctx->max_b_frames = 0`  ← **禁用 B 帧！**

`x264_encoder_maximum_delayed_frames()` 的计算公式（推测）：
```c
delayed_frames = params.i_bframe + params.i_bframe_pyramid + ...
```

如果 `i_bframe = 0`（无 B 帧），可能导致 `delayed_frames` 非常小甚至 0！

### 假设 B：`opaque->frame_opaque_ref` 指向损坏的内存
**可能性**: ⭐⭐⭐ (中等)

**推理**：
1. `reordered_opaque` 数组通过 `av_calloc()` 分配，初始化为全 0
2. 第一次调用 `opaque_uninit()` 时，`frame_opaque_ref` 应该是 NULL
3. `av_buffer_unref(NULL)` 应该安全返回（Line 141 检查）
4. 但如果某处代码污染了这个指针 → 指向无效内存 → 崩溃

---

## 🧪 验证方法

### 验证假设 A（推荐）⭐⭐⭐

#### 1. 打印 `nb_reordered_opaque` 的值
在 `X264_init()` 中添加日志：
```c
// libavcodec/libx264.c:1286 之后
x4->nb_reordered_opaque = x264_encoder_maximum_delayed_frames(x4->enc) + 17;
av_log(avctx, AV_LOG_ERROR,
       "[DEBUG] nb_reordered_opaque = %d (delayed_frames=%d)\n",
       x4->nb_reordered_opaque,
       x264_encoder_maximum_delayed_frames(x4->enc));
```

#### 2. 强制最小值
```c
// libavcodec/libx264.c:1286
int delayed_frames = x264_encoder_maximum_delayed_frames(x4->enc);
x4->nb_reordered_opaque = delayed_frames + 17;

// ⭐ 添加保护：最小值为 1
if (x4->nb_reordered_opaque < 1) {
    av_log(avctx, AV_LOG_WARNING,
           "[FIX] nb_reordered_opaque was %d, forcing to 1\n",
           x4->nb_reordered_opaque);
    x4->nb_reordered_opaque = 1;
}
```

#### 3. 检查 `av_calloc(0, size)` 的行为
测试代码：
```c
void *ptr = av_calloc(0, sizeof(X264Opaque));
av_log(NULL, AV_LOG_ERROR, "av_calloc(0, %zu) = %p\n",
       sizeof(X264Opaque), ptr);
```

### 验证假设 B

#### 在 `opaque_uninit()` 中添加防御性检查
```c
// libavcodec/libx264.c:149
static void opaque_uninit(X264Opaque *o)
{
    // ⭐ 添加日志和检查
    av_log(NULL, AV_LOG_ERROR,
           "[DEBUG] opaque_uninit: o=%p, frame_opaque_ref=%p\n",
           o, o ? o->frame_opaque_ref : NULL);

    if (o && o->frame_opaque_ref) {
        AVBufferRef *ref = o->frame_opaque_ref;
        av_log(NULL, AV_LOG_ERROR,
               "[DEBUG]   frame_opaque_ref->buffer=%p, data=%p, size=%d\n",
               ref->buffer, ref->data, ref->size);
    }

    av_buffer_unref(&o->frame_opaque_ref);
    memset(o, 0, sizeof(*o));
}
```

---

## 🎯 推荐的修复方案

### 方案 1：修复 `nb_reordered_opaque` 计算（最直接）⭐⭐⭐⭐⭐

**修改位置**: `cross-compile/src/ffmpeg-rockchip-6.0/libavcodec/libx264.c:1286`

```c
// 原代码
x4->nb_reordered_opaque = x264_encoder_maximum_delayed_frames(x4->enc) + 17;

// 修复后
int delayed_frames = x264_encoder_maximum_delayed_frames(x4->enc);
x4->nb_reordered_opaque = FFMAX(delayed_frames + 17, 1);  // 最小值 1

av_log(avctx, AV_LOG_WARNING,
       "[FIX 100.196] nb_reordered_opaque = %d (delayed_frames=%d, forced minimum=1)\n",
       x4->nb_reordered_opaque, delayed_frames);
```

### 方案 2：允许 B 帧（如果问题确实是 delayed_frames=0）

**修改位置**: `cross-compile/src/pjproject-2.16/pjmedia/src/pjmedia-codec/ffmpeg_vid_codecs.c:671`

```c
// 原代码 (FIX 100.194/195)
ctx->max_b_frames = 0;  // 禁用 B 帧

// 修复后
ctx->max_b_frames = 2;  // 允许 2 个 B 帧（libx264 默认值）

PJ_LOG(1, (THIS_FILE, "   ✅ GOP: gop_size=%d, keyint_min=%d, max_b_frames=%d",
           ctx->gop_size, ctx->keyint_min, ctx->max_b_frames));
```

**理由**：B 帧会增加延迟帧数，使 `delayed_frames > 0`

### 方案 3：回退到系统 libx264（终极方案）

如果以上都不行，说明 libx264.so.165 和 FFmpeg 6.0 真的不兼容。

---

## 📊 下一步行动

1. **优先验证假设 A**：
   - 在 FFmpeg 源码中添加 `nb_reordered_opaque` 打印日志
   - 重新编译 FFmpeg
   - 测试并查看日志

2. **如果 `nb_reordered_opaque = 0` 或很小**：
   - 实施方案 1（强制最小值 1）
   - 重新编译测试

3. **如果不是数组大小问题**：
   - 实施验证假设 B
   - 检查 `frame_opaque_ref` 的值

4. **终极方案**：
   - 使用系统 libx264
   - 或回退到 FFmpeg 4.4

---

## ✍️ 总结

**最有可能的根本原因**：
- 我们设置 `max_b_frames = 0`（禁用 B 帧）
- → `x264_encoder_maximum_delayed_frames()` 返回 0 或负数
- → `nb_reordered_opaque = 0` 或很小
- → `av_calloc(0, ...)` 返回非 NULL 但无效的指针
- → 访问 `reordered_opaque[0]` 时越界
- → `opaque->frame_opaque_ref` 指向垃圾内存
- → `av_buffer_unref()` 访问损坏的指针 → **SIGSEGV**

**证据**：
- ✅ 编码器成功打开
- ✅ 所有字段设置正确
- ❌ 第一帧编码时崩溃
- ❌ 崩溃在 `av_buffer_unref(&opaque->frame_opaque_ref)`

**下一步**：验证 `nb_reordered_opaque` 的值，如果为 0 或很小，强制设为最小值 1。
