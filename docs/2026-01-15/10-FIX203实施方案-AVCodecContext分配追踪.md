# FIX 100.203 实施方案 - AVCodecContext 分配追踪

**时间**: 2026-01-15 21:30（北京时间）
**目的**: 追踪 AVCodecContext 从分配到初始化的完整流程，确定 FFmpeg 是否替换了指针
**原则**: 只添加诊断，不修改功能逻辑

---

## 背景

### FIX 100.202 的最终发现

**根本原因**：
- PJSIP 使用的 AVCodecContext (0x7ee0038130) 从未被 X264_init() 初始化
- priv_data (0x7ee00384f0) 中 `x4->enc` 是 NULL，整个 X264Context 未初始化
- FFmpeg 初始化了 9 个不同的 AVCodecContext，但都不是 PJSIP 使用的那个

**待验证的问题**：
- ❓ FFmpeg 是否在 `avcodec_open2()` 内部替换了 `ff->enc_ctx` 指针？
- ❓ 还是 `ff->enc_ctx` 指针稳定，但 FFmpeg 重新分配了 `priv_data`？
- ❓ 为什么 FFmpeg 会创建 9 个 AVCodecContext 实例？

---

## 诊断策略

### 完整诊断点列表

| 诊断点 | 位置 | 时机 | 目的 |
|-------|------|------|------|
| **DIAG-C** | PJSIP Line 2275 | `avcodec_alloc_context3()` 后 | 记录 PJSIP 分配的原始地址 |
| **DIAG-D** | PJSIP Line 2851 | `avcodec_open2()` 调用前 | 确认调用前地址（应与 DIAG-C 一致）|
| **DIAG-E** | PJSIP Line 2869 | `avcodec_open2()` 返回后立即 | 检测 FFmpeg 是否替换了指针 |
| **DIAG-A** | PJSIP Line 2885 | `avcodec_open2()` 成功后 | 确认最终使用的地址（已存在）|
| **DIAG-5** | FFmpeg libx264.c | `X264_init()` 开头 | 记录 FFmpeg 收到的地址（已存在）|
| **DIAG-6** | FFmpeg libx264.c | `setup_frame()` 第一次编码 | 验证编码时的地址（已存在）|
| **DIAG-B** | PJSIP Line 4462 | `avcodec_send_frame()` 前 | 确认编码前地址（已存在）|

**诊断流程**：
```
DIAG-C (分配) → DIAG-D (打开前) → DIAG-E (打开后) → DIAG-A (成功) → DIAG-5 (初始化) → DIAG-B (编码前) → DIAG-6 (编码)
```

---

## 修改内容

### 修改 1：DIAG-C - avcodec_alloc_context3() 后（Line 2275-2287）

**文件**：`cross-compile/src/pjproject-2.16/pjmedia/src/pjmedia-codec/ffmpeg_vid_codecs.c`

```c
    /* Allocate ffmpeg codec context */
    if (ff->param->dir & PJMEDIA_DIR_ENCODING) {
#if LIBAVCODEC_VER_AT_LEAST(53,20)
        ff->enc_ctx = avcodec_alloc_context3(ff->enc);
#else
        ff->enc_ctx = avcodec_alloc_context();
#endif
        if (ff->enc_ctx == NULL)
            goto on_error;

        /* ✅ 2026-01-15 21:30 [FIX 100.203 DIAG-C] 记录 avcodec_alloc_context3() 分配的地址 */
        PJ_LOG(1,(THIS_FILE, ""));
        PJ_LOG(1,(THIS_FILE, "========================================"));
        PJ_LOG(1,(THIS_FILE, "[FIX 100.203 DIAG-C] AVCodecContext ALLOCATED"));
        PJ_LOG(1,(THIS_FILE, "========================================"));
        PJ_LOG(1,(THIS_FILE, "  ff->enc_ctx: %p", ff->enc_ctx));
        PJ_LOG(1,(THIS_FILE, "  ff->enc_ctx->priv_data: %p", ff->enc_ctx->priv_data));
        PJ_LOG(1,(THIS_FILE, "  ff->enc->name: %s", ff->enc->name));
        PJ_LOG(1,(THIS_FILE, "  🔍 This is the ORIGINAL address allocated by PJSIP"));
        PJ_LOG(1,(THIS_FILE, "[FIX 100.203 DIAG-C] COMPLETE"));
        PJ_LOG(1,(THIS_FILE, "========================================"));
        PJ_LOG(1,(THIS_FILE, ""));
    }
```

