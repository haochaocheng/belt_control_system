# 修复 91：FFmpeg 6.0 分支添加 EAGAIN 错误处理

**日期**：2026-01-09 09:24（北京时间）
**问题编号**：Fix 91
**严重程度**：🔴 严重 - Fix 90 代码执行了但没有处理 EAGAIN 错误
**状态**：✅ 代码已修改，待编译验证
**版本号**：CODE_VERSION 91

---

## 问题背景

### Fix 90 测试结果

**Line 1573 of voip.md**：
```
13:20:06.319    ffmpeg_vid_codecs.c !🔍 [DEBUG-VERSION] FFmpeg 6.0+ branch, receive_frame err=-11, format=-1
13:20:06.319     vstdec0x7f400106e0  codec decode() error: Bad or corrupted bitstream (PJMEDIA_CODEC_EBADBITSTREAM)
```

**关键发现**：
1. ✅ `[DEBUG-VERSION]` 日志出现了 → **代码是最新的**
2. ❌ `err=-11` (AVERROR(EAGAIN)) → 需要更多输入数据
3. ❌ `format=-1` → 帧数据无效（还没成功解码）
4. ❌ 返回 `EBADBITSTREAM` 错误 → 解码流程中断

### 用户反馈
```
"新测试已经完成，依然崩溃"
"新改代码新增自动判断机制，确保一定是最新代码"
"你这个日期不对，我北京时间是9点24"
```

---

## 根本原因分析

### FFmpeg 6.0 分支缺少 EAGAIN 处理

**ffmpeg_vid_codecs.c Line 3407-3410（修改前）**：

```c
if (err >= 0) {
    got_picture = PJ_TRUE;
}
// ❌ 没有 else 分支处理 EAGAIN！
```

**问题流程**：
1. `avcodec_receive_frame()` 返回 `-11` (EAGAIN)
2. `err >= 0` = FALSE → `got_picture` 未设置（保持初始值 0）
3. Line 3492 `if (err < 0)` = TRUE → 进入错误处理
4. 返回 `PJMEDIA_CODEC_EBADBITSTREAM`
5. 上层认为解码失败，停止喂数据
6. 程序崩溃

### 旧分支（Line 3480-3486）有正确处理

```c
if (err == 0) {
    got_picture = PJ_TRUE;
} else if (err == AVERROR(EAGAIN) || err == AVERROR_EOF) {
    /* EAGAIN: 需要更多输入数据; EOF: 解码结束 */
    err = 0;              // ← 清除错误码
    got_picture = PJ_FALSE;  // ← 告诉上层"没有图片，继续喂数据"
}
```

### 为什么 EAGAIN 需要特殊处理

FFmpeg 新 API (`avcodec_send_packet` / `avcodec_receive_frame`) 的工作机制：

1. **EAGAIN 的含义**：
   - "Not enough data, send more packets"
   - 这 **不是错误**，是正常状态
   - 类似于 "缓冲区未满，请继续输入"

2. **正确的处理**：
   ```c
   err = 0;            // 清除"错误"标志
   got_picture = FALSE;  // 告诉上层：这次没解出图片
   return PJ_SUCCESS;    // 返回成功，继续下一帧
   ```

3. **错误的处理**（修改前）：
   ```c
   // err 保持 -11
   // got_picture 未设置
   if (err < 0) {
       return PJMEDIA_CODEC_EBADBITSTREAM;  // ❌ 返回错误！
   }
   ```

---

## 解决方案

### 修复 91：在 FFmpeg 6.0 分支添加 EAGAIN 处理

**修改文件**：`cross-compile/src/pjproject-2.16/pjmedia/src/pjmedia-codec/ffmpeg_vid_codecs.c`

**修改位置**：Line 3424-3437

