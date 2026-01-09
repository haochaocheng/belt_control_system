# 视频电话失败诊断：FFmpeg H264 编解码器缺失

**日期**: 2026-01-09 21:00
**问题**: 拨打视频电话失败，走的是音频，本机只显示本机画面
**根本原因**: FFmpeg 库中缺少 H264 编解码器
**状态**: 🔴 **阻塞 - FFmpeg 编译配置错误**

---

## 🔍 日志分析

### 关键证据 1: H264 编解码器未找到（Line 30-50）

```
Line 30: Configuring RKMPP H.264 hardware codec (FFmpeg 6.0)
Line 31: ✅ [FIX 97] Hardware encoder ENABLED (USE_HARDWARE_ENCODER=1, default=1)
Line 32:    Using hardware encoder: h264_rkmpp
Line 33: ⚠️ WARNING: Hardware encoder 'h264_rkmpp' not found - video encoding DISABLED
Line 34: ⚠️ WARNING: Hardware decoder 'h264_rkmpp' not found - video decoding DISABLED
...
Line 45: Cannot find H264 encoder in ffmpeg library
Line 46: Cannot find H264 decoder in ffmpeg library
```

**分析**:
- PJSIP 尝试查找 h264_rkmpp 编码器 → **未找到**
- PJSIP 尝试查找 h264_rkmpp 解码器 → **未找到**
- FFmpeg 库中**完全没有 H264 编解码器**

---

### 关键证据 2: 只注册了 5 个老旧编解码器（Line 51-67）

```
Line 51: ✅ FFmpeg codec factory registered successfully
Line 52-66: 注册的编解码器:
  📹 Codec[3]: H263-1998  ← 1998 年标准
  📹 Codec[4]: H263       ← 1996 年标准
  📹 Codec[5]: H261       ← 1990 年标准
  📹 Codec[6]: JPEG       ← 图片编解码器
  📹 Codec[7]: MP4V       ← MPEG-4 Part 2（老旧）
Line 67: Total enabled codecs: 5
```

**分析**:
- **缺少 H264**（现代标准，2003 年）
- **缺少 VP8、VP9**（WebRTC 标准）
- 只有 H263、H261、JPEG、MP4V 等老旧编解码器
- 这些编解码器不被 PortSIP 支持

---

### 关键证据 3: PJSIP 配置失败（Line 113-130）

```
Line 113: 📹 [ATTEMPT 14] Configuring H264 for 720P (1280x720)...
Line 115: ⚠️ Failed to get H264 codec parameters: Not found (PJ_ENOTFOUND)
Line 128-130: 📹 Enumerating VIDEO codecs using pjsua_vid_enum_codecs:
    ✅ Found 1 video codecs:
    [ 0 ] "H263-1998/96" priority: 128
```

**分析**:
- 应用程序尝试配置 H264 → **失败（Not found）**
- PJSIP 枚举可用编解码器 → **只有 H263-1998**
- 无法配置 H264 720P

---

### 关键证据 4: INVITE SDP 只包含 H263（Line 456-504）

```
INVITE sip:1006@192.168.10.143 SIP/2.0
...
Content-Type: application/sdp

v=0
...
m=video 4002 RTP/AVP 96
c=IN IP4 192.168.10.188
a=rtpmap:96 H263-1998/90000  ← 只有 H263-1998
a=fmtp:96 CIF=1;QCIF=1
```

**分析**:
- 本机 INVITE 只提供 **H263-1998** 编解码器
- **没有 H264**
- PortSIP 不支持 H263

---

### 关键证据 5: 对方拒绝视频流（Line 585-615）

```
SIP/2.0 200 OK
...
Content-Type: application/sdp

v=0
...
m=audio 20400 RTP/AVP 8 0 96 120  ← 音频接受
...
m=video 0 RTP/AVP 0               ← 视频拒绝（port=0）
c=IN IP4 0.0.0.0                  ← IP 无效
a=mid:1
a=inactive                        ← 禁用视频
```

