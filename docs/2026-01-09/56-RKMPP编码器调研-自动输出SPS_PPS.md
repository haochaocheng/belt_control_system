# RKMPP 编码器调研：自动输出 SPS/PPS（无需额外配置）

**日期**: 2026-01-09 22:40
**源码**: E:\2025\3_gongkongji\NewFolder\ffmpeg-rk-temp\ffmpeg-rockchip-master\libavcodec\rkmppenc.c
**关键发现**: ✅ **RKMPP 编码器默认在每个 IDR 前输出 SPS/PPS，且使用 Annex B 格式**
**状态**: 🎉 **无需额外配置，但需检查 GLOBAL_HEADER 标志**

---

## 🔍 源码分析

### 关键代码：Header Mode 设置（Line 645-650）

```c
header_mode = (avctx->flags & AV_CODEC_FLAG_GLOBAL_HEADER)
              ? MPP_ENC_HEADER_MODE_DEFAULT : MPP_ENC_HEADER_MODE_EACH_IDR;
if ((ret = r->mapi->control(r->mctx, MPP_ENC_SET_HEADER_MODE, &header_mode)) != MPP_OK) {
    av_log(avctx, AV_LOG_ERROR, "Failed to set header mode: %d\n", ret);
    return AVERROR_EXTERNAL;
}
```

**逻辑解析**:

| 条件 | Header Mode | SPS/PPS 位置 | 用途 |
|------|------------|-------------|------|
| `AV_CODEC_FLAG_GLOBAL_HEADER` **已设置** | `MPP_ENC_HEADER_MODE_DEFAULT` | ❌ 只在 extradata 中（MP4/MKV） | 容器文件格式 |
| `AV_CODEC_FLAG_GLOBAL_HEADER` **未设置** | `MPP_ENC_HEADER_MODE_EACH_IDR` | ✅ 每个 IDR 前都包含 SPS/PPS | RTP 流式传输 |

---

### 关键代码：GLOBAL_HEADER 处理（Line 1217-1257）

```c
if ((avctx->flags & AV_CODEC_FLAG_GLOBAL_HEADER) &&
    (avctx->codec_id == AV_CODEC_ID_H264 ||
     avctx->codec_id == AV_CODEC_ID_HEVC)) {
    RK_U8 enc_hdr_buf[H26X_HEADER_SIZE];
    size_t pkt_len = 0;
    void *pkt_pos = NULL;

    memset(enc_hdr_buf, 0, H26X_HEADER_SIZE);

    // 获取 SPS/PPS extradata
    if ((ret = mpp_packet_init(&mpp_pkt,
                               (void *)enc_hdr_buf,
                               H26X_HEADER_SIZE)) != MPP_OK || !mpp_pkt) {
        av_log(avctx, AV_LOG_ERROR, "Failed to init extra info packet: %d\n", ret);
        ret = AVERROR_EXTERNAL;
        goto fail;
    }

    mpp_packet_set_length(mpp_pkt, 0);
    if ((ret = r->mapi->control(r->mctx, MPP_ENC_GET_HDR_SYNC, mpp_pkt)) != MPP_OK) {
        av_log(avctx, AV_LOG_ERROR, "Failed to get header sync: %d\n", ret);
        ret = AVERROR_EXTERNAL;
        goto fail;
    }

    pkt_pos = mpp_packet_get_pos(mpp_pkt);
    pkt_len = mpp_packet_get_length(mpp_pkt);

    // 存储到 avctx->extradata
    if (avctx->extradata) {
        av_free(avctx->extradata);
        avctx->extradata = NULL;
    }
    avctx->extradata = av_malloc(pkt_len + AV_INPUT_BUFFER_PADDING_SIZE);
    if (!avctx->extradata) {
        ret = AVERROR(ENOMEM);
        goto fail;
    }
    avctx->extradata_size = pkt_len + AV_INPUT_BUFFER_PADDING_SIZE;
    memcpy(avctx->extradata, pkt_pos, pkt_len);
    memset(avctx->extradata + pkt_len, 0, AV_INPUT_BUFFER_PADDING_SIZE);
    mpp_packet_deinit(&mpp_pkt);
}
```

**说明**:
- 如果设置了 `AV_CODEC_FLAG_GLOBAL_HEADER`，编码器会将 SPS/PPS 提取到 `avctx->extradata`
- 这适用于 MP4/MKV 等容器格式（SPS/PPS 存储在容器头部，不在每个 IDR 前）
- **对于 RTP 流式传输，不应该设置此标志！**

---

## 🎯 关键结论

### 1. RKMPP 编码器的默认行为（RTP 流式传输）

**前提**: `AV_CODEC_FLAG_GLOBAL_HEADER` **未设置**

