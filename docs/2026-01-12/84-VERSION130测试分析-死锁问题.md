# VERSION 130 测试分析 - ff_mutex 死锁问题

**日期**: 2026-01-12 19:30
**测试版本**: VERSION 130
**状态**: ❌ **发现死锁问题**

---

## 一、测试结果

### 用户反馈

- **第一次通话**：✅ 正常，双方能看到画面
- **第二次通话**：❌ **本机画面卡住，对方看不到视频**
- **程序状态**：✅ 没有崩溃
- **挂断状态**：✅ 对方挂断后，本机显示也挂断

### 关键日志证据

**第一次挂断（Line 4877-4880）**：
```
05:13:03.459  🔍 [CODEC-CLOSE VERSION 130 ENTRY] Function called
05:13:03.459  🔍 [CODEC-CLOSE VERSION 130] codec pointer valid
05:13:03.459  🔍 [CODEC-CLOSE VERSION 130] Closing codec, enc_ctx=0x7ef4015b50
05:13:03.459  🔍 [FIX 100.66 DIAG] dec_ctx=0x7ef4015f10, enc_ctx=0x7ef4015b50
```

**之后完全没有任何日志！**

**第二次通话统计（Line 6640-6641）**：
```
TX pt=100, size=640x480, fps=30.00, last update:never
total 0pkt 0B (0B +IP hdr) @avg=0bps/0bps
```

---

## 二、根本原因：死锁！

### 代码执行流程

```c
// Line 3070: ✅ 打印
PJ_LOG(1, "Closing codec, enc_ctx=%p", ff->enc_ctx);

// Line 3073: ✅ 打印
PJ_LOG(1, "🔍 [FIX 100.66 DIAG] dec_ctx=%p, enc_ctx=%p", ff->dec_ctx, ff->enc_ctx);
// → 日志显示：dec_ctx=0x7ef4015f10, enc_ctx=0x7ef4015b50（都不是NULL）

// Line 3075: ⚠️ 阻塞在这里！
pj_mutex_lock(ff_mutex);  // ← 永远无法获取锁！

// Line 3101: ❌ 从未执行
PJ_LOG(1, "🔍 [FIX 100.66 DIAG] Checking decoder...");
```

### 死锁原因

**`pj_mutex_lock(ff_mutex)` 被阻塞，无法获取锁！**

可能原因：
1. **其他线程持有 `ff_mutex` 但未释放**
2. **之前某次清理因异常退出，没有调用 `pj_mutex_unlock(ff_mutex)`**
3. **递归锁问题**（同一线程尝试二次获取同一个非递归锁）

### 后果

1. ✅ 第一次通话挂断时，`ffmpeg_codec_close()` 被阻塞
2. ❌ 清理代码从未执行
3. ❌ `pj_mutex_unlock(ff_mutex)` 从未被调用
4. ❌ `ff_mutex` 锁永远被持有
5. ❌ 第二次通话尝试使用编码器，但资源/锁被占用
6. ❌ 编码器无法编码任何帧（total 0pkt）

---

## 三、对比分析

### VERSION 129 vs VERSION 130

| 版本 | 问题 | 症状 |
|------|------|------|
| VERSION 129 | 清理代码未执行（原因未知）| 无清理日志，第二次通话0包 |
| VERSION 130 | **死锁在 pj_mutex_lock** | 打印了 dec_ctx/enc_ctx，但之后无日志 |

**关键发现**：
- VERSION 130 的诊断日志成功打印了 `dec_ctx` 和 `enc_ctx` 的地址
- 证明两个 context 都存在且有效
- 但代码在 `pj_mutex_lock(ff_mutex)` 处被阻塞

---

## 四、验证死锁的证据

### 证据 1：日志停止在 pj_mutex_lock 之前

```
Line 3073: PJ_LOG(...dec_ctx, enc_ctx...);  // ✅ 有日志
Line 3075: pj_mutex_lock(ff_mutex);         // ⚠️ 阻塞
Line 3101: PJ_LOG(...Checking decoder...);  // ❌ 无日志
```

### 证据 2：第二次通话编码器完全无输出

```
total 0pkt 0B (0B +IP hdr)
last update:never
```

**解释**：
- 第一次通话编码器资源没有释放（因为清理被阻塞）
- 第二次通话编码器初始化成功，但无法使用硬件资源
- 或者第二次通话编码器初始化时也尝试获取 `ff_mutex`，也被阻塞

### 证据 3：程序没有崩溃，但功能完全异常

- ✅ 程序仍在运行
- ✅ UI 可以操作
- ❌ 但视频编码器完全无法工作

这是**典型的死锁症状**：程序没有崩溃，但某些功能永久阻塞。

---

## 五、可能的死锁场景

### 场景 A：之前的清理异常退出

**假设**：
在 VERSION 130 之前的某个版本，清理代码可能因为异常退出（例如崩溃、提前返回），导致：
```c
pj_mutex_lock(ff_mutex);
// ... 异常发生，函数提前返回 ...
// pj_mutex_unlock(ff_mutex);  // ← 从未执行！
```

