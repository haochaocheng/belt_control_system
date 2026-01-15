# FIX 100.201 问题分析 - 编码器返回 EINVAL 错误

**时间**: 2026-01-15 04:30（北京时间）
**状态**: ❌ 不崩溃，但编码失败（无视频输出）
**错误**: `avcodec_send_frame() returned: -22` (AVERROR(EINVAL) = 无效参数)

---

## 1. 问题症状

### ✅ 不再崩溃
- 应用没有 SIGSEGV (exit code 139)
- 编码器可以处理帧，不会在 `opaque_uninit()` 崩溃

### ❌ 编码失败
```
Line 1894: avcodec_send_frame() returned: -22
Line 1895: ❌ [ENCODE] avcodec_send_frame() failed: -22 (Invalid argument)
Line 1896: Codec encode_begin() error: Codec internal creation error
```

**结果**：
- H264 数据包发送数量为 0
- 对方看不到视频

---

## 2. 根因分析

### 问题 1：FIX 100.201 的日志没有输出

**预期**：应该看到这样的日志
```
[FIX 100.201] X264Context not initialized!
  X264Context address: 0x7ef0015bf0
  reordered_opaque: (nil)
  🔍 Root cause: FFmpeg switched AVCodecContext inside avcodec_open2()
  ⚠️ Performing emergency initialization...
  ✅ Emergency initialization completed
```

**实际**：**完全没有 FIX 100.201 的日志！**

**原因分析**：
1. 使用了 `av_log()` 而不是 `fprintf(stderr, ...)`
2. PJSIP 的日志系统可能没有捕获 FFmpeg 的 `av_log()` 输出
3. 或者 FFmpeg 日志级别过滤了 `AV_LOG_WARNING`

**证据**：
- 之前的 DIAG-1/2/3 诊断都使用 `fprintf(stderr, ...)` 并成功输出
- FIX 100.201 使用 `av_log()` 但没有任何输出

---

### 问题 2：防御性初始化可能没有被触发

**对比地址**：

| 来源 | AVCodecContext | priv_data (X264Context) | reordered_opaque |
|------|----------------|------------------------|------------------|
| DIAG-A (PJSIP 打开后) | 0x7ef0015830 | 0x7ef0015bf0 | ? |
| DIAG-5#9 (FFmpeg 初始化) | 0x7eb44d1240 | 0x7eb44d16c0 | 0x7eb6bd50e0 ✅ |
| DIAG-B (PJSIP 编码时) | 0x7ef0015830 | 0x7ef0015bf0 | ? |

**关键**：
- PJSIP 使用的 priv_data (0x7ef0015bf0) 不在任何 DIAG-5 初始化列表中
- 这意味着 `x4->reordered_opaque` 应该是 NULL
- FIX 100.201 的防御性检查应该被触发

**但是**：
- 没有看到 FIX 100.201 的日志
- 编码器返回 `-22 (EINVAL)`，说明遇到了其他问题

---

### 问题 3：防御性初始化不完整

**FIX 100.201 只分配了 `reordered_opaque` 数组**，但 X264Context 还有其他重要字段需要初始化：

```c
typedef struct X264Context {
    x264_t *enc;                        ← ❌ 未初始化（可能是 NULL）
    x264_picture_t  pic;                ← ❌ 未初始化
    uint8_t        *sei;                ← ❌ 未初始化
    int             sei_size;           ← ❌ 未初始化
    X264Opaque     *reordered_opaque;   ← ✅ FIX 100.201 初始化了
    int             nb_reordered_opaque;← ✅ FIX 100.201 初始化了
    // ... 还有很多其他字段
} X264Context;
```

**关键问题**：
- `x4->enc` 可能是 NULL（x264 编码器实例未创建）
- FIX 100.201 检查了 `if (!x4->enc)` 并返回错误
- 但返回错误可能导致编码器无法工作

**真正的问题**：
- **X264Context 的整个实例都没有被 X264_init() 正确初始化**
- 仅仅分配 `reordered_opaque` 数组是不够的
- 我们需要整个 X264_init() 的初始化逻辑

---

## 3. 为什么 `avcodec_send_frame()` 返回 -22？

`-22 = AVERROR(EINVAL) = 无效参数`

**可能的原因**：

1. **x4->enc 是 NULL**
   - libx264 编码器需要 `x4->enc` 指向有效的 x264_t 实例
   - 如果是 NULL，`avcodec_send_frame()` 会返回 EINVAL

2. **x4->pic 未初始化**
   - `setup_frame()` 使用 `x4->pic` 来构建待编码的图片
   - 如果未初始化，可能导致无效参数

3. **其他 X264Context 字段未初始化**
   - x264 编码器依赖 X264Context 的多个字段
   - 任何关键字段未初始化都可能导致 EINVAL

---

## 4. 正确的修复方案

### 方案 A：完整的防御性初始化（不推荐）❌

**思路**：在 `setup_frame()` 中调用完整的 X264_init() 逻辑

