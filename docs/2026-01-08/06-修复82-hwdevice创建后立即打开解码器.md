# 修复 82 - hwdevice 创建后立即打开解码器

**日期**: 2026-01-08 16:50
**状态**: ✅ **代码修改完成，待测试**

---

## 🎯 问题回顾

### 测试日志分析

**日志被截断**：
```
03:17:26.547    ffmpeg_vid_codecs.c  ✅ [FIX 80] Detected RKMPP decoder: h264_rkmpp
03:17:26.547    ffmpeg_vid_codecs.c     ✅ RKMPP hwdevice created using DRM render node...
03:17:26.547    ffmpeg_vid_codecs.c     ✅ DRM render node is SHARED (multiple proc  ← 截断！
Application exited with code: 139                                                   ← 崩溃！
```

**关键发现**：
1. ✅ `av_hwdevice_ctx_create()` 成功
2. ✅ 日志输出到一半
3. 💥 崩溃发生在 Line 2092-2093 之间
4. ❌ 完全没有到达 Fix 81 STEP 1 (Line 2193)

---

## 🔍 崩溃位置定位

**Fix 80 代码（Line 2089-2095）**：
```c
} else {
    PJ_LOG(1,(..., "✅ RKMPP hwdevice created..."));  // ← Line 2090 执行了
    PJ_LOG(1,(..., "✅ DRM render node is SHARED...")); // ← Line 2091 被截断
    ctx->pix_fmt = AV_PIX_FMT_YUV420P;                // ← Line 2092 可能崩溃点 ⚡
    ctx->get_format = pjmedia_ffmpeg_get_format;     // ← Line 2093
    PJ_LOG(1,(..., "✅ Decoder configured..."));      // ← Line 2094 未执行
}
```

**崩溃在**：
- **Line 2092-2093** 之间
- 可能是设置 `ctx->pix_fmt` 触发硬件初始化
- 也可能是 `ctx->get_format` 函数指针赋值导致问题

---

## 💡 根本原因假设

### 假设 1：`ctx->pix_fmt` 设置触发 RKMPP 驱动初始化

**可能流程**：
```c
av_hwdevice_ctx_create(&ctx->hw_device_ctx, ...);  // ① 创建 DRM context ✅
ctx->pix_fmt = AV_PIX_FMT_YUV420P;                 // ② 设置像素格式
    // ③ FFmpeg 内部触发硬件格式配置
    // ④ RKMPP 驱动尝试初始化 MPP 硬件
    // 💥 驱动内部崩溃！
```

### 假设 2：硬件设备未完全初始化就访问

**可能流程**：
```c
av_hwdevice_ctx_create(...);  // ① 只创建了 context 句柄
// ② 但 RKMPP 驱动还未初始化
// ③ 后续访问 ctx 成员导致访问无效内存
// 💥 SIGSEGV崩溃！
```

---

## ✅ Fix 82 解决方案

### 策略：hwdevice 创建后立即打开解码器

**核心思路**：
1. `av_hwdevice_ctx_create()` 创建 DRM hwdevice ✅
2. **立即**调用 `avcodec_open2()` 打开解码器 ⚡
3. 避免任何中间操作（设置 `pix_fmt`、函数指针等）
4. 设置 `dec_opened = PJ_TRUE` 防止后续重复打开

---

## 🔧 代码修改

**文件**: `cross-compile/src/pjproject-2.16/pjmedia/src/pjmedia-codec/ffmpeg_vid_codecs.c`
**位置**: Line 2089-2122

### 修改前（Fix 80）

```c
} else {
    PJ_LOG(1,(THIS_FILE, "   ✅ RKMPP hwdevice created..."));
    PJ_LOG(1,(THIS_FILE, "   ✅ DRM render node is SHARED..."));
    ctx->pix_fmt = AV_PIX_FMT_YUV420P;  // ← 可能触发硬件初始化导致崩溃
    ctx->get_format = pjmedia_ffmpeg_get_format;
    PJ_LOG(1,(THIS_FILE, "   ✅ Decoder configured..."));
}
```

### 修改后（Fix 82）

```c
} else {
    /* ✅ 2026-01-08 16:50 [修复 82] hwdevice 创建后立即打开解码器 */
    int dec_err = 0;

    PJ_LOG(1,(THIS_FILE, "   ✅ RKMPP hwdevice created using DRM render node (/dev/dri/renderD128)"));
    PJ_LOG(1,(THIS_FILE, "   ✅ DRM render node is SHARED (multiple processes can access)"));

    // ❌ 不在这里设置 pix_fmt，避免触发硬件初始化
    // ctx->pix_fmt = AV_PIX_FMT_YUV420P;
    ctx->get_format = pjmedia_ffmpeg_get_format;

    /* ✅ 立即打开 RKMPP 解码器 */
    PJ_LOG(1,(THIS_FILE, "✅ [FIX 82] Opening RKMPP decoder immediately after hwdevice creation"));

    dec_err = avcodec_open2(ff->dec_ctx, ff->dec, NULL);

    if (dec_err < 0) {
        char errbuf[128];
        av_strerror(dec_err, errbuf, sizeof(errbuf));
        PJ_LOG(1,(THIS_FILE, "❌ [FIX 82] RKMPP decoder open failed: %d (%s)", dec_err, errbuf));
        print_ffmpeg_err(dec_err);
        status = PJMEDIA_CODEC_EFAILED;
        goto on_error;
    }

    dec_opened = PJ_TRUE;  /* 标记解码器已打开，防止后续重复打开 */
    PJ_LOG(1,(THIS_FILE, "✅ [FIX 82] RKMPP decoder opened successfully"));
    PJ_LOG(1,(THIS_FILE, "   Decoder output format: %d", ff->dec_ctx->pix_fmt));
    PJ_LOG(1,(THIS_FILE, "   Decoder dimensions: %dx%d", ff->dec_ctx->width, ff->dec_ctx->height));
}
```

