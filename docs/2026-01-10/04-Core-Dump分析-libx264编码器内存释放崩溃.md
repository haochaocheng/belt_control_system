# Core Dump 分析：libx264 编码器内存释放崩溃

**日期**: 2026-01-10 18:30
**问题编号**: 分析报告
**崩溃类型**: SIGSEGV（段错误）
**状态**: ✅ 已定位根本原因

---

## 📋 崩溃信息

### Core Dump 文件
- **文件**: `/tmp/belt-control-cores/core.pjsua_1.1.1768009838`
- **分析报告**: `/tmp/belt-control-cores/core.pjsua_1.1.1768009838.analysis.txt`
- **进程**: pjsua_1 (PID 61)

### 崩溃堆栈
```
[1] 崩溃位置
#0  __GI___libc_free (mem=<optimized out>) at ./malloc/malloc.c:3375
#1  0x0000007f84253500 in avcodec_close () from /app/lib/libavcodec.so.60
#2  0x0000007f84391734 in avcodec_open2 () from /app/lib/libavcodec.so.60
#3  0x00000055735b2078 in open_ffmpeg_codec.isra ()
```

---

## 🔍 崩溃分析

### 1. 崩溃位置
**Frame 0**: `__GI___libc_free()` - C 标准库的内存释放函数
- **文件**: `malloc/malloc.c:3375`
- **操作**: 释放内存时访问了无效地址
- **原因**: 试图释放一个无效指针或已损坏的内存块

### 2. 调用链分析

#### Frame 1: `avcodec_close()`
- **来源**: `/app/lib/libavcodec.so.60` (FFmpeg 编解码器库)
- **功能**: 关闭编解码器，清理资源
- **行为**: 调用 `free()` 释放编解码器上下文的内存

#### Frame 2: `avcodec_open2()`
- **来源**: `/app/lib/libavcodec.so.60`
- **功能**: 打开并初始化编解码器
- **关键**: 初始化失败后自动调用 `avcodec_close()` 清理

#### Frame 3: `open_ffmpeg_codec.isra()`
- **来源**: PJSIP 编解码器适配层
- **功能**: 调用 FFmpeg 打开编解码器

---

## 💡 根本原因分析

### 崩溃场景推测
```
1. PJSIP 调用 open_ffmpeg_codec()
   ↓
2. 内部调用 avcodec_open2() 初始化 libx264 编码器
   ↓
3. libx264 初始化失败（原因：格式不兼容）
   ↓
4. avcodec_open2() 检测到失败，自动调用 avcodec_close()
   ↓
5. avcodec_close() 试图释放未正确初始化的上下文
   ↓
6. free() 访问无效指针 → SIGSEGV 崩溃 ❌
```

### 为什么初始化失败？

根据之前的分析（[docs/2026-01-09/72-Core-Dump分析-编码器初始化崩溃根因.md](../2026-01-09/72-Core-Dump分析-编码器初始化崩溃根因.md)）：

**格式不兼容**：
```
RKMPP 解码器输出：
  - 格式：DRM_PRIME (179)
  - 描述：DRM 内核驱动 zero-copy 格式
  - 特点：GPU 内存，不在用户空间

libx264 编码器期望：
  - 格式：I420 (0)
  - 描述：YUV420P 平面格式
  - 特点：系统内存，用户可访问

结果：格式转换失败 → 初始化失败 → 清理崩溃
```

### 为什么清理会崩溃？

**double-free 或 use-after-free**：
- 编解码器初始化时部分分配了内存
- 初始化中途失败，部分指针未设置或设置为无效值
- `avcodec_close()` 试图释放这些未初始化/无效的指针
- `free()` 检测到无效指针 → 段错误

---

## 📊 日志证据

### 编码器信息（崩溃前）
```
Encoder: libx264rgb
Encoder context: width=768, height=432, pix_fmt=0, bitrate=800000
```

### 解码器信息（崩溃前）
```
✅ [FIX 84] RKMPP decoder opened successfully (hybrid mode)
   Decoder output format: 179 (expected: 23=NV12 or 0=I420)
   Decoder dimensions: 720x480
   ⚠️ Unexpected format 179! May cause compatibility issues.
      Expected: 23 (NV12) or 0 (I420)
```

**关键矛盾**：
- 解码器输出：格式 179（DRM_PRIME）
- 编码器期望：格式 0（I420）
- 没有有效的格式转换路径

---

## ✅ 解决方案

### 已有方案：使用硬件编码器

根据 [Fix 100.12](../2026-01-09/73-Fix100.12-硬件编码器解决DRM_PRIME问题.md)：