✅ **自动输出 SPS/PPS**:
- Header Mode: `MPP_ENC_HEADER_MODE_EACH_IDR`
- 每个 IDR 帧前都会包含 SPS/PPS
- 无需类似 libx264 的 `repeat-headers=1` 配置

✅ **自动使用 Annex B 格式**:
- 起始码: `00 00 00 01` 或 `00 00 01`
- NAL 单元格式: `[起始码] [NAL header] [NAL payload]`
- 无需类似 libx264 的 `annexb=1` 配置

✅ **自动包含 NAL 单元类型**:
- SPS (7): Sequence Parameter Set
- PPS (8): Picture Parameter Set
- SEI (6): Supplemental Enhancement Information（可选）
- IDR (5): Instantaneous Decoder Refresh

---

### 2. 与 libx264 的对比

| 特性 | libx264 | h264_rkmpp | 说明 |
|------|---------|-----------|------|
| **SPS/PPS 重复输出** | ❌ 需要配置 `repeat-headers=1` | ✅ 默认行为（如果未设置 GLOBAL_HEADER） | RKMPP 更简单 |
| **Annex B 格式** | ❌ 需要配置 `annexb=1` | ✅ 默认行为 | RKMPP 自动处理 |
| **配置复杂度** | 🟡 需要多个 `av_opt_set` 调用 | 🟢 只需确保不设置 GLOBAL_HEADER | RKMPP 更简单 |

---

## ⚠️ 潜在问题：PJSIP 可能错误设置了 GLOBAL_HEADER

### 检查点 1: PJSIP 代码中是否设置了 AV_CODEC_FLAG_GLOBAL_HEADER

**需要检查的代码位置**（`ffmpeg_vid_codecs.c`）:

```c
// 编码器初始化
ff->enc_ctx->flags = ???

// 可能的问题代码：
ff->enc_ctx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;  // ❌ 如果有这行，需要删除！
```

---

### 检查点 2: 日志验证

**voip.md 日志应该显示**（如果 RKMPP 正常工作）:

```
✅ Found h264_rkmpp hardware encoder
✅ H.264 RKMPP encoder manually registered
...
🔍 [ENCODE] Received packet: size=20909, flags=0x1  ← 关键帧
   NAL units: SPS(7), PPS(8), IDR(5)  ← 应该包含这些
```

**如果缺少 SPS/PPS**（说明 GLOBAL_HEADER 被错误设置）:

```
🔍 [ENCODE] Received packet: size=18000, flags=0x1  ← 关键帧
   NAL units: IDR(5)  ← 只有 IDR，缺少 SPS/PPS  ❌
```

---

## 📋 RKMPP 编码器支持的选项（从源码提取）

### Rate Control（码率控制）

**选项名**: `-rc_mode`
**类型**: 枚举
**值**:
- `VBR` (0): 可变比特率（Variable Bitrate）
- `CBR` (1): 恒定比特率（Constant Bitrate）
- `CQP` (2): 恒定 QP（Constant QP，FIXQP 模式）
- `AVBR` (3): 平均可变比特率（Average VBR）
**默认**: 自动选择（根据 qp_init、max_bps 参数）

---

### QP 控制（Quantization Parameter）

**选项**:
- `-qp_init`: 初始 QP 值（-1 to 51，默认 -1）
- `-qp_max`: P/B 帧最大 QP（-1 to 51，默认 -1）
- `-qp_min`: P/B 帧最小 QP（-1 to 51，默认 -1）
- `-qp_max_i`: I 帧最大 QP（-1 to 51，默认 -1）
- `-qp_min_i`: I 帧最小 QP（-1 to 51，默认 -1）

---

### Intra Refresh（渐进式刷新）

**选项**:
- `-intra_refresh`: 启用 Intra Refresh（boolean，默认 false）
- `-refresh_mode`: 刷新模式（row=0 or col=1，默认 row）
- `-refresh_num`: 每次刷新的 MB 行/列数量（1 to INT_MAX，默认 1）

**说明**: Intra Refresh 替代传统 IDR 帧，用于无缝切换场景。

---

### Profile & Level（配置档次和级别）

**H.264 选项**:
- `-profile`: 编码档次（baseline=66, main=77, high=100，默认 high）
- `-level`: 编码级别（-99 to 62，默认 0）
  - 例如：Level 4.0 = 40，Level 4.1 = 41
- `-coder`: 熵编码（CAVLC=0 or CABAC=1）
- `-8x8dct`: 8x8 变换（high profile 特性，boolean）

**HEVC 选项**:
- `-profile`: 编码档次（main=1, rext=4）
- `-level`: 编码级别（例如：Level 4.0 = 120）
- `-tier`: 等级（main=0, high=1）

---

### SEI & Prefix

**选项**:
- `-udu_sei`: User Data Unregistered SEI（boolean）
- `-prefix_mode`: Prefix mode（用于 H.264）

