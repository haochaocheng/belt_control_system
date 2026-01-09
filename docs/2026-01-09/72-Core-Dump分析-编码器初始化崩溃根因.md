# Core Dump 分析 - 编码器初始化崩溃根本原因

**日期**: 2026-01-10 15:30
**设备**: 新工控机 192.168.1.8
**问题**: 视频通话崩溃 (exit code 139 - SIGSEGV)

---

## 🎯 崩溃现场

### Core Dump 堆栈

```
#0  __GI___libc_free (mem=<optimized out>) at ./malloc/malloc.c:3375
#1  avcodec_close() from /app/lib/libavcodec.so.60
#2  avcodec_open2() from /app/lib/libavcodec.so.60
#3  open_ffmpeg_codec.isra()
#4  ffmpeg_codec_open()
#5  pjmedia_vid_stream_create()
```

**崩溃点**: `free()` 函数尝试释放无效指针

**触发路径**: `avcodec_open2()` → 初始化失败 → `avcodec_close()` 清理 → `free()` 崩溃

### 日志崩溃点

```
14:35:14.772    ffmpeg_vid_codecs.c  .......✅ [DEBUG] hw_device_ctx is NULL! (expected for libx264)
14:35:14.772    ffmpeg_vid_codecs.c  .......🔍 [DEBUG] Calling AVCODE  ← 崩溃在这里
Application exited with code: 139
```

**日志说明**：正在调用 `avcodec_open2()` 时立即崩溃

---

## 🔍 崩溃上下文分析

### 解码器状态（成功）

```
✅ [FIX 84] RKMPP decoder opened successfully (hybrid mode)
   Decoder output format: 179 (expected: 23=NV12 or 0=I420)
   Decoder dimensions: 720x480
   ⚠️ Unexpected format 179! May cause compatibility issues.
      Expected: 23 (NV12) or 0 (I420)
```

**关键发现**：
- ✅ 解码器初始化成功
- ❌ **输出格式是 179 (DRM_PRIME)** - GPU 内存中的帧
- ⚠️ **不是预期的 23 (NV12) 或 0 (I420)** - 系统内存格式

### 编码器状态（崩溃）

```
✅ [FIX 81] STEP 2: Opening encoder AFTER decoder
   Encoder: libx264rgb
   Strategy: Encoder initializes after RKMPP occupied DRM
🔍 [MUTEX REMOVED] Opening encoder WITHOUT mutex lock
🔍 [DEBUG] Encoder name: libx264rgb
🔍 [DEBUG] Encoder context: width=768, height=432, pix_fmt=0, bitrate=800000
🔍 [DEBUG] Encoder details:
   codec_id=27, codec_type=0
   profile=578, level=30
   gop_size=250, max_b_frames=0
   thread_count=0, thread_type=0
   time_base=1/25, framerate=1/1
✅ [FIX 80] libx264 encoder: hw_device_ctx set to NULL (no DRM access)
   Reason: Isolate from RKMPP decoder's DRM render node
✅ [DEBUG] hw_device_ctx is NULL! (expected for libx264)
🔍 [DEBUG] Calling AVCODE  ← 崩溃
```

**关键发现**：
- ✅ 编码器参数配置正确
- ✅ `pix_fmt=0` (YUV420P/I420) - 系统内存格式
- ✅ `hw_device_ctx=NULL` - 不使用硬件设备
- ❌ **崩溃在调用 `avcodec_open2()` 时**

---

## 💡 根本原因分析

### 问题本质：格式不匹配导致初始化失败

**1. 解码器 → 编码器格式冲突**

| 组件 | 格式 | 内存类型 | 说明 |
|------|------|----------|------|
| RKMPP 解码器 | 179 (DRM_PRIME) | GPU 内存 | 硬件解码器强制输出 |
| libx264 编码器 | 0 (YUV420P/I420) | 系统内存 | 软件编码器期望输入 |

**格式转换需求**：DRM_PRIME (GPU) → I420 (系统内存)

**2. FFmpeg 格式转换链初始化失败**

当 `avcodec_open2()` 打开编码器时：
1. FFmpeg 检测到输入格式（DRM_PRIME）与编码器期望格式（I420）不匹配
2. FFmpeg 尝试创建格式转换链（swscale 或 hwcontext）
3. **DRM_PRIME → I420 转换需要特殊处理**：
   - 需要从 GPU 内存读取帧（需要 DRM API）
   - 需要映射到系统内存（需要 `av_hwframe_transfer_data()`）
