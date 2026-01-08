# 修复 83 - 强制 RKMPP 解码器输出 NV12 格式

**日期**: 2026-01-08 17:40
**状态**: ✅ **代码修改完成，待测试**

---

## 🎯 问题回顾

### Fix 82 测试结果

**成功**：
- ✅ 程序不再崩溃（运行 9+ 秒无 exit 139）
- ✅ 远端看到本机视频（libx264 编码器正常工作）
- ✅ 接收到对方视频包（RX pt=100, 256.2KB）

**失败**：
- ❌ 本机看不到远端视频
- ❌ 251 个 "codec decode() error: Not found (PJ_ENOTFOUND)" 错误
- ❌ RemoteVideoManager 无法处理解码后的帧

### 根本原因分析

**日志证据**（voip.md Line 739）：
```
✅ [FIX 82] RKMPP decoder opened successfully
   Decoder output format: 179  ← ⚠️ DRM_PRIME（问题所在）
   Decoder dimensions: 720x480
```

**格式说明**：
- **179 = AV_PIX_FMT_DRM_PRIME**：GPU 内存表面格式
  - 数据存储在 GPU 内存（不是系统内存）
  - 需要 DRM 驱动访问
  - RemoteVideoManager 无法直接访问

- **23 = AV_PIX_FMT_NV12**：系统内存格式（需要）
  - 数据在系统内存，可直接访问
  - Y 平面 + UV 交错平面
  - RemoteVideoManager 可以处理

- **0 = AV_PIX_FMT_YUV420P (I420)**：系统内存格式（备选）
  - 三个独立平面（Y, U, V）
  - 也可以被 RemoteVideoManager 处理

**错误流程**：
```
1. RKMPP 解码器输出 DRM_PRIME 格式（GPU 内存）
2. PJSIP 尝试将 DRM_PRIME → I420/NV12 转换
3. 转换失败（没有正确的格式转换路径）
4. check_decode_result() 中 PixelFormat_to_pjmedia_format_id() 返回 PJ_ENOTFOUND
5. RemoteVideoManager 收到错误，无法显示视频
```

---

## ✅ Fix 83 解决方案

### 核心思路

**在解码器打开前，强制设置输出格式为 NV12**

- RKMPP 解码器支持 `output_format` 选项
- 设置为 `"nv12"` 后，解码器输出系统内存格式
- RemoteVideoManager 可以直接处理

### 参考依据

1. **Line 2173-2182**：旧代码（已废弃）显示曾经使用此方法
2. **修复 46**：使用相同方法修复 RKMPP 解码器名称问题
3. **FFmpeg RKMPP 文档**：`output_format` 是有效的解码器选项

---

## 🔧 代码修改

**文件**: `cross-compile/src/pjproject-2.16/pjmedia/src/pjmedia-codec/ffmpeg_vid_codecs.c`
**位置**: Line 2107-2127

### 修改前（Fix 82）

```c
/* ✅ 2026-01-08 16:50 [修复 82.1] 立即打开 RKMPP 解码器 */
PJ_LOG(1,(THIS_FILE, "✅ [FIX 82] Opening RKMPP decoder immediately after hwdevice creation"));

dec_err = avcodec_open2(ff->dec_ctx, ff->dec, NULL);
```

### 修改后（Fix 83）

```c
/* ✅ 2026-01-08 16:50 [修复 82.1] 立即打开 RKMPP 解码器 */
PJ_LOG(1,(THIS_FILE, "✅ [FIX 82] Opening RKMPP decoder immediately after hwdevice creation"));

/* ✅ 2026-01-08 17:40 [修复 83] 强制 RKMPP 解码器输出 NV12 格式 */
int format_ret = av_opt_set(ctx, "output_format", "nv12", 0);
if (format_ret == 0) {
    PJ_LOG(1,(THIS_FILE, "✅ [FIX 83] RKMPP decoder output_format set to NV12"));
    PJ_LOG(1,(THIS_FILE, "   Expected: format 23 (NV12) for software processing"));
} else {
    PJ_LOG(2,(THIS_FILE, "⚠️ [FIX 83] Failed to set output_format to NV12 (ret=%d)", format_ret));
    PJ_LOG(2,(THIS_FILE, "   Will use decoder default format (likely DRM_PRIME)"));
}

dec_err = avcodec_open2(ff->dec_ctx, ff->dec, NULL);
```

---

## 📊 关键改进

| 项目 | Fix 82 | Fix 83 |
|------|--------|--------|
| **hwdevice 创建** | ✅ DRM render node | ✅ 相同 |
| **解码器打开时机** | ✅ 立即打开 | ✅ 相同 |
| **输出格式设置** | ❌ 未设置（默认 DRM_PRIME） | ✅ **强制 NV12** |
| **RemoteVideoManager 兼容** | ❌ 无法访问 GPU 内存 | ✅ **系统内存可访问** |
| **解码错误** | ❌ 251 个 PJ_ENOTFOUND | ✅ **预期消除** |

---

## 🎯 预期日志输出

### 成功情况

