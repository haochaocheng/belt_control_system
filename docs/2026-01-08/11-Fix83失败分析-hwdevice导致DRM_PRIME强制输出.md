# Fix 83 失败分析 - hwdevice 导致 DRM_PRIME 强制输出

**日期**: 2026-01-08 18:00
**状态**: 🔍 **问题分析完成，准备 Fix 84**

---

## 🎯 Fix 83 测试结果

### 关键日志证据

**voip.md Line 734**:
```
⚠️ [FIX 83] Failed to set output_format to NV12 (ret=-1414549496)
   Will use decoder default format (likely DRM_PRIME)
```

**voip.md Line 738, 752**:
```
Decoder output format: 179  ← DRM_PRIME，不是期望的 23 (NV12)
```

**结果**：
- ❌ `av_opt_set(ctx, "output_format", "nv12", 0)` 失败
- ❌ 解码器仍然输出 format 179 (DRM_PRIME)
- ❌ 继续有大量 `codec decode() error: Not found (PJ_ENOTFOUND)` 错误

---

## 🔍 根本原因分析

### 原因 1：RKMPP 解码器不支持 "output_format" 选项

**证据**：
- 错误码 `-1414549496` 表明选项名称无效
- [FFmpeg RKMPP Wiki](https://github.com/nyanmisaka/ffmpeg-rockchip/wiki/Decoder) 显示 RKMPP 解码器选项只有：
  - `deint` - 去隔行
  - `afbc` - AFBC 压缩
  - `fast_parse` - 快速解析
  - `buf_mode` - 缓冲模式
- **没有 "output_format" 选项**

### 原因 2：hwdevice 强制使用 DRM_PRIME 格式

**关键发现**：

**Fix 80 代码**（`ffmpeg_vid_codecs.c` Line 2081）：
```c
ret = av_hwdevice_ctx_create(&ctx->hw_device_ctx, AV_HWDEVICE_TYPE_RKMPP,
                             "/dev/dri/renderD128", NULL, 0);
```

**效果**：
- 创建 `hw_device_ctx` 后，FFmpeg 检测到硬件设备存在
- **自动选择 DRM_PRIME 格式**（GPU 内存表面）
- **跳过 `get_format` 回调**（未给 PJSIP 选择格式的机会）

### 原因 3：`get_format` 回调从未被调用

**证据**：
- voip.md 中没有 `[FIX 49] get_format() called` 日志
- Fix 49 实现的 `pjmedia_ffmpeg_get_format` 回调应该会打印日志
- 日志不存在 → 回调未执行

**Fix 49 回调逻辑**（`ffmpeg_vid_codecs.c` Line 1806-1808）：
```c
// ✅ 优先选择 NV12（PJSIP 支持，RGA3 友好）
if (*p == AV_PIX_FMT_NV12) {
    PJ_LOG(3,(THIS_FILE, "   ✅ Selected NV12 (format=23) - PJSIP supported, RGA3 friendly"));
    return AV_PIX_FMT_NV12;
}
```

**为什么没被调用**：
- FFmpeg 检测到 `ctx->hw_device_ctx` 存在
- 直接使用硬件路径，默认格式 DRM_PRIME
- 不调用 `get_format` 回调

---

## 📊 RKMPP 解码器两种工作模式

### 模式 1：硬件模式（带 hwdevice）

```c
// 创建 hwdevice
av_hwdevice_ctx_create(&ctx->hw_device_ctx, AV_HWDEVICE_TYPE_RKMPP,
                       "/dev/dri/renderD128", NULL, 0);
avcodec_open2(ctx, decoder, NULL);
```

**特性**：
- ✅ 完全硬件加速（VPU 解码 + GPU 内存）
- ✅ 最低 CPU 占用
- ❌ **强制输出 DRM_PRIME 格式**（format 179）
- ❌ RemoteVideoManager 无法访问（GPU 内存，需要 DRM 驱动）
- ❌ `get_format` 回调不被调用

### 模式 2：混合模式（无 hwdevice）

```c
// 不创建 hwdevice
ctx->get_format = pjmedia_ffmpeg_get_format;
avcodec_open2(ctx, decoder, NULL);
```

**特性**：
- ✅ VPU 硬件解码
- ✅ **输出系统内存格式**（NV12/I420）
- ✅ `get_format` 回调正常调用
- ✅ RemoteVideoManager 可以访问
- ⚠️ CPU 占用略高（内存拷贝开销）
- ✅ 仍然比纯软件解码快得多

---

## ✅ Fix 84 解决方案

### 核心思路

**移除 `hw_device_ctx` 创建，使用 RKMPP 混合模式**

- VPU 硬件解码 → 输出到系统内存（NV12）
- `get_format` 回调正常工作 → PJSIP 选择 NV12 格式
- RemoteVideoManager 可以访问系统内存帧

### 代码修改

**文件**: `ffmpeg_vid_codecs.c`
**位置**: Line 2075-2142（Fix 80/82/83 代码区域）

**修改前**（Fix 82/83）：
```c
if (ff->dec && (pj_ansi_strstr(ff->dec->name, "rkmpp") != NULL)) {
    // 创建 hwdevice
    ret = av_hwdevice_ctx_create(&ctx->hw_device_ctx, AV_HWDEVICE_TYPE_RKMPP,
                                 "/dev/dri/renderD128", NULL, 0);

    // Fix 83: 尝试设置输出格式（失败）
    int format_ret = av_opt_set(ctx, "output_format", "nv12", 0);

    dec_err = avcodec_open2(ff->dec_ctx, ff->dec, NULL);
}
```

**修改后**（Fix 84）：
```c
if (ff->dec && (pj_ansi_strstr(ff->dec->name, "rkmpp") != NULL)) {
    PJ_LOG(1,(THIS_FILE, "✅ [FIX 84] Using RKMPP decoder in hybrid mode (VPU decode + system memory output)"));
    PJ_LOG(1,(THIS_FILE, "   Strategy: No hwdevice → get_format callback works → NV12 output"));

    // ❌ 不创建 hwdevice（关键修改）
    // 原因：hwdevice 强制 DRM_PRIME 输出，跳过 get_format 回调
    // 效果：RKMPP 使用混合模式 - VPU 硬件解码 + 系统内存输出

    // ✅ 设置 get_format 回调（让 PJSIP 选择 NV12）
    ctx->get_format = pjmedia_ffmpeg_get_format;

    // ✅ 立即打开解码器
    dec_err = avcodec_open2(ff->dec_ctx, ff->dec, NULL);

    if (dec_err < 0) {
        char errbuf[128];
        av_strerror(dec_err, errbuf, sizeof(errbuf));
        PJ_LOG(1,(THIS_FILE, "❌ [FIX 84] RKMPP decoder open failed: %d (%s)", dec_err, errbuf));
        goto on_error;
    }

    dec_opened = PJ_TRUE;
    PJ_LOG(1,(THIS_FILE, "✅ [FIX 84] RKMPP decoder opened successfully"));
    PJ_LOG(1,(THIS_FILE, "   Decoder output format: %d (expected: 23=NV12 or 0=I420)", ff->dec_ctx->pix_fmt));
    PJ_LOG(1,(THIS_FILE, "   Decoder dimensions: %dx%d", ff->dec_ctx->width, ff->dec_ctx->height));
}
```

---

## 🎯 预期结果

### 成功指标

| 指标 | Fix 83 | Fix 84（预期） |
|------|--------|---------------|
| **hwdevice 创建** | ✅ DRM render node | ❌ **不创建** |
| **解码器模式** | 硬件模式（DRM_PRIME） | **混合模式**（VPU + 系统内存） |
| **get_format 回调** | ❌ 未调用 | ✅ **正常调用** |
| **输出格式** | ❌ 179 (DRM_PRIME) | ✅ **23 (NV12)** |
| **RemoteVideoManager** | ❌ 无法访问 GPU 内存 | ✅ **可以访问系统内存** |
| **解码错误** | ❌ 251 个 PJ_ENOTFOUND | ✅ **0 个** |
| **本机看远端视频** | ❌ 看不到 | ✅ **可以看到** |

### 预期日志输出

```
✅ [FIX 84] Using RKMPP decoder in hybrid mode (VPU decode + system memory output)
   Strategy: No hwdevice → get_format callback works → NV12 output

🔍 [FIX 49] get_format() called, available formats:   ← 新增！
   Format option 0: nv12 (23)
   Format option 1: yuv420p (0)
   ✅ Selected NV12 (format=23) - PJSIP supported, RGA3 friendly

✅ [FIX 84] RKMPP decoder opened successfully
   Decoder output format: 23                           ← 应该是 23 (NV12)！
   Decoder dimensions: 720x480

🎉 双向视频通话正常建立！
   - 对方看到本机视频 ✅
   - 本机看到对方视频 ✅（新修复）
```

---

## 📊 性能影响分析

### CPU 占用预估

| 方案 | 解码方式 | 内存路径 | CPU 占用 |
|------|----------|----------|----------|
| **Fix 82/83**（hwdevice + DRM_PRIME） | VPU 硬件 | GPU 内存 | ~2-3% | ❌ 无法使用 |
| **Fix 84**（无 hwdevice + NV12） | VPU 硬件 | 系统内存 | ~5-8% | ✅ **推荐** |
| **纯软件解码**（h264） | CPU 软件 | 系统内存 | ~25-35% | ⚠️ 备选 |

**结论**：
- Fix 84 CPU 占用略高于纯硬件模式（多 2-5%）
- 但远低于纯软件解码（节省 20-30%）
- **性能足够，兼容性最好**

---

## ⚠️ 风险评估

### 可能的问题

**问题 1**：RKMPP 解码器可能仍然输出 DRM_PRIME
- **症状**：`get_format` 回调被调用，但只提供 DRM_PRIME 选项
- **原因**：RKMPP 驱动配置问题
- **解决**：回退到纯软件解码器（h264）

**问题 2**：性能不足
- **症状**：CPU 占用超过 15%
- **原因**：系统内存拷贝开销过大
- **解决**：优化内存拷贝路径或使用 zero-copy

**问题 3**：解码器打开失败
- **症状**：`avcodec_open2()` 返回错误
- **原因**：RKMPP 需要 hwdevice 才能工作
- **解决**：恢复 hwdevice + 实现 DRM_PRIME → NV12 转换

---

## 🔄 完整视频通话流程（Fix 84 后）

### 编码路径（本机 → 远端）

```
1. 摄像头采集 I420 帧
2. libx264 软件编码器：I420 → H.264 码流
3. PJSIP RTP 打包发送
4. 远端接收解码显示 ✅
```

### 解码路径（远端 → 本机）

```
1. PJSIP RTP 接收 H.264 码流
2. h264_rkmpp 混合解码器：
   - ✅ [FIX 84] 不使用 hwdevice（避免 DRM_PRIME）⚡
   - ✅ [FIX 49] get_format 回调选择 NV12
   - ✅ VPU 硬件解码 → 系统内存 NV12 格式
3. RemoteVideoManager 接收 NV12 帧 ✅
4. Qt/SDL 渲染显示 ✅
```

---

## 📁 相关文件

### 待修改的文件
1. `cross-compile/src/pjproject-2.16/pjmedia/src/pjmedia-codec/ffmpeg_vid_codecs.c`
   - Line 2075-2142: 移除 hwdevice 创建，简化为混合模式

### 相关文档
- [09-修复83-强制RKMPP输出NV12格式.md](09-修复83-强制RKMPP输出NV12格式.md) - Fix 83 失败尝试
- [06-修复82-hwdevice创建后立即打开解码器.md](06-修复82-hwdevice创建后立即打开解码器.md) - Fix 82 消除崩溃
- [02-修复80-软件编码硬件解码完全隔离方案.md](02-修复80-软件编码硬件解码完全隔离方案.md) - Fix 80 DRM render node
- 未来：`12-修复84-移除hwdevice使用混合模式.md` - Fix 84 实施文档

---

## 🚀 下一步

### 立即操作

根据用户要求 **"你只负责修改，我编译"**：

1. ✅ **问题分析已完成**（本文档）
2. ⏳ **等待用户确认 Fix 84 方案**
3. ⏳ **实施 Fix 84 代码修改**
4. ⏳ **用户编译测试 Fix 84**

### 验证要点

测试时检查：
- ✅ 日志中出现 `[FIX 84] Using RKMPP decoder in hybrid mode`
- ✅ 日志中出现 `[FIX 49] get_format() called`
- ✅ `get_format` 选择 NV12：`Selected NV12 (format=23)`
- ✅ `Decoder output format: 23`（不是 179）
- ✅ 无 "codec decode() error" 错误
- ✅ 本机可以看到远端视频画面
- ✅ 远端仍然可以看到本机视频（不回退）
- ✅ CPU 占用低于 15%

---

**文档版本**: v1.0
**创建时间**: 2026-01-08 18:00
**状态**: 🔍 问题分析完成，等待用户确认 Fix 84 方案