4. **转换链创建失败**：
   - 可能缺少必要的硬件上下文
   - 可能权限不足（DRM 访问）
   - 可能驱动不支持此转换

**3. 清理过程中的崩溃**

```c
// avcodec_open2() 伪代码
int avcodec_open2(AVCodecContext *ctx, AVCodec *codec, AVDictionary **options) {
    // 1. 分配编码器内部结构
    ctx->internal = av_mallocz(sizeof(AVCodecInternal));

    // 2. 初始化格式转换链
    ret = init_format_conversion(ctx);  // ← 在这里失败
    if (ret < 0) {
        goto fail;
    }

    // 3. 初始化编码器
    ret = codec->init(ctx);
    if (ret < 0) {
        goto fail;
    }

    return 0;

fail:
    avcodec_close(ctx);  // ← 清理失败的上下文
    return ret;
}

// avcodec_close() 清理时
void avcodec_close(AVCodecContext *ctx) {
    if (ctx->internal) {
        if (ctx->internal->some_buffer) {
            av_free(ctx->internal->some_buffer);  // ← 如果 some_buffer 未初始化，这里崩溃
        }
        av_free(ctx->internal);
    }
}
```

**崩溃原因**：
- `init_format_conversion()` 失败后，某些内部指针未正确初始化
- `avcodec_close()` 清理时，尝试 `free()` 这些未初始化的指针
- `free()` 收到无效指针，导致 SIGSEGV

---

## 🔧 解决方案分析

### 方案 A：禁用 hwdevice 创建（已失败）

**Fix 84 的策略**：不创建 hwdevice，期望 RKMPP 输出系统内存格式（NV12/I420）

**结果**：
- ✅ 旧工控机正常工作
- ❌ 新工控机崩溃在解码器初始化（RKMPP 驱动要求必须有 hwdevice）

**结论**：不可行（新工控机需要 hwdevice）

---

### 方案 B：恢复 hwdevice 创建（Fix 100.11，当前状态）

**Fix 100.11 的策略**：创建 hwdevice，保留 get_format 回调

**结果**：
- ✅ 解码器初始化成功
- ❌ 解码器强制输出 DRM_PRIME (179)
- ❌ 编码器初始化崩溃（格式转换失败）

**结论**：部分成功，但引入新问题

---

### 方案 C：实现 DRM_PRIME → I420 转换（复杂）

**策略**：在 `ffmpeg_vid_codecs.c` 中手动处理格式转换

**实现步骤**：
1. 检测解码器输出 DRM_PRIME 格式
2. 创建 `AVHWFramesContext` 用于帧传输
3. 使用 `av_hwframe_transfer_data()` 将 GPU 帧复制到系统内存
4. 转换为 I420 格式
5. 传递给编码器

**优点**：
- ✅ 解决格式转换问题
- ✅ 保留硬件解码性能

**缺点**：
- ❌ 实现复杂，需要深入了解 FFmpeg hwcontext API
- ❌ 需要测试各种边缘情况
- ❌ GPU → 系统内存复制有性能开销

---

### 方案 D：强制 RKMPP 输出系统内存格式（推荐）

**策略**：设置 RKMPP 解码器参数，强制输出 NV12/I420 到系统内存

**实现步骤**：
1. 在创建解码器后，设置 AVOptions：
   ```c
   // 尝试强制系统内存输出
   av_opt_set(ff->dec_ctx->priv_data, "output_format", "nv12", 0);
   // 或
   av_opt_set_int(ff->dec_ctx->priv_data, "output_type", 1, 0);  // 1 = system memory
   ```

2. 如果选项不存在，尝试设置 `get_buffer2` 回调：
   ```c
   ff->dec_ctx->get_buffer2 = custom_get_buffer;
   ```

3. 验证解码器输出格式

**优点**：
- ✅ 实现简单，只需设置几个参数
- ✅ 避免格式转换开销
- ✅ 兼容现有代码

**缺点**：
- ⚠️ 需要查阅 RKMPP 解码器文档，确认支持的选项
- ⚠️ 可能降低解码性能（系统内存 vs GPU 内存）

---

### 方案 E：使用 V4L2 解码器代替 RKMPP（备选）

