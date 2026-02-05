# FIX 100.194 - 修复 libx264 初始化崩溃：补全必需字段

**时间**: 2026-01-15 20:00 - 21:00
**版本**: FIX 100.194
**状态**: ✅ 代码已修改，正在编译部署

---

## 📋 问题回顾

### FIX 100.192 失败（第一次尝试）
- **策略**: libx264 完全跳过 h264_preopen() 配置
- **实施**: Line 652 立即返回 PJ_SUCCESS
- **结果**: 崩溃在 `av_buffer_unref()` → `avcodec_open2()`
- **原因**: 未知

### FIX 100.193 失败（第二次尝试）
- **发现**: 日志显示 `pix_fmt=0`（未初始化）
- **假设**: pix_fmt 未设置导致崩溃
- **实施**: 在提前返回前设置 `ctx->pix_fmt = AV_PIX_FMT_YUV420P`
- **结果**: **依然崩溃**
- **日志证据**:
  ```
  Line 1229: Encoder context: pix_fmt=0, bitrate=800000
  Line 1233: gop_size=-1, max_b_frames=-1
  ```

---

## 🔍 根因分析

### 关键发现
分析崩溃日志 Line 1233，发现更多未初始化字段：
- `gop_size=-1` ❌ 未初始化
- `max_b_frames=-1` ❌ 未初始化

### 代码流程梳理

#### 原始代码结构（未使用 libx264 时）
```
h264_preopen() 函数执行顺序:
├─ Line 608-626: 设置 width, height, time_base, framerate
├─ Line 640-652: [FIX 100.193] libx264 检测 → 立即返回 ← 这里提前退出！
├─ Line 655-704: 设置 profile, level, constraint_bits （未执行）
├─ Line 717-761: 设置 AVOptions (slice-max-size, preset, tune)（未执行）
└─ Line 773-784: 设置 gop_size, max_b_frames （未执行！⚠️）
```

#### 问题根源
FIX 100.193 在 Line 652 提前返回，**跳过了 Line 773-784 的关键配置**：

```c
// Line 773-784（未执行！）
int gop_size = (vfd->fps.num * 10) / vfd->fps.denum;
if (gop_size < 25) {
    gop_size = 250;
}
ctx->gop_size = gop_size;
ctx->keyint_min = gop_size / 10;
ctx->max_b_frames = 0;  // RKMPP 不支持 B 帧
```

### 为什么 pix_fmt=0 不是问题？
- `AV_PIX_FMT_YUV420P` 的枚举值**就是 0**（在 FFmpeg 中）
- Line 2355 已经设置了 `ctx->pix_fmt = AV_PIX_FMT_YUV420P`
- 所以 pix_fmt=0 是**正确的值**，不是未初始化

### 真正的问题
- **gop_size=-1**: libx264 无法接受无效的 GOP 大小
- **max_b_frames=-1**: libx264 无法接受无效的 B 帧数量
- 这些未初始化的值导致 `avcodec_open2()` 内部崩溃在 `av_buffer_unref()`

---

## ✅ 解决方案：FIX 100.194

### 修改位置
文件: `cross-compile/src/pjproject-2.16/pjmedia/src/pjmedia-codec/ffmpeg_vid_codecs.c`
函数: `h264_preopen()`
行号: Line 643-680

### 修改前代码（FIX 100.193）
```c
if (is_libx264) {
    PJ_LOG(1, (THIS_FILE, "⭐ [FIX 100.193] libx264 detected: Setting ONLY essential fields"));
    PJ_LOG(1, (THIS_FILE, "   Configured: width=%d, height=%d, framerate=%d/%d",
               ctx->width, ctx->height, ctx->framerate.num, ctx->framerate.den));

    /* ✅ 设置 pix_fmt */
    ctx->pix_fmt = AV_PIX_FMT_YUV420P;
    PJ_LOG(1, (THIS_FILE, "   ✅ pix_fmt = AV_PIX_FMT_YUV420P (I420)"));

    PJ_LOG(1, (THIS_FILE, "   Skipped: profile, level, constraint_bits, AVOptions (ALL)"));
    PJ_LOG(1, (THIS_FILE, "   Strategy: Let avcodec_open2() use libx264 defaults"));

    /* ✅ 立即返回 */
    return PJ_SUCCESS;
}
```

### 修改后代码（FIX 100.194）
```c
if (is_libx264) {
    PJ_LOG(1, (THIS_FILE, "⭐ [FIX 100.194] libx264 detected: Setting ESSENTIAL fields ONLY"));
    PJ_LOG(1, (THIS_FILE, "   Configured: width=%d, height=%d, framerate=%d/%d",
               ctx->width, ctx->height, ctx->framerate.num, ctx->framerate.den));

    /* ✅ 2026-01-15 20:45 [FIX 100.193 - 修复 pix_fmt 未初始化] */
    ctx->pix_fmt = AV_PIX_FMT_YUV420P;  // I420
    PJ_LOG(1, (THIS_FILE, "   ✅ pix_fmt = AV_PIX_FMT_YUV420P (I420)"));

    /* ✅ 2026-01-15 21:00 [FIX 100.194 - 修复 gop_size/max_b_frames 未初始化]
     * 问题：FIX 100.193 提前返回，跳过了 Line 773-784 的 gop_size/max_b_frames 设置
     * 后果：gop_size=-1, max_b_frames=-1 → libx264 初始化崩溃在 av_buffer_unref()
     * 证据：voip.md Line 1233 显示 gop_size=-1, max_b_frames=-1
     * 修复：必须设置这些 libx264 的必需字段
     * 理由：libx264 要求明确的 GOP 设置，否则无法初始化编码器
     */
    int gop_size = (vfd->fps.num * 10) / vfd->fps.denum;  // 10秒关键帧间隔
    if (gop_size < 25) {
        gop_size = 250;  // 最小值：250帧（10秒 @ 25fps）
    }
    ctx->gop_size = gop_size;
    ctx->keyint_min = gop_size / 10;  // 最小关键帧间隔（1秒）
    ctx->max_b_frames = 0;            // 禁用 B 帧（降低延迟）
    PJ_LOG(1, (THIS_FILE, "   ✅ gop_size=%d, keyint_min=%d, max_b_frames=%d",
               ctx->gop_size, ctx->keyint_min, ctx->max_b_frames));

    PJ_LOG(1, (THIS_FILE, "   Skipped: profile, level, constraint_bits, AVOptions (ALL)"));
    PJ_LOG(1, (THIS_FILE, "   Strategy: Let avcodec_open2() use libx264 defaults"));

    /* ✅ 立即返回 */
    return PJ_SUCCESS;
}
```