---

### 比特率控制（Bitrate）

**标准 FFmpeg 选项**（RKMPP 自动处理）:
- `-b:v`: 目标比特率（例如：4M）
- `-maxrate`: 最大比特率（例如：5M）
- `-minrate`: 最小比特率（例如：2M）
- `-bufsize`: 缓冲区大小（用于计算 stats_time）

---

## 🚀 推荐配置（PJSIP 集成）

### 配置 1: 确保不设置 GLOBAL_HEADER（最关键）

**文件**: `ffmpeg_vid_codecs.c` Line 1924-1999

```c
// Init generic encoder params
if (ff->param->dir & PJMEDIA_DIR_ENCODING) {
    AVCodecContext *ctx = ff->enc_ctx;

    // ✅ 确保不设置 GLOBAL_HEADER 标志
    // ❌ 删除或注释掉任何类似这样的代码：
    // ctx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;

    // ✅ RKMPP 编码器会自动在每个 IDR 前输出 SPS/PPS（默认行为）
}
```

---

### 配置 2: 设置基本参数（已有）

**文件**: `ffmpeg_vid_codecs.c` Line 1980-1991

```c
ctx->width = vfd->size.w;
ctx->height = vfd->size.h;
ctx->time_base.num = vfd->fps.denum;
ctx->time_base.den = vfd->fps.num;
if (vfd->avg_bps) {
    ctx->bit_rate = vfd->avg_bps;
    if (vfd->max_bps > vfd->avg_bps)
        ctx->bit_rate_tolerance = vfd->max_bps - vfd->avg_bps;
}
ctx->strict_std_compliance = FF_COMPLIANCE_STRICT;
ctx->workaround_bugs = FF_BUG_AUTODETECT;
ctx->opaque = ff;
```

---

### 配置 3: GOP 设置（已有）

**文件**: `ffmpeg_vid_codecs.c` Line 688-700（来自 h264_preopen）

```c
// ✅ 2026-01-02 20:00 [修复 37] 修复 GOP 大小异常
int gop_size = (vfd->fps.num * 10) / vfd->fps.denum;
if (gop_size < 25) {
    gop_size = 250;  // 最小值：250 帧（10秒 @ 25fps）
}
ctx->gop_size = gop_size;
ctx->keyint_min = gop_size / 10;  // 最小关键帧间隔（1秒）
ctx->max_b_frames = 0;            // RKMPP 不支持 B 帧
```

---

### 配置 4: 像素格式（已有）

**文件**: `ffmpeg_vid_codecs.c` Line 1949-1963

```c
if (ff->enc && (pj_ansi_strstr(ff->enc->name, "rkmpp") != NULL)) {
    PJ_LOG(3,(THIS_FILE, "⚠️ [FIX 40] RKMPP encoder detected: %s", ff->enc->name));
    PJ_LOG(3,(THIS_FILE, "   Setting pix_fmt to I420 (%d) for system memory input",
              AV_PIX_FMT_YUV420P));

    // ✅ 使用 I420（YUV420P）格式，匹配 PJSIP 视频管道输出
    // RKMPP 编码器会根据此格式创建对应的 r->hwframe (sw_format=I420)
    // 然后在编码时自动转换 I420 → DRM_PRIME (使用 RGA 硬件加速)
    ctx->pix_fmt = AV_PIX_FMT_YUV420P;
}
```

---

## 🔧 下一步操作

### 行动 1: 检查 PJSIP 代码中的 GLOBAL_HEADER 标志（最优先）

**任务**: 在 `ffmpeg_vid_codecs.c` 中搜索所有 `AV_CODEC_FLAG_GLOBAL_HEADER` 出现的地方

**搜索命令**:
```powershell
cd e:\2025\3_gongkongji\belt_control_system
grep -n "AV_CODEC_FLAG_GLOBAL_HEADER" cross-compile\src\pjproject-2.16\pjmedia\src\pjmedia-codec\ffmpeg_vid_codecs.c
```

**预期结果**:
- 如果找到 `ctx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER`：删除这行代码
- 如果找到 `ctx->flags & AV_CODEC_FLAG_GLOBAL_HEADER`：确认这是**条件判断**，不是设置

---

### 行动 2: 添加诊断日志，验证 Header Mode

**目标**: 在编码器初始化时打印 Header Mode，确认 RKMPP 使用 `EACH_IDR` 模式

**建议添加的日志**（在 `h264_preopen` 或 `open_ffmpeg_codec` 中）:

