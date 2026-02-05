     ┌────────────────────────────────────────────────────────────────────┐
     │                        • MobaXterm 12.3 •                          │
     │            (SSH client, X-server and networking tools)             │
     │                                                                    │
     │ ➤ SSH session to linaro@192.168.10.185                             │
     │   • SSH compression : ✔                                            │
     │   • SSH-browser     : ✔                                            │
     │   • X11-forwarding  : ✔  (remote display is forwarded through SSH) │
     │   • DISPLAY         : ✔  (automatically set on remote server)      │
     │                                                                    │
     │ ➤ For more info, ctrl+click on help or visit our website           │
     └────────────────────────────────────────────────────────────────────┘

Welcome to Ubuntu 20.04.6 LTS (GNU/Linux 5.10.226 aarch64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

System information as of Thu Feb  5 10:36:51 CST 2026

System load:   5.23 5.27 5.18   Up time:       2:46 hours
Memory usage:  8 % of 7851MB    IP:            10.83.50.73
CPU temp:      37°C             GPU temp:      37°C
Usage of /:    12% of 115G

Last login: Wed Feb  4 11:29:58 2026 from 192.168.10.142
linaro@enc:~$ ./run-ubuntu24-apt.sh
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
  Total reclaimed space: 1.579GB

[4/4] 磁盘状态检查...
  磁盘占用: 11%
  Docker 占用: 2.2G

==========================================
Belt Control System v3.5 - 启动应用
==========================================

non-network local connections being added to access control list
✅ X11 detected - using XCB with Mali GPU acceleration
Starting application with persistent data...
Qt Platform: xcb
kernel.core_pattern = /tmp/belt-control-cores/core.%e.%p.%t
=========================================
Belt Control System - 启动中...
=========================================

🔍 检测音频设备...
✅ 检测到 ES8388 音频芯片（Card 1），使用高品质音频输出
📝 生成 ALSA 配置文件...
✅ ALSA 配置已生成
   设备: ES8388
   ALSA: hw:1,0

📋 系统音频设备列表:
 0 [rockchiphdmiin ]: rockchip_hdmiin - rockchip,hdmiin
                      rockchip,hdmiin
 1 [rockchipes8388 ]: rockchip-es8388 - rockchip-es8388
                      rockchip-es8388
 2 [rockchiphdmi0  ]: rockchip-hdmi0 - rockchip-hdmi0
                      rockchip-hdmi0
 3 [rockchiphdmi1  ]: rockchip-hdmi1 - rockchip-hdmi1
                      rockchip-hdmi1
 4 [Device         ]: USB-Audio - USB PnP Sound Device
                      C-Media Electronics Inc. USB PnP Sound Device at usb-xhci-hcd.5.auto-1.2, full

=========================================
🚀 启动应用程序...
=========================================

=== Application starting ===
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
[DEBUG] 设备配置数据库: "/app/appdata/device_config.db"
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
[DEBUG] ✅ [DeviceConfigManager] 数据库连接成功: "/app/appdata/device_config.db"
[DEBUG] ✅ [DeviceConfigManager] 数据库表创建成功（包含电机/制动器/张紧控制表）
[DEBUG] ⏭️ [DeviceConfigManager] 数据已初始化，跳过
[DEBUG] ✅ [DeviceConfigManager] 数据库初始化完成
[DEBUG] ✅ ModbusTcpClient: Modbus TCP客户端已创建
[DEBUG] ✅ NetworkTask: 网络任务已创建
[WARNING] PulseAudioService: pa_context_connect() failed
[DEBUG]    ✅ 找到 192.168.x.x 网段地址: "192.168.10.185"
[DEBUG] [AudioNetworkSender] 初始化音频网络发送器
[DEBUG]    本地 IP: "192.168.10.185"
[DEBUG]    第3字节（IP[2]）: 10
[DEBUG]    组播地址（动态计算）: "224.1.10.1" : 8800
[DEBUG]    Opus 比特率: 16000 bps
[DEBUG]    ✅ UDP socket 绑定成功
[DEBUG]    ✅ 音频网络发送器初始化完成
[DEBUG] ✅ WebSocketClient 初始化完成
[DEBUG] ✅ AudioSenderWorker: 音频发送工作线程已创建（Qt::PreciseTimer）
[DEBUG] ✅ AudioNetworkTcpSender: 独立发送线程已创建
[DEBUG]    主线程: WebSocket 连接管理 + 音频编码（FFmpeg + Opus）
[DEBUG]    独立线程: 音频发送（定时器，20ms 精确定时）
[DEBUG] 📋 加载配置完成:
[DEBUG]    - ID: 0
[DEBUG]    - UUID: "Init"
[DEBUG]    - 名称: "皮带控制系统"
[DEBUG] ✅ AudioNetworkTcpSender 初始化完成
[DEBUG] 🎙️ SherpaOnnxTTS: 初始化TTS封装（进程通信模式）
[W][10057.927147] pw.conf      | [          conf.c: 1031 try_load_conf()] can't load config client-rt.conf: No such file or directory
[E][10057.927208] pw.conf      | [          conf.c: 1060 pw_conf_load_conf_for_context()] can't load config client-rt.conf: No such file or directory
[ALSOFT] (EE) Failed to create PipeWire event context (errno: 2)
[DEBUG] ✅ WebSocketClient 初始化完成
[DEBUG] ✅ AudioSenderWorker: 音频发送工作线程已创建（Qt::PreciseTimer）
[DEBUG] ✅ AudioNetworkTcpSender: 独立发送线程已创建
[DEBUG]    主线程: WebSocket 连接管理 + 音频编码（FFmpeg + Opus）
[DEBUG]    独立线程: 音频发送（定时器，20ms 精确定时）
[DEBUG] 📋 加载配置完成:
[DEBUG]    - ID: 0
[DEBUG]    - UUID: "Init"
[DEBUG]    - 名称: "皮带控制系统"
[DEBUG] ✅ AudioNetworkTcpSender 初始化完成
[DEBUG]    ✅ 找到 192.168.x.x 网段地址: "192.168.10.185"
[DEBUG] [AudioNetworkSender] 初始化音频网络发送器
[DEBUG]    本地 IP: "192.168.10.185"
[DEBUG]    第3字节（IP[2]）: 10
[DEBUG]    组播地址（动态计算）: "224.1.10.1" : 8800
[DEBUG]    Opus 比特率: 16000 bps
[DEBUG]    ✅ UDP socket 绑定成功
[DEBUG]    ✅ 音频网络发送器初始化完成
[DEBUG] ✅ CommonControl: 公共控制模块已创建
[DEBUG] 🔊 CommonControl: 音频输出已配置（使用 ALSA 默认设备 → ES8388）
[DEBUG] 🔊 CommonControl: 音频播放器已初始化
[DEBUG] ✅ UDP 服务发现已启动（端口 8600 ）
[DEBUG]    等待上位机广播配置 JSON...
[DEBUG] ✅ CommonControl: TCP 音频模块已启动 UDP 服务发现
[DEBUG] 🔄 开始批量预加载 2 个音频文件
[WARNING]    ⚠️ 文件不存在，跳过: "/app/appdata/audio/belt_start_1.mp3"
[WARNING]    ⚠️ 文件不存在，跳过: "/app/appdata/audio/belt_stop_1.mp3"
[DEBUG] ✅ 批量预加载完成
[DEBUG]    成功: 0 个
[DEBUG]    失败: 2 个
[DEBUG]    当前缓存文件数: 0
[DEBUG] ✅ CommonControl: 音频预加载完成（缓存文件数: 0 ）
[DEBUG] 🎙️ SherpaOnnxTTS: 初始化TTS引擎，模型目录: "/app/tts_models/vits-zh-aishell3"
[DEBUG] ✅ 找到TTS服务: "/app/sherpa_tts_service"
[DEBUG] 🚀 启动TTS服务进程...
[DEBUG] ✅ TTS服务进程已启动，PID: 41
[DEBUG] 📤 发送命令: "{\"command\":\"init\",\"model_dir\":\"/app/tts_models/vits-zh-aishell3\"}\n"
[DEBUG] 📥 收到响应: "{\"success\":true,\"message\":\"TTS engine initialized successfully. Sample rate: 8000Hz\"}"
[DEBUG] ✅ SherpaOnnxTTS初始化成功: "TTS engine initialized successfully. Sample rate: 8000Hz"
[DEBUG] ✅ CommonControl: TTS 语音合成器初始化成功
[DEBUG]    模型目录: "/app/tts_models/vits-zh-aishell3"
[DEBUG]    输出模式: 网络传输（TCP 模式 → 上位机）
[DEBUG] ✅ CommonControl: TTS 信号已连接到预警循环
[DEBUG]    删除旧的 TCP 发送器（自己创建的）
[DEBUG] 📡 停止独立发送线程...
[DEBUG] ✅ 独立发送线程已停止
[DEBUG] 📡 停止所有服务
[DEBUG] ✅ AudioNetworkTcpSender 析构完成
[DEBUG] ✅ WebSocketClient 析构完成
[DEBUG] ✅ SherpaOnnxTTS: 已设置共享的 TCP 发送器
[DEBUG]    删除旧的 UDP 发送器（自己创建的）
[DEBUG] [AudioNetworkSender] 销毁音频网络发送器
[DEBUG] ✅ SherpaOnnxTTS: 已设置共享的 UDP 发送器
[DEBUG] ✅ CommonControl: 已共享网络发送器给 TTS
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
[DEBUG] ✅ WebSocketClient 初始化完成
[DEBUG] ✅ AudioSenderWorker: 音频发送工作线程已创建（Qt::PreciseTimer）
[DEBUG] ✅ AudioNetworkTcpSender: 独立发送线程已创建
[DEBUG]    主线程: WebSocket 连接管理 + 音频编码（FFmpeg + Opus）
[DEBUG]    独立线程: 音频发送（定时器，20ms 精确定时）
[DEBUG] 📋 加载配置完成:
[DEBUG]    - ID: 0
[DEBUG]    - UUID: "Init"
[DEBUG]    - 名称: "皮带控制系统"
[DEBUG] ✅ AudioNetworkTcpSender 初始化完成
[DEBUG]    ✅ 找到 192.168.x.x 网段地址: "192.168.10.185"
[DEBUG] [AudioNetworkSender] 初始化音频网络发送器
[DEBUG]    本地 IP: "192.168.10.185"
[DEBUG]    第3字节（IP[2]）: 10
[DEBUG]    组播地址（动态计算）: "224.1.10.1" : 8800
[DEBUG]    Opus 比特率: 16000 bps
[DEBUG]    ✅ UDP socket 绑定成功
[DEBUG]    ✅ 音频网络发送器初始化完成
[DEBUG]   使用TTS模型: "vits-zh-aishell3"
[DEBUG]   模型目录: "/app/tts_models/vits-zh-aishell3"
[DEBUG]   语速: 0.9   音量: 1
[DEBUG] 🎙️ SherpaOnnxTTS: 初始化TTS引擎，模型目录: "/app/tts_models/vits-zh-aishell3"
[DEBUG] ✅ 找到TTS服务: "/app/sherpa_tts_service"
[DEBUG] 🚀 启动TTS服务进程...
[DEBUG] ✅ TTS服务进程已启动，PID: 50
[DEBUG] 📤 发送命令: "{\"command\":\"init\",\"model_dir\":\"/app/tts_models/vits-zh-aishell3\"}\n"
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
arm_release_ver: g24p0-00eac0, rk_so_ver: 8
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
[DEBUG] 🔧 [CONTACT DB] Initializing contact database...
[DEBUG] 📁 [CONTACT DB] Database path: "/app/appdata/contacts.db"
[DEBUG] 🚀 [ASYNC] FrameProcessorThread started
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
[DEBUG] ⚠️ [FIX 100.252] PJSIP not initialized, returning empty video codec list
[DEBUG] ⚠️ [FIX 100.252] PJSIP not initialized, returning empty codec list
[DEBUG] 📹 [FIX 100.251] Reading saved video device index: 0
[WARNING]    ⚠️ [FIX 100.251] Saved index 0 is out of range
[WARNING]       Valid range: 0 - -1
[WARNING]       Mapping size: 0
[WARNING]       Returning default index 0
[DEBUG] 📢 [FIX 100.250] Reading saved audio input device index: 0
[WARNING]    ⚠️ [FIX 100.250] Saved index 0 is out of range
[WARNING]       Valid range: 0 - -1
[WARNING]       Mapping size: 0
[WARNING]       Returning default index 0
[DEBUG] 🔊 [FIX 100.250] Reading saved audio output device index: 0
[WARNING]    ⚠️ [FIX 100.250] Saved index 0 is out of range
[WARNING]       Valid range: 0 - -1
[WARNING]       Mapping size: 0
[WARNING]       Returning default index 0
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
[DEBUG]    - parent: QQuickOverlay(0x5586048c80)
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
[DEBUG]    - parent: QQuickItem(0x5586c60b80)
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
[DEBUG] [Screen01] ✅ 组件加载完成
[DEBUG] [Screen01] 🎯 强制获取焦点...
[DEBUG] 🔍 [Screen01] ========== 焦点状态变化 ==========
[DEBUG] 🔍 [Screen01] activeFocus: ✅ 获得焦点
[DEBUG] 🔍 [Screen01] focus 属性: true
[DEBUG] 🔍 [Screen01] parent: QQuickLoader(0x5585ff0150)
[DEBUG] 🔍 [Screen01] parent.objectName:
[DEBUG] 🔍 [Screen01] =====================================
[DEBUG] [Screen01Form] ✅ 组件加载完成
[DEBUG] ✅ Input1 Screen01 加载成功
[DEBUG]    [布局] 屏幕尺寸: 0 x 0
[DEBUG] 🔍 [Input1Page] 缩放调试:
[DEBUG]    xScale (宽度缩放): 0.000
[DEBUG]    yScale (高度缩放): 0.000
[DEBUG]    预期显示尺寸: 0 x 0
[DEBUG] 🔗 [Input1Page] 设置 Screen01.currentPageIndex 绑定
[DEBUG]    input1Page.currentPageIndex = 0
[DEBUG] 📡 [Binding] Screen01.currentPageIndex 更新 = 0
[DEBUG]    Screen01.currentPageIndex = 0
[WARNING] qrc:/qt/qml/BeltControlQml/pages/ParameterSettings.qml:55:5: QML Back.ui: Cannot open: qrc:/qt/qml/BeltControlQml/pages/images/back2.svg
[WARNING] Qt Quick Layouts: Detected recursive rearrange. Aborting after two iterations.
[WARNING] Qt Quick Layouts: Detected recursive rearrange. Aborting after two iterations.
[WARNING] qrc:/qt/qml/BeltControlQml/pages/ControlPanel.qml:68:5: QML Back.ui: Cannot open: qrc:/qt/qml/BeltControlQml/pages/images/back2.svg
[WARNING] qrc:/qt/qml/BeltControlQml/pages/ControlPanel.qml:42:5: QML Connections: Detected function "onProtectionTriggered" in Connections element. This is probably intended to be a signal handler but no signal of the target matches the name.
[WARNING] qrc:/qt/qml/BeltControlQml/pages/ControlPanel.qml:42:5: QML Connections: Detected function "onProtectionRestored" in Connections element. This is probably intended to be a signal handler but no signal of the target matches the name.
[DEBUG] 🔍 [Screen01] ========== 焦点状态变化 ==========
[DEBUG] 🔍 [Screen01] activeFocus: ❌ 失去焦点
[DEBUG] 🔍 [Screen01] focus 属性: true
[DEBUG] 🔍 [Screen01] parent: QQuickLoader(0x5585ff0150)
[DEBUG] 🔍 [Screen01] parent.objectName:
[DEBUG] 🔍 [Screen01] =====================================
[DEBUG] [FULLSCREEN DEBUG] Screen size: 1920 x 1080
[DEBUG] [FULLSCREEN DEBUG] Window size: 1920 x 1080
[DEBUG] [FULLSCREEN DEBUG] Current visibility: 2
[DEBUG] [FULLSCREEN DEBUG] Platform: linux
[DEBUG] [FULLSCREEN DEBUG] Device 151 (1920x1080) detected, EGLFS naturally fullscreen
[DEBUG] Input1Page 已加载
[DEBUG] 🔍 [Input1Page] 缩放调试（Component.onCompleted）:
[DEBUG]    input1Page.width: 1920
[DEBUG]    input1Page.height: 1080
[DEBUG]    xScale (宽度缩放): 1.000
[DEBUG]    yScale (高度缩放): 1.000
[DEBUG]    预期显示尺寸: 1920 x 1080
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
[DEBUG] 🔍 [ControlPanel Head] 布局调试 v6:
[DEBUG]    root 尺寸: 1920 × 1080
[DEBUG]    容器原始尺寸: 1920 × 80
[DEBUG]    scaleFactor: 1.000
[DEBUG]    缩放后尺寸: 1920 × 80
[WARNING] qrc:/qt/qml/BeltControlQml/Input1/Input1Content/Screen01Form.ui.qml:19:5: Unable to assign [undefined] to QColor
[WARNING] qrc:/qt/qml/BeltControlQml/main.qml:412:17: Unable to assign [undefined] to QString
[WARNING] qrc:/qt/qml/BeltControlQml/components/sip_phone/pages/SipDialPage.qml:551: ReferenceError: micMuted is not defined
engine.load() completed
QML loaded successfully, starting event loop
[DEBUG] [Screen01] 📊 dataItems 有效数量: 12 / 12
[DEBUG] [Screen01] 🔄 初始化选中状态...
[DEBUG] [Screen01] 🔄 updateSelection 开始，selectedIndex: 0 有效组件: 12
[DEBUG] [Screen01] ✅ 组件 0 已选中
[DEBUG] [Screen01] 🔄 updateSelection 完成，成功更新 12 个组件
[DEBUG] [Screen01] 🖱️ 设置鼠标交互...
[DEBUG] [Screen01] 🖱️ 开始设置鼠标交互...
[DEBUG] [Screen01] ✅ 组件 0 鼠标交互已设置
[DEBUG] [Screen01] ✅ 组件 1 鼠标交互已设置
[DEBUG] [Screen01] ✅ 组件 2 鼠标交互已设置
[DEBUG] [Screen01] ✅ 组件 3 鼠标交互已设置
[DEBUG] [Screen01] ✅ 组件 4 鼠标交互已设置
[DEBUG] [Screen01] ✅ 组件 5 鼠标交互已设置
[DEBUG] [Screen01] ✅ 组件 6 鼠标交互已设置
[DEBUG] [Screen01] ✅ 组件 7 鼠标交互已设置
[DEBUG] [Screen01] ✅ 组件 8 鼠标交互已设置
[DEBUG] [Screen01] ✅ 组件 9 鼠标交互已设置
[DEBUG] [Screen01] ✅ 组件 10 鼠标交互已设置
[DEBUG] [Screen01] ✅ 组件 11 鼠标交互已设置
[DEBUG] [Screen01] 🖱️ 鼠标交互设置完成
Object created callback: obj=5585ade520
[DEBUG] ❌ [RINGTONE] Error: 1 Resource not found.
[DEBUG] ❌ [RINGTONE] Error: 1 GStreamer error: state change failed and some element failed to post a proper error message with the reason for the failure.
[DEBUG] ❌ [RINGTONE] Error: 1 Resource not found.
[DEBUG] ❌ [RINGTONE] Error: 1 GStreamer error: state change failed and some element failed to post a proper error message with the reason for the failure.
[DEBUG] 🔔 [RINGTONE] Using system ringtone: "C:/Windows/Media/Ring01.wav"
[DEBUG] 🔔 [RINGTONE] URL format: "file:///C:/Windows/Media/Ring01.wav"
[DEBUG] 🔔 [RINGTONE] Loaded custom ringtone: file:///C:/Windows/Media/Ring01.wav
[DEBUG] [SwipeView] 页面切换到索引: 1
[DEBUG] [SwipeView] 页面切换到索引: 2
[DEBUG] [SwipeView] 页面切换到索引: 3
[DEBUG] [SwipeView] 页面切换到索引: 4
[DEBUG] [SwipeView] 切换到 Input1Page，恢复 Screen01 焦点
[DEBUG] [SwipeView] 找到 Screen01，强制获取焦点
[DEBUG] 🔍 [Screen01] ========== 焦点状态变化 ==========
[DEBUG] 🔍 [Screen01] activeFocus: ✅ 获得焦点
[DEBUG] 🔍 [Screen01] focus 属性: true
[DEBUG] 🔍 [Screen01] parent: QQuickLoader(0x5585ff0150)
[DEBUG] 🔍 [Screen01] parent.objectName:
[DEBUG] 🔍 [Screen01] =====================================
[DEBUG] [Screen01] ⌨️ 按键事件 - Key: 16777237 焦点: ✅
[DEBUG] [Screen01] 📍 selectedIndex 变化: 4 → 行 1 列 0
[DEBUG] [Screen01] 🎯 导航成功: ↓ 下 - 索引 0 → 4
[DEBUG] [Screen01] 🔄 updateSelection 开始，selectedIndex: 4 有效组件: 12
[DEBUG] [Screen01] ✅ 组件 4 已选中
[DEBUG] [Screen01] 🔄 updateSelection 完成，成功更新 12 个组件
[DEBUG] [Screen01] ⌨️ 按键事件 - Key: 16777220 焦点: ✅
[DEBUG] [Screen01] ⏎ 回车键 - 打开设备设置对话框，索引: 4
[DEBUG] 🔍 [Screen01] ========== 打开对话框 ==========
[DEBUG] 🔍 [Screen01] 当前选中索引: 4
[DEBUG] 🔍 [Screen01] 打开前 - activeFocus: true
[DEBUG] 🔍 [Screen01] 打开前 - focus: true
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_info/pages/SerialPortParamsTab.qml: No such file or directory
[DEBUG] ✅ [SerialPortConfigPanel] Component.onCompleted 开始
[DEBUG] ✅ [SerialPortConfigPanel] currentSerialPort: null
[DEBUG] ✅ [SerialPortConfigPanel] 使用 Tab 架构
[DEBUG] ✅ [SerialPortConfigPanel] Component.onCompleted 完成
[DEBUG] 🔍 [SerialPortControlPage] serialConfigPanel Loader 状态变化: 1
[DEBUG] ✅ [SerialPortControlPage] serialConfigPanel Loader 加载完成
[DEBUG] ✅ [SerialPortControlPage] SerialPortConfigPanel 加载成功
[DEBUG] ✅ [SerialPortConfigPanel] currentSerialPort 变化: [object Object]
[DEBUG]    - 串口名称: COM1
[DEBUG]    - 设备路径: /dev/ttyS0
[DEBUG]    - 串口类型: RS422
[DEBUG] ✅ [SerialPortControlPage] SerialPortListPanel 加载成功
[DEBUG] ✅ [SerialPortControlPage] Component.onCompleted 开始
[DEBUG] ✅ [SerialPortControlPage] 串口数量: 6
[DEBUG] 🔍 [SerialPortControlPage] serialListPanel.status: 1
[DEBUG] 🔍 [SerialPortControlPage] serialListPanel.item: SerialPortListPanel_QMLTYPE_266(0x5586791220)
[DEBUG] 🔍 [SerialPortControlPage] serialConfigPanel.status: 1
[DEBUG] 🔍 [SerialPortControlPage] serialConfigPanel.item: SerialPortConfigPanel_QMLTYPE_263(0x55888ef3c0)
[DEBUG] ✅ [SerialPortControlPage] focusItemIndex 变化: 0 → 更新 currentSerialIndex
[DEBUG] ✅ [SerialPortControlPage] 初始化焦点 - focusSubArea: 0 focusItemIndex: 0
[DEBUG] ✅ [SerialPortControlPage] Component.onCompleted 完成
[DEBUG] ✅ [SerialPortControlPage] NavigationManager 初始化完成
[DEBUG] ✅ [DeviceSettingsDialog] SerialPortControlPage 加载成功
[DEBUG] ✅ [BasicConfigPage] NetworkParametersSection 加载成功
[DEBUG] ✅ [BasicConfigPage] BasicParametersSection 加载成功
[DEBUG] ✅ [DeviceSettingsDialog] BasicConfigPage 加载成功
[DEBUG] ✅ [DeviceSettingsDialog] Qt 虚拟键盘已初始化
[DEBUG] 🔍 [Screen01] focus 属性变化: false
[DEBUG] 🔍 [Screen01] ========== 焦点状态变化 ==========
[DEBUG] 🔍 [Screen01] activeFocus: ❌ 失去焦点
[DEBUG] 🔍 [Screen01] focus 属性: false
[DEBUG] 🔍 [Screen01] parent: QQuickLoader(0x5585ff0150)
[DEBUG] 🔍 [Screen01] parent.objectName:
[DEBUG] 🔍 [Screen01] =====================================
[DEBUG] 🔍 [DeviceSettingsDialog root] activeFocus 变化: true
[DEBUG] ✅ [DeviceSettingsDialog] 对话框已获取焦点
[DEBUG] ✅ [DEBUG] StackLayout 宽度: 1369
[DEBUG] ✅ [DEBUG] StackLayout 高度: 703
[DEBUG] ✅ [DEBUG] StackLayout 子元素数量: 8
[DEBUG] ✅ [DEBUG] SwitchInputPage Loader 宽度: 0
[DEBUG] ✅ [DEBUG] SwitchInputPage Loader 高度: 0
[DEBUG] 🔍 [Screen01] 对话框创建成功
[DEBUG] 🔍 [Screen01] dialog.parent === root: true
[DEBUG] 🔍 [Screen01] dialog.parent: Screen01_QMLTYPE_233(0x5587285770)
[DEBUG] 🔍 [Screen01] dialog.parentContainer === root: true
[DEBUG] 🔍 [Screen01] 对话框已显示
[DEBUG] 🔍 [Screen01] 打开后 - activeFocus: false
[DEBUG] 🔍 [Screen01] 打开后 - focus: false
[DEBUG] 🔍 [Screen01] =====================================
[DEBUG] [Screen01] 🎯 导航成功:  - 索引 4 → 4
[DEBUG] [Screen01] 🔄 updateSelection 开始，selectedIndex: 4 有效组件: 12
[DEBUG] [Screen01] ✅ 组件 4 已选中
[DEBUG] [Screen01] 🔄 updateSelection 完成，成功更新 12 个组件
[WARNING] ⚠️ [SerialPortControlPage] 当前 Tab 未加载
[DEBUG] ✅ [SerialPortControlPage] 初始参数数量: 0
[DEBUG] ✅ [导航] 上键 - 当前区域: 1 当前类别: 0
[DEBUG] ✅ [导航] 下键 - 当前区域: 1 当前类别: 0
[DEBUG] ✅ [DeviceSettingsDialog] 切换到类别 1 恢复内容索引: 0
[DEBUG] ✅ [SwitchInputPage] Component.onCompleted 开始
[DEBUG] ✅ [SwitchInputPage] Component.onCompleted 完成
[DEBUG] ✅ [DEBUG] SwitchInputPage 右侧区域宽度: 560
[DEBUG] ✅ [DEBUG] SwitchInputPage 右侧区域高度: 600
[DEBUG] ✅ [DEBUG] SwitchInputPage ScrollView 宽度: 530
[DEBUG] ✅ [DEBUG] SwitchInputPage ScrollView 高度: 413
[DEBUG] ✅ [DEBUG] GridLayout 加载完成
[DEBUG]    宽度: 371 高度: 348
[DEBUG]    parent.width: 270
[DEBUG]    paramScrollView.width: 530
[DEBUG]    计算宽度 (70%): 371
[DEBUG] ✅ [DEBUG] onLoaded 开始
[DEBUG] ✅ [DEBUG] 设置 virtualKeyboard: QtVirtualKeyboardIntegration_QMLTYPE_245(0x558676a750)
[DEBUG] ✅ [DEBUG] onLoaded 完成
[DEBUG] 🔍 [串口控制同步] onCurrentCategoryChanged - currentCategory: 1 currentFocusArea: 1
[DEBUG] ✅ [串口控制同步] 切换到其他类别 - 清除 focusItemIndex
[DEBUG] ✅ [SwitchInputPage] Qt.callLater 回调执行 - 事件循环正常
[DEBUG] ✅ [DEBUG] Qt.callLater 回调执行 - 事件循环正常
[DEBUG] ✅ [导航] 下键 - 当前区域: 1 当前类别: 1
[DEBUG] ✅ [DeviceSettingsDialog] 切换到类别 2 恢复内容索引: 0
[DEBUG] ✅ [AnalogInputPage] 开始加载设备 1 的模拟量保护配置
[DEBUG] ✅ [AnalogInputPage] 从数据库加载了 7 个保护项
[DEBUG] ✅ [AnalogInputPage] 数据库配置加载完成
[DEBUG] ✅ [AnalogInputPage] 从数据库加载完整参数: 速度
[DEBUG] ✅ [AnalogInputPage] 外层 ColumnLayout 宽度: 1178
[DEBUG] ✅ [AnalogInputPage] ScrollView 宽度: 1178
[DEBUG] ✅ [AnalogInputPage] ScrollView contentWidth: 1200
[DEBUG] ✅ [AnalogInputPage] ScrollView 内部 ColumnLayout 宽度: 1200
[DEBUG] ✅ [AnalogInputPage] ScrollView 内部 ColumnLayout parent.width: 1200
[DEBUG] ✅ [DeviceSettingsDialog] AnalogInputPage 加载成功
[DEBUG] 🔍 [串口控制同步] onCurrentCategoryChanged - currentCategory: 2 currentFocusArea: 1
[DEBUG] ✅ [串口控制同步] 切换到其他类别 - 清除 focusItemIndex
[DEBUG] ✅ [导航] 下键 - 当前区域: 1 当前类别: 2
[DEBUG] ✅ [DeviceSettingsDialog] 切换到类别 3 恢复内容索引: 0
[DEBUG] 🔵 [反馈通道焦点指示器] 组件加载完成
[DEBUG]   - 初始 border.color: #00000000
[DEBUG]   - 初始 root.focusParamIndex: 0
[DEBUG]   - 初始 width: 185 height: 60
[DEBUG]   - 初始 x: 0 y: 0
[DEBUG]   - 初始 z: 1000
[DEBUG] 🔵 [模块地址焦点指示器] 组件加载完成
[DEBUG]   - 初始 border.color: #00000000
[DEBUG]   - 初始 root.focusParamIndex: 0
[DEBUG]   - 初始 width: 185 height: 60
[DEBUG]   - 初始 x: 0 y: 0
[DEBUG]   - 初始 z: 1000
[DEBUG] 🔍 [DEBUG] 背景图片切换 - 电机 1 source: ../../../images/bhNameBK1.png currentMotorIndex: 0
[DEBUG] 🔍 [DEBUG] 背景图片组件创建 - 电机 1 初始 source: ../../../images/bhNameBK1.png
[DEBUG] ✅ [MotorControlPage] NavigationManager 初始化完成
[DEBUG] ✅ [MotorControlPage] focusItemIndex 变化: 0 → 同步 currentMotorIndex
[DEBUG] ✅ [MotorControlPage] 初始状态已同步 - focusItemIndex: 0
[DEBUG] ✅ [DeviceSettingsDialog] MotorControlPage 加载成功
[DEBUG] 🔍 [串口控制同步] onCurrentCategoryChanged - currentCategory: 3 currentFocusArea: 1
[DEBUG] ✅ [串口控制同步] 切换到其他类别 - 清除 focusItemIndex
[DEBUG] ✅ [NavigationManager] 更新 lastParamIndex: 4 （参数数量: 5 ）
[DEBUG] 🔍 [DEBUG] 背景图片切换 - 电机 2 source: ../../../images/bhNameBK.png currentMotorIndex: 0
[DEBUG] 🔍 [DEBUG] 背景图片组件创建 - 电机 2 初始 source: ../../../images/bhNameBK.png
[DEBUG] 🔍 [DEBUG] 背景图片切换 - 电机 3 source: ../../../images/bhNameBK.png currentMotorIndex: 0
[DEBUG] 🔍 [DEBUG] 背景图片组件创建 - 电机 3 初始 source: ../../../images/bhNameBK.png
[DEBUG] 🔍 [DEBUG] 背景图片切换 - 电机 4 source: ../../../images/bhNameBK.png currentMotorIndex: 0
[DEBUG] 🔍 [DEBUG] 背景图片组件创建 - 电机 4 初始 source: ../../../images/bhNameBK.png
[DEBUG] 🔍 [DEBUG] 背景图片切换 - 电机 5 source: ../../../images/bhNameBK.png currentMotorIndex: 0
[DEBUG] 🔍 [DEBUG] 背景图片组件创建 - 电机 5 初始 source: ../../../images/bhNameBK.png
[DEBUG] 🔍 [DEBUG] 背景图片切换 - 电机 6 source: ../../../images/bhNameBK.png currentMotorIndex: 0
[DEBUG] 🔍 [DEBUG] 背景图片组件创建 - 电机 6 初始 source: ../../../images/bhNameBK.png
[DEBUG] 🔍 [DEBUG] 背景图片切换 - 电机 7 source: ../../../images/bhNameBK.png currentMotorIndex: 0
[DEBUG] 🔍 [DEBUG] 背景图片组件创建 - 电机 7 初始 source: ../../../images/bhNameBK.png
[DEBUG] 🔍 [DEBUG] 背景图片切换 - 电机 8 source: ../../../images/bhNameBK.png currentMotorIndex: 0
[DEBUG] 🔍 [DEBUG] 背景图片组件创建 - 电机 8 初始 source: ../../../images/bhNameBK.png
[DEBUG] ✅ [导航] 下键 - 当前区域: 1 当前类别: 3
[DEBUG] ✅ [DeviceSettingsDialog] 切换到类别 4 恢复内容索引: 0
[DEBUG] ✅ [BrakeControlPage] NavigationManager 初始化完成
[DEBUG] ✅ [BrakeControlPage] focusItemIndex 变化: 0 → 更新 currentBrakeIndex 和 brakeListIndex
[DEBUG] 🔍 [BrakeListPanel] focusItemIndex 变化: 0
[DEBUG] ✅ [BrakeControlPage] 初始状态已同步 - focusItemIndex: 0
[DEBUG] ✅ [DeviceSettingsDialog] BrakeControlPage 加载成功
[DEBUG] 🔍 [串口控制同步] onCurrentCategoryChanged - currentCategory: 4 currentFocusArea: 1
[DEBUG] ✅ [串口控制同步] 切换到其他类别 - 清除 focusItemIndex
[DEBUG] 🔍 [BrakeListPanel] focusItemIndex 变化: -1
[DEBUG] ✅ [导航] 下键 - 当前区域: 1 当前类别: 4
[DEBUG] ✅ [DeviceSettingsDialog] 切换到类别 5 恢复内容索引: 0
[DEBUG] ✅ [TensionControlPage] NavigationManager 初始化完成
[DEBUG] ✅ [TensionControlPage] focusItemIndex 变化: 0 → 更新 currentControlIndex 和 controlListIndex
[DEBUG] ✅ [TensionControlPage] 初始状态已同步 - focusItemIndex: 0
[DEBUG] ✅ [DeviceSettingsDialog] TensionControlPage 加载成功
[DEBUG] 🔍 [串口控制同步] onCurrentCategoryChanged - currentCategory: 5 currentFocusArea: 1
[DEBUG] ✅ [串口控制同步] 切换到其他类别 - 清除 focusItemIndex
[DEBUG] ✅ [导航] 下键 - 当前区域: 1 当前类别: 5
[DEBUG] ✅ [DeviceSettingsDialog] 切换到类别 6 恢复内容索引: 0
[DEBUG] 🔍 [串口控制同步] onCurrentCategoryChanged - currentCategory: 6 currentFocusArea: 1
[DEBUG] ✅ [串口控制同步] 切换到其他类别 - 清除 focusItemIndex
[DEBUG] ✅ [导航] 右键 - 当前区域: 1
[DEBUG] 🔍 [串口控制同步] onCurrentFocusAreaChanged - currentFocusArea: 2 currentCategory: 6
[DEBUG] ✅ [串口控制同步] 焦点进入内容区域 - 设置 focusSubArea=0, focusItemIndex= 0
[DEBUG] ✅ [SerialPortControlPage] focusItemIndex 变化: 0 → 更新 currentSerialIndex
[DEBUG] ✅ [DeviceSettingsDialog] 同步串口控制列表焦点: 0
[DEBUG] ✅ [导航] 右键后区域: 2
[DEBUG] ✅ [导航] 右键 - 当前区域: 2
[DEBUG] 🔍 [串口控制导航] case 2 开始 - currentCategory: 6
[DEBUG] 🔍 [串口控制导航] getCurrentPage 返回: 有效对象
[DEBUG] 🔍 [串口控制导航] currentPage.focusSubArea 类型: number
[DEBUG] 🔍 [串口控制导航] currentPage.focusSubArea 值: 0
[DEBUG] 🔍 [串口控制导航] 进入子区域导航处理
[DEBUG] 🔍 [串口控制导航] isSerialPortControlPage: true
[DEBUG] 🔍 [串口控制导航] 右键 - 调用 NavigationManager.handleDirectionKey
[DEBUG] ✅ [NavigationManager] 方向键: Right 当前区域: A 当前索引: 0
[DEBUG] ✅ [NavigationManager] 切换区域: A → B
[DEBUG] ✅ [SerialPortControlPage] 区域变化: B
[DEBUG] 🔍 [SerialPortControlPage] focusSubArea 变化: 1
[DEBUG] 🔍 [SerialPortControlPage] 当前状态 - focusItemIndex: 0 currentSerialIndex: 0
[DEBUG] 🔍 [串口控制导航] NavigationManager.handleDirectionKey 返回
[DEBUG]    - currentPage.focusSubArea: 1
[DEBUG]    - currentPage.focusParamIndex: -1
[DEBUG] ✅ [导航] 右键 - 当前区域: 2
[DEBUG] 🔍 [串口控制导航] case 2 开始 - currentCategory: 6
[DEBUG] 🔍 [串口控制导航] getCurrentPage 返回: 有效对象
[DEBUG] 🔍 [串口控制导航] currentPage.focusSubArea 类型: number
[DEBUG] 🔍 [串口控制导航] currentPage.focusSubArea 值: 1
[DEBUG] 🔍 [串口控制导航] 进入子区域导航处理
[DEBUG] 🔍 [串口控制导航] isSerialPortControlPage: true
[DEBUG] 🔍 [串口控制导航] 右键 - 调用 NavigationManager.handleDirectionKey
[DEBUG] ✅ [NavigationManager] 方向键: Right 当前区域: B 当前索引: 0
[DEBUG] ✅ [SerialPortControlPage] Tab 索引变化: 1
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_info/pages/SerialPortSendTab.qml: No such file or directory
[DEBUG] ✅ [SerialPortControlPage] Tab 切换: 1
[DEBUG] ✅ [SerialPortControlPage] 已同步 currentTabIndex 到 SerialPortConfigPanel: 1
[DEBUG] ✅ [NavigationManager] Tab索引: 1 （参数区自动切换显示）
[DEBUG] 🔍 [串口控制导航] NavigationManager.handleDirectionKey 返回
[DEBUG]    - currentPage.focusSubArea: 1
[DEBUG]    - currentPage.focusParamIndex: -1
[WARNING] ⚠️ [SerialPortControlPage] 当前 Tab 未加载
[DEBUG] ✅ [SerialPortControlPage] Tab 切换后参数数量: 0
[DEBUG] ✅ [导航] 左键 - 当前区域: 2
[DEBUG] ✅ [导航] 串口控制页面左键 - 调用NavigationManager
[DEBUG] ✅ [NavigationManager] 方向键: Left 当前区域: B 当前索引: 1
[DEBUG] ✅ [SerialPortControlPage] Tab 索引变化: 0
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_info/pages/SerialPortParamsTab.qml: No such file or directory
[DEBUG] ✅ [SerialPortControlPage] Tab 切换: 0
[DEBUG] ✅ [SerialPortControlPage] 已同步 currentTabIndex 到 SerialPortConfigPanel: 0
[DEBUG] ✅ [NavigationManager] Tab索引: 0 （参数区自动切换显示）
[WARNING] ⚠️ [SerialPortControlPage] 当前 Tab 未加载
[DEBUG] ✅ [SerialPortControlPage] Tab 切换后参数数量: 0
[DEBUG] ✅ [导航] 右键 - 当前区域: 2
[DEBUG] 🔍 [串口控制导航] case 2 开始 - currentCategory: 6
[DEBUG] 🔍 [串口控制导航] getCurrentPage 返回: 有效对象
[DEBUG] 🔍 [串口控制导航] currentPage.focusSubArea 类型: number
[DEBUG] 🔍 [串口控制导航] currentPage.focusSubArea 值: 1
[DEBUG] 🔍 [串口控制导航] 进入子区域导航处理
[DEBUG] 🔍 [串口控制导航] isSerialPortControlPage: true
[DEBUG] 🔍 [串口控制导航] 右键 - 调用 NavigationManager.handleDirectionKey
[DEBUG] ✅ [NavigationManager] 方向键: Right 当前区域: B 当前索引: 0
[DEBUG] ✅ [SerialPortControlPage] Tab 索引变化: 1
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_info/pages/SerialPortSendTab.qml: No such file or directory
[DEBUG] ✅ [SerialPortControlPage] Tab 切换: 1
[DEBUG] ✅ [SerialPortControlPage] 已同步 currentTabIndex 到 SerialPortConfigPanel: 1
[DEBUG] ✅ [NavigationManager] Tab索引: 1 （参数区自动切换显示）
[DEBUG] 🔍 [串口控制导航] NavigationManager.handleDirectionKey 返回
[DEBUG]    - currentPage.focusSubArea: 1
[DEBUG]    - currentPage.focusParamIndex: -1
[WARNING] ⚠️ [SerialPortControlPage] 当前 Tab 未加载
[DEBUG] ✅ [SerialPortControlPage] Tab 切换后参数数量: 0
[DEBUG] ✅ [导航] 右键 - 当前区域: 2
[DEBUG] 🔍 [串口控制导航] case 2 开始 - currentCategory: 6
[DEBUG] 🔍 [串口控制导航] getCurrentPage 返回: 有效对象
[DEBUG] 🔍 [串口控制导航] currentPage.focusSubArea 类型: number
[DEBUG] 🔍 [串口控制导航] currentPage.focusSubArea 值: 1
[DEBUG] 🔍 [串口控制导航] 进入子区域导航处理
[DEBUG] 🔍 [串口控制导航] isSerialPortControlPage: true
[DEBUG] 🔍 [串口控制导航] 右键 - 调用 NavigationManager.handleDirectionKey
[DEBUG] ✅ [NavigationManager] 方向键: Right 当前区域: B 当前索引: 1
[DEBUG] ✅ [SerialPortControlPage] Tab 索引变化: 2
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_info/pages/SerialPortReceiveTab.qml: No such file or directory
[DEBUG] ✅ [SerialPortControlPage] Tab 切换: 2
[DEBUG] ✅ [SerialPortControlPage] 已同步 currentTabIndex 到 SerialPortConfigPanel: 2
[DEBUG] ✅ [NavigationManager] Tab索引: 2 （参数区自动切换显示）
[DEBUG] 🔍 [串口控制导航] NavigationManager.handleDirectionKey 返回
[DEBUG]    - currentPage.focusSubArea: 1
[DEBUG]    - currentPage.focusParamIndex: -1
[WARNING] ⚠️ [SerialPortControlPage] 当前 Tab 未加载
[DEBUG] ✅ [SerialPortControlPage] Tab 切换后参数数量: 0
[DEBUG] ✅ [导航] 左键 - 当前区域: 2
[DEBUG] ✅ [导航] 串口控制页面左键 - 调用NavigationManager
[DEBUG] ✅ [NavigationManager] 方向键: Left 当前区域: B 当前索引: 2
[DEBUG] ✅ [SerialPortControlPage] Tab 索引变化: 1
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_info/pages/SerialPortSendTab.qml: No such file or directory
[DEBUG] ✅ [SerialPortControlPage] Tab 切换: 1
[DEBUG] ✅ [SerialPortControlPage] 已同步 currentTabIndex 到 SerialPortConfigPanel: 1
[DEBUG] ✅ [NavigationManager] Tab索引: 1 （参数区自动切换显示）
[WARNING] ⚠️ [SerialPortControlPage] 当前 Tab 未加载
[DEBUG] ✅ [SerialPortControlPage] Tab 切换后参数数量: 0
[DEBUG] ✅ [导航] 左键 - 当前区域: 2
[DEBUG] ✅ [导航] 串口控制页面左键 - 调用NavigationManager
[DEBUG] ✅ [NavigationManager] 方向键: Left 当前区域: B 当前索引: 1
[DEBUG] ✅ [SerialPortControlPage] Tab 索引变化: 0
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_info/pages/SerialPortParamsTab.qml: No such file or directory
[DEBUG] ✅ [SerialPortControlPage] Tab 切换: 0
[DEBUG] ✅ [SerialPortControlPage] 已同步 currentTabIndex 到 SerialPortConfigPanel: 0
[DEBUG] ✅ [NavigationManager] Tab索引: 0 （参数区自动切换显示）
[WARNING] ⚠️ [SerialPortControlPage] 当前 Tab 未加载
[DEBUG] ✅ [SerialPortControlPage] Tab 切换后参数数量: 0
[DEBUG] ✅ [导航] 右键 - 当前区域: 2
[DEBUG] 🔍 [串口控制导航] case 2 开始 - currentCategory: 6
[DEBUG] 🔍 [串口控制导航] getCurrentPage 返回: 有效对象
[DEBUG] 🔍 [串口控制导航] currentPage.focusSubArea 类型: number
[DEBUG] 🔍 [串口控制导航] currentPage.focusSubArea 值: 1
[DEBUG] 🔍 [串口控制导航] 进入子区域导航处理
[DEBUG] 🔍 [串口控制导航] isSerialPortControlPage: true
[DEBUG] 🔍 [串口控制导航] 右键 - 调用 NavigationManager.handleDirectionKey
[DEBUG] ✅ [NavigationManager] 方向键: Right 当前区域: B 当前索引: 0
[DEBUG] ✅ [SerialPortControlPage] Tab 索引变化: 1
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_info/pages/SerialPortSendTab.qml: No such file or directory
[DEBUG] ✅ [SerialPortControlPage] Tab 切换: 1
[DEBUG] ✅ [SerialPortControlPage] 已同步 currentTabIndex 到 SerialPortConfigPanel: 1
[DEBUG] ✅ [NavigationManager] Tab索引: 1 （参数区自动切换显示）
[DEBUG] 🔍 [串口控制导航] NavigationManager.handleDirectionKey 返回
[DEBUG]    - currentPage.focusSubArea: 1
[DEBUG]    - currentPage.focusParamIndex: -1
[WARNING] ⚠️ [SerialPortControlPage] 当前 Tab 未加载
[DEBUG] ✅ [SerialPortControlPage] Tab 切换后参数数量: 0
[DEBUG] ✅ [导航] 左键 - 当前区域: 2
[DEBUG] ✅ [导航] 串口控制页面左键 - 调用NavigationManager
[DEBUG] ✅ [NavigationManager] 方向键: Left 当前区域: B 当前索引: 1
[DEBUG] ✅ [SerialPortControlPage] Tab 索引变化: 0
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_info/pages/SerialPortParamsTab.qml: No such file or directory
[DEBUG] ✅ [SerialPortControlPage] Tab 切换: 0
[DEBUG] ✅ [SerialPortControlPage] 已同步 currentTabIndex 到 SerialPortConfigPanel: 0
[DEBUG] ✅ [NavigationManager] Tab索引: 0 （参数区自动切换显示）
[WARNING] ⚠️ [SerialPortControlPage] 当前 Tab 未加载
[DEBUG] ✅ [SerialPortControlPage] Tab 切换后参数数量: 0
[DEBUG] ✅ [导航] 右键 - 当前区域: 2
[DEBUG] 🔍 [串口控制导航] case 2 开始 - currentCategory: 6
[DEBUG] 🔍 [串口控制导航] getCurrentPage 返回: 有效对象
[DEBUG] 🔍 [串口控制导航] currentPage.focusSubArea 类型: number
[DEBUG] 🔍 [串口控制导航] currentPage.focusSubArea 值: 1
[DEBUG] 🔍 [串口控制导航] 进入子区域导航处理
[DEBUG] 🔍 [串口控制导航] isSerialPortControlPage: true
[DEBUG] 🔍 [串口控制导航] 右键 - 调用 NavigationManager.handleDirectionKey
[DEBUG] ✅ [NavigationManager] 方向键: Right 当前区域: B 当前索引: 0
[DEBUG] ✅ [SerialPortControlPage] Tab 索引变化: 1
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_info/pages/SerialPortSendTab.qml: No such file or directory
[DEBUG] ✅ [SerialPortControlPage] Tab 切换: 1
[DEBUG] ✅ [SerialPortControlPage] 已同步 currentTabIndex 到 SerialPortConfigPanel: 1
[DEBUG] ✅ [NavigationManager] Tab索引: 1 （参数区自动切换显示）
[DEBUG] 🔍 [串口控制导航] NavigationManager.handleDirectionKey 返回
[DEBUG]    - currentPage.focusSubArea: 1
[DEBUG]    - currentPage.focusParamIndex: -1
[WARNING] ⚠️ [SerialPortControlPage] 当前 Tab 未加载
[DEBUG] ✅ [SerialPortControlPage] Tab 切换后参数数量: 0
[DEBUG] ✅ [导航] 右键 - 当前区域: 2
[DEBUG] 🔍 [串口控制导航] case 2 开始 - currentCategory: 6
[DEBUG] 🔍 [串口控制导航] getCurrentPage 返回: 有效对象
[DEBUG] 🔍 [串口控制导航] currentPage.focusSubArea 类型: number
[DEBUG] 🔍 [串口控制导航] currentPage.focusSubArea 值: 1
[DEBUG] 🔍 [串口控制导航] 进入子区域导航处理
[DEBUG] 🔍 [串口控制导航] isSerialPortControlPage: true
[DEBUG] 🔍 [串口控制导航] 右键 - 调用 NavigationManager.handleDirectionKey
[DEBUG] ✅ [NavigationManager] 方向键: Right 当前区域: B 当前索引: 1
[DEBUG] ✅ [SerialPortControlPage] Tab 索引变化: 2
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_info/pages/SerialPortReceiveTab.qml: No such file or directory
[DEBUG] ✅ [SerialPortControlPage] Tab 切换: 2
[DEBUG] ✅ [SerialPortControlPage] 已同步 currentTabIndex 到 SerialPortConfigPanel: 2
[DEBUG] ✅ [NavigationManager] Tab索引: 2 （参数区自动切换显示）
[DEBUG] 🔍 [串口控制导航] NavigationManager.handleDirectionKey 返回
[DEBUG]    - currentPage.focusSubArea: 1
[DEBUG]    - currentPage.focusParamIndex: -1
[WARNING] ⚠️ [SerialPortControlPage] 当前 Tab 未加载
[DEBUG] ✅ [SerialPortControlPage] Tab 切换后参数数量: 0
[DEBUG] ✅ [导航] 右键 - 当前区域: 2
[DEBUG] 🔍 [串口控制导航] case 2 开始 - currentCategory: 6
[DEBUG] 🔍 [串口控制导航] getCurrentPage 返回: 有效对象
[DEBUG] 🔍 [串口控制导航] currentPage.focusSubArea 类型: number
[DEBUG] 🔍 [串口控制导航] currentPage.focusSubArea 值: 1
[DEBUG] 🔍 [串口控制导航] 进入子区域导航处理
[DEBUG] 🔍 [串口控制导航] isSerialPortControlPage: true
[DEBUG] 🔍 [串口控制导航] 右键 - 调用 NavigationManager.handleDirectionKey
[DEBUG] ✅ [NavigationManager] 方向键: Right 当前区域: B 当前索引: 2
[DEBUG] ✅ [SerialPortControlPage] Tab 索引变化: 3
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_info/pages/ModbusRegisterTab.qml: No such file or directory
[DEBUG] ✅ [SerialPortControlPage] Tab 切换: 3
[DEBUG] ✅ [SerialPortControlPage] 已同步 currentTabIndex 到 SerialPortConfigPanel: 3
[DEBUG] ✅ [NavigationManager] Tab索引: 3 （参数区自动切换显示）
[DEBUG] 🔍 [串口控制导航] NavigationManager.handleDirectionKey 返回
[DEBUG]    - currentPage.focusSubArea: 1
[DEBUG]    - currentPage.focusParamIndex: -1
[WARNING] ⚠️ [SerialPortControlPage] 当前 Tab 未加载
[DEBUG] ✅ [SerialPortControlPage] Tab 切换后参数数量: 0