**方案**：使用 `h264_rkmpp` 硬件编码器替代 `libx264`
- ✅ 原生支持 DRM_PRIME 格式（179）
- ✅ 零拷贝（GPU → VPU，无需 CPU 介入）
- ✅ 性能更好（~1% CPU vs ~40% CPU）

**实施状态**：
- ✅ Fix 97 已实现硬件编码器支持
- ✅ 默认启用：`USE_HARDWARE_ENCODER=1`
- ❌ **问题发现**：run 脚本中未设置环境变量！

### 修复实施（2026-01-10 18:35）

**修改** build-ubuntu24-apt.ps1 (line 1587)：
```bash
sudo docker run \
    ...
    -e FFMPEG_HW_OPTS \
    -e USE_HARDWARE_ENCODER=1 \    # ✅ 新增：启用硬件编码器
    -e XDG_RUNTIME_DIR=/tmp \
    ...
```

**预期效果**：
- ✅ 编码器将使用 `h264_rkmpp` 而非 `libx264rgb`
- ✅ DRM_PRIME 格式直接传递给硬件编码器
- ✅ 不再崩溃
- ✅ CPU 使用率降低到 ~1%

---

## 🧪 验证步骤

### 1. 启用硬件编码器
```bash
# 在容器启动前设置环境变量
export USE_HARDWARE_ENCODER=1

# 或在 docker run 中添加
docker run ... -e USE_HARDWARE_ENCODER=1 ...
```

### 2. 查看日志确认
崩溃前应该看到：
```
✅ [FIX 97] USE_HARDWARE_ENCODER=1: Trying hardware encoder first
   Encoder: h264_rkmpp (hardware)
   Strategy: DRM_PRIME zero-copy (GPU → VPU)
```

### 3. 验证不再崩溃
- ✅ 编码器初始化成功
- ✅ 视频通话正常
- ✅ CPU 使用率 ~1%

---

## 📚 技术细节

### 为什么 libx264 无法处理 DRM_PRIME？

**DRM_PRIME 格式特性**：
- 内存位置：GPU 显存（不在系统 RAM）
- 访问方式：DMA（直接内存访问）
- 用户空间：无法直接读取像素数据

**libx264 要求**：
- 内存位置：系统 RAM
- 访问方式：CPU 读写
- 像素格式：I420（平面 YUV）

**结果**：libx264 无法访问 GPU 内存 → 初始化失败

### 为什么硬件编码器可以？

**h264_rkmpp 特性**：
- 直接操作 GPU 内存（通过 DRM API）
- 使用 VPU（视频处理单元）硬件编码
- 支持 zero-copy（GPU → VPU，无需 CPU）

**结果**：DRM_PRIME → VPU 直接传输 → 编码成功

---

## 🔗 相关文档

1. **Core Dump 根因分析**: [docs/2026-01-09/72-Core-Dump分析-编码器初始化崩溃根因.md](../2026-01-09/72-Core-Dump分析-编码器初始化崩溃根因.md)
2. **硬件编码器解决方案**: [docs/2026-01-09/73-Fix100.12-硬件编码器解决DRM_PRIME问题.md](../2026-01-09/73-Fix100.12-硬件编码器解决DRM_PRIME问题.md)
3. **自动 Core Dump 分析**: [docs/2026-01-10/01-工作总结-自动Core-Dump分析集成.md](01-工作总结-自动Core-Dump分析集成.md)
4. **启用 Core Dump**: [docs/2026-01-10/03-启用Core-Dump功能.md](03-启用Core-Dump功能.md)

---

## 📝 总结

### 崩溃根因
1. **直接原因**: `free()` 访问无效指针
2. **触发原因**: `avcodec_open2()` 初始化失败后清理
3. **根本原因**: DRM_PRIME 格式与 libx264 编码器不兼容

### 解决路径
- ❌ 方案 A：格式转换（DRM_PRIME → I420）→ 复杂且低效
- ✅ **方案 B**：使用硬件编码器（h264_rkmpp）→ 简单且高效

### 下一步行动
1. ✅ 已添加 `USE_HARDWARE_ENCODER=1` 环境变量（line 1587）
2. ⏳ 重新部署到设备 192.168.10.188
3. ⏳ 验证硬件编码器是否正常工作
4. ⏳ 测试视频通话不再崩溃

---

**创建时间**: 2026-01-10 18:30
**最后更新**: 2026-01-10 18:35
**作者**: Claude (Sonnet 4.5)
**状态**: ✅ 根因已定位，✅ 修复已实施，⏳ 等待验证
