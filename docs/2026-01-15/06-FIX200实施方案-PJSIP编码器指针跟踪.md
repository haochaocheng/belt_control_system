# FIX 100.200 实施方案 - PJSIP 编码器指针跟踪

**时间**: 2026-01-15 03:40（北京时间）
**目的**: 验证 PJSIP 的 `ff->enc_ctx` 指针在打开后到编码前是否被修改
**原则**: 只添加诊断，不修改功能逻辑

---

## 背景

### FIX 100.199 的关键发现

1. **9 个编码器实例被成功初始化**（X264Context 地址：0x7ef062dba0 ~ 0x7ea84d2150）
2. **第一次编码使用的是未初始化的实例**（X264Context 地址：0x7ef00159f0）
3. **使用的实例不在初始化列表中** → 数组为 NULL → 崩溃

### 需要验证的问题

**核心疑问**：`ff->enc_ctx` 指针在 `avcodec_open2()` 前后是否改变？

**假设 1（70%）**：FFmpeg 内部切换了 priv_data
```c
avcodec_alloc_context3()  → enc_ctx->priv_data = 0x7ef00159f0
avcodec_open2()           → enc_ctx->priv_data = 0x7ef062dba0 ✅ 初始化
avcodec_send_frame()      → enc_ctx->priv_data = 0x7ef00159f0 ❌ 未初始化
```

**假设 2（20%）**：PJSIP 缓存了错误的指针
```c
AVCodecContext *cached_ctx = ff->enc_ctx;  // 0x7ef00159f0
avcodec_open2(ff->enc_ctx, ...);           // ff->enc_ctx 可能改变
avcodec_send_frame(cached_ctx, ...);       // 使用旧缓存 ❌
```

---

## 诊断策略

### DIAG-A：编码器打开后记录地址

**位置**：`ffmpeg_vid_codecs.c` Line 2840（`avcodec_open2()` 之后）

**记录内容**：
1. `ff->enc_ctx` 指针地址
2. `ff->enc_ctx->priv_data` 地址（X264Context）
3. 编码器名称

**目的**：建立基准地址

---

### DIAG-B：第一次编码前验证地址

**位置**：`ffmpeg_vid_codecs.c` Line 4450（`avcodec_send_frame()` 之前）

**记录内容**：
1. `ff->enc_ctx` 指针地址
2. `ff->enc_ctx->priv_data` 地址
3. 对比 DIAG-A 的地址

**目的**：检测地址是否改变

---

## 修改内容

### 修改 1：DIAG-A - 编码器打开后（Line 2844-2857）

**文件**：`cross-compile/src/pjproject-2.16/pjmedia/src/pjmedia-codec/ffmpeg_vid_codecs.c`

```c
        err = AVCODEC_OPEN(ff->enc_ctx, ff->enc);

        PJ_LOG(3,(THIS_FILE, "🔍 [DEBUG] AVCODEC_OPEN returned with err=%d", err));

        /* ✅ 2026-01-15 03:30 [FIX 100.200 DIAG-A] 记录编码器打开后的 AVCodecContext 地址 */
        if (err == 0) {
            PJ_LOG(1,(THIS_FILE, ""));
            PJ_LOG(1,(THIS_FILE, "========================================"));
            PJ_LOG(1,(THIS_FILE, "[FIX 100.200 DIAG-A] Encoder opened successfully"));
            PJ_LOG(1,(THIS_FILE, "========================================"));
            PJ_LOG(1,(THIS_FILE, "  ff->enc_ctx: %p", ff->enc_ctx));
            PJ_LOG(1,(THIS_FILE, "  ff->enc_ctx->priv_data: %p", ff->enc_ctx->priv_data));
            PJ_LOG(1,(THIS_FILE, "  ff->enc->name: %s", ff->enc->name));
            PJ_LOG(1,(THIS_FILE, "  ✅ Recording encoder context address for later comparison"));
            PJ_LOG(1,(THIS_FILE, "[FIX 100.200 DIAG-A] COMPLETE"));
            PJ_LOG(1,(THIS_FILE, "========================================"));
            PJ_LOG(1,(THIS_FILE, ""));
        }
```

**输出示例**：
```
========================================
[FIX 100.200 DIAG-A] Encoder opened successfully
========================================
  ff->enc_ctx: 0x7ef0015630
  ff->enc_ctx->priv_data: 0x7ef00159f0  ← 应该匹配 DIAG-5
  ff->enc->name: libx264
  ✅ Recording encoder context address for later comparison
[FIX 100.200 DIAG-A] COMPLETE
========================================
```

---

### 修改 2：DIAG-B - 第一次编码前（Line 4462-4477）

**文件**：`cross-compile/src/pjproject-2.16/pjmedia/src/pjmedia-codec/ffmpeg_vid_codecs.c`