**输出示例**：
```
========================================
[FIX 100.203 DIAG-C] AVCodecContext ALLOCATED
========================================
  ff->enc_ctx: 0x7ee0038130
  ff->enc_ctx->priv_data: 0x7ee00384f0
  ff->enc->name: libx264
  🔍 This is the ORIGINAL address allocated by PJSIP
[FIX 100.203 DIAG-C] COMPLETE
========================================
```

---

### 修改 2：DIAG-D - avcodec_open2() 调用前（Line 2851-2861）

**文件**：`cross-compile/src/pjproject-2.16/pjmedia/src/pjmedia-codec/ffmpeg_vid_codecs.c`

```c
        /* ✅ 2026-01-15 21:35 [FIX 100.203 DIAG-D] 记录 avcodec_open2() 调用前的地址 */
        PJ_LOG(1,(THIS_FILE, ""));
        PJ_LOG(1,(THIS_FILE, "========================================"));
        PJ_LOG(1,(THIS_FILE, "[FIX 100.203 DIAG-D] BEFORE avcodec_open2()"));
        PJ_LOG(1,(THIS_FILE, "========================================"));
        PJ_LOG(1,(THIS_FILE, "  ff->enc_ctx: %p", ff->enc_ctx));
        PJ_LOG(1,(THIS_FILE, "  ff->enc_ctx->priv_data: %p", ff->enc_ctx->priv_data));
        PJ_LOG(1,(THIS_FILE, "  🔍 About to call avcodec_open2() - will FFmpeg replace this?"));
        PJ_LOG(1,(THIS_FILE, "[FIX 100.203 DIAG-D] COMPLETE"));
        PJ_LOG(1,(THIS_FILE, "========================================"));
        PJ_LOG(1,(THIS_FILE, ""));

        PJ_LOG(3,(THIS_FILE, "🔍 [DEBUG] Calling AVCODEC_OPEN for encoder (no mutex)..."));
        err = AVCODEC_OPEN(ff->enc_ctx, ff->enc);
```

**输出示例**：
```
========================================
[FIX 100.203 DIAG-D] BEFORE avcodec_open2()
========================================
  ff->enc_ctx: 0x7ee0038130
  ff->enc_ctx->priv_data: 0x7ee00384f0
  🔍 About to call avcodec_open2() - will FFmpeg replace this?
[FIX 100.203 DIAG-D] COMPLETE
========================================
```

---

### 修改 3：DIAG-E - avcodec_open2() 返回后立即（Line 2869-2883）

**文件**：`cross-compile/src/pjproject-2.16/pjmedia/src/pjmedia-codec/ffmpeg_vid_codecs.c`

```c
        err = AVCODEC_OPEN(ff->enc_ctx, ff->enc);

        PJ_LOG(3,(THIS_FILE, "🔍 [DEBUG] AVCODEC_OPEN returned with err=%d", err));

        /* ✅ 2026-01-15 21:40 [FIX 100.203 DIAG-E] 记录 avcodec_open2() 返回后立即的地址 */
        PJ_LOG(1,(THIS_FILE, ""));
        PJ_LOG(1,(THIS_FILE, "========================================"));
        PJ_LOG(1,(THIS_FILE, "[FIX 100.203 DIAG-E] AFTER avcodec_open2() (err=%d)", err));
        PJ_LOG(1,(THIS_FILE, "========================================"));
        PJ_LOG(1,(THIS_FILE, "  ff->enc_ctx: %p", ff->enc_ctx));
        if (ff->enc_ctx) {
            PJ_LOG(1,(THIS_FILE, "  ff->enc_ctx->priv_data: %p", ff->enc_ctx->priv_data));
        } else {
            PJ_LOG(1,(THIS_FILE, "  ff->enc_ctx->priv_data: (enc_ctx is NULL)"));
        }
        PJ_LOG(1,(THIS_FILE, "  🔍 Compare with DIAG-D - did FFmpeg replace the pointer?"));
        PJ_LOG(1,(THIS_FILE, "[FIX 100.203 DIAG-E] COMPLETE"));
        PJ_LOG(1,(THIS_FILE, "========================================"));
        PJ_LOG(1,(THIS_FILE, ""));
```

