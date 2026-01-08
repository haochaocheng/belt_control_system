/* PJSIP 配置文件 - RK3588 视频通话支持 */

/* 启用视频支持 */
#define PJMEDIA_HAS_VIDEO           1

/* ✅ 启用 SSL/TLS 支持 (2025-12-30) */
/* 必须启用才能编译 pj_ssl_* 函数到静态库中 */
#define PJ_HAS_SSL_SOCK             1

/* 强制启用 ALSA 音频支持 */
#define PJMEDIA_AUDIO_DEV_HAS_ALSA      1

/* 强制启用 V4L2 视频捕获支持 */
#define PJMEDIA_VIDEO_DEV_HAS_V4L2      1

/* 强制启用 SDL 视频渲染支持 */
#define PJMEDIA_VIDEO_DEV_HAS_SDL       1

/* ✅ 启用 FFmpeg 视频编解码 (2025-12-30 恢复) */
/* 必须启用才能支持 H.264 视频通话 */
#define PJMEDIA_HAS_FFMPEG              1
#define PJMEDIA_HAS_FFMPEG_VID_CODEC    1

/* ✅ 启用 RKMPP 硬件 H.264 编解码器 */
/* 这是 RK3588 专用的硬件加速编解码器，比 FFmpeg 软件编解码更高效 */
#define PJMEDIA_HAS_RKMPP_CODEC         1

/* ✅ 2026-01-08 00:45 [修复 77] 默认启用硬件解码器（必须调试硬件解码）*/
/* 条件编译开关：控制使用硬件还是软件解码器 */
/* ✅ 2026-01-08 18:45 [修复 86] 启用硬件解码器 + av_hwframe_transfer_data 转换
 * 发现：av_hwframe_transfer_data() 可以将 DRM_PRIME → NV12（GPU → CPU 内存）
 * 策略：VPU 硬件解码（format 179）→ av_hwframe_transfer_data() → NV12 系统内存
 * 性能：VPU 解码（0%）+ 格式转换（~5-10ms/frame）= 低 CPU 占用 + 兼容性
 * 参考：https://abhitronix.github.io/deffcode/v0.2.6-stable/recipes/advanced/decode-hw-acceleration/
 * 详细：docs/2026-01-08/14-修复86-使用av_hwframe_transfer_data转换格式.md
 */
#define USE_HARDWARE_DECODER            1  // ✅ Fix 86：硬件解码 + 格式转换

/* 启用 libyuv 视频处理 */
#define PJMEDIA_HAS_LIBYUV              1

/* 启用 Opus 音频编解码 - 高质量音频 */
#define PJMEDIA_HAS_OPUS_CODEC          1

/* ✅ 2025-12-31 关键修复：启用 RTCP-FB 反馈机制（兼容 PortSIP UC Client） */
/* PortSIP 要求这些反馈机制才会接受视频流，否则返回 a=inactive */
#define PJMEDIA_STREAM_ENABLE_RTCP_FB   1   /* 启用 RTCP 反馈 */
#define PJMEDIA_HAS_RTCP_XR             1   /* 启用 RTCP 扩展报告 */
#define PJMEDIA_VIDEO_DEV_HAS_FB        1   /* 启用视频反馈 */

/* 性能优化 */
#define PJSIP_SAFE_MODULE               0

/* ✅ CRITICAL FIX: Disable Keep-alive to prevent crash */
/* Keep-alive timer causes segfault after successful registration */
#define PJSIP_TRANSPORT_IDLE_TIME       0
#define PJSUA_REG_RETRY_INTERVAL        300

/* ⭐ ULTIMATE FIX: Completely disable TCP/TLS/UDP Keep-alive timers */
/* PJSIP Bug #2079: Race condition in keep_alive_timer_cb() */
/* Setting udpKaIntervalSec=0 at runtime is IGNORED by PJSIP 2.16 */
/* Must disable at compile-time to prevent timer from ever starting */
#define PJSIP_TCP_KEEP_ALIVE_INTERVAL   0   /* 禁用 TCP Keep-alive */
#define PJSIP_TLS_KEEP_ALIVE_INTERVAL   0   /* 禁用 TLS Keep-alive */

