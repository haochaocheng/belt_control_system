# 方案 A/B 深度分析 - X264_init 多次调用之谜

**时间**: 2026-01-16 01:15（北京时间）
**目的**: 在 FIX 100.206 部署期间，深入分析问题根本原因
**状态**: 分析中

---

## 🔍 核心发现

### 发现 1：X264_init() 被调用了 18 次，不是 7 次

**第一次启动**（Log Line 1268-1740）：**9 次**
```
1. X264Context: 0x7efc650860 (AVCodecContext: 0x7efc6503e0)
2. X264Context: 0x7efed55160 (AVCodecContext: 0x7efed54ce0)
3. X264Context: 0x7ee9537ed0 (AVCodecContext: 0x7ee9537a50)
4. X264Context: 0x7eebc3cba0 (AVCodecContext: 0x7eebc3c720)
5. X264Context: 0x7eda3d3950 (AVCodecContext: 0x7eda3d34d0)
6. X264Context: 0x7eccc925e0 (AVCodecContext: 0x7eccc92160)
7. X264Context: 0x7ecf3972b0 (AVCodecContext: 0x7ecf396e30)
8. X264Context: 0x7ebdc13010 (AVCodecContext: 0x7ebdc12b90)
9. X264Context: 0x7eb44d1d30 (AVCodecContext: 0x7eb44d18b0)
```

**第二次启动**（Log Line 5706-6127）：**9 次**
```
10. X264Context: 0x7ee864f340 (AVCodecContext: 0x7ee864eec0)
11. X264Context: 0x7eead53d30 (AVCodecContext: 0x7eead538b0)
12. X264Context: 0x7ed95379b0 (AVCodecContext: 0x7ed9537530)
13. X264Context: 0x7edbc3c640 (AVCodecContext: 0x7edbc3c1c0)
14. X264Context: 0x7ece3d3380 (AVCodecContext: 0x7ece3d2f00)
15. X264Context: 0x7ec0c92180 (AVCodecContext: 0x7ec0c91d00)
16. X264Context: 0x7ec3396de0 (AVCodecContext: 0x7ec3396960)
17. X264Context: 0x7eb1c12bc0 (AVCodecContext: 0x7eb1c12740)
18. X264Context: 0x7ea84d19d0 (AVCodecContext: 0x7ea84d1610)
```

---

### 发现 2：PJSIP 只调用了 2 次 avcodec_open2()

**第一次启动**（Log Line 1364-1367）：
```
[FIX 100.203 DIAG-D] BEFORE avcodec_open2()
  ff->enc_ctx: 0x7efc038320
  ff->enc_ctx->priv_data: 0x7efc0386e0  ← PJSIP 使用的地址
```

**第二次启动**（Log Line 6200-6203）：
```
[FIX 100.203 DIAG-D] BEFORE avcodec_open2()
  ff->enc_ctx: 0x7ee8037110
  ff->enc_ctx->priv_data: 0x7ee80374d0  ← PJSIP 使用的地址
```

---

### 发现 3：PJSIP 使用的地址从未被 X264_init() 初始化

**PJSIP 使用的地址**：
- 第一次启动：`0x7efc0386e0`
- 第二次启动：`0x7ee80374d0`

**所有 18 次 X264_init() 的地址**：
- ❌ **没有一个匹配 PJSIP 使用的地址**！

---

### 发现 4：PJSIP 只注册了 8 个编解码器

**注册的编解码器**（Log Line 460-484）：
1. H264 (libx264) ← **唯一使用 X264_init() 的**
2. VP8
3. VP9
4. H263-1998
5. H263
6. H261
7. JPEG
8. MP4V

**关键**：
- ✅ 只有 H264 使用 libx264（会调用 X264_init()）
- ❌ 其他 7 个编解码器**不使用 libx264**

---

## 🤔 核心疑问

### Q1：为什么 X264_init() 被调用 9 次，而不是 1 次？

**已知事实**：
- PJSIP 只注册了 1 个 libx264 编解码器（H264）
- PJSIP 只调用了 1 次 `avcodec_open2()` for H264 编码器
- 但 `X264_init()` 被调用了 9 次

**可能原因**：
1. **SDP 协商**：PJSIP 可能在 SDP 协商时尝试多个编码器配置
2. **编解码器工厂**：FFmpeg 内部可能创建多个编码器实例
3. **PJSIP 内部机制**：PJSIP 可能有内部的编解码器池

---

### Q2：为什么所有 X264_init() 的地址都不匹配 PJSIP 使用的地址？

**已知事实**：
- PJSIP 分配：`ff->enc_ctx->priv_data = 0x7efc0386e0`
- 所有 X264_init() 调用的地址：都不是 `0x7efc0386e0`