```
✅ [FIX 80] Detected RKMPP decoder: h264_rkmpp
   ✅ RKMPP hwdevice created using DRM render node (/dev/dri/renderD128)
   ✅ DRM render node is SHARED (multiple processes can access)

✅ [FIX 82] Opening RKMPP decoder immediately after hwdevice creation
✅ [FIX 83] RKMPP decoder output_format set to NV12           ← 新增！
   Expected: format 23 (NV12) for software processing         ← 新增！

✅ [FIX 82] RKMPP decoder opened successfully
   Decoder output format: 23                                   ← 应该是 23，不是 179！
   Decoder dimensions: 720x480

✅ [FIX 81] STEP 2: Opening encoder AFTER decoder
   Encoder: libx264
   ✅ Encoder opened successfully

🎉 双向视频通话正常建立！
   - 对方看到本机视频 ✅
   - 本机看到对方视频 ✅（新修复）
```

### 失败情况

**情况 1**：`av_opt_set()` 失败
```
⚠️ [FIX 83] Failed to set output_format to NV12 (ret=-2)
   Will use decoder default format (likely DRM_PRIME)
✅ [FIX 82] RKMPP decoder opened successfully
   Decoder output format: 179  ← 仍然是 DRM_PRIME

❌ 251 个 "codec decode() error: Not found" 错误继续出现
```

**情况 2**：解码器不支持 NV12
```
✅ [FIX 83] RKMPP decoder output_format set to NV12
✅ [FIX 82] RKMPP decoder opened successfully
   Decoder output format: 0    ← I420 而不是 NV12

⚠️ 可能需要额外的格式转换（I420 → NV12）
```

---

## ✅ 成功指标

| 指标 | 修复前 | 修复后（预期） |
|------|--------|--------------|
| **程序崩溃** | ✅ 已修复（Fix 82） | ✅ 保持不崩溃 |
| **解码器输出格式** | ❌ 179 (DRM_PRIME) | ✅ **23 (NV12)** |
| **解码错误数量** | ❌ 251 个 | ✅ **0 个** |
| **本机看到远端视频** | ❌ 看不到 | ✅ **可以看到** |
| **远端看到本机视频** | ✅ 正常 | ✅ 保持正常 |

---

## 🔄 完整视频通话流程（Fix 83 后）

### 编码路径（本机 → 远端）

```
1. 摄像头采集 I420 帧
2. libx264 软件编码器：I420 → H.264 码流
3. PJSIP RTP 打包发送
4. 远端接收解码显示 ✅
```

### 解码路径（远端 → 本机）

```
1. PJSIP RTP 接收 H.264 码流
2. h264_rkmpp 硬件解码器：
   - ✅ [FIX 80] 使用 DRM render node（不独占）
   - ✅ [FIX 82] 立即打开（避免中间操作崩溃）
   - ✅ [FIX 83] 输出 NV12 格式（系统内存）⚡
3. RemoteVideoManager 接收 NV12 帧 ✅
4. Qt/SDL 渲染显示 ✅
```

---

## 📁 相关文件

### 修改的文件
1. `cross-compile/src/pjproject-2.16/pjmedia/src/pjmedia-codec/ffmpeg_vid_codecs.c`
   - Line 2107-2127: Fix 83 主要修改

### 相关文档
- [01-软件编码硬件解码崩溃深度分析.md](01-软件编码硬件解码崩溃深度分析.md) - Fix 78 失败分析
- [02-修复80-软件编码硬件解码完全隔离方案.md](02-修复80-软件编码硬件解码完全隔离方案.md) - DRM render node
- [03-修复81-调整初始化顺序解决DRM冲突.md](03-修复81-调整初始化顺序解决DRM冲突.md) - 初始化顺序
- [05-修复81.1-移除条件编译解决未执行问题.md](05-修复81.1-移除条件编译解决未执行问题.md) - 运行时检测
- [06-修复82-hwdevice创建后立即打开解码器.md](06-修复82-hwdevice创建后立即打开解码器.md) - 消除崩溃
- **本文档** - Fix 83 强制 NV12 格式

---

## 🚀 下一步

### 立即操作

根据用户要求 **"你只负责修改，我编译"**：

1. ✅ **代码修改已完成**（Fix 83）
2. ⏳ **等待用户编译测试**
3. ⏳ **分析测试日志**（voip.md）

### 验证要点

测试时检查：
- ✅ 日志中出现 `[FIX 83] RKMPP decoder output_format set to NV12`
- ✅ `Decoder output format: 23`（不是 179）
- ✅ 无 "codec decode() error: Not found" 错误
- ✅ 本机可以看到远端视频画面
- ✅ 远端仍然可以看到本机视频（不回退）

---

## ⚠️ 可能的后续问题

### 如果 NV12 设置失败

**问题**：RKMPP 不支持 `output_format` 选项
**症状**：`⚠️ [FIX 83] Failed to set output_format to NV12`
**备选方案**：
1. 使用 I420 格式（format 0）
2. 在 RemoteVideoManager 中添加 DRM_PRIME → NV12 转换
3. 使用软件解码器（h264）

### 如果仍然无法显示视频

**可能原因**：
1. RemoteVideoManager 不支持 NV12 格式
2. Qt/SDL 渲染器配置问题
3. 帧尺寸不匹配（720x480 vs 预期尺寸）

**诊断方法**：
- 检查 RemoteVideoManager.cpp 支持的格式列表
- 添加 NV12 帧数据十六进制输出日志
- 验证帧尺寸和步长（stride）计算

---

**文档版本**: v1.0
**创建时间**: 2026-01-08 17:40
**状态**: ✅ 代码修改完成，等待用户编译测试
