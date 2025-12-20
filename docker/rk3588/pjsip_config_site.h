/* PJSIP 配置文件 - RK3588 视频通话支持 */

/* 启用视频支持 */
#define PJMEDIA_HAS_VIDEO           1

/* 强制启用 ALSA 音频支持 */
#define PJMEDIA_AUDIO_DEV_HAS_ALSA      1

/* 强制启用 V4L2 视频捕获支持 */
#define PJMEDIA_VIDEO_DEV_HAS_V4L2      1

/* 强制启用 SDL 视频渲染支持 */
#define PJMEDIA_VIDEO_DEV_HAS_SDL       1

/* 启用 FFmpeg 视频编解码 */
#define PJMEDIA_HAS_FFMPEG              1
#define PJMEDIA_HAS_FFMPEG_VID_CODEC    1

/* 启用 libyuv 视频处理 */
#define PJMEDIA_HAS_LIBYUV              1

/* 性能优化 */
#define PJSIP_SAFE_MODULE               0