**问题**：
- ❌ X264_init() 需要 AVCodecContext，但此时 ctx 可能状态不对
- ❌ 需要创建 x264_t 实例，但参数从哪里来？
- ❌ 可能导致资源泄漏（重复初始化）
- ❌ 过于复杂，治标不治本

---

### 方案 B：在 PJSIP 中强制使用已初始化的编码器（推荐）⭐

**核心思路**：
- FFmpeg 已经正确初始化了 9 个编码器实例（DIAG-5）
- PJSIP 为什么不使用这些已初始化的实例？
- **强制 PJSIP 使用 FFmpeg 返回的 AVCodecContext**

**修改位置**：PJSIP `ffmpeg_vid_codecs.c`

**修改方案**：

在 `avcodec_open2()` 之后，检查 `ctx->priv_data` 是否改变，如果改变，更新 PJSIP 的引用：

```c
// Line 2840: avcodec_open2() 之后
err = AVCODEC_OPEN(ff->enc_ctx, ff->enc);

/* ✅ 2026-01-15 04:40 [FIX 100.202] 检测并适配 FFmpeg 内部切换的 AVCodecContext */
if (err == 0) {
    AVCodecContext *original_ctx = ff->enc_ctx;
    void *original_priv = original_ctx->priv_data;

    PJ_LOG(1,(THIS_FILE, "[FIX 100.202] Checking if FFmpeg switched AVCodecContext..."));
    PJ_LOG(1,(THIS_FILE, "  Original ctx: %p, priv_data: %p", original_ctx, original_priv));

    /* 检查 priv_data 是否有 reordered_opaque 数组（判断是否初始化）*/
    // 这需要访问 X264Context 内部，可能需要包含 libx264.c 的头文件
    // 或者使用其他方法判断

    /* 如果检测到未初始化，尝试查找正确的实例 */
    // ... 这个方案也很复杂
}
```

**问题**：
- ⚠️ 需要访问 FFmpeg 内部结构（X264Context）
- ⚠️ 不清楚如何找到"正确的"AVCodecContext
- ⚠️ 可能破坏 PJSIP 的编码器管理逻辑

---

### 方案 C：修改 av_log 为 fprintf + 详细诊断（推荐）⭐⭐

**核心思路**：
1. 先确认 FIX 100.201 的防御性检查是否真的被触发
2. 将 `av_log()` 改为 `fprintf(stderr, ...)`，确保日志输出
3. 添加更详细的诊断，检查 `x4->enc` 等关键字段
4. 如果 `x4->enc` 是 NULL，返回更明确的错误信息

**修改内容**：

```c
/* ✅ 2026-01-15 04:45 [FIX 100.202] 改进防御性初始化的诊断和日志 */
if (!x4->reordered_opaque || x4->nb_reordered_opaque == 0) {
    fprintf(stderr, "\n");
    fprintf(stderr, "========================================\n");
    fprintf(stderr, "[FIX 100.202] X264Context NOT initialized!\n");
    fprintf(stderr, "========================================\n");
    fprintf(stderr, "  X264Context (x4): %p\n", (void*)x4);
    fprintf(stderr, "  x4->enc (x264_t*): %p  ", (void*)x4->enc);
    if (!x4->enc) {
        fprintf(stderr, "← ❌ NULL! Encoder not opened!\n");
    } else {
        fprintf(stderr, "← ✅ Valid\n");
    }
    fprintf(stderr, "  x4->reordered_opaque: %p  ← ❌ NULL!\n", (void*)x4->reordered_opaque);
    fprintf(stderr, "  x4->nb_reordered_opaque: %d  ← ❌ Should be > 0\n", x4->nb_reordered_opaque);
    fprintf(stderr, "\n");
    fprintf(stderr, "  🔍 Root cause:\n");
    fprintf(stderr, "    FFmpeg switched AVCodecContext inside avcodec_open2()\n");
    fprintf(stderr, "    PJSIP is using an uninitialized X264Context instance\n");
    fprintf(stderr, "\n");
    fflush(stderr);

    /* 检查 x4->enc 是否有效 */
    if (!x4->enc) {
        fprintf(stderr, "  ❌ FATAL: x4->enc is NULL!\n");
        fprintf(stderr, "     Cannot perform emergency initialization\n");
        fprintf(stderr, "     The entire X264Context was never initialized by X264_init()\n");
        fprintf(stderr, "========================================\n");
        fprintf(stderr, "\n");
        fflush(stderr);
        return AVERROR(EINVAL);  // 返回明确的错误
    }

    fprintf(stderr, "  ⚠️ Performing emergency initialization of reordered_opaque...\n");
    fflush(stderr);

    /* 分配 reordered_opaque 数组 */
    int delayed_frames = x264_encoder_maximum_delayed_frames(x4->enc);
    x4->nb_reordered_opaque = FFMAX(delayed_frames + 17, 1);
    x4->reordered_opaque = av_calloc(x4->nb_reordered_opaque,
                                    sizeof(*x4->reordered_opaque));
    if (!x4->reordered_opaque) {
        fprintf(stderr, "  ❌ ERROR: Memory allocation failed!\n");
        fprintf(stderr, "========================================\n");
        fprintf(stderr, "\n");
        fflush(stderr);
        x4->nb_reordered_opaque = 0;
        return AVERROR(ENOMEM);
    }
    x4->next_reordered_opaque = 0;

    fprintf(stderr, "  ✅ Emergency initialization completed\n");
    fprintf(stderr, "     Array pointer: %p\n", (void*)x4->reordered_opaque);
    fprintf(stderr, "     Array size: %d elements\n", x4->nb_reordered_opaque);
    fprintf(stderr, "  ⚠️ WARNING: Only reordered_opaque was initialized!\n");
    fprintf(stderr, "     Other X264Context fields may still be uninitialized\n");
    fprintf(stderr, "     Encoding may still fail with EINVAL\n");
    fprintf(stderr, "========================================\n");
    fprintf(stderr, "\n");
    fflush(stderr);
}
```

