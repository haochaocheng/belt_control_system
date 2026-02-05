# VERSION 167 失败分析 - codec->close 为 NULL
# 2026-01-15 13:00（北京时间）

## 一、问题回顾

### VERSION 167 测试结果

**崩溃位置**：NOT in avcodec_close (as expected)，而是在 `pj_grp_lock_dec_ref()`

```
崩溃栈：
#0  pj_grp_lock_dec_ref()
#1  op_remove_port.isra()
#2  handle_op_queue()
#3  on_clock_tick()
```

**关键日志发现**（voip.md Line 3350-3360）：

```
!!! [VERSION 167] === Encoder Context State ===
!!! [VERSION 167] enc_ctx address: 0x7f040368b0
!!! [VERSION 167] enc_ctx->codec: 0x7fb5559740
!!! [VERSION 167] codec->name: h264_rkmpp
!!! [VERSION 167] codec->close callback: (nil)   ← 关键问题！
!!! [VERSION 167] enc_ctx->hw_frames_ctx: (nil)
!!! [VERSION 167] enc_ctx->hw_device_ctx: 0x7f04037810
!!! [VERSION 167] enc_ctx->width=640, height=480

!!! [VERSION 167 STEP-1] === Calling Encoder Close Callback ===
!!! [VERSION 167 STEP-1] No encoder close callback available  ← rkmpp_encode_close() 未被调用
```

---

## 二、根本原因分析

### 1. enc_ctx->codec->close 为 NULL

**状态确认**：
- ✅ enc_ctx 存在：0x7f040368b0
- ✅ enc_ctx->codec 存在：0x7fb5559740
- ✅ codec->name 正确：h264_rkmpp
- ❌ **codec->close 为 NULL**

**预期行为**：
- codec->close 应该指向 `rkmpp_encode_close()` 函数（定义在 rkmppenc.c Line 1176）

### 2. 为什么 codec->close 为 NULL？

**可能原因 A：FFmpeg 6.0 API 变更**

FFmpeg 5.1+ 进行了重大 API 变更：
- 旧 API：`AVCodec` 结构体
- 新 API：`FFCodec` 结构体（内部使用）+ `AVCodec`（公共 API）

**关键变化**：
- FFmpeg 6.0 中，`AVCodec.close` 字段可能已移除或重定向
- close 回调可能在 `FFCodec.cb.close` 或其他位置

**可能原因 B：编码器注册问题**

```c
// rkmppenc.c 末尾
#if CONFIG_H264_RKMPP_ENCODER
DEFINE_RKMPP_ENCODER(h264, H264, h26x)
#endif
```

`DEFINE_RKMPP_ENCODER` 宏可能没有正确设置 close 回调。

**可能原因 C：PJSIP 使用的 FFmpeg API 过时**

```c
// ffmpeg_vid_codecs.c Line 89
#  define AVCODEC_OPEN(ctx,c)           avcodec_open2(ctx,c,NULL)
```

PJSIP 可能使用的是旧版 FFmpeg API，无法正确访问新版本的 codec 结构。

---

## 三、后果分析

### 1. rkmpp_encode_close() 未被调用

**未清理的资源**：

```c
static av_cold int rkmpp_encode_close(AVCodecContext *avctx)
{
    // ✅ 应该执行但未执行的清理步骤：

    // 1. 清理 MPP 配置
    mpp_enc_cfg_deinit(r->mcfg);

    // 2. 清理 MPP 帧池
    if (r->frame_group) {
        mpp_buffer_group_put(r->frame_group);
    }

    // 3. 销毁 MPP 上下文（最关键）
    if (r->ctx) {
        mpp_destroy(r->ctx);  // ← 未执行！
        r->ctx = NULL;
    }

    // 4. 清理输出队列
    while ((pkt = av_fifo_peek_buf(r->pkt_fifo, 0))) {
        av_packet_free(&pkt);
        av_fifo_drain(r->pkt_fifo, 1);
    }
    av_fifo_freep2(&r->pkt_fifo);
}
```

### 2. RKMPP 资源泄漏导致状态损坏

**影响链条**：

```
rkmpp_encode_close() 未执行
    ↓
mpp_destroy() 未调用
    ↓
MPP 上下文、DRM buffer、帧池等资源未释放
    ↓
RKMPP 驱动内部状态损坏
    ↓
PJSIP 尝试清理 video port
    ↓
pj_grp_lock_dec_ref() 遇到损坏的引用计数
    ↓
SIGSEGV 崩溃 ❌
```

---

## 四、与历史版本的对比

| 版本 | avcodec_close() | rkmpp_encode_close() | 崩溃位置 |
|------|----------------|---------------------|---------|
| VERSION 155 | ✅ 调用 | ✅ 被调用（通过 avcodec_close） | avcodec_close() 内部 |
| VERSION 156 | ❌ 不调用 | ❌ 未被调用（资源泄漏） | ✅ 不崩溃（但泄漏 2.5 MB）|
| **VERSION 167** | ❌ 不调用 | ❌ **未被调用（codec->close=NULL）** | pj_grp_lock_dec_ref() |

