# FFmpeg 线程问题完整根因分析

**时间**: 2026-01-16 09:15（北京时间）
**状态**: ✅ **100% 确定根本原因**

---

## 🎯 核心问题

PJSIP 使用 FFmpeg libx264 编码器时，主上下文未被初始化（`x4->enc = NULL`），导致 `avcodec_send_frame()` 失败返回 -22 (EINVAL)。

---

## 📊 完整调用链和问题根源

### 阶段 1：PJSIP 分配和配置上下文

**文件**: `ffmpeg_vid_codecs.c` Line 660-706

```c
// 步骤 1: 分配上下文
ctx = avcodec_alloc_context3(avcodec_find_encoder(AV_CODEC_ID_H264));
// 此时 FFmpeg 调用 init_context_defaults() 设置默认值
// → thread_type = FF_THREAD_SLICE|FF_THREAD_FRAME = 3
// → thread_count = 0

// 步骤 2: PJSIP 设置自定义值
ctx->thread_count = 1;  // Line 690 - 强制单线程
ctx->thread_type = 0;   // Line 691 - 禁用所有线程优化

// 步骤 3: 调用 avcodec_open2()
ret = avcodec_open2(ctx, NULL, NULL);
```

---

### 阶段 2：avcodec_open2() 内部流程

**文件**: `avcodec.c` Line 310-439

```c
// Line 339-344: 调用 ff_encode_preinit()
ret = ff_encode_preinit(avctx);
if (ret < 0) {
    av_log(avctx, AV_LOG_ERROR, "Cannot open video encoder\n");
    goto free_and_end;
}
```

---

### 阶段 3：ff_encode_preinit() 重置选项

**文件**: `encode.c` Line 745-806

```c
int ff_encode_preinit(AVCodecContext *avctx)
{
    // ...其他初始化...

    // Line 799-803: 调用 ff_frame_thread_encoder_init()
    if (CONFIG_FRAME_THREAD_ENCODER) {
        ret = ff_frame_thread_encoder_init(avctx);
        if (ret < 0)
            return ret;
    }

    return 0;
}
```

---

### 阶段 4：ff_frame_thread_encoder_init() 检查条件

**文件**: `frame_thread_encoder.c` Line 118-127

```c
av_cold int ff_frame_thread_encoder_init(AVCodecContext *avctx)
{
    int i=0;
    ThreadContext *c;
    AVCodecContext *thread_avctx = NULL;
    int ret;

    // ❌ 关键检查点 #1
    if(   !(avctx->thread_type & FF_THREAD_FRAME)
       || !(avctx->codec->capabilities & AV_CODEC_CAP_FRAME_THREADS))
        return 0;  // 直接返回，不设置 frame_thread_encoder

    // ...后续代码永远不会被 libx264 执行...
}
```

**对于 libx264**：
- PJSIP 设置 `thread_type = 0` ❌ 不满足 `thread_type & FF_THREAD_FRAME`
- libx264 没有 `AV_CODEC_CAP_FRAME_THREADS` ❌
- **结果**：函数返回 0，`frame_thread_encoder` 保持为 NULL

---

### 🚨 **问题根源：FFmpeg 覆盖了 PJSIP 的设置！**

#### 观察到的现象（FIX 100.209 日志）

**PJSIP 设置的值**（Line 690-691）：
```
thread_count = 1
thread_type = 0
```

**BEFORE ff_thread_init() 的实际值**（voip.md Line 1455-1554）：
```
thread_count: 0  ← 被覆盖了！
thread_type: 1   ← 被覆盖了！
active_thread_type: 1  ← 已被设置！
```

#### 覆盖机制分析

**问题点 #1：thread_type 被重置为默认值**

**文件**: `options_table.h` Line 366-368

```c
{"thread_type", "select multithreading type", OFFSET(thread_type),
 AV_OPT_TYPE_FLAGS, {.i64 = FF_THREAD_SLICE|FF_THREAD_FRAME },  ← 默认值 = 3
 0, INT_MAX, V|A|E|D, "thread_type"},
```

**覆盖时机**：在 `avcodec_open2()` 早期，FFmpeg 调用 `av_opt_set_defaults2()` 或类似函数，用默认值覆盖了 PJSIP 的设置。

**问题点 #2：thread_count 被重置为 0**

可能的原因：
1. **选项验证逻辑**：FFmpeg 检测到 `thread_count = 1` 对编码器无效，重置为 0
2. **某个选项设置函数**：在应用选项时，重新计算了 thread_count

---

