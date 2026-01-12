# VERSION 132 测试分析 - force_cleanup 崩溃问题

**日期**: 2026-01-12 20:40
**测试版本**: VERSION 132
**状态**: ❌ **第一次通话就崩溃**

---

## 一、测试结果

### 用户反馈

- **第一次通话**：❌ **挂断后崩溃**
- **Exit code**: 139 (SIGSEGV - 段错误)

---

## 二、关键日志证据

### 崩溃时日志（Line 10749-10774）

```
06:17:14.459  🔍 [CODEC-CLOSE VERSION 132 ENTRY] Function called
06:17:14.459  🔍 [CODEC-CLOSE VERSION 132] codec pointer valid
06:17:14.459  🔍 [CODEC-CLOSE VERSION 132] Closing codec, enc_ctx=0x7f08015910
06:17:14.459  🔍 [FIX 100.66 DIAG] dec_ctx=0x7f08015cd0, enc_ctx=0x7f08015910
06:17:14.459  ⏳ [FIX 100.70] Attempting to acquire ff_mutex (trylock)...
06:17:14.459  ⚠️ [FIX 100.70] Failed to acquire ff_mutex (status=120016), forcing cleanup WITHOUT lock
06:17:14.459  ⚠️ [FIX 100.70 FORCE CLEANUP] Starting cleanup WITHOUT mutex protection
06:17:14.459  ⚠️ [FIX 100.70 FORCE CLEANUP] Decoder cleanup (skip flush, release hw_frames_ctx)
06:17:14.459    [FIX 100.70 FORCE CLEANUP] Closing decoder
06:17:14.461  ⚠️ [FIX 100.70 FORCE CLEANUP] Encoder cleanup (flush, release hw_frames_ctx)
06:17:14.461    [FIX 100.70 FORCE CLEANUP] Flushing encoder buffers
06:17:14.462    [FIX 100.70 FORCE CLEANUP] Encoder buffers flushed (1 packets)
06:17:14.462    [FIX 100.70 FORCE CLEANUP] Closing encoder

Application exited with code: 139
```

### Core Dump 分析（Line 11030-11034）

```
[1] 崩溃位置
#0  __GI___libc_free (mem=<optimized out>) at ./malloc/malloc.c:3375
#1  0x0000007f89723500 in avcodec_close () from /app/lib/libavcodec.so.60
#2  0x000000555f18e634 in ffmpeg_codec_close ()
```

---

## 三、根本原因分析

### 问题 1：trylock 失败（关键！）⭐⭐⭐⭐⭐

**日志证据**：
```
⚠️ [FIX 100.70] Failed to acquire ff_mutex (status=120016), forcing cleanup WITHOUT lock
```

**PJ 错误码分析**：
- `status=120016` = `PJ_STATUS_FROM_OS(16)` = `EBUSY`
- 含义：**锁已被其他线程持有**

**关键问题**：
- **这是第一次通话挂断**，为什么锁会被持有？
- 没有其他通话在进行，不应该有其他线程持有 `ff_mutex`

**可能原因**：
1. **编码器初始化时持有锁未释放**（最可能）
   - `ffmpeg_codec_open()` 中可能使用了 `ff_mutex`
   - 如果初始化时获取锁但未释放 → 挂断时 trylock 失败

2. **编码线程持有锁**
   - 编码线程正在使用 `ff_mutex` 保护某些操作
   - 挂断时 trylock 与编码线程竞争

3. **PJSIP 内部递归调用**
   - 同一线程在持有锁的情况下再次调用 `codec_close()`
   - 非递归锁导致死锁

### 问题 2：force_cleanup 崩溃

**崩溃栈**：
```
ffmpeg_codec_close() → avcodec_close() → free() → SIGSEGV
```

**崩溃位置**：
- 在 `avcodec_close()` 内部的 `free()` 调用崩溃
- 说明要释放的内存已经被释放（double-free）或被破坏

**根本原因**：
- force_cleanup 不持有 mutex 锁
- 与编码线程并发访问 `ff->enc_ctx`
- 编码线程可能正在使用或释放 `enc_ctx`
- 导致并发访问冲突 → `avcodec_close()` 崩溃

---

## 四、为什么 trylock 会失败？

### 假设 1：ffmpeg_codec_open() 持有锁未释放

**检查代码**：
需要查看 `ffmpeg_codec_open()` 是否使用了 `ff_mutex`

**如果是**：
- `ffmpeg_codec_open()` 获取 `ff_mutex`
- 但某个异常路径未释放锁
- 导致 `ffmpeg_codec_close()` trylock 失败

### 假设 2：编码线程正在使用锁

**检查代码**：
需要查看 `ffmpeg_codec_encode()` 是否使用了 `ff_mutex`

**如果是**：
- 编码线程在编码时获取 `ff_mutex`
- 挂断线程尝试 trylock 时锁被持有
- trylock 失败 → force_cleanup

### 假设 3：递归调用