```c
        }

        /* ✅ 2026-01-09 09:24 [修复 91] 添加 EAGAIN 错误处理
         * 问题：err=-11 (EAGAIN) 时没有清除错误，导致返回 EBADBITSTREAM
         * 根因：FFmpeg 6.0 分支缺少 EAGAIN 处理，旧分支（Line 3482）有
         * 策略：EAGAIN 表示需要更多数据，设置 err=0, got_picture=FALSE
         * 效果：程序继续喂数据，直到解码成功（format=179）
         * 版本：CODE_VERSION 91
         */
        if (err == 0) {
            got_picture = PJ_TRUE;
        } else if (err == AVERROR(EAGAIN) || err == AVERROR_EOF) {
            PJ_LOG(3,(THIS_FILE, "🔍 [FIX 91] Handle EAGAIN/EOF: err=%d, clearing error", err));
            err = 0;
            got_picture = PJ_FALSE;
        }
    }
```

### 新增：版本号自动判断机制

**修改位置 1**：Line 48-50（文件头部）

```c
#define THIS_FILE   "ffmpeg_vid_codecs.c"

/* ✅ 2026-01-09 09:24 [版本控制] 自动判断机制
 * 用途：每次修改代码时更新版本号，运行时自动验证
 * 使用：在函数开始时打印 CODE_VERSION，确认使用了最新代码
 * 更新：每次修改时递增版本号，无需条件判断即可验证
 */
#define CODE_VERSION 91
#define CODE_DATE "2026-01-09 09:24"
#define CODE_DESCRIPTION "Fix 91: Add EAGAIN error handling to FFmpeg 6.0+ branch"
```

**修改位置 2**：Line 3291-3297（解码函数开始）

```c
    /* Check if decoder has been opened */
    PJ_ASSERT_RETURN(ff->dec_ctx, PJ_EINVALIDOP);

    /* ✅ 2026-01-09 09:24 [版本验证] 启动时打印版本号 */
    static pj_bool_t version_printed = PJ_FALSE;
    if (!version_printed) {
        PJ_LOG(3,(THIS_FILE, "🔍 [CODE-VERSION] %d - %s (%s)",
                  CODE_VERSION, CODE_DESCRIPTION, CODE_DATE));
        version_printed = PJ_TRUE;
    }
```

---

## 代码变更对比

### 修改前（Line 3407-3410）

```c
if (err >= 0) {
    got_picture = PJ_TRUE;
}
```

**问题**：
- `err=-11` 时，`err >= 0` = FALSE
- `got_picture` 未设置（值为 0）
- Line 3492 `if (err < 0)` 成立 → 返回错误

### 修改后（Line 3424-3437）

```c
if (err == 0) {
    got_picture = PJ_TRUE;
} else if (err == AVERROR(EAGAIN) || err == AVERROR_EOF) {
    PJ_LOG(3,(THIS_FILE, "🔍 [FIX 91] Handle EAGAIN/EOF: err=%d, clearing error", err));
    err = 0;
    got_picture = PJ_FALSE;
}
```

**改进**：
- `err=-11` 时，进入 `else if` 分支
- 清除 `err=0`，设置 `got_picture=FALSE`
- Line 3492 `if (err < 0)` 不成立 → 正常返回
- 上层继续喂数据

---

## 预期效果

### 成功标志

测试日志应该出现：

```
🔍 [CODE-VERSION] 91 - Fix 91: Add EAGAIN error handling to FFmpeg 6.0+ branch (2026-01-09 09:24)
🔍 [DEBUG-VERSION] FFmpeg 6.0+ branch, receive_frame err=-11, format=-1
🔍 [FIX 91] Handle EAGAIN/EOF: err=-11, clearing error
🔍 [DEBUG-VERSION] FFmpeg 6.0+ branch, receive_frame err=0, format=179
🔍 [FIX 90] Detected DRM_PRIME in FFmpeg 6.0+ branch
✅ [FIX 90] DRM_PRIME → yuv420p conversion SUCCESS
```

### 解决的问题

1. **EAGAIN 正确处理**：不再误判为错误，程序继续喂数据
2. **解码流程正常**：持续解码，直到 `err=0, format=179`
3. **DRM_PRIME 转换执行**：format=179 时触发 Fix 90 的转换逻辑
4. **格式转换成功**：179 → 0/23（I420/NV12）
5. **程序不再崩溃**：解码成功，视频正常显示

---

## 版本号机制说明

### 工作原理

1. **每次修改时递增版本号**：
   ```c
   #define CODE_VERSION 91  // ← 从 90 递增到 91
   ```