```c
        /* ✅ 2026-01-15 03:35 [FIX 100.200 DIAG-B] 验证编码器地址是否改变 */
        PJ_LOG(1,(THIS_FILE, ""));
        PJ_LOG(1,(THIS_FILE, "========================================"));
        PJ_LOG(1,(THIS_FILE, "[FIX 100.200 DIAG-B] First encode - verifying encoder context"));
        PJ_LOG(1,(THIS_FILE, "========================================"));
        PJ_LOG(1,(THIS_FILE, "  ff->enc_ctx: %p", ff->enc_ctx));
        PJ_LOG(1,(THIS_FILE, "  ff->enc_ctx->priv_data: %p", ff->enc_ctx->priv_data));
        PJ_LOG(1,(THIS_FILE, "  ff->enc->name: %s", ff->enc->name));
        PJ_LOG(1,(THIS_FILE, ""));
        PJ_LOG(1,(THIS_FILE, "  🔍 Compare with DIAG-A:"));
        PJ_LOG(1,(THIS_FILE, "    - If addresses MATCH → encoder context is stable ✅"));
        PJ_LOG(1,(THIS_FILE, "    - If addresses DIFFER → PJSIP using wrong context ❌"));
        PJ_LOG(1,(THIS_FILE, "[FIX 100.200 DIAG-B] COMPLETE"));
        PJ_LOG(1,(THIS_FILE, "========================================"));
        PJ_LOG(1,(THIS_FILE, ""));

        first_send_frame_call = 0;
```

**输出示例**：
```
========================================
[FIX 100.200 DIAG-B] First encode - verifying encoder context
========================================
  ff->enc_ctx: 0x7ef0015630
  ff->enc_ctx->priv_data: 0x7ef00159f0  ← 应该匹配 DIAG-A
  ff->enc->name: libx264

  🔍 Compare with DIAG-A:
    - If addresses MATCH → encoder context is stable ✅
    - If addresses DIFFER → PJSIP using wrong context ❌
[FIX 100.200 DIAG-B] COMPLETE
========================================
```

---

## 编译和测试

### 方法 1：快速验证（推荐，2-3 分钟）⭐

```powershell
# 使用快速验证脚本（只编译 PJSIP，不编译应用）
.\scripts\2026-01-09\03-quick-verify-pjsip.ps1 188
```

**优点**：
- 只编译 PJSIP（30 秒）
- 不重新编译应用和 Docker 镜像
- 快速迭代测试

---

### 方法 2：完整编译（如需要其他修改，约 15 分钟）

```powershell
.\build-ubuntu24-apt.ps1 188
```

---

## 预期结果分析

### 场景 A：地址匹配（DIAG-A == DIAG-B）

**日志示例**：
```
[FIX 100.200 DIAG-A] ff->enc_ctx: 0x7ef0015630, priv_data: 0x7ef00159f0
[FIX 100.200 DIAG-B] ff->enc_ctx: 0x7ef0015630, priv_data: 0x7ef00159f0 ✅
```

**结论**：
- PJSIP 指针稳定，没有被修改
- **问题在 FFmpeg 内部**（假设 1 成立）
- FFmpeg 在 `avcodec_open2()` 时重新分配了 priv_data，但外层 AVCodecContext 没有更新？

**下一步**：
1. 检查 FFmpeg `avcodec_open2()` 源码，查找 priv_data 分配逻辑
2. 或者使用防御性修复（在 libx264.c 中检测未初始化实例）

---

### 场景 B：地址不匹配（DIAG-A != DIAG-B）

**日志示例**：
```
[FIX 100.200 DIAG-A] ff->enc_ctx: 0x7ef062d720, priv_data: 0x7ef062dba0 ✅
[FIX 100.200 DIAG-B] ff->enc_ctx: 0x7ef0015630, priv_data: 0x7ef00159f0 ❌
```

**结论**：
- **PJSIP 使用了错误的 AVCodecContext 指针**（假设 2 成立）
- 可能在暂停/恢复、多线程、或缓存中使用了旧指针

**下一步**：
1. 搜索 PJSIP 代码中所有 `ff->enc_ctx` 的使用
2. 检查是否有多个 AVCodecContext 实例
3. 修复 PJSIP 指针管理逻辑

---

### 场景 C：DIAG-A 地址就不匹配 FFmpeg DIAG-5

**日志示例**：
```
[FIX 100.199 DIAG-5] X264Context: 0x7ef062dba0  ← FFmpeg 初始化
[FIX 100.200 DIAG-A] priv_data: 0x7ef00159f0   ← PJSIP 记录 ❌ 不匹配
```

**结论**：
- **AVCodecContext 在 `avcodec_open2()` 调用后立即被替换**
- 可能是 FFmpeg 内部机制或 PJSIP 有隐藏的重新分配

**下一步**：
1. 在 `avcodec_open2()` 调用前也添加诊断（DIAG-A-PRE）
2. 对比调用前后的地址变化

---

## 根据结果的修复方案

### 方案 A：FFmpeg 防御性修复（如果场景 A）