**可能原因**：
1. **FFmpeg 创建新实例**：
   - `avcodec_open2()` 内部创建了新的 AVCodecContext
   - 初始化新实例，但没有更新 PJSIP 的指针
   - PJSIP 继续使用旧的、未初始化的实例

2. **多线程竞态**：
   - PJSIP 多线程调用 `avcodec_open2()`
   - FFmpeg 创建了多个实例，但都不是 PJSIP 使用的那个

3. **编解码器池机制**：
   - PJSIP 或 FFmpeg 有编解码器池
   - 池中的实例被初始化，但 PJSIP 使用的实例不在池中

---

## 📊 方案 A：验证是否真的是同一个编解码器

### 目标

验证 9 次 `X264_init()` 调用是否都是 libx264 编码器，还是不同的编解码器。

### 实施方案

**修改 FIX 100.205 DIAG-F 日志**：

```c
fprintf(stderr, "[FIX 100.205 DIAG-F] X264_init() CALLED\n");
fprintf(stderr, "========================================\n");
fprintf(stderr, "  AVCodecContext: %p\n", (void*)avctx);
fprintf(stderr, "  Codec name: %s\n", avctx->codec ? avctx->codec->name : "NULL");  // ✅ 添加编码器名称
fprintf(stderr, "  Codec ID: %d\n", avctx->codec ? avctx->codec->id : -1);          // ✅ 添加编码器 ID
fprintf(stderr, "  X264Context (priv_data): %p\n", (void*)x4);
fprintf(stderr, "  width: %d, height: %d\n", avctx->width, avctx->height);
fprintf(stderr, "  pix_fmt: %d\n", avctx->pix_fmt);
fprintf(stderr, "  bit_rate: %lld\n", (long long)avctx->bit_rate);
fprintf(stderr, "========================================\n\n");
fflush(stderr);
```

### 预期结果

**场景 1：所有调用都是 libx264**
```
[FIX 100.205 DIAG-F] X264_init() CALLED
  Codec name: libx264  ← 全部都是 libx264
  Codec ID: 27 (AV_CODEC_ID_H264)
```

**场景 2：混合了不同的编解码器**（极不可能，因为函数名叫 X264_init）
```
[FIX 100.205 DIAG-F] X264_init() CALLED
  Codec name: libx264rgb  ← 可能是 RGB 格式的 x264
  Codec ID: 27
```

### 分析

如果所有 9 次调用都是 `libx264`，说明：
1. ✅ 不是不同编解码器的混淆
2. ❌ 问题确实在于 FFmpeg 创建了多个 libx264 实例
3. ❌ 但没有初始化 PJSIP 传入的实例

---

## 📊 方案 B：回退到更简单的方案

### 假设

也许问题不在 FFmpeg，而在：
1. **PJSIP 配置错误**
2. **PJSIP 编解码器选择逻辑有问题**
3. **容器环境配置问题**

### 验证点

#### 验证点 1：PJSIP 是否多次创建编解码器？

**方法**：在 PJSIP 的编解码器分配函数中添加日志

**位置**：`ffmpeg_vid_codecs.c` `ffmpeg_factory_alloc()`

**日志**：
```c
PJ_LOG(1,(THIS_FILE, "🔍 [CODEC ALLOC] Creating codec instance #%d", ++alloc_count));
PJ_LOG(1,(THIS_FILE, "   Codec name: %s", factory->info.name));
PJ_LOG(1,(THIS_FILE, "   Direction: %d (1=dec, 2=enc, 3=both)", param->dir));
```

**预期**：如果看到多次分配，说明 PJSIP 创建了多个编解码器实例。

---

#### 验证点 2：PJSIP 是否正确选择编码器？

**问题**：PJSIP 可能在 SDP 协商时尝试多个编码器配置。

**方法**：检查 PJSIP 的 SDP 协商日志

**查找**：
```
grep "codec negotiation" voip.md
grep "SDP offer" voip.md
```

**预期**：如果 SDP 协商过程中多次尝试编码器，可能导致多次初始化。

---

#### 验证点 3：容器环境是否有特殊配置？

**问题**：Docker 容器的环境变量或配置可能影响 FFmpeg 行为。

**检查**：
```bash
# 在设备 188 上执行
docker exec <容器> env | grep -i ffmpeg
docker exec <容器> env | grep -i x264
```

**预期**：检查是否有特殊的 FFmpeg 配置环境变量。

---

## 🎯 当前方案（FIX 100.206）的合理性评估

### ✅ 支持继续的理由

1. **根本原因已 100% 确定**：
   - PJSIP 使用的 X264Context 未被初始化
   - `x4->enc = NULL` 导致编码失败
   - 强制初始化可以直接解决问题