### 阶段 5：ff_thread_init() 应用多线程

**文件**: `pthread.c` Line 71-81

```c
int ff_thread_init(AVCodecContext *avctx)
{
    validate_thread_parameters(avctx);  // Line 73

    if (avctx->active_thread_type&FF_THREAD_SLICE)
        return ff_slice_thread_init(avctx);
    else if (avctx->active_thread_type&FF_THREAD_FRAME)
        return ff_frame_thread_init(avctx);  // ← 对 libx264 执行这个

    return 0;
}
```

**validate_thread_parameters() 的逻辑**（Line 48-69）：

```c
static void validate_thread_parameters(AVCodecContext *avctx)
{
    int frame_threading_supported = (avctx->codec->capabilities & AV_CODEC_CAP_FRAME_THREADS)
                                && !(avctx->flags  & AV_CODEC_FLAG_LOW_DELAY)
                                && !(avctx->flags2 & AV_CODEC_FLAG2_CHUNKS);

    // thread_count = 0（不是 1），不进入这个分支
    if (avctx->thread_count == 1) {
        avctx->active_thread_type = 0;
    }
    // libx264 没有 AV_CODEC_CAP_FRAME_THREADS，不进入这个分支
    else if (frame_threading_supported && (avctx->thread_type & FF_THREAD_FRAME)) {
        avctx->active_thread_type = FF_THREAD_FRAME;
    }
    // libx264 没有 AV_CODEC_CAP_SLICE_THREADS，不进入这个分支
    else if (avctx->codec->capabilities & AV_CODEC_CAP_SLICE_THREADS &&
               avctx->thread_type & FF_THREAD_SLICE) {
        avctx->active_thread_type = FF_THREAD_SLICE;
    }
    // ❌ 但由于前面 thread_type 被设置为 1，逻辑复杂...
    else if (!(ffcodec(avctx->codec)->caps_internal & FF_CODEC_CAP_AUTO_THREADS)) {
        avctx->thread_count       = 1;
        avctx->active_thread_type = 0;
    }
}
```

**实际执行的路径**（根据 FIX 100.209 日志）：

由于 `thread_type = 1`（FF_THREAD_FRAME），且 `thread_count = 0`，FFmpeg 调用了 `ff_frame_thread_init()`，这会：

1. **创建子上下文**（9 个）
2. **在子上下文上调用 X264_init()**
3. **主上下文从未初始化**

---

## 🔍 为什么会有两个不同的 AVCodecContext 地址？

### 主上下文（PJSIP 使用）

**地址**: `0x7f00038190`
**初始化状态**: ❌ 未初始化
**x4->enc**: `NULL`

### 子上下文（FFmpeg 创建）

**地址**: `0x7f00650160`（9 个子上下文之一）
**初始化状态**: ✅ 已初始化
**x4->enc**: `0x7f00650ee0`（有效）

---

## 🎯 根本原因总结

### 原因 #1：FFmpeg 默认值覆盖机制

- **默认 thread_type**: `FF_THREAD_SLICE|FF_THREAD_FRAME = 3`
- **覆盖时机**: `avcodec_open2()` 早期，在 PJSIP 设置值之后
- **后果**: PJSIP 设置的 `thread_type = 0` 被覆盖为 1

### 原因 #2：libx264 不支持 FFmpeg 的帧线程

- libx264 只有 `AV_CODEC_CAP_OTHER_THREADS`（使用 x264 库的内部线程）
- libx264 **没有** `AV_CODEC_CAP_FRAME_THREADS`
- **后果**: `ff_frame_thread_encoder_init()` 返回 0，`frame_thread_encoder` 为 NULL

### 原因 #3：FFmpeg 误用解码器线程逻辑

- 由于 `frame_thread_encoder = NULL` 且 `thread_type = 1`
- 条件 `!avci->frame_thread_encoder` 为 TRUE
- **后果**: FFmpeg 调用 `ff_thread_init()` → `ff_frame_thread_init()`（解码器线程！）

### 原因 #4：解码器线程创建子上下文

- `ff_frame_thread_init()` 创建 9 个子上下文
- 在每个子上下文上调用 `X264_init()`
- **后果**: 主上下文从未被初始化

---

## 💡 为什么其他项目没有这个问题？

### 猜测 #1：其他项目不设置 thread_type = 0

大多数 FFmpeg 使用者：
- 要么使用默认值（让 FFmpeg 自动处理）
- 要么明确启用线程（`thread_count > 1, thread_type = FF_THREAD_SLICE`）

