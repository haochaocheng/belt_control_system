# VERSION 135 崩溃全面分析 - 无日志输出之谜

**日期**: 2026-01-12 23:45
**重要性**: ⭐⭐⭐⭐⭐ **关键疑点**
**状态**: 🔍 **深度分析中**

---

## 一、问题现象

### 用户反馈
```
135测试解决，依然崩溃
```

### 崩溃信息
```
Application exited with code: 139

Core Dump:
#0  __GI___libc_free (mem=<optimized out>) at ./malloc/malloc.c:3375
#1  0x0000007fb1083500 in avcodec_close () from /app/lib/libavcodec.so.60
#2  0x000000557730e644 in ffmpeg_codec_close ()
#3  0x0000005577359bc4 in on_destroy ()
```

---

## 二、关键疑点

### ⚠️ 重大发现：完全没有 ffmpeg_codec_close() 日志

**预期日志**（应该在函数入口就打印）：
```c
PJ_LOG(1,(THIS_FILE, "🔍 [CODEC-CLOSE VERSION %d ENTRY] Function called", CODE_VERSION));
```

**实际日志**：
- ❌ 搜索 "CODEC-CLOSE VERSION 135"：无结果
- ❌ 搜索 "FIX 100.73"：无结果
- ❌ 搜索 "codec_data is NULL"：无结果

**崩溃前最后的日志**（Line ~1509）：
```
11:16:49.481             vid_conf.c  .Removed video port 0 (SDL renderer), port count=5
11:16:49.481             vid_port.c  .Destroying SDL renderer..
11:16:49.481              sdl_dev.c  .Stopping sdl video stream
11:16:49.509            pjsua_vid.c !.........✅ [FIX 71.2] Step 1: Slibv4l2: error dequeuing buf: Invalid argument

Application exited with code: 139
```

---

## 三、可能的原因分析

### 假设 1：日志缓冲未 flush

**理论**：
- `PJ_LOG` 使用缓冲输出
- 崩溃发生太快，缓冲未 flush 到文件
- 日志丢失

**支持证据**：
- ✅ 其他 `PJ_LOG(1)` 日志正常显示
- ✅ 启动日志显示 VERSION 135

**反对证据**：
- ❌ PJSIP 日志系统通常是即时的
- ❌ `PJ_LOG(1)` 是最高优先级，应该立即输出

**可能性**：🔴 低 (20%)

### 假设 2：崩溃在函数序言（Function Prologue）

**理论**：
- 崩溃发生在函数入口
- 在执行第一个 C 语句之前
- 栈帧设置时就失败

**支持证据**：
- ✅ 没有任何日志输出
- ✅ Core Dump 显示在 `ffmpeg_codec_close()` 中

**反对证据**：
- ❌ 函数序言只是栈指针调整，很少崩溃
- ❌ Core Dump 地址 `0x000000557730e644` 可能在函数中间

**可能性**：🟡 中等 (40%)

### 假设 3：调用了错误的函数版本

**理论**：
- 编译缓存问题
- 链接了旧版本的目标文件
- 实际运行的不是 VERSION 135

**支持证据**：
- ❌ 启动日志明确显示 VERSION 135
- ❌ build 脚本会清理缓存

**反对证据**：
- ✅ VERSION 135 启动日志正常显示
- ✅ 编码器初始化日志显示 VERSION 135

**可能性**：🔴 低 (10%)

### 假设 4：栈指针损坏

**理论**：
- 在调用 `ffmpeg_codec_close()` 之前，栈已损坏
- 函数调用时栈指针错误
- 无法正确设置栈帧

**支持证据**：
- ✅ GDB 显示 "Invalid register `rip`"
- ✅ 可能是栈已损坏的迹象

**反对证据**：
- ❌ 如果栈损坏，应该在调用时就崩溃，不应该在函数内

**可能性**：🟡 中等 (30%)

### 假设 5：PJ_LOG 宏本身有问题

**理论**：
- `THIS_FILE` 或 `CODE_VERSION` 导致问题
- 宏展开时访问了无效内存

**支持证据**：
- ✅ 可以解释为什么没有日志

**反对证据**：
- ❌ 其他地方的 `PJ_LOG(1, (THIS_FILE, ...))` 都正常
- ❌ 启动时的 `CODE_VERSION` 打印正常

**可能性**：🔴 极低 (5%)

---

## 四、验证步骤

### 步骤 1：验证代码是否正确部署 ✅