**输出示例**：
```
========================================
[FIX 100.203 DIAG-E] AFTER avcodec_open2() (err=0)
========================================
  ff->enc_ctx: 0x7ee0038130
  ff->enc_ctx->priv_data: 0x7ee00384f0
  🔍 Compare with DIAG-D - did FFmpeg replace the pointer?
[FIX 100.203 DIAG-E] COMPLETE
========================================
```

---

## 编译和测试

### 方法：快速验证（推荐，2-3 分钟）

```powershell
# 只编译 PJSIP，快速部署
.\scripts\2026-01-09\03-quick-verify-pjsip.ps1 188
```

---

## 预期结果分析

### 场景 A：FFmpeg 替换了 enc_ctx 指针（最极端）

**日志示例**：
```
[DIAG-C] enc_ctx: 0x7ee0038130, priv_data: 0x7ee00384f0
[DIAG-D] enc_ctx: 0x7ee0038130, priv_data: 0x7ee00384f0 ✅
[DIAG-E] enc_ctx: 0x7ef062d720, priv_data: 0x7ef062dba0 ❌ 完全不同！
[DIAG-A] enc_ctx: 0x7ef062d720, priv_data: 0x7ef062dba0 ✅
[DIAG-5] avctx:   0x7ef062d720, priv_data: 0x7ef062dba0 ✅
```

**结论**：
- FFmpeg 在 `avcodec_open2()` 内部完全替换了 `enc_ctx` 指针
- PJSIP 的 `ff->enc_ctx` 被 FFmpeg 修改为新地址
- 新地址已被正确初始化

**问题**：
- 为什么第一次编码时使用的是旧地址 (0x7ee0038130)？
- 可能是 PJSIP 缓存了旧指针，或者有多个实例

---

### 场景 B：FFmpeg 只替换了 priv_data（部分替换）

**日志示例**：
```
[DIAG-C] enc_ctx: 0x7ee0038130, priv_data: 0x7ee00384f0
[DIAG-D] enc_ctx: 0x7ee0038130, priv_data: 0x7ee00384f0 ✅
[DIAG-E] enc_ctx: 0x7ee0038130, priv_data: 0x7ef062dba0 ❌ priv_data 变了！
[DIAG-A] enc_ctx: 0x7ee0038130, priv_data: 0x7ef062dba0 ✅
[DIAG-5] avctx:   0x7ee0038130, priv_data: 0x7ef062dba0 ✅
```

**结论**：
- FFmpeg 保留了 `enc_ctx` 指针，但重新分配了 `priv_data`
- `enc_ctx->priv_data` 从旧地址改为新地址
- 新 `priv_data` 已被正确初始化

**问题**：
- 为什么第一次编码时使用的是旧 `priv_data` (0x7ee00384f0)？
- 可能是 PJSIP 或 FFmpeg 有多级缓存

---

### 场景 C：FFmpeg 没有替换任何指针（最可能）⭐

**日志示例**：
```
[DIAG-C] enc_ctx: 0x7ee0038130, priv_data: 0x7ee00384f0
[DIAG-D] enc_ctx: 0x7ee0038130, priv_data: 0x7ee00384f0 ✅
[DIAG-E] enc_ctx: 0x7ee0038130, priv_data: 0x7ee00384f0 ✅ 完全一致！
[DIAG-A] enc_ctx: 0x7ee0038130, priv_data: 0x7ee00384f0 ✅
[DIAG-5] avctx:   0x7ef062d720, priv_data: 0x7ef062dba0 ❌ 完全不同！
```