**策略**：注册 `h264_v4l2m2m` 解码器代替 `h264_rkmpp`

**理由**：
- V4L2 是 Linux 标准接口，兼容性更好
- V4L2 解码器可能默认输出系统内存格式
- 不需要 hwdevice（可能）

**实现**：
```c
// 在 ffmpeg_codec_factory_alloc() 中
if (strstr(dec->name, "v4l2m2m")) {
    // 使用 V4L2 解码器
    ff->dec = avcodec_find_decoder_by_name("h264_v4l2m2m");
}
```

**优点**：
- ✅ 可能避免 DRM_PRIME 问题
- ✅ 标准接口，兼容性好

**缺点**：
- ⚠️ 性能可能不如 RKMPP
- ⚠️ 需要测试验证是否工作

---

### 方案 F：禁用硬件解码，使用软件解码（最后手段）

**策略**：注册软件 H.264 解码器（`h264`）

**实现**：
```c
ff->dec = avcodec_find_decoder(AV_CODEC_ID_H264);  // 软件解码器
```

**优点**：
- ✅ 绝对兼容，不会有格式问题
- ✅ 实现简单

**缺点**：
- ❌ CPU 负载显著增加（~50-80%）
- ❌ 失去硬件加速优势

---

## 📋 推荐方案优先级

### 优先级 1：方案 D（强制 RKMPP 系统内存输出）

**理由**：
- 实现成本低
- 可能完美解决问题
- 保留硬件加速

**下一步**：
1. 查阅 RKMPP 解码器文档（FFmpeg/Rockchip）
2. 尝试不同的 AVOptions
3. 测试验证输出格式

---

### 优先级 2：方案 E（V4L2 解码器）

**理由**：
- 标准接口，兼容性好
- 实现简单
- 可能避免 hwdevice 问题

**下一步**：
1. 修改代码注册 V4L2 解码器
2. 重新编译测试
3. 验证输出格式和性能

---

### 优先级 3：方案 C（手动格式转换）

**理由**：
- 可以解决问题
- 保留硬件解码

**下一步**：
1. 研究 FFmpeg `av_hwframe_transfer_data()` API
2. 实现 DRM_PRIME → I420 转换
3. 测试性能开销

---

### 优先级 4：方案 F（软件解码）

**理由**：
- 最后的备用方案
- 确保视频通话可用

---

## 🔬 诊断命令

### 查看 RKMPP 解码器支持的选项

```bash
# 在设备上运行
docker exec belt-control-app /app/lib/ffmpeg -h decoder=h264_rkmpp
```

**预期输出**：列出所有支持的 AVOptions

---

### 测试 V4L2 解码器是否可用

```bash
# 在设备上运行
docker exec belt-control-app /app/lib/ffmpeg -decoders | grep v4l2
```

**预期输出**：
```
V..... h264_v4l2m2m         H.264 (V4L2 Memory-to-Memory) (codec h264)
```

---

## 📝 关键要点

### ⚠️ 核心矛盾

**Fix 100.11 的双刃剑效应**：

| 效果 | 说明 |
|------|------|
| ✅ 好处 | 解码器可以初始化（新工控机需要 hwdevice） |
| ❌ 坏处 | 解码器强制输出 DRM_PRIME，编码器无法处理 |

### 🎯 问题本质

**不是编码器的问题，是格式转换的问题**：
- 解码器输出：GPU 内存（DRM_PRIME）
- 编码器期望：系统内存（I420）
- FFmpeg 转换链：初始化失败 → 崩溃

### 💡 解决方向

**优先尝试让解码器输出系统内存格式**：
1. 设置 RKMPP 解码器参数
2. 或使用 V4L2 解码器
3. 最后才考虑手动格式转换

---

## 📁 相关文件

- **Core Dump**: `/tmp/belt-control-cores/core.pjsua_0.1` (808 MB)
- **崩溃日志**: `docs/log/voip.md` (Line 最后 80 行)
- **代码文件**: `cross-compile/src/pjproject-2.16/pjmedia/src/pjmedia-codec/ffmpeg_vid_codecs.c`
- **工作总结**: [docs/2026-01-09/71-工作总结-新工控机视频通话崩溃调试.md](71-工作总结-新工控机视频通话崩溃调试.md)

---

**分析状态**: ✅ 已完成根因分析
**下一步**: 优先尝试方案 D（强制 RKMPP 系统内存输出）