**检查源码**：
```powershell
grep -n "FIX 100.73" cross-compile\src\pjproject-2.16\pjmedia\src\pjmedia-codec\ffmpeg_vid_codecs.c
```

**结果**：
```
48:/* ✅ 2026-01-12 23:30 [FIX 100.73] 防止 codec_data 为 NULL 时的空指针解引用 */
3094:    /* ✅ 2026-01-12 23:30 [FIX 100.73] 防止 codec_data 为 NULL 时的空指针解引用
3118:        PJ_LOG(1,(THIS_FILE, "✅ [FIX 100.73] codec_data is NULL...
```

**结论**：✅ 代码已正确修改

### 步骤 2：验证编译路径 ✅

**检查 build 脚本**：
```powershell
grep "pjsipSourceDir" build-ubuntu24-apt.ps1
```

**结果**：
```
$pjsipSourceDir = "$ProjectRoot\cross-compile\src\pjproject-2.16"
```

**结论**：✅ 编译使用正确的源码路径

### 步骤 3：验证运行时版本 ✅

**启动日志**（Line 1193-1196）：
```
11:16:44.390    ffmpeg_vid_codecs.c  .......🔍 [STARTUP-VERSION] 135
11:16:44.390    ffmpeg_vid_codecs.c  .......   Fix 100.73: Add NULL check for codec_data in ffmpeg_codec_close() to prevent double-close crash
11:16:44.390    ffmpeg_vid_codecs.c  .......   Date: 2026-01-12
```

**结论**：✅ VERSION 135 正确运行

---

## 五、Core Dump 深度分析

### 调用栈
```
#0  __GI___libc_free (mem=<optimized out>) at ./malloc/malloc.c:3375
    ↑ free() 崩溃
#1  0x0000007fb1083500 in avcodec_close () from /app/lib/libavcodec.so.60
    ↑ FFmpeg 清理内部资源
#2  0x000000557730e644 in ffmpeg_codec_close ()
    ↑ 我们的函数
#3  0x0000005577359bc4 in on_destroy ()
    ↑ PJSIP 清理回调
```

### 关键问题

**Q1**: 为什么没有日志？
- 函数确实被调用了（在调用栈中）
- 但第一个 `PJ_LOG` 未执行

**Q2**: 崩溃在哪里？
- 不是在我们的 NULL 检查处（没有日志）
- 是在 `avcodec_close()` 内部的 `free()`

**Q3**: `avcodec_close()` 在哪里被调用？
- Line 3223：解码器清理
- Line 3293：编码器清理

### 可能的崩溃点

**猜测 1**：崩溃在进入函数时
```c
static pj_status_t ffmpeg_codec_close( pjmedia_vid_codec *codec )
{
    // ← 崩溃在这里？在设置栈帧时？
    ffmpeg_private *ff;
    pj_mutex_t *ff_mutex;
    PJ_LOG(1,(THIS_FILE, "..."));  // ← 未执行
}
```

**猜测 2**：崩溃在第一个日志语句
```c
PJ_LOG(1,(THIS_FILE, "🔍 [CODEC-CLOSE VERSION %d ENTRY] Function called", CODE_VERSION));
// ← 执行这一行时崩溃？但为什么？
```

**猜测 3**：日志确实执行了，但未 flush
```c
PJ_LOG(1,(THIS_FILE, "..."));  // ← 执行了
// ... 后续代码
avcodec_close(...);  // ← 崩溃在这里
// 日志缓冲未 flush
```

---

## 六、被忽略的线索

### 线索 1：GDB 显示 "Invalid register `rip`"

**含义**：
- `rip` 是 x86-64 的指令指针寄存器
- ARM64 应该是 `pc`（Program Counter）
- GDB 提示无效，可能是：
  - 栈帧损坏
  - GDB 配置问题
  - 符号表问题

### 线索 2：崩溃前的 v4l2 错误

**日志**（Line ~1509）：
```
libv4l2: error dequeuing buf: Invalid argument
```

**可能相关**：
- v4l2 摄像头驱动错误
- 可能导致某些资源状态异常
- 进而影响后续清理

### 线索 3：`on_destroy()` 调用

**这是关键**：
- 不是正常的 `pjmedia_vid_codec_close()` 路径
- 是 `on_destroy()` 回调中的调用
- 可能是第二次调用（Fix 100.73 应该防止）

---

## 七、下一步行动建议

### 方案 A：添加更强的诊断日志 ⭐⭐⭐⭐

**目的**：确定代码是否真的执行

