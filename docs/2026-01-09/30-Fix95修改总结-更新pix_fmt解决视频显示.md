# Fix 95: 更新 dec_ctx->pix_fmt 解决视频显示问题

**日期**: 2026-01-09 13:45
**版本**: CODE_VERSION 95
**修改文件**: `cross-compile/src/pjproject-2.16/pjmedia/src/pjmedia-codec/ffmpeg_vid_codecs.c`
**状态**: ✅ Fix 94 成功 - 程序不再崩溃 | ❌ 对方视频无法显示

---

## 📊 Fix 94 测试结果

### ✅ 成功部分

1. **程序不再崩溃** 🎉
   - Fix 93 禁用 Encoder 日志 → 延长运行时间
   - Fix 94 禁用 Decoder 日志 → 彻底解决崩溃
   - 运行时间: **20秒+** (之前 1.5-1.8秒)

2. **编码和RTP发送正常**
   - Encoder 成功编码视频帧
   - RTP 发送正常: `[RTP SEND] Encode success`

### ❌ 新问题

**对方视频无法显示** - 所有解码操作返回 `PJ_ENOTFOUND`

---

## 🔍 根本原因分析

### 日志证据 (voip.md)

```
Line 1682: 🔍 [FIX 90] Detected DRM_PRIME in FFmpeg 6.0+ branch
Line 1683:    Original err=0, attempting format conversion...
Line 1684: 🔍 [FIX 76 FORMAT] Decoded frame format: 23 (NV12)  ← 转换成功！
Line 1685: codec decode() error: Not found (PJ_ENOTFOUND)      ← 但返回错误
```

### 代码分析

#### 执行流程

1. **Fix 90 转换成功** (Line 3400-3474):
   ```c
   if (avframe.format == AV_PIX_FMT_DRM_PRIME) {  // 179
       av_hwframe_transfer_data(sw_frame, &avframe, 0);  // DRM_PRIME → NV12
       av_frame_move_ref(&avframe, sw_frame);
       avframe.format = 23;  // ✅ NV12
       err = 0; got_picture = TRUE;
   }
   ```

2. **check_decode_result() 检查格式** (Line 3938-3947):
   ```c
   status = check_decode_result(codec, &input->timestamp, got_keyframe);
   if (status != PJ_SUCCESS) {
       return status;  // ❌ 返回 PJ_ENOTFOUND
   }
   ```

3. **格式不匹配检测** (Line 3220-3231):
   ```c
   if (ff->dec_ctx->pix_fmt != ff->expected_dec_fmt) {
       status = PixelFormat_to_pjmedia_format_id(ff->dec_ctx->pix_fmt, &new_fmt_id);
       if (status != PJ_SUCCESS)
           return status;  // ❌ DRM_PRIME 不是 PJMEDIA 支持的格式
   }
   ```

### 根本原因

| 变量 | Fix 90 前 | Fix 90 后 | 期望 |
|------|-----------|-----------|------|
| `avframe.format` | 179 (DRM_PRIME) | **23 (NV12)** ✅ | 23 |
| `ff->dec_ctx->pix_fmt` | 179 (DRM_PRIME) | **179 (DRM_PRIME)** ❌ | **23** |
| `ff->expected_dec_fmt` | 0 or 23 | 0 or 23 | 23 |

**问题**：
- Fix 90/92 只更新了 `avframe.format`
- **没有更新 `ff->dec_ctx->pix_fmt`**
- `check_decode_result()` 检测到 `179 != 23` → 格式变化
- 尝试将 DRM_PRIME (179) 转换为 PJMEDIA 格式 → **PJ_ENOTFOUND**

---

## 🛠️ Fix 95 修改内容

### 1. 更新版本号 (Line 48-51)

```c
/* ✅ 2026-01-09 13:45 [修复 95] 版本号更新 */
#define CODE_VERSION 95
#define CODE_DATE "2026-01-09 13:45"
#define CODE_DESCRIPTION "Fix 95: Update dec_ctx->pix_fmt after DRM_PRIME conversion"
```

### 2. Fix 90 分支 - 更新 pix_fmt (Line 3463-3470)

**位置**: FFmpeg 6.0+ 分支 (`LIBAVCODEC_VER_AT_LEAST(58,137)`)

```c
// 移动引用（正确的所有权转移）
av_frame_move_ref(&avframe, sw_frame);

// 释放 sw_frame 结构（数据已转移到 avframe）
av_frame_free(&sw_frame);

/* ✅ 2026-01-09 13:45 [修复 95] 更新解码器上下文的像素格式
 * 问题：Fix 90 转换后 avframe.format 是 NV12，但 dec_ctx->pix_fmt 仍是 DRM_PRIME
 * 根因：check_decode_result() 使用 dec_ctx->pix_fmt 检查格式变化
 *       PixelFormat_to_pjmedia_format_id(DRM_PRIME) 返回 PJ_ENOTFOUND
 * 策略：转换成功后立即更新 dec_ctx->pix_fmt = avframe.format (NV12)
 * 效果：check_decode_result() 能正确识别 NV12 格式，视频显示正常
 */
ff->dec_ctx->pix_fmt = avframe.format;  // 更新为 NV12

// ✅ 修正状态：转换成功视为解码成功
err = 0;
got_picture = PJ_TRUE;
```

