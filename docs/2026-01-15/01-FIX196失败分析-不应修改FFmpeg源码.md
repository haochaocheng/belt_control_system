# FIX 100.196/100.197 失败分析 - 不应修改 FFmpeg 源码

**时间**: 2026-01-15 00:30（北京时间）
**问题**: libx264 软件编码器初始化后崩溃
**测试结果**: FIX 100.196 仍然崩溃

---

## 1. 测试结果

### ✅ 诊断日志成功输出

```
[FIX 100.196 DIAG] delayed_frames=52, nb_reordered_opaque=69
```

**重复 9 次！** - 这是异常现象

### ✅ 所有修改都生效

| 项目 | 预期值 | 实际值 | 状态 |
|-----|-------|--------|------|
| PJSIP `max_b_frames` | 2 | 2 ✅ | 成功 |
| FFmpeg `delayed_frames` | > 0 | **52** ✅ | 不为0！|
| FFmpeg `nb_reordered_opaque` | > 0 | **69** ✅ | 52+17=69 正确！|
| 编码器打开 | 成功 | 成功 ✅ | 成功 |

### ❌ 但仍然崩溃

```
Line 1311: ✅ Encoder opened successfully
Line 1323: Encoder stream paused
Line 1327: Encoder stream resumed
→ 崩溃在 av_buffer_unref()
```

---

## 2. 关键发现

### 🔍 核心结论

**我们的假设完全错了！**

- ❌ **原假设**: `nb_reordered_opaque=0` 导致数组越界
- ✅ **实际情况**: `nb_reordered_opaque=69`（非零），但仍然崩溃

### 🔴 真正问题

**问题不在 FFmpeg 官方源码，而在我们的使用方式！**

用户指导（正确）：
- **"ffmpeg 官方源码，不可能是它得问题"**
- **"主要是我们的问题，官方不可能出现BUG"**
- **"尽量不要修改ffmpeg源码"**

---

## 3. 异常现象分析

### ⚠️ 诊断日志重复9次

```
Line 1292-1300: [FIX 100.196 DIAG] delayed_frames=52, nb_reordered_opaque=69
```

**这不正常！** `X264_init` 函数理论上只会被调用一次。

**可能原因**：
1. **多线程竞争** - 但 PJSIP 应该有锁保护
2. **输出缓冲** - 但我们用了 `fflush(stderr)`
3. **某个循环调用了 9 次** - 需要深入调查

---

## 4. 崩溃位置分析

### 崩溃调用栈

```
#0  av_buffer_unref() from /app/lib/libavutil.so.58
#1  ?? () from /app/lib/libavcodec.so.60  ← opaque_uninit()
#2  ?? () from /app/lib/libavcodec.so.60  ← X264_flush() 或 X264_close()
```

### FFmpeg libx264.c 源码分析

```c
// Line 149-153: opaque_uninit函数
static void opaque_uninit(X264Opaque *o)
{
    av_buffer_unref(&o->frame_opaque_ref);  // ← 崩溃点
    memset(o, 0, sizeof(*o));
}
```

**调用位置**：
1. Line 506: `X264_encode()` - 编码时清理opaque
2. Line 698: `X264_encode()` - 编码完成后清理
3. Line 779: `X264_flush()` - flush时循环清理所有opaque
4. Line 792: `X264_close()` - 关闭时循环清理所有opaque

---

## 5. 根因假设

### 假设1：编码器流暂停/恢复触发Flush

**证据**：
```
Line 1323: Encoder stream paused
Line 1327: Encoder stream resumed
→ 崩溃
```

PJSIP 在编码器暂停/恢复时可能调用了不当的操作。

### 假设2：PJSIP错误地操作了FFmpeg内部资源

**历史经验**：
- FIX 100.77 曾因手动释放 `hw_frames_ctx` 导致崩溃
- 教训：不要手动操作 FFmpeg 自动管理的资源

**可能问题**：
- PJSIP 在某个阶段错误地操作了 `AVCodecContext`
- 导致 FFmpeg 内部状态不一致
- flush/close 时访问无效资源

---

## 6. 我们的错误修改

### ❌ FIX 100.196 - 修改 FFmpeg libx264.c

```c
// Line 1295-1301: 强制最小值为1
if (x4->nb_reordered_opaque < 1) {
    fprintf(stderr, "[FIX 100.196] forcing to 1\n");
    x4->nb_reordered_opaque = 1;
}
```

**问题**：
- 修改了 FFmpeg 官方源码
- 但实际上 `nb_reordered_opaque=69`，这段代码根本没执行
- **完全无用的修改！**

### ❌ FIX 100.197 - 修改 FFmpeg libx264.c

```c
// Line 1304-1306: 改用 fprintf
fprintf(stderr, "[FIX 100.196 DIAG] ...\n");
fflush(stderr);
```

**问题**：
- 仅用于诊断，但修改了官方源码
- 应该在 PJSIP 层添加诊断

---

## 7. 正确的调试方向

### ✅ 应该做的

1. **回退所有 FFmpeg 源码修改**
   - 移除 Line 1284-1313 的所有修改
   - 保持 FFmpeg 官方代码不变

2. **只修改 PJSIP 代码**
   - ✅ 保留 `max_b_frames=2`（这个修改是合理的）
   - 检查编码器暂停/恢复的处理
   - 检查是否错误地操作了 `AVCodecContext`

3. **深入调查异常现象**
   - 为什么诊断日志重复9次？
   - 编码器暂停/恢复时发生了什么？
   - PJSIP 是否调用了 flush 或其他清理操作？

---

## 8. 下一步行动

### 方案A：回退FFmpeg修改，保持PJSIP修改

1. 回退 `libx264.c` 到官方版本
2. 保留 PJSIP `max_b_frames=2`
3. 测试是否仍然崩溃

### 方案B：分析PJSIP编码器暂停/恢复逻辑

1. 搜索 PJSIP 中 "paused" 和 "resumed" 的处理
2. 检查是否调用了 flush 或清理操作
3. 对比成功的 Fix 100.50 版本

### 方案C：使用软件解码器（临时方案）

- libx264 软件编码器 + rkmpp_h264 硬件解码器
- 如果仍然崩溃，说明问题在 PJSIP 的通用逻辑中

---

## 9. 教训总结

1. **不要轻易修改第三方库源码**
   - 特别是 FFmpeg 这样成熟的库
   - 官方代码经过大量测试，不太可能有基本BUG

2. **先彻底理解问题再修改**
   - 我们基于错误假设修改了代码
   - 实际上问题根本不在那里

3. **相信用户的判断**
   - 用户多次强调"不要怀疑FFmpeg"
   - 我们应该更早听取这个建议

---

## 10. 参考文档

- voip.md Line 1292-1327: 测试日志
- libx264.c Line 149-153: opaque_uninit函数
- libx264.c Line 767-783: X264_flush函数
- FIX 100.77: 历史上因手动释放hw_frames_ctx导致崩溃

---

## 附录：完整崩溃日志关键部分

```
00:13:46.209  max_b_frames=2                           ← PJSIP修改生效
00:13:46.209  gop_size=300
[FIX 100.196 DIAG] delayed_frames=52, nb_reordered_opaque=69  ← 重复9次！
00:13:46.288  ✅ Encoder opened successfully
00:13:46.289  Encoder stream paused                    ← 暂停
00:13:46.790  Encoder stream resumed                   ← 恢复
→ 崩溃在 av_buffer_unref()
```
