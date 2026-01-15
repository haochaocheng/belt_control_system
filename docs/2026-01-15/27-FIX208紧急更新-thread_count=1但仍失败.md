# FIX 100.208 紧急更新 - thread_count=1 但仍然失败

**时间**: 2026-01-16 07:35（北京时间）
**状态**: ⚠️ **需要重新分析**
**发现**: 日志显示 thread_count=1, thread_type=0（单线程），但编码仍然失败

---

## 🚨 关键发现

用户指出日志显示 `thread_count=1, thread_type=0`，这意味着在调用 `avcodec_open2()` 之前，编码器已经被配置为单线程模式。

### 证据（voip.md Line 1327, 1349）

```
Encoder context before avcodec_open2():
  thread_count=1  ← ⚠️ 已经是单线程！
  thread_type=0   ← ⚠️ 不使用任何线程类型！
  width=640, height=480
  pix_fmt=0
  gop_size=300, max_b_frames=2
```

---

## 📊 问题重新定义

### ❌ 之前的分析（错误）

我认为：
- libx264 使用多线程初始化（FF_THREAD_FRAME）
- FFmpeg 创建了 9 个子线程上下文
- 主上下文从未被初始化
- 解决方案：禁用多线程

### ✅ 实际情况

1. **thread_count=1, thread_type=0**（已经是单线程）
2. **但仍然有 9 次 X264_init() 调用**
3. **X264_init() 的 AVCodecContext 地址仍然和 PJSIP 不匹配**

**结论**：**问题不是多线程导致的！**

---

## 🔍 新的疑问

### 问题 1：为什么 thread_count=1 但有 9 次 X264_init()？

**可能原因**：

A. **FFmpeg 自动调整 thread_count**
   - PJSIP 设置 thread_count=1
   - FFmpeg 内部检测到 CPU 核心数
   - 自动调整为 thread_count=9

B. **frame_thread_encoder 不受 thread_count 控制**
   - frame_thread_encoder 有自己的线程池
   - 不管 thread_count 是多少，都创建固定数量的线程

C. **其他未知机制**
   - FFmpeg 有其他创建多个 AVCodecContext 的机制

---

### 问题 2：X264_init() 的 AVCodecContext 为什么不匹配？

**地址对比**：

| 项目 | PJSIP 传入 | X264_init() 收到 | 匹配？ |
|------|-----------|-----------------|--------|
| AVCodecContext | `0x7ed0016890` | `0x7ed062eaa0` | ❌ |
| priv_data | `0x7ed0016c50` | `0x7ed062ef20` | ❌ |

**可能原因**：
- FFmpeg 在某个地方复制或克隆了 AVCodecContext
- 或者创建了新的 AVCodecContext

---

## 🎯 下一步调查方向

### 方向 1：检查 FFmpeg 是否自动调整 thread_count ⭐⭐⭐⭐⭐

**添加诊断**：在 `avcodec_open2()` 之后立即记录 `thread_count`

```c
// 在 PJSIP ffmpeg_vid_codecs.c AVCODEC_OPEN 之后添加
PJ_LOG(1,(THIS_FILE, "After avcodec_open2():"));
PJ_LOG(1,(THIS_FILE, "  thread_count: %d", ff->enc_ctx->thread_count));
PJ_LOG(1,(THIS_FILE, "  active_thread_type: %d", ff->enc_ctx->active_thread_type));
```

**预期发现**：
- 如果 thread_count 从 1 变成了 9 → FFmpeg 自动调整
- 如果 thread_count 仍然是 1 → 问题在其他地方

---

### 方向 2：检查 avctx->active_thread_type ⭐⭐⭐⭐⭐

**关键代码**（avcodec.c Line 358-360）：

```c
if (!(avctx->active_thread_type & FF_THREAD_FRAME) ||
    avci->frame_thread_encoder) {
    if (codec2->init) {
        // FIX 100.207 代码在这里
    }
}
```

**问题**：
- `thread_type=0` 不代表 `active_thread_type=0`
- FFmpeg 可能在内部激活了 `FF_THREAD_FRAME`

**添加诊断**：

