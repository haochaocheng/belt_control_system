# VERSION 129 测试分析 - 清理代码未执行

**日期**: 2026-01-12 19:15
**测试版本**: VERSION 129
**状态**: ❌ **清理代码未执行**

---

## 一、测试结果

### 用户反馈

- **第一次通话**：✅ 正常，双方能看到画面
- **第二次通话**：❌ **本机画面卡住，对方看不到视频**
- **程序状态**：✅ 没有崩溃
- **挂断状态**：✅ 对方挂断后，本机显示也挂断

### 日志证据

**第一次挂断（Line 4778-4780）**：
```
04:19:14.592  🔍 [CODEC-CLOSE VERSION 129 ENTRY] Function called
04:19:14.592  🔍 [CODEC-CLOSE VERSION 129] codec pointer valid
04:19:14.592  🔍 [CODEC-CLOSE VERSION 129] Closing codec, enc_ctx=0x7ee8015280
```

**关键问题**：
- ✅ CODEC-CLOSE 函数被调用
- ✅ codec 指针有效
- ✅ enc_ctx 指针有效（0x7ee8015280）
- ❌ **没有任何 Fix 100.65.2 解码器清理日志**
- ❌ **没有任何 Fix 100.50 编码器清理日志**

**第二次通话统计（Line 6945-6946）**：
```
TX pt=100, size=640x480, fps=30.00, last update:never
total 0pkt 0B (0B +IP hdr) @avg=0bps/0bps
```

**关键问题**：
- ✅ 编码器初始化成功（VERSION 129）
- ✅ 摄像头打开成功（640x480@30fps）
- ❌ **编码器没有发送任何视频包（0pkt）**
- ❌ **last update:never**（编码器从未更新）

---

## 二、根本原因分析

### 代码执行流程

```c
static pj_status_t ffmpeg_codec_close( pjmedia_vid_codec *codec )
{
    // Line 3060: ✅ 打印
    PJ_LOG(1, "CODEC-CLOSE VERSION 129 ENTRY");

    // Line 3062: ✅ 通过
    PJ_ASSERT_RETURN(codec, PJ_EINVAL);

    // Line 3064: ✅ 打印
    PJ_LOG(1, "codec pointer valid");

    // Line 3066-3067: ✅ 执行
    ff = (ffmpeg_private*)codec->codec_data;
    ff_mutex = ((struct ffmpeg_factory*)codec->factory)->mutex;

    // Line 3070: ✅ 打印
    PJ_LOG(1, "Closing codec, enc_ctx=%p", ff->enc_ctx);

    // Line 3075: ✅ 执行
    pj_mutex_lock(ff_mutex);

    // Line 3104: ❌ 这里之后没有任何日志！
    if (ff->dec_ctx && ff->dec_ctx != ff->enc_ctx) {
        // ... 解码器清理 ...
    }

    // Line 3159: ❌ 这里也没有任何日志！
    if (ff->enc_ctx) {
        // ... 编码器清理 ...
    }

    // Line 3223: ❌ 应该到这里，但没有日志证明
    ff->enc_ctx = NULL;
    ff->dec_ctx = NULL;
    pj_mutex_unlock(ff_mutex);

    return PJ_SUCCESS;
}
```

### 可能的原因

**假设 1**：`ff->dec_ctx` 和 `ff->enc_ctx` 都是 NULL
- `if (ff->dec_ctx && ...)` → FALSE，跳过解码器清理
- `if (ff->enc_ctx)` → FALSE，跳过编码器清理
- 直接到 Line 3223，设置为 NULL 并返回

**假设 2**：`ff->dec_ctx == ff->enc_ctx`
- `if (ff->dec_ctx && ff->dec_ctx != ff->enc_ctx)` → FALSE
- 只清理一次（在编码器部分）
- 但日志显示编码器清理也没有执行

**假设 3**（最不可能）：代码在 `pj_mutex_lock()` 后被其他线程抢占
- 但程序没有崩溃，也没有卡住，这不太可能

---

## 三、Fix 100.66 诊断方案

### 目标

**确认 `ff->dec_ctx` 和 `ff->enc_ctx` 的实际值**

### 实施内容

**文件**: `ffmpeg_vid_codecs.c`
**版本**: 129 → 130

#### 修改 1: 添加 dec_ctx/enc_ctx 状态日志（Line 3072-3073）

```c
/* ✅ 2026-01-12 19:10 [FIX 100.66 DIAG] 添加诊断日志检查 dec_ctx 和 enc_ctx 状态 */
PJ_LOG(1,(THIS_FILE, "🔍 [FIX 100.66 DIAG] dec_ctx=%p, enc_ctx=%p", ff->dec_ctx, ff->enc_ctx));
```

#### 修改 2: 添加解码器条件检查日志（Line 3101-3105）

