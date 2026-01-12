# VERSION 141 失败分析 - 必须彻底改变调查方向

**日期**: 2026-01-13 02:20
**重要性**: ⭐⭐⭐⭐⭐ **关键转折点 - Fix 100.76-100.79 全部失败**
**状态**: 📊 **分析完成，必须改变方向**

---

## 一、VERSION 141 测试结果

### 崩溃模式（与 VERSION 137-140 完全一致）

**stderr 输出**：
```
!!! [STDERR-DIAG-5] ENTER decoder cleanup
!!! [STDERR-DIAG-6] About to call avcodec_free_context(dec_ctx)
14:14:23.657 ✅ [FIX 100.79] Closing decoder using avcodec_free_context
!!! [STDERR-DIAG-7] avcodec_free_context(dec_ctx) returned  ← ✅ 解码器成功

!!! [STDERR-DIAG-8] ENTER encoder cleanup
!!! [STDERR-DIAG-9] About to call avcodec_free_context(enc_ctx)
14:14:23.661 ✅ [FIX 100.79] Closing encoder using avcodec_free_context
← ❌ DIAG-10 缺失：编码器崩溃！
```

**容器状态**：
```bash
$ docker ps -a | grep belt-control-app
7a0c07db0ec0   belt-control:v3.5-apt   Exited (139) 4 minutes ago
```

**Core Dump 分析**（`core.clock.1.1768227263.analysis.txt`）：
```
#0  __GI___libc_free (mem=<optimized out>) at ./malloc/malloc.c:3375
#1  0x0000007fad863500 in avcodec_close () from /app/lib/libavcodec.so.60
#2  0x0000007faddad730 in avcodec_free_context () from /app/lib/libavcodec.so.60  ← Fix 100.79 使用的 API
#3  0x000000558c33e6d8 in ffmpeg_codec_close ()
```

---

## 二、关键发现：avcodec_free_context 内部调用 avcodec_close

**崩溃堆栈解读**：
```
Frame #3: ffmpeg_codec_close()              ← 我们的代码
         ↓
Frame #2: avcodec_free_context()           ← Fix 100.79 使用的推荐 API
         ↓
Frame #1: avcodec_close()                  ← FFmpeg 内部调用的废弃 API
         ↓
Frame #0: free()                           ← 崩溃点：访问已释放的内存
```

**结论**：
1. `avcodec_free_context()` **内部调用了 `avcodec_close()`**
2. Fix 100.79 依然崩溃，因为问题就在 `avcodec_close()` 内部
3. 即使使用推荐 API，最终还是会调用到 `avcodec_close()`
4. **问题不在 API 选择，而是在编码器的内部状态被破坏**

---

## 三、Fix 100.76-100.79 全部失败的总结

### Fix 100.76（VERSION 138）
**目标**：移除清理阶段的 hw_frames_ctx 手动释放
**结果**：❌ 失败 - 同样的崩溃位置
**教训**：问题不在清理阶段的 hw_frames_ctx

### Fix 100.77（VERSION 139）
**目标**：移除 Fix 100.42 的 hw_frames_ctx 手动释放
**结果**：❌ 失败 - 同样的崩溃位置
**教训**：问题不在 Fix 100.42

### Fix 100.78（VERSION 140）
**目标**：移除编码器 Flush 操作
**结果**：❌ 失败 - 同样的崩溃位置
**教训**：问题不在 av_init_packet 的 Flush 循环

### Fix 100.79（VERSION 141）
**目标**：使用 avcodec_free_context 替换 avcodec_close
**结果**：❌ 失败 - 同样的崩溃位置
**教训**：问题不在 API 选择，avcodec_free_context 内部也调用 avcodec_close

**共同特征**：
- ✅ 解码器清理始终成功（DIAG-7 出现）
- ❌ 编码器清理始终崩溃（DIAG-10 缺失）
- 💥 崩溃位置始终在 `free()` 内部（访问已释放的内存）