**结果**：
- `ff_mutex` 锁永远被持有
- 之后任何尝试获取此锁的操作都会被阻塞

### 场景 B：递归锁问题

**假设**：
同一个线程尝试二次获取同一个非递归锁：
```c
// Thread A 第一次调用 ffmpeg_codec_close
pj_mutex_lock(ff_mutex);  // ✅ 获取成功
// ... 在清理过程中，PJSIP 内部回调再次调用 ffmpeg_codec_close ...
pj_mutex_lock(ff_mutex);  // ❌ 死锁！
```

**结果**：
- 如果 `ff_mutex` 不是递归锁（recursive mutex）
- 同一线程尝试二次获取会导致死锁

### 场景 C：多线程竞争

**假设**：
多个线程同时调用 `ffmpeg_codec_close()`：
```
Thread A: pj_mutex_lock(ff_mutex);  // ✅ 获取成功，开始清理
Thread B: pj_mutex_lock(ff_mutex);  // ⏸️ 阻塞等待 Thread A 释放
```

但如果 Thread A 在清理过程中遇到问题（例如等待其他资源），可能导致：
- Thread A 持有 `ff_mutex` 但等待其他资源
- Thread B 等待 `ff_mutex`
- **循环等待 → 死锁**

---

## 六、解决方案

### Fix 100.67：移除 ff_mutex 锁（激进）⚠️

**理由**：
- `ffmpeg_codec_close()` 应该只被调用一次（每个 codec 生命周期）
- 如果 PJSIP 保证不会并发调用，锁是多余的

**风险**：
- 如果 PJSIP 确实会并发调用，移除锁可能导致竞态条件

### Fix 100.68：添加超时机制（保守）✅

**方案**：
使用 `pj_mutex_trylock()` 或者添加超时：
```c
pj_status_t status = pj_mutex_trylock(ff_mutex);
if (status != PJ_SUCCESS) {
    PJ_LOG(1, "⚠️ [FIX 100.68] Failed to acquire ff_mutex, forcing cleanup");
    // 强制清理，不等待锁
    goto force_cleanup;
}

// ... 正常清理 ...

pj_mutex_unlock(ff_mutex);
return PJ_SUCCESS;

force_cleanup:
    // 不持有锁的清理
    avcodec_close(ff->dec_ctx);
    avcodec_close(ff->enc_ctx);
    return PJ_SUCCESS;
```

### Fix 100.69：添加诊断日志确认死锁（最保守）✅ **推荐**

**方案**：
在 `pj_mutex_lock()` 前后添加日志：
```c
PJ_LOG(1, "⏳ [FIX 100.69 DIAG] Attempting to acquire ff_mutex...");
pj_mutex_lock(ff_mutex);
PJ_LOG(1, "✅ [FIX 100.69 DIAG] ff_mutex acquired successfully");
```

**目标**：
- 确认死锁位置
- 如果第一条日志打印但第二条不打印 → 证实死锁
- 如果两条都不打印 → 问题在更前面

---

## 七、建议的下一步

### 立即行动：Fix 100.69（诊断日志）

1. 在 `pj_mutex_lock(ff_mutex)` 前后添加诊断日志
2. 部署测试
3. 确认死锁位置

### 根据诊断结果决定

**如果确认死锁**：
- 使用 Fix 100.68（超时 + 强制清理）
- 或者调查为什么之前的清理没有 unlock

**如果不是死锁**：
- 重新分析为什么日志停止

---

## 八、关键洞察

### 洞察 1：Fix 100.66 的诊断成功

**成就**：
- 成功打印了 `dec_ctx=0x7ef4015f10, enc_ctx=0x7ef4015b50`
- 证明了 VERSION 129 的猜测：dec_ctx 和 enc_ctx 都存在

**价值**：
- 排除了 "context 为 NULL" 的假设
- 将问题定位到 `pj_mutex_lock()` 处

### 洞察 2：死锁是最危险的 bug

**特征**：
- 程序不崩溃
- 程序不报错
- 但功能完全失效

**难点**：
- 没有 core dump
- 没有错误码
- 只能通过日志位置推断

### 洞察 3：互斥锁需要异常安全

**问题**：
如果清理代码中有任何异常路径（提前返回、崩溃），必须确保 `pj_mutex_unlock()` 被调用。

**C 语言的困境**：
- 没有 RAII（C++ 的自动资源管理）
- 必须手动在每个返回路径 unlock
- 容易遗漏

---

## 九、总结

### 核心发现

1. ✅ **Fix 100.66 成功**：确认 dec_ctx 和 enc_ctx 都不是 NULL
2. ❌ **发现死锁**：`pj_mutex_lock(ff_mutex)` 阻塞
3. ❌ **清理代码从未执行**
4. ❌ **第二次通话编码器 0 包**

### 下一步

**Fix 100.69**：添加诊断日志确认死锁位置

---

**文档创建时间**: 2026-01-12 19:30
**分析者**: Claude Sonnet 4.5
**状态**: ⚠️ **死锁问题已识别，等待 Fix 100.69 验证**