**分析**:
- 音频流正常：`m=audio 20400`
- **视频流被拒绝**: `m=video 0` (port=0 表示禁用)
- **IP 地址无效**: `c=IN IP4 0.0.0.0`
- **状态为 inactive**: `a=inactive`

**原因**: PortSIP 不支持 H263-1998，协商失败

---

### 关键证据 6: 最终结果（Line 668-692）

```
Line 668: 🔍 [MEDIA LOOP] 4=== Processing media 1, type=2 ===
Line 673: Call 0: stream #1 (video) unchanged.
Line 675: video updated, stream #1:  (inactive)
Line 691: 📞 [MEDIA STATE] Media 1 : type= 2 dir= 0 status= 0 (VIDEO= 2)
Line 692: 📞 [MEDIA STATE] Final result for call 0 : hasVideo = false
```

**分析**:
- 媒体类型 2 = VIDEO
- dir= 0 = 无方向（inactive）
- status= 0 = 未激活
- **hasVideo = false** ← 最终结果：无视频

---

## 🎯 根本原因

### FFmpeg 库编译配置错误

**问题**: FFmpeg 库中没有 H264 编解码器

**可能原因**:

1. **FFmpeg 编译时未启用 H264 编解码器**
   - 缺少 `--enable-encoder=h264_rkmpp`
   - 缺少 `--enable-decoder=h264_rkmpp`
   - 缺少 `--enable-libx264`（软件编码器）

2. **librga.so.2 等依赖库缺失导致编解码器无法加载**
   - 虽然我们已经添加了 librga.so.2
   - 但可能还有其他依赖缺失

3. **FFmpeg 库版本不匹配**
   - 容器中的 FFmpeg 库可能不是硬件加速版本
   - 可能使用了错误的 FFmpeg 库

---

## 🔧 诊断步骤

### 步骤 1: 检查容器中的 FFmpeg 库

```bash
ssh linaro@192.168.10.188
docker run --rm belt-control:v3.5-apt ffmpeg -encoders 2>&1 | grep -E "h264|H264"
docker run --rm belt-control:v3.5-apt ffmpeg -decoders 2>&1 | grep -E "h264|H264"
```

**预期输出**（如果 FFmpeg 正确编译）:
```
Encoders:
 V..... h264_rkmpp         Rockchip Media Process Platform H.264 encoder (codec h264)
 V..... libx264            libx264 H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10 (codec h264)

Decoders:
 V..... h264               H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10 (codec h264)
 V..... h264_rkmpp         Rockchip Media Process Platform H.264 decoder (codec h264)
```

---

### 步骤 2: 检查 FFmpeg 库路径

```bash
docker run --rm belt-control:v3.5-apt ldd /app/belt_control_system | grep libav
```

**检查**:
- `libavcodec.so.58` 是否指向正确的硬件加速版本
- 路径应该是 `/app/lib/libavcodec.so.58`

---

### 步骤 3: 检查 FFmpeg 库中的编解码器

```bash
docker run --rm belt-control:v3.5-apt sh -c "LD_LIBRARY_PATH=/app/lib ffmpeg -codecs 2>&1 | grep -E 'h264|H264'"
```

**预期输出**:
```
DEV.LS h264       H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10 (decoders: h264 h264_rkmpp ) (encoders: h264_rkmpp libx264 )
```

---

## 💡 可能的解决方案

### 方案 A: 验证 FFmpeg 库来源 ⭐ **推荐**

**检查 FFmpeg 库是否来自正确的源**:

```powershell
# 检查 libs/ffmpeg-rkmpp-complete 目录
ls libs/ffmpeg-rkmpp-complete/libavcodec.so.*
```

**问题可能**:
- `libs/ffmpeg-rkmpp-complete` 目录中的 FFmpeg 库不是硬件加速版本
- 复制了错误的 FFmpeg 库到镜像

**验证方法**:
```bash
# 在设备 188 上检查 FFmpeg 编解码器
ssh linaro@192.168.10.188 "ffmpeg -encoders 2>&1 | grep h264"
```

**如果设备 188 上有 h264_rkmpp**:
- 需要从设备 188 重新下载 FFmpeg 库到 `libs/ffmpeg-rkmpp-complete`