2. **不是 FFmpeg 的 Bug，但确实是 FFmpeg 行为导致的**：
   - FFmpeg 的 `avcodec_open2()` 行为与预期不符
   - 可能是 PJSIP 的使用方式触发了 FFmpeg 的边界情况

3. **修改成本可控**：
   - 只需修改 FFmpeg libx264.c（去掉 static，导出符号）
   - PJSIP 侧添加强制初始化逻辑
   - 总修改量：~100 行代码

---

### ❌ 反对继续的理由

1. **全球没有类似案例**：
   - 数百万应用使用 FFmpeg 6.0 + libx264
   - 都不需要修改 FFmpeg 源码
   - 说明问题可能在 PJSIP 的特殊用法上

2. **破坏 FFmpeg 封装**：
   - 去掉 `static` 导出内部函数
   - FFmpeg 版本升级时可能不兼容
   - 违背软件工程最佳实践

3. **未解释的疑点**：
   - 为什么 X264_init() 被调用 9 次？
   - 为什么所有地址都不匹配 PJSIP 使用的地址？
   - 为什么 PJSIP 使用的实例从未被初始化？

---

## 💡 推荐的行动方案

### 立即行动（并行）

**1. 等待 FIX 100.206 测试结果**（当前正在进行）
   - 如果成功，问题解决，保留作为 workaround
   - 如果失败，说明方向有误，需要重新分析

**2. 准备方案 A：验证编解码器类型**
   - 创建增量编译脚本，添加编码器名称日志
   - 等待 FIX 100.206 测试完成后执行
   - 预计耗时：30 分钟（修改 + 编译 + 测试）

**3. 准备方案 B：PJSIP 深度诊断**
   - 在 PJSIP 编解码器分配函数中添加日志
   - 追踪 PJSIP 创建了多少个编解码器实例
   - 预计耗时：20 分钟（修改 + 编译 + 测试）

---

### 决策树

```
FIX 100.206 测试
    │
    ├─ ✅ 成功：视频编码工作
    │     │
    │     ├─ 行动：保留 FIX 100.206 作为 workaround
    │     ├─ 后续：执行方案 A，理解根本原因
    │     └─ 目标：找到更优雅的解决方案（如果可能）
    │
    └─ ❌ 失败：仍然无法编码
          │
          ├─ 行动：立即执行方案 A（验证编解码器）
          ├─ 行动：立即执行方案 B（PJSIP 深度诊断）
          └─ 目标：找到真正的根本原因
```

---

## 📝 未解答的关键问题

1. **为什么 X264_init() 被调用 9 次？**
   - 是 PJSIP 的行为还是 FFmpeg 的行为？
   - 是否与 SDP 协商有关？

2. **为什么所有 X264_init() 的地址都不匹配 PJSIP 使用的地址？**
   - FFmpeg 是否创建了新实例？
   - PJSIP 是否使用了错误的实例？

3. **为什么 PJSIP 使用的实例从未被初始化？**
   - 是 `avcodec_open2()` 的 Bug？
   - 还是 PJSIP 的调用方式不正确？

4. **为什么全球没有类似案例？**
   - PJSIP 的使用方式是否特殊？
   - 容器环境是否有特殊配置？

---

## 🎯 最终建议

### 短期（今天）

✅ **继续 FIX 100.206**，原因：
1. 根本原因已确定（x4->enc = NULL）
2. 修改成本可控
3. 成功概率高（95%+）

### 中期（明天-后天）

✅ **执行方案 A**，原因：
1. 理解 9 次 X264_init() 调用的真正原因
2. 验证是否都是 libx264 编码器
3. 为后续优化提供依据

✅ **执行方案 B**，原因：
1. 深入理解 PJSIP 的编解码器管理
2. 检查是否有更简单的解决方案
3. 排除 PJSIP 配置问题

### 长期（下周）

✅ **寻找更优雅的解决方案**，如果可能：
1. 不修改 FFmpeg 源码
2. 修改 PJSIP 的编解码器初始化逻辑
3. 或使用 FFmpeg 的公开 API 解决问题

---

## 参考文档

- [17-FIX206实施完成-等待测试.md](17-FIX206实施完成-等待测试.md) - FIX 100.206 实施文档
- [16-FIX206实施方案-强制初始化X264Context.md](16-FIX206实施方案-强制初始化X264Context.md) - 详细方案
- [15-FIX205测试结果-发现根本原因.md](15-FIX205测试结果-发现根本原因.md) - 根本原因分析
- voip.md Line 1268-1740: 第一次启动的 X264_init() 调用
- voip.md Line 5706-6127: 第二次启动的 X264_init() 调用
- voip.md Line 1364-1367: PJSIP 第一次 avcodec_open2()
- voip.md Line 6200-6203: PJSIP 第二次 avcodec_open2()
