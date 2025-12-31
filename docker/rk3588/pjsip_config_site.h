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