---

## 📝 修改总结

### libx264 编码器必需字段（FIX 100.194 补全）

| 字段 | 值 | 说明 | 来源 |
|------|-----|------|------|
| `width` | 640 | 视频宽度 | Line 608（已设置） |
| `height` | 480 | 视频高度 | Line 609（已设置） |
| `time_base` | 1/30 | 时间基准 | Line 610-611（已设置） |
| `framerate` | 30/1 | 帧率 | Line 621-622（已设置） |
| `pix_fmt` | 0 (YUV420P) | 像素格式 | ✅ FIX 100.193 补充 |
| `gop_size` | 300 | GOP 大小 | ✅ FIX 100.194 补充 |
| `keyint_min` | 30 | 最小关键帧间隔 | ✅ FIX 100.194 补充 |
| `max_b_frames` | 0 | B 帧数量 | ✅ FIX 100.194 补充 |

### 跳过的字段（交给 libx264 默认处理）
- `profile`: 让 libx264 自动选择（默认 high）
- `level`: 让 libx264 自动选择（根据分辨率）
- `constraint_bits`: 不设置约束位
- **所有 AVOptions**:
  - `slice-max-size`: 不限制 NAL 大小
  - `intra-refresh`: 不设置 PIR
  - `preset`: 不设置预设（默认 medium）
  - `tune`: 不设置调优（默认无）
  - `x264opts`: 不设置任何 x264 选项

---

## 🎯 预期效果

### 修复前（FIX 100.193）
```
13:24:45.558 [DEBUG] Encoder context: pix_fmt=0, bitrate=800000
13:24:45.558 [DEBUG]   gop_size=-1, max_b_frames=-1  ← 未初始化
13:24:45.558 [DEBUG] Calling AVCODEC_OPEN...
Application exited with code: 139 (SIGSEGV)
#0 av_buffer_unref() ← 崩溃
```

### 修复后（FIX 100.194）
```
[预期] ⭐ [FIX 100.194] libx264 detected: Setting ESSENTIAL fields ONLY
[预期]    ✅ pix_fmt = AV_PIX_FMT_YUV420P (I420)
[预期]    ✅ gop_size=300, keyint_min=30, max_b_frames=0
[预期] [DEBUG] Encoder context: pix_fmt=0, bitrate=800000
[预期] [DEBUG]   gop_size=300, max_b_frames=0  ← 已初始化
[预期] [DEBUG] Calling AVCODEC_OPEN...
[预期] ✅ Encoder opened successfully  ← 不再崩溃
```

---

## 🔄 部署状态

### 编译命令
```powershell
.\build-ubuntu24-apt.ps1 192.168.1.192
```

### 编译流程
1. ✅ 检测到 PJSIP 源码已更新
2. ✅ 触发 PJSIP 静态库重新编译
3. ⏳ 正在交叉编译应用程序...
4. ⏳ 待部署到设备 192.168.1.192

### 预期测试步骤
1. 启动应用并登录 SIP 账号
2. 拨打测试电话
3. 观察日志：
   - 应该看到 `[FIX 100.194] libx264 detected`
   - 应该看到 `gop_size=300, max_b_frames=0`
   - 应该看到 `✅ Encoder opened successfully`
   - **不应该**看到 exit code 139

---

## 📚 相关文档

### 本次修复链
1. [52-最终解决方案-软件编码器libx264为唯一可靠方案.md](52-最终解决方案-软件编码器libx264为唯一可靠方案.md)
2. [FIX 100.192] libx264 完全跳过 h264_preopen 配置 → **失败**
3. [FIX 100.193] 补充 pix_fmt 设置 → **失败**
4. **[FIX 100.194] 补充 gop_size/max_b_frames 设置 → 测试中**

### VERSION 历史
- VERSION 155-167: RKMPP 硬件编码器各种修复尝试（全部失败）
- VERSION 168+: 切换到 libx264 软件编码器方案

### 技术背景
- FFmpeg 6.0 API 变化
- libx264 必需参数要求
- h264_preopen() 执行时机问题

---

## ✍️ 修改记录

| 时间 | 修改内容 | 作者 |
|------|----------|------|
| 2026-01-15 20:00 | FIX 100.192: libx264 提前返回策略 | Claude |
| 2026-01-15 20:45 | FIX 100.193: 补充 pix_fmt 设置 | Claude |
| 2026-01-15 21:00 | FIX 100.194: 补充 gop_size/max_b_frames | Claude |
| 2026-01-15 21:05 | 创建本文档记录修改过程 | Claude |

---

**下一步**: 等待编译完成，部署到设备 192.168.1.192 进行测试验证。
