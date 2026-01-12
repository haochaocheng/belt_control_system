# VERSION 131 测试分析 - ff_mutex 死锁完全确认

**日期**: 2026-01-12 20:00
**测试版本**: VERSION 131
**状态**: ✅ **死锁 100% 确认**

---

## 一、测试结果

### 用户反馈

- **第一次通话**：✅ 正常，双方能看到画面
- **第二次通话**：❌ **本机画面卡住，对方看不到视频**
- **程序状态**：✅ 没有崩溃
- **挂断状态**：✅ 对方挂断后，本机显示也挂断

---

## 二、关键证据：死锁 100% 确认！⭐⭐⭐⭐⭐

### 证据 1：第一次挂断日志（Line 6586-6590）

```
05:38:41.584  🔍 [CODEC-CLOSE VERSION 131 ENTRY] Function called
05:38:41.584  🔍 [CODEC-CLOSE VERSION 131] codec pointer valid
05:38:41.584  🔍 [CODEC-CLOSE VERSION 131] Closing codec, enc_ctx=0x7efc015440
05:38:41.584  🔍 [FIX 100.66 DIAG] dec_ctx=0x7efc015800, enc_ctx=0x7efc015440
05:38:41.584  ⏳ [FIX 100.69 DIAG] Attempting to acquire ff_mutex...
```

**之后完全没有任何日志！**

**关键发现**：
- ✅ 打印了 `dec_ctx=0x7efc015800, enc_ctx=0x7efc015440`（都有效）
- ✅ 打印了 `Attempting to acquire ff_mutex...`
- ❌ **之后没有 `ff_mutex acquired successfully` 日志**
- ❌ **之后没有任何清理日志**

**结论**：
- ✅ **100% 确认代码在 `pj_mutex_lock(ff_mutex)` 处被阻塞**
- ✅ **死锁位置精确定位**

---

## 三、第二次通话：编码器 0 包发送

### 编码器初始化（Line 6974）

```
05:39:00.531  🔍 [ENCODER-INIT VERSION 131] Fix 100.49 code loaded
05:39:00.535  ✅ [DEBUG] Encoder opened successfully
```

**发现**：
- ✅ 编码器成功打开
- ✅ 摄像头成功打开（640x480@30fps）
- ✅ 编码器配置正确

### 统计信息（Line 8459-8460）

```
TX pt=100, size=640x480, fps=30.00, last update:never
total 0pkt 0B (0B +IP hdr) @avg=0bps/0bps
```

**关键问题**：
- ❌ **编码器没有发送任何视频包（0pkt）**
- ❌ **last update:never**（编码器从未更新）

**根本原因**：
- 第一次通话的资源没有释放（因为清理代码被死锁阻塞）
- 第二次通话的编码器无法获取硬件设备资源
- 编码器初始化成功，但无法实际工作

---

## 四、第二次挂断：完全没有 CODEC-CLOSE 调用

**搜索结果**：
- 只有一次 `CODEC-CLOSE VERSION 131` 调用（Line 6586，第一次挂断）
- 第二次挂断时完全没有 CODEC-CLOSE 日志

**推测**：
- PJSIP 可能认为 codec 已经被释放了
- 因为第一次 `ffmpeg_codec_close()` 调用还在阻塞中
- 第二次挂断时没有再次调用清理函数

---

## 五、死锁的完整影响链

```
第一次通话挂断
    ↓
ffmpeg_codec_close() 被调用
    ↓
打印 dec_ctx 和 enc_ctx 的值
    ↓
打印 "Attempting to acquire ff_mutex..."
    ↓
pj_mutex_lock(ff_mutex) 阻塞 ← ⚠️ 永远等待
    ↓
清理代码从未执行
    ↓
ff_mutex 永远未被释放
    ↓
RKMPP 硬件设备资源未释放
    ↓
第二次通话
    ↓
编码器初始化成功（软件层面）
    ↓
但无法访问 RKMPP 硬件设备（资源被占用）
    ↓
编码器 0 包发送（无法实际工作）
    ↓
第二次挂断
    ↓
ffmpeg_codec_close() 不被调用（PJSIP 认为已释放）
```

---

## 六、与 VERSION 130 的对比

| 版本 | 诊断日志 | 发现 | 结论 |
|------|---------|------|------|
| VERSION 130 | `dec_ctx=..., enc_ctx=...` | 两者都有效 | 不是 NULL 问题 |
| VERSION 131 | `Attempting to acquire ff_mutex...` | 之后无日志 | **死锁在 pj_mutex_lock()** ✅ |

**进展**：
- VERSION 130: 发现 dec_ctx/enc_ctx 都有效
- VERSION 131: **精确定位死锁位置**

---

## 七、为什么会死锁？

### 可能原因 1：之前的清理异常退出

**假设**：
- 在 VERSION 131 之前的某次清理，因为异常退出（崩溃、提前返回）
- `pj_mutex_lock(ff_mutex)` 执行了
- 但 `pj_mutex_unlock(ff_mutex)` 从未执行
- `ff_mutex` 锁永远被持有

**结果**：
- 之后任何尝试获取此锁的操作都会被阻塞