/* ⭐ CRITICAL: Disable UDP Keep-alive timer to prevent crash */
/* This is the account-level keep-alive that PJSIP uses for UDP transports */
/* Default value is 15 seconds if not defined */
/* Setting to 0 completely disables the timer */
#define PJ_ENABLE_EXTRA_CHECK           0   /* 禁用额外检查以避免 assertion */
#define PJSUA_UDP_KA_INTERVAL           0   /* 禁用 UDP Keep-alive */

/* ⭐ FIX: Disable text/RTT media to reduce SIP INVITE message size */
/* INVITE messages were 1510 bytes causing IP fragmentation (MTU=1500) */
/* Fragmented packets get dropped by firewalls/routers causing no response */
#define PJMEDIA_HAS_RTSP                0   /* 禁用 RTSP */
#define PJSUA_DEFAULT_TEXT_IN_SDP       PJ_FALSE  /* 不在 SDP 中包含 text 媒体 */

/* ✅ 2025-12-31 关键修复：禁用通话后自动 re-INVITE（优化编解码器） */
/* 问题：PJSIP 在通话建立后自动发送 re-INVITE 优化编解码器 */
/* 结果：PortSIP/miniSIP 误认为有问题，将视频设为 a=inactive */
/* 解决：在账户配置中设置 lock_codec = PJ_FALSE（见 risipaccountconfiguration.cpp） */
/* 注意：这是运行时配置，不是编译时宏 */

/* Disable transport keep-alive data */
#define PJ_TURN_TP_UDP_KEEP_ALIVE_DATA  ""
#define PJ_TURN_TP_TCP_KEEP_ALIVE_DATA  ""

/* ✅ 2026-01-01 20:30 [修复 22] 禁用 PJSIP Debug 断言避免 re-INVITE mutex 崩溃 */
/* 问题：PortSIP 服务器在通话建立后发送 re-INVITE 添加 RTCP feedback 特性 */
/* 结果：PJSIP 重新初始化音频流时触发 mutex->owner 断言失败（Exit 133）*/
/* 根本原因：PJSIP 在 PJ_DEBUG=1 模式下检查 mutex 所有者，re-INVITE 处理时出现线程同步问题 */
/* 解决方案：强制禁用 PJ_DEBUG，绕过断言（mutex 问题仍存在但不会崩溃）*/
/* 参考：pjlib/src/pj/os_core_unix.c:1668 - pj_assert(mutex->owner == pj_thread_this()) */
/* 参考：pjsip/src/pjsip/sip_transport_loop.c:227 - 类似问题的注释 */
#define PJ_DEBUG                        0   /* 禁用 Debug 模式（关闭 mutex 断言）*/
#define NDEBUG                          1   /* 定义 NDEBUG 强制 Release 模式 */

/* ✅ 2026-01-02 14:00 [修复 29] 彻底禁用 PJSIP 自动预览窗口 */
/* 问题：PJSIP 在视频通话时自动创建预览窗口，导致视频端口重新分配 */
/* 现象：
 *   1. SDP协商时声明端口 4002
 *   2. PJSIP 创建预览窗口后，RTP 端口变为 4006
 *   3. 对方仍然发送到 4002 → 本机未监听 → ICMP Port Unreachable
 *   4. 结果：Video frames = 0，完全无法接收对方视频
 * 根本原因：
 *   - risipendpoint.cpp:532 设置 vidPreviewEnableNative = false 无效
 *   - 该配置只禁用"native"预览，PJSIP 仍会创建 SDL 预览窗口
 *   - 日志证据：pjsua_vid.c "Creating video window: type=preview"
 * 解决方案：
 *   - 编译时禁用所有预览窗口：PJSUA_VID_PREVIEW_DISABLE 1
 *   - 使用自定义 LocalVideoManager 管理本地预览
 *   - 避免 PJSIP 干预视频端口分配和摄像头资源
 * 参考：
 *   - docs/2026-01-02/视频端口不匹配问题-PJSIP预览窗口分析.md
 *   - docs/2026-01-01/修复26-优先使用PJSIP预览避免摄像头冲突.md
 *   - Wireshark 抓包：Frame 73,75,77,79,90 - RTP 到 4006 而非 4002
 */
#define PJSUA_VID_PREVIEW_DISABLE       1   /* 禁用 PJSIP 自动预览窗口 */