2. **程序启动时自动打印**：
   ```c
   PJ_LOG(3,(THIS_FILE, "🔍 [CODE-VERSION] 91 - Fix 91: Add EAGAIN error handling to FFmpeg 6.0+ branch (2026-01-09 09:24)"));
   ```

3. **无需条件判断即可验证**：
   - 日志中出现 `[CODE-VERSION] 91` → 使用了最新代码
   - 日志中没有或版本号旧 → 使用了旧代码

### 使用方法

**未来修改代码时**：

```c
// 1. 更新版本号
#define CODE_VERSION 92
#define CODE_DATE "2026-01-09 10:30"
#define CODE_DESCRIPTION "Fix 92: Description of the fix"

// 2. 程序启动时自动打印版本号（无需修改）
// 3. 测试日志中查找 [CODE-VERSION] 92 即可验证
```

---

## 下一步

### 1. 验证代码修改

```bash
grep -n "CODE_VERSION\|FIX 91" cross-compile/src/pjproject-2.16/pjmedia/src/pjmedia-codec/ffmpeg_vid_codecs.c
```

应该看到：
- Line 48: `#define CODE_VERSION 91`
- Line 3294: `PJ_LOG(3,(THIS_FILE, "🔍 [CODE-VERSION] %d`
- Line 3434: `PJ_LOG(3,(THIS_FILE, "🔍 [FIX 91] Handle EAGAIN/EOF`

### 2. 重新编译

```powershell
.\build-ubuntu24-apt.ps1 188
```

### 3. 测试验证

在设备上运行视频通话，检查 `docs/log/voip.md`：

**期望日志**：
```
🔍 [CODE-VERSION] 91 - Fix 91: Add EAGAIN error handling to FFmpeg 6.0+ branch (2026-01-09 09:24)
🔍 [DEBUG-VERSION] FFmpeg 6.0+ branch, receive_frame err=-11, format=-1
🔍 [FIX 91] Handle EAGAIN/EOF: err=-11, clearing error
...（继续解码）...
🔍 [DEBUG-VERSION] FFmpeg 6.0+ branch, receive_frame err=0, format=179
🔍 [FIX 90] Detected DRM_PRIME in FFmpeg 6.0+ branch
✅ [FIX 90] DRM_PRIME → yuv420p conversion SUCCESS
```

---

## 技术总结

### Fix 91 vs Fix 90

| 修复 | 问题 | 解决方案 | 效果 |
|------|------|---------|------|
| Fix 90 | DRM_PRIME 转换代码在旧分支 | 在 FFmpeg 6.0 分支添加转换代码 | ✅ 代码执行了 |
| Fix 91 | EAGAIN 被误判为错误 | 添加 EAGAIN 处理，清除错误 | ⏳ 待验证 |

### 根本原因链

```
1. FFmpeg 6.0 条件编译分支被使用
   ↓
2. 该分支缺少 DRM_PRIME 转换（Fix 90 已修复）
   ↓
3. 该分支缺少 EAGAIN 处理（Fix 91 修复）
   ↓
4. err=-11 被当作错误 → 返回 EBADBITSTREAM
   ↓
5. 上层停止喂数据
   ↓
6. 解码器永远收不到完整数据 → format 永远是 -1
   ↓
7. 程序崩溃
```

### Fix 91 的关键作用

**修改前**：
```
avcodec_receive_frame() → err=-11 → EBADBITSTREAM → 解码失败
```

**修改后**：
```
avcodec_receive_frame() → err=-11 → err=0, got_picture=FALSE → 继续喂数据
avcodec_receive_frame() → err=0, format=179 → Fix 90 转换 → 解码成功
```

---

## 相关文档

- [18-修复90-FFmpeg6.0分支添加DRM_PRIME转换.md](../2026-01-08/18-修复90-FFmpeg6.0分支添加DRM_PRIME转换.md)
- [16-修复89-在receive_frame后立即转换DRM_PRIME.md](../2026-01-08/16-修复89-在receive_frame后立即转换DRM_PRIME.md)
- [17-修复89实施完成-代码修改总结.md](../2026-01-08/17-修复89实施完成-代码修改总结.md)