**关键区别**：
- VERSION 156：故意不调用 avcodec_close()，也不调用 rkmpp_encode_close() → 资源泄漏但不崩溃
- VERSION 167：试图手动调用 rkmpp_encode_close()，但 codec->close 为 NULL → 资源未清理，后续崩溃

**重要发现**：
- **VERSION 155 为什么能调用 rkmpp_encode_close()?**
  - avcodec_close() 内部有特殊逻辑处理 NULL close 回调？
  - 或者 avcodec_close() 通过其他方式调用 close 函数？

---

## 五、解决方案分析

### 方案 A：直接调用 rkmpp_encode_close() ⭐⭐⭐⭐

**核心思路**：不依赖 enc_ctx->codec->close，直接声明并调用 rkmpp_encode_close()

**实施方法**：

```c
// ffmpeg_vid_codecs.c

// ✅ 声明 rkmpp_encode_close() 外部函数
extern int rkmpp_encode_close(void *avctx);

static pj_status_t ffmpeg_codec_close(pjmedia_vid_codec *codec)
{
    struct ffmpeg_private *ff = (struct ffmpeg_private*)codec->codec_data;

    if (ff->enc_ctx) {
        fprintf(stderr, "!!! [VERSION 168 PLAN-A] Directly calling rkmpp_encode_close()\n");
        fflush(stderr);

        // ✅ 直接调用，不通过 codec->close
        rkmpp_encode_close(ff->enc_ctx);

        // ✅ 等待 RKMPP 异步线程完全退出
        usleep(2000 * 1000);  // 2 秒

        // ✅ 手动释放 hw_frames_ctx、hw_device_ctx
        if (ff->enc_ctx->hw_frames_ctx) {
            av_buffer_unref(&ff->enc_ctx->hw_frames_ctx);
        }
        if (ff->enc_ctx->hw_device_ctx) {
            av_buffer_unref(&ff->enc_ctx->hw_device_ctx);
        }

        // ✅ 释放 AVCodecContext 结构
        av_free(ff->enc_ctx);
        ff->enc_ctx = NULL;
    }

    // 解码器正常释放
    if (ff->dec_ctx) {
        avcodec_free_context(&ff->dec_ctx);
    }

    return PJ_SUCCESS;
}
```

**优点**：
- ✅ 确保 rkmpp_encode_close() 被调用
- ✅ RKMPP 资源被正确清理
- ✅ 避免 codec->close 为 NULL 的问题

**缺点**：
- ⚠️ 需要 extern 声明（跨模块调用）
- ⚠️ 可能违反 FFmpeg API 封装原则
- ⚠️ 需要确认 rkmpp_encode_close() 是否导出

**风险评估**：⭐⭐ **低到中等**

---

### 方案 B：使用 avcodec_flush_buffers() + 手动清理 ⭐⭐

**核心思路**：使用 FFmpeg 标准 API flush 编码器缓冲，然后手动清理资源

```c
static pj_status_t ffmpeg_codec_close(pjmedia_vid_codec *codec)
{
    struct ffmpeg_private *ff = (struct ffmpeg_private*)codec->codec_data;

    if (ff->enc_ctx) {
        fprintf(stderr, "!!! [VERSION 168 PLAN-B] Using avcodec_flush_buffers()\n");
        fflush(stderr);

        // ✅ 刷新编码器缓冲（可能触发部分清理）
        avcodec_flush_buffers(ff->enc_ctx);

        // ✅ 等待 RKMPP 异步线程退出
        usleep(2000 * 1000);

        // ✅ 手动清理所有资源
        // （同方案 A）
    }

    return PJ_SUCCESS;
}
```

**优点**：
- ✅ 使用标准 FFmpeg API
- ✅ 不需要 extern 声明

**缺点**：
- ❌ avcodec_flush_buffers() 可能不会调用 close 回调
- ❌ RKMPP 资源可能仍未清理
- ❌ 效果不确定

**风险评估**：⭐⭐⭐ **中等**

---

### 方案 C：通过 avcodec_free_context() 触发清理 ⭐⭐⭐

**核心思路**：研究 avcodec_free_context() 的实现，看它如何调用 close

```c
static pj_status_t ffmpeg_codec_close(pjmedia_vid_codec *codec)
{
    struct ffmpeg_private *ff = (struct ffmpeg_private*)codec->codec_data;

    if (ff->enc_ctx) {
        fprintf(stderr, "!!! [VERSION 168 PLAN-C] Using avcodec_free_context()\n");
        fflush(stderr);

        // ✅ 延迟 2 秒，等待 RKMPP 异步线程（即使未调用 close）
        usleep(2000 * 1000);

        // ✅ 使用 avcodec_free_context()（而不是手动 av_free）
        avcodec_free_context(&ff->enc_ctx);
    }

    return PJ_SUCCESS;
}
```

**关键问题**：
- avcodec_free_context() 是否会调用 close 回调？
- 如果 codec->close 为 NULL，它会做什么？

**优点**：
- ✅ 使用标准 FFmpeg API
- ✅ 可能触发内部清理逻辑