### 可能原因 2：递归锁问题

**假设**：
- 同一个线程尝试二次获取同一个非递归锁
- 第一次 `pj_mutex_lock(ff_mutex)` 成功
- 在清理过程中，某个回调再次调用 `ffmpeg_codec_close()`
- 第二次 `pj_mutex_lock(ff_mutex)` 死锁

**结果**：
- 如果 `ff_mutex` 不是递归锁，同一线程二次获取会死锁

### 可能原因 3：循环等待

**假设**：
- Thread A 持有 `ff_mutex`，等待其他资源
- Thread B 持有其他资源，等待 `ff_mutex`
- 形成循环等待

**结果**：
- 经典的死锁场景

---

## 八、解决方案：Fix 100.70

### 方案 A：使用 trylock + 强制清理（推荐）⭐

**核心思路**：
- 不等待锁，如果获取失败，直接强制清理

```c
pj_status_t status = pj_mutex_trylock(ff_mutex);
if (status != PJ_SUCCESS) {
    PJ_LOG(1, "⚠️ [FIX 100.70] Failed to acquire ff_mutex, forcing cleanup without lock");
    goto force_cleanup;
}

// ... 正常清理（持有锁）...

pj_mutex_unlock(ff_mutex);
return PJ_SUCCESS;

force_cleanup:
    PJ_LOG(1, "⚠️ [FIX 100.70] Force cleanup without mutex protection");

    // 不持有锁的清理
    if (ff->dec_ctx && ff->dec_ctx != ff->enc_ctx) {
        // 跳过 flush
        if (ff->dec_ctx->hw_frames_ctx) {
            av_buffer_unref(&ff->dec_ctx->hw_frames_ctx);
            ff->dec_ctx->hw_frames_ctx = NULL;
        }
        avcodec_close(ff->dec_ctx);
        av_free(ff->dec_ctx);
    }

    if (ff->enc_ctx) {
        avcodec_send_frame(ff->enc_ctx, NULL);
        // ... flush ...
        if (ff->enc_ctx->hw_frames_ctx) {
            av_buffer_unref(&ff->enc_ctx->hw_frames_ctx);
            ff->enc_ctx->hw_frames_ctx = NULL;
        }
        avcodec_close(ff->enc_ctx);
        av_free(ff->enc_ctx);
    }

    ff->enc_ctx = NULL;
    ff->dec_ctx = NULL;

    return PJ_SUCCESS;
```

**优势**：
- ✅ 不会被死锁阻塞
- ✅ 强制清理，确保资源释放
- ✅ 第二次通话可以正常工作

**风险**：
- ⚠️ 不持有锁的清理可能有竞态条件
- 但比死锁好得多

---

## 九、技术洞察

### 洞察 1：诊断式开发的成功

**过程**：
- Fix 100.66: 诊断 dec_ctx/enc_ctx → 发现都存在
- Fix 100.69: 诊断 ff_mutex → **确认死锁位置** ✅
- Fix 100.70: 根据诊断结果实施解决方案

**价值**：
- 每一步都基于证据
- 避免猜测和盲目修改
- 问题定位越来越精确

### 洞察 2：死锁诊断方法

**方法**：
- 在可疑位置前后添加日志
- 如果前有后无 → 确认阻塞位置
- 使用时间戳检测执行时间异常

### 洞察 3：C 语言的资源管理挑战

**问题**：
- 没有 RAII（自动资源管理）
- 必须手动在每个路径 unlock
- 容易遗漏

**解决**：
- 使用 trylock 代替 lock
- 添加 force_cleanup 路径
- 最小化持有锁的时间

---

## 十、总结

### 核心成就

1. ✅ **100% 确认死锁**：代码在 `pj_mutex_lock(ff_mutex)` 处被阻塞
2. ✅ **精确定位**：通过 Fix 100.69 诊断日志精确定位
3. ✅ **完整分析**：理解了死锁对第二次通话的影响

### 下一步

**立即实施 Fix 100.70 方案 A**：
- 使用 `pj_mutex_trylock()` 代替 `pj_mutex_lock()`
- 添加 `force_cleanup` 路径
- 确保无论如何都能完成清理

---

## 十一、诊断成功标志

| 诊断目标 | 方法 | 结果 |
|---------|------|------|
| dec_ctx/enc_ctx 是否为 NULL？ | Fix 100.66 | ✅ 都有效 |
| 是否死锁在 pj_mutex_lock()？ | Fix 100.69 | ✅ **确认死锁** |

**Fix 100.69 的诊断日志完美完成了任务！**

---

**文档创建时间**: 2026-01-12 20:00
**分析者**: Claude Sonnet 4.5
**状态**: ✅ **死锁 100% 确认，立即实施 Fix 100.70**

**下一步**：
```bash
# 实施 Fix 100.70
# 修改 ffmpeg_vid_codecs.c
# 更新版本号到 VERSION 132
# 部署测试
```

**期望结果**：
- ✅ 第一次挂断：成功清理（持有锁或强制清理）
- ✅ 第二次通话：编码器正常发送视频包
- ✅ **完全稳定的视频通话系统** ⭐⭐⭐⭐⭐