**结论**：
- FFmpeg 没有替换 PJSIP 的指针
- PJSIP 的 `ff->enc_ctx` 和 `priv_data` 在 `avcodec_open2()` 前后完全一致
- **但是 FFmpeg X264_init() 收到的是另一个不同的 AVCodecContext**

**关键问题**：
- **为什么 FFmpeg 会使用不同的 AVCodecContext？**
- 可能原因：
  1. FFmpeg 内部有多个编解码器实例的池或缓存
  2. PJSIP 注册了多个编码器配置（9 个）
  3. `avcodec_open2()` 内部创建了临时实例用于测试/协商

---

### 场景 D：FFmpeg 创建了多个实例（最复杂）

**日志示例**：
```
[DIAG-C] enc_ctx: 0x7ee0038130, priv_data: 0x7ee00384f0  ← PJSIP 分配
[DIAG-D] enc_ctx: 0x7ee0038130, priv_data: 0x7ee00384f0  ← 调用前
[DIAG-E] enc_ctx: 0x7ee0038130, priv_data: 0x7ee00384f0  ← 调用后（未变）
[DIAG-A] enc_ctx: 0x7ee0038130, priv_data: 0x7ee00384f0  ← PJSIP 看到的

[DIAG-5#1] avctx: 0x7ef062d720, priv_data: 0x7ef062dba0  ← FFmpeg 实例 1
[DIAG-5#2] avctx: 0x7ef2d31ed0, priv_data: 0x7ef2d32350  ← FFmpeg 实例 2
... (共 9 个实例)
```

**结论**：
- PJSIP 的指针稳定（场景 C）
- **但 FFmpeg 在内部创建了 9 个不同的 AVCodecContext**
- 这些实例都被正确初始化，但 PJSIP 没有使用它们

**关键疑问**：
- **FFmpeg 为什么创建 9 个实例？**
- **这 9 个实例是做什么用的？**
- **PJSIP 如何知道使用哪个实例？**

---

## 下一步调查方向

### 如果是场景 C（最可能）

**目标**：理解 FFmpeg 为什么创建多个 AVCodecContext

**方法**：
1. 在 FFmpeg `avcodec_open2()` 源码中添加诊断
2. 追踪 `avcodec_alloc_context3()` 在 FFmpeg 内部的调用
3. 查找 FFmpeg 是否有编解码器池或配置协商机制

**文件**：
- `cross-compile/src/ffmpeg-rockchip-6.0/libavcodec/avcodec.c`
- `cross-compile/src/ffmpeg-rockchip-6.0/libavcodec/options.c`

---

### 如果是场景 A/B（FFmpeg 替换指针）

**目标**：理解为什么第一次编码使用旧指针

**方法**：
1. 在 PJSIP `avcodec_send_frame()` 前检查 `ff->enc_ctx` 地址
2. 查找 PJSIP 是否有多个编码器实例
3. 检查 PJSIP 的编码器暂停/恢复逻辑

---

## 时间估算

| 步骤 | 预计耗时 | 备注 |
|-----|---------|------|
| 修改代码 | ✅ 已完成 | 3 处诊断点 |
| 编译 PJSIP | 30 秒 | 使用快速验证脚本 |
| 部署到设备 | 1 分钟 | rsync + 重启容器 |
| 测试并收集日志 | 1 分钟 | 拨打视频通话 |
| 分析日志 | 5-10 分钟 | 对比所有诊断点 |
| **总计** | **8-13 分钟** | 快速迭代 |

---

## 参考文档

- [docs/2026-01-15/09-FIX202测试结果-确认根本原因.md](09-FIX202测试结果-确认根本原因.md)
- [docs/2026-01-15/08-FIX201问题分析-编码器返回EINVAL.md](08-FIX201问题分析-编码器返回EINVAL.md)
- [docs/2026-01-15/07-FIX200测试结果-找到根本原因.md](07-FIX200测试结果-找到根本原因.md)
- ffmpeg_vid_codecs.c Line 2268: avcodec_alloc_context3()
- ffmpeg_vid_codecs.c Line 2840: AVCODEC_OPEN()
- libx264.c Line 1034: X264_init()