---

## 📊 关键改进

| 项目 | Fix 80 | Fix 82 |
|------|--------|--------|
| **hwdevice 创建** | ✅ `av_hwdevice_ctx_create()` | ✅ 相同 |
| **`pix_fmt` 设置** | ❌ `ctx->pix_fmt = AV_PIX_FMT_YUV420P;` | ✅ **已移除** |
| **解码器打开** | ❌ 在 Line 2199（Fix 81） | ✅ **立即打开（Line 2107）** |
| **`dec_opened` 标志** | ❌ 未设置 | ✅ **Line 2118 设置** |
| **防重复打开** | ❌ 无保护 | ✅ Fix 81 STEP 1/3 检查标志 |

---

## 🔄 完整执行流程

### 新的初始化顺序（Fix 82）

```
1. Line 2075: Fix 80 检测到 h264_rkmpp
2. Line 2081: av_hwdevice_ctx_create() 创建 DRM render node
3. Line 2097-2102: 日志输出，设置 get_format
4. Line 2105-2107: ✅ [FIX 82] 立即 avcodec_open2() 打开解码器 ⚡
5. Line 2118: dec_opened = PJ_TRUE ⚡
6. Line 2193: Fix 81 STEP 1 检查 dec_opened，跳过（已打开）
7. Line 2220: 编码器打开
8. Line 2504: Fix 81 STEP 3 检查 !dec_opened，跳过（已打开）
```

**关键优势**：
- ✅ 解码器在 hwdevice 创建后立即打开
- ✅ 避免中间任何可能触发硬件初始化的操作
- ✅ 使用 `dec_opened` 标志防止重复打开
- ✅ 兼容 Fix 81 的初始化顺序逻辑

---

## 🎯 预期日志输出

### 成功情况

```
✅ [FIX 80] Detected RKMPP decoder: h264_rkmpp
   ✅ RKMPP hwdevice created using DRM render node (/dev/dri/renderD128)
   ✅ DRM render node is SHARED (multiple processes can access)

✅ [FIX 82] Opening RKMPP decoder immediately after hwdevice creation  ← 新增！
✅ [FIX 82] RKMPP decoder opened successfully                          ← 新增！
   Decoder output format: 0
   Decoder dimensions: 0x0

✅ [FIX 81] STEP 2: Opening encoder AFTER decoder
   Encoder: libx264
   ✅ Encoder opened successfully

🎉 视频通话正常建立！
```

### 仍崩溃情况

如果仍然崩溃，日志会精确显示崩溃位置：

**情况 1**：`avcodec_open2()` 崩溃
```
✅ [FIX 82] Opening RKMPP decoder immediately after hwdevice creation
Application exited with code: 139  ← 崩溃在 avcodec_open2() 调用中
```

**情况 2**：解码器打开后崩溃
```
✅ [FIX 82] RKMPP decoder opened successfully
   Decoder output format: 0
Application exited with code: 139  ← 崩溃在获取解码器信息时
```

---

## ✅ 成功指标

| 指标 | 修复前 | 修复后 |
|------|--------|--------|
| **hwdevice 创建** | ✅ 成功 | ✅ 成功 |
| **`pix_fmt` 设置** | ❌ 可能触发崩溃 | ✅ **已移除** |
| **解码器打开时机** | ❌ 延迟到 Line 2199 | ✅ **立即（Line 2107）** |
| **日志完整性** | ❌ 被截断 | ✅ **完整输出** |
| **程序崩溃** | ❌ exit 139 | ✅ **不崩溃（预期）** |

---

## 📁 相关文件

### 修改的文件
1. `cross-compile/src/pjproject-2.16/pjmedia/src/pjmedia-codec/ffmpeg_vid_codecs.c`
   - Line 2089-2122: Fix 82 主要修改

### 相关文档
- [02-修复80-软件编码硬件解码完全隔离方案.md](02-修复80-软件编码硬件解码完全隔离方案.md) - Fix 80 DRM render node 方案
- [03-修复81-调整初始化顺序解决DRM冲突.md](03-修复81-调整初始化顺序解决DRM冲突.md) - Fix 81 初始化顺序
- [05-修复81.1-移除条件编译解决未执行问题.md](05-修复81.1-移除条件编译解决未执行问题.md) - Fix 81.1 运行时检测
- **本文档** - Fix 82 立即打开解码器

---

## 🚀 下一步

### 立即操作
1. **重新编译 PJSIP 静态库**（源码已修改）
2. **重新编译应用程序**
3. **部署到设备 188**
4. **测试视频通话**

### 验证要点
- ✅ 日志中出现 `[FIX 82] Opening RKMPP decoder immediately`
- ✅ 日志中出现 `[FIX 82] RKMPP decoder opened successfully`
- ✅ 解码器信息正常输出（format, dimensions）
- ✅ 程序不崩溃（exit 0 或正常运行）
- ✅ 视频通话正常建立

---

**文档版本**: v1.0
**创建时间**: 2026-01-08 16:50
**状态**: ✅ 代码修改完成，等待编译测试