---

## 四、为什么清理 API 修复全部失败？

### 核心洞察

**问题不在清理阶段，而在编码器使用阶段！**

**证据 1：解码器 vs 编码器对比**
| 特征 | 解码器 | 编码器 |
|------|--------|--------|
| 清理 API | avcodec_free_context | avcodec_free_context |
| hw_frames_ctx | 有 | 有 |
| hw_device_ctx | 有 | 有（共享） |
| 清理结果 | ✅ **始终成功** | ❌ **始终崩溃** |

**问题**：为什么使用相同的清理 API，解码器成功但编码器失败？

**答案**：编码器的**内部状态**在初始化或使用过程中被破坏了！

### 证据 2：avcodec_free_context 的实现

**FFmpeg 源码**（E:\2025\3_gongkongji\NewFolder\ffmpeg-rk-temp\ffmpeg-rockchip-master\libavcodec\avcodec.c）：

```c
void avcodec_free_context(AVCodecContext **pavctx)
{
    AVCodecContext *avctx = *pavctx;

    if (!avctx)
        return;

    avcodec_close(avctx);  // ← 内部调用 avcodec_close()

    av_freep(&avctx->extradata);
    av_freep(&avctx->subtitle_header);
    av_freep(&avctx->intra_matrix);
    av_freep(&avctx->inter_matrix);
    av_freep(&avctx->rc_override);

    av_freep(pavctx);
}
```

**关键代码**：`avcodec_close(avctx);`

**含义**：
- `avcodec_free_context()` 第一步就是调用 `avcodec_close()`
- 然后才释放额外的内存（extradata, subtitle_header 等）
- **所以无论用哪个 API，都会调用 `avcodec_close()`**

### 证据 3：崩溃在 free() 内部

**Core Dump 显示**：
```
#0  __GI___libc_free (mem=<optimized out>) at ./malloc/malloc.c:3375
```

**含义**：
- `free()` 函数尝试释放一块内存
- 这块内存的状态异常（可能已经被释放过，或者内存结构被破坏）
- 导致 `free()` 内部的元数据检查失败 → SIGSEGV

**问题**：这块内存是什么？为什么解码器没问题但编码器有问题？

---

## 五、必须改变方向：不再关注清理代码

### 旧方向（Fix 100.76-100.79）：修复清理代码

**假设**：清理代码有问题（手动释放、API 选择等）
**结果**：5 个连续失败（VERSION 137-141）
**教训**：**清理代码不是问题所在**

### 新方向：分析编码器初始化和使用阶段

**假设**：编码器在初始化或使用过程中破坏了内部状态
**证据**：
1. 解码器使用相同清理代码 → 成功
2. 编码器使用相同清理代码 → 崩溃
3. **唯一解释**：编码器的初始化/使用有问题

**需要调查的代码**：
1. **编码器初始化**（`open_ffmpeg_codec` 中的编码器部分）
2. **编码器使用**（`encode_frame` 函数）
3. **编码器特有资源**（解码器没有的资源）

---

## 六、关键线索：编码器 vs 解码器的差异

### 差异 1：av_init_packet 使用（编码路径）

**位置**：`ffmpeg_vid_codecs.c:3723`（编码器 encode_frame 函数）

```c
/* 每帧编码时都调用 */
av_init_packet(&avpacket);  // ← 废弃 API，每帧都调用
avpacket.data = (pj_uint8_t*)output->buf;
avpacket.size = output_buf_len;

ret = avcodec_send_frame(ff->enc_ctx, &avframe);
ret = avcodec_receive_packet(ff->enc_ctx, &avpacket);

av_packet_unref(&avpacket);  // ← 每帧都 unref
```

**问题**：
- `av_init_packet()` 在 FFmpeg 6.0 中已废弃
- **Fix 100.42.2 已经证明**：`av_init_packet()` 会破坏 `avframe.data`
- 这里每帧都调用，可能累积破坏编码器内部状态

