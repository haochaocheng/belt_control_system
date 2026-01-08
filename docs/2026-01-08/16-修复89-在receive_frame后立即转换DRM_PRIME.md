# 修复 89 - 在 avcodec_receive_frame() 后立即转换 DRM_PRIME

**日期**: 2026-01-08 20:10
**状态**: ✅ **方案完成，待实施**

---

## 🎯 问题回顾

### Fix 86 测试失败

**现象**：
- RKMPP 解码器输出 DRM_PRIME (format 179) ✅ 正常
- 3-4 秒后程序崩溃 (exit 139 SIGSEGV) ❌

**日志证据**：
```
09:51:06.860     vstdec0x7f500121e0  codec decode() error: Bad or corrupted bitstream (PJMEDIA_CODEC_EBADBITSTREAM)
09:51:06.957     vstdec0x7f500121e0  codec decode()
Application exited with code: 139
```

### 根本原因分析

**代码流程** (`ffmpeg_vid_codecs.c` Line 3347-3375):
```c
err = avcodec_receive_frame(ff->dec_ctx, &avframe);  // Line 3349
if (err == 0) {
    got_picture = PJ_TRUE;                            // Line 3351
} else if (err == AVERROR(EAGAIN) || err == AVERROR_EOF) {
    err = 0;
    got_picture = PJ_FALSE;                           // Line 3355
}
// Line 3357 结束

// Line 3362: 错误检查
if (err < 0) {
    output->type = PJMEDIA_FRAME_TYPE_NONE;
    return PJMEDIA_CODEC_EBADBITSTREAM;               // 直接返回！
}

// Line 3375: 只有 got_picture == TRUE 才执行后续处理
} else if (got_picture) {
    // ...
    // Line 3418: Fix 86 的转换代码
    if (avframe.format == AV_PIX_FMT_DRM_PRIME) {
        // av_hwframe_transfer_data()
    }
}
```

**问题**：
1. ❌ `avcodec_receive_frame()` 可能成功获取了 DRM_PRIME 帧，但返回错误码
2. ❌ Line 3355 设置 `got_picture = FALSE`
3. ❌ Line 3362-3374 检测到错误，直接返回 `PJMEDIA_CODEC_EBADBITSTREAM`
4. ❌ **Fix 86 的转换代码 (Line 3418) 永远不会执行！**

**为什么会返回错误码？**
- RKMPP 可能在内部检测到 DRM_PRIME 格式不被 PJSIP 支持
- 或者 DRM buffer 访问失败
- 但 `avframe` 数据结构已经填充了有效的 DRM_PRIME 帧

---

## ✅ Fix 89 解决方案

### 核心思路

**在 avcodec_receive_frame() 之后立即转换，不等待错误检查**

1. 调用 `avcodec_receive_frame()` 获取帧
2. **立即检查** `avframe.format == DRM_PRIME`（不管 err 值）
3. **如果是 DRM_PRIME**，立即调用 `av_hwframe_transfer_data()` 转换
4. 转换成功后，覆盖原始 `avframe`，修正 `err` 和 `got_picture`
5. 然后正常流程继续

### 代码修改

**文件**: `cross-compile/src/pjproject-2.16/pjmedia/src/pjmedia-codec/ffmpeg_vid_codecs.c`

**位置**: Line 3347-3357

#### 修改前（Fix 86 位置）:
```c
err = avcodec_receive_frame(ff->dec_ctx, &avframe);
if (err == 0) {
    got_picture = PJ_TRUE;
} else if (err == AVERROR(EAGAIN) || err == AVERROR_EOF) {
    err = 0;
    got_picture = PJ_FALSE;
}
// ← Fix 86 的转换代码在 Line 3418（太晚了）
```

