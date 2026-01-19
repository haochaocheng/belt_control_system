# Phase 3.1 完成 - Opus 编解码器代码集成

**日期**: 2026-01-19 04:10
**状态**: ✅ Phase 3.1 完成！应用程序代码已注册 Opus 16kHz 编解码器
**下一步**: Phase 3.2 - 用户执行构建和部署，验证 Opus 集成

---

## 🎉 Phase 3.1 完成内容

### 目标
在应用程序代码中注册 Opus 音频编解码器，使其在 SIP 通话中可用。

### 修改文件
- **文件**: `src/risip/core/risipendpoint.cpp`
- **修改行数**: 3 处修改（头文件、初始化代码、配置参数）

---

## 📝 代码修改详情

### 修改 1：添加 Opus 头文件

**位置**: [risipendpoint.cpp:34-37](../../src/risip/core/risipendpoint.cpp#L34-L37)

```cpp
// ✅ 2026-01-19 04:00 [Phase 3.1] Opus 音频编解码器支持
// 原因：支持 Opus 16kHz 高质量音频编解码器
// 参考：docs/2026-01-18/26-Phase2完整成功-PJSIP已包含Opus支持.md
#include <pjmedia-codec/opus.h>
```

**说明**：
- PJSIP Opus 编解码器 API 头文件
- 提供 `pjmedia_codec_opus_init()` 等函数

---

### 修改 2：初始化 Opus 编解码器

**位置**: [risipendpoint.cpp:581-611](../../src/risip/core/risipendpoint.cpp#L581-L611)

```cpp
// ✅ 2026-01-19 04:00 [Phase 3.1] 初始化 Opus 音频编解码器
// 原因：支持 Opus 16kHz 高质量音频（可选编解码器，PCMA/PCMU 为必需）
// 说明：PJSIP config_site.h 中定义了 PJMEDIA_HAS_OPUS_CODEC 1
//       但 PJSUA2 可能未自动初始化，需要手动调用
// 参考：docs/2026-01-18/26-Phase2完整成功-PJSIP已包含Opus支持.md
qDebug() << "🎵 [CODEC] Initializing Opus codec...";
try {
    pj_status_t status;
    pjmedia_endpt *med_endpt = pjsua_get_pjmedia_endpt();

    if (med_endpt) {
        // 初始化 Opus 编解码器工厂
        status = pjmedia_codec_opus_init(med_endpt);
        if (status != PJ_SUCCESS) {
            char errmsg[PJ_ERR_MSG_SIZE];
            pj_strerror(status, errmsg, sizeof(errmsg));
            qWarning() << "  ⚠️ Failed to initialize Opus codec:" << errmsg;
            qWarning() << "  继续运行，Opus 将不可用（PCMA/PCMU 仍可正常工作）";
        } else {
            qInfo() << "  ✅ Opus codec initialized successfully";

            // 设置 Opus 默认参数（可选）
            pjmedia_codec_opus_set_default_param(nullptr);  // 使用默认参数
            qInfo() << "  ✅ Opus default parameters set";
        }
    } else {
        qWarning() << "  ⚠️ Media endpoint not ready, skipping Opus initialization";
    }
} catch (...) {
    qWarning() << "  ⚠️ Exception during Opus initialization, continuing without Opus";
}
```

**关键点**：
1. **位置**：在 `libInit()` 和 `libStart()` 之间
2. **错误处理**：初始化失败不影响应用启动（PCMA/PCMU 仍可用）
3. **默认参数**：使用 PJSIP 的 Opus 默认配置
4. **异常安全**：捕获所有异常，防止应用崩溃

---

### 修改 3：配置 Opus 16kHz 单声道

**位置**: [risipendpoint.cpp:892-907](../../src/risip/core/risipendpoint.cpp#L892-L907)

```cpp
// ✅ 2026-01-19 04:05 [Phase 3.1] 启用 Opus 16kHz 单声道高质量音频
// 原因：Opus 16kHz 提供更好的音质（宽带音频），适合专业通话
// 优先级：213（低于 PCMA/PCMU），作为可选编解码器
// 配置：opus/16000/1 = 16kHz 采样率 / 单声道
// 说明：
//   - PCMA/PCMU (8kHz) 为必需编解码器（优先级 215/214）
//   - Opus (16kHz) 为可选编解码器（优先级 213）
//   - 对方支持 Opus 时自动使用，不支持时回退到 PCMA/PCMU
// 参考：docs/2026-01-18/26-Phase2完整成功-PJSIP已包含Opus支持.md
try {
    Endpoint::instance().codecSetPriority("opus/16000/1", 213);
    qDebug() << "  ✅ opus/16000/1 enabled (priority: 213) - 16kHz 高质量音频";
} catch (Error &err) {
    qDebug() << "Warning: Could not set Opus codec priority:" << QString::fromStdString(err.reason);
    qDebug() << "  可能原因：Opus 编解码器未正确初始化";
}
```

**配置说明**：
- **编解码器 ID**: `opus/16000/1`
  - `opus`: 编解码器类型
  - `16000`: 采样率 16kHz（宽带音频）
  - `1`: 单声道
- **优先级**: 213（低于 PCMA/PCMU 的 215/214）
- **策略**: 可选编解码器，对方支持则使用，不支持则回退到 PCMA/PCMU

**修改前**：
```cpp
Endpoint::instance().codecSetPriority("opus/48000/2", 213);
// 48kHz 立体声（带宽过高，不适合 VoIP）
```

**修改后**：
```cpp
Endpoint::instance().codecSetPriority("opus/16000/1", 213);
// 16kHz 单声道（宽带音频，VoIP 最佳配置）
```

---

### 修改 4：更新调试日志

**位置**: [risipendpoint.cpp:963-969](../../src/risip/core/risipendpoint.cpp#L963-L969)

```cpp
qDebug() << "✅ [CODEC] Audio codec configuration complete";
qDebug() << "  Enabled: PCMA/8000, PCMU/8000, Opus/16000 (3 codecs)";
qDebug() << "  - PCMA/PCMU: 必需编解码器（8kHz 窄带音频）";
qDebug() << "  - Opus: 可选编解码器（16kHz 宽带音频，高质量）";
qDebug() << "  Disabled: GSM, iLBC, telephone-event, g722, speex";
qDebug() << "  Expected SDP reduction: ~200 bytes (from 1682 → ~1480 bytes)";
qDebug() << "  Target: < MTU 1500 bytes to avoid IP fragmentation";
```

**说明**：
- 清晰显示启用的编解码器配置
- 区分必需编解码器（PCMA/PCMU）和可选编解码器（Opus）
- 说明采样率和音质特性

---

## 🎯 Opus 16kHz 技术规格

### 音频质量对比

| 编解码器 | 采样率 | 带宽类型 | 比特率 | 音质 | 用途 |
|---------|--------|---------|--------|------|------|
| PCMA/PCMU | 8 kHz | 窄带 | 64 kbps | 基础 | 兼容性（必需） |
| G.722 | 16 kHz | 宽带 | 64 kbps | 良好 | 传统高清语音 |
| **Opus** | **16 kHz** | **宽带** | **6-32 kbps** | **高** | **现代 VoIP（推荐）** |
| Opus | 48 kHz | 全带宽 | 12-64 kbps | 非常高 | 音乐、会议 |

### Opus 16kHz 优势

1. **高质量**：宽带音频（50-7000 Hz），明显优于窄带（300-3400 Hz）
2. **低延迟**：20ms 帧大小，适合实时通话
3. **低带宽**：可变比特率 6-32 kbps（自动调整）
4. **开放标准**：IETF RFC 6716，无专利问题
5. **灵活性**：支持动态调整比特率和复杂度

### VoIP 推荐配置

```
编解码器优先级（从高到低）：
1. PCMA/8000 (priority: 215) - 必需（G.711 A-law）
2. PCMU/8000 (priority: 214) - 必需（G.711 μ-law）
3. Opus/16000 (priority: 213) - 可选（高质量宽带）
```

**协商策略**：
- 对方支持 Opus → 使用 Opus 16kHz（高质量）
- 对方不支持 Opus → 回退到 PCMA/PCMU 8kHz（兼容性）

---

## 📊 初始化流程

### PJSIP 启动顺序

```
1. libCreate()          → 创建 PJSIP endpoint
2. libInit()            → 初始化 endpoint（注册标准编解码器）
   ↓
3. pjmedia_codec_opus_init()  → ✅ 手动注册 Opus 编解码器
   ↓
4. libStart()           → 启动 endpoint
5. codecSetPriority()   → 设置编解码器优先级
```

### Opus 初始化检查

**成功日志**：
```
🎵 [CODEC] Initializing Opus codec...
  ✅ Opus codec initialized successfully
  ✅ Opus default parameters set
...
  ✅ opus/16000/1 enabled (priority: 213) - 16kHz 高质量音频
✅ [CODEC] Audio codec configuration complete
  Enabled: PCMA/8000, PCMU/8000, Opus/16000 (3 codecs)
```

**失败日志（不影响运行）**：
```
🎵 [CODEC] Initializing Opus codec...
  ⚠️ Failed to initialize Opus codec: [错误信息]
  继续运行，Opus 将不可用（PCMA/PCMU 仍可正常工作）
...
Warning: Could not set Opus codec priority: [错误信息]
  可能原因：Opus 编解码器未正确初始化
```

---

## 🔗 PJSIP API 参考

### 使用的 PJSIP 函数

#### 1. `pjmedia_codec_opus_init()`
```c
pj_status_t pjmedia_codec_opus_init(pjmedia_endpt *endpt);
```
- **功能**：注册 Opus 编解码器工厂到 PJSIP
- **参数**：`endpt` - PJSIP media endpoint
- **返回**：`PJ_SUCCESS` 或错误码

#### 2. `pjmedia_codec_opus_set_default_param()`
```c
pj_status_t pjmedia_codec_opus_set_default_param(const pjmedia_codec_opus_config *cfg);
```
- **功能**：设置 Opus 编解码器默认参数
- **参数**：`cfg` - Opus 配置（NULL 使用默认值）
- **返回**：`PJ_SUCCESS` 或错误码

#### 3. `pjsua_get_pjmedia_endpt()`
```c
pjmedia_endpt* pjsua_get_pjmedia_endpt(void);
```
- **功能**：获取 PJSIP media endpoint
- **返回**：media endpoint 指针

#### 4. `Endpoint::codecSetPriority()`
```cpp
void Endpoint::codecSetPriority(const string &codec_id, pj_uint8_t priority);
```
- **功能**：设置编解码器优先级
- **参数**：
  - `codec_id`: 编解码器 ID（如 "opus/16000/1"）
  - `priority`: 优先级（0=禁用，1-255=启用）
- **异常**：编解码器不存在时抛出 `Error`

---

## 🎯 Phase 3.2-3.4 操作指南

### Phase 3.2：执行构建和部署（用户操作）

#### 步骤 1：执行完整构建
```powershell
# 在项目根目录执行
.\build-ubuntu24-apt.ps1 188
```

**预期输出**：
```
Step 1: Cross-compilation check...
  Binary not found, compilation required
  Running cross-compilation with GLIBC fix (32 threads)...
  [OK] Cross-compilation complete

Step 2-6: Docker build and deploy...
  [OK] Application image built successfully
  [OK] Deployment complete
```

#### 步骤 2：SSH 连接设备并运行
```powershell
ssh linaro@192.168.10.188
./run-ubuntu24-apt.sh
```

**预期日志**（查找关键信息）：
```
🎵 [CODEC] Initializing Opus codec...
  ✅ Opus codec initialized successfully
  ✅ Opus default parameters set
...
  ✅ opus/16000/1 enabled (priority: 213) - 16kHz 高质量音频
✅ [CODEC] Audio codec configuration complete
  Enabled: PCMA/8000, PCMU/8000, Opus/16000 (3 codecs)
```

---

### Phase 3.3：测试 SDP 协商包含 Opus

#### 测试方法

1. **启动应用并注册 SIP 账号**
2. **拨打测试电话**（对方需支持 Opus）
3. **查看日志**：`docs/log/voip.md`

**预期 SDP**：
```
m=audio 4000 RTP/AVP 96 0 8
a=rtpmap:96 opus/16000/1
a=rtpmap:0 PCMU/8000
a=rtpmap:8 PCMA/8000
```

**说明**：
- `96 opus/16000/1` 排在最前面（优先级最高的可选编解码器）
- `0 PCMU/8000` 和 `8 PCMA/8000` 作为兼容性保障

#### 抓包验证（可选）

使用 Wireshark 抓包 SIP 消息：
```
SIP INVITE → m=audio → 查找 "opus/16000/1"
```

---

### Phase 3.4：验证 Opus 16kHz 通话质量

#### 测试场景

1. **场景 1**：与支持 Opus 的客户端通话
   - **对方客户端**：Linphone, Jitsi, Zoiper（需启用 Opus）
   - **预期**：自动协商使用 Opus 16kHz
   - **验证**：日志显示 "Using codec: opus/16000/1"

2. **场景 2**：与仅支持 PCMA/PCMU 的客户端通话
   - **对方客户端**：传统 SIP 电话
   - **预期**：自动回退到 PCMA/PCMU 8kHz
   - **验证**：日志显示 "Using codec: PCMA/8000 或 PCMU/8000"

#### 音质对比

**测试方法**：
1. 分别使用 Opus 和 PCMA 拨打同一个号码
2. 对比音质差异

**预期结果**：
- **Opus 16kHz**：声音清晰、自然，高频细节丰富
- **PCMA 8kHz**：声音略显低沉，高频受限

---

## 📚 相关文档

### Phase 1-2 文档
- [20-Opus编解码器支持完整实施计划.md](../2026-01-18/20-Opus编解码器支持完整实施计划.md) - 总体规划
- [26-Phase2完整成功-PJSIP已包含Opus支持.md](../2026-01-18/26-Phase2完整成功-PJSIP已包含Opus支持.md) - Phase 2 总结

### Phase 3 文档
- **本文档** - Phase 3.1 代码集成

### 技术参考
- [PJSIP Opus Codec API](https://docs.pjsip.org/en/latest/api/generated/pjmedia-codec/group/group__PJMED__OPUS__CODEC.html)
- [Opus Codec Official Site](https://opus-codec.org/)
- [RFC 6716 - Opus Audio Codec](https://tools.ietf.org/html/rfc6716)

---

## 📋 阶段总结

### Phase 1 ✅ 完成
- Opus 1.5.2 源码下载和编译

### Phase 2 ✅ 完成
- PJSIP 静态库集成 Opus 支持

### Phase 3.1 ✅ 完成 ⭐ **本文档**
- 应用程序代码注册 Opus 编解码器
- 配置 Opus 16kHz 单声道
- 设置编解码器优先级

### Phase 3.2-3.4 ⏳ 待完成（用户操作）
- 执行构建和部署
- 测试 SDP 协商包含 Opus
- 验证 Opus 16kHz 通话质量

### Phase 4 ⏳ 待完成
- SIP 设置界面添加音频编码器选择

---

## 💡 关键教训

### 1. 编解码器初始化时机很重要
- **正确**：`libInit()` 和 `libStart()` 之间
- **错误**：`libCreate()` 之前（media endpoint 未创建）
- **错误**：`libStart()` 之后（太晚，编解码器列表已固定）

### 2. 优先级策略
- **必需编解码器**（PCMA/PCMU）：优先级 215/214
- **可选编解码器**（Opus）：优先级 213（低于必需）
- **禁用编解码器**：优先级 0

### 3. 错误处理要健壮
- Opus 初始化失败不应影响应用启动
- PCMA/PCMU 作为后备方案保证基本通话
- 异常捕获防止应用崩溃

### 4. VoIP 编解码器配置
- **16kHz** 是宽带音频的最佳平衡点（质量 vs 带宽）
- **单声道** 适合 VoIP（立体声带宽浪费）
- **48kHz** 适合音乐/会议，不适合普通通话

---

**创建时间**: 2026-01-19 04:10
**最后更新**: 2026-01-19 04:10
**状态**: ✅ Phase 3.1 完成，等待 Phase 3.2（用户构建和部署）