**解码器对比**：
- 解码器 decode_frame 函数（Line 4291）也使用 `av_init_packet()`
- **但解码器清理成功！**
- 说明 `av_init_packet()` 可能不是唯一问题，或者编码器特有的问题

### 差异 2：编码器初始化代码

**需要检查**：
- 编码器的 `avcodec_open2()` 调用前的参数设置
- 编码器是否有特殊的 hw_device_ctx / hw_frames_ctx 设置
- 编码器是否有解码器没有的资源

### 差异 3：hw_device_ctx 共享机制

**当前代码**：
```c
/* 编码器共享解码器的 hw_device_ctx */
ff->enc_ctx->hw_device_ctx = av_buffer_ref(ff->dec_ctx->hw_device_ctx);
```

**可能的问题**：
- 共享的 hw_device_ctx 引用计数管理
- 解码器关闭时，hw_device_ctx 可能被释放
- 编码器关闭时，尝试访问已释放的 hw_device_ctx？

**但这个假设有矛盾**：
- 解码器先关闭（DIAG-7 成功）
- 然后编码器才关闭（DIAG-10 崩溃）
- 如果是 hw_device_ctx 问题，应该在解码器关闭时就崩溃

---

## 七、下一步调查计划

### 步骤 1：读取编码器初始化代码

**文件**：`cross-compile/src/pjproject-2.16/pjmedia/src/pjmedia-codec/ffmpeg_vid_codecs.c`
**函数**：`open_ffmpeg_codec`（编码器部分）
**关注点**：
- `avcodec_alloc_context3()` 调用
- 编码器参数设置（width, height, pix_fmt, bit_rate 等）
- `hw_device_ctx` 的设置和引用
- `avcodec_open2()` 调用前后的代码

### 步骤 2：对比编码器和解码器初始化

**目标**：找出编码器特有的初始化步骤
**方法**：
- 读取解码器初始化代码
- 逐行对比编码器和解码器的差异
- 找出可能导致内部状态异常的代码

### 步骤 3：分析 av_init_packet 使用

**位置**：`ffmpeg_vid_codecs.c:3723`（编码器）和 `Line 4291`（解码器）
**问题**：
- 为什么解码器用 `av_init_packet` 成功，编码器崩溃？
- 是否可以替换为 `av_packet_alloc()` / `av_packet_free()`？
- 这是否是累积破坏的根源？

### 步骤 4：检查 hw_device_ctx 共享

**代码**：编码器设置 `hw_device_ctx` 的地方
**验证**：
- 引用计数是否正确
- 解码器关闭后，hw_device_ctx 是否仍然有效
- 编码器是否需要独立的 hw_device_ctx

---

## 八、关键洞察

### 洞察 1：5 次清理代码修复全部失败 → 问题不在清理

**失败序列**：
- VERSION 138 (Fix 100.76): 移除清理阶段 hw_frames_ctx 释放 - ❌
- VERSION 139 (Fix 100.77): 移除 Fix 100.42 hw_frames_ctx 释放 - ❌
- VERSION 140 (Fix 100.78): 移除编码器 Flush 操作 - ❌
- VERSION 141 (Fix 100.79): 使用推荐 API avcodec_free_context - ❌

**结论**：**停止修改清理代码！**

### 洞察 2：解码器成功 vs 编码器失败 → 问题在编码器特有的逻辑

**共同点**：
- 使用相同的清理 API（avcodec_free_context）
- 使用相同的 hw_device_ctx
- 使用相同的诊断代码

**差异点**：
- 编码器有编码路径（encode_frame, av_init_packet）
- 编码器有特殊的初始化参数
- 编码器可能有解码器没有的资源

**结论**：**问题在编码器的初始化或使用阶段**

### 洞察 3：avcodec_free_context 内部调用 avcodec_close → 无法绕过

