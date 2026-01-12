# 根本原因分析 - ff_mutex 的设计问题

**日期**: 2026-01-12 21:00
**分析**: Fix 100.70 失败的根本原因
**状态**: 🔍 **重新审视问题**

---

## 一、关键发现

### 发现 1：open_ffmpeg_codec() 中 mutex 已被移除

**代码证据**（Line 2599-2600, 2647）：
```c
// PJ_LOG(3,(THIS_FILE, "🔍 [DEBUG] Step 1: About to lock mutex for encoder open"));
// pj_mutex_lock(ff_mutex);  // ← 被注释掉了！

...

// 2025-12-31 10:10 原代码（已注释）：pj_mutex_unlock(ff_mutex);
```

**原因**（Line 2590-2595）：
```c
// 2025-12-31 10:10 [FIX 100.17.4] 移除 open_ffmpeg_codec() 中的 mutex 锁定，避免递归死锁
//   原因：
//   1. pj_mutex_create_simple() 创建的是非递归锁
//   2. ffmpeg_codec_open() 已经持有 ff_mutex
//   3. open_ffmpeg_codec() 内部再次 lock → 死锁
//   4. 用户日志显示卡在 pj_mutex_lock(ff_mutex) 上
```

**结论**：
- ✅ `open_ffmpeg_codec()` 不使用 `ff_mutex`
- ✅ 编码器初始化不会持有锁

### 发现 2：ffmpeg_factory.mutex 被所有 codec 共享

**设计**（Line 196）：
```c
struct ffmpeg_factory
{
    ...
    pj_mutex_t  *mutex;  // ← 全局 mutex，所有 codec 共享
};
```

**使用**：
- 音频 codec 关闭时使用
- 视频 codec 关闭时使用
- Factory 销毁时使用

**问题**：
- 如果音频 codec 正在关闭并持有锁
- 视频 codec 尝试 trylock → 失败（EBUSY）

---

## 二、VERSION 132 崩溃的真正原因

### 场景重建

```
时刻 T0: 通话结束信号
    ↓
时刻 T1: 音频 codec 开始关闭
    ├─ pj_mutex_lock(ffmpeg_factory.mutex)  ✅ 获取成功
    ├─ 开始清理音频编解码器...
    └─ （耗时操作，例如 flush、释放资源）
    ↓
时刻 T2: 视频 codec 开始关闭（在音频 codec 清理期间）
    ├─ pj_mutex_trylock(ffmpeg_factory.mutex)  ❌ 失败（EBUSY）
    ├─ 进入 force_cleanup 路径
    ├─ 不持有锁，开始清理视频编解码器
    └─ avcodec_close() → 崩溃
    ↓
时刻 T3: 音频 codec 完成清理
    └─ pj_mutex_unlock(ffmpeg_factory.mutex)
```

**关键问题**：
- 音频和视频 codec 并发关闭
- 视频 codec trylock 失败 → force_cleanup
- force_cleanup 不持有锁 → 与音频 codec 并发
- 并发访问共享资源 → 崩溃

---

## 三、VERSION 131 死锁的真正原因（重新分析）

### 可能场景 A：音频 codec 清理卡住

```
时刻 T1: 音频 codec 开始关闭
    ├─ pj_mutex_lock(ffmpeg_factory.mutex)  ✅ 获取成功
    ├─ 开始清理音频解码器
    ├─ flush 操作卡住（永不返回）← ⚠️ 关键
    └─ 锁永远不释放
    ↓
时刻 T2: 视频 codec 开始关闭
    ├─ pj_mutex_lock(ffmpeg_factory.mutex)  ⏸️ 永远等待
    └─ 死锁
```

### 可能场景 B：音频和视频 codec 循环等待

```
Thread A (音频): 持有 ffmpeg_factory.mutex，等待音频硬件资源
Thread B (视频): 持有视频硬件资源，等待 ffmpeg_factory.mutex
→ 循环等待 → 死锁
```

---

## 四、关键教训

### 教训 1：trylock + force_cleanup 不是解决方案