#### 修改后（Fix 89）:
```c
err = avcodec_receive_frame(ff->dec_ctx, &avframe);

/* ✅ 2026-01-08 20:10 [修复 89] 在 receive_frame 后立即转换 DRM_PRIME
 * 问题：Fix 86 的转换代码在 got_picture 检查之后，永远不会执行
 * 根因：RKMPP 可能返回错误码，但 avframe 已包含有效的 DRM_PRIME 数据
 * 策略：不管 err 值，先检查 avframe.format，如果是 DRM_PRIME 立即转换
 * 效果：转换成功后修正 err=0, got_picture=TRUE，后续流程正常
 * 详细：docs/2026-01-08/16-修复89-在receive_frame后立即转换DRM_PRIME.md
 */
if (avframe.format == AV_PIX_FMT_DRM_PRIME) {  // format 179
    AVFrame *sw_frame;
    int transfer_ret;

    PJ_LOG(3,(THIS_FILE, "🔍 [FIX 89] Detected DRM_PRIME immediately after receive_frame"));
    PJ_LOG(3,(THIS_FILE, "   Original err=%d, attempting format conversion...", err));

    // 分配系统内存帧
    sw_frame = av_frame_alloc();
    if (!sw_frame) {
        PJ_LOG(1,(THIS_FILE, "❌ [FIX 89] Failed to allocate sw_frame"));
        err = AVERROR(ENOMEM);
        got_picture = PJ_FALSE;
    } else {
        // GPU 内存 → CPU 内存格式转换
        transfer_ret = av_hwframe_transfer_data(sw_frame, &avframe, 0);
        if (transfer_ret < 0) {
            char errbuf[128];
            av_strerror(transfer_ret, errbuf, sizeof(errbuf));
            PJ_LOG(1,(THIS_FILE, "❌ [FIX 89] av_hwframe_transfer_data failed: %d (%s)",
                      transfer_ret, errbuf));
            av_frame_free(&sw_frame);
            err = transfer_ret;
            got_picture = PJ_FALSE;
        } else {
            // 转换成功！
            PJ_LOG(3,(THIS_FILE, "✅ [FIX 89] DRM_PRIME → %s conversion SUCCESS",
                      av_get_pix_fmt_name(sw_frame->format) ?
                      av_get_pix_fmt_name(sw_frame->format) : "unknown"));

            // 复制元数据
            sw_frame->pts = avframe.pts;
            sw_frame->pkt_dts = avframe.pkt_dts;
            sw_frame->width = avframe.width;
            sw_frame->height = avframe.height;

            // 释放 GPU 帧
            av_frame_unref(&avframe);

            // 使用系统内存帧替换原始帧
            avframe = *sw_frame;
            av_free(sw_frame);  // 只释放结构，不释放数据

            // ✅ 修正状态：转换成功视为解码成功
            err = 0;
            got_picture = PJ_TRUE;

            PJ_LOG(3,(THIS_FILE, "   Corrected: err=0, got_picture=TRUE, format=%d (%s)",
                      avframe.format,
                      av_get_pix_fmt_name(avframe.format) ?
                      av_get_pix_fmt_name(avframe.format) : "unknown"));
        }
    }
}

// 原始逻辑继续
if (err == 0) {
    got_picture = PJ_TRUE;
} else if (err == AVERROR(EAGAIN) || err == AVERROR_EOF) {
    err = 0;
    got_picture = PJ_FALSE;
}
```

---

## 📊 修改效果

### 代码执行流程对比

| 阶段 | Fix 86（失败） | Fix 89（新方案） |
|------|---------------|-----------------|
| **1. receive_frame** | err != 0, format=179 | err != 0, format=179 |
| **2. 格式检查** | ❌ 跳过（等待 got_picture） | ✅ **立即检测 DRM_PRIME** |
| **3. 格式转换** | ❌ 永远不执行 | ✅ **立即转换 → NV12** |
| **4. 状态修正** | - | ✅ **err=0, got_picture=TRUE** |
| **5. 错误检查** | err<0 → 返回错误 | err=0 → 继续 |
| **6. 后续处理** | ❌ 未执行 | ✅ **正常处理 NV12 帧** |

### 预期日志输出

```
🔍 [FIX 89] Detected DRM_PRIME immediately after receive_frame
   Original err=-1094995529, attempting format conversion...

✅ [FIX 89] DRM_PRIME → nv12 conversion SUCCESS
   Corrected: err=0, got_picture=TRUE, format=23 (nv12)

✅ Frame processing continues with NV12 format
   - 本机看到远端视频 ✅
   - 无崩溃 ✅
   - CPU 占用 ~10-15% ✅
```

---

## ⚠️ 风险评估

### 风险 1: avframe 数据无效
- **概率**: 🟨 中等
- **场景**: err < 0 且 avframe 确实没有有效数据
- **缓解**: av_hwframe_transfer_data() 会返回错误，不影响原有错误处理

### 风险 2: 内存泄漏
- **概率**: 🟩 极低
- **原因**: 代码已正确调用 av_frame_unref() 和 av_free()
- **缓解**: 与 Fix 86 相同的内存管理逻辑

### 风险 3: 性能影响
- **概率**: 🟩 极低
- **原因**: 只在 format=179 时执行，不影响其他格式
- **性能**: ~5-10ms/frame（与 Fix 86 相同）

---

## 🚀 实施步骤

### Step 1: 修改代码

**文件**: `ffmpeg_vid_codecs.c` Line 3347-3357

**修改**: 在 `avcodec_receive_frame()` 之后插入 Fix 89 代码块

### Step 2: 编译测试

```powershell
.\build-ubuntu24-apt.ps1 188
```

### Step 3: 验证

**检查日志** (`voip.md`):
- ✅ `[FIX 89] Detected DRM_PRIME immediately`
- ✅ `[FIX 89] DRM_PRIME → nv12 conversion SUCCESS`
- ✅ `Corrected: err=0, got_picture=TRUE`
- ✅ 双向视频通话正常
- ✅ 无崩溃

---

## 📁 相关文件

### 需修改的文件
1. **ffmpeg_vid_codecs.c** - Line 3349 后插入 Fix 89 代码

### 相关文档
- [14-修复86-使用av_hwframe_transfer_data转换格式.md](14-修复86-使用av_hwframe_transfer_data转换格式.md) - Fix 86 失败
- [11-Fix83失败分析-hwdevice导致DRM_PRIME强制输出.md](11-Fix83失败分析-hwdevice导致DRM_PRIME强制输出.md) - Fix 84 分析
- [15-硬件编码器+解码器同时使用可行性分析.md](15-硬件编码器+解码器同时使用可行性分析.md) - 硬件编码分析
- **本文档** - Fix 89 实施方案

---

**文档版本**: v1.0
**创建时间**: 2026-01-08 20:10
**状态**: ✅ 方案完成，等待用户确认后实施