**FFmpeg 源码证据**：
```c
void avcodec_free_context(AVCodecContext **pavctx) {
    avcodec_close(avctx);  // ← 第一步就调用 avcodec_close
    // ... 然后释放其他内存
}
```

**结论**：
- 不存在\"不调用 avcodec_close\"的清理方法
- 必须确保 `avcodec_close()` 被调用时，编码器内部状态是正常的
- **唯一的方法**：修复初始化/使用阶段，避免破坏内部状态

---

## 九、用户反馈回顾

### 反馈 1："100.77测试结束，还是崩溃，快点解决"
- **时间**：VERSION 139 失败后
- **情绪**：催促
- **含义**：希望快速解决

### 反馈 2："140测试结束，依然崩溃，你就不能全面的排查吗，到140了，还没有找到原因"
- **时间**：VERSION 140 失败后
- **情绪**：不满 + 质疑
- **含义**：希望进行**全面排查**，而不是局部修复
- **正确性**：✅ **用户是对的！** 我们应该早点全面分析

### 反馈 3："你只复制修改，我编译，把你的126d9f任务关闭，之前我已经编译了"
- **时间**：VERSION 140 失败后
- **情绪**：指导工作方式
- **含义**：用户自己编译测试，我只负责代码修改和分析

### 反馈 4："141测试完成，依然崩溃"
- **时间**：VERSION 141 失败后
- **情绪**：陈述事实
- **含义**：即使使用推荐 API 也失败

**从反馈中学到的**：
1. **用户在 VERSION 140 时就要求全面排查** - 我们应该早点改变方向
2. 用户希望快速解决 - 但快速修复的前提是**找对方向**
3. **5 次失败后，必须承认方向错误**

---

## 十、总结

### 核心结论

**问题不在清理 API 的选择，而是在编码器的内部状态被破坏**

### 关键证据

1. **5 次清理代码修复全部失败**（VERSION 137-141）
2. **解码器清理始终成功，编码器清理始终崩溃**
3. **avcodec_free_context 内部调用 avcodec_close**（无法绕过）
4. **崩溃在 free() 内部**（访问已释放的内存）

### 必须改变方向

**旧方向**（已放弃）：
- ❌ 修改清理阶段代码
- ❌ 更换清理 API
- ❌ 移除资源手动释放

**新方向**（现在开始）：
- ✅ 分析编码器初始化代码
- ✅ 分析编码器使用阶段（encode_frame, av_init_packet）
- ✅ 对比编码器和解码器差异
- ✅ 找出编码器特有的状态破坏点

### 下一步行动

1. **立即读取编码器初始化代码**（`open_ffmpeg_codec` 函数）
2. **对比编码器和解码器初始化**（找出差异）
3. **分析 av_init_packet 使用**（Line 3723 和 4291）
4. **检查 hw_device_ctx 共享机制**
5. **定位真正的根本原因**

---

**文档创建时间**: 2026-01-13 02:20
**分析者**: Claude Sonnet 4.5
**状态**: 📊 **分析完成，准备改变方向**

**关键成就**：
- ✅ 确认 VERSION 141 失败模式
- ✅ 发现 avcodec_free_context 内部调用 avcodec_close
- ✅ 确认问题不在清理 API 选择
- ✅ 确定新的调查方向（编码器初始化/使用）
- ⏭️ 准备开始全新的调查

**对用户的回应**：
- 用户在 VERSION 140 时要求\"全面排查\" - **现在我们开始全面排查**
- 不再局部修复清理代码 - **改为分析完整的编码器生命周期**
- 5 次失败教会了我们 - **方向比速度更重要**

**下一步**：
```powershell
# 不再编译部署，先进行代码分析
# 读取编码器初始化代码
# 对比编码器和解码器差异
# 定位状态破坏的根源
```

**成功率预估**：**未知**，因为这是全新的方向，但这是**唯一正确的方向**。