**场景**：
- `ffmpeg_codec_close()` 获取 trylock 失败（status=EBUSY）
- 说明**当前线程已经持有这个锁**（非递归锁）
- 这是递归调用的特征

**验证**：
需要检查调用栈，看是否有递归调用

---

## 五、Fix 100.70 的问题

### 设计假设（错误）

**Fix 100.70 假设**：
- 死锁是因为之前的清理异常退出未释放锁
- trylock 失败 → 说明锁被持有且无法释放
- force_cleanup 可以绕过死锁

**实际情况**：
- trylock 失败 → 锁**正在被使用**（不是死锁）
- force_cleanup 不持有锁 → 与持有锁的线程并发
- 并发访问 `enc_ctx` → 崩溃

### 风险实现（错误）

**Fix 100.70 文档警告**：
> 风险：不持有锁的清理可能有竞态条件

**实际结果**：
- ✅ 警告正确
- ❌ 但低估了风险：不是"可能"竞态，而是"必然"竞态
- ❌ 竞态导致**第一次通话就崩溃**

---

## 六、正确的解决方案思路

### 方案 1：放弃 trylock，回退到 lock（不推荐）

**思路**：
- 撤销 Fix 100.70
- 回到 VERSION 131（死锁）
- 找到死锁的真正原因并修复

**劣势**：
- 回到原点
- 没有解决死锁问题

### 方案 2：找到 trylock 失败的根本原因（推荐）⭐

**思路**：
1. 检查 `ffmpeg_codec_open()` 是否使用 `ff_mutex`
2. 检查 `ffmpeg_codec_encode()` 是否使用 `ff_mutex`
3. 找到谁持有锁但未释放
4. 修复真正的问题

**优势**：
- 从根本解决问题
- 不需要 force_cleanup

### 方案 3：使用递归锁（可能）

**思路**：
- 将 `ff_mutex` 改为递归锁
- 允许同一线程多次获取锁

**优势**：
- 解决递归调用问题
- 简单直接

**劣势**：
- 如果不是递归调用问题，无效
- 可能掩盖其他问题

### 方案 4：移除 ff_mutex（激进）⚠️

**思路**：
- 完全移除 `ff_mutex`
- 假设 PJSIP 保证不并发调用

**优势**：
- 完全避免死锁和竞态

**劣势**：
- 如果 PJSIP 确实会并发调用，可能崩溃
- 需要验证 PJSIP 的线程模型

---

## 七、下一步行动

### 立即行动：调查 ff_mutex 的使用

**检查项**：
1. ✅ `ffmpeg_codec_open()` 中是否使用 `ff_mutex`
2. ✅ `ffmpeg_codec_encode()` 中是否使用 `ff_mutex`
3. ✅ `ffmpeg_codec_decode()` 中是否使用 `ff_mutex`
4. ✅ 所有使用 `ff_mutex` 的地方是否正确释放

### 诊断方案：Fix 100.71

**添加诊断日志**：
- 在所有 `pj_mutex_lock(ff_mutex)` 前后添加日志
- 记录获取锁的线程 ID
- 记录锁的持有时间
- 找到谁持有锁导致 trylock 失败

---

## 八、关键洞察

### 洞察 1：trylock 失败 ≠ 死锁

**误解**：
- Fix 100.70 假设 trylock 失败 = 死锁（锁永远被持有）

**事实**：
- trylock 失败 = 锁**正在被使用**（可能合法）
- 不能假设可以安全地绕过锁

### 洞察 2：force_cleanup 的风险被低估

**Fix 100.70 文档**：
> 风险：不持有锁的清理可能有竞态条件
> 但竞态风险 < 死锁风险

**实际情况**：
- ❌ 竞态风险 = 100%（第一次通话就崩溃）
- ❌ 竞态风险 >> 死锁风险
- ❌ 不持有锁的清理 = 必然崩溃

### 洞察 3：必须找到锁被持有的根本原因

**结论**：
- 不能绕过锁（trylock + force_cleanup）
- 必须找到为什么 trylock 会失败
- 修复真正持有锁的代码

---

## 九、总结

### 核心问题

1. ❌ **trylock 失败**：第一次通话挂断时，`ff_mutex` 已被持有
2. ❌ **force_cleanup 崩溃**：不持有锁导致并发访问 `enc_ctx`
3. ❌ **Fix 100.70 设计错误**：假设 trylock 失败 = 死锁

### 下一步

**Fix 100.71**：
1. 调查所有使用 `ff_mutex` 的代码
2. 添加诊断日志定位谁持有锁
3. 修复真正的问题（不是绕过）

---

**文档创建时间**: 2026-01-12 20:40
**分析者**: Claude Sonnet 4.5
**状态**: ❌ **Fix 100.70 失败，需要 Fix 100.71**

**关键教训**：
- ✅ trylock 失败 ≠ 死锁
- ✅ 不能假设可以安全地绕过锁
- ✅ 必须找到锁被持有的根本原因