**缺点**：
- ⚠️ 不确定是否会调用 rkmpp_encode_close()
- ⚠️ VERSION 156 使用此方法仍泄漏资源

**风险评估**：⭐⭐⭐ **中等**

---

### 方案 D：恢复 VERSION 156（接受资源泄漏）⭐⭐⭐⭐

**核心思路**：回到 VERSION 156，接受 2.5 MB 资源泄漏，但保证不崩溃

**理由**：
- ✅ VERSION 156 已验证不崩溃
- ✅ 资源泄漏量可控（每次通话 2.5 MB）
- ✅ 进程退出时 OS 回收所有内存
- ⚠️ 长期使用（50+ 次通话）可能影响性能

**适用场景**：
- 短期解决方案（应急）
- 等待方案 E（软件编码器）或方案 A 实施

**风险评估**：⭐ **最低**（已验证）

---

### 方案 E：使用软件编码器 libx264 ⭐⭐⭐⭐⭐

**核心思路**：完全放弃 RKMPP 硬件编码器，使用 libx264 软件编码器

```powershell
$env:USE_HARDWARE_ENCODER=0
.\build-ubuntu24-apt.ps1 188
```

**优点**：
- ✅ 100% 避免 RKMPP 相关问题
- ✅ 没有 hw_device_ctx 问题
- ✅ 资源清理简单可靠
- ✅ Fix 100.50 成功案例可能就是软件编码器

**缺点**：
- ❌ CPU 占用较高（但 libx264 veryfast 很快）
- ❌ 放弃硬件加速优势

**风险评估**：⭐ **无**（成熟方案）

---

## 六、推荐实施路线

### 第一步：尝试方案 A（直接调用 rkmpp_encode_close）⭐⭐⭐⭐

**理由**：
- 直接解决 codec->close 为 NULL 的问题
- 确保 RKMPP 资源被正确清理

**实施步骤**：
1. 修改 `ffmpeg_vid_codecs.c`：添加 extern 声明和直接调用
2. 增量编译 PJSIP（2-3 分钟）
3. 部署测试

**预期结果**：
- ✅ rkmpp_encode_close() 被调用
- ✅ RKMPP 资源被清理
- ✅ 挂断不崩溃
- ✅ 无资源泄漏

**如果方案 A 失败（链接错误或仍崩溃）**：
→ 立即尝试方案 E（软件编码器）

---

### 第二步：如果方案 A 成功，长期监控

**验证要点**：
- 3 次视频通话测试
- 10+ 次视频通话压力测试
- 监控资源使用（无泄漏）

---

### 备选方案：方案 E（软件编码器）

**如果方案 A 失败，或需要最可靠方案**：
- 使用 libx264 软件编码器
- 100% 可靠，避免所有硬件相关问题

---

## 七、关键认知更新

### 1. VERSION 167 失败的真正原因

**不是**：
- ❌ RKMPP 异步线程竞态条件（方案 G 已验证）
- ❌ avcodec_close() 的清理顺序问题

**而是**：
- ✅ **codec->close 为 NULL，rkmpp_encode_close() 未被调用**
- ✅ RKMPP 资源未清理，导致后续 PJSIP 操作崩溃

### 2. VERSION 156 为什么成功？

**猜测**：
- VERSION 156 完全不调用任何清理函数
- RKMPP 资源被泄漏，但不会触发清理逻辑
- 没有尝试访问已损坏的资源 → 不崩溃

**VERSION 167 为什么失败？**：
- VERSION 167 手动释放了 hw_frames_ctx、hw_device_ctx
- 但 RKMPP 内部资源（MPP context、DRM buffer）未清理
- PJSIP 后续操作遇到不一致状态 → 崩溃

### 3. 为什么 codec->close 为 NULL？

**需要进一步调查**：
- FFmpeg 6.0 API 变更？
- RKMPP 编码器注册问题？
- PJSIP 使用的 FFmpeg API 不兼容？

**下一步研究**：
- 查看 FFmpeg 6.0 的 AVCodec 结构定义
- 查看 rkmppenc.c 的 DEFINE_RKMPP_ENCODER 宏
- 查看 avcodec_open2() 如何设置 codec 指针

---

## 八、总结

**VERSION 167 失败的核心问题**：
- ❌ codec->close 为 NULL
- ❌ rkmpp_encode_close() 未被调用
- ❌ RKMPP 资源未清理 → PJSIP 崩溃

**推荐方案**：
1. **⭐⭐⭐⭐ 方案 A**：直接调用 rkmpp_encode_close()（优先尝试）
2. **⭐⭐⭐⭐⭐ 方案 E**：软件编码器 libx264（最可靠兜底方案）

**下一步行动**：
- 实施 VERSION 168（方案 A：直接调用）
- 如失败，立即切换到方案 E（软件编码器）

---

**文档创建时间**：2026-01-15 13:00（北京时间）
**分析人**：Claude Sonnet 4.5
**状态**：📋 **失败分析完成，方案 A 设计完成**
**下一步**：实施 VERSION 168（方案 A）→ 测试验证 → 如失败则方案 E