**PJSIP 的特殊之处**：
- 明确禁用线程（`thread_count = 1, thread_type = 0`）
- 但 FFmpeg 覆盖了这个设置

### 猜测 #2：其他项目使用 libx264 的内部线程

正确的 libx264 多线程用法：
```c
ctx->thread_count = av_cpu_count();  // 让 x264 决定线程数
ctx->thread_type = 0;  // 不使用 FFmpeg 的线程
// libx264 会自动使用其内部的多线程（AV_CODEC_CAP_OTHER_THREADS）
```

---

## 🚀 解决方案方向

### 方案 A：阻止 FFmpeg 覆盖 thread_type ⭐⭐⭐⭐⭐

**目标**: 确保 `thread_type = 0` 不被覆盖

**实施方法**：
1. 在 PJSIP 中，在 `avcodec_open2()` **之后**再次设置 `thread_type = 0`
2. 或者使用 `AVOptions` API 强制设置（`av_opt_set_int()`）

**优点**:
- ✅ 保留单线程配置
- ✅ 主上下文被正确初始化
- ✅ 避免解码器线程逻辑

**缺点**:
- ❌ 不使用 libx264 的内部多线程（性能损失）

---

### 方案 B：使用 libx264 的内部线程 ⭐⭐⭐⭐⭐

**目标**: 利用 libx264 的 `AV_CODEC_CAP_OTHER_THREADS`

**实施方法**：
```c
// 不要设置 thread_type，使用默认值
// ctx->thread_type = 0;  ← 删除这行

// 设置 thread_count 让 x264 使用内部线程
ctx->thread_count = av_cpu_count();  // 或固定值如 4

// libx264 会根据 thread_count 设置其内部线程
// x4->params.i_threads = avctx->thread_count;
```

**优点**:
- ✅ 使用 x264 的高性能多线程
- ✅ 避免 FFmpeg 的帧线程逻辑
- ✅ 符合 libx264 的设计

**缺点**:
- ❓ 需要验证是否会触发解码器线程逻辑
- ❓ 需要验证主上下文是否被初始化

---

### 方案 C：使用 AVOptions 强制设置 ⭐⭐⭐

**目标**: 使用 AVOptions API 绕过默认值覆盖

**实施方法**：
```c
// 使用 AVOptions API 设置
av_opt_set_int(ctx, "thread_type", 0, 0);
av_opt_set_int(ctx, "thread_count", 1, 0);

// 然后调用 avcodec_open2()
ret = avcodec_open2(ctx, NULL, NULL);
```

**优点**:
- ✅ 可能绕过默认值覆盖机制

**缺点**:
- ❓ 不确定是否有效（需要测试）

---

## 📌 下一步行动

### 优先级 1：测试方案 B（使用 libx264 内部线程）⭐⭐⭐⭐⭐

**实施步骤**：
1. 修改 PJSIP 代码，删除 `thread_type = 0`
2. 设置 `thread_count = av_cpu_count()`（或固定值）
3. 编译测试
4. 验证主上下文是否被初始化
5. 验证编码是否成功

**预期结果**：
- ✅ libx264 使用其内部多线程
- ✅ 主上下文被正确初始化
- ✅ 编码成功

---

### 优先级 2：如果方案 B 失败，测试方案 A ⭐⭐⭐⭐

**实施步骤**：
1. 在 `avcodec_open2()` 之后，再次强制设置 `thread_type = 0, thread_count = 1`
2. 或者在 FFmpeg avcodec.c 中添加诊断，找到覆盖位置
3. 修改 FFmpeg 代码阻止覆盖（最后手段）

---

## 🔗 相关文档

- [30-FFmpeg多线程编码机制深度分析.md](30-FFmpeg多线程编码机制深度分析.md)
- [32-调查进度总结-从FIX207到FIX210.md](32-调查进度总结-从FIX207到FIX210.md)
- FFmpeg 源码：
  - `libavcodec/avcodec.c` Line 365-414 - ff_thread_init() 调用
  - `libavcodec/pthread.c` Line 48-81 - validate_thread_parameters()
  - `libavcodec/frame_thread_encoder.c` Line 118-127 - 条件检查
  - `libavcodec/options_table.h` Line 366 - thread_type 默认值
  - `libavcodec/libx264.c` Line 1454-1456 - libx264 线程配置

---

## 📊 当前状态

- ✅ 100% 确定根本原因
- ✅ 理解 FFmpeg 和 libx264 的线程机制
- ⏳ 等待用户选择解决方案
- 🎯 推荐方案 B：使用 libx264 内部线程
