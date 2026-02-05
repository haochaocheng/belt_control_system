
pi@NanoPi-R6C:~$
pi@NanoPi-R6C:~$ ./run-ubuntu24-apt.sh
==========================================
Belt Control System v3.5 - 部署准备
==========================================

[1/4] 停止旧容器...
belt-control-app
belt-control-app
  ✅ 容器已删除

[2/4] 清理旧镜像...
  ℹ️ 无旧镜像

[3/4] 清理 Docker 系统...
  Total reclaimed space: 1.448GB

[4/4] 磁盘状态检查...
  磁盘占用: 26%
  Docker 占用: 3.4G

==========================================
Belt Control System v3.5 - 启动应用
==========================================

non-network local connections being added to access control list
✅ X11 detected - using XCB with Mali GPU acceleration
Starting application with persistent data...
Qt Platform: xcb
kernel.core_pattern = /tmp/belt-control-cores/core.%e.%p.%t
mpp[1]: mpp_platform: client 18 driver is not ready!
=== Application starting ===
🕐 Build timestamp: 2025-12-28 10:23 (codec_info NULL check)
📦 Compiled at: Jan 18 2026 11:05:30
[WARNING] Detected locale "C" with character encoding "ANSI_X3.4-1968", which is not UTF-8.
Qt depends on a UTF-8 locale, and has switched to "C.UTF-8" instead.
If this causes problems, reconfigure your locale. See the locale(1) manual
for more information.
QGuiApplication created
QQmlApplicationEngine created
Logger initialized
Registering SipPhoneManager...
[DEBUG] ✅ VideoSinkItem registered to QML
[DEBUG] SipPhoneManager registered to QML
SipPhoneManager registered to QML
Creating hardware HAL...
Using RealHAL
Creating BeltController...
BeltController initialized
Creating control modules...
[DEBUG] ========== 数据文件路径配置 ==========
[DEBUG] 数据目录: "/app/appdata"
[DEBUG] 配置文件: "/app/appdata/config.ini"
[DEBUG] 报警历史数据库: "/app/appdata/alarm_history.db"
[DEBUG] 保护配置数据库: "/app/appdata/protection_config.db"
[DEBUG] 操作日志数据库: "/app/appdata/operation_logs.db"
[DEBUG] 联系人数据库: "/app/appdata/contacts.db"
[DEBUG] 通话记录数据库: "/app/appdata/call_history.db"
[DEBUG] SIP账户配置: "/app/appdata/sip_accounts.ini"
[DEBUG] TTS缓存目录: "/app/appdata/tts_cache"
[DEBUG] =====================================
[DEBUG] ✅ SystemConfig: 配置管理器已创建
[DEBUG]    配置文件路径: "/app/appdata/config.ini"
[DEBUG] 📂 SystemConfig: 配置已加载
[DEBUG]    本机编号: 1
[DEBUG]    工作模式: "检修"
[DEBUG]    起车预警时间: 10 秒
[DEBUG]    起车预警播放次数: 3 次
[DEBUG]    播放模式: 按时间
[DEBUG]    启动顺序: "张紧 -> 抱闸 -> 1号电机 -> 2号电机"
[DEBUG]    停止顺序: "2号电机 -> 1号电机 -> 抱闸 -> 张紧"
[DEBUG]    Modbus服务器IP: "192.168.10.243"
[DEBUG]    网关: "192.168.1.10"
[DEBUG]    子网掩码: "255.255.255.0"
[DEBUG]    轮询间隔: 100 ms
[DEBUG] ✅ DeviceDatabase: 设备数据库已创建
[DEBUG] ✅ DeviceDatabase: 初始化了 16 个默认设备
[DEBUG] ✅ DeviceDatabase: 已保存 16 个设备到配置文件
[DEBUG] 📊 DeviceRuntimeTracker: 加载统计数据 - 日: "00:00:00" 周: "00:00:00" 月: "00:00:00"
[DEBUG] ✅ DeviceRuntimeTracker 初始化完成
[DEBUG] 📂 OperationLogDatabase: 数据库路径: "/app/appdata/operation_logs.db"
[DEBUG] ✅ OperationLogDatabase: 数据库连接成功
[DEBUG] ✅ OperationLogDatabase: 表结构创建成功
[DEBUG] ✅ AlarmHistoryDatabase: 报警历史数据库已创建
[DEBUG] ✅ AlarmHistoryDatabase: 数据库已打开: "/app/appdata/alarm_history.db"
[DEBUG] ✅ AlarmHistoryDatabase: 数据库表已创建
[DEBUG] ✅ AlarmHistoryDatabase: 数据库初始化完成
[DEBUG] 保护配置数据库初始化成功: "/app/appdata/protection_config.db"
[DEBUG] ✅ ModbusTcpClient: Modbus TCP客户端已创建
[DEBUG] ✅ NetworkTask: 网络任务已创建
mpp[11]: mpp_platform: client 18 driver is not ready!
[WARNING] PulseAudioService: pa_context_connect() failed
[DEBUG] ✅ CommonControl: 公共控制模块已创建
[W][20595.547785] pw.conf      | [          conf.c: 1031 try_load_conf()] can't load config client-rt.conf: No such file or directory
[E][20595.547805] pw.conf      | [          conf.c: 1060 pw_conf_load_conf_for_context()] can't load config client-rt.conf: No such file or directory
[ALSOFT] (EE) Failed to create PipeWire event context (errno: 2)
[DEBUG] 🔊 CommonControl: 音频播放器已初始化
[DEBUG] 🔗 CommonControl: SystemConfig已连接
[DEBUG] 🔗 CommonControl: NetworkTask已连接
[DEBUG] 🔗 CommonControl: 已连接 registerValueReceived 信号
[DEBUG] 🔗 CommonControl: OperationLogDB已连接
[DEBUG] 🔗 CommonControl: RuntimeTracker已连接
[DEBUG] ✅ MaintenanceControl: 检修模式控制已创建
[DEBUG] ✅ LocalControl: 就地模式控制已创建
[DEBUG] ✅ ProtectionMonitorService: 保护监控服务已创建
[DEBUG] 🔗 ProtectionMonitorService: ProtectionConfigManager 已连接
[DEBUG] 🔗 ProtectionMonitorService: NetworkTask 已连接（功能暂时禁用）
[DEBUG] ✅ AlarmPlaybackService: 报警播放服务已创建
[DEBUG] 🎙️ 初始化 Sherpa-ONNX TTS引擎...
[DEBUG] 🎙️ SherpaOnnxTTS: 初始化TTS封装（进程通信模式）
[DEBUG]   使用TTS模型: "vits-zh-aishell3"
[DEBUG]   模型目录: "/app/tts_models/vits-zh-aishell3"
[DEBUG]   语速: 0.9   音量: 1
[DEBUG] 🎙️ SherpaOnnxTTS: 初始化TTS引擎，模型目录: "/app/tts_models/vits-zh-aishell3"
[DEBUG] ✅ 找到TTS服务: "/app/sherpa_tts_service"
[DEBUG] 🚀 启动TTS服务进程...
[DEBUG] ✅ TTS服务进程已启动，PID: 31
[DEBUG] 📤 发送命令: "{\"command\":\"init\",\"model_dir\":\"/app/tts_models/vits-zh-aishell3\"}\n"
[WARNING] Warning: "Failed to connect: Connection refused"
[WARNING] Warning: "Failed to connect: Connection refused"
[DEBUG] 📥 收到响应: "{\"success\":true,\"message\":\"TTS engine initialized successfully. Sample rate: 8000Hz\"}"
[DEBUG] ✅ SherpaOnnxTTS初始化成功: "TTS engine initialized successfully. Sample rate: 8000Hz"
[DEBUG] ✅ Sherpa-ONNX TTS初始化成功
[DEBUG] 设置语速: 0.9
[DEBUG] 🗂️  AlarmPlaybackService: 初始化TTS缓存
[DEBUG]   TTS缓存目录（持久化）: "/app/appdata/tts_cache"
[DEBUG]   开始预缓存 10 个常用报警文本...
[DEBUG]   ✓ 已存在: "急停保护报警"
[DEBUG]   ✓ 已存在: "主机急停保护报警"
[DEBUG]   ✓ 已存在: "沿线急停"
[DEBUG]   ✓ 已存在: "打滑保护报警"
[DEBUG]   ✓ 已存在: "跑偏保护报警"
[DEBUG]   ✓ 已存在: "堆煤保护报警"
[DEBUG]   ✓ 已存在: "撕裂保护报警"
[DEBUG]   ✓ 已存在: "超速保护报警"
[DEBUG]   ✓ 已存在: "低速保护报警"
[DEBUG]   ✓ 已存在: "温度保护报警"
[DEBUG] ✅ TTS缓存初始化完成，已缓存 10 个文本
All control modules created
Setting context properties...
Context properties set
Adding QML import path...
QML import path added
Loading QML from: qrc:/qt/qml/BeltControlQml/main.qml
arm_release_ver: g13p0-01eac0, rk_so_ver: 10
[DEBUG] VideoCallManager: Created (video subsystem will be initialized after PJSIP startup)
[DEBUG] ✅ QtVideoPreview created (Qt Multimedia-based)
[DEBUG] ✅ QVideoSink created
[DEBUG] ✅ QMediaCaptureSession created and connected to video sink
[DEBUG] ✅ QtVideoPreview created (for QML integration)
[DEBUG] ✅ LocalVideoManager created (PJSIP preview mode)
[DEBUG] ✅ LocalVideoManager created (for PJSIP preview)
[DEBUG] ✅ RemoteVideoManager created (Event-driven Push mode + Async v6)
[DEBUG] ✅ FrameProcessorThread created
[DEBUG] ✅ [ASYNC] Frame processor thread started
[DEBUG] ✅ RemoteVideoManager created (for video calls)
[DEBUG] ✅ [FIX 100.246] Risip instance will be created on-demand when user enters SIP settings
[DEBUG] 🚀 [ASYNC] FrameProcessorThread started
[DEBUG] 🔧 [CONTACT DB] Initializing contact database...
[DEBUG] 📁 [CONTACT DB] Database path: "/app/appdata/contacts.db"
[DEBUG] ✅ [CONTACT DB] Database opened successfully
[DEBUG] ✅ [CONTACT DB] Tables and indexes created
[DEBUG] ✅ [CONTACT DB] Loaded 0 contacts into cache
[DEBUG] ✅ [CONTACT DB] Initialization complete, loaded 0 contacts
[DEBUG] 🔧 [CONTACT DB] Initializing contact database...
[DEBUG] 📁 [CONTACT DB] Database path: "/app/appdata/contacts.db"
[WARNING] QSqlDatabasePrivate::removeDatabase: connection 'ContactDatabase' is still in use, all queries will cease to work.
[WARNING] QSqlDatabasePrivate::addDatabase: duplicate connection name 'ContactDatabase', old connection removed.
[DEBUG] ✅ [CONTACT DB] Database opened successfully
[DEBUG] ✅ [CONTACT DB] Tables and indexes created
[DEBUG] ✅ [CONTACT DB] Loaded 0 contacts into cache
[DEBUG] ✅ [CONTACT DB] Initialization complete, loaded 0 contacts
[DEBUG] ═══════════════════════════════════════════════════════
[DEBUG] 🔥🔥🔥 SipPhoneManager VERSION 2026-01-18-01:00
[DEBUG] 🔥🔥🔥 FIX 100.246 - 懒加载：用户进入 SIP 设置时才创建 Risip
[DEBUG] ═══════════════════════════════════════════════════════
[DEBUG] 🔥 [Keyboard Overlay] Enabled changed: false
[DEBUG] 📹 [Settings] Saved video device index: 0
[DEBUG] 📢 [Settings] Saved audio input device index: 0
[DEBUG] 🔊 [Settings] Saved audio output device index: 0
[DEBUG] [DEBUG] accountsModel() called but risipInstance is null
[DEBUG] [DEBUG] accountsModel() called but risipInstance is null
[DEBUG] 📋 [Dialog Background MouseArea] Initialized
[DEBUG] ═══════════════════════════════════════════════════════
[DEBUG] 🔥🔥🔥 SIP SETTINGS PAGE LOADED - VERSION 2026-01-18-12:00
[DEBUG] 🔥🔥🔥 FIX 100.246: 前后端分离完成，设备枚举通过 signal 更新
[DEBUG] ═══════════════════════════════════════════════════════
[DEBUG] [AddAccountDialog] Dialog created
[DEBUG] 🖱️ [Dialog Header MouseArea] Initialized
[DEBUG]    - Size: 0 x 40
[DEBUG]    - Enabled: true
[DEBUG] 🔥 [Keyboard Overlay] Created in contentItem
[DEBUG] 🔥 [Keyboard Close MouseArea] Created
[DEBUG]    - Size: 0 x 538
[DEBUG]    - z: 200
[DEBUG] 📜 [dialogFlickable] Initialized
[DEBUG]    - Size: 0 x 538
[DEBUG]    - contentHeight: 380
[DEBUG]    - interactive: false
[DEBUG] 📝 [passwordField] Initialized - z: 0
[DEBUG] 📝 [usernameField] Initialized - z: 0
[DEBUG] 🖱️ [Dialog Content MouseArea] Initialized - z: 1
[DEBUG] 🔥 [QML Camera] ComboBox initialized
[DEBUG]    Initial model count: 0
[DEBUG]    CurrentIndex: 0
[DEBUG] 🔥 [QML Mic] ComboBox initialized
[DEBUG]    Initial model count: 0
[DEBUG]    CurrentIndex: 0
[DEBUG] 🔥 [QML Speaker] ComboBox initialized
[DEBUG]    Initial model count: 0
[DEBUG]    CurrentIndex: 0
[DEBUG] [QML] ListView initialized
[DEBUG] [DEBUG] accountsModel() called but risipInstance is null
[DEBUG] [QML] Model object: null
[DEBUG] [QML] Model count: 0
[DEBUG] [DEBUG] accountsModel() called but risipInstance is null
[DEBUG] [QML] Model rowCount: null
[WARNING] No active account - cannot get call history
[WARNING] Unable to set the pipeline to the paused state.
[DEBUG] ✅ VideoSinkItem created (ItemHasContents disabled until first frame)
[DEBUG] ✅ VideoSinkItem created (ItemHasContents disabled until first frame)
[DEBUG] 🔍 [QML] Video Accept Button visibility check:
[DEBUG]     callStatus: 就绪 → hasCallStatus: false
[DEBUG]     isIncomingVideoCall: false
[DEBUG]     → visible: false
[DEBUG] Number display text changed to: 请输入号码
[DEBUG] ✅ ========================================
[DEBUG] ✅ SipDialPage loaded and ready!
[DEBUG] ✅ ========================================
[DEBUG] ✅ Remote VideoSinkItem created
[DEBUG] ✅ Connected to video sink, waiting for frames...
[DEBUG] ✅ Remote VideoSinkItem connected to video sink
[DEBUG] ✅ VideoSinkItem created for local preview
[DEBUG] ✅ Connected to video sink, waiting for frames...
[DEBUG] ✅ VideoSinkItem connected to PJSIP local video sink
[DEBUG] ✅ [RINGTONE] MediaPlayer created with system ringtone
[DEBUG] ✅ SipDialPage Loader: Ready (before onLoaded)
[DEBUG] ✅ ✅ ✅ SipDialPage Loader: Successfully loaded!
[DEBUG] 📇 Loading contacts from database...
[DEBUG] 📇 [SipPhoneManager] Loaded 0 contacts from database
[DEBUG] 📇 Loaded 0 contacts from database
[DEBUG] ⌨️ [InputPanel] Visibility changed: false
[DEBUG] 🖱️ [Keyboard Debug MouseArea] Visible changed: false
[DEBUG] ========================================
[DEBUG] 🔧 [Keyboard Container] Initialized in Overlay
[DEBUG]    - parent: QQuickOverlay(0x55a8cc8140)
[DEBUG]    - parent is Overlay: true
[DEBUG]    - Initial z-index: 1 ⬅️ Will be dynamically adjusted
[DEBUG] ========================================
[DEBUG] ========================================
[DEBUG] 🔧 [Keyboard Wrapper] Initialized
[DEBUG]    - z-index: 2 (above keyboardOverlay)
[DEBUG]    - width: 0
[DEBUG]    - height: 600
[DEBUG] ========================================
[DEBUG] ========================================
[DEBUG] ⌨️ [InputPanel] Virtual keyboard initialized
[DEBUG]    - parent: QQuickItem(0x55a9844420)
[DEBUG]    - z-index: 1
[DEBUG]    - width: 0
[DEBUG]    - height: 600
[DEBUG]    - enabled: true
[DEBUG]    - visible: false
[DEBUG] ========================================
[DEBUG] 🖱️ [Keyboard Debug MouseArea] Initialized
[DEBUG]    - Size: 0 x 600
[DEBUG]    - Z-index: -1
[DEBUG]    - Enabled: true
[DEBUG] =========================================
[DEBUG] 🔥🔥🔥 VERSION: 2025-12-19-07:00 DYNAMIC-Z 🔥🔥🔥
[DEBUG] 🛡️ [Main keyboardOverlay] DISABLED - using Dialog overlay instead
[DEBUG]    - z-index: 3 (parent container z: 1 - DYNAMIC)
[DEBUG]    - visible: false (SHOULD be false)
[DEBUG]    - enabled: false (SHOULD be false)
[DEBUG] =========================================
[WARNING] qrc:/qt/qml/BeltControlQml/Input1/Input1Content/Screen01.ui.qml:358:13: QML QQuickImage: Cannot open: qrc:/qt/qml/BeltControlQml/Input1/Input1Content/images/group2_frame3_bottom_right.png
[WARNING] qrc:/qt/qml/BeltControlQml/Input1/Input1Content/Screen01.ui.qml:205:9: QML QQuickImage: Cannot open: qrc:/qt/qml/BeltControlQml/Input1/Input1Content/images/group2_frame1.png
[DEBUG] ✅ Input1 Screen01 加载成功
[DEBUG]    [布局] 屏幕尺寸: 0 x 0
[DEBUG]    [布局] 缩放因子: 0.00
[DEBUG]    [布局] 显示尺寸: 0 x 0
[WARNING] Qt Quick Layouts: Detected recursive rearrange. Aborting after two iterations.
[WARNING] Qt Quick Layouts: Detected recursive rearrange. Aborting after two iterations.
[DEBUG] [FULLSCREEN DEBUG] 验证修改0117Screen size: 1920 x 1200
[DEBUG] [FULLSCREEN DEBUG] Window size: 1920 x 1200
[DEBUG] [FULLSCREEN DEBUG] Current visibility: 2
[DEBUG] [FULLSCREEN DEBUG] Platform: linux
[DEBUG] [FULLSCREEN DEBUG] Device 151 (1920x1080) detected, EGLFS naturally fullscreen
[DEBUG] Input1Page 已加载
[DEBUG] ✅ DeviceOperationLog: 已加载 0 条日志记录
[DEBUG] 📋 CommonControl: 设置设备反馈配置 - "张紧" 使用反馈: true 反馈通道: 0 反馈延时: 3 秒
[DEBUG] 📋 CommonControl: 设置设备反馈配置 - "抱闸" 使用反馈: true 反馈通道: 1 反馈延时: 3 秒
[DEBUG] 📋 CommonControl: 设置设备反馈配置 - "洒水" 使用反馈: true 反馈通道: 2 反馈延时: 3 秒
[DEBUG] 📋 CommonControl: 设置设备反馈配置 - "1号电机" 使用反馈: true 反馈通道: 3 反馈延时: 3 秒
[DEBUG] 📋 CommonControl: 设置设备反馈配置 - "2号电机" 使用反馈: true 反馈通道: 4 反馈延时: 3 秒
[DEBUG] 📋 CommonControl: 设置设备反馈配置 - "破碎机" 使用反馈: true 反馈通道: 5 反馈延时: 3 秒
[DEBUG] 📋 CommonControl: 设置设备反馈配置 - "转载机" 使用反馈: true 反馈通道: 6 反馈延时: 3 秒
[DEBUG] 📋 CommonControl: 设置设备反馈配置 - "前刮板" 使用反馈: true 反馈通道: 7 反馈延时: 3 秒
[DEBUG] 📋 CommonControl: 设置设备反馈配置 - "后刮板" 使用反馈: true 反馈通道: 8 反馈延时: 3 秒
[DEBUG] 📋 CommonControl: 设置设备反馈配置 - "1号乳化液泵" 使用反馈: true 反馈通道: 9 反馈延时: 3 秒
[DEBUG] 📋 CommonControl: 设置设备反馈配置 - "2号乳化液泵" 使用反馈: true 反馈通道: 10 反馈延时: 3 秒
[DEBUG] 📋 CommonControl: 设置设备反馈配置 - "3号乳化液泵" 使用反馈: true 反馈通道: 11 反馈延时: 3 秒
[DEBUG] 📋 CommonControl: 设置设备反馈配置 - "4号乳化液泵" 使用反馈: true 反馈通道: 12 反馈延时: 3 秒
[DEBUG] 📋 CommonControl: 设置设备反馈配置 - "1号喷雾泵" 使用反馈: true 反馈通道: 13 反馈延时: 3 秒
[DEBUG] 📋 CommonControl: 设置设备反馈配置 - "2号喷雾泵" 使用反馈: true 反馈通道: 14 反馈延时: 3 秒
[DEBUG] 📋 CommonControl: 设置设备反馈配置 - "3号喷雾泵" 使用反馈: true 反馈通道: 15 反馈延时: 3 秒
[DEBUG] ✅ ParameterSettings: 已同步 16 个设备的反馈配置
[DEBUG] ✅ OperationLogPanel: 已加载 0 条日志记录
[WARNING] qrc:/qt/qml/BeltControlQml/Input1/Input1Content/Screen01.ui.qml:20:5: Unable to assign [undefined] to QColor
[WARNING] qrc:/qt/qml/BeltControlQml/main.qml:397:17: Unable to assign [undefined] to QString
[WARNING] qrc:/qt/qml/BeltControlQml/components/sip_phone/pages/SipDialPage.qml:563: ReferenceError: micMuted is not defined
engine.load() completed
QML loaded successfully, starting event loop
Object created callback: obj=55a87add40
[DEBUG] ❌ [RINGTONE] Error: 1 Resource not found.
[DEBUG] ❌ [RINGTONE] Error: 1 GStreamer error: state change failed and some element failed to post a proper error message with the reason for the failure.
[DEBUG] ❌ [RINGTONE] Error: 1 Resource not found.
[DEBUG] ❌ [RINGTONE] Error: 1 GStreamer error: state change failed and some element failed to post a proper error message with the reason for the failure.
[WARNING] Warning: "Failed to connect: Connection refused"
[DEBUG] 🔔 [RINGTONE] Using system ringtone: "C:/Windows/Media/Ring01.wav"
[DEBUG] 🔔 [RINGTONE] URL format: "file:///C:/Windows/Media/Ring01.wav"
[DEBUG] 🔔 [RINGTONE] Loaded custom ringtone: file:///C:/Windows/Media/Ring01.wav
[DEBUG] SIP button clicked, opening SIP popup...
[DEBUG] SIP Popup opened successfully
[DEBUG] Popup size: 800 x 1034.1000000000001
[DEBUG] [DEBUG] Deferred initialization starting...
[DEBUG] ════════════════════════════════════════════════════════════
[DEBUG] 🔥🔥🔥 [ENTRY] initializeEndpoint() called!
[DEBUG]    [TIMING] Called at: "2026-01-18 07:25:55.987"
[DEBUG]    [STATE] d->initialized = false
[DEBUG]    [STATE] d->risipInstance = NULL
[DEBUG] ════════════════════════════════════════════════════════════
[DEBUG] Initializing SIP endpoint with Risip SDK...
[DEBUG] Creating Risip instance (not yet created by device enumeration)...
[DEBUG] ✅ Risip instance created
[DEBUG] Starting Risip endpoint with fixed PJSIP (FD_SETSIZE=1024)...
[DEBUG] Configs files cannot be found nor be read!!
07:25:55.992         os_core_unix.c !pjlib 2.16 for POSIX initialized
07:25:55.993         sip_endpoint.c  .Creating endpoint instance...
07:25:55.993                  pjlib  .select() I/O Queue created (0x55ab9b69a8)
07:25:55.994         sip_endpoint.c  .Module "mod-msg-print" registered
07:25:55.994        sip_transport.c  .Transport manager created.
07:25:55.994           pjsua_core.c  .PJSUA state changed: NULL --> CREATED
07:25:55.994         sip_endpoint.c  .Module "mod-pjsua-log" registered
07:25:55.994         sip_endpoint.c  .Module "mod-tsx-layer" registered
07:25:55.994         sip_endpoint.c  .Module "mod-stateful-util" registered
07:25:55.994         sip_endpoint.c  .Module "mod-ua" registered
07:25:55.994         sip_endpoint.c  .Module "mod-100rel" registered
07:25:55.994         sip_endpoint.c  .Module "mod-pjsua" registered
07:25:55.994         sip_endpoint.c  .Module "mod-invite" registered
07:25:56.135             alsa_dev.c  ..ALSA driver found 11 devices
07:25:56.135             alsa_dev.c  ..ALSA initialized
07:25:56.135                  pjlib  ..select() I/O Queue created (0x55abab3068)
07:25:56.141            pjsua_vid.c  ..Initializing video subsystem..
07:25:56.141             vid_conf.c  ...Created video conference bridge with 32 ports
07:25:56.141    ffmpeg_vid_codecs.c  ...Configuring RKMPP H.264 hardware codec (FFmpeg 6.0)
07:25:56.141    ffmpeg_vid_codecs.c  ...✅ [FIX 100.16] Hardware encoder ENABLED (global variable enable_hw_encoder=1)
07:25:56.141    ffmpeg_vid_codecs.c  ...   Using hardware encoder: h264_rkmpp
07:25:56.142    ffmpeg_vid_codecs.c  ...Found hardware encoder: h264_rkmpp
07:25:56.142    ffmpeg_vid_codecs.c  ...✅ H.264 RKMPP encoder manually registered:
07:25:56.142    ffmpeg_vid_codecs.c  ...   enc=0x7f88ca9740, enabled=1, dir=0x1
07:25:56.142    ffmpeg_vid_codecs.c  ...   dec_fmt_id_cnt=1, fps_cnt=3
07:25:56.142    ffmpeg_vid_codecs.c  ...Found hardware decoder: h264_rkmpp
07:25:56.142    ffmpeg_vid_codecs.c  ...Configuring RKMPP VP8 hardware codec
07:25:56.142    ffmpeg_vid_codecs.c  ...✅ [FIX 100.16] Hardware encoder ENABLED (global variable enable_hw_encoder=1)
07:25:56.142    ffmpeg_vid_codecs.c  ...   Using hardware encoder: vp8_rkmpp
07:25:56.142    ffmpeg_vid_codecs.c  ...WARNING: Hardware encoder 'vp8_rkmpp' not found
07:25:56.142    ffmpeg_vid_codecs.c  ...Found hardware decoder: vp8_rkmpp
07:25:56.142    ffmpeg_vid_codecs.c  ...Configuring RKMPP VP9 hardware codec
07:25:56.142    ffmpeg_vid_codecs.c  ...✅ [FIX 100.16] Hardware encoder ENABLED (global variable enable_hw_encoder=1)
07:25:56.142    ffmpeg_vid_codecs.c  ...   Using hardware encoder: vp9_rkmpp
07:25:56.142    ffmpeg_vid_codecs.c  ...WARNING: Hardware encoder 'vp9_rkmpp' not found
07:25:56.142    ffmpeg_vid_codecs.c  ...Found hardware decoder: vp9_rkmpp
07:25:56.142    ffmpeg_vid_codecs.c  ...✅ FFmpeg codec factory registered successfully
07:25:56.142    ffmpeg_vid_codecs.c  ...  📹 Codec[0]: H264
07:25:56.142    ffmpeg_vid_codecs.c  ...      enc=0x7f88ca9740, dec=0x7f88ca9190, dir=0x3, enabled=1
07:25:56.142    ffmpeg_vid_codecs.c  ...      dec_fmt_id_cnt=1, clock_rate=90000
07:25:56.142    ffmpeg_vid_codecs.c  ...  📹 Codec[1]: VP8
07:25:56.142    ffmpeg_vid_codecs.c  ...      enc=0x7f88c8d978, dec=0x7f88ca9000, dir=0x3, enabled=1
07:25:56.142    ffmpeg_vid_codecs.c  ...      dec_fmt_id_cnt=1, clock_rate=90000
07:25:56.142    ffmpeg_vid_codecs.c  ...  📹 Codec[2]: VP9
07:25:56.142    ffmpeg_vid_codecs.c  ...      enc=0x7f88cd1808, dec=0x7f88ca8f38, dir=0x3, enabled=1
07:25:56.142    ffmpeg_vid_codecs.c  ...      dec_fmt_id_cnt=3, clock_rate=90000
07:25:56.142    ffmpeg_vid_codecs.c  ...  📹 Codec[3]: H263-1998
07:25:56.142    ffmpeg_vid_codecs.c  ...      enc=0x7f88cc7348, dec=0x7f88cc67a0, dir=0x3, enabled=1
07:25:56.142    ffmpeg_vid_codecs.c  ...      dec_fmt_id_cnt=1, clock_rate=90000
07:25:56.142    ffmpeg_vid_codecs.c  ...  📹 Codec[4]: H263
07:25:56.142    ffmpeg_vid_codecs.c  ...      enc=0x7f88cc7458, dec=0x7f88cc6868, dir=0x3, enabled=1
07:25:56.142    ffmpeg_vid_codecs.c  ...      dec_fmt_id_cnt=1, clock_rate=90000
07:25:56.142    ffmpeg_vid_codecs.c  ...  📹 Codec[5]: H261
07:25:56.142    ffmpeg_vid_codecs.c  ...      enc=0x7f88cc6698, dec=0x7f88c839e0, dir=0x3, enabled=1
07:25:56.142    ffmpeg_vid_codecs.c  ...      dec_fmt_id_cnt=1, clock_rate=90000
07:25:56.142    ffmpeg_vid_codecs.c  ...  📹 Codec[6]: JPEG
07:25:56.142    ffmpeg_vid_codecs.c  ...      enc=0x7f88cc8738, dec=0x7f88cc8518, dir=0x3, enabled=1
07:25:56.142    ffmpeg_vid_codecs.c  ...      dec_fmt_id_cnt=4, clock_rate=90000
07:25:56.142    ffmpeg_vid_codecs.c  ...  📹 Codec[7]: MP4V
07:25:56.142    ffmpeg_vid_codecs.c  ...      enc=0x7f88cc9040, dec=0x7f88cc8f30, dir=0x3, enabled=1
07:25:56.142    ffmpeg_vid_codecs.c  ...      dec_fmt_id_cnt=1, clock_rate=90000
07:25:56.142    ffmpeg_vid_codecs.c  ...  Total enabled codecs: 8
07:25:56.285             v4l2_dev.c  ...Video4Linux2 has 1 devices
07:25:56.339              sdl_dev.c  ...SDL 2.30 initialized
07:25:56.340         colorbar_dev.c  ...Colorbar video src initialized with 2 device(s):
07:25:56.340         colorbar_dev.c  ... 0: Colorbar generator
07:25:56.340         colorbar_dev.c  ... 1: Colorbar-active
07:25:56.340         sip_endpoint.c  .Module "mod-evsub" registered
07:25:56.340         sip_endpoint.c  .Module "mod-presence" registered
07:25:56.340         sip_endpoint.c  .Module "mod-dlg_even" registered
07:25:56.340         sip_endpoint.c  .Module "mod-mwi" registered
07:25:56.340         sip_endpoint.c  .Module "mod-refer" registered
07:25:56.340         sip_endpoint.c  .Module "mod-pjsua-pres" registered
07:25:56.340         sip_endpoint.c  .Module "mod-pjsua-im" registered
07:25:56.340         sip_endpoint.c  .Module "mod-pjsua-options" registered
07:25:56.340           pjsua_core.c  .2 SIP worker threads created
07:25:56.340           pjsua_core.c  .pjsua version 2.16 for Linux-6.1.57/aarch64/glibc-2.39 initialized
07:25:56.340           pjsua_core.c  .PJSUA state changed: CREATED --> INIT
07:25:56.340           pjsua_core.c  PJSUA state changed: INIT --> STARTING
07:25:56.340         sip_endpoint.c  .Module "mod-unsolicited-mwi" registered
07:25:56.340           pjsua_core.c  .PJSUA state changed: STARTING --> RUNNING
[DEBUG] ✅ RisipEndpoint: Installed audio routing, call state, and incoming call callback wrappers
[DEBUG] RisipEndpoint: Total video devices: 4
[DEBUG]   Device 0 : USB camera: USB camera | Dir: 1 | Driver: v4l2
[DEBUG]   ✅ Selected 0 as default capture device: USB camera: USB camera
[DEBUG]   Device 1 : SDL renderer | Dir: 2 | Driver: SDL
[DEBUG]   Device 2 : Colorbar generator | Dir: 1 | Driver: Colorbar
[DEBUG]   Device 3 : Colorbar-active | Dir: 1 | Driver: Colorbar
[DEBUG] 🎵 [AUDIO DEV] Configuring global audio device (separate input/output)...
[DEBUG]   Total audio devices: 11
[DEBUG]     Device 0 : "hw:CARD=rockchiphdmi0,DEV=0" | Caps: 0 in / 0 out | Driver: ALSA
[DEBUG]       [PJSIP HDMI DEBUG] ═══════════════════════════════════
[DEBUG]       [PJSIP HDMI] Device: "hw:CARD=rockchiphdmi0,DEV=0"
[DEBUG]       [PJSIP HDMI] Driver: ALSA
[DEBUG]       [PJSIP HDMI] input_count: 0
[DEBUG]       [PJSIP HDMI] output_count: 0 ← 问题核心
[DEBUG]       [PJSIP HDMI] default_samples_per_sec: 8000
[DEBUG]       [PJSIP HDMI] caps: 30
[DEBUG]       [PJSIP HDMI] routes: 0
[DEBUG]       [PJSIP HDMI] ext_fmt_cnt: 0
[DEBUG]       [PJSIP HDMI DEBUG] ═══════════════════════════════════
[DEBUG]     Device 1 : "plughw:CARD=rockchiphdmi0,DEV=0" | Caps: 0 in / 0 out | Driver: ALSA
[DEBUG]       [PJSIP HDMI DEBUG] ═══════════════════════════════════
[DEBUG]       [PJSIP HDMI] Device: "plughw:CARD=rockchiphdmi0,DEV=0"
[DEBUG]       [PJSIP HDMI] Driver: ALSA
[DEBUG]       [PJSIP HDMI] input_count: 0
[DEBUG]       [PJSIP HDMI] output_count: 0 ← 问题核心
[DEBUG]       [PJSIP HDMI] default_samples_per_sec: 8000
[DEBUG]       [PJSIP HDMI] caps: 30
[DEBUG]       [PJSIP HDMI] routes: 0
[DEBUG]       [PJSIP HDMI] ext_fmt_cnt: 0
[DEBUG]       [PJSIP HDMI] ⚠️ output_count=0 BUT this is plughw device
[DEBUG]       [PJSIP HDMI] → Will FORCE select it (bypass ALSA bug)
[DEBUG]       [PJSIP HDMI DEBUG] ═══════════════════════════════════
[DEBUG]       ✅ FORCE select plughw device (bypass output_count=0 ALSA bug)
[DEBUG]     Device 2 : "default:CARD=rockchiphdmi0" | Caps: 0 in / 0 out | Driver: ALSA
[DEBUG]       [PJSIP HDMI DEBUG] ═══════════════════════════════════
[DEBUG]       [PJSIP HDMI] Device: "default:CARD=rockchiphdmi0"
[DEBUG]       [PJSIP HDMI] Driver: ALSA
[DEBUG]       [PJSIP HDMI] input_count: 0
[DEBUG]       [PJSIP HDMI] output_count: 0 ← 问题核心
[DEBUG]       [PJSIP HDMI] default_samples_per_sec: 8000
[DEBUG]       [PJSIP HDMI] caps: 30
[DEBUG]       [PJSIP HDMI] routes: 0
[DEBUG]       [PJSIP HDMI] ext_fmt_cnt: 0
[DEBUG]       [PJSIP HDMI DEBUG] ═══════════════════════════════════
[DEBUG]     Device 3 : "sysdefault:CARD=rockchiphdmi0" | Caps: 0 in / 0 out | Driver: ALSA
[DEBUG]       [PJSIP HDMI DEBUG] ═══════════════════════════════════
[DEBUG]       [PJSIP HDMI] Device: "sysdefault:CARD=rockchiphdmi0"
[DEBUG]       [PJSIP HDMI] Driver: ALSA
[DEBUG]       [PJSIP HDMI] input_count: 0
[DEBUG]       [PJSIP HDMI] output_count: 0 ← 问题核心
[DEBUG]       [PJSIP HDMI] default_samples_per_sec: 8000
[DEBUG]       [PJSIP HDMI] caps: 30
[DEBUG]       [PJSIP HDMI] routes: 0
[DEBUG]       [PJSIP HDMI] ext_fmt_cnt: 0
[DEBUG]       [PJSIP HDMI DEBUG] ═══════════════════════════════════
[DEBUG]     Device 4 : "dmix:CARD=rockchiphdmi0,DEV=0" | Caps: 0 in / 0 out | Driver: ALSA
[DEBUG]       [PJSIP HDMI DEBUG] ═══════════════════════════════════
[DEBUG]       [PJSIP HDMI] Device: "dmix:CARD=rockchiphdmi0,DEV=0"
[DEBUG]       [PJSIP HDMI] Driver: ALSA
[DEBUG]       [PJSIP HDMI] input_count: 0
[DEBUG]       [PJSIP HDMI] output_count: 0 ← 问题核心
[DEBUG]       [PJSIP HDMI] default_samples_per_sec: 8000
[DEBUG]       [PJSIP HDMI] caps: 30
[DEBUG]       [PJSIP HDMI] routes: 0
[DEBUG]       [PJSIP HDMI] ext_fmt_cnt: 0
[DEBUG]       [PJSIP HDMI DEBUG] ═══════════════════════════════════
[DEBUG]     Device 5 : "hw:CARD=camera,DEV=0" | Caps: 1 in / 0 out | Driver: ALSA
[DEBUG]       ✅ Selected as capture device (input)
[DEBUG]     Device 6 : "plughw:CARD=camera,DEV=0" | Caps: 1 in / 0 out | Driver: ALSA
[DEBUG]     Device 7 : "default:CARD=camera" | Caps: 1 in / 0 out | Driver: ALSA
[DEBUG]     Device 8 : "sysdefault:CARD=camera" | Caps: 1 in / 0 out | Driver: ALSA
[DEBUG]     Device 9 : "front:CARD=camera,DEV=0" | Caps: 1 in / 0 out | Driver: ALSA
[DEBUG]     Device 10 : "dsnoop:CARD=camera,DEV=0" | Caps: 1 in / 0 out | Driver: ALSA
[DEBUG]   Trying capture device 5 + playback device 1 ...
07:25:56.340            pjsua_aud.c  Set sound device: capture=5, playback=1, mode=0, use_default_settings=0
07:25:56.340            pjsua_aud.c  .Opening sound device (speaker + mic) PCM@16000/2/20ms
07:25:56.341             alsa_dev.c  ..ALSA lib: open '/dev/snd/pcmC0D0p' failed (-16): Device or resource busy
07:25:56.341             alsa_dev.c  ..Unable to open playback device 'plughw:CARD=rockchiphdmi0,DEV=0', err: Device or resource busy
07:25:56.341             alsa_dev.c  ..⚠️ [FIX 100.247] Playback device failed to open, but will continue if capture succeeds (independent device mode)
07:25:56.344             alsa_dev.c  ..✅ [FIX 100.247] Capture device opened successfully
07:25:56.344             alsa_dev.c  ..✅ [FIX 100.247] Audio stream created with CAPTURE ONLY (playback failed but capture succeeded)
07:25:56.344             alsa_dev.c  ..✅ [FIX 100.247] Final param.dir = 1 (1=PLAYBACK, 2=CAPTURE, 3=BOTH)
07:25:56.345         ec0x55ababf0d0  ..Speex AEC created, clock_rate=16000, channel=2, samples per frame=640, tail length=200 ms, latency=0 ms
07:25:56.345           sound_port.c  ..Sound port uses internal (or software) clock
07:25:56.345             alsa_dev.c  ..✅ [FIX 100.247] Capture thread started
07:25:56.345             alsa_dev.c  🎤 [FIX 100.247 DEBUG] Capture thread started
[DEBUG]   ✅ Global audio device set: capture= 5 , playback= 1
07:25:56.345             alsa_dev.c  🎤 [DEBUG] ca_pcm pointer: 0x55abac0600
07:25:56.345             alsa_dev.c  🎤 [DEBUG] Expected frames per read: 320
[DEBUG] 🎵 [CODEC] Configuring audio codecs (reduced set to avoid IP fragmentation)...
07:25:56.345             alsa_dev.c  🎤 [DEBUG] Buffer size: 1280 bytes
[DEBUG]   ✅ PCMA/8000 enabled (priority: 215)
[DEBUG]   ✅ PCMU/8000 enabled (priority: 214)
[DEBUG]   ✅ opus/48000/2 enabled (priority: 213) - 用户要求保留，后续使用
[DEBUG]   ⛔ GSM/8000 disabled (to reduce SDP size)
[DEBUG]   ⛔ iLBC/8000 disabled (to reduce SDP size)
07:25:56.345           endpoint.cpp !pjsua_codec_set_priority(&codec_str, priority) error: Not found (PJ_ENOTFOUND) (status=70006) [../src/pjsua2/endpoint.cpp:2625]
[DEBUG] Warning: Could not disable telephone-event 8kHz: "Not found (PJ_ENOTFOUND)"
07:25:56.346           endpoint.cpp  pjsua_codec_set_priority(&codec_str, priority) error: Not found (PJ_ENOTFOUND) (status=70006) [../src/pjsua2/endpoint.cpp:2625]
[DEBUG] Warning: Could not disable telephone-event 48kHz: "Not found (PJ_ENOTFOUND)"
[DEBUG]   ⛔ g722/16000 disabled
[DEBUG] ✅ [CODEC] Audio codec configuration complete
[DEBUG]   Enabled: PCMA, PCMU, Opus (3 codecs - 用户要求保留 Opus)
[DEBUG]   Disabled: GSM, iLBC, telephone-event, g722, speex
[DEBUG]   Expected SDP reduction: ~200 bytes (from 1682 → ~1480 bytes)
[DEBUG]   Target: < MTU 1500 bytes to avoid IP fragmentation
[DEBUG] ========================================
[DEBUG] 📹 [ATTEMPT 14] Configuring H264 for 720P (1280x720)...
[DEBUG] ========================================
07:25:56.346    ffmpeg_vid_codecs.c  🔍 ffmpeg_default_attr() START: codec=H264
07:25:56.346    ffmpeg_vid_codecs.c     Found codec desc=0x55729b5728, enabled=1
07:25:56.346    ffmpeg_vid_codecs.c     About to init enc_fmt: fmt_id=0x34363248, 640x480
07:25:56.346    ffmpeg_vid_codecs.c     After init enc_fmt: detail_type=2 (VIDEO=2)
07:25:56.346    ffmpeg_vid_codecs.c     After init dec_fmt: detail_type=2 (VIDEO=2)
07:25:56.346    ffmpeg_vid_codecs.c  ✅ ffmpeg_default_attr() END: enc_fmt.detail_type=2, dec_fmt.detail_type=2
[DEBUG]   Current H264 encoder settings:
[DEBUG]     TX size: 640 x 480
[DEBUG]     TX fps: 30 / 1
[DEBUG] ✅ H264 video codec configured: 640x480 (VGA) @ 30fps (TX/RX) - standard VGA resolution
[DEBUG] 📹 Enumerating AUDIO codecs:
[DEBUG]   AUDIO CODEC:  "PCMA/8000/1" "" 215
[DEBUG]   AUDIO CODEC:  "PCMU/8000/1" "" 214
[DEBUG]   AUDIO CODEC:  "opus/48000/2" "" 213
[DEBUG]   AUDIO CODEC:  "speex/32000/1" "" 0
[DEBUG]   AUDIO CODEC:  "speex/8000/1" "" 0
[DEBUG]   AUDIO CODEC:  "speex/16000/1" "" 0
[DEBUG]   AUDIO CODEC:  "G722/16000/1" "" 0
[DEBUG]   AUDIO CODEC:  "iLBC/8000/1" "" 0
[DEBUG]   AUDIO CODEC:  "GSM/8000/1" "" 0
[DEBUG]   AUDIO CODEC:  "L16/44100/2" "" 0
[DEBUG]   AUDIO CODEC:  "L16/44100/1" "" 0
[DEBUG] 📹 Enumerating VIDEO codecs using pjsua_vid_enum_codecs:
[DEBUG]   ✅ Found 4 video codecs:
[DEBUG]     [ 0 ] "H264/100" priority: 128
[DEBUG]     [ 1 ] "VP8/104" priority: 128
[DEBUG]     [ 2 ] "VP9/107" priority: 128
[DEBUG]     [ 3 ] "H263-1998/96" priority: 128
[DEBUG] SIP endpoint started successfully
[DEBUG] ✅ PJSIP log level set to 5 (maximum debug) after endpoint initialization
[DEBUG] ✅ RisipEndpoint: UI call state callback registered
[DEBUG] ✅ Registered call state callback for UI updates
[DEBUG] Initializing video subsystem (PJSIP is now ready)...
[DEBUG] VideoCallManager: Found 4 video devices
[DEBUG] VideoCallManager: Device 0 : USB camera: USB camera Driver: v4l2
[DEBUG] ✅ VideoCallManager: Selected camera 0 as default: USB camera: USB camera
[DEBUG] VideoCallManager: Device 1 : SDL renderer Driver: SDL
[DEBUG] VideoCallManager: Device 2 : Colorbar generator Driver: Colorbar
[DEBUG] VideoCallManager: Device 3 : Colorbar-active Driver: Colorbar
[DEBUG] ✅ VideoCallManager: Default capture device set to: 0
[DEBUG] 📹 Configuring H264 encoder parameters for optimal frame rate...
[DEBUG]   Current H264 encoder FPS: 30 / 1
[DEBUG] ✅ H264 encoder configured: 640x480 (VGA) @ 30fps (TX/RX)
[DEBUG] ✅ Using PJSIP's automatic H264 codec parameter negotiation
[DEBUG] 📹 Ensuring video codec priorities are set...
[DEBUG]   Set "H264/100" priority to 200 (highest)
[DEBUG]   Set "VP8/104" priority to 150
[DEBUG]   Set "VP9/107" priority to 140
[DEBUG] Setting video capture device in all accounts...
[DEBUG] ✅ Using real capture device ID from VideoCallManager: 0
[DEBUG] No accounts found yet (will be configured when account is created)
[DEBUG] Connected to RisipCallManager for incoming calls
[DEBUG] Loading saved accounts from QSettings...
[DEBUG] 📖 [Risip] 从持久化位置读取SIP账户配置: "/app/appdata/sip_accounts.ini"
[DEBUG] [DEBUG] 🔍 总账户数量: 2
[DEBUG] [DEBUG] 📖 从配置文件读取的defaultAccount: "sip:1001@192.168.1.4"
[DEBUG] [DEBUG] 📝 开始读取账户 0
[DEBUG] [DEBUG] ✅ 账户配置创建完成，URI: "sip:1000@192.168.1.4"
[DEBUG] [DEBUG] 🚀 准备调用createAccount()...
[DEBUG] [DEBUG] 🔹 createAccount() 开始
[DEBUG] [DEBUG] 🔹 配置有效，URI: "sip:1000@192.168.1.4"
[DEBUG] [DEBUG] 🔹 创建配置副本...
[DEBUG] [DEBUG] ✅ 配置副本创建完成
[DEBUG] [DEBUG] 🔹 创建RisipAccount对象...
[DEBUG] [DEBUG] ✅ RisipAccount对象创建完成
[DEBUG] [DEBUG] 🔹 先设置配置（避免信号处理中访问未初始化的配置）...
[DEBUG] [DEBUG] 🔹 setConfiguration() - 开始设置配置
[DEBUG] [DEBUG]    旧配置指针: 0x55a94de670
[DEBUG] [DEBUG]    新配置指针: 0x55aba9d220
[DEBUG] [DEBUG] 🔸 复制新配置内容到现有配置对象...
[DEBUG] [DEBUG] ✅ 配置内容已复制（原config对象由调用者管理）
[DEBUG] [DEBUG] 🔸 设置账户状态为NotCreated...
[DEBUG] [DEBUG] ✅ 状态已设置
[DEBUG] [DEBUG] 🔸 发出configurationChanged信号...
[DEBUG] [DEBUG] ✅ setConfiguration() 完成
[DEBUG] [DEBUG] ✅ setConfiguration()完成
[DEBUG] [DEBUG] 🗑️ 标记临时config副本稍后删除...
[DEBUG] [DEBUG] ✅ 临时config副本已标记为稍后删除
[DEBUG] [DEBUG] 🔹 获取sipEndpoint指针: 0x55a93fdfb8
[DEBUG] [DEBUG] ✅ sipEndpoint()指针有效
[DEBUG] [DEBUG] 🔹 调用account->setSipEndPoint()...
[DEBUG] [DEBUG] ✅ setSipEndPoint()完成
[DEBUG] [DEBUG] 🔹 添加到账户模型...
[DEBUG] [DEBUG] RisipAccountListModel::addSipAccount() - Before add, count: 0
[DEBUG] [DEBUG]   Adding account URI: "sip:1000@192.168.1.4"
[DEBUG] [DEBUG]   Server address: "192.168.1.4"
[DEBUG] [DEBUG] RisipAccountListModel::addSipAccount() - After add, count: 1
[DEBUG] [DEBUG]   Total accounts in hash: 1
[DEBUG] [DEBUG] ✅ addSipAccount()完成
[DEBUG] [DEBUG] 🔹 为账户创建联系人模型...
[DEBUG] [DEBUG] ✅ createModelsForAccount()完成
[DEBUG] [DEBUG] 🔹 为账户创建通话模型...
[DEBUG] 📁 [CALL HISTORY DB] Database path: "/app/appdata/call_history.db"
[DEBUG] 📁 [DATABASE] Initializing SQLite database at: "/app/appdata/call_history.db"
[DEBUG] ✅ [DATABASE] Database opened successfully
[DEBUG] ✅ [DATABASE] Tables and indexes created
[DEBUG] ✅ [DATABASE] Database initialized, total records: 4
[DEBUG] ✅ [DATABASE] Loaded 4 records from database
[DEBUG] ✅ [HISTORY MODEL] Loaded 4 records from database
[DEBUG] [DEBUG] ✅ createModelsForAccount()完成
[DEBUG] [DEBUG] ✅ createAccount()完成，返回账户对象
[DEBUG] [DEBUG] ✅ createAccount()返回成功
[DEBUG] [DEBUG] ✅ 账户 0 加载完成
[DEBUG] [DEBUG] 🗑️ 使用deleteLater()标记configuration删除
[DEBUG] [DEBUG] 📝 开始读取账户 1
[DEBUG] [DEBUG] ✅ 账户配置创建完成，URI: "sip:1001@192.168.1.4"
[DEBUG] [DEBUG] 🚀 准备调用createAccount()...
[DEBUG] [DEBUG] 🔹 createAccount() 开始
[DEBUG] [DEBUG] 🔹 配置有效，URI: "sip:1001@192.168.1.4"
[DEBUG] [DEBUG] 🔹 创建配置副本...
[DEBUG] [DEBUG] ✅ 配置副本创建完成
[DEBUG] [DEBUG] 🔹 创建RisipAccount对象...
[DEBUG] [DEBUG] ✅ RisipAccount对象创建完成
[DEBUG] [DEBUG] 🔹 先设置配置（避免信号处理中访问未初始化的配置）...
[DEBUG] [DEBUG] 🔹 setConfiguration() - 开始设置配置
[DEBUG] [DEBUG]    旧配置指针: 0x55abb55e70
[DEBUG] [DEBUG]    新配置指针: 0x55abb3fbd0
[DEBUG] [DEBUG] 🔸 复制新配置内容到现有配置对象...
[DEBUG] [DEBUG] ✅ 配置内容已复制（原config对象由调用者管理）
[DEBUG] [DEBUG] 🔸 设置账户状态为NotCreated...
[DEBUG] [DEBUG] ✅ 状态已设置
[DEBUG] [DEBUG] 🔸 发出configurationChanged信号...
[DEBUG] [DEBUG] ✅ setConfiguration() 完成
[DEBUG] [DEBUG] ✅ setConfiguration()完成
[DEBUG] [DEBUG] 🗑️ 标记临时config副本稍后删除...
[DEBUG] [DEBUG] ✅ 临时config副本已标记为稍后删除
[DEBUG] [DEBUG] 🔹 获取sipEndpoint指针: 0x55a93fdfb8
[DEBUG] [DEBUG] ✅ sipEndpoint()指针有效
[DEBUG] [DEBUG] 🔹 调用account->setSipEndPoint()...
[DEBUG] [DEBUG] ✅ setSipEndPoint()完成
[DEBUG] [DEBUG] 🔹 添加到账户模型...
[DEBUG] [DEBUG] RisipAccountListModel::addSipAccount() - Before add, count: 1
[DEBUG] [DEBUG]   Adding account URI: "sip:1001@192.168.1.4"
[DEBUG] [DEBUG]   Server address: "192.168.1.4"
[DEBUG] [DEBUG] RisipAccountListModel::addSipAccount() - After add, count: 2
[DEBUG] [DEBUG]   Total accounts in hash: 2
[DEBUG] [DEBUG] ✅ addSipAccount()完成
[DEBUG] [DEBUG] 🔹 为账户创建联系人模型...
[DEBUG] [DEBUG] ✅ createModelsForAccount()完成
[DEBUG] [DEBUG] 🔹 为账户创建通话模型...
[DEBUG] ✅ [DATABASE] Loaded 4 records from database
[DEBUG] ✅ [HISTORY MODEL] Loaded 4 records from database
[DEBUG] [DEBUG] ✅ createModelsForAccount()完成
[DEBUG] [DEBUG] ✅ createAccount()完成，返回账户对象
[DEBUG] [DEBUG] ✅ createAccount()返回成功
[DEBUG] [DEBUG] ✅ 账户 1 加载完成
[DEBUG] [DEBUG] 🗑️ 使用deleteLater()标记configuration删除
[DEBUG] [DEBUG] 🎯 准备设置默认账户: "sip:1001@192.168.1.4"
[WARNING] QObject::disconnect: Unexpected nullptr parameter
[DEBUG] SIP DEFAULT ACCOUNT  "sip:1001@192.168.1.4"
[DEBUG] [DEBUG] ✅ readSettings()完成
[DEBUG] Saved accounts loaded successfully
[DEBUG] [DEBUG] accountsModel() returning model with 2 accounts
[DEBUG] [DEBUG] accountsModel() returning model with 2 accounts
[DEBUG] Emitted accountsModelChanged() signal to QML
[DEBUG] Auto-registering default account: "sip:1001@192.168.1.4"
[DEBUG] Set default account as active in RisipCallManager
[DEBUG] Auto-login enabled, starting registration...
[DEBUG] [LOGIN] 🔹 login() called
[DEBUG] [LOGIN] ✅ sipEndpoint valid
[DEBUG] [LOGIN] Current status: 1
[DEBUG] [LOGIN] 🔸 Account needs to be created/reconfigured
[DEBUG] [LOGIN] 🔸 Creating transport network...
07:25:56.355             tcptp:5060  SIP TCP listener ready for incoming connections at 192.168.1.8:5060
[DEBUG] [LOGIN] ✅ Transport network created
[DEBUG] [LOGIN] ✅ Transport ID set in configuration
[DEBUG] [LOGIN] 🔸 Creating PjsipAccount object...
[DEBUG] [LOGIN] ✅ PjsipAccount object created
[DEBUG] [LOGIN] 🔸 Setting Risip interface...
[DEBUG] [LOGIN] ✅ Risip interface set
[DEBUG] [LOGIN] 🔸 Preparing AccountConfig...
[DEBUG] [LOGIN]    configuration pointer: 0x55abb55e70
[DEBUG] [LOGIN] 🔸 Getting AccountConfig reference...
[DEBUG] [CONFIG] 🔹 pjsipAccountConfig() called
[DEBUG] [CONFIG] 🔸 Clearing authCreds...
[DEBUG] [CONFIG] ✅ authCreds cleared
[DEBUG] [CONFIG] 🔸 Setting URI...
[DEBUG] [CONFIG] 🔸 Setting idUri and registrarUri...
[DEBUG] [CONFIG]    URI: "sip:1001@192.168.1.4"
[DEBUG] [CONFIG]    Server: "192.168.1.4"
[DEBUG] [CONFIG] ✅ URI fields set
[DEBUG] [CONFIG] 🔸 Disabling account Keep-alive timer (PJSIP bug #2079 workaround)...
[DEBUG] [CONFIG]    Bug: Race condition in keep_alive_timer_cb() causes crash after 200 OK
[DEBUG] [CONFIG]    Fix: udpKaIntervalSec = 0 (prevents timer from starting)
[DEBUG] [CONFIG] ✅ Account Keep-alive disabled (udpKaIntervalSec=0, ICE=false, TURN=false, STUN=disabled)
[DEBUG] [CONFIG]    Expected: NO 'Keep-alive timer started' message after registration
[DEBUG] [CONFIG] 🔸 Configuring additional RTCP-FB capabilities for PortSIP compatibility...
[DEBUG] [CONFIG] ✅ RTCP-FB configured with 2 essential capabilities (optimized for MTU):
[DEBUG] [CONFIG]    (nack pli - already added by PJSIP)
[DEBUG] [CONFIG]    1. nack (Generic NACK) - RFC standard
[DEBUG] [CONFIG]    2. ccm fir (Full Intra Request) - RFC standard
[DEBUG] [CONFIG]    ❌ Removed: goog-remb (Google extension, ~55 bytes saved)
[DEBUG] [CONFIG]    ❌ Removed: transport-cc (Google extension, ~55 bytes saved)
[DEBUG] [CONFIG]    Expected INVITE size reduction: ~110 bytes (1566 → ~1456 < MTU 1500)
[DEBUG] [CONFIG] 🔸 Disabling Lock Codec to prevent post-call re-INVITE...
[DEBUG] [CONFIG] ✅ Lock Codec disabled (lockCodecEnabled=false)
[DEBUG] [CONFIG]    Expected: NO automatic re-INVITE after call setup
[DEBUG] [CONFIG]    Expected: Video remains a=sendrecv (not a=inactive)
[DEBUG] [LOGIN] ✅ Got AccountConfig reference (no copy)
[DEBUG] [LOGIN] 🔸 Calling pjsipAccount->create() with reference...
07:25:56.356            pjsua_acc.c  Adding account: id=sip:1001@192.168.1.4
07:25:56.356            pjsua_acc.c  .Account sip:1001@192.168.1.4 added with id 0
07:25:56.356            pjsua_acc.c  .Acc 0: setting registration..
07:25:56.356            pjsua_acc.c  ..Contact for acc 0 updated: <sip:1001@192.168.1.8:5060;ob>
07:25:56.356       tcpc0x55abb63b58  ...TCP client transport created
07:25:56.356       tcpc0x55abb63b58  ...TCP transport 192.168.1.8:38859 is connecting to 192.168.1.4:5060...
07:25:56.356           pjsua_core.c  ...TX 495 bytes Request msg REGISTER/cseq=12172 (tdta0x55abb61c20) to TCP 192.168.1.4:5060:
REGISTER sip:192.168.1.4 SIP/2.0
Via: SIP/2.0/TCP 192.168.1.8:5060;rport;branch=z9hG4bKPj5949e991-4913-4b7e-850e-bf1e55efb5ad;alias
Max-Forwards: 70
From: <sip:1001@192.168.1.4>;tag=2c69dffa-1bbd-429d-9499-4e76cb2486bc
To: <sip:1001@192.168.1.4>
Call-ID: c733621a-6013-428b-a02a-98d14ba1e3fc
CSeq: 12172 REGISTER
Contact: <sip:1001@192.168.1.8:5060;ob>
Expires: 300
Allow: PRACK, INVITE, ACK, BYE, CANCEL, UPDATE, INFO, SUBSCRIBE, NOTIFY, REFER, MESSAGE, OPTIONS
Content-Length:  0


--end msg--
[DEBUG] [PJSIP] 🔹 onRegStarted() called (thread-safe version)
[DEBUG] [PJSIP]    renew: true
[DEBUG] [PJSIP] 🔸 Queuing status change to risip::RisipAccount::Registering for main thread...
[DEBUG] [PJSIP] ✅ onRegStarted() completed (status change queued)
07:25:56.356            pjsua_acc.c  ..Acc 0: Registration sent
[DEBUG] [LOGIN] ✅ pjsipAccount->create() completed successfully
[DEBUG] [LOGIN] 🔸 Setting status to Registering...
[DEBUG] Account status changed: 2 ( "Registering." )
[DEBUG] [LOGIN] ⏭️  Skipping setPresence() - will be called automatically on SignedIn
[DEBUG] [LOGIN] ✅ login() completed successfully
[DEBUG]
[DEBUG] ════════════════════════════════════════════════════════════
[DEBUG] 📱 [FIX 100.246] Enumerating devices after PJSIP initialization
[DEBUG] ════════════════════════════════════════════════════════════
[DEBUG] ════════════════════════════════════════════════════════════
[DEBUG] 🔥🔥🔥 [ENTRY] getAudioInputDevices() called!
[DEBUG]    [TIMING] Called at: "2026-01-18 07:25:56.356"
[DEBUG]    [STATE] d->initialized = true
[DEBUG]    [STATE] d->risipInstance = EXISTS
[DEBUG] ════════════════════════════════════════════════════════════
[DEBUG]    [API] Calling pjsua_enum_aud_devs() with max count: 64
[DEBUG]    [API] pjsua_enum_aud_devs() returned, status: 0 count: 11
[DEBUG] 📢 [Device Enum] Total audio devices: 11
[DEBUG]    [ALL] Device 0 : "hw:CARD=rockchiphdmi0,DEV=0" | In: 0 Out: 0
[DEBUG]       ⏭️ SKIPPED (no input channels)
[DEBUG]    [ALL] Device 1 : "plughw:CARD=rockchiphdmi0,DEV=0" | In: 0 Out: 0
[DEBUG]       ⏭️ SKIPPED (no input channels)
[DEBUG]    [ALL] Device 2 : "default:CARD=rockchiphdmi0" | In: 0 Out: 0
[DEBUG]       ⏭️ SKIPPED (no input channels)
[DEBUG]    [ALL] Device 3 : "sysdefault:CARD=rockchiphdmi0" | In: 0 Out: 0
[DEBUG]       ⏭️ SKIPPED (no input channels)
[DEBUG]    [ALL] Device 4 : "dmix:CARD=rockchiphdmi0,DEV=0" | In: 0 Out: 0
[DEBUG]       ⏭️ SKIPPED (no input channels)
[DEBUG]    [ALL] Device 5 : "hw:CARD=camera,DEV=0" | In: 1 Out: 0
[DEBUG]       ⏭️ SKIPPED (duplicate alias)
[DEBUG]    [ALL] Device 6 : "plughw:CARD=camera,DEV=0" | In: 1 Out: 0
[DEBUG]       ✅ ADDED: "camera (麦克风)" ( "camera" )
[DEBUG]          [INDEX MAPPING] User index: 0 → PJSIP index: 6
[DEBUG]    [ALL] Device 7 : "default:CARD=camera" | In: 1 Out: 0
[DEBUG]       ⏭️ SKIPPED (card already added): "camera"
[DEBUG]    [ALL] Device 8 : "sysdefault:CARD=camera" | In: 1 Out: 0
[DEBUG]       ⏭️ SKIPPED (duplicate alias)
[DEBUG]    [ALL] Device 9 : "front:CARD=camera,DEV=0" | In: 1 Out: 0
[DEBUG]       ⏭️ SKIPPED (duplicate alias)
[DEBUG]    [ALL] Device 10 : "dsnoop:CARD=camera,DEV=0" | In: 1 Out: 0
[DEBUG]       ⏭️ SKIPPED (virtual device): "camera"
[DEBUG] 📢 [Device Enum] Total INPUT devices added: 1
[DEBUG] ✅ Audio input devices enumerated: 1
[DEBUG] 📱 [QML Mic] Received audioInputDevicesChanged signal
[DEBUG]    New device count: 1
[DEBUG] ════════════════════════════════════════════════════════════
[DEBUG] 🔥🔥🔥 [ENTRY] getAudioOutputDevices() called!
[DEBUG]    [TIMING] Called at: "2026-01-18 07:25:56.358"
[DEBUG]    [STATE] d->initialized = true
[DEBUG]    [STATE] d->risipInstance = EXISTS
[DEBUG] ════════════════════════════════════════════════════════════
[DEBUG]    [API] Calling pjsua_enum_aud_devs() with max count: 64
[DEBUG]    [API] pjsua_enum_aud_devs() returned, status: 0 count: 11
[DEBUG] 🔊 [Device Enum] Total audio devices: 11
[DEBUG]    [ALL] Device 0 : "hw:CARD=rockchiphdmi0,DEV=0" | In: 0 Out: 0
[DEBUG]       [HDMI DEEP DEBUG] ═══════════════════════════════════
[DEBUG]       [HDMI] Device name: "hw:CARD=rockchiphdmi0,DEV=0"
[DEBUG]       [HDMI] Driver: "ALSA"
[DEBUG]       [HDMI] input_count: 0
[DEBUG]       [HDMI] output_count: 0 ← 为什么是 0？
[DEBUG]       [HDMI] default_samples_per_sec: 8000
[DEBUG]       [HDMI] caps (能力标志): 30
[DEBUG]       [HDMI] routes (路由数量): 0
[DEBUG]       [HDMI] ext_fmt_cnt (扩展格式数量): 0
[DEBUG]       [HDMI DEEP DEBUG] ═══════════════════════════════════
[DEBUG]       [HDMI ANALYSIS] 可能的原因:
[DEBUG]          1. HDMI 未连接显示器 → 音频通道未激活
[DEBUG]          2. ALSA 驱动 bug → 未正确报告音频能力
[DEBUG]          3. PJSIP ALSA 适配问题 → 枚举逻辑有问题
[DEBUG]          4. 设备需要先打开 → 才能获取正确的通道数
[DEBUG]          5. 权限问题 → 需要特定权限查询设备能力
[DEBUG]       ⏭️ SKIPPED (no output channels)
[DEBUG]    [ALL] Device 1 : "plughw:CARD=rockchiphdmi0,DEV=0" | In: 0 Out: 0
[DEBUG]       [HDMI DEEP DEBUG] ═══════════════════════════════════
[DEBUG]       [HDMI] Device name: "plughw:CARD=rockchiphdmi0,DEV=0"
[DEBUG]       [HDMI] Driver: "ALSA"
[DEBUG]       [HDMI] input_count: 0
[DEBUG]       [HDMI] output_count: 0 ← 为什么是 0？
[DEBUG]       [HDMI] default_samples_per_sec: 8000
[DEBUG]       [HDMI] caps (能力标志): 30
[DEBUG]       [HDMI] routes (路由数量): 0
[DEBUG]       [HDMI] ext_fmt_cnt (扩展格式数量): 0
[DEBUG]       [HDMI DEEP DEBUG] ═══════════════════════════════════
[DEBUG]       [HDMI ANALYSIS] 可能的原因:
[DEBUG]          1. HDMI 未连接显示器 → 音频通道未激活
[DEBUG]          2. ALSA 驱动 bug → 未正确报告音频能力
[DEBUG]          3. PJSIP ALSA 适配问题 → 枚举逻辑有问题
[DEBUG]          4. 设备需要先打开 → 才能获取正确的通道数
[DEBUG]          5. 权限问题 → 需要特定权限查询设备能力
[DEBUG]       ⏭️ SKIPPED (no output channels)
[DEBUG]    [ALL] Device 2 : "default:CARD=rockchiphdmi0" | In: 0 Out: 0
[DEBUG]       [HDMI DEEP DEBUG] ═══════════════════════════════════
[DEBUG]       [HDMI] Device name: "default:CARD=rockchiphdmi0"
[DEBUG]       [HDMI] Driver: "ALSA"
[DEBUG]       [HDMI] input_count: 0
[DEBUG]       [HDMI] output_count: 0 ← 为什么是 0？
[DEBUG]       [HDMI] default_samples_per_sec: 8000
[DEBUG]       [HDMI] caps (能力标志): 30
[DEBUG]       [HDMI] routes (路由数量): 0
[DEBUG]       [HDMI] ext_fmt_cnt (扩展格式数量): 0
[DEBUG]       [HDMI DEEP DEBUG] ═══════════════════════════════════
[DEBUG]       [HDMI ANALYSIS] 可能的原因:
[DEBUG]          1. HDMI 未连接显示器 → 音频通道未激活
[DEBUG]          2. ALSA 驱动 bug → 未正确报告音频能力
[DEBUG]          3. PJSIP ALSA 适配问题 → 枚举逻辑有问题
[DEBUG]          4. 设备需要先打开 → 才能获取正确的通道数
[DEBUG]          5. 权限问题 → 需要特定权限查询设备能力
[DEBUG]       ⏭️ SKIPPED (no output channels)
[DEBUG]    [ALL] Device 3 : "sysdefault:CARD=rockchiphdmi0" | In: 0 Out: 0
[DEBUG]       [HDMI DEEP DEBUG] ═══════════════════════════════════
[DEBUG]       [HDMI] Device name: "sysdefault:CARD=rockchiphdmi0"
[DEBUG]       [HDMI] Driver: "ALSA"
[DEBUG]       [HDMI] input_count: 0
[DEBUG]       [HDMI] output_count: 0 ← 为什么是 0？
[DEBUG]       [HDMI] default_samples_per_sec: 8000
[DEBUG]       [HDMI] caps (能力标志): 30
[DEBUG]       [HDMI] routes (路由数量): 0
[DEBUG]       [HDMI] ext_fmt_cnt (扩展格式数量): 0
[DEBUG]       [HDMI DEEP DEBUG] ═══════════════════════════════════
[DEBUG]       [HDMI ANALYSIS] 可能的原因:
[DEBUG]          1. HDMI 未连接显示器 → 音频通道未激活
[DEBUG]          2. ALSA 驱动 bug → 未正确报告音频能力
[DEBUG]          3. PJSIP ALSA 适配问题 → 枚举逻辑有问题
[DEBUG]          4. 设备需要先打开 → 才能获取正确的通道数
[DEBUG]          5. 权限问题 → 需要特定权限查询设备能力
[DEBUG]       ⏭️ SKIPPED (no output channels)
[DEBUG]    [ALL] Device 4 : "dmix:CARD=rockchiphdmi0,DEV=0" | In: 0 Out: 0
[DEBUG]       [HDMI DEEP DEBUG] ═══════════════════════════════════
[DEBUG]       [HDMI] Device name: "dmix:CARD=rockchiphdmi0,DEV=0"
[DEBUG]       [HDMI] Driver: "ALSA"
[DEBUG]       [HDMI] input_count: 0
[DEBUG]       [HDMI] output_count: 0 ← 为什么是 0？
[DEBUG]       [HDMI] default_samples_per_sec: 8000
[DEBUG]       [HDMI] caps (能力标志): 30
[DEBUG]       [HDMI] routes (路由数量): 0
[DEBUG]       [HDMI] ext_fmt_cnt (扩展格式数量): 0
[DEBUG]       [HDMI DEEP DEBUG] ═══════════════════════════════════
[DEBUG]       [HDMI ANALYSIS] 可能的原因:
[DEBUG]          1. HDMI 未连接显示器 → 音频通道未激活
[DEBUG]          2. ALSA 驱动 bug → 未正确报告音频能力
[DEBUG]          3. PJSIP ALSA 适配问题 → 枚举逻辑有问题
[DEBUG]          4. 设备需要先打开 → 才能获取正确的通道数
[DEBUG]          5. 权限问题 → 需要特定权限查询设备能力
[DEBUG]       ⏭️ SKIPPED (no output channels)
[DEBUG]    [ALL] Device 5 : "hw:CARD=camera,DEV=0" | In: 1 Out: 0
[DEBUG]       ⏭️ SKIPPED (no output channels)
[DEBUG]    [ALL] Device 6 : "plughw:CARD=camera,DEV=0" | In: 1 Out: 0
[DEBUG]       ⏭️ SKIPPED (no output channels)
[DEBUG]    [ALL] Device 7 : "default:CARD=camera" | In: 1 Out: 0
[DEBUG]       ⏭️ SKIPPED (no output channels)
[DEBUG]    [ALL] Device 8 : "sysdefault:CARD=camera" | In: 1 Out: 0
[DEBUG]       ⏭️ SKIPPED (no output channels)
[DEBUG]    [ALL] Device 9 : "front:CARD=camera,DEV=0" | In: 1 Out: 0
[DEBUG]       ⏭️ SKIPPED (no output channels)
[DEBUG]    [ALL] Device 10 : "dsnoop:CARD=camera,DEV=0" | In: 1 Out: 0
[DEBUG]       ⏭️ SKIPPED (no output channels)
[DEBUG] 🔊 [Device Enum] Total OUTPUT devices added: 0
[DEBUG] ⚠️ [Device Enum] No output devices found, added placeholder
[DEBUG] ✅ Audio output devices enumerated: 1
[DEBUG] 📱 [QML Speaker] Received audioOutputDevicesChanged signal
[DEBUG]    New device count: 1
[DEBUG] ════════════════════════════════════════════════════════════
[DEBUG] 🔥🔥🔥 [ENTRY] getVideoDevices() called!
[DEBUG]    [TIMING] Called at: "2026-01-18 07:25:56.359"
[DEBUG]    [STATE] d->initialized = true
[DEBUG]    [STATE] d->risipInstance = EXISTS
[DEBUG] ════════════════════════════════════════════════════════════
[DEBUG] 📹 [Device Enum] Total video devices: 4
[DEBUG]    Video Device 0 : "USB camera: USB camera"
[DEBUG] 📹 [Device Enum] Total video devices found: 1
[DEBUG] ✅ Video devices enumerated: 1
[DEBUG] 📱 [QML Camera] Received videoDevicesChanged signal
[DEBUG]    New device count: 1
[DEBUG] ════════════════════════════════════════════════════════════
[DEBUG] 📱 [FIX 100.246] All devices enumerated, signals emitted to QML
[DEBUG] ════════════════════════════════════════════════════════════
[DEBUG]
07:25:56.360       tcpc0x55abb63b58 !TCP transport 192.168.1.8:38859 is connected to 192.168.1.4:5060
07:25:56.362             alsa_dev.c !✅ [FIX 100.247 DEBUG] Capture stats: total=1, success=1, errors=0, frames_read=320
07:25:56.362             alsa_dev.c  🎤 [AUDIO DATA] Silent: NO ✅, Non-zero samples: 640/640 (100.0%), Max amplitude: 32768
07:25:56.362           pjsua_core.c  .RX 574 bytes Response msg 401/REGISTER/cseq=12172 (rdata0x55abb63e48) from TCP 192.168.1.4:5060:
SIP/2.0 401 Unauthorized
Via: SIP/2.0/TCP 192.168.1.8:5060;branch=z9hG4bKPj5949e991-4913-4b7e-850e-bf1e55efb5ad;received=192.168.1.8;rport=38859
From: <sip:1001@192.168.1.4>;tag=2c69dffa-1bbd-429d-9499-4e76cb2486bc
To: <sip:1001@192.168.1.4>;tag=79d883fe88eb9021
CSeq: 12172 REGISTER
Call-ID: c733621a-6013-428b-a02a-98d14ba1e3fc
Allow: ACK, BYE, CANCEL, INFO, INVITE, MESSAGE, NOTIFY, OPTIONS, PRACK, REFER, REGISTER, SUBSCRIBE
WWW-Authenticate: Digest realm="myvoipapp.com", nonce="69318C2DAFCF4A208C3EC12FC949C016", algorithm=MD5, stale=true
Content-Length: 0


--end msg--
07:25:56.364                capdbuf !Underflow, buf_cnt=0, will generate 1 frame
07:25:56.367           pjsua_core.c  ....TX 683 bytes Request msg REGISTER/cseq=12173 (tdta0x55abb61c20) to TCP 192.168.1.4:5060:
REGISTER sip:192.168.1.4 SIP/2.0
Via: SIP/2.0/TCP 192.168.1.8:38859;rport;branch=z9hG4bKPj03b5541e-c764-43da-8da7-e91d84405585;alias
Max-Forwards: 70
From: <sip:1001@192.168.1.4>;tag=2c69dffa-1bbd-429d-9499-4e76cb2486bc
To: <sip:1001@192.168.1.4>
Call-ID: c733621a-6013-428b-a02a-98d14ba1e3fc
CSeq: 12173 REGISTER
Contact: <sip:1001@192.168.1.8:5060;ob>
Expires: 300
Allow: PRACK, INVITE, ACK, BYE, CANCEL, UPDATE, INFO, SUBSCRIBE, NOTIFY, REFER, MESSAGE, OPTIONS
Authorization: Digest username="1001", realm="myvoipapp.com", nonce="69318C2DAFCF4A208C3EC12FC949C016", uri="sip:192.168.1.4", response="8a5de56df3c827ac369fbba34dee4701", algorithm=MD5
Content-Length:  0


--end msg--
07:25:56.370           pjsua_core.c  .RX 560 bytes Response msg 200/REGISTER/cseq=12173 (rdata0x55abb63e48) from TCP 192.168.1.4:5060:
SIP/2.0 200 OK
Via: SIP/2.0/TCP 192.168.1.8:38859;branch=z9hG4bKPj03b5541e-c764-43da-8da7-e91d84405585;received=192.168.1.8;rport=38859
From: <sip:1001@192.168.1.4>;tag=2c69dffa-1bbd-429d-9499-4e76cb2486bc
To: <sip:1001@192.168.1.4>;tag=3d14c1b9df280471
CSeq: 12173 REGISTER
Call-ID: c733621a-6013-428b-a02a-98d14ba1e3fc
Allow: ACK, BYE, CANCEL, INFO, INVITE, MESSAGE, NOTIFY, OPTIONS, PRACK, REFER, REGISTER, SUBSCRIBE
Contact: "1001"<sip:1001@192.168.1.8;transport=tcp;ob>
Server: SIP server (5 clients, 20251206)
Expires: 120
Content-Length: 0


--end msg--
07:25:56.370            pjsua_acc.c  ....SIP outbound status for acc 0 is not active
07:25:56.370            pjsua_acc.c  ....Service-Route updated for acc 0 with 0 URI(s)
07:25:56.370            pjsua_acc.c  ....sip:1001@192.168.1.4: registration success, status=200 (OK), will re-register in 120 seconds
[DEBUG] [PJSIP] 🔹 onRegState() called (thread-safe version v4 - compile-time Keep-alive disable)
[DEBUG] [PJSIP]    Response code: 200
[DEBUG] [PJSIP]    m_risipAccount pointer: 0x55abb55e50
[DEBUG] [PJSIP] 🔸 Determining status from response code (no AccountInfo)...
[DEBUG] [PJSIP] ✅ Registration successful (200 OK)
[DEBUG] [PJSIP] 🔸 Queuing ALL updates to main thread (including response code)...
[DEBUG] [PJSIP] ✅ onRegState() completed (all updates queued)
[DEBUG] [PJSIP] 🔚 onRegState() returning immediately (no blocking, no AccountInfo)...
[DEBUG] [PJSIP] 🔚 About to return from onRegState()...
[DEBUG] [PJSIP-MainThread] 🔸 onRegStarted: Setting status to risip::RisipAccount::Registering
[DEBUG] [PJSIP-MainThread] ✅ onRegStarted: Status set successfully
[DEBUG] [PJSIP-MainThread] 🔸 Setting last response code: 200
[DEBUG] [PJSIP-MainThread] 🔸 Setting status to risip::RisipAccount::SignedIn
[DEBUG] Account status changed: 4 ( "Signed in." )
[DEBUG] Account registered successfully
[DEBUG] [PJSIP-MainThread] ✅ All updates completed
[DEBUG] ✅ Configuring video device AFTER login initiation: "sip:1001@192.168.1.4"
[DEBUG] Configuring video device for account: "sip:1001@192.168.1.4"
[DEBUG] Checking account 0 URI: "sip:1001@192.168.1.4"
[DEBUG] Found account ID 0 for URI: "sip:1001@192.168.1.4"
[DEBUG] ✅ Using real capture device ID from VideoCallManager: 0
07:25:56.477            pjsua_acc.c !Modifying account 0
[DEBUG] ✅ Account 0 video device configured: vid_cap_dev= 0
07:25:56.639                capdbuf  Buffer size adjusted from 3840 to 3202 (eff_cnt=2560)
07:25:56.653                capdbuf  Buffer size adjusted from 3202 to 2608 (eff_cnt=2560)
07:25:56.697                capdbuf  Buffer size adjusted from 3248 to 2590 (eff_cnt=2560)
07:25:56.755                capdbuf  Buffer size adjusted from 3230 to 2788 (eff_cnt=2560)
07:25:56.799                capdbuf  Buffer size adjusted from 3428 to 2772 (eff_cnt=2560)
07:25:56.857                capdbuf  Buffer size adjusted from 3412 to 2728 (eff_cnt=2560)
07:25:56.915                capdbuf  Buffer size adjusted from 3368 to 2750 (eff_cnt=2560)
07:25:56.958                capdbuf  Buffer size adjusted from 3390 to 2750 (eff_cnt=2560)
07:25:57.016                capdbuf  Buffer size adjusted from 3390 to 2750 (eff_cnt=2560)
07:25:57.060                capdbuf  Buffer size adjusted from 3390 to 2750 (eff_cnt=2560)
[DEBUG] 📝 Refreshing call history model...
[DEBUG] Retrieved call history model for account: "sip:1001@192.168.1.4"
[DEBUG]    ✅ Model retrieved, rowCount: 4
07:25:57.118                capdbuf  Buffer size adjusted from 3390 to 2750 (eff_cnt=2560)
07:25:57.176                capdbuf  Buffer size adjusted from 3390 to 2750 (eff_cnt=2560)
07:25:57.234                capdbuf  Buffer size adjusted from 3390 to 2610 (eff_cnt=2560)
07:25:57.278                capdbuf  Buffer size adjusted from 3250 to 2716 (eff_cnt=2560)
07:25:57.336                capdbuf  Buffer size adjusted from 3356 to 2782 (eff_cnt=2560)
07:25:57.379                capdbuf  Buffer size adjusted from 3422 to 2750 (eff_cnt=2560)
07:25:57.437                capdbuf  Buffer size adjusted from 3390 to 2608 (eff_cnt=2560)
07:25:57.495                capdbuf  Buffer size adjusted from 3248 to 2662 (eff_cnt=2560)
07:25:57.539                capdbuf  Buffer size adjusted from 3302 to 2736 (eff_cnt=2560)
07:25:57.597                capdbuf  Buffer size adjusted from 3376 to 2606 (eff_cnt=2560)
07:25:57.640                capdbuf  Buffer size adjusted from 3246 to 2578 (eff_cnt=2560)
07:25:57.698                capdbuf  Buffer size adjusted from 3218 to 2662 (eff_cnt=2560)
07:25:57.756                capdbuf  Buffer size adjusted from 3302 to 2762 (eff_cnt=2560)
07:25:57.800                capdbuf  Buffer size adjusted from 3402 to 2710 (eff_cnt=2560)
07:25:57.814             alsa_dev.c !✅ [FIX 100.247 DEBUG] Capture stats: total=101, success=101, errors=0, frames_read=320
07:25:57.814             alsa_dev.c  🎤 [AUDIO DATA] Silent: NO ✅, Non-zero samples: 640/640 (100.0%), Max amplitude: 22533
07:25:57.858                capdbuf  Buffer size adjusted from 3350 to 2678 (eff_cnt=2560)
07:25:57.916                capdbuf  Buffer size adjusted from 3318 to 2654 (eff_cnt=2560)
[DEBUG] Dial pad button clicked: 1
[DEBUG] Number display text changed to: 1
[DEBUG] C++ currentNumberChanged signal received: 1
[DEBUG] Number updated to: 1
07:25:57.960                capdbuf  Buffer size adjusted from 3294 to 2618 (eff_cnt=2560)
07:25:58.018                capdbuf  Buffer size adjusted from 3258 to 2526 (eff_cnt=2560)
07:25:58.076                capdbuf  Buffer size adjusted from 3166 to 2790 (eff_cnt=2240)
07:25:58.119                capdbuf  Buffer size adjusted from 3430 to 2660 (eff_cnt=2240)
07:25:58.177                capdbuf  Buffer size adjusted from 3300 to 2538 (eff_cnt=2240)
07:25:58.235                capdbuf  Buffer size adjusted from 3178 to 2578 (eff_cnt=2240)
07:25:58.279                capdbuf  Buffer size adjusted from 3218 to 2772 (eff_cnt=2240)
07:25:58.337                capdbuf  Buffer size adjusted from 3412 to 2814 (eff_cnt=2240)
07:25:58.395                capdbuf  Buffer size adjusted from 3454 to 2812 (eff_cnt=2240)
07:25:58.439                capdbuf  Buffer size adjusted from 3452 to 2576 (eff_cnt=2240)
07:25:58.497                capdbuf  Buffer size adjusted from 3216 to 2798 (eff_cnt=2240)
07:25:58.555                capdbuf  Buffer size adjusted from 3438 to 2726 (eff_cnt=2240)
07:25:58.598                capdbuf  Buffer size adjusted from 3366 to 2664 (eff_cnt=2240)
07:25:58.656                capdbuf  Buffer size adjusted from 3304 to 2622 (eff_cnt=2240)
07:25:58.700                capdbuf  Buffer size adjusted from 3262 to 2624 (eff_cnt=2240)
07:25:58.758                capdbuf  Buffer size adjusted from 3264 to 2662 (eff_cnt=2240)
07:25:58.816                capdbuf  Buffer size adjusted from 3302 to 2730 (eff_cnt=2240)
07:25:58.874                capdbuf  Buffer size adjusted from 3370 to 2638 (eff_cnt=2240)
07:25:58.917                capdbuf  Buffer size adjusted from 3278 to 2772 (eff_cnt=2240)
07:25:58.976                capdbuf  Buffer size adjusted from 3412 to 2744 (eff_cnt=2240)
[DEBUG] Dial pad button clicked: 0
[DEBUG] Number display text changed to: 10
[DEBUG] C++ currentNumberChanged signal received: 10
[DEBUG] Number updated to: 10
07:25:59.019                capdbuf  Buffer size adjusted from 3384 to 2562 (eff_cnt=2240)
07:25:59.077                capdbuf  Buffer size adjusted from 3202 to 2604 (eff_cnt=2240)
07:25:59.135                capdbuf  Buffer size adjusted from 3244 to 2696 (eff_cnt=2240)
07:25:59.179                capdbuf  Buffer size adjusted from 3336 to 2696 (eff_cnt=2240)
[DEBUG] Dial pad button clicked: 0
[DEBUG] Number display text changed to: 100
[DEBUG] C++ currentNumberChanged signal received: 100
[DEBUG] Number updated to: 100
07:25:59.237                capdbuf  Buffer size adjusted from 3336 to 2814 (eff_cnt=2240)
07:25:59.265             alsa_dev.c !✅ [FIX 100.247 DEBUG] Capture stats: total=201, success=201, errors=0, frames_read=320
07:25:59.265             alsa_dev.c  🎤 [AUDIO DATA] Silent: NO ✅, Non-zero samples: 640/640 (100.0%), Max amplitude: 16456
07:25:59.295                capdbuf  Buffer size adjusted from 3454 to 2564 (eff_cnt=2240)
07:25:59.338                capdbuf  Buffer size adjusted from 3204 to 2692 (eff_cnt=2240)
07:25:59.396                capdbuf  Buffer size adjusted from 3332 to 2792 (eff_cnt=2240)
07:25:59.440                capdbuf  Buffer size adjusted from 3432 to 2746 (eff_cnt=2240)
07:25:59.498                capdbuf  Buffer size adjusted from 3386 to 2826 (eff_cnt=2240)
07:25:59.556                capdbuf  Buffer size adjusted from 3466 to 2842 (eff_cnt=2240)
07:25:59.600                capdbuf  Buffer size adjusted from 3482 to 2710 (eff_cnt=2240)
07:25:59.658                capdbuf  Buffer size adjusted from 3350 to 2588 (eff_cnt=2240)
07:25:59.716                capdbuf  Buffer size adjusted from 3228 to 2681 (eff_cnt=2240)
07:25:59.730                capdbuf  Buffer size adjusted from 2681 to 2092 (eff_cnt=2000)
07:25:59.759                capdbuf  Buffer size adjusted from 2732 to 2074 (eff_cnt=2000)
07:25:59.817                capdbuf  Buffer size adjusted from 2714 to 2120 (eff_cnt=2000)
07:25:59.875                capdbuf  Buffer size adjusted from 2760 to 1936 (eff_cnt=2000)
07:25:59.977                capdbuf  Buffer size adjusted from 3216 to 2624 (eff_cnt=2000)
07:26:00.035                capdbuf  Buffer size adjusted from 3264 to 2712 (eff_cnt=2000)
07:26:00.049                capdbuf  Buffer size adjusted from 2712 to 2078 (eff_cnt=2000)
07:26:00.078                capdbuf  Buffer size adjusted from 2718 to 2186 (eff_cnt=2000)
07:26:00.137                capdbuf  Buffer size adjusted from 2826 to 2128 (eff_cnt=2000)
07:26:00.195                capdbuf  Buffer size adjusted from 2768 to 2122 (eff_cnt=2000)
07:26:00.238                capdbuf  Buffer size adjusted from 2762 to 2172 (eff_cnt=2000)
07:26:00.296                capdbuf  Buffer size adjusted from 2812 to 1936 (eff_cnt=2000)
07:26:00.398                capdbuf  Buffer size adjusted from 3216 to 2778 (eff_cnt=2000)
07:26:00.412                capdbuf  Buffer size adjusted from 2778 to 2194 (eff_cnt=2000)
07:26:00.456                capdbuf  Buffer size adjusted from 2834 to 2114 (eff_cnt=2000)
07:26:00.499                capdbuf  Buffer size adjusted from 2754 to 2088 (eff_cnt=2000)
07:26:00.557                capdbuf  Buffer size adjusted from 2728 to 2100 (eff_cnt=2000)
07:26:00.615                capdbuf  Buffer size adjusted from 2740 to 1938 (eff_cnt=2000)
07:26:00.716             alsa_dev.c !✅ [FIX 100.247 DEBUG] Capture stats: total=301, success=301, errors=0, frames_read=320
07:26:00.716             alsa_dev.c  🎤 [AUDIO DATA] Silent: NO ✅, Non-zero samples: 640/640 (100.0%), Max amplitude: 12111
07:26:00.717                capdbuf  Buffer size adjusted from 3218 to 2711 (eff_cnt=2000)
07:26:00.732                capdbuf  Buffer size adjusted from 2711 to 2033 (eff_cnt=2000)
[DEBUG] Dial pad button clicked: 6
[DEBUG] Number display text changed to: 1006
[DEBUG] C++ currentNumberChanged signal received: 1006
[DEBUG] Number updated to: 1006
07:26:00.775                capdbuf  Buffer size adjusted from 2673 to 2147 (eff_cnt=2000)
07:26:00.819                capdbuf  Buffer size adjusted from 2787 to 1861 (eff_cnt=2000)
07:26:00.935                capdbuf  Buffer size adjusted from 3141 to 2625 (eff_cnt=2000)
07:26:00.978                capdbuf  Buffer size adjusted from 3265 to 2731 (eff_cnt=2000)
07:26:00.993                capdbuf  Buffer size adjusted from 2731 to 2185 (eff_cnt=2000)
07:26:01.036                capdbuf  Buffer size adjusted from 2825 to 2207 (eff_cnt=2000)
07:26:01.094                capdbuf  Buffer size adjusted from 2847 to 1935 (eff_cnt=2000)
07:26:01.196                capdbuf  Buffer size adjusted from 3215 to 2799 (eff_cnt=2000)
07:26:01.210                capdbuf  Buffer size adjusted from 2799 to 1895 (eff_cnt=2000)
07:26:01.298                capdbuf  Buffer size adjusted from 3175 to 2568 (eff_cnt=2000)
07:26:01.356                capdbuf  Buffer size adjusted from 3208 to 2543 (eff_cnt=2000)
07:26:01.414                capdbuf  Buffer size adjusted from 3183 to 2639 (eff_cnt=1820)
07:26:01.428                capdbuf  Buffer size adjusted from 2639 to 2095 (eff_cnt=1820)
07:26:01.457                capdbuf  Buffer size adjusted from 2735 to 2070 (eff_cnt=1820)
07:26:01.515                capdbuf  Buffer size adjusted from 2710 to 2120 (eff_cnt=1820)
07:26:01.559                capdbuf  Buffer size adjusted from 2760 to 1916 (eff_cnt=1820)
07:26:01.617                capdbuf  Buffer size adjusted from 2556 to 2034 (eff_cnt=1820)
07:26:01.675                capdbuf  Buffer size adjusted from 2674 to 1990 (eff_cnt=1820)
07:26:01.718                capdbuf  Buffer size adjusted from 2630 to 1970 (eff_cnt=1820)
07:26:01.776                capdbuf  Buffer size adjusted from 2610 to 2170 (eff_cnt=1820)
07:26:01.834                capdbuf  Buffer size adjusted from 2810 to 1914 (eff_cnt=1820)
07:26:01.878                capdbuf  Buffer size adjusted from 2554 to 1939 (eff_cnt=1820)
07:26:01.936                capdbuf  Buffer size adjusted from 2579 to 1963 (eff_cnt=1820)
07:26:01.994                capdbuf  Buffer size adjusted from 2603 to 2077 (eff_cnt=1820)
07:26:02.038                capdbuf  Buffer size adjusted from 2717 to 1951 (eff_cnt=1820)
07:26:02.096                capdbuf  Buffer size adjusted from 2591 to 2151 (eff_cnt=1820)
07:26:02.154                capdbuf  Buffer size adjusted from 2791 to 2108 (eff_cnt=1820)
07:26:02.167             alsa_dev.c !✅ [FIX 100.247 DEBUG] Capture stats: total=401, success=401, errors=0, frames_read=320
07:26:02.167             alsa_dev.c  🎤 [AUDIO DATA] Silent: NO ✅, Non-zero samples: 640/640 (100.0%), Max amplitude: 7624
07:26:02.197                capdbuf  Buffer size adjusted from 2748 to 2145 (eff_cnt=1820)
07:26:02.255                capdbuf  Buffer size adjusted from 2785 to 2034 (eff_cnt=1820)
[DEBUG] [DEBUG] Video call button clicked
[DEBUG] ✅ Making call to: "1006" (Video)
[DEBUG] 📇 Outgoing call - Number: "1006" Display: "1006"
[DEBUG] ✅ Refreshing video device configuration before call for: "sip:1001@192.168.1.4"
[DEBUG] Configuring video device for account: "sip:1001@192.168.1.4"
[DEBUG] Checking account 0 URI: "sip:1001@192.168.1.4"
[DEBUG] Found account ID 0 for URI: "sip:1001@192.168.1.4"
[DEBUG] ✅ Using real capture device ID from VideoCallManager: 0
07:26:02.263            pjsua_acc.c !Modifying account 0
[DEBUG] ✅ Account 0 video device configured: vid_cap_dev= 0
[DEBUG] ✅ Account configured with capture device: 0 (from VideoCallManager)
[DEBUG] 📞 Creating call using unified Risip API, video = true
[DEBUG] [PjsipCall-DEBUG] ⏰ Constructor START: callId = -1
[DEBUG] [PjsipCall-DEBUG] ⏰ About to call setRisipCall(NULL)...
[DEBUG] [PjsipCall-DEBUG] ✅ Constructor END: PjsipCall created successfully
[DEBUG] ✅ RisipCall: Enabling video with RKMPP hardware encoding
07:26:02.263           pjsua_call.c  Making call with acc #0 to <sip:1006@192.168.1.4>
07:26:02.263          pjsua_media.c  .Call 0: initializing media..
07:26:02.264          pjsua_media.c  ..RTP socket reachable at 192.168.1.8:4000
07:26:02.264          pjsua_media.c  ..RTCP socket reachable at 192.168.1.8:4001
07:26:02.264       srtp0x55a931b760  ..SRTP transport created
07:26:02.264          pjsua_media.c  ..RTP socket reachable at 192.168.1.8:4002
07:26:02.264          pjsua_media.c  ..RTCP socket reachable at 192.168.1.8:4003
07:26:02.264       srtp0x55abcc2a50  ..SRTP transport created
07:26:02.264          pjsua_media.c  ..Media index 0 selected for audio call 0
07:26:02.264        udp0x55abee9270  ..UDP media transport created
07:26:02.264        udp0x55abb577d0  ..UDP media transport created
07:26:02.264    ffmpeg_vid_codecs.c  .🔍 ffmpeg_default_attr() START: codec=VP8
07:26:02.264    ffmpeg_vid_codecs.c  .   Found codec desc=0x55729b5a70, enabled=1
07:26:02.264    ffmpeg_vid_codecs.c  .   About to init enc_fmt: fmt_id=0x30385056, 640x480
07:26:02.264    ffmpeg_vid_codecs.c  .   After init enc_fmt: detail_type=2 (VIDEO=2)
07:26:02.264    ffmpeg_vid_codecs.c  .   After init dec_fmt: detail_type=2 (VIDEO=2)
07:26:02.264    ffmpeg_vid_codecs.c  .✅ ffmpeg_default_attr() END: enc_fmt.detail_type=2, dec_fmt.detail_type=2
07:26:02.264    ffmpeg_vid_codecs.c  .🔍 ffmpeg_default_attr() START: codec=VP9
07:26:02.264    ffmpeg_vid_codecs.c  .   Found codec desc=0x55729b5db8, enabled=1
07:26:02.264    ffmpeg_vid_codecs.c  .   About to init enc_fmt: fmt_id=0x30395056, 640x480
07:26:02.264    ffmpeg_vid_codecs.c  .   After init enc_fmt: detail_type=2 (VIDEO=2)
07:26:02.264    ffmpeg_vid_codecs.c  .   After init dec_fmt: detail_type=2 (VIDEO=2)
07:26:02.264    ffmpeg_vid_codecs.c  .✅ ffmpeg_default_attr() END: enc_fmt.detail_type=2, dec_fmt.detail_type=2
07:26:02.264    ffmpeg_vid_codecs.c  .🔍 ffmpeg_default_attr() START: codec=H263-1998
07:26:02.264    ffmpeg_vid_codecs.c  .   Found codec desc=0x55729b6100, enabled=1
07:26:02.264    ffmpeg_vid_codecs.c  .   About to init enc_fmt: fmt_id=0x33363250, 352x288
07:26:02.264    ffmpeg_vid_codecs.c  .   After init enc_fmt: detail_type=2 (VIDEO=2)
07:26:02.264    ffmpeg_vid_codecs.c  .   After init dec_fmt: detail_type=2 (VIDEO=2)
07:26:02.264    ffmpeg_vid_codecs.c  .✅ ffmpeg_default_attr() END: enc_fmt.detail_type=2, dec_fmt.detail_type=2
07:26:02.264           pjsua_core.c  ....TX 1572 bytes Request msg INVITE/cseq=28371 (tdta0x55abc8dd00) to TCP 192.168.1.4:5060:
INVITE sip:1006@192.168.1.4 SIP/2.0
Via: SIP/2.0/TCP 192.168.1.8:38859;rport;branch=z9hG4bKPj32af9348-c9bb-4060-9d9f-4d8cba464daf;alias
Max-Forwards: 70
From: sip:1001@192.168.1.4;tag=5a61ba17-b1b3-4cc3-96e1-46dbffbcf7f3
To: <sip:1006@192.168.1.4>
Contact: <sip:1001@192.168.1.8:5060;ob>
Call-ID: 4c51ed3d-6cd6-4b3c-b9d2-97d1a2e66dc0
CSeq: 28371 INVITE
Allow: PRACK, INVITE, ACK, BYE, CANCEL, UPDATE, INFO, SUBSCRIBE, NOTIFY, REFER, MESSAGE, OPTIONS
Supported: replaces, 100rel, timer, siprec, norefersub
Session-Expires: 22000
Min-SE: 1200
Content-Type: application/sdp
Content-Length:   963

v=0
o=- 3977709962 3977709962 IN IP4 192.168.1.8
s=pjmedia
b=AS:1377
t=0 0
a=X-nat:0
m=audio 4000 RTP/AVP 8 0 96 120 121
c=IN IP4 192.168.1.8
b=TIAS:96000
a=rtcp:4001 IN IP4 192.168.1.8
a=sendrecv
a=rtpmap:8 PCMA/8000
a=rtpmap:0 PCMU/8000
a=rtpmap:96 opus/48000/2
a=fmtp:96 useinbandfec=1
a=rtpmap:120 telephone-event/8000
a=fmtp:120 0-16
a=rtpmap:121 telephone-event/48000
a=fmtp:121 0-16
a=ssrc:735993109 cname:2a45fb084dbaf1c5
a=rtcp-fb:* nack
a=rtcp-fb:* ccm fir
m=video 4002 RTP/AVP 100 104 107 96
c=IN IP4 192.168.1.8
b=TIAS:1200000
a=rtcp:4003 IN IP4 192.168.1.8
a=sendrecv
a=rtpmap:100 H264/90000
a=fmtp:100 profile-level-id=42e01e; packetization-mode=1
a=rtpmap:104 VP8/90000
a=fmtp:104 max-fr=30; max-fs=580
a=rtpmap:107 VP9/90000
a=fmtp:107 max-fr=30; max-fs=580
a=rtpmap:96 H263-1998/90000
a=fmtp:96 CIF=1;QCIF=1
a=ssrc:1112695372 cname:2a45fb084dbaf1c5
a=rtcp-fb:* nack pli
a=rtcp-fb:* nack
a=rtcp-fb:* ccm fir

--end msg--
[DEBUG] 🔔 [PJSIP C CALLBACK] call_state_callback_wrapper() called, call_id: 0
[DEBUG] 🔔 [PJSIP C CALLBACK] Getting call info...
[DEBUG] 🔔 [PJSIP C CALLBACK] pjsua_call_get_info() status: 0
[DEBUG] ✅ [UI UPDATE] Call 0 state: "呼叫 1006"
[DEBUG] 🔍 [QML] Video Accept Button visibility check:
[DEBUG]     callStatus: 呼叫 1006 → hasCallStatus: false
[DEBUG]     isIncomingVideoCall: false
[DEBUG]     → visible: false
[DEBUG] 📞 [RINGTONE] Call status changed: 呼叫 1006
[DEBUG] ✅ [CALL STATE] Call 0 state: CALLING
[DEBUG] 🔔 [PJSIP C CALLBACK] Calling original PJSUA2 on_call_state callback...
[DEBUG] 🔔 [PJSIP C CALLBACK] call_state_callback_wrapper() called, call_id: 0
[DEBUG] ⚠️ [PJSIP C CALLBACK] Recursive invocation detected, returning
[DEBUG] 🔔 [PJSIP C CALLBACK] Original callback returned
[DEBUG] 🔔 [PJSIP C CALLBACK] call_state_callback_wrapper() completed
[DEBUG] 📝 [HISTORY] Adding initial call record:
[DEBUG]    Contact: "1006"
[DEBUG]    Direction: 2 (1=Incoming, 2=Outgoing, -1=Unknown)
[DEBUG]    Duration: 0 ms (will update when call ends)
[DEBUG]    Timestamp: "2026-01-18 07:26:02"
07:26:02.267           pjsua_core.c  .RX 427 bytes Response msg 100/INVITE/cseq=28371 (rdata0x55abb63e48) from TCP 192.168.1.4:5060:
SIP/2.0 100 Trying
Via: SIP/2.0/TCP 192.168.1.8:38859;branch=z9hG4bKPj32af9348-c9bb-4060-9d9f-4d8cba464daf;received=192.168.1.8;rport=38859
From: sip:1001@192.168.1.4;tag=5a61ba17-b1b3-4cc3-96e1-46dbffbcf7f3
To: <sip:1006@192.168.1.4>
CSeq: 28371 INVITE
Call-ID: 4c51ed3d-6cd6-4b3c-b9d2-97d1a2e66dc0
Allow: ACK, BYE, CANCEL, INFO, INVITE, MESSAGE, NOTIFY, OPTIONS, PRACK, REFER, REGISTER, SUBSCRIBE
Content-Length: 0


--end msg--
[DEBUG] ✅ [HISTORY] Initial record added, total count: 5
[DEBUG] ✅ RisipCallManager: Call initiated via unified API, video = true
[DEBUG] 🔍 通话创建后 callDirection = 2 (0=Outgoing, 1=Incoming, 2=Unknown), video = true
[DEBUG] 🔍 [QML] Video Accept Button visibility check:
[DEBUG]     callStatus: 视频拨号: 1006 → hasCallStatus: false
[DEBUG]     isIncomingVideoCall: false
[DEBUG]     → visible: false
[DEBUG] 📞 [RINGTONE] Call status changed: 视频拨号: 1006
[DEBUG] ✅ Call initiated via unified Risip API, video = true
07:26:02.299                capdbuf  Buffer size adjusted from 2674 to 2154 (eff_cnt=1820)
07:26:02.317           pjsua_core.c  .RX 496 bytes Response msg 180/INVITE/cseq=28371 (rdata0x55abb63e48) from TCP 192.168.1.4:5060:
SIP/2.0 180 Ringing
Via: SIP/2.0/TCP 192.168.1.8:38859;branch=z9hG4bKPj32af9348-c9bb-4060-9d9f-4d8cba464daf;received=192.168.1.8;rport=38859
From: sip:1001@192.168.1.4;tag=5a61ba17-b1b3-4cc3-96e1-46dbffbcf7f3
To: <sip:1006@192.168.1.4>;tag=cec7704ea19952cd
CSeq: 28371 INVITE
Call-ID: 4c51ed3d-6cd6-4b3c-b9d2-97d1a2e66dc0
Allow: ACK, BYE, CANCEL, INFO, INVITE, MESSAGE, NOTIFY, OPTIONS, PRACK, REFER, REGISTER, SUBSCRIBE
Contact: <sip:1006@192.168.1.4;transport=tcp>
Content-Length: 0


--end msg--
[DEBUG] 🔔 [PJSIP C CALLBACK] call_state_callback_wrapper() called, call_id: 0
[DEBUG] 🔔 [PJSIP C CALLBACK] Getting call info...
[DEBUG] 🔔 [PJSIP C CALLBACK] pjsua_call_get_info() status: 0
[DEBUG] ✅ [UI UPDATE] Call 0 state: "1006 振铃中"
[DEBUG] ✅ [CALL STATE] Call 0 state: EARLY
[DEBUG] 🔔 [PJSIP C CALLBACK] Calling original PJSUA2 on_call_state callback...
[DEBUG] 🔔 [PJSIP C CALLBACK] call_state_callback_wrapper() called, call_id: 0
[DEBUG] ⚠️ [PJSIP C CALLBACK] Recursive invocation detected, returning
[DEBUG] 🔔 [PJSIP C CALLBACK] Original callback returned
[DEBUG] 🔔 [PJSIP C CALLBACK] call_state_callback_wrapper() completed
[DEBUG] 🔍 [QML] Video Accept Button visibility check:
[DEBUG]     callStatus: 1006 振铃中 → hasCallStatus: false
[DEBUG]     isIncomingVideoCall: false
[DEBUG]     → visible: false
[DEBUG] 📞 [RINGTONE] Call status changed: 1006 振铃中
07:26:02.357                capdbuf  Buffer size adjusted from 2794 to 2170 (eff_cnt=1820)
07:26:02.415                capdbuf  Buffer size adjusted from 2810 to 2058 (eff_cnt=1820)
07:26:02.459                capdbuf  Buffer size adjusted from 2698 to 1958 (eff_cnt=1820)
07:26:02.517                capdbuf  Buffer size adjusted from 2598 to 2128 (eff_cnt=1820)
07:26:02.575                capdbuf  Buffer size adjusted from 2768 to 2098 (eff_cnt=1820)
07:26:02.618                capdbuf  Buffer size adjusted from 2738 to 2006 (eff_cnt=1820)
07:26:02.676                capdbuf  Buffer size adjusted from 2646 to 1938 (eff_cnt=1820)
07:26:02.720                capdbuf  Buffer size adjusted from 2578 to 1992 (eff_cnt=1820)
07:26:02.778                capdbuf  Buffer size adjusted from 2632 to 1929 (eff_cnt=1820)
07:26:02.836                capdbuf  Buffer size adjusted from 2569 to 2023 (eff_cnt=1820)
07:26:02.894                capdbuf  Buffer size adjusted from 2663 to 2095 (eff_cnt=1820)
07:26:02.937                capdbuf  Buffer size adjusted from 2735 to 2003 (eff_cnt=1820)
07:26:02.995                capdbuf  Buffer size adjusted from 2643 to 1951 (eff_cnt=1820)
07:26:03.039                capdbuf  Buffer size adjusted from 2591 to 1921 (eff_cnt=1820)
07:26:03.097                capdbuf  Buffer size adjusted from 2561 to 1929 (eff_cnt=1686)
07:26:03.155                capdbuf  Buffer size adjusted from 2569 to 1991 (eff_cnt=1686)
07:26:03.199                capdbuf  Buffer size adjusted from 2631 to 1942 (eff_cnt=1686)
07:26:03.257                capdbuf  Buffer size adjusted from 2582 to 2076 (eff_cnt=1686)
07:26:03.315                capdbuf  Buffer size adjusted from 2716 to 2042 (eff_cnt=1686)
07:26:03.358                capdbuf  Buffer size adjusted from 2682 to 2115 (eff_cnt=1686)
07:26:03.416                capdbuf  Buffer size adjusted from 2755 to 1996 (eff_cnt=1686)
07:26:03.474                capdbuf  Buffer size adjusted from 2636 to 2178 (eff_cnt=1686)
07:26:03.518                capdbuf  Buffer size adjusted from 2818 to 2154 (eff_cnt=1686)
07:26:03.576                capdbuf  Buffer size adjusted from 2794 to 1980 (eff_cnt=1686)
07:26:03.619             alsa_dev.c !✅ [FIX 100.247 DEBUG] Capture stats: total=501, success=501, errors=0, frames_read=320
07:26:03.619             alsa_dev.c  🎤 [AUDIO DATA] Silent: NO ✅, Non-zero samples: 640/640 (100.0%), Max amplitude: 32767
07:26:03.634                capdbuf  Buffer size adjusted from 2620 to 2123 (eff_cnt=1686)
07:26:03.678                capdbuf  Buffer size adjusted from 2763 to 2047 (eff_cnt=1686)
07:26:03.736                capdbuf  Buffer size adjusted from 2687 to 2121 (eff_cnt=1686)
07:26:03.794                capdbuf  Buffer size adjusted from 2761 to 1985 (eff_cnt=1686)
07:26:03.837                capdbuf  Buffer size adjusted from 2625 to 2129 (eff_cnt=1686)
07:26:03.895                capdbuf  Buffer size adjusted from 2769 to 2141 (eff_cnt=1686)
07:26:03.939                capdbuf  Buffer size adjusted from 2781 to 1957 (eff_cnt=1686)
07:26:03.997                capdbuf  Buffer size adjusted from 2597 to 2061 (eff_cnt=1686)
07:26:04.055                capdbuf  Buffer size adjusted from 2701 to 1925 (eff_cnt=1686)
07:26:04.098                capdbuf  Buffer size adjusted from 2565 to 2117 (eff_cnt=1686)
07:26:04.157                capdbuf  Buffer size adjusted from 2757 to 2005 (eff_cnt=1686)
07:26:04.215                capdbuf  Buffer size adjusted from 2645 to 2017 (eff_cnt=1686)
07:26:04.258                capdbuf  Buffer size adjusted from 2657 to 2139 (eff_cnt=1686)
07:26:04.316                capdbuf  Buffer size adjusted from 2779 to 2121 (eff_cnt=1686)
07:26:04.360                capdbuf  Buffer size adjusted from 2761 to 1985 (eff_cnt=1686)
07:26:04.418                capdbuf  Buffer size adjusted from 2625 to 2175 (eff_cnt=1686)
07:26:04.476                capdbuf  Buffer size adjusted from 2815 to 1991 (eff_cnt=1686)
07:26:04.534                capdbuf  Buffer size adjusted from 2631 to 2093 (eff_cnt=1686)
07:26:04.577                capdbuf  Buffer size adjusted from 2733 to 1957 (eff_cnt=1686)
07:26:04.635                capdbuf  Buffer size adjusted from 2597 to 2151 (eff_cnt=1686)
07:26:04.679                capdbuf  Buffer size adjusted from 2791 to 2109 (eff_cnt=1686)
07:26:04.737                capdbuf  Buffer size adjusted from 2749 to 2087 (eff_cnt=1686)
07:26:04.795                capdbuf  Buffer size adjusted from 2727 to 2043 (eff_cnt=1584)
07:26:04.840                capdbuf  Buffer size adjusted from 2683 to 2088 (eff_cnt=1584)
07:26:04.897                capdbuf  Buffer size adjusted from 2728 to 2166 (eff_cnt=1584)
07:26:04.956                capdbuf  Buffer size adjusted from 2806 to 2050 (eff_cnt=1584)
07:26:04.998                capdbuf  Buffer size adjusted from 2690 to 1899 (eff_cnt=1584)
07:26:05.057                capdbuf  Buffer size adjusted from 2539 to 2129 (eff_cnt=1584)
07:26:05.070             alsa_dev.c !✅ [FIX 100.247 DEBUG] Capture stats: total=601, success=601, errors=0, frames_read=320
07:26:05.071             alsa_dev.c  🎤 [AUDIO DATA] Silent: NO ✅, Non-zero samples: 639/640 (99.8%), Max amplitude: 29406
07:26:05.114                capdbuf  Buffer size adjusted from 2769 to 1888 (eff_cnt=1584)
07:26:05.158                capdbuf  Buffer size adjusted from 2528 to 2036 (eff_cnt=1584)
07:26:05.216                capdbuf  Buffer size adjusted from 2676 to 1944 (eff_cnt=1584)
07:26:05.275                capdbuf  Buffer size adjusted from 2584 to 1968 (eff_cnt=1584)
07:26:05.317                capdbuf  Buffer size adjusted from 2608 to 1982 (eff_cnt=1584)
07:26:05.376                capdbuf  Buffer size adjusted from 2622 to 2046 (eff_cnt=1584)
07:26:05.434                capdbuf  Buffer size adjusted from 2686 to 2088 (eff_cnt=1584)
07:26:05.477                capdbuf  Buffer size adjusted from 2728 to 2128 (eff_cnt=1584)
07:26:05.535                capdbuf  Buffer size adjusted from 2768 to 1994 (eff_cnt=1584)
07:26:05.579                capdbuf  Buffer size adjusted from 2634 to 2044 (eff_cnt=1584)
07:26:05.637                capdbuf  Buffer size adjusted from 2684 to 2210 (eff_cnt=1584)
07:26:05.695                capdbuf  Buffer size adjusted from 2850 to 2002 (eff_cnt=1584)
07:26:05.738                capdbuf  Buffer size adjusted from 2642 to 2152 (eff_cnt=1584)
07:26:05.796                capdbuf  Buffer size adjusted from 2792 to 2022 (eff_cnt=1584)
07:26:05.854                capdbuf  Buffer size adjusted from 2662 to 2148 (eff_cnt=1584)
07:26:05.898                capdbuf  Buffer size adjusted from 2788 to 2112 (eff_cnt=1584)
07:26:05.956                capdbuf  Buffer size adjusted from 2752 to 2080 (eff_cnt=1584)
07:26:06.000                capdbuf  Buffer size adjusted from 2720 to 2154 (eff_cnt=1584)
07:26:06.058                capdbuf  Buffer size adjusted from 2794 to 2150 (eff_cnt=1584)
07:26:06.116                capdbuf  Buffer size adjusted from 2790 to 2108 (eff_cnt=1584)
07:26:06.175                capdbuf  Buffer size adjusted from 2748 to 1892 (eff_cnt=1584)
07:26:06.217                capdbuf  Buffer size adjusted from 2532 to 2102 (eff_cnt=1584)
07:26:06.276                capdbuf  Buffer size adjusted from 2742 to 2040 (eff_cnt=1584)
07:26:06.319                capdbuf  Buffer size adjusted from 2680 to 2132 (eff_cnt=1584)
07:26:06.322           pjsua_core.c  .RX 1124 bytes Response msg 200/INVITE/cseq=28371 (rdata0x55abb63e48) from TCP 192.168.1.4:5060:
SIP/2.0 200 OK
Via: SIP/2.0/TCP 192.168.1.8:38859;branch=z9hG4bKPj32af9348-c9bb-4060-9d9f-4d8cba464daf;received=192.168.1.8;rport=5060
From: sip:1001@192.168.1.4;tag=5a61ba17-b1b3-4cc3-96e1-46dbffbcf7f3
To: <sip:1006@192.168.1.4>;tag=cec7704ea19952cd
CSeq: 28371 INVITE
Call-ID: 4c51ed3d-6cd6-4b3c-b9d2-97d1a2e66dc0
Allow: ACK, BYE, CANCEL, INFO, INVITE, MESSAGE, NOTIFY, OPTIONS, PRACK, REFER, REGISTER, SUBSCRIBE
Contact: <sip:1006@192.168.1.4;transport=tcp>
Content-Type: application/sdp
Content-Length: 601

v=0
o=- 1768721167 1768721167 IN IP4 192.168.1.4
s=mss
t=0 0
m=audio 20400 RTP/AVP 8 0 96 120
c=IN IP4 192.168.1.4
a=mid:0
a=sendrecv
a=rtpmap:8 PCMA/8000
a=rtpmap:0 PCMU/8000
a=rtpmap:96 opus/48000/2
a=fmtp:96 useinbandfec=1
a=rtpmap:120 telephone-event/8000
a=fmtp:120 0-16
a=ssrc:2625035282 cname:1+mJXWTXgNeOJrTW
m=video 20402 RTP/AVP 100 104
c=IN IP4 192.168.1.4
a=mid:1
a=sendrecv
a=rtpmap:100 H264/90000
a=rtpmap:104 VP8/90000
a=fmtp:104 max-fr=30;max-fs=580
a=ssrc:1893418499 cname:1+mJXWTXgNeOJrTW
a=fmtp:100 packetization-mode=1;profile-level-id=42e01e;session-id=14

--end msg--
[DEBUG] 🔔 [PJSIP C CALLBACK] call_state_callback_wrapper() called, call_id: 0
[DEBUG] 🔔 [PJSIP C CALLBACK] Getting call info...
[DEBUG] 🔔 [PJSIP C CALLBACK] pjsua_call_get_info() status: 0
[DEBUG] ✅ [UI UPDATE] Call 0 state: "连接中..."
[DEBUG] ✅ [CALL STATE] Call 0 state: CONNECTING
[DEBUG] 🔔 [PJSIP C CALLBACK] Calling original PJSUA2 on_call_state callback...
[DEBUG] 🔔 [PJSIP C CALLBACK] call_state_callback_wrapper() called, call_id: 0
[DEBUG] ⚠️ [PJSIP C CALLBACK] Recursive invocation detected, returning
[DEBUG] 🔔 [PJSIP C CALLBACK] Original callback returned
[DEBUG] 🔔 [PJSIP C CALLBACK] call_state_callback_wrapper() completed
07:26:06.322        inv0x55a9311af0  ....SDP negotiation done: Success
07:26:06.322          pjsua_media.c  .....Call 0: updating media..
07:26:06.322         avsync-call_00  ......avsync-call_00 created
07:26:06.322          pjsua_media.c  ......🔍 [MEDIA LOOP] Processing 2 media streams for call 0
07:26:06.322          pjsua_media.c  ......🔍 [MEDIA LOOP] 4=== Processing media 0, type=1 ===
07:26:06.322          pjsua_media.c  ......🔍 [MEDIA LOOP] Applying media update for media 0, type=1
07:26:06.322          pjsua_media.c  ......🔍 [MEDIA LOOP] Calling apply_med_update() for AUDIO (media 0)
07:26:06.322          pjsua_media.c  ......🔍 [FIX 100.51 DIAG] First media update (call_id=0 media=0)
07:26:06.323          pjsua_media.c  .......Media stream call00:0 is destroyed
07:26:06.323          pjsua_media.c  ......🔍 [MEDIA] Calling pjmedia_transport_media_start() for media 0 (type=1)
07:26:06.323        udp0x55abee9270  ......UDP media transport started
07:26:06.323          pjsua_media.c  ......✅ [MEDIA] pjmedia_transport_media_start() returned status=0
07:26:06.323          pjsua_media.c  ......🔍 [MEDIA] Checking media_changed flag: 1 (media 0, type=1)
07:26:06.323          pjsua_media.c  ......🔍 [MEDIA] Media changed, entering channel update block
07:26:06.323          pjsua_media.c  ......🔍 [MEDIA] Calling pjsua_aud_channel_update()-5
07:26:06.323            pjsua_aud.c  ......Audio channel update for index 0 for call 0...
07:26:06.323       strm0x7ecc006fb8  .......VAD temporarily disabled
07:26:06.323        udp0x55abee9270  .......UDP media transport attached
07:26:06.323       strm0x7ecc006fb8  .......Receive RTCP-FB generic NACK
[DEBUG] 🔍 [QML] Video Accept Button visibility check:
[DEBUG]     callStatus: 连接中... → hasCallStatus: false
07:26:06.323         avsync-call_00  .......Added media Audio, clock rate=8000
07:26:06.323       strm0x7ecc006fb8  .......Encoder stream started
07:26:06.323       strm0x7ecc006fb8  .......Decoder stream started
[DEBUG]     isIncomingVideoCall: false
[DEBUG]     → visible: false
[DEBUG] 🔔 [PJSIP CALLBACK] onStreamCreated() triggered
[DEBUG] 📞 [RINGTONE] Call status changed: 连接中...
[DEBUG] 🔔 [PJSIP CALLBACK] Stream index: 0
[DEBUG] 🔔 [PJSIP CALLBACK] Stream pointer: 0x7ecc006fb8
[DEBUG] 🔔 [PJSIP CALLBACK] onStreamCreated() returning...
07:26:06.324           conference.c  ........Add port 1 (sip:1006@192.168.1.4) queued
07:26:06.324          pjsua_media.c  ......🔍 [TRANSPORT] About to check transport info for media 0
07:26:06.324          pjsua_media.c  ......🔍 [TRANSPORT] No LOOP transport for media 0
07:26:06.324          pjsua_media.c  ......✅ [MEDIA PROCESSING] Media 0 processing completed successfully
07:26:06.324          pjsua_media.c  ......🔍 [LOOP] Exiting media_changed block for media 0
07:26:06.324          pjsua_media.c  ......🔍 [LOOP] Completed all checks for media 0, about to finish iteration
07:26:06.324          pjsua_media.c  ......audio updated, stream #0: PCMA (sendrecv)
07:26:06.324          pjsua_media.c  ......✅ [MEDIA LOOP] apply_med_update() for AUDIO returned status=0
07:26:06.324          pjsua_media.c  ......🔍 [MEDIA LOOP] About to check status (status=0, PJ_SUCCESS=0)
07:26:06.324          pjsua_media.c  ......🔍 [MEDIA LOOP] Status check passed, about to log success
07:26:06.324          pjsua_media.c  ......✅ [MEDIA LOOP] AUDIO succeeded, continuing...
07:26:06.324          pjsua_media.c  ......🔍 [MEDIA LOOP] Checking deactivated transport (media 0, port=4000)
07:26:06.324          pjsua_media.c  ......✅ [MEDIA LOOP] Transport check completed for media 0
07:26:06.324          pjsua_media.c  ......🔍 [MEDIA LOOP] Entered on_check_med_status for media 0, status=0
07:26:06.324          pjsua_media.c  ......✅ [MEDIA LOOP] Status SUCCESS for media 0
07:26:06.324          pjsua_media.c  ......🔍 [MEDIA LOOP] Checking got_media flag (media 0, port=4000)
07:26:06.324          pjsua_media.c  ......✅ [MEDIA LOOP] Setting got_media=TRUE for media 0
07:26:06.324          pjsua_media.c  ......✅ [MEDIA LOOP] Completed processing media 0 (status=0), moving to next
07:26:06.324          pjsua_media.c  ......🔍 [MEDIA LOOP] 4=== Processing media 1, type=2 ===
07:26:06.324          pjsua_media.c  ......🔍 [MEDIA LOOP] Applying media update for media 1, type=2
07:26:06.324          pjsua_media.c  ......🔍 [MEDIA LOOP] Calling apply_med_update() for VIDEO (media 1)
07:26:06.324          pjsua_media.c  ......🔍 [FIX 100.51 DIAG] Media update for call_id=0 media=1
07:26:06.324          pjsua_media.c  ......   Time since last call end: 0.002 seconds
07:26:06.324          pjsua_media.c  ......   vid_conf port_count=0 (before update)
07:26:06.324          pjsua_media.c  ......⚠️ [FIX 100.51 DIAG] Too soon after last call, vid_conf might still be cleaning up
07:26:06.324          pjsua_media.c  ......🔍 [MEDIA] Calling pjmedia_vid_stream_info_from_sdp() for media 1
07:26:06.324          pjsua_media.c  ......✅ [MEDIA] pjmedia_vid_stream_info_from_sdp() returned status=0
07:26:06.324          pjsua_media.c  .......Media stream call00:1 is destroyed
07:26:06.324          pjsua_media.c  ......🔍 [MEDIA] Calling pjmedia_transport_media_start() for media 1 (type=2)
07:26:06.324        udp0x55abb577d0  ......UDP media transport started
07:26:06.324          pjsua_media.c  ......✅ [MEDIA] pjmedia_transport_media_start() returned status=0
07:26:06.324          pjsua_media.c  ......🔍 [MEDIA] Checking media_changed flag: 1 (media 1, type=2)
07:26:06.324          pjsua_media.c  ......🔍 [MEDIA] Media changed, entering channel update block
07:26:06.324          pjsua_media.c  ......🔍 [MEDIA] Calling pjsua_vid_channel_update()
07:26:06.324            pjsua_vid.c  ......🔍 [FIX 100.51 DIAG] Video channel update #1
07:26:06.324            pjsua_vid.c  ......   call_id=0, media_idx=1, inv_state=4
07:26:06.324            pjsua_vid.c  ......   vid_conf port_count=0
07:26:06.324            pjsua_vid.c  ......   call_med->type=2, call_med->tp_ready=0
07:26:06.324            pjsua_vid.c  ......Video channel update..
07:26:06.324            pjsua_vid.c  .......🔍 [DEBUG] About to call pjmedia_vid_dev_get_info
07:26:06.324            pjsua_vid.c  .......   cap_dev ID: 0
07:26:06.324            pjsua_vid.c  .......   codec_info ptr: 0x7f067c9bf8
07:26:06.324            pjsua_vid.c  .......   codec_info->
╔══════════════════════════════════════════════════════════════╗
║ [FFmpeg层] avcodec_open2() - ULTRA EARLY ENTRY             ║
║ [FIX 100.223] 函数入口第1条语句（局部变量声明前）          ║
╠══════════════════════════════════════════════════════════════╣
║   AVCodecContext 指针: 0x7ecc0155e0                         ║
║   thread_type: 3                                           ║
║   thread_count: 1                                          ║
║   codec 参数: 0x7f88ca9190 (name: h264_rkmpp)                    ║
╚══════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════╗
║ [FIX 100.225-FFMPEG] AVCodecContext 结构体内存导出（入口）  ║
╠══════════════════════════════════════════════════════════════╣
║ 层级: FFmpeg (编译链接 FFmpeg 的 AVCodecContext 定义)      ║
║ FFmpeg 编译时使用的 FFmpeg 版本:                            ║
║   LIBAVCODEC_VERSION_MAJOR: 60                              ║
║   完整版本: LIBAVCODEC_VERSION                                              ║
║   头文件来源推断:                                           ║
║     ✅ FFmpeg-Rockchip (v60) - 源码编译                     ║
║     路径: cross-compile/src/ffmpeg-rockchip-6.0/...         ║
╠══════════════════════════════════════════════════════════════╣
║ sizeof(AVCodecContext): 944 bytes                           ║
║ AVCodecContext 地址: 0x7ecc0155e0                         ║
╠══════════════════════════════════════════════════════════════╣
║ 字段偏移量（从结构体起始地址）：                            ║
║   thread_type:  offset=640, 值=3                          ║
║   thread_count: offset=636, 值=1                          ║
║   width:        offset=116, 值=640                          ║
║   height:       offset=120, 值=480                          ║
║   bit_rate:     offset=56, 值=200000                        ║
╠══════════════════════════════════════════════════════════════╣
║ 原始内存 dump（前 128 字节，16进制）：                      ║
║ 0000: d0 b1 c9 88 7f 00 00 00 00 00 00 00 00 00 00 00 ║
║ 0010: 90 91 ca 88 7f 00 00 00 1b 00 00 00 00 00 00 00 ║
║ 0020: 80 16 00 cc 7e 00 00 00 00 00 00 00 00 00 00 00 ║
║ 0030: 18 48 01 cc 7e 00 00 00 40 0d 03 00 00 00 00 00 ║
║ 0040: 00 09 3d 00 00 00 00 00 ff ff ff ff 00 00 00 00 ║
║ 0050: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ║
║ 0060: 00 00 00 00 00 00 00 00 01 00 00 00 01 00 00 00 ║
║ 0070: 00 00 00 00 80 02 00 00 e0 01 00 00 80 02 00 00 ║
╚══════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════╗
║ [FFmpeg层] avcodec.c - avcodec_open2() 入口                  ║
╠══════════════════════════════════════════════════════════════╣
║ [FIX 100.220-A] ENTRY POINT                                  ║
║   类型: 🎥 解码器 (DECODER)                             ║
║   AVCodecContext: 0x7ecc0155e0                              ║
║   thread_type: 3 (期望=0, FF_THREAD_FRAME=1)               ║
║   thread_count: 1 (期望=4)                                 ║
║   codec: h264_rkmpp                                         ║
╚══════════════════════════════════════════════════════════════╝
║ [FFmpeg层] avcodec.c - 第一次 av_opt_set_dict() 之前       ║
║ [FIX 100.220-D] BEFORE av_opt_set_dict(avctx->priv_data)   ║
║   类型: 🎥 解码器                                       ║
║   AVCodecContext: 0x7ecc0155e0                              ║
║   codec->name: h264_rkmpp                                   ║
║   thread_type: 3  thread_count: 1                         ║
║ [FFmpeg层] avcodec.c - 第一次 av_opt_set_dict() 之后       ║
║ [FIX 100.220-E] AFTER av_opt_set_dict(avctx->priv_data)    ║
║   类型: 🎥 解码器                                       ║
║   thread_type: 3  thread_count: 1                         ║
║   如果值变了，问题在第一次 av_opt_set_dict()               ║
║ [FFmpeg层] avcodec.c - 第二次 av_opt_set_dict() 之前       ║
║ [FIX 100.220-F] BEFORE av_opt_set_dict(avctx, options)       ║
║   类型: 🎥 解码器                                       ║
║   AVCodecContext: 0x7ecc0155e0                              ║
║   codec->name: h264_rkmpp                                   ║
║   thread_type: 3  thread_count: 1                         ║
║ [FFmpeg层] avcodec.c - av_opt_set_dict() 之后               ║
║ [FIX 100.220-B] AFTER av_opt_set_dict(avctx, options)       ║
║   类型: 🎥 解码器                                       ║
║   thread_type: 3  thread_count: 1                         ║
║   如果值变了，问题在 av_opt_set_dict()                      ║
║ [FFmpeg层] avcodec.c - 即将调用 ff_encode_preinit()         ║
║ [FIX 100.220-C] BEFORE ff_encode_preinit()                  ║
║   类型: 🎥 解码器                                       ║
║   thread_type: 3  thread_count: 1                         ║
║   下一步进入 encode.c → ff_frame_thread_encoder_init()      ║
║ [FFmpeg层] avcodec.c - ff_thread_init() 之前             ║
║ [FIX 100.220-G] BEFORE ff_thread_init()                   ║
║   类型: 🎥 解码器                                       ║
║   AVCodecContext: 0x7ecc0155e0                              ║
║   thread_type: 3  thread_count: 1                         ║
║   active_thread_type: 0 (0=NONE, 1=FRAME, 2=SLICE)        ║
║ [FFmpeg层] pthread.c - validate_thread_parameters() 入口      ║
║ [FIX 100.220-I] ENTRY POINT                                   ║
║   类型: 🎥 解码器                                       ║
║   AVCodecContext: 0x7ecc0155e0                              ║
║   codec->name: h264_rkmpp                                   ║
║   thread_type: 3  thread_count: 1                         ║
║   active_thread_type: 0 (BEFORE)                            ║
╠══════════════════════════════════════════════════════════════╣
║ 条件检查:                                                    ║
║   thread_count == 1: 1                                      ║
║   frame_threading_supported: 0                              ║
║     (capabilities & CAP_FRAME_THREADS): 0                   ║
║     (flags & LOW_DELAY): 0                                  ║
║     (flags2 & CHUNKS): 0                                    ║
║   (thread_type & FF_THREAD_FRAME): 1                        ║
║   (capabilities & CAP_SLICE_THREADS): 0                      ║
║   (thread_type & FF_THREAD_SLICE): 2                         ║
║   (caps_internal & AUTO_THREADS): 0                          ║
║ ✅ 条件1: thread_count == 1 → active_thread_type = 0       ║
╠══════════════════════════════════════════════════════════════╣
║   active_thread_type: 0 (AFTER)                             ║
╚══════════════════════════════════════════════════════════════╝
║ [FFmpeg层] avcodec.c - ff_thread_init() 之后             ║
║ [FIX 100.220-H] AFTER ff_thread_init()                    ║
║   类型: 🎥 解码器                                       ║
║   thread_type: 3  thread_count: 1                         ║
║   active_thread_type: 0 (0=NONE, 1=FRAME, 2=SLICE)        ║
║   如果 active_thread_type 变了，问题在 ff_thread_init()    ║
mpp[1]: mpp_info: mpp version: b13eb80 author: Herman Chen    2026-01-08 feat[mpp_ext]: Move parsers to libmpp_ext.so
dec_fmt_id_cnt: 1
07:26:06.324            pjsua_vid.c  .......🔍 [DEBUG] pjmedia_vid_dev_get_info returned status: 0
07:26:06.324    ffmpeg_vid_codecs.c  .......
07:26:06.324    ffmpeg_vid_codecs.c  .......========================================
07:26:06.324    ffmpeg_vid_codecs.c  .......🔍 [STARTUP-VERSION] 156
07:26:06.324    ffmpeg_vid_codecs.c  .......   Fix 100.80: Use av_packet_alloc() instead of deprecated av_init_packet() (encoder/decoder both) - fixes memory corruption
07:26:06.324    ffmpeg_vid_codecs.c  .......   Date: 2026-01-14
07:26:06.324    ffmpeg_vid_codecs.c  .......========================================
07:26:06.324    ffmpeg_vid_codecs.c  .......
07:26:06.324    ffmpeg_vid_codecs.c  .......
07:26:06.324    ffmpeg_vid_codecs.c  .......========================================
07:26:06.324    ffmpeg_vid_codecs.c  .......[FIX 100.203 DIAG-C] AVCodecContext ALLOCATED
07:26:06.324    ffmpeg_vid_codecs.c  .......========================================
07:26:06.324    ffmpeg_vid_codecs.c  .......  ff->enc_ctx: 0x7ecc015220
07:26:06.324    ffmpeg_vid_codecs.c  .......  ff->enc_ctx->priv_data: 0x7ecc0015e0
07:26:06.324    ffmpeg_vid_codecs.c  .......  ff->enc->name: h264_rkmpp
07:26:06.324    ffmpeg_vid_codecs.c  .......  🔍 This is the ORIGINAL address allocated by PJSIP
07:26:06.324    ffmpeg_vid_codecs.c  .......[FIX 100.203 DIAG-C] COMPLETE
07:26:06.324    ffmpeg_vid_codecs.c  .......========================================
07:26:06.324    ffmpeg_vid_codecs.c  .......
07:26:06.324    ffmpeg_vid_codecs.c  .......🔍 [PIX_FMT] Initial pix_fmt from dec_fmt: 0
07:26:06.324    ffmpeg_vid_codecs.c  .......⚠️ [FIX 100.38] RKMPP encoder detected: h264_rkmpp
07:26:06.324    ffmpeg_vid_codecs.c  .......   Encoder preferred format: 8 (drm_prime)
07:26:06.324    ffmpeg_vid_codecs.c  .......   Setting pix_fmt to NV12 (23) to match decoder output
07:26:06.324    ffmpeg_vid_codecs.c  .......✅ [FIX 100.45] RKMPP encoder configured for I420 input
07:26:06.324    ffmpeg_vid_codecs.c  .......   Matches camera output: I420 (3 planes: Y, U, V)
07:26:06.324    ffmpeg_vid_codecs.c  .......   Internal conversion: I420 → NV12 → DRM_PRIME (handled by encoder)
07:26:06.324    ffmpeg_vid_codecs.c  .......✅ [FIX 84/100.11] Detected RKMPP decoder: h264_rkmpp
07:26:06.324    ffmpeg_vid_codecs.c  .......   Strategy: Hardware-first mode (VPU with hwdevice, fallback to system memory)
07:26:06.324    ffmpeg_vid_codecs.c  .......   ✅ Fix 100.11: Create hwdevice → avoid crash on device 192.168.1.8
07:26:06.324    ffmpeg_vid_codecs.c  .......   ✅ Keep get_format callback → select NV12/I420 if possible
07:26:06.324    ffmpeg_vid_codecs.c  .......   ✅ [FIX 100.11] hwdevice created: /dev/dri/renderD128
07:26:06.324    ffmpeg_vid_codecs.c  .......   ✅ get_format callback set (will select NV12 or I420)
07:26:06.324           conference.c !.Added port 1 (sip:1006@192.168.1.4), port count=2
07:26:06.329       strm0x7ecc006fb8  Bad RTP pt 126 (expecting 8)
07:26:06.329    ffmpeg_vid_codecs.c !.......✅ [FIX 84] RKMPP decoder opened successfully (hybrid mode)
07:26:06.329    ffmpeg_vid_codecs.c  .......   Decoder output format: 179 (expected: 23=NV12 or 0=I420)
07:26:06.329    ffmpeg_vid_codecs.c  .......   Decoder dimensions: 640x480
07:26:06.329    ffmpeg_vid_codecs.c  .......   ⚠️ Unexpected format 179! May cause compatibility issues.
07:26:06.329    ffmpeg_vid_codecs.c  .......      Expected: 23 (NV12) or 0 (I420)
07:26:06.329    ffmpeg_vid_codecs.c  .......✅ [PLAN D - 纯硬件] Decoder will output I420, convert to NV12 using RGA3
07:26:06.329    ffmpeg_vid_codecs.c  .......   Strategy: I420 → RGA3 (HW) → NV12 → RGA3 (HW) → RGBA
07:26:06.329    ffmpeg_vid_codecs.c  .......   Performance: VPU(0%) + RGA3(0%) + RGA3(0%) = ~15% CPU (all hardware)
07:26:06.329    ffmpeg_vid_codecs.c  .......✅ [FIX 59] H.264 packetizer mode set to: 1 (NON_INTERLEAVED (FU-A supported))
07:26:06.329    ffmpeg_vid_codecs.c  .......✅ [FIX 100.44] Set encoder framerate=30/1 (expected output: 30fps)
07:26:06.329    ffmpeg_
╔══════════════════════════════════════════════════════════════╗
║ [FFmpeg层] avcodec_open2() - ULTRA EARLY ENTRY             ║
║ [FIX 100.223] 函数入口第1条语句（局部变量声明前）          ║
╠══════════════════════════════════════════════════════════════╣
║   AVCodecContext 指针: 0x7ecc0155e0                         ║
║   thread_type: 3                                           ║
║   thread_count: 1                                          ║
║   codec 参数: 0x7f88ca9190 (name: h264_rkmpp)                    ║
╚══════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════╗
║ [FIX 100.225-FFMPEG] AVCodecContext 结构体内存导出（入口）  ║
╠══════════════════════════════════════════════════════════════╣
║ 层级: FFmpeg (编译链接 FFmpeg 的 AVCodecContext 定义)      ║
║ FFmpeg 编译时使用的 FFmpeg 版本:                            ║
║   LIBAVCODEC_VERSION_MAJOR: 60                              ║
║   完整版本: LIBAVCODEC_VERSION                                              ║
║   头文件来源推断:                                           ║
║     ✅ FFmpeg-Rockchip (v60) - 源码编译                     ║
║     路径: cross-compile/src/ffmpeg-rockchip-6.0/...         ║
╠══════════════════════════════════════════════════════════════╣
║ sizeof(AVCodecContext): 944 bytes                           ║
║ AVCodecContext 地址: 0x7ecc0155e0                         ║
╠══════════════════════════════════════════════════════════════╣
║ 字段偏移量（从结构体起始地址）：                            ║
║   thread_type:  offset=640, 值=3                          ║
║   thread_count: offset=636, 值=1                          ║
║   width:        offset=116, 值=640                          ║
║   height:       offset=120, 值=480                          ║
║   bit_rate:     offset=56, 值=200000                        ║
╠══════════════════════════════════════════════════════════════╣
║ 原始内存 dump（前 128 字节，16进制）：                      ║
║ 0000: d0 b1 c9 88 7f 00 00 00 00 00 00 00 00 00 00 00 ║
║ 0010: 90 91 ca 88 7f vid_codecs.c  .......   Encoder: h264_rkmpp (h264_rkmpp, applying standard configuration)
07:26:06.329    ffmpeg_vid_codecs.c  .......Failed to set H264 max NAL size to 1304
07:26:06.329    ffmpeg_vid_codecs.c  .......✅ [FIX 61] Disabled x264 intra-refresh to restore SPS/PPS
07:26:06.329    ffmpeg_vid_codecs.c  .......❌ [FIX 67] Failed to set x264opts
07:26:06.329    ffmpeg_vid_codecs.c  .......Failed to set x264 preset 'veryfast'
07:26:06.329    ffmpeg_vid_codecs.c  .......Failed to set x264 tune 'zerolatency'
07:26:06.329    ffmpeg_vid_codecs.c  .......✅ [FIX 37] Set GOP size to 300 (10-second keyframe interval at 30/1 fps)
07:26:06.329    ffmpeg_vid_codecs.c  .......   keyint_min=30, max_b_frames=0
07:26:06.329    ffmpeg_vid_codecs.c  .......✅ [FIX 97.1] Detected RKMPP encoder: h264_rkmpp
07:26:06.329    ffmpeg_vid_codecs.c  .......   Creating shared RKMPP hwdevice via DRM Render Node...
07:26:06.329    ffmpeg_vid_codecs.c  .......   ✅ [FIX 97.1] Shared RKMPP hwdevice created successfully
07:26:06.329    ffmpeg_vid_codecs.c  .......   ✅ [FIX 97.1] Encoder hw_device_ctx set (shared with decoder via renderD128)
07:26:06.329    ffmpeg_vid_codecs.c  .......   Strategy: DRM Render Node (/dev/dri/renderD128) for concurrent encode/decode
07:26:06.329    ffmpeg_vid_codecs.c  .......   Verified by: Jellyfin, Frigate, Radxa Community
07:26:06.329    ffmpeg_vid_codecs.c  .......   ✅ [Fix 100.50 原始代码] hw_frames_ctx set to NULL
07:26:06.329    ffmpeg_vid_codecs.c  .......✅ [FIX 81] STEP 1: Opening HARDWARE decoder FIRST (before encoder)
07:26:06.329    ffmpeg_vid_codecs.c  .......   Decoder: h264_rkmpp
07:26:06.329    ffmpeg_vid_codecs.c  .......   RKMPP hwdevice: 0x7ecc000d30
07:26:06.329    ffmpeg_vid_codecs.c  .......   Strategy: Let RKMPP occupy DRM render node first
07:26:06.330    ffmpeg_vid_codecs.c  .......✅ [FIX 81] STEP 1 SUCCESS: Decoder opened successfully
07:26:06.330    ffmpeg_vid_codecs.c  .......   Decoder output format: 179
07:26:06.330    ffmpeg_vid_codecs.c  .......   Decoder dimensions: 640x480
07:26:06.330    ffmpeg_vid_codecs.c  .......✅ [FIX 81] STEP 2: Opening encoder AFTER decoder
07:26:06.330    ffmpeg_vid_codecs.c  .......   Encoder: h264_rkmpp
07:26:06.330    ffmpeg_vid_codecs.c  .......   Strategy: Encoder initializes after RKMPP occupied DRM
07:26:06.330    ffmpeg_vid_codecs.c  .......🔍 [MUTEX REMOVED] Opening encoder WITHOUT mutex lock
07:26:06.330    ffmpeg_vid_codecs.c  .......🔍 [DEBUG] Encoder name: h264_rkmpp
07:26:06.330    ffmpeg_vid_codecs.c  .......🔍 [DEBUG] Encoder context: width=640, height=480, pix_fmt=0, bitrate=800000
07:26:06.330    ffmpeg_vid_codecs.c  .......🔍 [DEBUG] Encoder details:
07:26:06.330    ffmpeg_vid_codecs.c  .......   codec_id=27, codec_type=0
07:26:06.330    ffmpeg_vid_codecs.c  .......   profile=578, level=30
07:26:06.330    ffmpeg_vid_codecs.c  .......   gop_size=300, max_b_frames=0
07:26:06.330    ffmpeg_vid_codecs.c  .......   thread_count=1, thread_type=3
07:26:06.330    ffmpeg_vid_codecs.c  .......   time_base=1/30, framerate=30/1
07:26:06.330    ffmpeg_vid_codecs.c  .......🔍 [DEBUG] hw_device_ctx is set: 0x7ecc0160d0
07:26:06.330    ffmpeg_vid_codecs.c  .......   hw_device_ctx->data: 0x7ecc62bc40
07:26:06.330    ffmpeg_vid_codecs.c  .......   hw_device_ctx->size: 48
07:26:06.330    ffmpeg_vid_codecs.c  .......✅ [FIX 100.84.1] Solution B - rkmppenc.c skips hwframe/hwdevice release
07:26:06.330    ffmpeg_vid_codecs.c  .......
07:26:06.330    ffmpeg_vid_codecs.c  .......========================================
07:26:06.330    ffmpeg_vid_codecs.c  .......[FIX 100.203 DIAG-D] BEFORE avcodec_open2()
07:26:06.330    ffmpeg_vid_codecs.c  .......========================================
07:26:06.330    ffmpeg_vid_codecs.c  .......  ff->enc_ctx: 0x7ecc015220
07:26:06.330    ffmpeg_vid_codecs.c  .......  ff->enc_ctx->priv_data: 0x7ecc0015e0
07:26:06.330    ffmpeg_vid_codecs.c  .......  🔍 About to call avcodec_open2() - will FFmpeg replace this?
07:26:06.330    ffmpeg_vid_codecs.c  .......[FIX 100.203 DIAG-D] COMPLETE
07:26:06.3300 00 00 1b 00 00 00 00 00 00 00 ║
║ 0020: 80 16 00 cc 7e 00 00 00 d0 11 00 cc 7e 00 00 00 ║
║ 0030: 18 48 01 cc 7e 00 00 00 40 0d 03 00 00 00 00 00 ║
║ 0040: 00 09 3d 00 00 00 00 00 ff ff ff ff 00 00 00 00 ║
║ 0050: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ║
║ 0060: 00 00 00 00 00 00 00 00 01 00 00 00 01 00 00 00 ║
║ 0070: 00 00 00 00 80 02 00 00 e0 01 00 00 80 02 00 00 ║
╚══════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════╗
║ [FFmpeg层] avcodec.c - avcodec_open2() 入口                  ║
╠══════════════════════════════════════════════════════════════╣
║ [FIX 100.220-A] ENTRY POINT                                  ║
║   类型: 🎥 解码器 (DECODER)                             ║
║   AVCodecContext: 0x7ecc0155e0                              ║
║   thread_type: 3 (期望=0, FF_THREAD_FRAME=1)               ║
║   thread_count: 1 (期望=4)                                 ║
║   codec: h264_rkmpp                                         ║
╚══════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════╗
║ [PJSIP层] ffmpeg_vid_codecs.c - 即将调用avcodec_open2()     ║
║ [FIX 100.222] BEFORE avcodec_open2() - NO BUFFER            ║
╠══════════════════════════════════════════════════════════════╣
║   AVCodecContext: 0x7ecc015220                              ║
║   thread_type: 3 (期望=0)                                  ║
║   thread_count: 1 (期望=4)                                 ║
║   codec: h264_rkmpp                                         ║
║   ❌ 值已被修改! 这里就已经是错误的!                        ║
╚══════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════╗
║ [PJSIP层] AVCODEC_OPEN 宏展开诊断                          ║
║ [FIX 100.224] BEFORE MACRO EXPANSION                        ║
╠══════════════════════════════════════════════════════════════╣
║ 宏调用: AVCODEC_OPEN(ff->enc_ctx, ff->enc)                 ║
║ 展开为: avcodec_open2(ff->enc_ctx, ff->enc, NULL)          ║
╠══════════════════════════════════════════════════════════════╣
║ 参数1 (AVCodecContext*): 0x7ecc015220                     ║
║   ->thread_type:  3                                        ║
║   ->thread_count: 1                                        ║
║ 参数2 (AVCodec*):        0x7f88ca9740                     ║
║   ->name: h264_rkmpp                                        ║
║ 参数3 (AVDictionary**):  NULL (固定值)                     ║
╠══════════════════════════════════════════════════════════════╣
║ ⚠️  即将调用 avcodec_open2()...                             ║
╚══════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════╗
║ [FIX 100.225-PJSIP] AVCodecContext 结构体内存导出（调用前） ║
╠══════════════════════════════════════════════════════════════╣
║ 层级: PJSIP (编译链接 PJSIP 的 AVCodecContext 定义)        ║
║ PJSIP 编译时使用的 FFmpeg 版本:                             ║
║   LIBAVCODEC_VERSION_MAJOR: 60                              ║
║   LIBAVCODEC_VERSION_MINOR: 31                              ║
║   LIBAVCODEC_VERSION_MICRO: 102                              ║
║   完整版本: 60.31.102                                              ║
║   头文件来源推断:                                           ║
║     ✅ FFmpeg-Rockchip (v60) - 源码编译                     ║
║     路径: cross-compile/src/ffmpeg-rockchip-6.0/...         ║
╠══════════════════════════════════════════════════════════════╣
║ sizeof(AVCodecContext): 944 bytes                           ║
║ AVCodecContext 地址: 0x7ecc015220                         ║
╠══════════════════════════════════════════════════════════════╣
║ 字段偏移量（从结构体起始地址）：                            ║
║   thread_type:  offset=640, 值=3                          ║
║   thread_count: offset=636, 值=1                          ║
║   width:        offset=116, 值=640                          ║
║   height:       offset=120, 值=480                          ║
║   bit_rate:     offset=56, 值=800000                        ║
╠══════════════════════════════════════════════════════════════╣
║ 原始内存 dump（前 128 字节，16进制）：                      ║
║ 0000: d0 b1 c9 88 7f 00 00 00 00 00 00 00 00 00 00 00 ║
║ 0010: 40 97 ca 88 7f 00 00 00 1b 00 00 00 00 00 00 00 ║
║ 0020: e0 15 00 cc 7e 00 00 00 00 00 00 00 00 00 00 00 ║
║ 0030: 18 48 01 cc 7e 00 00 00 00 35 0c 00 00 00 00 00 ║
║ 0040: 80 1a 06 00 00 00 00 00 ff ff ff ff 00 00 00 00 ║
║ 0050: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ║
║ 0060: 00 00 00 00 01 00 00 00 1e 00 00 00 01 00 00 00 ║
║ 0070: 00 00 00 00 80 02 00 00 e0 01 00 00 00 00 00 00 ║
╚══════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════╗
║ [FFmpeg层] avcodec_open2() - ULTRA EARLY ENTRY             ║
║ [FIX 100.223] 函数入口第1条语句（局部变量声明前）          ║
╠══════════════════════════════════════════════════════════════╣
║   AVCodecContext 指针: 0x7ecc015220                         ║
║   thread_type: 3                                           ║
║   thread_count: 1                                          ║
║   codec 参数: 0x7f88ca9740 (name: h264_rkmpp)                    ║
╚══════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════╗
║ [FIX 100.225-FFMPEG] AVCodecContext 结构体内存导出（入口）  ║
╠══════════════════════════════════════════════════════════════╣
║ 层级: FFmpeg (编译链接 FFmpeg 的 AVCodecContext 定义)      ║
║ FFmpeg 编译时使用的 FFmpeg 版本:                            ║
║   LIBAVCODEC_VERSION_MAJOR: 60                              ║
║   完整版本: LIBAVCODEC_VERSION                                              ║
║   头文件来源推断:                                           ║
║     ✅ FFmpeg-Rockchip (v60) - 源码编译                     ║
║     路径: cross-compile/src/ffmpeg-rockchip-6.0/...         ║
╠══════════════════════════════════════════════════════════════╣
║ sizeof(AVCodecContext): 944 bytes                           ║
║ AVCodecContext 地址: 0x7ecc015220                         ║
╠══════════════════════════════════════════════════════════════╣
║ 字段偏移量（从结构体起始地址）：                            ║
║   thread_type:  offset=640, 值=3                          ║
║   thread_count: offset=636, 值=1                          ║
║   width:        offset=116, 值=640                          ║
║   height:       offset=120, 值=480                          ║
║   bit_rate:     offset=56, 值=800000                        ║
╠══════════════════════════════════════════════════════════════╣
║ 原始内存 dump（前 128 字节，16进制）：                      ║
║ 0000: d0 b1 c9 88 7f 00 00 00 00 00 00 00 00 00 00 00 ║
║ 0010: 40 97 ca 88 7f 00 00 00 1b 00 00 00 00 00 00 00 ║
║ 0020: e0 15 00 cc 7e 00 00 00 00 00 00 00 00 00 00 00 ║
║ 0030: 18 48 01 cc 7e 00 00 00 00 35 0c 00 00 00 00 00 ║
║ 0040: 80 1a 06 00 00 00 00 00 ff ff ff ff 00 00 00 00 ║
║ 0050: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ║
║ 0060: 00 00 00 00 01 00 00 00 1e 00 00 00 01 00 00 00 ║
║ 0070: 00 00 00 00 80 02 00 00 e0 01 00 00 00 00 00 00 ║
╚══════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════╗
║ [FFmpeg层] avcodec.c - avcodec_open2() 入口                  ║
╠══════════════════════════════════════════════════════════════╣
║ [FIX 100.220-A] ENTRY POINT                                  ║
║   类型: 🎬 编码器 (ENCODER)                             ║
║   AVCodecContext: 0x7ecc015220                              ║
║   thread_type: 3 (期望=0, FF_THREAD_FRAME=1)               ║
║   thread_count: 1 (期望=4)                                 ║
║   codec: h264_rkmpp                                         ║
╚══════════════════════════════════════════════════════════════╝
║ [FFmpeg层] avcodec.c - 第一次 av_opt_set_dict() 之前       ║
║ [FIX 100.220-D] BEFORE av_opt_set_dict(avctx->priv_data)   ║
║   类型: 🎬 编码器                                       ║
║   AVCodecContext: 0x7ecc015220                              ║
║   codec->name: h264_rkmpp                                   ║
║   thread_type: 3  thread_count: 1                         ║
║ [FFmpeg层] avcodec.c - 第一次 av_opt_set_dict() 之后       ║
║ [FIX 100.220-E] AFTER av_opt_set_dict(avctx->priv_data)    ║
║   类型: 🎬 编码器                                       ║
║   thread_type: 3  thread_count: 1                         ║
║   如果值变了，问题在第一次 av_opt_set_dict()               ║
║ [FFmpeg层] avcodec.c - 第二次 av_opt_set_dict() 之前       ║
║ [FIX 100.220-F] BEFORE av_opt_set_dict(avctx, options)       ║
║   类型: 🎬 编码器                                       ║
║   AVCodecContext: 0x7ecc015220                              ║
║   codec->name: h264_rkmpp                                   ║
║   thread_type: 3  thread_count: 1                         ║
║ [FFmpeg层] avcodec.c - av_opt_set_dict() 之后               ║
║ [FIX 100.220-B] AFTER av_opt_set_dict(avctx, options)       ║
║   类型: 🎬 编码器                                       ║
║   thread_type: 3  thread_count: 1                         ║
║   如果值变了，问题在 av_opt_set_dict()                      ║
║ [FFmpeg层] avcodec.c - 即将调用 ff_encode_preinit()         ║
║ [FIX 100.220-C] BEFORE ff_encode_preinit()                  ║
║   类型: 🎬 编码器                                       ║
║   thread_type: 3  thread_count: 1                         ║
║   下一步进入 encode.c → ff_frame_thread_encoder_init()      ║
║ [FFmpeg层] avcodec.c - ff_thread_init() 之前             ║
║ [FIX 100.220-G] BEFORE ff_thread_init()                   ║
║   类型: 🎬 编码器                                       ║
║   AVCodecContext: 0x7ecc015220                              ║
║   thread_type: 3  thread_count: 1                         ║
║   active_thread_type: 0 (0=NONE, 1=FRAME, 2=SLICE)        ║
║ [FFmpeg层] pthread.c - validate_thread_parameters() 入口      ║
║ [FIX 100.220-I] ENTRY POINT                                   ║
║   类型: 🎬 编码器                                       ║
║   AVCodecContext: 0x7ecc015220                              ║
║   codec->name: h264_rkmpp                                   ║
║   thread_type: 3  thread_count: 1                         ║
║   active_thread_type: 0 (BEFORE)                            ║
╠══════════════════════════════════════════════════════════════╣
║ 条件检查:                                                    ║
║   thread_count == 1: 1                                      ║
║   frame_threading_supported: 0                              ║
║     (capabilities & CAP_FRAME_THREADS): 0                   ║
║     (flags & LOW_DELAY): 0                                  ║
║     (flags2 & CHUNKS): 0                                    ║
║   (thread_type & FF_THREAD_FRAME): 1                        ║
║   (capabilities & CAP_SLICE_THREADS): 0                      ║
║   (thread_type & FF_THREAD_SLICE): 2                         ║
║   (caps_internal & AUTO_THREADS): 0                          ║
║ ✅ 条件1: thread_count == 1 → active_thread_type = 0       ║
╠══════════════════════════════════════════════════════════════╣
║   active_thread_type: 0 (AFTER)                             ║
╚══════════════════════════════════════════════════════════════╝
║ [FFmpeg层] avcodec.c - ff_thread_init() 之后             ║
║ [FIX 100.220-H] AFTER ff_thread_init()                    ║
║   类型: 🎬 编码器                                       ║
║   thread_type: 3  thread_count: 1                         ║
║   active_thread_type: 0 (0=NONE, 1=FRAME, 2=SLICE)        ║
║   如果 active_thread_type 变了，问题在 ff_thread_init()    ║
mpp[1]: mpp_info: mpp version: b13eb80 author: Herman Chen    2026-01-08 feat[mpp_ext]: Move parsers to libmpp_ext.so
mpp[1]: mpp_enc: set prep cfg w:h [640:480] stride [640:512] fmt 4 rotate 0 mirror 0
mpp[1]: mpp_enc: set rc cbr bps [800000:850000:750000] fps [30:1:fix] - [30:1:fix] gop 300
mpp[1]: mpp_enc: Warning: invalid cabac_en 1 for h264 profile 66, set to 0.
mpp[1]: mpp_enc: Warning: invalid cabac_init_idc 0 for h264 profile 66, set to -1.
mpp[1]: mpp_enc: mode cbr bps [750000:800000:850000] fps fix [30/1] -> fix [30/1] gop i [300] v [0]

╔══════════════════════════════════════════════════════════════╗
║ [PJSIP层] avcodec_open2() 返回后立即检查                   ║
║ [FIX 100.224] AFTER avcodec_open2() RETURN                  ║
╠══════════════════════════════════════════════════════════════╣
║ 返回值 (err): 0                                            ║
║ AVCodecContext: 0x7ecc015220                              ║
║   thread_type:  3                                          ║
║   thread_count: 1                                          ║
║   active_thread_type: 0                                    ║
╚══════════════════════════════════════════════════════════════╝
0    ffmpeg_vid_codecs.c  .......========================================
07:26:06.330    ffmpeg_vid_codecs.c  .......
07:26:06.330    ffmpeg_vid_codecs.c  .......🔍 [DEBUG] Calling AVCODEC_OPEN for encoder (no mutex)...
07:26:06.330    ffmpeg_vid_codecs.c  .......🔍 [ENCODER-INIT VERSION 156] Fix 100.49 code loaded
07:26:06.330    ffmpeg_vid_codecs.c  .......🔍 [DEBUG] Calling AVCODEC_OPEN() without options (not libx264)
07:26:06.333    ffmpeg_vid_codecs.c !.......   ✅ [FIX 100.238] avcodec_open2() succeeded
07:26:06.333    ffmpeg_vid_codecs.c  .......      - thread_type: 3 (should be 1 for libx264)
07:26:06.333    ffmpeg_vid_codecs.c  .......      - thread_count: 1
07:26:06.333    ffmpeg_vid_codecs.c  .......      - active_thread_type: 0 (0=NONE, 1=FRAME, 2=SLICE)
07:26:06.333    ffmpeg_vid_codecs.c  .......🔍 [DEBUG] AVCODEC_OPEN returned with err=0
07:26:06.333    ffmpeg_vid_codecs.c  .......
07:26:06.333    ffmpeg_vid_codecs.c  .......========================================
07:26:06.333    ffmpeg_vid_codecs.c  .......[FIX 100.203 DIAG-E] AFTER avcodec_open2() (err=0)
07:26:06.333    ffmpeg_vid_codecs.c  .......========================================
07:26:06.333    ffmpeg_vid_codecs.c  .......  ff->enc_ctx: 0x7ecc015220
07:26:06.333    ffmpeg_vid_codecs.c  .......  ff->enc_ctx->priv_data: 0x7ecc0015e0
07:26:06.333    ffmpeg_vid_codecs.c  .......  🔍 Compare with DIAG-D - did FFmpeg replace the pointer?
07:26:06.333    ffmpeg_vid_codecs.c  .......[FIX 100.203 DIAG-E] COMPLETE
07:26:06.333    ffmpeg_vid_codecs.c  .......========================================
07:26:06.333    ffmpeg_vid_codecs.c  .......
07:26:06.333    ffmpeg_vid_codecs.c  .......
07:26:06.333    ffmpeg_vid_codecs.c  .......========================================
07:26:06.333    ffmpeg_vid_codecs.c  .......[FIX 100.200 DIAG-A] Encoder opened successfully
07:26:06.333    ffmpeg_vid_codecs.c  .......========================================
07:26:06.333    ffmpeg_vid_codecs.c  .......  ff->enc_ctx: 0x7ecc015220
07:26:06.333    ffmpeg_vid_codecs.c  .......  ff->enc_ctx->priv_data: 0x7ecc0015e0
07:26:06.333    ffmpeg_vid_codecs.c  .......  ff->enc->name: h264_rkmpp
07:26:06.333    ffmpeg_vid_codecs.c  .......  ✅ Recording encoder context address for later comparison
07:26:06.333    ffmpeg_vid_codecs.c  .......[FIX 100.200 DIAG-A] COMPLETE
07:26:06.333    ffmpeg_vid_codecs.c  .......========================================
07:26:06.333    ffmpeg_vid_codecs.c  .......
07:26:06.333    ffmpeg_vid_codecs.c  .......
07:26:06.333    ffmpeg_vid_codecs.c  .......========================================
07:26:06.333    ffmpeg_vid_codecs.c  .......[FIX 100.204] Step 1: Verifying encoder initialization
07:26:06.333    ffmpeg_vid_codecs.c  .......========================================
07:26:06.333    ffmpeg_vid_codecs.c  .......  ff->enc pointer: 0x7f88ca9740
07:26:06.333    ffmpeg_vid_codecs.c  .......  ff->enc->name: h264_rkmpp
07:26:06.333    ffmpeg_vid_codecs.c  .......  ff->enc->id: 27 (expected H.264: 27)
07:26:06.333    ffmpeg_vid_codecs.c  .......  ff->enc->type: 0
07:26:06.333    ffmpeg_vid_codecs.c  .......  AVCodecContext key parameters:
07:26:06.333    ffmpeg_vid_codecs.c  .......    codec: 0x7f88ca9740 (should match ff->enc)
07:26:06.333    ffmpeg_vid_codecs.c  .......    codec_id: 27
07:26:06.333    ffmpeg_vid_codecs.c  .......    width: 640, height: 480
07:26:06.333    ffmpeg_vid_codecs.c  .......    pix_fmt: 0
07:26:06.333    ffmpeg_vid_codecs.c  .......    bit_rate: 800000
07:26:06.333    ffmpeg_vid_codecs.c  .......    gop_size: 300
07:26:06.333    ffmpeg_vid_codecs.c  .......    max_b_frames: 0
07:26:06.333    ffmpeg_vid_codecs.c  .......
07:26:06.333    ffmpeg_vid_codecs.c  .......[FIX 100.204] Verification complete
07:26:06.333    ffmpeg_vid_codecs.c  .......========================================
07:26:06.333    ffmpeg_vid_codecs.c  .......
07:26:06.333    ffmpeg_vid_codecs.c  .......✅ [DEBUG] Encoder opened successfully
07:26:06.333    ffmpeg_vid_codecs.c  .......🔍 [DIAG 63] Encoder flags: 0x0
07:26:06.333    ffmpeg_vid_glx: failed to create dri3 screen
failed to load driver: rockchip
codecs.c  .......   ✅ GLOBAL_HEADER is NOT set
07:26:06.333    ffmpeg_vid_codecs.c  .......🔍 [DIAG 63] Extradata size: 0
07:26:06.333    ffmpeg_vid_codecs.c  .......✅ [FIX 100.45] All encoders use I420 format (matches camera input)
07:26:06.333    ffmpeg_vid_codecs.c  .......   RKMPP encoder will convert I420 → NV12/DRM_PRIME internally
07:26:06.333        udp0x55abb577d0  .......UDP media transport attached
07:26:06.333         avsync-call_00  .......Added media Video, clock rate=90000
07:26:06.333      vstrm0x7ecc010680  .......Encoder stream started
07:26:06.333      vstrm0x7ecc010680  .......Decoder stream started
07:26:06.333     vstenc0x7ecc010680  .......Encoder stream paused
07:26:06.333            pjsua_vid.c  .......Setting up RX..
07:26:06.333            pjsua_vid.c  ........Creating video window: type=stream, cap_id=-1, rend_id=-2
07:26:06.333             vid_port.c  .........Opening device SDL renderer [SDL] for render: format=I420, size=592x592 @45:1 fps
07:26:06.377                capdbuf  Buffer size adjusted from 2772 to 2177 (eff_cnt=1584)
07:26:06.435                capdbuf  Buffer size adjusted from 2817 to 1933 (eff_cnt=1584)
07:26:06.478                capdbuf  Buffer size adjusted from 2573 to 1972 (eff_cnt=1508)
07:26:06.521             alsa_dev.c  ✅ [FIX 100.247 DEBUG] Capture stats: total=701, success=701, errors=0, frames_read=320
07:26:06.521             alsa_dev.c  🎤 [AUDIO DATA] Silent: NO ✅, Non-zero samples: 640/640 (100.0%), Max amplitude: 7696
07:26:06.537                capdbuf  Buffer size adjusted from 2612 to 1929 (eff_cnt=1508)
07:26:06.595                capdbuf  Buffer size adjusted from 2569 to 2102 (eff_cnt=1508)
07:26:06.638                capdbuf  Buffer size adjusted from 2742 to 2083 (eff_cnt=1508)
07:26:06.646             vid_port.c !.........Device SDL renderer [SDL] opened: format=I420, size=592x592 @45:1 fps
07:26:06.647             vid_conf.c  .........Add video port 0 (SDL renderer) queued
07:26:06.647            pjsua_vid.c  .........stream window id 0 created for cap_dev=-1 rend_dev=-2
07:26:06.647            pjsua_vid.c  .........Window 0 created
07:26:06.647             vid_conf.c  ........Add video port 1 (vstdec0x7ecc010680) queued
07:26:06.647             vid_conf.c  .........Connect video ports 1->0 queued
07:26:06.647              sdl_dev.c  ........Starting sdl video stream
07:26:06.648             vid_conf.c  .......Add video port 2 (vstenc0x7ecc010680) queued
07:26:06.648            pjsua_vid.c  .......Setting up TX..
07:26:06.648            pjsua_vid.c  ........✅ [FIX 33] In call (call_id=0), proceeding to open camera
07:26:06.648            pjsua_vid.c  ........⚠️ [FIX 32] PJSUA_VID_PREVIEW_DISABLE enabled, opening camera WITHOUT preview window
07:26:06.648            pjsua_vid.c  ........    Camera dev 0 will connect directly to encoder
07:26:06.648            pjsua_vid.c  ........✅ [FIX 100.37] Forced camera resolution to 640x480@30fps (VGA)
07:26:06.648            pjsua_vid.c  ........🔴 [FIX 73] Attempting to open camera (max 3 retries)
07:26:06.648             vid_port.c  ........Opening device USB camera: USB camera [v4l2] for capture: format=I420, size=640x480 @30:1 fps
07:26:06.657             vid_port.c  ........Device USB camera: USB camera [v4l2] opened: format=I420, size=640x480 @30:1 fps
07:26:06.658            pjsua_vid.c  ........🔍 [FIX 100.51 DIAG] About to add camera to vid_conf
07:26:06.658            pjsua_vid.c  ........   vid_conf port_count=0 (before add)
07:26:06.658            pjsua_vid.c  ........   vp_cap=0x7eccd54358, call_id=0
07:26:06.658             vid_conf.c  ........Add video port 3 (USB camera: USB camera) queued
07:26:06.658            pjsua_vid.c  ........✅ [FIX 100.51 DIAG] Camera added to vid_conf successfully
07:26:06.658            pjsua_vid.c  ........   cap_slot=3, vid_conf port_count=0 (after add)
07:26:06.658            pjsua_vid.c  ........🔍 [FIX 100.51 DIAG] About to connect camera to encoder
07:26:06.658            pjsua_vid.c  ........   cap_slot=3 → strm_enc_slot=2
07:26:06.658             vid_conf.c  .........Connect video ports 3->2 queued
07:26:06.658            pjsua_vid.c  ........✅ [FIX 100.51 DIAG] Camera connected to encoder successfully
07:26:06.658             v4l2_dev.c  ........Starting v4l2 video stream USB camera: USB camera
07:26:06.663             vid_conf.c !.Added video port 0 (SDL renderer), port count=1
07:26:06.663             vid_conf.c  .Added video port 1 (vstdec0x7ecc010680), port count=2
07:26:06.663             vid_conf.c  .Port 1 (vstdec0x7ecc010680) transmitting to port 0 (SDL renderer)
07:26:06.663             vid_conf.c  .Added video port 2 (vstenc0x7ecc010680), port count=3
07:26:06.663             vid_conf.c  .Added video port 3 (USB camera: USB camera), port count=4
07:26:06.663             vid_conf.c  .Port 3 (USB camera: USB camera) transmitting to port 2 (vstenc0x7ecc010680)
07:26:06.696                capdbuf  Buffer size adjusted from 2723 to 2137 (eff_cnt=1508)
07:26:06.754                capdbuf  Buffer size adjusted from 2777 to 2114 (eff_cnt=1508)
07:26:06.798                capdbuf  Buffer size adjusted from 2754 to 2145 (eff_cnt=1508)
07:26:06.834     vstenc0x7ecc010680 !Encoder stream resumed
07:26:06.856                capdbuf  Buffer size adjusted from 2785 to 2004 (eff_cnt=1508)
07:26:06.899                capdbuf  Buffer size adjusted from 2644 to 2119 (eff_cnt=1508)
07:26:06.943            pjsua_vid.c !........✅ [FIX 32] Camera opened and connected to encoder WITHOUT preview
07:26:06.943            pjsua_vid.c  ........    cap_slot=3 → strm_enc_slot=2
07:26:06.943            pjsua_vid.c  ........✅ [FIX 71.1] Saved resources to global: vp_cap=0x7eccd54358 pool=0x7eccd53d10 cap_slot=3
07:26:06.943          pjsua_media.c  ......✅ [MEDIA] pjsua_vid_channel_update() returned status=0
07:26:06.943          pjsua_media.c  ......🔍 [TRANSPORT] About to check transport info for media 1
07:26:06.943          pjsua_media.c  ......🔍 [TRANSPORT] No LOOP transport for media 1
07:26:06.943          pjsua_media.c  ......✅ [MEDIA PROCESSING] Media 1 processing completed successfully
07:26:06.943          pjsua_media.c  ......🔍 [LOOP] Exiting media_changed block for media 1
07:26:06.943          pjsua_media.c  ......🔍 [LOOP] Completed all checks for media 1, about to finish iteration
07:26:06.943          pjsua_media.c  ......video updated, stream #1: H264 (sendrecv)
07:26:06.943          pjsua_media.c  ......✅ [MEDIA LOOP] apply_med_update() for VIDEO returned status=0
07:26:06.943          pjsua_media.c  ......🔍 [MEDIA LOOP] Checking deactivated transport (media 1, port=4002)
07:26:06.943          pjsua_media.c  ......✅ [MEDIA LOOP] Transport check completed for media 1
07:26:06.943          pjsua_media.c  ......🔍 [MEDIA LOOP] Entered on_check_med_status for media 1, status=0
07:26:06.943          pjsua_media.c  ......✅ [MEDIA LOOP] Status SUCCESS for media 1
07:26:06.943          pjsua_media.c  ......🔍 [MEDIA LOOP] Checking got_media flag (media 1, port=4002)
07:26:06.943          pjsua_media.c  ......✅ [MEDIA LOOP] Setting got_media=TRUE for media 1
07:26:06.943          pjsua_media.c  ......✅ [MEDIA LOOP] Completed processing media 1 (status=0), moving to next
07:26:06.943          pjsua_media.c  ......✅ [MEDIA LOOP] All media streams processed successfully
[DEBUG] 📞 [MEDIA STATE] Call 0 media_cnt: 2 state: 4 media_status: 1
[DEBUG] 📞 [MEDIA STATE] Media 0 : type= 1 dir= 3 status= 1 (AUDIO= 1 , VIDEO= 2 )
[DEBUG] 📞 [MEDIA STATE] Media 1 : type= 2 dir= 3 status= 1 (AUDIO= 1 , VIDEO= 2 )
[DEBUG] ✅ [MEDIA STATE] Detected video in call 0
[DEBUG] 📞 [MEDIA STATE] Final result for call 0 : hasVideo = true
[DEBUG] ✅ [AUDIO CALLBACK] Media active for call 0 conf_slot: 1
07:26:06.943            pjsua_aud.c  .....Conf connect: 0 --> 1
07:26:06.943           conference.c  .......Connect ports 0->1 queued
[DEBUG] ✅ [AUDIO CALLBACK] Connected: sound device (0) → call ( 1 )
07:26:06.943            pjsua_aud.c  .....Conf connect: 1 --> 0
07:26:06.943           conference.c  .......Connect ports 1->0 queued
[DEBUG] ✅ [AUDIO CALLBACK] Connected: call ( 1 ) → sound device (0)
[DEBUG] ✅ [AUDIO CALLBACK] Audio routing completed for call 0
07:26:06.943           pjsua_core.c  .....TX 371 bytes Request msg ACK/cseq=28371 (tdta0x7ecce3b0d0) to TCP 192.168.1.4:5060:
ACK sip:1006@192.168.1.4;transport=tcp SIP/2.0
Via: SIP/2.0/TCP 192.168.1.8:38859;rport;branch=z9hG4bKPjb741dd85-bc04-496b-8d16-d952ffff1a29;alias
Max-Forwards: 70
From: sip:1001@192.168.1.4;tag=5a61ba17-b1b3-4cc3-96e1-46dbffbcf7f3
To: <sip:1006@192.168.1.4>;tag=cec7704ea19952cd
Call-ID: 4c51ed3d-6cd6-4b3c-b9d2-97d1a2e66dc0
CSeq: 28371 ACK
Content-Length:  0


--end msg--
[DEBUG] 🔔 [PJSIP C CALLBACK] call_state_callback_wrapper() called, call_id: 0
[DEBUG] 🔔 [PJSIP C CALLBACK] Getting call info...
[DEBUG] 🔔 [PJSIP C CALLBACK] pjsua_call_get_info() status: 0
[DEBUG] ✅ Notifying video managers: Call connected, ID = 0
[DEBUG] 📹 RemoteVideoManager: Call connected, callId = 0
[DEBUG] 📹 [DEBUG Fix 95] m_videoSink pointer: QVideoSink(0x55a8d007f0)
[DEBUG] 📹 [DEBUG Fix 95] m_videoSink is valid: true
[DEBUG] ✅ [UI UPDATE] Call 0 state: "视频通话中: 1006"
[DEBUG] ✅ [UI] inCall changed to: true
[DEBUG] ✅ [CALL STATE] Call 0 state: CONFIRMED
[DEBUG] 🔔 [PJSIP C CALLBACK] Calling original PJSUA2 on_call_state callback...
[DEBUG] 🔔 [PJSIP C CALLBACK] call_state_callback_wrapper() called, call_id: 0
[DEBUG] ⚠️ [PJSIP C CALLBACK] Recursive invocation detected, returning
[DEBUG] 🔔 [PJSIP C CALLBACK] Original callback returned
[DEBUG] 🔔 [PJSIP C CALLBACK] call_state_callback_wrapper() completed
07:26:06.944           conference.c !.Port 0 (hw:CARD=camera,DEV=0) transmitting to port 1 (sip:1006@192.168.1.4)
07:26:06.944           conference.c  .Port 1 (sip:1006@192.168.1.4) transmitting to port 0 (hw:CARD=camera,DEV=0)
07:26:06.944           Master/sound  Underflow, buf_cnt=0, will generate 1 frame
07:26:06.945       strm0x7ecc006fb8  Resetting jitter buffer in stream playback start
07:26:06.946       strm0x7ecc006fb8  VAD re-enabled
[DEBUG] ✅ RemoteVideoManager: Check timer started
[DEBUG] 📹 [ACTIVATE VIDEO] Checking for pending video activation for call 0
[DEBUG]    No pending video activation for this call
[DEBUG] 🔍 [QML] Video Accept Button visibility check:
[DEBUG]     callStatus: 视频通话中: 1006 → hasCallStatus: false
[DEBUG]     isIncomingVideoCall: false
[DEBUG]     → visible: false
[DEBUG] 📞 [RINGTONE] Call status changed: 视频通话中: 1006
[DEBUG] ✅ Video call started - auto-starting PJSIP local video preview
[DEBUG] ✅ LocalVideoManager: Auto-selected capture device 0 : USB camera: USB camera
[DEBUG] ⚠️ LocalVideoManager: No PJSIP preview found for device 0
[DEBUG]    [FIX 69.9] Found 1 calls, searching for video...
[DEBUG]    [FIX 69.9] Call 0 has 2 media streams
[DEBUG]    [FIX 69.9] Found active video media at index 1
[DEBUG]    [FIX 69.9] Found enc_slot: 2
[DEBUG]    [FIX 69.9] enc_slot port info:
[DEBUG]       name: "vstenc0x7ecc010680"
[DEBUG]       transmitter_cnt: 1
[DEBUG]       listener_cnt: 0
[DEBUG] ✅ [FIX 69.9] Found cap_slot via vid_conf API: 3
[DEBUG]    Connection: cap_slot( 3 ) → enc_slot( 2 )
[DEBUG] ✅ [FIX 69.12] Active call found, cap_slot: 3
[DEBUG]    Strategy: Create custom port (Push mode) connected to capture port
[DEBUG] ✅ [FIX 69.12] Custom pjmedia_port created for local preview: 640 x 480 @ 30 / 1 fps
[DEBUG] ✅ [FIX 69.12] Custom port created for local preview
07:26:06.952             vid_conf.c  Add video port 4 (qt_local_video_sink) queued
[DEBUG] ✅ [FIX 69.12] Custom port added to vid conf, slot: 4
07:26:06.952             vid_conf.c  .Connect video ports 3->4 queued
[DEBUG] ✅ [FIX 69.12] Connected cap_slot: 3 → custom_slot: 4
[DEBUG] 🎉 [FIX 69.12] Local video preview activated via custom port (Push mode)!
[DEBUG]    Architecture: Camera → Capture Port → Vid Tee → [Encoder (RTP) + Custom Port (本地预览)]
[DEBUG]    PJSIP will push frames to put_frame() callback automatically ✅
[DEBUG] ✅ [UI] Call timer started
07:26:06.957                capdbuf  Buffer size adjusted from 2759 to 1910 (eff_cnt=1508)
07:26:07.015                capdbuf  Buffer size adjusted from 2550 to 1958 (eff_cnt=1508)
07:26:07.059                capdbuf  Buffer size adjusted from 2598 to 2073 (eff_cnt=1508)
07:26:07.113     vstenc0x7ecc010680 !🔍 [RTP SEND] put_frame() FIRST CALL
07:26:07.113     vstenc0x7ecc010680     Port: vstenc0x7ecc010680
07:26:07.113     vstenc0x7ecc010680     Transport: 0x55abb9dcb8
07:26:07.113    ffmpeg_vid_codecs.c  🔍 [FIX 100.42 DIAG] AVFrame data population check:
07:26:07.113    ffmpeg_vid_codecs.c     plane_cnt=3
07:26:07.113    ffmpeg_vid_codecs.c     input->buf=0x7eccce3068, input->size=460800
07:26:07.113    ffmpeg_vid_codecs.c     Plane[0]: data=0x7eccce3068, linesize=640, bytes=307200
07:26:07.113    ffmpeg_vid_codecs.c     Plane[1]: data=0x7eccd2e068, linesize=320, bytes=76800
07:26:07.113    ffmpeg_vid_codecs.c     Plane[2]: data=0x7eccd40c68, linesize=320, bytes=76800
07:26:07.113    ffmpeg_vid_codecs.c  🔍 [FIX 100.42.2] After entering #if LIBAVCODEC_VER_AT_LEAST(58,0):
07:26:07.113    ffmpeg_vid_codecs.c     data[0]=0x7eccce3068, data[1]=0x7eccd2e068
07:26:07.113    ffmpeg_vid_codecs.c  ✅✅✅ [DIAGNOSTIC] Entered FFmpeg 58.0+ API block (FIX 100.18: with hardware frame handling)
07:26:07.113    ffmpeg_vid_codecs.c      FFmpeg version: 60.31.102
07:26:07.113    ffmpeg_vid_codecs.c      About to prepare frame and call avcodec_send_frame()
07:26:07.113    ffmpeg_vid_codecs.c  ❗❗❗ [CRITICAL] About to call avcodec_send_frame()
07:26:07.113    ffmpeg_vid_codecs.c      AVFrame: format=0 (23=NV12,0=I420,179=DRM_PRIME), size=640x480
07:26:07.113    ffmpeg_vid_codecs.c      AVFrame: linesize[0]=640, linesize[1]=320, linesize[2]=320
07:26:07.113    ffmpeg_vid_codecs.c      AVFrame: data[0]=0x7eccce3068, data[1]=0x7eccd2e068, data[2]=0x7eccd40c68
07:26:07.113    ffmpeg_vid_codecs.c      Encoder context: pix_fmt=0 (23=NV12,0=I420), size=640x480
07:26:07.113    ffmpeg_vid_codecs.c      Encoder: h264_rkmpp
07:26:07.113    ffmpeg_vid_codecs.c      ✅ [FIX 100.42 SUCCESS] hw_frames_ctx is NULL (will use CPU memory input)
07:26:07.113    ffmpeg_vid_codecs.c
07:26:07.113    ffmpeg_vid_codecs.c  ========================================
07:26:07.113    ffmpeg_vid_codecs.c  [FIX 100.198 DIAG-4] === FIRST avcodec_send_frame() CALL ===
07:26:07.113    ffmpeg_vid_codecs.c  ========================================
07:26:07.113    ffmpeg_vid_codecs.c    AVFrame basic fields:
07:26:07.113    ffmpeg_vid_codecs.c      avframe.format: 0
07:26:07.113    ffmpeg_vid_codecs.c      avframe.width: 640
07:26:07.113    ffmpeg_vid_codecs.c      avframe.height: 480
07:26:07.113    ffmpeg_vid_codecs.c      avframe.pts: 0
07:26:07.113    ffmpeg_vid_codecs.c      avframe.pkt_dts: 0
07:26:07.113    ffmpeg_vid_codecs.c      avframe.key_frame: 0
07:26:07.113    ffmpeg_vid_codecs.c      avframe.pict_type: 1
07:26:07.113    ffmpeg_vid_codecs.c    AVFrame data pointers:
07:26:07.113    ffmpeg_vid_codecs.c      avframe.data[0]: 0x7eccce3068
07:26:07.113    ffmpeg_vid_codecs.c      avframe.data[1]: 0x7eccd2e068
07:26:07.113    ffmpeg_vid_codecs.c      avframe.data[2]: 0x7eccd40c68
07:26:07.113    ffmpeg_vid_codecs.c      avframe.linesize[0]: 640
07:26:07.113    ffmpeg_vid_codecs.c      avframe.linesize[1]: 320
07:26:07.113    ffmpeg_vid_codecs.c      avframe.linesize[2]: 320
07:26:07.113    ffmpeg_vid_codecs.c    AVFrame buffer references:
07:26:07.113    ffmpeg_vid_codecs.c      avframe.buf[0]: (nil)
07:26:07.113    ffmpeg_vid_codecs.c      avframe.buf[1]: (nil)
07:26:07.113    ffmpeg_vid_codecs.c      avframe.buf[2]: (nil)
07:26:07.113    ffmpeg_vid_codecs.c      avframe.extended_buf: (nil)
07:26:07.113    ffmpeg_vid_codecs.c      avframe.nb_extended_buf: 0
07:26:07.113    ffmpeg_vid_codecs.c    AVFrame opaque fields (CRITICAL):
07:26:07.113    ffmpeg_vid_codecs.c      avframe.opaque: (nil)
07:26:07.113    ffmpeg_vid_codecs.c      avframe.opaque_ref: (nil)
07:26:07.113    ffmpeg_vid_codecs.c      ✅ avframe.opaque_ref is NULL (expected for freshmpp[1]: mpp_enc: set prep cfg w:h [640:480] stride [640:480] fmt 4 rotate 0 mirror 0
 frame)
07:26:07.113    ffmpeg_vid_codecs.c    AVFrame hw context:
07:26:07.113    ffmpeg_vid_codecs.c      avframe.hw_frames_ctx: (nil)
07:26:07.113    ffmpeg_vid_codecs.c    Encoder context state:
07:26:07.113    ffmpeg_vid_codecs.c      ff->enc_ctx: 0x7ecc015220
07:26:07.113    ffmpeg_vid_codecs.c      ff->enc_ctx->codec: 0x7f88ca9740
07:26:07.113    ffmpeg_vid_codecs.c      ff->enc_ctx->codec->name: h264_rkmpp
07:26:07.113    ffmpeg_vid_codecs.c      ff->enc_ctx->codec->id: 27
07:26:07.113    ffmpeg_vid_codecs.c      ff->enc_ctx->pix_fmt: 0
07:26:07.113    ffmpeg_vid_codecs.c      ff->enc_ctx->width: 640
07:26:07.113    ffmpeg_vid_codecs.c      ff->enc_ctx->height: 480
07:26:07.113    ffmpeg_vid_codecs.c      ff->enc_ctx->hw_frames_ctx: (nil)
07:26:07.113    ffmpeg_vid_codecs.c      ff->enc_ctx->hw_device_ctx: 0x7ecc0160d0
07:26:07.113    ffmpeg_vid_codecs.c    [CRITICAL] About to call avcodec_send_frame()...
07:26:07.113    ffmpeg_vid_codecs.c  [FIX 100.198 DIAG-4] DIAGNOSTIC COMPLETE
07:26:07.113    ffmpeg_vid_codecs.c  ========================================
07:26:07.113    ffmpeg_vid_codecs.c
07:26:07.113    ffmpeg_vid_codecs.c
07:26:07.113    ffmpeg_vid_codecs.c  ========================================
07:26:07.113    ffmpeg_vid_codecs.c  [FIX 100.200 DIAG-B] First encode - verifying encoder context
07:26:07.113    ffmpeg_vid_codecs.c  ========================================
07:26:07.113    ffmpeg_vid_codecs.c    ff->enc_ctx: 0x7ecc015220
07:26:07.113    ffmpeg_vid_codecs.c    ff->enc_ctx->priv_data: 0x7ecc0015e0
07:26:07.113    ffmpeg_vid_codecs.c    ff->enc->name: h264_rkmpp
07:26:07.113    ffmpeg_vid_codecs.c
07:26:07.113    ffmpeg_vid_codecs.c    🔍 Compare with DIAG-A:
07:26:07.113    ffmpeg_vid_codecs.c      - If addresses MATCH → encoder context is stable ✅
07:26:07.113    ffmpeg_vid_codecs.c      - If addresses DIFFER → PJSIP using wrong context ❌
07:26:07.113    ffmpeg_vid_codecs.c  [FIX 100.200 DIAG-B] COMPLETE
07:26:07.113    ffmpeg_vid_codecs.c  ========================================
07:26:07.113    ffmpeg_vid_codecs.c
07:26:07.113    ffmpeg_vid_codecs.c
07:26:07.113    ffmpeg_vid_codecs.c  ========================================
07:26:07.113    ffmpeg_vid_codecs.c  [FIX 100.210] Checking encoder threading mode
07:26:07.113    ffmpeg_vid_codecs.c  ========================================
07:26:07.113    ffmpeg_vid_codecs.c    ff->enc_ctx: 0x7ecc015220
07:26:07.113    ffmpeg_vid_codecs.c    ff->enc_ctx->internal: 0x7ecc62bcc0
07:26:07.113    ffmpeg_vid_codecs.c    ✅ internal structure exists
07:26:07.113    ffmpeg_vid_codecs.c
07:26:07.113    ffmpeg_vid_codecs.c    🔍 Checking encoding path:
07:26:07.113    ffmpeg_vid_codecs.c      avctx->thread_count: 1
07:26:07.113    ffmpeg_vid_codecs.c      avctx->thread_type: 3
07:26:07.113    ffmpeg_vid_codecs.c      avctx->active_thread_type: 0
07:26:07.113    ffmpeg_vid_codecs.c
07:26:07.113    ffmpeg_vid_codecs.c    ✅ Single-threaded path (expected)
07:26:07.113    ffmpeg_vid_codecs.c      active_thread_type & FF_THREAD_FRAME: NO
07:26:07.113    ffmpeg_vid_codecs.c      ✅ Main context should be initialized
07:26:07.113    ffmpeg_vid_codecs.c  [FIX 100.210] COMPLETE
07:26:07.113    ffmpeg_vid_codecs.c  ========================================
07:26:07.113    ffmpeg_vid_codecs.c
07:26:07.116    ffmpeg_vid_codecs.c  ❗❗❗ [CRITICAL] avcodec_send_frame() returned: 0
07:26:07.116    ffmpeg_vid_codecs.c  ⚠️ [FIX 100.43] Encoder returned EAGAIN (no output yet), size=0
07:26:07.116    ffmpeg_vid_codecs.c     This is normal for the first few frames (encoder buffering)
07:26:07.116     vstenc0x7ecc010680  🔍 [RTP SEND] Encode success: size=0, has_more=0, transport=0x55abb9dcb8
07:26:07.116             vid_conf.c  .Added video port 4 (qt_local_video_sink), port count=5
07:26:07.116             vid_conf.c  .Port 3 (USB camera: USB camera) transmitting to port 4 (qt_local_video_sink)
[DEBUG] 🎬 [FIRST LOCAL FRAME] Format: 640 x 480 @ 30 / 1 fps | Buffer size: 460800 bytes
[DEBUG] ✅ LocalVideoManager: Using Qt native YUV420P format for I420 video: 640 x 480
07:26:07.117                capdbuf  Buffer size adjusted from 2713 to 2011 (eff_cnt=1508)
[DEBUG] 📹 [VIDEO SINK ITEM] Received frame 1 size: 640 x 480 valid: true format: Format_YUV420P
[DEBUG] ✅ First video frame received: QSize(640, 480) from format: Format_YUV420P
[DEBUG] ✅ ItemHasContents enabled now that we have frames
[DEBUG] 📹 [PAINT NODE] Rendering frame 1 image: 640 x 480 item size: 744 x 236 has content: true
[DEBUG] 📹 [PAINT NODE] Created new texture node
[DEBUG] 📹 [PAINT NODE] Created texture from image: QSize(640, 480)
07:26:07.175                capdbuf  Buffer size adjusted from 2651 to 2049 (eff_cnt=1508)
07:26:07.219                capdbuf  Buffer size adjusted from 2689 to 2187 (eff_cnt=1508)
07:26:07.233                capdbuf  Buffer size adjusted from 2187 to 1443 (eff_cnt=1508)
07:26:07.244    ffmpeg_vid_codecs.c !🔍 [FIX 100.42 DIAG] AVFrame data population check:
07:26:07.244    ffmpeg_vid_codecs.c     plane_cnt=3
07:26:07.244    ffmpeg_vid_codecs.c     input->buf=0x7eccce3068, input->size=460800
07:26:07.244    ffmpeg_vid_codecs.c     Plane[0]: data=0x7eccce3068, linesize=640, bytes=307200
07:26:07.244    ffmpeg_vid_codecs.c     Plane[1]: data=0x7eccd2e068, linesize=320, bytes=76800
07:26:07.244    ffmpeg_vid_codecs.c     Plane[2]: data=0x7eccd40c68, linesize=320, bytes=76800
07:26:07.244    ffmpeg_vid_codecs.c  🔍 [FIX 100.42.2] After entering #if LIBAVCODEC_VER_AT_LEAST(58,0):
07:26:07.244    ffmpeg_vid_codecs.c     data[0]=0x7eccce3068, data[1]=0x7eccd2e068
07:26:07.246    ffmpeg_vid_codecs.c !🔍 [DIAG 66] === FIRST KEYFRAME ANALYSIS ===
07:26:07.246    ffmpeg_vid_codecs.c     Packet size: 9740
07:26:07.246    ffmpeg_vid_codecs.c     Packet flags: 0x1 (KEY=1)
07:26:07.246    ffmpeg_vid_codecs.c     Analyzing NAL units...
07:26:07.246    ffmpeg_vid_codecs.c     NAL#0 @ offset 0: type=7 nri=3 header=0x67
07:26:07.246    ffmpeg_vid_codecs.c     NAL#1 @ offset 27: type=8 nri=3 header=0x68
07:26:07.246    ffmpeg_vid_codecs.c     NAL#2 @ offset 35: type=5 nri=3 header=0x65
07:26:07.246    ffmpeg_vid_codecs.c     Total NAL units found: 3
07:26:07.246    ffmpeg_vid_codecs.c     Expected: SPS(7), PPS(8), SEI(6), IDR(5)
07:26:07.246     vstenc0x7ecc010680  🔍 [RTP SEND] Encode success: size=32, has_more=1, transport=0x55abb9dcb8
07:26:07.246     vstenc0x7ecc010680  🔍 [RTP SEND] About to send packet #0
07:26:07.246     vstenc0x7ecc010680     frame_out.size=32, transport=0x55abb9dcb8
07:26:07.246     vstenc0x7ecc010680  🔍 [RTP SEND] About to send packet #1
07:26:07.246     vstenc0x7ecc010680     frame_out.size=1304, transport=0x55abb9dcb8
07:26:07.246     vstenc0x7ecc010680  🔍 [RTP SEND] About to send packet #2
07:26:07.246     vstenc0x7ecc010680     frame_out.size=1304, transport=0x55abb9dcb8
07:26:07.246     vstenc0x7ecc010680  🔍 [RTP SEND] About to send packet #3
07:26:07.246     vstenc0x7ecc010680     frame_out.size=1304, transport=0x55abb9dcb8
07:26:07.246     vstenc0x7ecc010680  🔍 [RTP SEND] About to send packet #4
07:26:07.246     vstenc0x7ecc010680     frame_out.size=1304, transport=0x55abb9dcb8
07:26:07.320                capdbuf  Buffer size adjusted from 2723 to 1981 (eff_cnt=1508)
07:26:07.376    ffmpeg_vid_codecs.c !🔍 [FIX 100.42 DIAG] AVFrame data population check:
07:26:07.376    ffmpeg_vid_codecs.c     plane_cnt=3
07:26:07.376    ffmpeg_vid_codecs.c     input->buf=0x7eccce3068, input->size=460800
07:26:07.376    ffmpeg_vid_codecs.c     Plane[0]: data=0x7eccce3068, linesize=640, bytes=307200
07:26:07.376    ffmpeg_vid_codecs.c     Plane[1]: data=0x7eccd2e068, linesize=320, bytes=76800
07:26:07.376    ffmpeg_vid_codecs.c     Plane[2]: data=0x7eccd40c68, linesize=320, bytes=76800
07:26:07.376    ffmpeg_vid_codecs.c  🔍 [FIX 100.42.2] After entering #if LIBAVCODEC_VER_AT_LEAST(58,0):
07:26:07.376    ffmpeg_vid_codecs.c     data[0]=0x7eccce3068, data[1]=0x7eccd2e068
07:26:07.377     vstenc0x7ecc010680  🔍 [RTP SEND] Encode success: size=1304, has_more=1, transport=0x55abb9dcb8
07:26:07.378                capdbuf  Buffer size adjusted from 2621 to 2100 (eff_cnt=1508)
07:26:07.436                capdbuf  Buffer size adjusted from 2740 to 2185 (eff_cnt=1508)
07:26:07.451                capdbuf  Buffer size adjusted from 2185 to 1546 (eff_cnt=1508)
[DEBUG] 🔴 [HANGUP-DEBUG] RemoteVideoManager::destroyCustomPort() 开始
[DEBUG] 🔴 [HANGUP-DEBUG] m_customPort: 0x0
[DEBUG] 🔴 [HANGUP-DEBUG] m_customSlot: -1
[DEBUG] 🔴 [HANGUP-DEBUG] m_pool: 0x0
[DEBUG] 🔴 [HANGUP-DEBUG] m_customPort 已经为 NULL，跳过
[DEBUG] 🔴 [HANGUP-DEBUG] m_pool 已经为 NULL，跳过释放
[DEBUG] 🔴 [HANGUP-DEBUG] RemoteVideoManager::destroyCustomPort() 完成
[DEBUG] 🔴 [HANGUP-DEBUG] ═══════════════════════════════════════════
[DEBUG] ==========================================
[DEBUG] 🔍 [HARDWARE DECODER VERIFICATION]
[DEBUG] ==========================================
[DEBUG] 📹 Video Stream Info:
[DEBUG]    Port Name: "vstdec0x7ecc010680"
[DEBUG]    Format: 808596553
[DEBUG]    Resolution: 592 x 592
[DEBUG]    FPS: 45 / 1
[DEBUG]    Avg Bitrate: 110592000 bps
[DEBUG]    Max Bitrate: 110592000 bps
[DEBUG] 🔍 [HARDWARE DECODER VERIFICATION - REAL CHECK]
[DEBUG] ==========================================
[DEBUG] 📂 Method 1: Checking hardware device usage...
[DEBUG]    ⚠️ WARNING: No hardware decoder device detected
[DEBUG]    → Likely using SOFTWARE decoding (libx264)
[DEBUG]    → This will cause HIGH CPU usage
[DEBUG]
[DEBUG] ⚙️ Method 2: Checking CPU usage (baseline)...
[DEBUG]    ℹ️ Process CPU time (jiffies): 1266
[DEBUG]    ℹ️ Recommendation: Monitor CPU% during video call
[DEBUG]       - Hardware decoding: <20% CPU
[DEBUG]       - Software decoding: >60% CPU
[DEBUG]
[DEBUG] 📋 Method 3: Enable FFmpeg debug logs to see actual decoder
[DEBUG]    Run with environment variable:
[DEBUG]    export AV_LOG_FORCE_NOCOLOR=1
[DEBUG]    export AV_LOG_LEVEL=info
[DEBUG]    Then check logs for lines like:
[DEBUG]    → '[h264 @ 0x...] decoder: h264_v4l2m2m' (HARDWARE)
[DEBUG]    → '[h264 @ 0x...] decoder: h264' (SOFTWARE)
[DEBUG] ==========================================
[DEBUG] ==========================================
[DEBUG] ✅ Creating custom port with default format (640x360 @ 30fps)
[DEBUG] ✅ Custom pjmedia_port created for Qt video sink: 640 x 360 @ 60 / 1 fps
[DEBUG] ✅ Call video slot: 1
07:26:07.472             vid_conf.c  Add video port 5 (qt_remote_video_sink) queued
[DEBUG] ✅ Custom port added to vid conf, slot: 5
07:26:07.472             vid_conf.c  .Connect video ports 1->5 queued
[DEBUG] ✅ Connected call video slot 1 -> custom slot 5
[DEBUG] 🎉 RemoteVideoManager: Event-driven Push mode activated!
[DEBUG] 🔧 [Attempt 22] Hiding all PJSIP SDL video windows...
[DEBUG] ℹ️ [Attempt 22] No SDL windows found to hide
[DEBUG] ✅ [Attempt 24] Connected to video bridge (Push mode)
[DEBUG] 🔄 [Attempt 24] Reconnected to video bridge after SDP renegotiation
07:26:07.480                capdbuf  Buffer size adjusted from 2186 to 1521 (eff_cnt=1508)
07:26:07.512    ffmpeg_vid_codecs.c !🔍 [FIX 100.42.2] After entering #if LIBAVCODEC_VER_AT_LEAST(58,0):
07:26:07.512    ffmpeg_vid_codecs.c     data[0]=0x7eccce3068, data[1]=0x7eccd2e068
07:26:07.513     vstenc0x7ecc010680  🔍 [RTP SEND] Encode success: size=1304, has_more=1, transport=0x55abb9dcb8
07:26:07.513             vid_conf.c  .Added video port 5 (qt_remote_video_sink), port count=6
07:26:07.513             vid_conf.c  .Port 1 (vstdec0x7ecc010680) transmitting to port 5 (qt_remote_video_sink)
[DEBUG] 🎯 [PJSIP CALLBACK] First put_frame call
07:26:07.538                capdbuf  Buffer size adjusted from 2161 to 1477 (eff_cnt=1508)
07:26:07.639                capdbuf  Buffer size adjusted from 2757 to 2079 (eff_cnt=1508)
07:26:07.644    ffmpeg_vid_codecs.c !🔍 [FIX 100.42.2] After entering #if LIBAVCODEC_VER_AT_LEAST(58,0):
07:26:07.644    ffmpeg_vid_codecs.c     data[0]=0x7eccce3068, data[1]=0x7eccd2e068
07:26:07.645     vstenc0x7ecc010680  🔍 [RTP SEND] Encode success: size=1304, has_more=1, transport=0x55abb9dcb8
07:26:07.698                capdbuf  Buffer size adjusted from 2719 to 1919 (eff_cnt=1508)
07:26:07.717    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:07.717    ffmpeg_vid_codecs.c  🔍 [FIX 76 FORMAT] Decoded frame format: 23 (NV12)
07:26:07.717    ffmpeg_vid_codecs.c  🔍 [FIX 100.27 DIAG] Before memcpy: output->buf=0x7ecc72e368, output_buf_len=1401856, vafp->framebytes=460800
07:26:07.717    ffmpeg_vid_codecs.c     plane_cnt=2, dec_vfi=0x55729b7a00
07:26:07.718    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:07.756                capdbuf  Buffer size adjusted from 2559 to 2117 (eff_cnt=1508)
07:26:07.776    ffmpeg_vid_codecs.c !🔍 [FIX 100.42.2] After entering #if LIBAVCODEC_VER_AT_LEAST(58,0):
07:26:07.776    ffmpeg_vid_codecs.c     data[0]=0x7eccce3068, data[1]=0x7eccd2e068
07:26:07.794     vstenc0x7ecc010680 !🔍 [RTP SEND] Encode success: size=1304, has_more=1, transport=0x55abb9dcb8
07:26:07.795     vstdec0x7ecc010680   Decoding format changed: 640x480 NV12<- 30/1(~30)fps
07:26:07.795             vid_conf.c  .Update video port 1 queued
07:26:07.795             vid_conf.c  .Update video port 0 queued
07:26:07.795             vid_conf.c !Port 1 (vstdec0x7ecc010680): updated frame rate 45 -> 30
07:26:07.796             vid_conf.c  Port 1 (vstdec0x7ecc010680): updated frame size 592x592 -> 640x480
07:26:07.796             vid_conf.c  Video port 1 updated
07:26:07.797              sdl_dev.c  Stopping sdl video stream
07:26:07.799                capdbuf  Buffer size adjusted from 2757 to 1947 (eff_cnt=1508)
07:26:07.857                capdbuf  Buffer size adjusted from 2587 to 2187 (eff_cnt=1508)
07:26:07.872                capdbuf  Buffer size adjusted from 2187 to 1550 (eff_cnt=1508)
07:26:07.879    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:07.879    ffmpeg_vid_codecs.c  🔍 [FIX 76 FORMAT] Decoded frame format: 23 (NV12)
07:26:07.879    ffmpeg_vid_codecs.c  🔍 [FIX 100.27 DIAG] Before memcpy: output->buf=0x7ecc72e368, output_buf_len=1401856, vafp->framebytes=460800
07:26:07.879    ffmpeg_vid_codecs.c     plane_cnt=2, dec_vfi=0x55729b7a00
07:26:07.880    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:07.880              sdl_dev.c !Starting sdl video stream
07:26:07.912    ffmpeg_vid_codecs.c !🔍 [FIX 100.42.2] After entering #if LIBAVCODEC_VER_AT_LEAST(58,0):
07:26:07.912    ffmpeg_vid_codecs.c     data[0]=0x7eccce3068, data[1]=0x7eccd2e068
07:26:07.912     vstenc0x7ecc010680  🔍 [RTP SEND] Encode success: size=1304, has_more=1, transport=0x55abb9dcb8
07:26:07.913             vid_conf.c  .Video port 1 updated
07:26:07.913             vid_conf.c  .Port 0 (SDL renderer): updated frame size 592x592 -> 640x480
07:26:07.913             vid_conf.c  .Video port 0 updated
07:26:07.913     vstdec0x7ecc010680   Decoding format changed: 640x480 NV12<- 30/1(~30)fps
07:26:07.913             vid_conf.c  .Update video port 1 queued
07:26:07.913             vid_conf.c  .Update video port 0 queued
07:26:07.914              sdl_dev.c !Stopping sdl video stream
07:26:07.914              sdl_dev.c  Starting sdl video stream
07:26:07.915                capdbuf  Buffer size adjusted from 2190 to 1498 (eff_cnt=1508)
07:26:07.924    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:07.924    ffmpeg_vid_codecs.c  🔍 [FIX 76 FORMAT] Decoded frame format: 23 (NV12)
07:26:07.924    ffmpeg_vid_codecs.c  🔍 [FIX 100.27 DIAG] Before memcpy: output->buf=0x7ecc72e368, output_buf_len=1401856, vafp->framebytes=460800
07:26:07.924    ffmpeg_vid_codecs.c     plane_cnt=2, dec_vfi=0x55729b7a00
07:26:07.924    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:07.972             alsa_dev.c !✅ [FIX 100.247 DEBUG] Capture stats: total=801, success=801, errors=0, frames_read=320
07:26:07.973             alsa_dev.c  🎤 [AUDIO DATA] Silent: NO ✅, Non-zero samples: 640/640 (100.0%), Max amplitude: 32768
07:26:07.974    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:07.974    ffmpeg_vid_codecs.c  🔍 [FIX 76 FORMAT] Decoded frame format: 23 (NV12)
07:26:07.974    ffmpeg_vid_codecs.c  🔍 [FIX 100.27 DIAG] Before memcpy: output->buf=0x7ecc72e368, output_buf_len=1401856, vafp->framebytes=460800
07:26:07.974    ffmpeg_vid_codecs.c     plane_cnt=2, dec_vfi=0x55729b7a00
07:26:07.974    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:08.017                capdbuf  Buffer size adjusted from 2778 to 2013 (eff_cnt=1508)
07:26:08.065    ffmpeg_vid_codecs.c !🔍 [FIX 100.42.2] After entering #if LIBAVCODEC_VER_AT_LEAST(58,0):
07:26:08.065    ffmpeg_vid_codecs.c     data[0]=0x7eccce3068, data[1]=0x7eccd2e068
07:26:08.066     vstenc0x7ecc010680  🔍 [RTP SEND] Encode success: size=1304, has_more=1, transport=0x55abb9dcb8
[DEBUG] 🎬 [FIRST FRAME] Port format: 640 x 360 @ 60 / 1 fps | Frame buffer size: 345600 bytes | Format ID: 30323449
07:26:08.066             vid_conf.c  .Video port 1 updated
07:26:08.066             vid_conf.c  .Video port 0 updated
07:26:08.068    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:08.068    ffmpeg_vid_codecs.c  🔍 [FIX 76 FORMAT] Decoded frame format: 23 (NV12)
07:26:08.068    ffmpeg_vid_codecs.c  🔍 [FIX 100.27 DIAG] Before memcpy: output->buf=0x7ecc72e368, output_buf_len=1401856, vafp->framebytes=460800
07:26:08.068    ffmpeg_vid_codecs.c     plane_cnt=2, dec_vfi=0x55729b7a00
07:26:08.068    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
[DEBUG] 📹 [DISPLAY FRAME] Presenting to QVideoSink: frame 1 size: 640 x 360 valid: true m_videoSink: QVideoSink(0x55a8d007f0)
[DEBUG] ✅ First video frame received: QSize(640, 360) from format: Format_YUV420P
[DEBUG] ✅ ItemHasContents enabled now that we have frames
07:26:08.075                capdbuf  Buffer size adjusted from 2653 to 1951 (eff_cnt=1508)
07:26:08.082     vstdec0x7ecc010680 ! Decoding format changed: 640x480 NV12<- 30/1(~30)fps
07:26:08.082             vid_conf.c  .Update video port 1 queued
07:26:08.082             vid_conf.c  .Update video port 0 queued
07:26:08.082              sdl_dev.c !Stopping sdl video stream
07:26:08.082              sdl_dev.c  Starting sdl video stream
[DEBUG] 📹 [PAINT NODE] Created new texture node
07:26:08.118                capdbuf  Buffer size adjusted from 2591 to 2133 (eff_cnt=1508)
07:26:08.132    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:08.133    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:08.133                capdbuf  Buffer size adjusted from 2133 to 1367 (eff_cnt=1452)
07:26:08.176    ffmpeg_vid_codecs.c !🔍 [FIX 100.42.2] After entering #if LIBAVCODEC_VER_AT_LEAST(58,0):
07:26:08.176    ffmpeg_vid_codecs.c     data[0]=0x7eccce3068, data[1]=0x7eccd2e068
07:26:08.177     vstenc0x7ecc010680  🔍 [RTP SEND] Encode success: size=1304, has_more=1, transport=0x55abb9dcb8
07:26:08.177             vid_conf.c  .Video port 1 updated
07:26:08.177             vid_conf.c  .Video port 0 updated
07:26:08.182    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:08.182    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
[DEBUG] 🎯 [LOCAL PUSH] Video frames: 8 | Non-video: 0 | Total callbacks: 9
[DEBUG] 📤 [LOCAL VIDEO SEND] FPS: "8.4" | Avg interval: "133.6" ms | Total frames: 9
07:26:08.186     vstdec0x7ecc010680 ! Decoding format changed: 640x480 NV12<- 30/1(~30)fps
07:26:08.186             vid_conf.c  .Update video port 1 queued
07:26:08.186             vid_conf.c  .Update video port 0 queued
07:26:08.186              sdl_dev.c !Stopping sdl video stream
07:26:08.186              sdl_dev.c  Starting sdl video stream
07:26:08.229    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:08.229    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:08.234                capdbuf  Buffer size adjusted from 2647 to 2127 (eff_cnt=1452)
07:26:08.249                capdbuf  Buffer size adjusted from 2127 to 1265 (eff_cnt=1452)
07:26:08.312    ffmpeg_vid_codecs.c  🔍 [FIX 100.42.2] After entering #if LIBAVCODEC_VER_AT_LEAST(58,0):
07:26:08.312    ffmpeg_vid_codecs.c     data[0]=0x7eccce3068, data[1]=0x7eccd2e068
07:26:08.313     vstenc0x7ecc010680  🔍 [RTP SEND] Encode success: size=1304, has_more=1, transport=0x55abb9dcb8
07:26:08.313             vid_conf.c  .Video port 1 updated
07:26:08.313             vid_conf.c  .Video port 0 updated
07:26:08.314     vstdec0x7ecc010680   Decoding format changed: 640x480 NV12<- 30/1(~30)fps
07:26:08.314             vid_conf.c  .Update video port 1 queued
07:26:08.314             vid_conf.c  .Update video port 0 queued
07:26:08.314              sdl_dev.c !Stopping sdl video stream
07:26:08.315              sdl_dev.c  Starting sdl video stream
07:26:08.325    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:08.325    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
[DEBUG] 📹 [VIDEO SINK ITEM] Received frame 16 size: 640 x 360 valid: true format: Format_YUV420P
07:26:08.336                capdbuf  Buffer size adjusted from 2545 to 2149 (eff_cnt=1452)
07:26:08.351                capdbuf  Buffer size adjusted from 2149 to 1477 (eff_cnt=1452)
07:26:08.372    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:08.372    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:08.380                capdbuf  Buffer size adjusted from 2117 to 1350 (eff_cnt=1452)
07:26:08.444    ffmpeg_vid_codecs.c  🔍 [FIX 100.42.2] After entering #if LIBAVCODEC_VER_AT_LEAST(58,0):
07:26:08.444    ffmpeg_vid_codecs.c     data[0]=0x7eccce3068, data[1]=0x7eccd2e068
07:26:08.445     vstenc0x7ecc010680  🔍 [RTP SEND] Encode success: size=32, has_more=1, transport=0x55abb9dcb8
07:26:08.445             vid_conf.c  .Video port 1 updated
07:26:08.445             vid_conf.c  .Video port 0 updated
07:26:08.457     vstdec0x7ecc010680 ! Decoding format changed: 640x480 NV12<- 30/1(~30)fps
07:26:08.457             vid_conf.c  .Update video port 1 queued
07:26:08.457             vid_conf.c  .Update video port 0 queued
07:26:08.457              sdl_dev.c !Stopping sdl video stream
07:26:08.458              sdl_dev.c  Starting sdl video stream
[DEBUG] 📹 [PAINT NODE] Rendering frame 16 image: 640 x 360 item size: 367 x 236 has content: true
[DEBUG] 📹 [PAINT NODE] Created texture from image: QSize(640, 360)
07:26:08.483    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:08.484    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:08.496                capdbuf  Buffer size adjusted from 2630 to 1862 (eff_cnt=1452)
07:26:08.539                capdbuf  Buffer size adjusted from 2502 to 1980 (eff_cnt=1452)
07:26:08.575    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:08.575    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:08.576    ffmpeg_vid_codecs.c !🔍 [FIX 100.42.2] After entering #if LIBAVCODEC_VER_AT_LEAST(58,0):
07:26:08.576    ffmpeg_vid_codecs.c     data[0]=0x7eccce3068, data[1]=0x7eccd2e068
07:26:08.576     vstenc0x7ecc010680  🔍 [RTP SEND] Encode success: size=32, has_more=1, transport=0x55abb9dcb8
[DEBUG] 🎯 [PJSIP CALLBACK FPS] "14.1" | Total callbacks: 15 | Video frames: 8 | Non-video: 0 | Empty: 6 | Elapsed: 1064 ms
07:26:08.577             vid_conf.c  .Video port 1 updated
07:26:08.577             vid_conf.c  .Video port 0 updated
07:26:08.578     vstdec0x7ecc010680   Decoding format changed: 640x480 NV12<- 30/1(~30)fps
07:26:08.578             vid_conf.c  .Update video port 1 queued
07:26:08.578             vid_conf.c  .Update video port 0 queued
07:26:08.578              sdl_dev.c !Stopping sdl video stream
07:26:08.578              sdl_dev.c  Starting sdl video stream
07:26:08.583    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:08.584    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:08.597                capdbuf  Buffer size adjusted from 2620 to 2161 (eff_cnt=1452)
07:26:08.612                capdbuf  Buffer size adjusted from 2161 to 1352 (eff_cnt=1452)
07:26:08.627    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:08.627    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:08.699                capdbuf  Buffer size adjusted from 2632 to 2072 (eff_cnt=1452)
07:26:08.712    ffmpeg_vid_codecs.c !🔍 [FIX 100.42.2] After entering #if LIBAVCODEC_VER_AT_LEAST(58,0):
07:26:08.712    ffmpeg_vid_codecs.c     data[0]=0x7eccce3068, data[1]=0x7eccd2e068
07:26:08.713     vstenc0x7ecc010680  🔍 [RTP SEND] Encode success: size=1304, has_more=1, transport=0x55abb9dcb8
07:26:08.713             vid_conf.c !.Video port 1 updated
07:26:08.713             vid_conf.c  .Video port 0 updated
07:26:08.720     vstdec0x7ecc010680   Decoding format changed: 640x480 NV12<- 30/1(~30)fps
07:26:08.720             vid_conf.c  .Update video port 1 queued
07:26:08.720             vid_conf.c  .Update video port 0 queued
07:26:08.721              sdl_dev.c !Stopping sdl video stream
07:26:08.721              sdl_dev.c  Starting sdl video stream
07:26:08.726    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:08.726    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:08.757                capdbuf  Buffer size adjusted from 2712 to 2012 (eff_cnt=1452)
07:26:08.773    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:08.773    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:08.800                capdbuf  Buffer size adjusted from 2652 to 2163 (eff_cnt=1452)
07:26:08.815                capdbuf  Buffer size adjusted from 2163 to 1425 (eff_cnt=1452)
07:26:08.835    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:08.835    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:08.844    ffmpeg_vid_codecs.c !🔍 [FIX 100.42.2] After entering #if LIBAVCODEC_VER_AT_LEAST(58,0):
07:26:08.844    ffmpeg_vid_codecs.c     data[0]=0x7eccce3068, data[1]=0x7eccd2e068
07:26:08.844     vstenc0x7ecc010680  🔍 [RTP SEND] Encode success: size=1304, has_more=1, transport=0x55abb9dcb8
07:26:08.845             vid_conf.c  .Video port 1 updated
07:26:08.845             vid_conf.c  .Video port 0 updated
07:26:08.861     vstdec0x7ecc010680 ! Decoding format changed: 640x480 NV12<- 30/1(~30)fps
07:26:08.861             vid_conf.c  .Update video port 1 queued
07:26:08.861             vid_conf.c  .Update video port 0 queued
07:26:08.862              sdl_dev.c !Stopping sdl video stream
07:26:08.862              sdl_dev.c  Starting sdl video stream
07:26:08.917                capdbuf  Buffer size adjusted from 2705 to 1909 (eff_cnt=1452)
07:26:08.930    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:08.931    ffmpeg_vid_codecs.c !✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:08.975                capdbuf  Buffer size adjusted from 2549 to 2077 (eff_cnt=1452)
07:26:08.976    ffmpeg_vid_codecs.c !🔍 [FIX 100.42.2] After entering #if LIBAVCODEC_VER_AT_LEAST(58,0):
07:26:08.976    ffmpeg_vid_codecs.c     data[0]=0x7eccce3068, data[1]=0x7eccd2e068
07:26:08.976     vstenc0x7ecc010680  🔍 [RTP SEND] Encode success: size=1304, has_more=1, transport=0x55abb9dcb8
07:26:08.977             vid_conf.c  .Video port 1 updated
07:26:08.977             vid_conf.c  .Video port 0 updated
07:26:08.984     vstdec0x7ecc010680   Decoding format changed: 640x480 NV12<- 30/1(~30)fps
07:26:08.984             vid_conf.c  .Update video port 1 queued
07:26:08.984             vid_conf.c  .Update video port 0 queued
07:26:08.984              sdl_dev.c !Stopping sdl video stream
07:26:08.984              sdl_dev.c  Starting sdl video stream
07:26:08.989    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:08.990    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
[DEBUG] 📹 [DISPLAY FRAME] Presenting to QVideoSink: frame 16 size: 640 x 360 valid: true m_videoSink: QVideoSink(0x55a8d007f0)
[DEBUG] 📹 [VIDEO SINK ITEM] Received frame 31 size: 640 x 360 valid: true format: Format_YUV420P
07:26:09.018                capdbuf  Buffer size adjusted from 2717 to 2125 (eff_cnt=1452)
07:26:09.028    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:09.028    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:09.033                capdbuf  Buffer size adjusted from 2125 to 1559 (eff_cnt=1452)
07:26:09.076                capdbuf  Buffer size adjusted from 2199 to 1495 (eff_cnt=1452)
07:26:09.112    ffmpeg_vid_codecs.c !🔍 [FIX 100.42.2] After entering #if LIBAVCODEC_VER_AT_LEAST(58,0):
07:26:09.112    ffmpeg_vid_codecs.c     data[0]=0x7eccce3068, data[1]=0x7eccd2e068
07:26:09.112     vstenc0x7ecc010680  🔍 [RTP SEND] Encode success: size=1304, has_more=1, transport=0x55abb9dcb8
[DEBUG] 📊 [REMOTE VIDEO PUSH] Enqueued FPS: "16.2" | Avg interval: "65.4" ms | Avg copy time: "0.06" ms | Total frames: 17 ""
[DEBUG] 🔧 [ASYNC WORKER] Processed FPS: "16.3" | Last convert time: 0 ms | Queue size: 0
07:26:09.113             vid_conf.c  .Video port 1 updated
07:26:09.113             vid_conf.c  .Video port 0 updated
07:26:09.114     vstdec0x7ecc010680   Decoding format changed: 640x480 NV12<- 30/1(~30)fps
07:26:09.114             vid_conf.c  .Update video port 1 queued
07:26:09.114             vid_conf.c  .Update video port 0 queued
07:26:09.114              sdl_dev.c !Stopping sdl video stream
07:26:09.114              sdl_dev.c  Starting sdl video stream
07:26:09.134                capdbuf  Buffer size adjusted from 2135 to 1436 (eff_cnt=1452)
07:26:09.142    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:09.142    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:09.189    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:09.189    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:09.236                capdbuf  Buffer size adjusted from 2716 to 2190 (eff_cnt=1452)
07:26:09.237    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:09.237    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:09.244    ffmpeg_vid_codecs.c !🔍 [FIX 100.42.2] After entering #if LIBAVCODEC_VER_AT_LEAST(58,0):
07:26:09.244    ffmpeg_vid_codecs.c     data[0]=0x7eccce3068, data[1]=0x7eccd2e068
07:26:09.244     vstenc0x7ecc010680  🔍 [RTP SEND] Encode success: size=1153, has_more=0, transport=0x55abb9dcb8
07:26:09.245             vid_conf.c  .Video port 1 updated
07:26:09.245             vid_conf.c  .Video port 0 updated
07:26:09.250                capdbuf  Buffer size adjusted from 2190 to 1449 (eff_cnt=1452)
[DEBUG] 🎯 [LOCAL PUSH] Video frames: 8 | Non-video: 0 | Total callbacks: 17
[DEBUG] 📤 [LOCAL VIDEO SEND] FPS: "7.5" | Avg interval: "133.6" ms | Total frames: 17
07:26:09.255     vstdec0x7ecc010680 ! Decoding format changed: 640x480 NV12<- 30/1(~30)fps
07:26:09.255             vid_conf.c  .Update video port 1 queued
07:26:09.255             vid_conf.c  .Update video port 0 queued
07:26:09.255              sdl_dev.c !Stopping sdl video stream
07:26:09.255              sdl_dev.c  Starting sdl video stream
07:26:09.281    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:09.281    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:09.337                capdbuf  Buffer size adjusted from 2729 to 2113 (eff_cnt=1452)
07:26:09.352                capdbuf  Buffer size adjusted from 2113 to 1417 (eff_cnt=1452)
07:26:09.376    ffmpeg_vid_codecs.c !🔍 [FIX 100.42.2] After entering #if LIBAVCODEC_VER_AT_LEAST(58,0):
07:26:09.376    ffmpeg_vid_codecs.c     data[0]=0x7eccce3068, data[1]=0x7eccd2e068
07:26:09.376     vstenc0x7ecc010680  🔍 [RTP SEND] Encode success: size=1304, has_more=1, transport=0x55abb9dcb8
07:26:09.377             vid_conf.c  .Video port 1 updated
07:26:09.377             vid_conf.c  .Video port 0 updated
07:26:09.377     vstdec0x7ecc010680   Decoding format changed: 640x480 NV12<- 30/1(~30)fps
07:26:09.377             vid_conf.c  .Update video port 1 queued
07:26:09.377             vid_conf.c  .Update video port 0 queued
07:26:09.378              sdl_dev.c !Stopping sdl video stream
07:26:09.378              sdl_dev.c  Starting sdl video stream
07:26:09.381    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:09.381    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
[DEBUG] 📹 [PAINT NODE] Rendering frame 31 image: 640 x 480 item size: 368 x 236 has content: true
[DEBUG] 📹 [PAINT NODE] Created texture from image: QSize(640, 480)
07:26:09.424             alsa_dev.c  ✅ [FIX 100.247 DEBUG] Capture stats: total=901, success=901, errors=0, frames_read=320
07:26:09.424             alsa_dev.c  🎤 [AUDIO DATA] Silent: NO ✅, Non-zero samples: 640/640 (100.0%), Max amplitude: 8400
07:26:09.425    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:09.425    ffmpeg_vid_codecs.c !✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:09.439                capdbuf  Buffer size adjusted from 2697 to 1995 (eff_cnt=1452)
07:26:09.493    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:09.493    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:09.497                capdbuf  Buffer size adjusted from 2635 to 2024 (eff_cnt=1452)
07:26:09.512    ffmpeg_vid_codecs.c !🔍 [FIX 100.42.2] After entering #if LIBAVCODEC_VER_AT_LEAST(58,0):
07:26:09.512    ffmpeg_vid_codecs.c     data[0]=0x7eccce3068, data[1]=0x7eccd2e068
07:26:09.512     vstenc0x7ecc010680  🔍 [RTP SEND] Encode success: size=1304, has_more=1, transport=0x55abb9dcb8
07:26:09.513             vid_conf.c  .Video port 1 updated
07:26:09.513             vid_conf.c  .Video port 0 updated
07:26:09.529     vstdec0x7ecc010680 ! Decoding format changed: 640x480 NV12<- 30/1(~30)fps
07:26:09.529             vid_conf.c  .Update video port 1 queued
07:26:09.529             vid_conf.c  .Update video port 0 queued
07:26:09.529              sdl_dev.c !Stopping sdl video stream
07:26:09.530              sdl_dev.c  Starting sdl video stream
07:26:09.555                capdbuf  Buffer size adjusted from 2664 to 2047 (eff_cnt=1452)
07:26:09.589    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:09.589    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:09.599                capdbuf  Buffer size adjusted from 2687 to 1921 (eff_cnt=1452)
07:26:09.636    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:09.637    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:09.644    ffmpeg_vid_codecs.c  🔍 [FIX 100.42.2] After entering #if LIBAVCODEC_VER_AT_LEAST(58,0):
07:26:09.644    ffmpeg_vid_codecs.c     data[0]=0x7eccce3068, data[1]=0x7eccd2e068
07:26:09.644     vstenc0x7ecc010680  🔍 [RTP SEND] Encode success: size=1304, has_more=1, transport=0x55abb9dcb8
[DEBUG] 🎯 [PJSIP CALLBACK FPS] "14.5" | Total callbacks: 31 | Video frames: 24 | Non-video: 0 | Empty: 6 | Elapsed: 2132 ms
07:26:09.645             vid_conf.c  .Video port 1 updated
07:26:09.645             vid_conf.c  .Video port 0 updated
07:26:09.645     vstdec0x7ecc010680   Decoding format changed: 640x480 NV12<- 30/1(~30)fps
07:26:09.646             vid_conf.c  .Update video port 1 queued
07:26:09.646             vid_conf.c  .Update video port 0 queued
[DEBUG] 📹 [VIDEO SINK ITEM] Received frame 46 size: 640 x 360 valid: true format: Format_YUV420P
07:26:09.657                capdbuf  Buffer size adjusted from 2561 to 1963 (eff_cnt=1452)
07:26:09.684    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:09.684    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:09.700                capdbuf  Buffer size adjusted from 2603 to 1688 (eff_cnt=1452)
07:26:09.758                capdbuf  Buffer size adjusted from 2328 to 1986 (eff_cnt=1452)
07:26:09.776    ffmpeg_vid_codecs.c  🔍 [FIX 100.42.2] After entering #if LIBAVCODEC_VER_AT_LEAST(58,0):
07:26:09.776    ffmpeg_vid_codecs.c     data[0]=0x7eccce3068, data[1]=0x7eccd2e068
07:26:09.776     vstenc0x7ecc010680  🔍 [RTP SEND] Encode success: size=32, has_more=1, transport=0x55abb9dcb8
07:26:09.777             vid_conf.c  .Video port 1 updated
07:26:09.777             vid_conf.c  .Video port 0 updated
07:26:09.777              sdl_dev.c  Stopping sdl video stream
07:26:09.777              sdl_dev.c  Starting sdl video stream
07:26:09.786     vstdec0x7ecc010680 ! Decoding format changed: 640x480 NV12<- 30/1(~30)fps
07:26:09.786             vid_conf.c  .Update video port 1 queued
07:26:09.786             vid_conf.c  .Update video port 0 queued
07:26:09.786              sdl_dev.c !Stopping sdl video stream
07:26:09.786              sdl_dev.c  Starting sdl video stream
07:26:09.796    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:09.797    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:09.816                capdbuf  Buffer size adjusted from 2626 to 2092 (eff_cnt=1410)
07:26:09.831                capdbuf  Buffer size adjusted from 2092 to 1452 (eff_cnt=1410)
07:26:09.844    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:09.845    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:09.860                capdbuf  Buffer size adjusted from 2092 to 1374 (eff_cnt=1410)
07:26:09.891    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:09.891    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:09.912    ffmpeg_vid_codecs.c !🔍 [FIX 100.42.2] After entering #if LIBAVCODEC_VER_AT_LEAST(58,0):
07:26:09.912    ffmpeg_vid_codecs.c     data[0]=0x7eccce3068, data[1]=0x7eccd2e068
07:26:09.912     vstenc0x7ecc010680  🔍 [RTP SEND] Encode success: size=32, has_more=1, transport=0x55abb9dcb8
07:26:09.913             vid_conf.c  .Video port 1 updated
07:26:09.913             vid_conf.c  .Video port 0 updated
07:26:09.913     vstdec0x7ecc010680   Decoding format changed: 640x480 NV12<- 30/1(~30)fps
07:26:09.913             vid_conf.c  .Update video port 1 queued
07:26:09.913             vid_conf.c  .Update video port 0 queued
07:26:09.914              sdl_dev.c !Stopping sdl video stream
07:26:09.914              sdl_dev.c  Starting sdl video stream
07:26:09.976                capdbuf  Buffer size adjusted from 2654 to 2139 (eff_cnt=1410)
07:26:09.989    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:09.989    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:09.990                capdbuf  Buffer size adjusted from 2139 to 1312 (eff_cnt=1410)
07:26:10.037    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:10.037    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:10.044    ffmpeg_vid_codecs.c !🔍 [FIX 100.42.2] After entering #if LIBAVCODEC_VER_AT_LEAST(58,0):
07:26:10.044    ffmpeg_vid_codecs.c     data[0]=0x7eccce3068, data[1]=0x7eccd2e068
07:26:10.044     vstenc0x7ecc010680  🔍 [RTP SEND] Encode success: size=1304, has_more=1, transport=0x55abb9dcb8
07:26:10.045             vid_conf.c  .Video port 1 updated
07:26:10.045             vid_conf.c  .Video port 0 updated
[DEBUG] 📹 [DISPLAY FRAME] Presenting to QVideoSink: frame 31 size: 640 x 360 valid: true m_videoSink: QVideoSink(0x55a8d007f0)
07:26:10.056     vstdec0x7ecc010680 ! Decoding format changed: 640x480 NV12<- 30/1(~30)fps
07:26:10.056             vid_conf.c  .Update video port 1 queued
07:26:10.056             vid_conf.c  .Update video port 0 queued
07:26:10.056              sdl_dev.c !Stopping sdl video stream
07:26:10.056              sdl_dev.c  Starting sdl video stream
07:26:10.078                capdbuf  Buffer size adjusted from 2592 to 2062 (eff_cnt=1410)
07:26:10.084    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:10.084    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:10.092                capdbuf  Buffer size adjusted from 2062 to 1296 (eff_cnt=1410)
07:26:10.148    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:10.148    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:10.176    ffmpeg_vid_codecs.c !🔍 [FIX 100.42.2] After entering #if LIBAVCODEC_VER_AT_LEAST(58,0):
07:26:10.176    ffmpeg_vid_codecs.c     data[0]=0x7eccce3068, data[1]=0x7eccd2e068
07:26:10.176     vstenc0x7ecc010680  🔍 [RTP SEND] Encode success: size=1304, has_more=1, transport=0x55abb9dcb8
[DEBUG] 📊 [REMOTE VIDEO PUSH] Enqueued FPS: "15.0" | Avg interval: "66.5" ms | Avg copy time: "0.06" ms | Total frames: 33 ""
07:26:10.177             vid_conf.c  .Video port 1 updated
07:26:10.177             vid_conf.c  .Video port 0 updated
[DEBUG] 🔧 [ASYNC WORKER] Processed FPS: "15.6" | Last convert time: 0 ms | Queue size: 0
07:26:10.177     vstdec0x7ecc010680   Decoding format changed: 640x480 NV12<- 30/1(~30)fps
07:26:10.177             vid_conf.c  .Update video port 1 queued
07:26:10.177             vid_conf.c  .Update video port 0 queued
07:26:10.178              sdl_dev.c !Stopping sdl video stream
07:26:10.178              sdl_dev.c  Starting sdl video stream
[DEBUG] 📹 [PAINT NODE] Rendering frame 46 image: 640 x 480 item size: 368 x 236 has content: true
[DEBUG] 📹 [PAINT NODE] Created texture from image: QSize(640, 480)
07:26:10.194                capdbuf  Buffer size adjusted from 2576 to 1982 (eff_cnt=1410)
07:26:10.237                capdbuf  Buffer size adjusted from 2622 to 2058 (eff_cnt=1410)
07:26:10.245    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:10.245    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:10.252                capdbuf  Buffer size adjusted from 2058 to 1354 (eff_cnt=1410)
07:26:10.291    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:10.291    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:10.312    ffmpeg_vid_codecs.c !🔍 [FIX 100.42.2] After entering #if LIBAVCODEC_VER_AT_LEAST(58,0):
07:26:10.312    ffmpeg_vid_codecs.c     data[0]=0x7eccce3068, data[1]=0x7eccd2e068
07:26:10.312     vstenc0x7ecc010680  🔍 [RTP SEND] Encode success: size=1304, has_more=1, transport=0x55abb9dcb8
07:26:10.313             vid_conf.c  .Video port 1 updated
07:26:10.313             vid_conf.c  .Video port 0 updated
[DEBUG] 🎯 [LOCAL PUSH] Video frames: 8 | Non-video: 0 | Total callbacks: 25
[DEBUG] 📤 [LOCAL VIDEO SEND] FPS: "7.5" | Avg interval: "133.1" ms | Total frames: 25
07:26:10.329     vstdec0x7ecc010680 ! Decoding format changed: 640x480 NV12<- 30/1(~30)fps
07:26:10.329             vid_conf.c  .Update video port 1 queued
07:26:10.329             vid_conf.c  .Update video port 0 queued
07:26:10.330              sdl_dev.c !Stopping sdl video stream
07:26:10.330              sdl_dev.c  Starting sdl video stream
[DEBUG] 📹 [VIDEO SINK ITEM] Received frame 61 size: 640 x 360 valid: true format: Format_YUV420P
07:26:10.339                capdbuf  Buffer size adjusted from 2634 to 2004 (eff_cnt=1410)
07:26:10.341    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:10.341    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:10.397                capdbuf  Buffer size adjusted from 2644 to 2001 (eff_cnt=1410)
07:26:10.436    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:10.436    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:10.440                capdbuf  Buffer size adjusted from 2641 to 2117 (eff_cnt=1410)
07:26:10.444    ffmpeg_vid_codecs.c !🔍 [FIX 100.42.2] After entering #if LIBAVCODEC_VER_AT_LEAST(58,0):
07:26:10.444    ffmpeg_vid_codecs.c     data[0]=0x7eccce3068, data[1]=0x7eccd2e068
07:26:10.444     vstenc0x7ecc010680  🔍 [RTP SEND] Encode success: size=1304, has_more=1, transport=0x55abb9dcb8
07:26:10.445             vid_conf.c  .Video port 1 updated
07:26:10.445             vid_conf.c  .Video port 0 updated
07:26:10.445     vstdec0x7ecc010680   Decoding format changed: 640x480 NV12<- 30/1(~30)fps
07:26:10.445             vid_conf.c  .Update video port 1 queued
07:26:10.445             vid_conf.c  .Update video port 0 queued
07:26:10.455                capdbuf  Buffer size adjusted from 2117 to 1289 (eff_cnt=1410)
07:26:10.500    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:10.500    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:10.549    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:10.549    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:10.556                capdbuf  Buffer size adjusted from 2569 to 2153 (eff_cnt=1410)
07:26:10.571                capdbuf  Buffer size adjusted from 2153 to 1563 (eff_cnt=1410)
07:26:10.576    ffmpeg_vid_codecs.c !🔍 [FIX 100.42.2] After entering #if LIBAVCODEC_VER_AT_LEAST(58,0):
07:26:10.576    ffmpeg_vid_codecs.c     data[0]=0x7eccce3068, data[1]=0x7eccd2e068
07:26:10.576     vstenc0x7ecc010680  🔍 [RTP SEND] Encode success: size=927, has_more=0, transport=0x55abb9dcb8
07:26:10.577             vid_conf.c  .Video port 1 updated
07:26:10.577             vid_conf.c  .Video port 0 updated
07:26:10.577              sdl_dev.c  Stopping sdl video stream
07:26:10.577              sdl_dev.c  Starting sdl video stream
07:26:10.586     vstdec0x7ecc010680 ! Decoding format changed: 640x480 NV12<- 30/1(~30)fps
07:26:10.586             vid_conf.c  .Update video port 1 queued
07:26:10.586             vid_conf.c  .Update video port 0 queued
07:26:10.587              sdl_dev.c !Stopping sdl video stream
07:26:10.587              sdl_dev.c  Starting sdl video stream
07:26:10.600                capdbuf  Buffer size adjusted from 2203 to 1523 (eff_cnt=1410)
07:26:10.645    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:10.645    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:10.658                capdbuf  Buffer size adjusted from 2163 to 1301 (eff_cnt=1410)
07:26:10.694    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:10.694    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:10.712    ffmpeg_vid_codecs.c !🔍 [FIX 100.42.2] After entering #if LIBAVCODEC_VER_AT_LEAST(58,0):
07:26:10.712    ffmpeg_vid_codecs.c     data[0]=0x7eccce3068, data[1]=0x7eccd2e068
07:26:10.712     vstenc0x7ecc010680  🔍 [RTP SEND] Encode success: size=801, has_more=0, transport=0x55abb9dcb8
[DEBUG] 🎯 [PJSIP CALLBACK FPS] "14.7" | Total callbacks: 47 | Video frames: 40 | Non-video: 0 | Empty: 6 | Elapsed: 3200 ms
07:26:10.713             vid_conf.c  .Video port 1 updated
07:26:10.713             vid_conf.c  .Video port 0 updated
07:26:10.713     vstdec0x7ecc010680   Decoding format changed: 640x480 NV12<- 30/1(~30)fps
07:26:10.713             vid_conf.c  .Update video port 1 queued
07:26:10.713             vid_conf.c  .Update video port 0 queued
07:26:10.714              sdl_dev.c !Stopping sdl video stream
07:26:10.714              sdl_dev.c  Starting sdl video stream
07:26:10.740    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:10.740    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:10.760                capdbuf  Buffer size adjusted from 2581 to 1916 (eff_cnt=1410)
07:26:10.806    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:10.806    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:10.818                capdbuf  Buffer size adjusted from 2556 to 1612 (eff_cnt=1410)
07:26:10.844    ffmpeg_vid_codecs.c !🔍 [FIX 100.42.2] After entering #if LIBAVCODEC_VER_AT_LEAST(58,0):
07:26:10.844    ffmpeg_vid_codecs.c     data[0]=0x7eccce3068, data[1]=0x7eccd2e068
07:26:10.844     vstenc0x7ecc010680  🔍 [RTP SEND] Encode success: size=734, has_more=0, transport=0x55abb9dcb8
07:26:10.845             vid_conf.c  .Video port 1 updated
07:26:10.845             vid_conf.c  .Video port 0 updated
07:26:10.854     vstdec0x7ecc010680 ! Decoding format changed: 640x480 NV12<- 30/1(~30)fps
07:26:10.854             vid_conf.c  .Update video port 1 queued
07:26:10.854             vid_conf.c  .Update video port 0 queued
07:26:10.854              sdl_dev.c !Stopping sdl video stream
07:26:10.854              sdl_dev.c  Starting sdl video stream
07:26:10.876             alsa_dev.c !✅ [FIX 100.247 DEBUG] Capture stats: total=1001, success=1001, errors=0, frames_read=320
07:26:10.876             alsa_dev.c  🎤 [AUDIO DATA] Silent: NO ✅, Non-zero samples: 640/640 (100.0%), Max amplitude: 12244
07:26:10.876                capdbuf  Buffer size adjusted from 2252 to 1486 (eff_cnt=1410)
07:26:10.900    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:10.900    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:10.919                capdbuf  Buffer size adjusted from 2126 to 1292 (eff_cnt=1410)
07:26:10.950    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:10.950    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:10.976    ffmpeg_vid_codecs.c  🔍 [FIX 100.42.2] After entering #if LIBAVCODEC_VER_AT_LEAST(58,0):
07:26:10.976    ffmpeg_vid_codecs.c     data[0]=0x7eccce3068, data[1]=0x7eccd2e068
07:26:10.977     vstenc0x7ecc010680  🔍 [RTP SEND] Encode success: size=1216, has_more=0, transport=0x55abb9dcb8
07:26:10.977             vid_conf.c !.Video port 1 updated
07:26:10.977             vid_conf.c  .Video port 0 updated
07:26:10.977     vstdec0x7ecc010680   Decoding format changed: 640x480 NV12<- 30/1(~30)fps
07:26:10.978             vid_conf.c  .Update video port 1 queued
07:26:10.978             vid_conf.c  .Update video port 0 queued
07:26:10.978              sdl_dev.c !Stopping sdl video stream
07:26:10.978              sdl_dev.c  Starting sdl video stream
[DEBUG] 📹 [DISPLAY FRAME] Presenting to QVideoSink: frame 46 size: 640 x 360 valid: true m_videoSink: QVideoSink(0x55a8d007f0)
[DEBUG] 📹 [VIDEO SINK ITEM] Received frame 76 size: 640 x 360 valid: true format: Format_YUV420P
[DEBUG] 📹 [PAINT NODE] Rendering frame 61 image: 640 x 360 item size: 367 x 236 has content: true
[DEBUG] 📹 [PAINT NODE] Created texture from image: QSize(640, 360)
07:26:11.035                capdbuf  Buffer size adjusted from 2572 to 2033 (eff_cnt=1410)
07:26:11.046    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:11.046    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:11.079                capdbuf  Buffer size adjusted from 2673 to 1908 (eff_cnt=1410)
07:26:11.112    ffmpeg_vid_codecs.c !🔍 [FIX 100.42.2] After entering #if LIBAVCODEC_VER_AT_LEAST(58,0):
07:26:11.112    ffmpeg_vid_codecs.c     data[0]=0x7eccce3068, data[1]=0x7eccd2e068
07:26:11.112     vstenc0x7ecc010680  🔍 [RTP SEND] Encode success: size=32, has_more=1, transport=0x55abb9dcb8
07:26:11.113             vid_conf.c  .Video port 1 updated
07:26:11.113             vid_conf.c  .Video port 0 updated
07:26:11.129     vstdec0x7ecc010680 ! Decoding format changed: 640x480 NV12<- 30/1(~30)fps
07:26:11.129             vid_conf.c  .Update video port 1 queued
07:26:11.129             vid_conf.c  .Update video port 0 queued
07:26:11.129              sdl_dev.c !Stopping sdl video stream
07:26:11.129              sdl_dev.c  Starting sdl video stream
07:26:11.137                capdbuf  Buffer size adjusted from 2548 to 2021 (eff_cnt=1410)
07:26:11.149    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:11.149    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:11.156    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:11.157    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:11.173           pjsua_core.c  .RX 373 bytes Request msg BYE/cseq=29 (rdata0x55abb63e48) from TCP 192.168.1.4:5060:
BYE sip:1001@192.168.1.8;ob SIP/2.0
Via: SIP/2.0/TCP 192.168.1.4;branch=z9hG4bKYXH3ddf7aef83b3f1b5;rport
From: <sip:1006@192.168.1.4>;tag=cec7704ea19952cd
To: <sip:1001@192.168.1.4>;tag=5a61ba17-b1b3-4cc3-96e1-46dbffbcf7f3
Call-ID: 4c51ed3d-6cd6-4b3c-b9d2-97d1a2e66dc0
User-Agent: SIP server (5 clients, 20251206)
CSeq: 29 BYE
Max-Forwards: 70
Content-Length: 0


--end msg--
07:26:11.173           pjsua_core.c  .......TX 315 bytes Response msg 200/BYE/cseq=29 (tdta0x7ecce3fbc0) to TCP 192.168.1.4:5060:
SIP/2.0 200 OK
Via: SIP/2.0/TCP 192.168.1.4;rport=5060;received=192.168.1.4;branch=z9hG4bKYXH3ddf7aef83b3f1b5
Call-ID: 4c51ed3d-6cd6-4b3c-b9d2-97d1a2e66dc0
From: <sip:1006@192.168.1.4>;tag=cec7704ea19952cd
To: <sip:1001@192.168.1.4>;tag=5a61ba17-b1b3-4cc3-96e1-46dbffbcf7f3
CSeq: 29 BYE
Content-Length:  0


--end msg--
07:26:11.173          pjsua_media.c  ......Call 0: deinitializing media..
07:26:11.173          pjsua_media.c  .......
  [DISCONNECTED] To: <sip:1006@192.168.1.4>;tag=cec7704ea19952cd
    Call time: 00h:00m:04s, 1st res in 55 ms, conn in 4680ms
    #0 audio PCMA @8kHz, sendrecv, peer=192.168.1.4:20400
       SRTP status: Not active Crypto-suite:
       RX pt=8, last update:00h:00m:04.256s ago
          total 225pkt 35.8KB (44.8KB +IP hdr) @avg=59.1Kbps/73.9Kbps
          pkt loss=0 (0.0%), discrd=1 (0.4%), dup=0 (0.0%), reord=0 (0.0%)
                (msec)    min     avg     max     last    dev
          loss period:   0.000   0.000   0.000   0.000   0.000
          jitter     :   0.000   0.489   1.125   0.500   0.294
       TX pt=8, ptime=20, last update:00h:00m:01.996s ago
          total 198pkt 31.6KB (39.6KB +IP hdr) @avg=52.2Kbps/65.3Kbps
          pkt loss=0 (0.0%), dup=0 (0.0%), reorder=0 (0.0%)
                (msec)    min     avg     max     last    dev
          loss period:   0.000   0.000   0.000   0.000   0.000
          jitter     :   0.875   0.875   0.875   0.875   0.000
       RTT msec      :   1.434   1.434   1.434   1.434   0.000
    #1 video H264, sendrecv, peer=192.168.1.4:20402
       SRTP status: Not active Crypto-suite:
       RX pt=100, size=640x480, fps=30.00, last update:00h:00m:04.010s ago
          total 176pkt 207.4KB (214.4KB +IP hdr) @avg=342.8Kbps/354.4Kbps
     libv4l2: error dequeuing buf: Invalid argument
     pkt loss=0 (0.0%), discrd=0 (0.0%), dup=0 (0.0%), reord=0 (0.0%)
                (msec)    min     avg     max     last    dev
          loss period:   0.000   0.000   0.000   0.000   0.000
          jitter     :   0.044   0.542   0.977   0.977   0.198
       TX pt=100, size=640x480, fps=30.00, last update:00h:00m:01.151s ago
          total 95pkt 94.3KB (98.1KB +IP hdr) @avg=155.8Kbps/162.1Kbps
          pkt loss=0 (0.0%), dup=0 (0.0%), reorder=0 (0.0%)
                (msec)    min     avg     max     last    dev
          loss period:   0.000   0.000   0.000   0.000   0.000
          jitter     :  41.377  56.189  71.000  71.000  14.811
       RTT msec      :   0.000   0.000   0.000   0.000   0.000
07:26:11.173           conference.c  .........Remove port 1 queued
07:26:11.173       strm0x7ecc006fb8  ........Stream destroying
07:26:11.173        udp0x55abee9270  ........UDP media transport detached
07:26:11.173          pjsua_media.c  ........Media stream call00:0 is destroyed
07:26:11.173            pjsua_vid.c  ........Stopping video stream..
07:26:11.173              sdl_dev.c  .........Stopping sdl video stream
07:26:11.173            pjsua_vid.c  .........Window 0: destroying..
07:26:11.173             vid_conf.c  ...........Remove video port 0 queued
07:26:11.173              sdl_dev.c  ..........Stopping sdl video stream
07:26:11.173             vid_port.c  ..........Destroy request on SDL renderer..
07:26:11.173            pjsua_vid.c  .........Call 0 media 1: Stream video window released
07:26:11.173            pjsua_vid.c  .........✅ [FIX 70] Fix 32 mode detected, cleaning up orphan camera resources
07:26:11.173            pjsua_vid.c  .........    vp_cap=0x7eccd54358 pool=0x7eccd53d10 cap_slot=3
07:26:11.173             v4l2_dev.c  .........Stopping v4l2 video stream USB camera: USB camera
07:26:11.180                capdbuf  Buffer size adjusted from 2661 to 2167 (eff_cnt=1410)
07:26:11.185           conference.c !.Stop any transmission to port 1 (sip:1006@192.168.1.4)
07:26:11.185           conference.c  .Port 0 (hw:CARD=camera,DEV=0) stop transmitting to port 1 (sip:1006@192.168.1.4)
07:26:11.185           conference.c  .Stop any transmission from port 1 (sip:1006@192.168.1.4)
07:26:11.185           conference.c  .Port 1 (sip:1006@192.168.1.4) stop transmitting to port 0 (hw:CARD=camera,DEV=0)
07:26:11.185           conference.c  .Removed port 1 (sip:1006@192.168.1.4), port count=1
07:26:11.185         avsync-call_00  .Removed media Audio
07:26:11.185       strm0x7ecc006fb8  .Stream destroyed
07:26:11.195                capdbuf  Buffer size adjusted from 2167 to 1413 (eff_cnt=1410)
07:26:11.200            pjsua_vid.c !.........✅ [FIX 71.2] Step 1: Stopped video capture
07:26:11.200             vid_conf.c  ..........Disconnect video ports 3->2 queued
07:26:11.200            pjsua_vid.c  .........✅ [FIX 71.2] Step 2: Disconnected cap_slot 3 from enc_slot 2
07:26:11.200             vid_conf.c  ..........Remove video port 3 queued
07:26:11.200            pjsua_vid.c  .........✅ [FIX 71.2] Step 3: Removed cap_slot 3 from vid_conf
07:26:11.200             vid_port.c  .........Destroy request on USB camera: USB camera..
07:26:11.200            pjsua_vid.c  .........✅ [FIX 71.2] Step 4: Destroyed vid_port (V4L2 device released)
07:26:11.200            pjsua_vid.c  .........✅ [FIX 71.2] Step 5: Released memory pool
07:26:11.200            pjsua_vid.c  .........✅ [FIX 70 + 71.2] Camera resources fully cleaned up
07:26:11.200             vid_conf.c  ..........Remove video port 2 queued
07:26:11.200             vid_conf.c  ..........Remove video port 1 queued
07:26:11.200           vid_stream.c  .........Destroy request on vstrm0x7ecc010680..
[DEBUG] 📊 [REMOTE VIDEO PUSH] Enqueued FPS: "15.6" | Avg interval: "63.9" ms | Avg copy time: "0.00" ms | Total frames: 49 ""
07:26:11.200             vid_conf.c  .Video port 1 updated
07:26:11.201             vid_conf.c  .Video port 0 updated
07:26:11.201             vid_conf.c  .Port 1 (vstdec0x7ecc010680) stop transmitting to port 0 (SDL renderer)
[DEBUG] 🔧 [ASYNC WORKER] Processed FPS: "15.6" | Last convert time: 0 ms | Queue size: 0
!!! [CRASH-DEBUG-N] Checkpoint N: About to log port removal (port 0, name=SDL renderer)
!!! [CRASH-DEBUG-O] Checkpoint O: About to call pjmedia_port_dec_ref (port=0x7eccb60140)
!!! [CRASH-DEBUG-O1] port=0x7eccb60140, checking grp_lock...
!!! [CRASH-DEBUG-O2] grp_lock=0x7eccbe1230, on_destroy=0x5572267290
!!! [CRASH-DEBUG-O3] Calling pjmedia_port_dec_ref now...
07:26:11.201             vid_conf.c  .Removed video port 0 (SDL renderer), port count=5
07:26:11.201             vid_port.c  .Destroying SDL renderer..
07:26:11.201              sdl_dev.c  .Stopping sdl video stream
07:26:11.206    ffmpeg_vid_codecs.c !✅ [FIX 100.28] Broadcasted PJMEDIA_EVENT_FMT_CHANGED for format 842094158
07:26:11.206    ffmpeg_vid_codecs.c  ✅ [FIX 100.27 DIAG] After memcpy: output->type=3, output->size=460800
07:26:11.206        udp0x55abb577d0 !.........UDP media transport detached
07:26:11.206          pjsua_media.c  ........Media stream call00:1 is destroyed
07:26:11.206         avsync-call_00  .......avsync-call_00 destroy requested
07:26:11.206       srtp0x55a931b760  .......Destroying SRTP transport
07:26:11.206        udp0x55abee9270  .......UDP media transport destroying
07:26:11.206        udp0x55abee9270  .......UDP media transport destroyed
07:26:11.206       srtp0x55a931b760  .......SRTP transport destroyed
07:26:11.206       srtp0x55abcc2a50  .......Destroying SRTP transport
07:26:11.206        udp0x55abb577d0  .......UDP media transport destroying
[DEBUG] 🔔 [PJSIP C CALLBACK] call_state_callback_wrapper() called, call_id: 0
[DEBUG] 🔔 [PJSIP C CALLBACK] Getting call info...
[DEBUG] 🔔 [PJSIP C CALLBACK] pjsua_call_get_info() status: 0
[DEBUG] 🔴 [HANGUP-DEBUG] ═══════════════════════════════════════════
[DEBUG] 🔴 [HANGUP-DEBUG] 进入 PJSIP_INV_STATE_DISCONNECTED 回调
[DEBUG] 🔴 [HANGUP-DEBUG] call_id: 0
[DEBUG] 🔴 [HANGUP-DEBUG] ═══════════════════════════════════════════
[DEBUG] 🔴 [FIX 72 DIAG] PJSIP_INV_STATE_DISCONNECTED triggered, call_id: 0
[DEBUG] 🔴 [HANGUP-DEBUG] 准备调用 notifyCallDisconnected()...
[DEBUG] 🔴 [FIX 72] About to call notifyCallDisconnected()
[DEBUG] 🔴 [HANGUP-DEBUG] ═══════════════════════════════════════════
[DEBUG] 🔴 [HANGUP-DEBUG] notifyCallDisconnected() 开始执行
[DEBUG] 🔴 [HANGUP-DEBUG] ═══════════════════════════════════════════
[DEBUG] ✅ Notifying video managers: Call disconnected
[DEBUG] 🔴 [HANGUP-DEBUG] 步骤 1/2: 调用 RemoteVideoManager::onCallDisconnected()...
[DEBUG] 🔴 [HANGUP-DEBUG] ═══════════════════════════════════════════
[DEBUG] 🔴 [HANGUP-DEBUG] RemoteVideoManager::onCallDisconnected() 开始
[DEBUG] 🔴 [HANGUP-DEBUG] ═══════════════════════════════════════════
[DEBUG] 🔴 [FIX 72] RemoteVideoManager::onCallDisconnected() entered
[DEBUG] 📹 RemoteVideoManager: Call disconnected
[DEBUG] 🔴 [HANGUP-DEBUG] 发送 requestStopCheck 信号...
[DEBUG] 🔴 [FIX 72] Emitting requestStopCheck signal
[DEBUG] 🔴 [HANGUP-DEBUG] 调用 disconnectFromVideoBridge()...
[DEBUG] 🔴 [FIX 72] Calling disconnectFromVideoBridge()
[DEBUG] 🔌 RemoteVideoManager: Removing custom port from video conference, slot: 5
07:26:11.207             vid_conf.c  .......Remove video port 5 queued
[DEBUG] 🔌 RemoteVideoManager: Disconnecting from video bridge
[DEBUG] 🔴 [HANGUP-DEBUG] disconnectFromVideoBridge() 完成
[DEBUG] 🔴 [HANGUP-DEBUG] 调用 destroyCustomPort()...
[DEBUG] 🔴 [FIX 72] Calling destroyCustomPort()
[DEBUG] 🔴 [HANGUP-DEBUG] RemoteVideoManager::destroyCustomPort() 开始
[DEBUG] 🔴 [HANGUP-DEBUG] m_customPort: 0x55ac6637e0
[DEBUG] 🔴 [HANGUP-DEBUG] m_customSlot: -1
[DEBUG] 🔴 [HANGUP-DEBUG] m_pool: 0x55ac663730
[DEBUG] 🔴 [HANGUP-DEBUG] 清空 m_customPort 指针 (pool 由 on_destroy 回调释放)
[DEBUG] 🔴 [FIX 100.245] Pool 不立即释放，等待 port_on_destroy 回调
[DEBUG] 🔴 [HANGUP-DEBUG] RemoteVideoManager::destroyCustomPort() 完成
[DEBUG] 🔴 [HANGUP-DEBUG] ═══════════════════════════════════════════
[DEBUG] 🔴 [HANGUP-DEBUG] destroyCustomPort() 完成
[DEBUG] 🔴 [FIX 72] Port cleanup completed
[DEBUG] 🔴 [HANGUP-DEBUG] 步骤 1/2: RemoteVideoManager::onCallDisconnected() 完成
[DEBUG] 🔴 [HANGUP-DEBUG] 步骤 2/2: 准备调用 LocalVideoManager::stopPreview()...
[DEBUG] 🔧 [FIX VERSION 156] Stopping local preview on call disconnect
[DEBUG] 🔴 [HANGUP-DEBUG] 使用 QMetaObject::invokeMethod 在主线程调用...
[DEBUG] 🔴 [HANGUP-DEBUG] 步骤 2/2: stopPreview() 已入队等待主线程执行
[DEBUG] ✅ [FIX VERSION 156] stopPreview() queued for execution in Qt main thread
[DEBUG] 🔴 [HANGUP-DEBUG] ═══════════════════════════════════════════
[DEBUG] 🔴 [HANGUP-DEBUG] notifyCallDisconnected() 执行完成
[DEBUG] 🔴 [HANGUP-DEBUG] ═══════════════════════════════════════════
[DEBUG] 🔴 [HANGUP-DEBUG] notifyCallDisconnected() 已完成
[DEBUG] 🔴 [FIX 72] notifyCallDisconnected() completed
[DEBUG] ✅ [UI UPDATE] Call 0 state: "通话结束"
[DEBUG] ✅ [UI] inCall changed to: false
[DEBUG] ✅ [CALL STATE] Call 0 state: DISCONNECTED
[DEBUG] 🔔 [PJSIP C CALLBACK] Calling original PJSUA2 on_call_state callback...
[DEBUG] 🔔 [PJSIP C CALLBACK] call_state_callback_wrapper() called, call_id: 0
[DEBUG] ⚠️ [PJSIP C CALLBACK] Recursive invocation detected, returning
[DEBUG] 🔔 [PJSIP C CALLBACK] Original callback returned
[DEBUG] 🔔 [PJSIP C CALLBACK] call_state_callback_wrapper() completed
[DEBUG] ⏹️ RemoteVideoManager: Check timer stopped
[DEBUG] 🔴 [HANGUP-DEBUG] ═══════════════════════════════════════════
[DEBUG] 🔴 [HANGUP-DEBUG] LocalVideoManager::stopPreview() 开始
[DEBUG] 🔴 [HANGUP-DEBUG] ═══════════════════════════════════════════
[DEBUG] 🔴 [HANGUP-DEBUG] 非析构路径，正常清理
[DEBUG] 🔴 [HANGUP-DEBUG] 正常路径 - custom_slot ID: 4
[DEBUG] 🔧 [FIX 100.64] Initiating cleanup (custom_slot: 4 , no QMutex member)
[DEBUG] 🔴 [HANGUP-DEBUG] ⚠️ 准备手动移除 port (custom_slot: 4 )
[DEBUG]    [FIX VERSION 156] Manually removing custom_slot from vid_conf to stop callbacks
07:26:11.216             vid_conf.c  .Remove video port 4 queued
[DEBUG] 🔴 [HANGUP-DEBUG] pjsua_vid_conf_remove_port() 返回, status: 0
[DEBUG]    ✅ [FIX VERSION 156] Port removed successfully (custom_slot: 4 )
[DEBUG] 🔴 [HANGUP-DEBUG] ✅ Port 移除成功
[DEBUG]    [FIX VERSION 156] Port marked as null (pool will be released by on_destroy callback)
[DEBUG] ✅ [FIX 100.64] Custom port cleanup initiated (PJSIP will auto-cleanup, no QMutex member)
[DEBUG] ✅ Current call video flag updated: false
[DEBUG] 🔍 [QML] Video Accept Button visibility check:
[DEBUG]     callStatus: 通话结束 → hasCallStatus: false
[DEBUG]     isIncomingVideoCall: false
[DEBUG]     → visible: false
[DEBUG] 📞 [RINGTONE] Call status changed: 通话结束
[DEBUG] ✅ Call ended - updating UI state (video cleanup handled by C++)
[DEBUG] ✅ [UI] Call timer stopped
[DEBUG] C++ currentNumberChanged signal received:
[DEBUG] Number display text changed to: 请输入号码
!!! [CRASH-DEBUG-P] Checkpoint P: pjmedia_port_dec_ref returned
!!! [CRASH-DEBUG-Q] Checkpoint Q: About to call pj_pool_safe_release (pool=0x7eccbe0f70)
!!! [CRASH-DEBUG-R] Checkpoint R: pj_pool_safe_release returned
!!! [CRASH-DEBUG-S] Checkpoint S: About to return from remove_port (port 0)
!!! [CRASH-DEBUG-N] Checkpoint N: About to log port removal (port 3, name=USB camera: USB camera)
!!! [CRASH-DEBUG-O] Checkpoint O: About to call pjmedia_port_dec_ref (port=0x7eccd541d0)
!!! [CRASH-DEBUG-O1] port=0x7eccd541d0, checking grp_lock...
!!! [CRASH-DEBUG-O2] grp_lock=0x7eccdc9610, on_destroy=0x5572267290
!!! [CRASH-DEBUG-O3] Calling pjmedia_port_dec_ref now...
!!! [CRASH-DEBUG-P] Checkpoint P: pjmedia_port_dec_ref returned
!!! [CRASH-DEBUG-Q] Checkpoint Q: About to call pj_pool_safe_release (pool=0x7eccd54a20)
!!! [CRASH-DEBUG-R] Checkpoint R: pj_pool_safe_release returned
!!! [CRASH-DEBUG-S] Checkpoint S: About to return from remove_port (port 3)
!!! [CRASH-DEBUG-N] Checkpoint N: About to log port removal (port 2, name=vstenc0x7ecc010680)
!!! [CRASH-DEBUG-O] Checkpoint O: About to call pjmedia_port_dec_ref (port=0x7ecc011920)
!!! [CRASH-DEBUG-O1] port=0x7ecc011920, checking grp_lock...
!!! [CRASH-DEBUG-O2] grp_lock=0x7ecc014ab0, on_destroy=(nil)
!!! [CRASH-DEBUG-O3] Calling pjmedia_port_dec_ref now...
!!! [CRASH-DEBUG-P] Checkpoint P: pjmedia_port_dec_ref returned
!!! [CRASH-DEBUG-Q] Checkpoint Q: About to call pj_pool_safe_release (pool=0x7eccce2e30)
!!! [CRASH-DEBUG-R] Checkpoint R: pj_pool_safe_release returned
!!! [CRASH-DEBUG-S] Checkpoint S: About to return from remove_port (port 2)
!!! [CRASH-DEBUG-N] Checkpoint N: About to log port removal (port 1, name=vstdec0x7ecc010680)
!!! [CRASH-DEBUG-O] Checkpoint O: About to call pjmedia_port_dec_ref (port=0x7ecc011820)
!!! [CRASH-DEBUG-O1] port=0x7ecc011820, checking grp_lock...
!!! [CRASH-DEBUG-O2] grp_lock=0x7ecc014ab0, on_destroy=(nil)
!!! [CRASH-DEBUG-O3] Calling pjmedia_port_dec_ref now...

!!! [STDERR-DIAG] ENTER ffmpeg_codec_close VERSION 156 !!!
!!! [STDERR-DIAG] codec pointer = 0x7ecc014690
!!! [STDERR-DIAG] codec is valid, about to access codec_data
!!! [STDERR-DIAG] About to read codec->codec_data (codec=0x7ecc014690)
!!! [STDERR-DIAG] codec->codec_data = 0x7ecc014818
!!! [STDERR-DIAG] codec_data is valid, continuing cleanup
!!! [STDERR-DIAG-2] ff_mutex obtained
!!! [STDERR-DIAG-3] enc_ctx accessed (enc_ctx=0x7ecc015220)
!!! [STDERR-DIAG-4] dec_ctx accessed (dec_ctx=0x7ecc0155e0)
!!! [STDERR-DIAG-5] ENTER decoder cleanup
!!! [STDERR-DIAG-6] About to call avcodec_free_context(dec_ctx)
!!! [STDERR-DIAG-7] avcodec_free_context(dec_ctx) returned
!!! [STDERR-DIAG-8] ENTER encoder cleanup

========================================================================
!!! [VERSION 155 DIAG] === Two-Layer Resource Management Analysis ===
========================================================================

!!! [HYPOTHESIS-1] Fix 100.50 had NO Flush (probability: ⭐⭐⭐⭐⭐)
    Evidence:
      - Fix 100.50 logs (docs/2026-01-11/47 Line 169-193)
      - Only shows: "CODEC-CLOSE VERSION 125 ENTRY"
      - NO "Flushing encoder buffers" output
    Theory:
      - Fix 100.50 skipped manual Flush entirely
      - avcodec_close() handles Flush internally
      - Uses own properly initialized AVPacket
    VERSION 154 Test:
      - Will SKIP manual Flush operation
      - Let avcodec_close() auto-flush
    Reference: docs/2026-01-14/06-VERSION153失败分析-Flush阶段崩溃根因.md

!!! [HYPOTHESIS-2] Fix 100.50 used av_init_packet() (probability: ⭐⭐)
    Problem:
      - Documentation may have omitted av_init_packet() call
      - But Fix 100.78 said av_init_packet() causes crash
    Contradiction:
      - If Fix 100.50 used av_init_packet() and succeeded,
        why did Fix 100.78 say it crashes?
    Conclusion:
      - Hypothesis 2 unlikely
      - Prioritize testing Hypothesis 1
    FFmpeg 6.0 Status:
      - av_init_packet() DEPRECATED since FFmpeg 6.0
      - VERSION 154 does NOT use av_init_packet()

!!! [HYPOTHESIS-3] FFmpeg version difference (probability: ⭐)
    Theory:
      - Fix 100.50 may have used different FFmpeg version
      - Older avcodec_receive_packet() might be more tolerant
    Current Environment:
      - FFmpeg version: 6.1
      - LIBAVCODEC_VERSION: 60.31.102
      - LIBAVUTIL_VERSION: 58.29.100
    API Check:
      - av_init_packet() deprecated: YES (since FFmpeg 6.0)
      - avcodec_receive_packet() behavior: Calls av_packet_unref() first
    Conclusion:
      - Version difference unlikely root cause
      - Core API behavior same across FFmpeg 6.x

!!! [HYPOTHESIS-4] Don't manually release hw_frames_ctx (probability: ⭐⭐⭐)
    Theory:
      - Let avcodec_close() auto-release ALL resources
      - Including hw_frames_ctx and hw_device_ctx
    Risk:
      - Fix 100.50 explicitly released hw_frames_ctx manually
      - Changing this may introduce new issues
    STATUS:
      - VERSION 154 KEEPS manual hw_frames_ctx release (same as Fix 100.50)
      - Will test Hypothesis 4 ONLY IF Hypothesis 1 fails

========================================================================
!!! [VERSION 154 STRATEGY] Testing Hypothesis 1 (highest probability)
========================================================================


!!! [VERSION 154 HYPOTHESIS-1] === Testing: Remove Flush Operation ===
!!! [VERSION 154 HYPOTHESIS-1] Theory: Fix 100.50 had NO Flush at all
!!! [VERSION 154 HYPOTHESIS-1] Evidence: Fix 100.50 logs show no Flush output
!!! [VERSION 154 HYPOTHESIS-1] Reference: docs/2026-01-11/47-Fix100.50成功-解决挂断崩溃问题.md Line 169-193
!!! [VERSION 154 HYPOTHESIS-1] Action: Skip manual Flush, let avcodec_close() auto-flush
!!! [VERSION 154 HYPOTHESIS-1] FFmpeg Doc: "avcodec_close() will flush and free all resources"
!!! [VERSION 154 HYPOTHESIS-1] Flush operation SKIPPED (as per hypothesis)
!!! [VERSION 154 HYPOTHESIS-1] Proceeding to Step 2: hw_frames_ctx release
!!! [VERSION 154 HYPOTHESIS-1] === Hypothesis 1 Implementation Complete ===


!!! [VERSION 155 STEP-2] === hw_frames_ctx Management ===
!!! [VERSION 155 STEP-2] Status: NOT releasing manually (NEW - different from VERSION 154)
!!! [VERSION 155 STEP-2] Reason: Avoid Double-Free in avcodec_close()
!!! [VERSION 155 STEP-2] Historical Failure:
    - VERSION 154: Manually released → Double-Free ❌
    - 方案C (2026-01-14 00:40): Manually released → Double-Free ❌
!!! [VERSION 155 STEP-2] hw_frames_ctx is NULL (not set or already released)
!!! [VERSION 155 STEP-2] === hw_frames_ctx NULL ===


!!! [VERSION 155 STEP-3] === hw_device_ctx Management ===
!!! [VERSION 155 STEP-3] Status: NOT releasing manually (same as Fix 100.50)
!!! [VERSION 155 STEP-3] Reason: Shared ref-counted, avcodec_close() will handle it
!!! [VERSION 155 STEP-3] hw_device_ctx status:
    Address: 0x7ecc0160d0 (shared, ref-counted)
    Shared between encoder and decoder
    Will be released by avcodec_close() automatically
!!! [VERSION 155 STEP-3] === hw_device_ctx Auto-Release Strategy ===


========================================================================
!!! [VERSION 156 PLAN-I] === Resource Leak Strategy ===
========================================================================

!!! [VERSION 156 PLAN-I] 🚨 WARNING: Intentional resource leak!
!!! [VERSION 156 PLAN-I] Reason: Avoid race condition with RKMPP async threads

!!! [VERSION 156 PLAN-I] === Encoder Context State (will be leaked) ===
!!! [VERSION 156 PLAN-I] enc_ctx address: 0x7ecc015220 (will be leaked)
!!! [VERSION 156 PLAN-I] enc_ctx->codec: 0x7f88ca9740
!!! [VERSION 156 PLAN-I] codec->name: h264_rkmpp
!!! [VERSION 156 PLAN-I] enc_ctx->hw_frames_ctx: (nil) (will be leaked)
!!! [VERSION 156 PLAN-I] enc_ctx->hw_device_ctx: 0x7ecc0160d0 (will be leaked)
!!! [VERSION 156 PLAN-I] enc_ctx->width=640, height=480
!!! [VERSION 156 PLAN-I] enc_ctx->pix_fmt=0

!!! [VERSION 156 PLAN-I] === Why This Might Work ===
!!! [VERSION 156 PLAN-I] VERSION 155 failure analysis:
    - enc_ctx->hw_device_ctx: 0x7ee80391f0 (PJSIP layer)
    - r->hwdevice: 0x7ee865c070 (RKMPP internal)
    - Two different AVBufferRef pointing to same RKMPP device
    - async_frames=4: RKMPP uses async mode
    - mpp_destroy() returns but async threads may still run
    - avcodec_close() tries to release hw_device_ctx
    - Conflicts with background threads → SIGSEGV

!!! [VERSION 156 PLAN-I] By NOT calling avcodec_close():
    - ✅ No synchronous cleanup
    - ✅ No race with RKMPP async threads
    - ✅ Let OS reclaim resources on process exit
    - ❌ Resources leaked until process ends

!!! [VERSION 156 PLAN-I] ❌ NOT calling avcodec_close(enc_ctx=0x7ecc015220)
!!! [VERSION 156 PLAN-I] ❌ NOT calling avcodec_free_context(&enc_ctx)
!!! [VERSION 156 PLAN-I] ✅ Only clearing pointer to prevent use-after-free

!!! [VERSION 156 PLAN-I] === After Pointer Clear ===
!!! [VERSION 156 PLAN-I] enc_ctx will be set to NULL (pointer cleared)
!!! [VERSION 156 PLAN-I] Original enc_ctx=0x7ecc015220 is now leaked
!!! [VERSION 156 PLAN-I] === VERSION 156 COMPLETE ===
!!! [VERSION 156 PLAN-I] If no crash: Plan I SUCCESS - Race condition avoided!
!!! [VERSION 156 PLAN-I] If still crash: Need to try Plan E (software encoder)
========================================================================
!!! [CRASH-DEBUG-1] Checkpoint A: About to call PJ_LOG
!!! [CRASH-DEBUG-2] Checkpoint B: PJ_LOG completed
!!! [CRASH-DEBUG-3] Checkpoint C: Exited if(enc_ctx) block
!!! [CRASH-DEBUG-4] Checkpoint D: enc_ctx set to NULL
!!! [CRASH-DEBUG-5] Checkpoint E: dec_ctx set to NULL
!!! [CRASH-DEBUG-6] Checkpoint F: About to call final PJ_LOG
!!! [CRASH-DEBUG-7] Checkpoint G: About to return PJ_SUCCESS
!!! [CRASH-DEBUG-J] Checkpoint J: About to set codec->codec_data = NULL
!!! [CRASH-DEBUG-K] Checkpoint K: About to call pj_pool_release (pool=0x7ecc0145e0)
!!! [CRASH-DEBUG-L] Checkpoint L: pj_pool_release returned successfully
!!! [CRASH-DEBUG-M] Checkpoint M: About to return PJ_SUCCESS from dealloc_codec
!!! [CRASH-DEBUG-P] Checkpoint P: pjmedia_port_dec_ref returned
!!! [CRASH-DEBUG-Q] Checkpoint Q: About to call pj_pool_safe_release (pool=0x7eccc61e50)
!!! [CRASH-DEBUG-R] Checkpoint R: pj_pool_safe_release returned
!!! [CRASH-DEBUG-S] Checkpoint S: About to return from remove_port (port 1)
!!! [CRASH-DEBUG-N] Checkpoint N: About to log port removal (port 5, name=qt_remote_video_sink)
!!! [CRASH-DEBUG-O] Checkpoint O: About to call pjmedia_port_dec_ref (port=0x55ac6637e0)
!!! [CRASH-DEBUG-O1] port=0x55ac6637e0, checking grp_lock...
!!! [CRASH-DEBUG-O2] grp_lock=0x55ac676ef0, on_destroy=0x55720a2da0
!!! [CRASH-DEBUG-O3] Calling pjmedia_port_dec_ref now...
!!! [CRASH-DEBUG-P] Checkpoint P: pjmedia_port_dec_ref returned
!!! [CRASH-DEBUG-Q] Checkpoint Q: About to call pj_pool_safe_release (pool=0x55ac660130)
!!! [CRASH-DEBUG-R] Checkpoint R: pj_pool_safe_release returned
!!! [CRASH-DEBUG-S] Checkpoint S: About to return from remove_port (port 5)
!!! [CRASH-DEBUG-N] Checkpoint N: About to log port removal (port 4, name=qt_local_video_sink)
!!! [CRASH-DEBUG-O] Checkpoint O: About to call pjmedia_port_dec_ref (port=0x55abc92bc0)
!!! [CRASH-DEBUG-O1] port=0x55abc92bc0, checking grp_lock...
!!! [CRASH-DEBUG-O2] grp_lock=0x55abc820c0, on_destroy=0x557209a820
!!! [CRASH-DEBUG-O3] Calling pjmedia_port_dec_ref now...
!!! [CRASH-DEBUG-P] Checkpoint P: pjmedia_port_dec_ref returned
!!! [CRASH-DEBUG-Q] Checkpoint Q: About to call pj_pool_safe_release (pool=0x55abcc20a0)
!!! [CRASH-DEBUG-R] Checkpoint R: pj_pool_safe_release returned
!!! [CRASH-DEBUG-S] Checkpoint S: About to return from remove_port (port 4)
07:26:11.231             vid_conf.c !.Port 3 (USB camera: USB camera) stop transmitting to port 2 (vstenc0x7ecc010680)
07:26:11.231             vid_conf.c  .Port 3 (USB camera: USB camera) stop transmitting to port 4 (qt_local_video_sink)
07:26:11.231             vid_conf.c  .Removed video port 3 (USB camera: USB camera), port count=4
07:26:11.231             vid_port.c  .Destroying USB camera: USB camera..
07:26:11.231             v4l2_dev.c  .Stopping v4l2 video stream USB camera: USB camera
07:26:11.231             v4l2_dev.c  .Destroying v4l2 video stream USB camera: USB camera
07:26:11.232             vid_conf.c  .Removed video port 2 (vstenc0x7ecc010680), port count=3
07:26:11.232             vid_conf.c  .Port 1 (vstdec0x7ecc010680) stop transmitting to port 5 (qt_remote_video_sink)
07:26:11.232             vid_conf.c  .Removed video port 1 (vstdec0x7ecc010680), port count=2
07:26:11.232    ffmpeg_vid_codecs.c  .🔍 [CODEC-CLOSE VERSION 156 ENTRY] Function called
07:26:11.232    ffmpeg_vid_codecs.c  .🔍 [CODEC-CLOSE VERSION 156] codec pointer valid
07:26:11.232    ffmpeg_vid_codecs.c  .🔍 [CODEC-CLOSE VERSION 156] Closing codec, enc_ctx=0x7ecc015220
07:26:11.232    ffmpeg_vid_codecs.c  .🔍 [FIX 100.66 DIAG] dec_ctx=0x7ecc0155e0, enc_ctx=0x7ecc015220
07:26:11.232    ffmpeg_vid_codecs.c  .🔍 [FIX 100.66 DIAG] Checking decoder: dec_ctx=0x7ecc0155e0, enc_ctx=0x7ecc015220, condition=1
07:26:11.232    ffmpeg_vid_codecs.c  .✅ [FIX 100.66 DIAG] Entering decoder cleanup
07:26:11.232    ffmpeg_vid_codecs.c  .✅ [FIX 100.65.2] Skipping decoder flush (avcodec_close will handle it)
07:26:11.232    ffmpeg_vid_codecs.c  .✅ [FIX 100.76] Skipping manual hw_frames_ctx release (avcodec_close will handle it)
07:26:11.232    ffmpeg_vid_codecs.c  .  [FIX 100.65] hw_device_ctx will be released by avcodec_close() (shared, ref-counted)
07:26:11.232    ffmpeg_vid_codecs.c  .✅ [FIX 100.79] Closing decoder using avcodec_free_context (replaces deprecated avcodec_close)
07:26:11.238    ffmpeg_vid_codecs.c  .🔍 [FIX 100.66 DIAG] Checking encoder: enc_ctx=0x7ecc015220, condition=1
07:26:11.238    ffmpeg_vid_codecs.c  .✅ [FIX 100.66 DIAG] Entering encoder cleanup
07:26:11.238    ffmpeg_vid_codecs.c  .✅ [VERSION 154 Step 1/3] Skipping encoder Flush (let avcodec_close auto-flush)
07:26:11.238    ffmpeg_vid_codecs.c  .✅ [VERSION 155 Step 2/3] Skipping hw_frames_ctx release (let avcodec_close handle it)
07:26:11.238    ffmpeg_vid_codecs.c  .  [VERSION 155 Step 2/3] hw_frames_ctx is NULL
07:26:11.238    ffmpeg_vid_codecs.c  .  [VERSION 155 Step 3/3] hw_device_ctx will be auto-released by avcodec_close()
07:26:11.238    ffmpeg_vid_codecs.c  .  [VERSION 155] hw_device_ctx will be released by avcodec_close() (shared, ref-counted)
07:26:11.238    ffmpeg_vid_codecs.c  .⚠️ [VERSION 156 Plan I] NOT calling avcodec_close() - Resource leak to avoid RKMPP race
07:26:11.238    ffmpeg_vid_codecs.c  .✅ [VERSION 156 Plan I] Encoder resources leaked (no avcodec_close) - Race condition avoided!
07:26:11.238    ffmpeg_vid_codecs.c  .✅ [FIX 100.71] Cleanup completed (WITHOUT mutex)
07:26:11.238    ffmpeg_vid_codecs.c  .✅ [FIX 100.72] Codec already closed (enc_ctx=NULL, dec_ctx=NULL)
07:26:11.238        udp0x55abb577d0  .UDP media transport destroyed
07:26:11.238       srtp0x55abcc2a50  .SRTP transport destroyed
07:26:11.238         avsync-call_00  .Removed media Video
07:26:11.238         avsync-call_00  .avsync-call_00 destroyed
07:26:11.238      vstrm0x7ecc010680  .Stream destroyed
07:26:11.238             vid_conf.c  .Removed video port 5 (qt_remote_video_sink), port count=1
07:26:11.239             vid_conf.c  .Removed video port 4 (qt_local_video_sink), port count=0
07:26:11.239                capdbuf  Buffer size adjusted from 2053 to 1457 (eff_cnt=1410)
07:26:11.297                capdbuf  Buffer size adjusted from 2097 to 1259 (eff_cnt=1410)
07:26:11.398                capdbuf  Buffer size adjusted from 2539 to 2043 (eff_cnt=1410)
07:26:11.456                capdbuf  Buffer size adjusted from 2683 to 2193 (eff_cnt=1410)
07:26:11