**方法**：
1. 添加 `fprintf(stderr, ...)` 直接输出到 stderr
2. 在函数最开始添加，绕过 PJSIP 日志系统
3. 添加 `fflush(stderr)` 强制立即输出

**代码**：
```c
static pj_status_t ffmpeg_codec_close( pjmedia_vid_codec *codec )
{
    fprintf(stderr, "!!! ENTER ffmpeg_codec_close VERSION 135 !!!\n");
    fflush(stderr);

    ffmpeg_private *ff;
    ...
}
```

**优点**：
- ✅ 可靠，不依赖日志系统
- ✅ 强制 flush，不会丢失

**缺点**：
- ❌ 需要重新编译部署

### 方案 B：获取完整的 GDB backtrace ⭐⭐⭐⭐⭐

**目的**：获取更详细的调用栈和寄存器状态

**方法**：
1. 连接到设备
2. 使用 GDB 加载 core dump
3. 运行 `bt full` 获取完整调用栈
4. 运行 `info registers` 获取所有寄存器
5. 运行 `disassemble` 查看崩溃位置的汇编代码

**命令**：
```bash
ssh linaro@192.168.1.8
cd /tmp/belt-control-cores
gdb /app/belt_control_system core.pjsua_1.1.1768216609

(gdb) bt full
(gdb) info registers
(gdb) frame 2
(gdb) disassemble
(gdb) x/20i $pc-40
```

**优点**：
- ✅ 不需要重新编译
- ✅ 可以看到精确的崩溃位置

**缺点**：
- ❌ 需要手动操作

### 方案 C：检查是否有多线程竞争 ⭐⭐⭐

**目的**：确定是否有并发访问导致的内存损坏

**方法**：
1. 检查 `on_destroy()` 是否可能从多个线程调用
2. 检查是否有其他清理路径
3. 添加线程 ID 日志

### 方案 D：检查 FFmpeg 上下文状态 ⭐⭐

**目的**：确定 `enc_ctx` 和 `dec_ctx` 的状态

**方法**：
1. 在每个 `avcodec_close()` 调用前
2. 打印 `enc_ctx` 和 `dec_ctx` 的指针值
3. 检查是否已经被释放

---

## 八、暂停修改的原因

### 为什么不立即修改

1. **根本原因未确定**：
   - 我们不知道为什么没有日志
   - 不知道崩溃的精确位置
   - 不知道是否是新问题

2. **Fix 100.73 可能无效**：
   - 如果日志未执行，NULL 检查也未执行
   - 可能需要在更早的地方检查

3. **可能遗漏了关键信息**：
   - v4l2 错误可能相关
   - 栈损坏可能是根本原因
   - 需要更多证据

### 用户要求

> 全面排查，不要找一点可疑的就修改，修改前要全面的评估

**遵循原则**：
- ✅ 先彻底理解问题
- ✅ 收集完整信息
- ✅ 然后才决定修改方案

---

## 九、推荐的调查顺序

### 第一优先级：获取完整 GDB 分析 ⭐⭐⭐⭐⭐

**为什么**：
- 不需要重新编译
- 可以精确定位崩溃位置
- 可以看到汇编代码

**命令**：
```bash
# 方案 B 的命令
```

### 第二优先级：添加 stderr 诊断日志 ⭐⭐⭐⭐

**为什么**：
- 确定代码是否执行
- 不依赖日志系统
- 强制 flush

**修改**：
```c
// 方案 A 的代码
```

### 第三优先级：检查并发和线程安全 ⭐⭐⭐

**为什么**：
- `on_destroy()` 可能从多个线程调用
- 需要确保线程安全

---

## 十、待解答的关键问题

1. ❓ 为什么 `PJ_LOG(1)` 没有输出？
2. ❓ 崩溃的精确代码行是哪一行？
3. ❓ `on_destroy()` 是第几次调用 `ffmpeg_codec_close()`？
4. ❓ v4l2 错误是否导致了后续的内存损坏？
5. ❓ 栈指针是否真的损坏？
6. ❓ 是否有其他线程同时访问同一资源？

---

**文档创建时间**: 2026-01-12 23:45
**分析者**: Claude Sonnet 4.5
**状态**: 🔍 **等待更多证据**

**下一步**：
用户，我建议先执行**方案 B**（获取完整 GDB backtrace），这样我们可以精确知道崩溃发生在哪一行代码，而不需要重新编译部署。

您是否同意先获取更详细的 GDB 信息？