**优点**：
- ✅ 使用 `fprintf(stderr, ...)` 确保日志输出
- ✅ 详细诊断 `x4->enc` 状态
- ✅ 明确告知用户问题和限制
- ✅ 返回明确的错误码

**预期结果**：
- 如果 `x4->enc` 是 NULL → 返回 EINVAL，并输出详细错误
- 如果 `x4->enc` 有效 → 分配数组，但警告其他字段可能未初始化

---

### 方案 D：强制使用硬件编码器（临时方案）

**修改位置**：设备 188 的环境变量

```bash
export USE_HARDWARE_ENCODER=1
```

**优点**：
- ✅ 快速验证是否只有 libx264 有问题
- ✅ 硬件编码器可能不受此问题影响

**缺点**：
- ❌ 硬件编码器可能不稳定（之前的经验）
- ❌ 治标不治本

---

## 5. 推荐行动方案

### 立即实施：FIX 100.202 - 改进诊断日志（方案 C）⭐

**步骤**：

1. **修改 libx264.c**（10 分钟）
   - 将 `av_log()` 改为 `fprintf(stderr, ...)`
   - 添加 `x4->enc` 的检查和详细诊断
   - 如果 `x4->enc` 是 NULL，返回明确错误

2. **增量编译 FFmpeg**（2-5 分钟）
   ```powershell
   .\scripts\2026-01-15\incremental-compile-libx264.ps1
   ```

3. **完整部署测试**（15 分钟）
   ```powershell
   .\build-ubuntu24-apt.ps1 188
   ```

4. **验证诊断**（5 分钟）
   - 拨打视频通话
   - 检查日志是否有 `[FIX 100.202]` 诊断信息
   - 确认 `x4->enc` 的状态（NULL 或有效）

**预计总耗时**：35 分钟

---

### 根据诊断结果的下一步

#### 场景 A：x4->enc 是 NULL

**日志示例**：
```
[FIX 100.202] X264Context NOT initialized!
  x4->enc: (nil)  ← ❌ NULL! Encoder not opened!
  ❌ FATAL: The entire X264Context was never initialized
```

**结论**：整个 X264Context 都未初始化，不仅是 `reordered_opaque`

**解决方案**：
- 无法在 libx264.c 中修复（需要完整的初始化）
- 必须在 PJSIP 中解决（方案 B，但很复杂）
- 或者找到为什么 FFmpeg 会切换 AVCodecContext 的根本原因

---

#### 场景 B：x4->enc 有效，但编码仍失败

**日志示例**：
```
[FIX 100.202] X264Context NOT initialized!
  x4->enc: 0x7ef0015500  ← ✅ Valid
  ✅ Emergency initialization completed
  ⚠️ WARNING: Other X264Context fields may still be uninitialized
```

**结论**：`reordered_opaque` 被成功分配，但其他字段可能有问题

**解决方案**：
- 检查 `x4->pic` 等其他字段的状态
- 可能需要初始化更多字段
- 或者考虑方案 B（PJSIP 侧修复）

---

## 6. 总结

### ✅ FIX 100.201 的成就
- 成功避免了崩溃（不再 SIGSEGV）
- 证明了防御性编程的价值

### ❌ FIX 100.201 的不足
- 只初始化了 `reordered_opaque` 数组
- 其他 X264Context 字段可能未初始化
- 导致编码器返回 EINVAL

### 🎯 下一步
- 实施 FIX 100.202（改进诊断）
- 根据诊断结果确定最终修复方案
- 可能需要在 PJSIP 侧解决（而不是 FFmpeg）

---

## 7. 参考文档

- [docs/2026-01-15/07-FIX200测试结果-找到根本原因.md](07-FIX200测试结果-找到根本原因.md)
- libx264.c Line 548: setup_frame()
- libx264.c Line 1034: X264_init()
- ffmpeg_vid_codecs.c Line 2840: avcodec_open2()