```c
if (ff->enc && (pj_ansi_strstr(ff->enc->name, "rkmpp") != NULL)) {
    PJ_LOG(1,(THIS_FILE, "✅ [RKMPP ENCODER] Header Mode Configuration:"));
    if (ff->enc_ctx->flags & AV_CODEC_FLAG_GLOBAL_HEADER) {
        PJ_LOG(1,(THIS_FILE, "   ⚠️ GLOBAL_HEADER is SET (extradata mode, may cause SPS/PPS issues)"));
        PJ_LOG(1,(THIS_FILE, "   Header Mode: MPP_ENC_HEADER_MODE_DEFAULT"));
        PJ_LOG(1,(THIS_FILE, "   SPS/PPS Location: In extradata only"));
    } else {
        PJ_LOG(1,(THIS_FILE, "   ✅ GLOBAL_HEADER is NOT SET (streaming mode)"));
        PJ_LOG(1,(THIS_FILE, "   Header Mode: MPP_ENC_HEADER_MODE_EACH_IDR"));
        PJ_LOG(1,(THIS_FILE, "   SPS/PPS Location: In every IDR frame (Annex B format)"));
    }
}
```

---

### 行动 3: 分析首个关键帧的 NAL 单元

**目标**: 确认首个关键帧包含 SPS/PPS

**现有日志**（voip.md Line 1037-1075 - DIAG 66）:
```
🔍 [DIAG 66] === FIRST KEYFRAME ANALYSIS ===
   Packet size: 20909
   Packet flags: 0x1 (KEY=1)
   Analyzing NAL units...
   NAL#0 @ offset 0: type=7 nri=3 header=0x67   ← SPS
   NAL#1 @ offset 24: type=8 nri=3 header=0x68  ← PPS
   NAL#2 @ offset 32: type=6 nri=0 header=0x06  ← SEI
   NAL#3 @ offset 79: type=5 nri=3 header=0x65  ← IDR
   Total NAL units found: 4
   Expected: SPS(7), PPS(8), SEI(6), IDR(5)
```

**分析**: ✅ **首个关键帧已包含 SPS/PPS！**（如果 GLOBAL_HEADER 未设置）

---

## 📖 参考资料

### 官方文档
- [nyanmisaka/ffmpeg-rockchip - GitHub](https://github.com/nyanmisaka/ffmpeg-rockchip)
- [Encoder Wiki](https://github.com/nyanmisaka/ffmpeg-rockchip/wiki/Encoder)
- [Decoder Wiki](https://github.com/nyanmisaka/ffmpeg-rockchip/wiki/Decoder)

### 源码文件
- **RKMPP 编码器**: `E:\2025\3_gongkongji\NewFolder\ffmpeg-rk-temp\ffmpeg-rockchip-master\libavcodec\rkmppenc.c`
  - Line 645-650: Header Mode 设置
  - Line 1217-1257: GLOBAL_HEADER 处理
  - Line 391-654: 编码器配置函数

### 本项目文档
- [55-硬件编码器证据分析-SPS_PPS配置缺失.md](55-硬件编码器证据分析-SPS_PPS配置缺失.md) - 问题诊断
- [43-Fix97-添加硬件编码器开关.md](43-Fix97-添加硬件编码器开关.md) - 环境变量控制

---

## ✅ 核心结论

### 1. RKMPP 编码器无需额外配置

✅ **SPS/PPS 自动输出**: 默认行为（`MPP_ENC_HEADER_MODE_EACH_IDR`）
✅ **Annex B 格式**: 默认行为（起始码前缀）
✅ **NAL 单元完整**: 自动包含 SPS、PPS、SEI、IDR

**唯一要求**: ❌ **不要设置 `AV_CODEC_FLAG_GLOBAL_HEADER` 标志！**

---

### 2. 高 CPU 负载的可能原因（已更新）

根据源码分析，RKMPP 编码器应该已经正确输出 SPS/PPS，高 CPU 负载的原因可能是：

1. **RGA 硬件转换失败** (60% 可能性)
   - I420 → DRM_PRIME 转换应该由 RGA 硬件完成
   - 如果 RGA 失败，可能回退到 CPU swscale
   - 需要检查 RGA 初始化日志

2. **网络重传** (30% 可能性)
   - PortSIP 接收端解码失败，请求重传
   - 本地 CPU 处理大量重传请求

3. **其他因素** (10% 可能性)
   - PJSIP 线程调度问题
   - 其他模块 CPU 占用

---

### 3. 下一步验证重点

1. **检查 GLOBAL_HEADER 标志**（最优先）
2. **检查 RGA 初始化日志**（次优先）
3. **添加 Header Mode 诊断日志**（辅助验证）

---

**创建时间**: 2026-01-09 22:40
**核心发现**: RKMPP 编码器默认输出 SPS/PPS（Annex B 格式），无需额外配置
**关键要求**: 不要设置 AV_CODEC_FLAG_GLOBAL_HEADER 标志
**下一步**: 检查 PJSIP 代码中的 GLOBAL_HEADER 设置