**修改位置**：FFmpeg `libx264.c` Line 551

```c
static int setup_frame(AVCodecContext *ctx, const AVFrame *frame,
                       x264_picture_t **ppic)
{
    X264Context *x4 = ctx->priv_data;

    /* ⚠️ 防御性检查：如果数组是 NULL，重新分配 */
    if (!x4->reordered_opaque || x4->nb_reordered_opaque == 0) {
        av_log(ctx, AV_LOG_WARNING,
               "[FIX 100.200] reordered_opaque array lost, reallocating...\n");

        int delayed_frames = x264_encoder_maximum_delayed_frames(x4->enc);
        x4->nb_reordered_opaque = FFMAX(delayed_frames + 17, 1);
        x4->reordered_opaque = av_calloc(x4->nb_reordered_opaque,
                                        sizeof(*x4->reordered_opaque));
        if (!x4->reordered_opaque) {
            return AVERROR(ENOMEM);
        }
        x4->next_reordered_opaque = 0;
    }

    X264Opaque *opaque = &x4->reordered_opaque[x4->next_reordered_opaque];
    // ... 继续原有逻辑
}
```

**优点**：
- 快速解决崩溃问题
- 不依赖 PJSIP 修改

**缺点**：
- 修改了 FFmpeg 官方源码
- 治标不治本

---

### 方案 B：PJSIP 指针修复（如果场景 B）

**思路**：
1. 找到 PJSIP 中使用错误指针的位置
2. 确保始终使用最新的 `ff->enc_ctx`
3. 或者在编码器打开后保存指针，编码前验证

**具体修改位置**：待确定（根据测试结果）

---

### 方案 C：禁用多实例（临时测试）

**修改位置**：PJSIP 编码器注册代码

**思路**：
- 只注册一个 libx264 编码器（减少到 1 个实例）
- 验证是否解决问题
- 如果解决 → 确认是多实例管理问题

---

## 时间估算

| 步骤 | 预计耗时 | 备注 |
|-----|---------|------|
| 修改代码 | ✅ 已完成 | 2 处诊断点 |
| 编译 PJSIP | 30 秒 | 使用快速验证脚本 |
| 部署到设备 | 1 分钟 | rsync + 重启容器 |
| 测试并收集日志 | 1 分钟 | 拨打视频通话 |
| 分析日志 | 2-5 分钟 | 对比 DIAG-A/B/5/6 |
| **总计** | **5-8 分钟** | 快速迭代 |

---

## 参考文档

- [docs/2026-01-15/05-FIX199测试结果-找到真正根因.md](05-FIX199测试结果-找到真正根因.md)
- [docs/2026-01-15/04-FIX198测试结果-找到真正根因.md](04-FIX198测试结果-找到真正根因.md)
- ffmpeg_vid_codecs.c Line 2840: AVCODEC_OPEN(ff->enc_ctx, ff->enc)
- ffmpeg_vid_codecs.c Line 4450: avcodec_send_frame(ff->enc_ctx, &avframe)
- libx264.c Line 1034: X264_init()
- libx264.c Line 551: setup_frame()

---

## 附录：完整诊断点列表

| 诊断点 | 位置 | 目的 | 状态 |
|-------|------|------|------|
| DIAG-1 | FFmpeg opaque_uninit() | 捕获 NULL 指针崩溃 | ✅ 已实施（FIX 198）|
| DIAG-2 | FFmpeg X264_init() | 验证数组分配成功 | ✅ 已实施（FIX 198）|
| DIAG-3 | FFmpeg setup_frame() | 发现数组为 NULL | ✅ 已实施（FIX 198）|
| DIAG-4 | PJSIP avcodec_send_frame() | 验证 AVFrame 清洁 | ✅ 已实施（FIX 198）|
| DIAG-5 | FFmpeg X264_init() 结束 | 记录初始化地址 | ✅ 已实施（FIX 199）|
| DIAG-6 | FFmpeg setup_frame() | 验证指针完整性 | ✅ 已实施（FIX 199）|
| DIAG-7 | FFmpeg X264_close() | 跟踪清理调用 | ✅ 已实施（FIX 199）|
| **DIAG-A** | **PJSIP 编码器打开后** | **记录 PJSIP 侧地址** | **✅ 本次实施（FIX 200）** |
| **DIAG-B** | **PJSIP 第一次编码前** | **验证地址是否改变** | **✅ 本次实施（FIX 200）** |

**完整诊断链**：
```
DIAG-A (PJSIP 打开后) → DIAG-5 (FFmpeg 初始化) → DIAG-B (PJSIP 编码前) → DIAG-6 (FFmpeg 编码) → DIAG-3 (发现 NULL)
```

**对比目标**：
- DIAG-A.priv_data 应该 == DIAG-5.X264Context ✅
- DIAG-B.priv_data 应该 == DIAG-A.priv_data ✅
- DIAG-B.priv_data 应该 == DIAG-6.X264Context ❌ **实际不匹配！**