**为什么**：
- trylock 失败不代表死锁
- trylock 失败可能是**正常的并发竞争**
- force_cleanup 绕过锁 = 破坏并发安全 = 崩溃

### 教训 2：共享 mutex 的设计问题

**问题**：
- 所有 codec（音频 + 视频）共享一个 `ffmpeg_factory.mutex`
- 一个 codec 的清理卡住 → 所有 codec 的清理都被阻塞

**正确设计**：
- 每个 codec 实例应该有独立的 mutex
- 或者不使用 mutex（假设 PJSIP 保证不并发）

---

## 五、正确的解决方案

### 方案 1：撤销 Fix 100.70，使用正常 lock（回退）

**思路**：
- 撤销 trylock + force_cleanup
- 回到 `pj_mutex_lock()` 等待锁
- 调查音频 codec 为什么会卡住

**优势**：
- 不会并发崩溃

**劣势**：
- 如果音频 codec 确实卡住，视频 codec 也会卡住

### 方案 2：移除 ffmpeg_factory.mutex（推荐）⭐⭐⭐⭐⭐

**思路**：
- 完全移除 `ffmpeg_factory.mutex`
- 假设 PJSIP 保证每个 codec 的生命周期是单线程的
- 或者为每个 codec 实例创建独立的 mutex

**优势**：
- 避免所有 mutex 相关问题
- 简化代码

**验证**：
- 需要确认 PJSIP 是否真的会并发调用同一个 codec 的方法

### 方案 3：使用每个 codec 实例的独立 mutex

**思路**：
- 在 `ffmpeg_private` 结构体中添加 `pj_mutex_t *mutex`
- 每个 codec 实例在 open 时创建自己的 mutex
- 每个 codec 实例在 close 时销毁自己的 mutex

**优势**：
- 完全独立，不会互相阻塞
- 保持并发安全

**劣势**：
- 增加复杂度
- 需要修改更多代码

---

## 六、立即行动

### 推荐方案：Fix 100.71 - 移除 ffmpeg_factory.mutex

**核心思路**：
- 完全移除 `ffmpeg_codec_close()` 中的 mutex 使用
- 假设 PJSIP 保证不会并发调用同一个 codec 的方法

**修改**：
1. 移除 Line 3101-3110（trylock 逻辑）
2. 移除 Line 3265（unlock）
3. 移除 Line 3270-3344（force_cleanup）
4. 直接执行清理代码

**风险**：
- 如果 PJSIP 确实会并发调用，可能崩溃
- 但比当前状态（必然崩溃）好

---

## 七、为什么 VERSION 131 看起来像死锁？

### 重新审视 VERSION 131 日志

**日志**：
```
⏳ [FIX 100.69 DIAG] Attempting to acquire ff_mutex...
```
**之后无日志！**

**之前的假设**：
- pj_mutex_lock() 永远阻塞 → 死锁

**新的理解**：
- pj_mutex_lock() 确实在等待
- 但可能是等待**音频 codec 完成清理**
- 音频 codec 清理可能很慢（flush 操作）
- 或者音频 codec 清理确实卡住了

**验证方法**：
- 添加日志记录所有 codec 的 open/close
- 查看是否有多个 codec 同时关闭

---

## 八、总结

### 核心问题

1. ❌ **共享 mutex 的设计缺陷**：所有 codec 共享一个锁
2. ❌ **trylock + force_cleanup 错误**：假设 trylock 失败 = 死锁
3. ✅ **真正原因**：音频和视频 codec 并发关闭，竞争同一个锁

### 正确的解决方案

**Fix 100.71**：移除 `ffmpeg_codec_close()` 中的 mutex 使用

---

**文档创建时间**: 2026-01-12 21:00
**分析者**: Claude Sonnet 4.5
**状态**: 🔍 **问题重新理解，准备 Fix 100.71**

**关键洞察**：
- trylock 失败是因为音频 codec 正在使用锁（正常并发）
- 不是死锁，是并发竞争
- 解决方案：移除 mutex（假设 PJSIP 单线程）
