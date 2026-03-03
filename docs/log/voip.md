
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
  Total reclaimed space: 0B

[4/4] 磁盘状态检查...
  磁盘占用: 21%
  Docker 占用: 5.4G

==========================================
Belt Control System v3.5 - 启动应用
==========================================

non-network local connections being added to access control list
✅ X11 detected - using XCB with Mali GPU acceleration
Starting application with persistent data...
Qt Platform: xcb
kernel.core_pattern = /tmp/belt-control-cores/core.%e.%p.%t
=========================================
Belt Control System - Starting...
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

=========================================
Setting up PaddleSpeech model paths...
=========================================
✅ 使用容器内模型路径（Docker 挂载）
📂 模型基础路径: /app/tts_models/paddlespeech/models
📂 PADDLESPEECH_HOME: /app/tts_models/paddlespeech
✅ 已设置 PADDLESPEECH_HOME=/app/tts_models/paddlespeech
✅ 已设置 PPSPEECH_HOME=/app/tts_models/paddlespeech
✅ PaddleSpeech conf symlink created.
✅ PaddleSpeech datasets symlink created.
✅ PaddleSpeech model symlinks created.

=========================================
Setting up PaddleNLP model symlinks...
=========================================
✅ 使用容器内 PaddleNLP 路径（Docker 挂载）
📂 PaddleNLP 基础路径: /app/tts_models/paddlenlp
✅ PaddleNLP model symlinks created.

=========================================
Patching G2PW config for offline use...
=========================================
✅ G2PW config already patched or different format