---

### 方案 B: 从设备 188 重新下载 FFmpeg 库

**步骤 1**: 检查设备 188 上的 FFmpeg 库

```bash
ssh linaro@192.168.10.188 "ldd /usr/bin/ffmpeg | grep libavcodec"
```

**步骤 2**: 下载正确的 FFmpeg 库

```bash
ssh linaro@192.168.10.188 "ls -la /usr/lib/aarch64-linux-gnu/libavcodec.so*"
# 找到实际文件，例如 libavcodec.so.58.54.100

scp linaro@192.168.10.188:/usr/lib/aarch64-linux-gnu/libavcodec.so.58.54.100 libs/ffmpeg-rkmpp-complete/
# 同样下载 libavformat, libavutil, libswscale, libswresample
```

**步骤 3**: 重新构建镜像

```powershell
.\build-ubuntu24-apt.ps1 188
```

---

### 方案 C: 检查 FFmpeg 编译配置

**如果需要重新编译 FFmpeg**:

检查 FFmpeg 编译配置是否包含：
```bash
--enable-rkmpp
--enable-encoder=h264_rkmpp
--enable-decoder=h264_rkmpp
--enable-libx264
```

---

## 🚀 立即执行

### 第一步：验证 FFmpeg 编解码器

```bash
ssh linaro@192.168.10.188
docker run --rm belt-control:v3.5-apt sh -c "ffmpeg -encoders 2>&1 | grep -i h264"
```

**预期输出**:
- 如果看到 `h264_rkmpp` → FFmpeg 正确 → 检查库路径
- 如果**没有** `h264_rkmpp` → FFmpeg 库错误 → 需要重新下载

---

### 第二步：检查 FFmpeg 库来源

```powershell
# 检查本地 FFmpeg 库
Get-ChildItem libs/ffmpeg-rkmpp-complete/ | Format-Table Name, Length

# 检查设备 188 上的 FFmpeg 版本
ssh linaro@192.168.10.188 "ffmpeg -version | head -3"
ssh linaro@192.168.10.188 "ffmpeg -encoders 2>&1 | grep h264"
```

---

### 第三步：如果 FFmpeg 库错误，重新下载

```bash
# 从设备 188 下载 FFmpeg 库
ssh linaro@192.168.10.188 "ls -la /usr/lib/aarch64-linux-gnu/libav*.so.* | grep -v '\->'"

# 创建下载脚本
# 将所有 libav*.so.*.*.* 文件下载到 libs/ffmpeg-rkmpp-complete/
```

---

## 📊 时间线

1. **07:20:54** - PJSIP 初始化，查找 H264 编解码器
2. **07:20:54** - ⚠️ H264 编解码器未找到
3. **07:20:54** - 只注册 H263、H261、JPEG、MP4V
4. **07:20:59** - 发送 INVITE，只包含 H263-1998
5. **07:21:04** - 收到 200 OK，视频流被拒绝（port=0, inactive）
6. **07:21:04** - 最终结果：hasVideo = false
7. **07:21:04** - 建立音频通话 + 本地预览窗口

---

## ✅ 结论

### 核心问题

**FFmpeg 库中缺少 H264 编解码器**

**表现**:
1. h264_rkmpp 编码器未找到
2. h264_rkmpp 解码器未找到
3. 只有 H263、H261 等老旧编解码器
4. 视频协商失败（对方不支持 H263）
5. 最终只建立音频通话

---

### 下一步

1. **立即执行**: 检查容器中的 FFmpeg 编解码器
2. **验证 FFmpeg 库来源**: 确认是硬件加速版本
3. **如果错误**: 从设备 188 重新下载 FFmpeg 库
4. **重新构建镜像**: 包含正确的 FFmpeg 库

---

**创建时间**: 2026-01-09 21:00
**核心问题**: FFmpeg 库中缺少 H264 编解码器
**根本原因**: FFmpeg 库编译配置错误或使用了错误的库
**状态**: 🔴 **阻塞 - 需要验证和修复 FFmpeg 库**