```c
/* ✅ STEP 1: 先清理解码器 */
PJ_LOG(1,(THIS_FILE, "🔍 [FIX 100.66 DIAG] Checking decoder: dec_ctx=%p, enc_ctx=%p, condition=%d",
          ff->dec_ctx, ff->enc_ctx, (ff->dec_ctx && ff->dec_ctx != ff->enc_ctx) ? 1 : 0));

if (ff->dec_ctx && ff->dec_ctx != ff->enc_ctx) {
    PJ_LOG(1,(THIS_FILE, "✅ [FIX 100.66 DIAG] Entering decoder cleanup"));
    // ... 清理代码 ...
}
```

#### 修改 3: 添加编码器条件检查日志（Line 3156-3160）

```c
/* ✅ STEP 2: 后清理编码器 */
PJ_LOG(1,(THIS_FILE, "🔍 [FIX 100.66 DIAG] Checking encoder: enc_ctx=%p, condition=%d",
          ff->enc_ctx, ff->enc_ctx ? 1 : 0));

if (ff->enc_ctx) {
    PJ_LOG(1,(THIS_FILE, "✅ [FIX 100.66 DIAG] Entering encoder cleanup"));
    // ... 清理代码 ...
}
```

---

## 四、预期诊断结果

### 场景 A：dec_ctx 和 enc_ctx 都是 NULL

**日志**：
```
🔍 [CODEC-CLOSE VERSION 130 ENTRY] Function called
🔍 [CODEC-CLOSE VERSION 130] codec pointer valid
🔍 [CODEC-CLOSE VERSION 130] Closing codec, enc_ctx=(nil)
🔍 [FIX 100.66 DIAG] dec_ctx=(nil), enc_ctx=(nil)
🔍 [FIX 100.66 DIAG] Checking decoder: dec_ctx=(nil), enc_ctx=(nil), condition=0
🔍 [FIX 100.66 DIAG] Checking encoder: enc_ctx=(nil), condition=0
```

**结论**：
- PJSIP 已经在其他地方释放了编解码器
- ffmpeg_codec_close() 被重复调用
- **问题在更上层**（可能是 PJSIP 内部逻辑）

### 场景 B：dec_ctx == enc_ctx（共享同一个 context）

**日志**：
```
🔍 [FIX 100.66 DIAG] dec_ctx=0x7ee8015280, enc_ctx=0x7ee8015280
🔍 [FIX 100.66 DIAG] Checking decoder: dec_ctx=0x..., enc_ctx=0x..., condition=0
🔍 [FIX 100.66 DIAG] Checking encoder: enc_ctx=0x7ee8015280, condition=1
✅ [FIX 100.66 DIAG] Entering encoder cleanup
✅ [FIX 100.50 Step 1/3] Flushing encoder buffers
...
```

**结论**：
- 编解码器共享同一个 context
- 只需要清理一次（在编码器部分）
- 但为什么 VERSION 129 没有执行编码器清理？

### 场景 C：dec_ctx 或 enc_ctx 被破坏（野指针）

**日志**：
```
🔍 [FIX 100.66 DIAG] dec_ctx=0xdeadbeef, enc_ctx=0x7ee8015280
```

**结论**：
- 内存损坏
- **严重问题**，需要检查内存管理

---

## 五、下一步

### 1. 部署 VERSION 130

```powershell
.\build-ubuntu24-apt.ps1 192.168.1.8
```

### 2. 测试并查看日志

**关键期望**：
```
🔍 [FIX 100.66 DIAG] dec_ctx=???, enc_ctx=???
🔍 [FIX 100.66 DIAG] Checking decoder: ..., condition=?
🔍 [FIX 100.66 DIAG] Checking encoder: ..., condition=?
```

### 3. 根据日志结果决定下一步

- **场景 A** → 调查 PJSIP 内部为何提前释放
- **场景 B** → 理解共享 context 的设计
- **场景 C** → 追踪内存损坏源头

---

## 六、关键洞察

### 洞察 1：清理代码的静默失败

**问题**：
- 代码没有崩溃
- 代码没有卡住
- 但清理代码就是没有执行

**原因**：
- 条件检查失败（`if` 语句返回 FALSE）
- 没有日志证明条件检查的结果

**教训**：
- **所有条件检查都必须有日志**
- 不仅要记录 "执行了什么"，还要记录 "为什么不执行"

### 洞察 2：第二次通话编码器 0 包的原因

**推测**：
如果第一次通话的编码器没有被正确清理（因为 `ff->enc_ctx` 已经是 NULL），那么第二次通话：
1. PJSIP 创建新的编码器 context
2. 但 RKMPP 硬件设备状态异常（因为第一次没有清理）
3. 编码器初始化成功，但无法编码任何帧

---

## 七、总结

### 核心发现

1. ❌ **VERSION 129 清理代码完全没有执行**
2. ❌ **没有任何解码器清理日志**
3. ❌ **没有任何编码器清理日志**
4. ❌ **第二次通话编码器 0 包发送**

### Fix 100.66 目标

**诊断 `ff->dec_ctx` 和 `ff->enc_ctx` 的实际值**

**确认清理代码为何未执行**

---

**文档创建时间**: 2026-01-12 19:15
**分析者**: Claude Sonnet 4.5
**状态**: ✅ **Fix 100.66 诊断方案已完成，等待测试**