=========================================
Launching application...
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
Registering TTSConfigManager...
TTSConfigManager registered to QML
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
[DEBUG] ✅ DeviceDatabase: 从配置文件加载了 16 个设备
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
[CRITICAL] "创建device_digital_protections表失败: near \"/\": syntax error Unable to execute statement"
[DEBUG] ✅ [SerialPortController] 串口配置初始化完成 - 6个串口
[DEBUG] ✅ [SerialPortController] 配置已加载
[DEBUG] ✅ [SerialPortController] 初始化完成
[DEBUG] ✅ [ModbusController] 初始化完成
[DEBUG] ✅ [ModbusSlaveController] 构造函数
[DEBUG] ✅ [ModbusSlaveController] 初始化寄存器映射
[DEBUG]    - 保持寄存器数量: 100
[DEBUG]    - 输入寄存器数量: 100
[DEBUG]    - 线圈数量: 100
[DEBUG]    - 离散输入数量: 100
[DEBUG] ✅ [ModbusSlaveController] 寄存器映射初始化完成
[DEBUG] ✅ [ModbusSlaveController] 构造函数
[DEBUG] ✅ [ModbusSlaveController] 初始化寄存器映射
[DEBUG]    - 保持寄存器数量: 100
[DEBUG]    - 输入寄存器数量: 100
[DEBUG]    - 线圈数量: 100
[DEBUG]    - 离散输入数量: 100
[DEBUG] ✅ [ModbusSlaveController] 寄存器映射初始化完成
[DEBUG] ✅ [ModbusSlaveController] 构造函数
[DEBUG] ✅ [ModbusSlaveController] 初始化寄存器映射
[DEBUG]    - 保持寄存器数量: 100
[DEBUG]    - 输入寄存器数量: 100
[DEBUG]    - 线圈数量: 100
[DEBUG]    - 离散输入数量: 100
[DEBUG] ✅ [ModbusSlaveController] 寄存器映射初始化完成
[DEBUG] ✅ [ModbusSlaveController] 构造函数
[DEBUG] ✅ [ModbusSlaveController] 初始化寄存器映射
[DEBUG]    - 保持寄存器数量: 100
[DEBUG]    - 输入寄存器数量: 100
[DEBUG]    - 线圈数量: 100
[DEBUG]    - 离散输入数量: 100
[DEBUG] ✅ [ModbusSlaveController] 寄存器映射初始化完成
[DEBUG] ✅ [ModbusSlaveController] 构造函数
[DEBUG] ✅ [ModbusSlaveController] 初始化寄存器映射
[DEBUG]    - 保持寄存器数量: 100
[DEBUG]    - 输入寄存器数量: 100
[DEBUG]    - 线圈数量: 100
[DEBUG]    - 离散输入数量: 100
[DEBUG] ✅ [ModbusSlaveController] 寄存器映射初始化完成
[DEBUG] ✅ [ModbusSlaveController] 构造函数
[DEBUG] ✅ [ModbusSlaveController] 初始化寄存器映射
[DEBUG]    - 保持寄存器数量: 100
[DEBUG]    - 输入寄存器数量: 100
[DEBUG]    - 线圈数量: 100
[DEBUG]    - 离散输入数量: 100
[DEBUG] ✅ [ModbusSlaveController] 寄存器映射初始化完成
[DEBUG] ✅ [CANController] 构造函数开始
[DEBUG] ✅ [CANController] 初始化配置
[DEBUG] ✅ [CANController] 配置初始化完成，CAN 数量: 2
[DEBUG] ✅ [CANController] QSettings 初始化完成
[DEBUG] ✅ [CANController] 加载配置
[DEBUG] ✅ [CANController] 配置加载完成
[DEBUG] ✅ [CANController] 构造函数完成
[DEBUG] ✅ [ModbusTCPMasterController] 初始化完成
[DEBUG] ✅ [ModbusTCPMasterController] 初始化完成
[DEBUG] ✅ [ModbusTCPMasterController] 初始化完成
[DEBUG] ✅ [ModbusTCPMasterController] 初始化完成
[DEBUG] ✅ [ModbusTCPMasterController] 初始化完成
[DEBUG] ✅ [ModbusTCPMasterController] 初始化完成
[DEBUG] ✅ [ModbusTCPMasterController] 初始化完成
[DEBUG] ✅ [ModbusTCPMasterController] 初始化完成
[DEBUG] ✅ [ModbusTCPSlaveController] 初始化完成
[DEBUG] ✅ [ModbusTCPSlaveController] 初始化完成
[DEBUG] ✅ [ModbusTCPSlaveController] 初始化完成
[DEBUG] ✅ [ModbusTCPSlaveController] 初始化完成
[DEBUG] ✅ [ModbusTCPSlaveController] 初始化完成
[DEBUG] ✅ [ModbusTCPSlaveController] 初始化完成
[DEBUG] ✅ [ModbusTCPSlaveController] 初始化完成
[DEBUG] ✅ [ModbusTCPSlaveController] 初始化完成
[DEBUG] ✅ [S7ClientController] 初始化完成（Snap7支持已启用）
[DEBUG] ✅ [S7ClientController] 初始化完成（Snap7支持已启用）
[DEBUG] ✅ [S7ClientController] 初始化完成（Snap7支持已启用）
[DEBUG] ✅ [S7ClientController] 初始化完成（Snap7支持已启用）
[DEBUG] ✅ [S7ClientController] 初始化完成（Snap7支持已启用）
[DEBUG] ✅ [S7ClientController] 初始化完成（Snap7支持已启用）
[DEBUG] ✅ [S7ClientController] 初始化完成（Snap7支持已启用）
[DEBUG] ✅ [S7ClientController] 初始化完成（Snap7支持已启用）
[DEBUG] ✅ [S7ServerController] 初始化完成（Snap7支持已启用）
[DEBUG] ✅ [S7ServerController] 初始化完成（Snap7支持已启用）
[DEBUG] ✅ [S7ServerController] 初始化完成（Snap7支持已启用）
[DEBUG] ✅ [S7ServerController] 初始化完成（Snap7支持已启用）
[DEBUG] ✅ [S7ServerController] 初始化完成（Snap7支持已启用）
[DEBUG] ✅ [S7ServerController] 初始化完成（Snap7支持已启用）
[DEBUG] ✅ [S7ServerController] 初始化完成（Snap7支持已启用）
[DEBUG] ✅ [S7ServerController] 初始化完成（Snap7支持已启用）
[DEBUG] ✅ [MQTTController] 初始化 MQTT 控制器
[DEBUG] ✅ [MQTTController] 初始化 8 个模块配置完成
[DEBUG] ✅ [MQTTController] Qt MQTT 已启用
MQTTController initialized
[DEBUG] ✅ [MQTTAutoManager] 初始化自动管理器
[DEBUG]    配置文件: "/app/appdata/mqtt_settings.ini"
[DEBUG]    数据超时阈值: 2 秒（从 QSettings 加载）
[DEBUG]    连接超时阈值: 1 秒（从 QSettings 加载）
[DEBUG] ✅ [MQTTAutoManager] 初始化健康状态
[DEBUG] ✅ [MQTTAutoManager] 初始化定时器
[DEBUG] ✅ [MQTTAutoManager] 自动管理器初始化完成
[DEBUG] ✅ [DIDataManager] 初始化开关量数据管理器
[DEBUG] ✅ [AIDataManager] 初始化模拟量数据管理器
[DEBUG] 🚀 [MQTTAutoManager] 启动自动管理器
[DEBUG] 🔌 [MQTTAutoManager] 连接所有模块（前4个）
[DEBUG] ✅ [MQTTController] 创建客户端: 0
[DEBUG] ✅ [MQTTController] 创建客户端: 0
[DEBUG] ✅ [MQTTController] 创建客户端: 1
[DEBUG] ✅ [MQTTController] 创建客户端: 1
[DEBUG] ✅ [MQTTController] 创建客户端: 2
[DEBUG] ✅ [MQTTController] 创建客户端: 2
[DEBUG] ✅ [MQTTController] 创建客户端: 3
[DEBUG] ✅ [MQTTController] 创建客户端: 3
[DEBUG] ✅ [MQTTAutoManager] 启动重连检查定时器
[DEBUG] ✅ [MQTTAutoManager] 启动开关量采集定时器
[DEBUG] ✅ [MQTTAutoManager] 启动模拟量采集定时器
[DEBUG] ✅ [MQTTAutoManager] 启动健康检查定时器
[DEBUG] ✅ [MQTTAutoManager] 自动管理器已启动
MQTT Auto Manager started
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
[DEBUG]    - ID: 1
[DEBUG]    - UUID: "edd600c8-ffa3-4892-93c6-f56f8f0ad477"
[DEBUG]    - 名称: "皮带控制系统"
[DEBUG] ✅ AudioNetworkTcpSender 初始化完成
[DEBUG] ✅ [TTSEngineManager] 创建
[DEBUG] ✅ CommonControl: 公共控制模块已创建
[W][31126.683688] pw.conf      | [          conf.c: 1031 try_load_conf()] can't load config client-rt.conf: No such file or directory
[E][31126.683714] pw.conf      | [          conf.c: 1060 pw_conf_load_conf_for_context()] can't load config client-rt.conf: No such file or directory
[ALSOFT] (EE) Failed to create PipeWire event context (errno: 2)
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
[DEBUG] 🔧 [CommonControl] 注册 TTS 引擎
[DEBUG] ✅ [PaddleSpeech] 适配器创建
[DEBUG] ✅ [TTSEngineManager] 注册引擎: "PaddleSpeech"
[DEBUG] ✅ [CommonControl] PaddleSpeech 注册成功
[DEBUG] ✅ [CommonControl] 所有 TTS 引擎注册完成
[DEBUG] ✅ CommonControl: TTS 引擎管理器初始化完成
[DEBUG] ✅ CommonControl: TTS 初始化进度信号已连接
[DEBUG] 🔗 CommonControl: SystemConfig已连接
[DEBUG] 🔗 CommonControl: NetworkTask已连接
[DEBUG] 🔗 CommonControl: 已连接 registerValueReceived 信号
[DEBUG] 🔗 CommonControl: OperationLogDB已连接
[DEBUG] 🔗 CommonControl: RuntimeTracker已连接
[DEBUG] [BatchAudioGenerator] 初始化
BatchAudioGenerator created
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
[DEBUG]    - ID: 1
[DEBUG]    - UUID: "edd600c8-ffa3-4892-93c6-f56f8f0ad477"
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
[DEBUG] ✅ TTS服务进程已启动，PID: 57
[DEBUG] 📤 发送命令: "{\"command\":\"init\",\"model_dir\":\"/app/tts_models/vits-zh-aishell3\"}\n"
[DEBUG] ✅ [MQTTAutoManager] 模块 3 已连接
[DEBUG] ✅ [MQTTController] 模块 3 订阅主题: "belt_control/ai/module2/status" QoS: 1
[DEBUG] ✅ [MQTTAutoManager] 模块 3 订阅主题: "belt_control/ai/module2/status"
[DEBUG] ✅ [MQTTAutoManager] 模块 0 已连接
[DEBUG] ✅ [MQTTController] 模块 0 订阅主题: "belt_control/di/module1/status" QoS: 1
[DEBUG] ✅ [MQTTAutoManager] 模块 0 订阅主题: "belt_control/di/module1/status"
[DEBUG] ✅ [MQTTAutoManager] 模块 1 已连接
[DEBUG] ✅ [MQTTController] 模块 1 订阅主题: "belt_control/di/module2/status" QoS: 1
[DEBUG] ✅ [MQTTAutoManager] 模块 1 订阅主题: "belt_control/di/module2/status"
[DEBUG] ✅ [MQTTAutoManager] 模块 2 已连接
[DEBUG] ✅ [MQTTController] 模块 2 订阅主题: "belt_control/ai/module1/status" QoS: 1
[DEBUG] ✅ [MQTTAutoManager] 模块 2 订阅主题: "belt_control/ai/module1/status"
[DEBUG] ✅ [MQTTAutoManager] 模块 0 硬件数据到达，状态从 "已连接" → 正常
[DEBUG] ✅ [MQTTAutoManager] 模块 2 硬件数据到达，状态从 "已连接" → 正常
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
[DEBUG] 📋 [DeviceRoleManager] 初始化
[DEBUG]    配置文件路径: "/root/.config/belt_control_system/device_role.json"
[DEBUG] 🔧 [DeviceRoleManager] 初始化设备列表
[DEBUG]    已初始化 12 个设备
[DEBUG] 🔧 [DeviceRoleManager] 初始化集控设备列表
[DEBUG]    已初始化 1 个集控设备
[DEBUG] ℹ️ [DeviceRoleManager] 配置文件不存在，使用默认配置
[DEBUG] ℹ️ [DeviceRoleManager] 配置文件不存在，使用默认配置
DeviceRoleManager initialized
[DEBUG] ✅ [DeviceRoleManager] MQTT 控制器已设置
[DEBUG] ✅ [MQTTController] 模块 0 订阅主题: "station/status/+" QoS: 1
[DEBUG] 📡 [DeviceRoleManager] 订阅主题: station/status/+
[DEBUG] ✅ [MQTTController] 模块 0 订阅主题: "device/status/+" QoS: 1
[DEBUG] 📡 [DeviceRoleManager] 订阅主题: device/status/+
[DEBUG] ✅ [DeviceRoleManager] MQTT 发布已启动
[DEBUG]    发布间隔: 1秒
[DEBUG]    集控主题: station/status/ 1
[DEBUG]    设备主题: device/status/ 1
DeviceRoleManager MQTT publishing started
[DEBUG] ✅ [AudioPathMapper] 音频路径映射器已创建，基础目录: "/app/audio"
[DEBUG] 📁 [AudioPathMapper] 设置基础目录: "/home/linaro/belt-control-data/audio"
[DEBUG] ✅ [MqttProtectionMonitor] MQTT保护监控器已创建
[DEBUG] 📁 [MqttProtectionMonitor] 音频基础目录: "/home/linaro/belt-control-data/audio"
[DEBUG] 🔗 [MqttProtectionMonitor] 已连接DIDataManager的bitChanged信号
[DEBUG] 📝 [MqttProtectionMonitor] 设置皮带映射: 模块 0 → 1 号皮带
[DEBUG] 🚀 [MqttProtectionMonitor] 启动MQTT保护监控
[DEBUG] 📋 [MqttProtectionMonitor] 皮带映射:
[DEBUG]    模块 0 → 1 号皮带
[DEBUG]    模块 1 → 2 号皮带
MQTT Protection Monitor started
MQTT module offline voice alert connected
Protection trigger -> alarm history DB connection established
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
[DEBUG] ⌨️ [InputPanel] Enabled changed: false
[DEBUG] 🖱️ [Keyboard Debug MouseArea] Visible changed: false
[DEBUG] ========================================
[DEBUG] 🔧 [Keyboard Container] Initialized in Overlay
[DEBUG]    - parent: QQuickOverlay(0x5579336490)
[DEBUG]    - parent is Overlay: true
[DEBUG]    - Initial z-index: 1 ⬅️ Will be dynamically adjusted
[DEBUG] ========================================
[DEBUG] ========================================
[DEBUG] 🔧 [Keyboard Wrapper] Initialized
[DEBUG]    - z-index: 2 (above keyboardOverlay)
[DEBUG]    - width: 1920
[DEBUG]    - height: 600
[DEBUG] ========================================
[DEBUG] ========================================
[DEBUG] ⌨️ [InputPanel] Virtual keyboard initialized
[DEBUG]    - parent: QQuickItem(0x5579eb2fe0)
[DEBUG]    - z-index: 1
[DEBUG]    - width: 1920
[DEBUG]    - height: 600
[DEBUG]    - enabled: false
[DEBUG]    - visible: false
[DEBUG] ========================================
[DEBUG] 🖱️ [Keyboard Debug MouseArea] Initialized
[DEBUG]    - Size: 1920 x 600
[DEBUG]    - Z-index: -1
[DEBUG]    - Enabled: true
[DEBUG] =========================================
[DEBUG] 🔥🔥🔥 VERSION: 2025-12-19-07:00 DYNAMIC-Z 🔥🔥🔥
[DEBUG] 🛡️ [Main keyboardOverlay] DISABLED - using Dialog overlay instead
[DEBUG]    - z-index: 3 (parent container z: 1 - DYNAMIC)
[DEBUG]    - visible: false (SHOULD be false)
[DEBUG]    - enabled: false (SHOULD be false)
[DEBUG] =========================================
[WARNING] qrc:/qt/qml/BeltControlQml/pages/ParameterSettings.qml:55:5: QML Back.ui: Cannot open: qrc:/qt/qml/BeltControlQml/pages/images/back2.svg
[WARNING] qrc:/qt/qml/BeltControlQml/pages/DeviceMonitorPage.qml:21:5: QML Back.ui: Cannot open: qrc:/qt/qml/BeltControlQml/pages/images/back2.svg
[WARNING] Qt Quick Layouts: Detected recursive rearrange. Aborting after two iterations.
[WARNING] Qt Quick Layouts: Detected recursive rearrange. Aborting after two iterations.
[WARNING] qrc:/qt/qml/BeltControlQml/pages/ControlPanel.qml:68:5: QML Back.ui: Cannot open: qrc:/qt/qml/BeltControlQml/pages/images/back2.svg
[WARNING] qrc:/qt/qml/BeltControlQml/pages/ControlPanel.qml:42:5: QML Connections: Detected function "onProtectionTriggered" in Connections element. This is probably intended to be a signal handler but no signal of the target matches the name.
[WARNING] qrc:/qt/qml/BeltControlQml/pages/ControlPanel.qml:42:5: QML Connections: Detected function "onProtectionRestored" in Connections element. This is probably intended to be a signal handler but no signal of the target matches the name.
[DEBUG] [Screen01] ✅ 组件加载完成
[DEBUG] [Screen01] 🎯 强制获取焦点...
[DEBUG] 🔍 [Screen01] ========== 焦点状态变化 ==========
[DEBUG] 🔍 [Screen01] activeFocus: ✅ 获得焦点
[DEBUG] 🔍 [Screen01] focus 属性: true
[DEBUG] 🔍 [Screen01] parent: QQuickLoader(0x557918bcb0)
[DEBUG] 🔍 [Screen01] parent.objectName:
[DEBUG] 🔍 [Screen01] =====================================
[DEBUG] [Screen01Form] ✅ 组件加载完成
[DEBUG] ✅ Input1 Screen01 加载成功
[DEBUG]    [布局] 屏幕尺寸: 1920 x 1080
[DEBUG] 🔍 [Input1Page] 缩放调试:
[DEBUG]    xScale (宽度缩放): 1.000
[DEBUG]    yScale (高度缩放): 1.000
[DEBUG]    预期显示尺寸: 1920 x 1080
[DEBUG] 🔗 [Input1Page] 设置 Screen01.currentPageIndex 绑定
[DEBUG]    input1Page.currentPageIndex = 0
[DEBUG] 📡 [Binding] Screen01.currentPageIndex 更新 = 0
[DEBUG]    Screen01.currentPageIndex = 0
[DEBUG] [BUILD MARKER] Phase7.45.31-SwipeViewRootAnchorFix-2026-02-12
[DEBUG] [FULLSCREEN DEBUG] Screen size: 1920 x 1080
[DEBUG] [FULLSCREEN DEBUG] Window size: 1920 x 1080
[DEBUG] [FULLSCREEN DEBUG] Current visibility: 2
[DEBUG] [FULLSCREEN DEBUG] Platform: linux
[DEBUG] [FULLSCREEN DEBUG] Device 151 (1920x1080) detected, EGLFS naturally fullscreen
[DEBUG] 📋 [TTSConfig] 初始化TTS配置管理器
[DEBUG] 📂 [TTSConfig] 加载TTS配置
[DEBUG]   - "startup_warning" : model= 0 , speaker= 0 , rate= 1
[DEBUG]   - "fault_alarm" : model= 0 , speaker= 0 , rate= 1
[DEBUG]   - "test" : model= 0 , speaker= 0 , rate= 1
[DEBUG] 📂 已恢复批量合成参数
[DEBUG] 🚀 TTSConfigSection 组件加载完成
[DEBUG] 🔄 自动初始化 TTS 引擎，索引: 0
[DEBUG] 🔄 [CommonControl] 切换 TTS 引擎 - 索引: 0 名称: "PaddleSpeech"
[DEBUG] 🔄 [TTSEngineManager] 切换引擎: "PaddleSpeech"
[DEBUG] ✅ [CommonControl] TTS 引擎切换成功: "PaddleSpeech"
[DEBUG] 🔄 更新模型列表...
[DEBUG] 模型切换: 0
[DEBUG] ✅ 模型列表已更新: 4 个模型
[DEBUG] 🔄 更新引擎状态...
[DEBUG] 📊 当前引擎: PaddleSpeech
[DEBUG] ✅ 引擎状态已更新: 已初始化
[DEBUG] 📂 已恢复TTS参数: 说话人ID=0, 语速=1.0, 音量=80%
[DEBUG] 🔄 启动异步TTS模型初始化...
[DEBUG] 🔄 [CommonControl] 异步切换 TTS 模型 - 索引: 0
[DEBUG] Input1Page 已加载
[DEBUG] 🔍 [Input1Page] 缩放调试（Component.onCompleted）:
[DEBUG]    input1Page.width: 1920
[DEBUG]    input1Page.height: 1080
[DEBUG]    xScale (宽度缩放): 1.000
[DEBUG]    yScale (高度缩放): 1.000
[DEBUG]    预期显示尺寸: 1920 x 1080
[DEBUG] 🔄 [CommonControl] 切换 TTS 模型 - 索引: 0
[DEBUG]    模型路径: "/app/tts_models/paddlespeech/fastspeech2_csmsc"
[DEBUG] 🔧 [TTSEngineManager] 初始化引擎: "PaddleSpeech" 模型: "/app/tts_models/paddlespeech/fastspeech2_csmsc"
[DEBUG] 🔧 [PaddleSpeech] 初始化 - 模型: "/app/tts_models/paddlespeech/fastspeech2_csmsc"
[WARNING] QObject: Cannot create children for a parent that is in a different thread.
(Parent is PaddleSpeechAdapter(0x5578b1b5c0), parent's thread is QThread(0x55784185d0), current thread is QThread(0x55791b25e0)
[DEBUG] 📂 [PaddleSpeech] PADDLESPEECH_HOME= "/app/tts_models/paddlespeech"
[DEBUG] 📂 [PaddleSpeech] PPSPEECH_HOME= "/app/tts_models/paddlespeech"
[DEBUG] 🚀 [PaddleSpeech] 启动服务: "/app/tts_engines/paddlespeech/paddle_tts_service.py"
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
[DEBUG] ✅ [PaddleSpeech] 服务启动成功
[DEBUG] 📋 CommonControl: 设置设备反馈配置 - "1号乳化液泵" 使用反馈: true 反馈通道: 9 反馈延时: 3 秒
[DEBUG] 📋 CommonControl: 设置设备反馈配置 - "2号乳化液泵" 使用反馈: true 反馈通道: 10 反馈延时: 3 秒
[DEBUG] 📋 CommonControl: 设置设备反馈配置 - "3号乳化液泵" 使用反馈: true 反馈通道: 11 反馈延时: 3 秒
[DEBUG] 📋 CommonControl: 设置设备反馈配置 - "4号乳化液泵" 使用反馈: true 反馈通道: 12 反馈延时: 3 秒
[DEBUG] 📋 CommonControl: 设置设备反馈配置 - "1号喷雾泵" 使用反馈: true 反馈通道: 13 反馈延时: 3 秒
[DEBUG] 📋 CommonControl: 设置设备反馈配置 - "2号喷雾泵" 使用反馈: true 反馈通道: 14 反馈延时: 3 秒
[DEBUG] 📤 [PaddleSpeech] 发送命令: "initialize"
[DEBUG] 📋 CommonControl: 设置设备反馈配置 - "3号喷雾泵" 使用反馈: true 反馈通道: 15 反馈延时: 3 秒
[DEBUG] ✅ ParameterSettings: 已同步 16 个设备的反馈配置
[DEBUG] ✅ [DeviceMonitorPage] 数字孪生设备监控页面已加载
[DEBUG] ✅ [BeltConnectionDiagram] 增强版皮带连接关系图已加载
[DEBUG] ✅ OperationLogPanel: 已加载 0 条日志记录
[DEBUG] 🔍 [ControlPanel Head] 布局调试 v6:
[DEBUG]    root 尺寸: 1920 × 1080
[DEBUG]    容器原始尺寸: 1920 × 80
[DEBUG]    scaleFactor: 1.000
[DEBUG]    缩放后尺寸: 1920 × 80
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/GlowLed.qml:32: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/ModernButton.qml:66: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/ModernButton.qml:65: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/ModernButton.qml:64: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/ModernButton.qml:18: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/ModernButton.qml:66: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/ModernButton.qml:65: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/ModernButton.qml:64: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/ModernButton.qml:18: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/GlowLed.qml:32: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/GlowLed.qml:12: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/GlowLed.qml:12: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/GlowLed.qml:11: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/MiniTrendChart.qml:14: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/MiniTrendChart.qml:26: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/MiniTrendChart.qml:23: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/MiniTrendChart.qml:25: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/MiniTrendChart.qml:24: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/ModernButton.qml:11: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/ModernButton.qml:10: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/ModernButton.qml:11: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/ModernButton.qml:10: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/pages/BatchSynthesisContent.qml:347:29: Unable to assign [undefined] to QString
[WARNING] qrc:/qt/qml/BeltControlQml/pages/BatchSynthesisContent.qml:359:29: Unable to assign [undefined] to QString
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
[DEBUG] 📊 AlarmHistoryDatabase: 查询返回 197 条记录
[DEBUG] ✅ [AlarmPage] 加载报警记录: 197 条
[DEBUG] 📊 TTS 初始化进度: 正在加载 PaddleSpeech 模型...
Object created callback: obj=5578bf6f40
[WARNING] [PaddleSpeech Error] "[2026-03-03 08:47:29,324] [INFO] 📂 PADDLESPEECH_HOME 环境变量: '/app/tts_models/paddlespeech'\n[2026-03-03 08:47:29,324] [INFO] 📂 PPSPEECH_HOME 环境变量: '/app/tts_models/paddlespeech'\n[2026-03-03 08:47:29,324] [INFO] ✅ 使用环境变量 PADDLESPEECH_HOME=/app/tts_models/paddlespeech\n[2026-03-03 08:47:29,324] [INFO] ✅ 使用环境变量 PPSPEECH_HOME=/app/tts_models/paddlespeech\n[2026-03-03 08:47:29,324] [INFO] 🚀 PaddleSpeech TTS 服务启动\n[2026-03-03 08:47:29,324] [INFO] 📂 工作目录: /app\n[2026-03-03 08:47:29,324] [INFO] 🐍 Python 版本: 3.12.3 (main, Jan 22 2026, 20:57:42) [GCC 13.3.0]\n[2026-03-03 08:47:29,324] [INFO] 📨 收到命令: initialize\n[2026-03-03 08:47:29,324] [INFO] 🔧 初始化 PaddleSpeech - 模型: /app/tts_models/paddlespeech/fastspeech2_csmsc\n[2026-03-03 08:47:29,324] [INFO] 📝 提取模型名称: fastspeech2_csmsc"
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/MiniTrendChart.qml:42: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/GlowLed.qml:2063805104: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/GlowLed.qml:2063805696: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/GlowLed.qml:2063805104: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/GlowLed.qml:2063805696: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/GlowLed.qml:2063802960: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/GlowLed.qml:2063803552: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/GlowLed.qml:2063802960: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/GlowLed.qml:2063803552: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/GlowLed.qml:2063802960: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/GlowLed.qml:2063803552: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/GlowLed.qml:2063802960: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/GlowLed.qml:2063803552: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/GlowLed.qml:2063802960: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/GlowLed.qml:2063803552: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/GlowLed.qml:2063802960: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/GlowLed.qml:2063803552: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/GlowLed.qml:2063802960: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/GlowLed.qml:2063803552: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/GlowLed.qml:2063802960: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/GlowLed.qml:2063803552: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/GlowLed.qml:32: ReferenceError: Theme is not defined
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_monitor/GlowLed.qml:12: ReferenceError: Theme is not defined
[WARNING] ⚠️ [DIDataManager] 缺少data字段（后续相同警告已抑制）
[DEBUG] ❌ [RINGTONE] Error: 1 Resource not found.
[DEBUG] ❌ [RINGTONE] Error: 1 GStreamer error: state change failed and some element failed to post a proper error message with the reason for the failure.
[DEBUG] ❌ [RINGTONE] Error: 1 Resource not found.
[DEBUG] ❌ [RINGTONE] Error: 1 GStreamer error: state change failed and some element failed to post a proper error message with the reason for the failure.
[WARNING] [PaddleSpeech Error] "/usr/local/lib/python3.12/dist-packages/paddle/utils/cpp_extension/extension_utils.py:718: UserWarning: No ccache found. Please be aware that recompiling all source files may be required. You can download and install ccache from: https://github.com/ccache/ccache/blob/master/doc/INSTALL.md\n  warnings.warn(warning_message)"
[DEBUG] 🔔 [RINGTONE] Using system ringtone: "C:/Windows/Media/Ring01.wav"
[DEBUG] 🔔 [RINGTONE] URL format: "file:///C:/Windows/Media/Ring01.wav"
[DEBUG] 🔔 [RINGTONE] Loaded custom ringtone: file:///C:/Windows/Media/Ring01.wav
[DEBUG] [MQTTAutoManager] 模块 0 健康检查 | connected: true | lastDataTime: 1772527655 | timeSinceLastData: 0 s | status: "正常" | timeoutCount: 0
[DEBUG] [MQTTAutoManager] 模块 1 健康检查 | connected: true | lastDataTime: 0 | timeSinceLastData: -1 s | status: "等待数据" | timeoutCount: 0
[DEBUG] [MQTTAutoManager] 模块 2 健康检查 | connected: true | lastDataTime: 1772527655 | timeSinceLastData: 0 s | status: "正常" | timeoutCount: 0
[DEBUG] [MQTTAutoManager] 模块 3 健康检查 | connected: true | lastDataTime: 0 | timeSinceLastData: -1 s | status: "等待数据" | timeoutCount: 0
[WARNING] [PaddleSpeech Error] "\u001B[0;93m2026-03-03 08:47:36.698735413 [W:onnxruntime:Default, device_discovery.cc:211 DiscoverDevicesForPlatform] GPU device discovery failed: device_discovery.cc:91 ReadFileContents Failed to open file: \"/sys/class/drm/card1/device/vendor\"\u001B[m"
[DEBUG] 🔍 [Screen01] ========== 焦点状态变化 ==========
[DEBUG] 🔍 [Screen01] activeFocus: ❌ 失去焦点
[DEBUG] 🔍 [Screen01] focus 属性: true
[DEBUG] 🔍 [Screen01] parent: QQuickLoader(0x557918bcb0)
[DEBUG] 🔍 [Screen01] parent.objectName:
[DEBUG] 🔍 [Screen01] =====================================
[DEBUG] [SwipeView] 页面切换到索引: 1
[DEBUG] [SwipeView] 页面切换到索引: 2
[DEBUG] [MQTTAutoManager] 模块 0 健康检查 | connected: true | lastDataTime: 1772527665 | timeSinceLastData: 0 s | status: "正常" | timeoutCount: 0
[DEBUG] [MQTTAutoManager] 模块 1 健康检查 | connected: true | lastDataTime: 0 | timeSinceLastData: -1 s | status: "等待数据" | timeoutCount: 0
[DEBUG] [MQTTAutoManager] 模块 2 健康检查 | connected: true | lastDataTime: 1772527664 | timeSinceLastData: 1 s | status: "正常" | timeoutCount: 0
[DEBUG] [MQTTAutoManager] 模块 3 健康检查 | connected: true | lastDataTime: 0 | timeSinceLastData: -1 s | status: "等待数据" | timeoutCount: 0
[DEBUG] [SwipeView] 页面切换到索引: 3
[DEBUG] [SwipeView] 页面切换到索引: 4
[DEBUG] [SwipeView] 页面切换到索引: 5
[DEBUG] [SwipeView] 切换到 Input1Page，恢复 Screen01 焦点
[DEBUG] [SwipeView] 找到 Screen01，强制获取焦点
[DEBUG] 🔍 [Screen01] ========== 焦点状态变化 ==========
[DEBUG] 🔍 [Screen01] activeFocus: ✅ 获得焦点
[DEBUG] 🔍 [Screen01] focus 属性: true
[DEBUG] 🔍 [Screen01] parent: QQuickLoader(0x557918bcb0)
[DEBUG] 🔍 [Screen01] parent.objectName:
[DEBUG] 🔍 [Screen01] =====================================
[DEBUG] [Screen01] 🖱️ 鼠标悬停在组件 0
[DEBUG] [Screen01] 🖱️ 鼠标悬停在组件 1
[DEBUG] [Screen01] 🖱️ 鼠标悬停在组件 0
[DEBUG] [Screen01] 🖱️ 单击组件 0
[DEBUG] [Screen01] 🔄 updateSelection 开始，selectedIndex: 0 有效组件: 12
[DEBUG] [Screen01] ✅ 组件 0 已选中
[DEBUG] [Screen01] 🔄 updateSelection 完成，成功更新 12 个组件
[DEBUG] [Screen01] 🖱️🖱️ 双击组件 0 - 打开设备设置对话框
[DEBUG] [Screen01] 🔄 updateSelection 开始，selectedIndex: 0 有效组件: 12
[DEBUG] [Screen01] ✅ 组件 0 已选中
[DEBUG] [Screen01] 🔄 updateSelection 完成，成功更新 12 个组件
[DEBUG] 🔍 [Screen01] ========== 打开对话框 ==========
[DEBUG] 🔍 [Screen01] 当前选中索引: 0
[DEBUG] 🔍 [Screen01] 打开前 - activeFocus: true
[DEBUG] 🔍 [Screen01] 打开前 - focus: true
[DEBUG] ✅ [MQTTAutoControlTab] 初始化完成
[DEBUG] ✅ [MQTTConfigPanel] MQTTAutoControlTab 加载成功
[DEBUG] ✅ [MQTTConfigPanel] MQTTMonitorTab 加载成功
[DEBUG] ✅ [MQTTConfigPanel] MQTTPublishTab 加载成功
[DEBUG] ✅ [MQTTConfigPanel] MQTTSubscribeTab 加载成功
[DEBUG] ✅ [MQTTConfigPanel] MQTTConnectionTab 加载成功
[DEBUG] ✅ [MQTTControlPage] MQTTConfigPanel 加载成功
[DEBUG] ✅ [MQTTControlPage] MQTTListPanel 加载成功
[DEBUG] ✅ [MQTTControlPage] Component.onCompleted
[DEBUG] ✅ [MQTTControlPage] focusItemIndex 变化: 0
[DEBUG] ✅ [DeviceSettingsDialog] MQTTControlPage 加载成功
[DEBUG] ✅ [TCPConfigPanel] S7SlaveTab 加载成功
[DEBUG] ✅ [TCPConfigPanel] S7MasterTab 加载成功
[DEBUG] ✅ [TCPConfigPanel] ModbusTCPSlaveTab 加载成功
[DEBUG] ✅ [TCPConfigPanel] ModbusTCPMasterTab 加载成功
[DEBUG] ✅ [TCPControlPage] TCPConfigPanel 加载成功
[DEBUG] ✅ [TCPControlPage] TCPListPanel 加载成功
[DEBUG] ✅ [TCPControlPage] Component.onCompleted
[DEBUG] ✅ [TCPControlPage] focusItemIndex 变化: 0
[DEBUG] ✅ [DeviceSettingsDialog] TCPControlPage 加载成功
[DEBUG] ✅ [CANConfigPanel] CANReceiveTab 加载成功
[DEBUG] ✅ [CANSendTab] Component.onCompleted
[DEBUG]    - virtualKeyboard: null
[DEBUG] ✅ [CANConfigPanel] CANSendTab 加载成功
[DEBUG] ✅ [CANParamsTab] GridLayout 加载完成
[DEBUG]    - columns: 2
[DEBUG]    - width: 0
[DEBUG]    - paramScrollView.width: 0
[DEBUG]    - columnSpacing: 16
[DEBUG]    - rowSpacing: 12
[DEBUG] 🔍 [CANParamsTab] statusText 初始化
[DEBUG]    - canController 是否存在: true
[DEBUG]    - canController.status: DOWN
[DEBUG]    - canController.isUp: false
[DEBUG] ✅ [CANConfigPanel] CANParamsTab 加载成功
[DEBUG] ✅ [CANControlPage] CANConfigPanel 加载成功
[DEBUG] ✅ [CANControlPage] CANListPanel 加载成功
[DEBUG] ✅ [CANControlPage] Component.onCompleted 开始
[DEBUG] ✅ [CANControlPage] CAN 数量: 2
[DEBUG] ✅ [CANControlPage] focusItemIndex 变化: 0 → 更新 currentCanIndex
[DEBUG] ✅ [CANControlPage] 初始化焦点 - focusSubArea: 0 focusItemIndex: 0
[DEBUG] ✅ [CANControlPage] Component.onCompleted 完成
[DEBUG] ✅ [CANControlPage] NavigationManager 初始化完成
[DEBUG] ✅ [DeviceSettingsDialog] CANControlPage 加载成功
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_info/pages/SerialPortParamsTab.qml:777:21: QML Row: Cannot specify left, right, horizontalCenter, fill or centerIn anchors for items inside Row. Row will not function.
[DEBUG] ✅ [SerialPortParamsTab] Component.onCompleted 开始
[DEBUG] ✅ [SerialPortParamsTab] Component.onCompleted 完成
[DEBUG] ✅ [SerialPortParamsTab] GridLayout 加载完成
[DEBUG]    - columns: 2
[DEBUG]    - width: 0
[DEBUG]    - paramScrollView.width: 0
[DEBUG]    - columnSpacing: 16
[DEBUG]    - rowSpacing: 12
[DEBUG] ✅ [CustomComboBox] parityCombo 找到 DeviceSettingsDialog
[DEBUG] ✅ [CustomComboBox] stopBitsCombo 找到 DeviceSettingsDialog
[DEBUG] ✅ [CustomComboBox] dataBitsCombo 找到 DeviceSettingsDialog
[DEBUG] ✅ [SerialPortParamsTab] 索引1（波特率）Item 加载完成
[DEBUG]    - Layout.column: 1
[DEBUG]    - Layout.row: 0
[DEBUG]    - width: 0
[DEBUG]    - height: 60
[DEBUG] ✅ [CustomComboBox] 找到 DeviceSettingsDialog，设置 parentDialog
[DEBUG] ✅ [SerialPortParamsTab] 索引0（串口名称）Item 加载完成
[DEBUG]    - Layout.column: 0
[DEBUG]    - Layout.row: 0
[DEBUG]    - width: 0
[DEBUG]    - height: 40
[DEBUG] ✅ [SerialPortParamsTab] serialNameText 加载完成 - text:
[DEBUG] ✅ [SerialPortConfigPanel] SerialPortParamsTab 加载成功
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
[DEBUG] ✅ [SerialPortParamsTab] 串口切换: COM1
[DEBUG] ✅ [SerialPortControlPage] SerialPortListPanel 加载成功
[DEBUG] ✅ [SerialPortControlPage] Component.onCompleted 开始
[DEBUG] ✅ [SerialPortControlPage] 串口数量: 6
[DEBUG] 🔍 [SerialPortControlPage] serialListPanel.status: 1
[DEBUG] 🔍 [SerialPortControlPage] serialListPanel.item: SerialPortListPanel_QMLTYPE_423(0x557d70b080)
[DEBUG] 🔍 [SerialPortControlPage] serialConfigPanel.status: 1
[DEBUG] 🔍 [SerialPortControlPage] serialConfigPanel.item: SerialPortConfigPanel_QMLTYPE_418(0x557d70b5e0)
[DEBUG] ✅ [SerialPortControlPage] focusItemIndex 变化: 0 → 更新 currentSerialIndex
[DEBUG] ✅ [SerialPortControlPage] 初始化焦点 - focusSubArea: 0 focusItemIndex: 0
[DEBUG] ✅ [SerialPortControlPage] Component.onCompleted 完成
[DEBUG] ✅ [SerialPortControlPage] NavigationManager 初始化完成
[DEBUG] ✅ [DeviceSettingsDialog] SerialPortControlPage 加载成功
[DEBUG] ✅ [BasicConfigPage] NetworkParametersSection 加载成功
[DEBUG] ✅ [BasicConfigPage] BasicParametersSection 加载成功
[DEBUG] ✅ [BasicConfigPage] 组件初始化 - 设备ID: 1
[DEBUG] ✅ [BasicConfigPage] 开始加载所有配置 - 设备ID: 1
[DEBUG] ✅ [BasicConfigPage] 开始加载基本参数配置 - 设备ID: 1
[DEBUG] ⚠️ [BasicConfigPage] 没有找到基本参数配置，使用默认值
[DEBUG] ✅ [BasicConfigPage] 开始加载网络参数配置 - 设备ID: 1
[DEBUG] ⚠️ [BasicConfigPage] 没有找到网络参数配置，使用默认值
[DEBUG] ⚠️ [BasicConfigPage] 没有找到配置，使用默认值
[DEBUG] ✅ [DeviceSettingsDialog] BasicConfigPage 加载成功
[DEBUG] ✅ [DeviceSettingsDialog] Qt 虚拟键盘已初始化
[DEBUG] 🔒 [DeviceSettingsDialog] 设备ID: 1 权限检查: 可编辑
[DEBUG] 🔍 [Screen01] focus 属性变化: false
[DEBUG] 🔍 [Screen01] ========== 焦点状态变化 ==========
[DEBUG] 🔍 [Screen01] activeFocus: ❌ 失去焦点
[DEBUG] 🔍 [Screen01] focus 属性: false
[DEBUG] 🔍 [Screen01] parent: QQuickLoader(0x557918bcb0)
[DEBUG] 🔍 [Screen01] parent.objectName:
[DEBUG] 🔍 [Screen01] =====================================
[DEBUG] 🔍 [DeviceSettingsDialog root] activeFocus 变化: true
[DEBUG] ✅ [DeviceSettingsDialog] 对话框已获取焦点
[DEBUG] ✅ [DEBUG] StackLayout 宽度: 1369
[DEBUG] ✅ [DEBUG] StackLayout 高度: 703
[DEBUG] ✅ [DEBUG] StackLayout 子元素数量: 11
[DEBUG] ✅ [DEBUG] SwitchInputPage Loader 宽度: 0
[DEBUG] ✅ [DEBUG] SwitchInputPage Loader 高度: 0
[DEBUG] 🔍 [Screen01] 对话框创建成功
[DEBUG] 🔍 [Screen01] dialog.parent === root: true
[DEBUG] 🔍 [Screen01] dialog.parent: Screen01_QMLTYPE_333(0x557ab3d1a0)
[DEBUG] 🔍 [Screen01] dialog.parentContainer === root: true
[DEBUG] 🔍 [Screen01] 对话框已显示
[DEBUG] 🔍 [Screen01] 打开后 - activeFocus: false
[DEBUG] 🔍 [Screen01] 打开后 - focus: false
[DEBUG] 🔍 [Screen01] =====================================
[DEBUG] ✅ [NavigationManager] 更新 lastParamIndex: 10 （参数数量: 11 ）
[DEBUG] ✅ [NavigationManager] 更新 lastParamIndex: 8 （参数数量: 9 ）
[DEBUG] ✅ [NavigationManager] 更新 lastParamIndex: 3 （参数数量: 4 ）
[DEBUG] ✅ [CANControlPage] 初始参数数量: 4
[DEBUG] ✅ [NavigationManager] 更新 lastParamIndex: 7 （参数数量: 8 ）
[DEBUG] ✅ [SerialPortControlPage] 初始参数数量: 8
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_info/pages/SerialPortParamsTab.qml:777:21: QML Row: Cannot specify left, right, horizontalCenter, fill or centerIn anchors for items inside Row. Row will not function.
[DEBUG] 🔍 [DeviceSettingsDialog root] activeFocus 变化: false
[DEBUG] ✅ [DeviceSettingsDialog] 切换到类别 1 恢复内容索引: 0
[DEBUG] ✅ [SwitchInputPage] Component.onCompleted 开始
[DEBUG] ✅ [SwitchInputPage] Component.onCompleted 完成
[DEBUG] ✅ [DEBUG] SwitchInputPage 右侧区域宽度: 560
[DEBUG] ✅ [DEBUG] SwitchInputPage 右侧区域高度: 600
[DEBUG] ✅ [DEBUG] SwitchInputPage ScrollView 宽度: 530
[DEBUG] ✅ [DEBUG] SwitchInputPage ScrollView 高度: 331
[DEBUG] ✅ [DEBUG] GridLayout 加载完成
[DEBUG]    宽度: 371 高度: 420
[DEBUG]    parent.width: 270
[DEBUG]    paramScrollView.width: 530
[DEBUG]    计算宽度 (70%): 371
[DEBUG] ✅ [DEBUG] onLoaded 开始
[DEBUG] ✅ [DEBUG] 设置 virtualKeyboard: QtVirtualKeyboardIntegration_QMLTYPE_345(0x557bc8cfa0)
[DEBUG] ✅ [DEBUG] onLoaded 完成
[WARNING] qrc:/qt/qml/BeltControlQml/components/device_info/pages/SwitchInputPage.qml:2161:45: Unable to assign [undefined] to QColor
[DEBUG] 🔍 [MQTT控制同步] onCurrentCategoryChanged - currentCategory: 1 currentFocusArea: 1
[DEBUG] ✅ [MQTT控制同步] 切换到其他类别 - 清除 focusItemIndex
[DEBUG] 🔍 [TCP控制同步] onCurrentCategoryChanged - currentCategory: 1 currentFocusArea: 1
[DEBUG] ✅ [TCP控制同步] 切换到其他类别 - 清除 focusItemIndex
[DEBUG] 🔍 [CAN控制同步] onCurrentCategoryChanged - currentCategory: 1 currentFocusArea: 1
[DEBUG] ✅ [CAN控制同步] 切换到其他类别 - 清除 focusItemIndex
[DEBUG] 🔍 [串口控制同步] onCurrentCategoryChanged - currentCategory: 1 currentFocusArea: 1
[DEBUG] ✅ [串口控制同步] 切换到其他类别 - 清除 focusItemIndex
[DEBUG] ✅ [SwitchInputPage] Qt.callLater 回调执行 - 加载第一个保护项
[DEBUG] ✅ [SwitchInputPage] 从数据库加载完整参数: 急停
[DEBUG] ✅ [SwitchInputPage] 初始加载第一个保护项完成
[DEBUG] ✅ [DEBUG] Qt.callLater 回调执行 - 事件循环正常
[DEBUG] [MQTTAutoManager] 模块 0 健康检查 | connected: true | lastDataTime: 1772527674 | timeSinceLastData: 1 s | status: "正常" | timeoutCount: 0
[DEBUG] [MQTTAutoManager] 模块 1 健康检查 | connected: true | lastDataTime: 0 | timeSinceLastData: -1 s | status: "等待数据" | timeoutCount: 0
[DEBUG] [MQTTAutoManager] 模块 2 健康检查 | connected: true | lastDataTime: 1772527674 | timeSinceLastData: 1 s | status: "正常" | timeoutCount: 0
[DEBUG] [MQTTAutoManager] 模块 3 健康检查 | connected: true | lastDataTime: 0 | timeSinceLastData: -1 s | status: "等待数据" | timeoutCount: 0
[DEBUG] ⚠️ [MQTTAutoManager] 模块 0 数据中断，等待恢复 | timeSinceLastData: 3 s
[DEBUG] ⚠️ [MQTTAutoManager] 模块 2 数据中断，等待恢复 | timeSinceLastData: 3 s
[WARNING] [PaddleSpeech Error] "[nltk_data] Error loading averaged_perceptron_tagger: <urlopen error\n[nltk_data]     [Errno -3] Temporary failure in name resolution>"
[WARNING] ⚠️ [MQTTAutoManager] 模块 0 数据超时
[DEBUG] 🔊 [MQTTAutoManager] 模块 0 触发离线语音: "/home/linaro/belt-control-data/audio/paddlespeech-fastspeech2_csmsc-spk0/Status/开关量模块一离线.wav"
[DEBUG] 📋 CommonControl: 音频加入队列: "开关量模块一离线.wav" | 队列长度: 1
[DEBUG] ▶️ CommonControl: 从队列播放: "开关量模块一离线.wav" | 剩余队列: 0
[DEBUG] 🔊 CommonControl: 播放音频: "开关量模块一离线.wav" | 大小: 174 KB | 格式: "WAV"
[DEBUG]    [状态] 当前播放状态: Stopped
[DEBUG]    [新源] 设置新音频源: "开关量模块一离线.wav"
[DEBUG]    [媒体状态]  "LoadingMedia" | 距上次状态变化: 0 ms
[DEBUG]    [加载] setSource() 耗时: 7 ms
[DEBUG]    [输出模式] TCP网络
[DEBUG]    [TCP发送] 开始发送到 TCP 音频模块...
[WARNING]    [TCP发送] ⚠️ 未连接到 TCP 服务器，本地播放（QMediaPlayer）
[DEBUG]    [延迟播放] 设置 m_pendingPlay=true，等待 BufferedMedia
[DEBUG]    [总计] playAudio() 总耗时: 7 ms
[DEBUG]    [媒体] 当前源: "file:///home/linaro/belt-control-data/audio/paddlespeech-fastspeech2_csmsc-spk0/Status/开关量模块一离线.wav"
[DEBUG]    [媒体] 媒体状态: LoadingMedia
[DEBUG]    [媒体] 音频可用: false
[DEBUG]    [媒体] 时长: 0 ms
[WARNING] ⚠️ [MQTTAutoManager] 模块 2 数据超时
[DEBUG] 🔊 [MQTTAutoManager] 模块 2 触发离线语音: "/home/linaro/belt-control-data/audio/paddlespeech-fastspeech2_csmsc-spk0/Status/模拟量模块一离线.wav"
[DEBUG] 📋 CommonControl: 音频加入队列: "模拟量模块一离线.wav" | 队列长度: 1
[DEBUG]    [媒体状态]  "LoadedMedia" | 距上次状态变化: 141 ms
[WARNING] ⚠️ [MQTTAutoManager] 模块 0 数据超时
[WARNING] ⚠️ [MQTTAutoManager] 模块 2 数据超时
[WARNING] ⚠️ [MQTTAutoManager] 模块 0 数据超时
[WARNING] ⚠️ [MQTTAutoManager] 模块 2 数据超时
[WARNING] ⚠️ [MQTTAutoManager] 模块 0 数据超时
[WARNING] ⚠️ [MQTTAutoManager] 模块 2 数据超时
[WARNING] ⚠️ [MQTTAutoManager] 模块 0 数据超时
[WARNING] ⚠️ [MQTTAutoManager] 模块 2 数据超时
[WARNING] ⚠️ [MQTTAutoManager] 模块 0 数据超时
[WARNING] ⚠️ [MQTTAutoManager] 模块 2 数据超时
[DEBUG] [MQTTAutoManager] 模块 0 健康检查 | connected: true | lastDataTime: 1772527674 | timeSinceLastData: 11 s | status: "数据超时" | timeoutCount: 8
[WARNING] ⚠️ [MQTTAutoManager] 模块 0 数据超时
[DEBUG] [MQTTAutoManager] 模块 1 健康检查 | connected: true | lastDataTime: 0 | timeSinceLastData: -1 s | status: "等待数据" | timeoutCount: 0
[DEBUG] [MQTTAutoManager] 模块 2 健康检查 | connected: true | lastDataTime: 1772527674 | timeSinceLastData: 11 s | status: "数据超时" | timeoutCount: 8
[WARNING] ⚠️ [MQTTAutoManager] 模块 2 数据超时
[DEBUG] [MQTTAutoManager] 模块 3 健康检查 | connected: true | lastDataTime: 0 | timeSinceLastData: -1 s | status: "等待数据" | timeoutCount: 0
[WARNING] ⚠️ [MQTTAutoManager] 模块 0 数据超时
[WARNING] ⚠️ [MQTTAutoManager] 模块 2 数据超时
[WARNING] ⚠️ [MQTTAutoManager] 模块 0 数据超时
[WARNING] ⚠️ [MQTTAutoManager] 模块 2 数据超时
[WARNING] ⚠️ [MQTTAutoManager] 模块 0 数据超时
[WARNING] ⚠️ [MQTTAutoManager] 模块 2 数据超时