```c
// 在 FFmpeg avcodec.c Line 357 之后添加
fprintf(stderr, "\n[DEBUG] Thread settings check:\n");
fprintf(stderr, "  thread_count: %d\n", avctx->thread_count);
fprintf(stderr, "  thread_type: %d\n", avctx->thread_type);
fprintf(stderr, "  active_thread_type: %d\n", avctx->active_thread_type);
fprintf(stderr, "  frame_thread_encoder: %d\n", avci->frame_thread_encoder);
fprintf(stderr, "  Condition check:\n");
fprintf(stderr, "    !(active_thread_type & FF_THREAD_FRAME): %d\n",
                !(avctx->active_thread_type & FF_THREAD_FRAME));
fprintf(stderr, "    frame_thread_encoder: %d\n", avci->frame_thread_encoder);
fprintf(stderr, "    Will enter codec->init block: %d\n",
                (!(avctx->active_thread_type & FF_THREAD_FRAME) || avci->frame_thread_encoder));
fflush(stderr);
```

---

### 方向 3：检查 ff_thread_init() 是否被调用 ⭐⭐⭐⭐

**添加诊断**（avcodec.c Line 346-354）：

```c
if (HAVE_THREADS && !avci->frame_thread_encoder) {
    fprintf(stderr, "\n[DEBUG] Calling ff_thread_init()\n");
    fprintf(stderr, "  thread_count: %d\n", avctx->thread_count);
    fflush(stderr);

    lock_avcodec(codec2);
    ret = ff_thread_init(avctx);
    unlock_avcodec(codec2);

    fprintf(stderr, "[DEBUG] ff_thread_init() returned: %d\n", ret);
    fprintf(stderr, "  active_thread_type after: %d\n", avctx->active_thread_type);
    fflush(stderr);

    if (ret < 0) {
        goto free_and_end;
    }
}
```

---

## 📋 FIX 100.208 状态

### ⚠️ FIX 100.208 可能无效

**原因**：
- 日志显示已经是 thread_count=1
- FIX 100.208 的修改（设置 thread_count=1）可能不起作用
- 问题不在用户设置的 thread_count，而在 FFmpeg 内部行为

### ✅ 但仍然值得测试

**理由**：
1. 用户设置的 thread_count=1 可能被 FFmpeg 覆盖
2. FIX 100.208 在 avcodec_open2() 之前设置
3. 可能比之前的设置更晚，更有效
4. 额外设置 thread_type=0 可能有效

---

## 🚀 建议

### 选项 A：先测试 FIX 100.208（快速验证）

**理由**：
- 代码已经写好
- 快速验证（2-3 分钟）
- 可能比之前的设置更有效

**操作**：
```powershell
.\scripts\2026-01-09\03-quick-verify-pjsip.ps1 188
```

**预期**：
- 如果成功 → 问题解决
- 如果失败 → 至少确认方向错误，进入选项 B

---

### 选项 B：添加详细诊断日志（深入调查）

**修改文件**：
1. `cross-compile/src/ffmpeg-rockchip-6.0/libavcodec/avcodec.c`
   - 添加方向 2 和方向 3 的诊断日志

2. `cross-compile/src/pjproject-2.16/pjmedia/src/pjmedia-codec/ffmpeg_vid_codecs.c`
   - 添加方向 1 的诊断日志（avcodec_open2 之后）

**预期发现**：
- 确定 FFmpeg 如何调整 thread_count
- 确定 active_thread_type 的值
- 确定 ff_thread_init() 是否被调用
- 100% 理解为什么有 9 次 X264_init()

---

## 📝 总结

### ✅ 已确认的事实

1. **thread_count=1, thread_type=0**（调用 avcodec_open2() 之前）
2. **仍然有 9 次 X264_init() 调用**
3. **X264_init() 的 AVCodecContext 地址不匹配**
4. **编码失败**

### ❓ 核心未解之谜

1. 为什么 thread_count=1 但有 9 次 X264_init()？
2. FFmpeg 是否自动调整了 thread_count？
3. active_thread_type 的值是什么？
4. ff_thread_init() 是否被调用？

### 🎯 推荐行动

**立即测试 FIX 100.208**（选项 A），如果失败，执行选项 B 深入调查。

---

## 🔗 相关文档

- [26-FIX208实施完成-禁用libx264多线程.md](26-FIX208实施完成-禁用libx264多线程.md) - FIX 208 实施方案（可能无效）
- [25-FIX207澄清-捕获的是解码器不是编码器.md](25-FIX207澄清-捕获的是解码器不是编码器.md) - 澄清误解
- voip.md Line 1327, 1349: thread_count=1 证据
- voip.md Line 1374-1424: 地址不匹配证据
- FFmpeg frame_thread_encoder.c Line 198: 创建新 AVCodecContext 的代码