### 3. Fix 89 分支 - 更新 pix_fmt (Line 3569-3574)

**位置**: FFmpeg 52.72+ 分支 (`LIBAVCODEC_VER_AT_LEAST(52,72)`)

```c
// 移动引用（正确的所有权转移）
av_frame_move_ref(&avframe, sw_frame);

// 释放 sw_frame 结构（数据已转移到 avframe）
av_frame_free(&sw_frame);

/* ✅ 2026-01-09 13:45 [修复 95] 更新解码器上下文的像素格式（同 Fix 90）
 * 问题：Fix 89 转换后 avframe.format 是 NV12，但 dec_ctx->pix_fmt 仍是 DRM_PRIME
 * 根因：check_decode_result() 使用 dec_ctx->pix_fmt 检查格式变化
 * 策略：转换成功后立即更新 dec_ctx->pix_fmt = avframe.format (NV12)
 */
ff->dec_ctx->pix_fmt = avframe.format;  // 更新为 NV12

// ✅ 修正状态：转换成功视为解码成功
err = 0;
got_picture = PJ_TRUE;
```

---

## 📊 修改统计

| 修改类型 | 数量 | 行号 |
|---------|------|------|
| **版本号更新** | 1 | Line 48-51 |
| **Fix 90: 更新 pix_fmt** | 1 | Line 3470 |
| **Fix 89: 更新 pix_fmt** | 1 | Line 3574 |
| **总计** | **3 处修改** | |

---

## 🎯 预期效果

### Fix 修改链

| Fix | 目标 | 结果 | 效果 |
|-----|------|------|------|
| Fix 91 | 处理 EAGAIN | ✅ | 解码器不再返回 BADBITSTREAM |
| Fix 92 | 正确内存管理 | ✅ | 避免悬空指针崩溃 |
| Fix 93 | 禁用 Encoder 日志 | ✅ | 延长运行时间 (15→55帧) |
| Fix 94 | 禁用 Decoder 日志 | ✅ | **彻底解决崩溃** 🎉 |
| **Fix 95** | **更新 dec_ctx->pix_fmt** | **⏳** | **解决视频显示问题** |

### 验证要点

**成功标志**：
1. ✅ 程序不崩溃 (已达成)
2. ✅ 日志中没有 `PJ_ENOTFOUND` 错误 (待验证)
3. ✅ 日志中出现 `[FIX 76 FORMAT] Decoded frame format: 23 (NV12)`
4. ✅ **对方视频正常显示** 📹

**失败标志**：
- ❌ 仍然返回 `codec decode() error: Not found`
- ❌ 对方视频窗口黑屏或无画面

---

## 📝 验证清单

### 编译前验证

- [x] 版本号已更新: CODE_VERSION 95
- [x] Fix 90 已添加 `ff->dec_ctx->pix_fmt = avframe.format`
- [x] Fix 89 已添加 `ff->dec_ctx->pix_fmt = avframe.format`
- [x] Fix 91-94 代码完整保留

### 编译部署

```powershell
# 完整编译和部署
.\build-ubuntu24-apt.ps1 188
```

### 测试步骤

1. **启动程序**
2. **建立视频通话**
3. **观察日志**：
   - ✅ 看到 `[FIX 90] Detected DRM_PRIME`
   - ✅ 看到 `[FIX 76 FORMAT] Decoded frame format: 23 (NV12)`
   - ✅ **没有** `codec decode() error: Not found`
4. **验证视频**：
   - ✅ 对方视频窗口有画面
   - ✅ 画面流畅，无卡顿

---

## 🔗 相关文档

- [28-Fix93崩溃Core-Dump分析.md](./28-Fix93崩溃Core-Dump分析.md) - Core Dump 分析
- [29-Fix94修改总结-禁用Decoder日志.md](./29-Fix94修改总结-禁用Decoder日志.md) - Fix 94 崩溃修复
- [26-Fix92测试崩溃分析报告.md](./26-Fix92测试崩溃分析.md) - Fix 92 测试

---

## 📈 进度总结

### 问题解决进度

| 阶段 | 问题 | 解决方案 | 状态 |
|------|------|---------|------|
| **1** | BADBITSTREAM 错误 | Fix 91: EAGAIN 处理 | ✅ |
| **2** | 程序崩溃 (内存) | Fix 92: av_frame_move_ref() | ✅ |
| **3** | 程序崩溃 (Encoder 日志) | Fix 93: 禁用 Encoder 日志 | ✅ |
| **4** | 程序崩溃 (Decoder 日志) | Fix 94: 禁用 Decoder 日志 | ✅ |
| **5** | 对方视频无法显示 | **Fix 95: 更新 dec_ctx->pix_fmt** | **⏳ 待验证** |

### 历史崩溃时间线

- Fix 92: 崩溃前运行 **~1.5秒** (~15帧)
- Fix 93: 崩溃前运行 **~1.8秒** (~55帧)
- Fix 94: **不再崩溃** ✅ (**20秒+**)
- Fix 95: **期望视频正常显示** 📹

---

**创建时间**: 2026-01-09 13:45
**修改文件**: 1 个 (`ffmpeg_vid_codecs.c`)
**修改行数**: 3 处
**状态**: ✅ 代码修改完成，待编译测试
**优先级**: 🔥 高 - 最后一步，解决视频显示问题
