
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
  Total reclaimed space: 831.4MB

[4/4] 磁盘状态检查...
  磁盘占用: 21%
  Docker 占用: 5.2G

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
[DEBUG] 🔄 [DeviceConfigManager] 检查迁移 001（开关量保护）...
[DEBUG] ⏭️ [DeviceConfigManager] 迁移001已执行过，跳过
[DEBUG] 🔄 [DeviceConfigManager] 检查迁移 002（模拟量保护）...
[DEBUG] ⏭️ [DeviceConfigManager] 迁移002已执行过，跳过
[DEBUG] 🔄 [DeviceConfigManager] 检查迁移 003（模拟量保护扩展至18项）...
[DEBUG] ⏭️ [DeviceConfigManager] 迁移003已执行过，跳过
[DEBUG] 🔄 [DeviceConfigManager] 检查迁移 004（速度保护额定速度+延时字段）...
[DEBUG] ⏭️ [DeviceConfigManager] 迁移004已执行过，跳过
[DEBUG] 🔄 [DeviceConfigManager] 检查迁移 005（修正通道号和模块类型）...
[DEBUG] ⏭️ [DeviceConfigManager] 迁移005已执行过，跳过
[DEBUG] 🔄 [DeviceConfigManager] 检查迁移 006（删除旧拆分保护项）...
[DEBUG] ⏭️ [DeviceConfigManager] 迁移006已执行过，跳过
[DEBUG] 🔄 [DeviceConfigManager] 检查迁移 007（重新排序模拟量保护项）...
[DEBUG] ⏭️ [DeviceConfigManager] 迁移007已执行过，跳过
[DEBUG] 🔄 [DeviceConfigManager] 检查迁移 008（修复模拟量保护项排序）...
[DEBUG] ⏭️ [DeviceConfigManager] 迁移008已执行过，跳过
[DEBUG] 🔄 [DeviceConfigManager] 检查迁移 009（恢复完整的18项模拟量保护）...
[DEBUG] ⏭️ [DeviceConfigManager] 迁移009已执行过，跳过
[DEBUG] 🔄 [DeviceConfigManager] 检查迁移 010（审核后更新模拟量保护默认值）...
[DEBUG] ⏭️ [DeviceConfigManager] 迁移010已执行过，跳过
[DEBUG] 🔄 [DeviceConfigManager] 检查迁移 011（修正模拟量保护上限值为安全规程标准）...
[DEBUG] ⏭️ [DeviceConfigManager] 迁移011已执行过，跳过
[DEBUG] 🔄 [DeviceConfigManager] 检查迁移 012（完整通道重映射：截图顺序分配CH0-CH7）...
[DEBUG] ⏭️ [DeviceConfigManager] 迁移012已执行过，跳过
[DEBUG] 🔄 [DeviceConfigManager] 检查迁移 013（洒水使能默认值）...
[DEBUG] 🔧 [DeviceConfigManager] 执行迁移013: 设置洒水使能默认值
[DEBUG]   ✅ 模拟量保护洒水使能: 48 条
[DEBUG]   ✅ 开关量保护洒水使能: 24 条
[DEBUG]   ✅ 洒水输出配置初始化完成
[DEBUG] ⏭️ [DeviceConfigManager] 数据已初始化，跳过
[DEBUG] ✅ [DeviceConfigManager] 数据库初始化完成
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
[DEBUG] ✅ [AIDataManager] 滤波器初始化完成，类型: "limit"
[DEBUG] ✅ [AIDataManager] 初始化模拟量数据管理器（滤波器: "limit" ）
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
[DEBUG] ✅ TTS服务进程已启动，PID: 58
[DEBUG] 📤 发送命令: "{\"command\":\"init\",\"model_dir\":\"/app/tts_models/vits-zh-aishell3\"}\n"
[DEBUG] ✅ [MQTTAutoManager] 模块 0 已连接
[DEBUG] ✅ [MQTTController] 模块 0 订阅主题: "belt_control/di/module1/status" QoS: 1
[DEBUG] ✅ [MQTTAutoManager] 模块 0 订阅主题: "belt_control/di/module1/status"
[DEBUG] ✅ [MQTTAutoManager] 模块 1 已连接
[DEBUG] ✅ [MQTTController] 模块 1 订阅主题: "belt_control/di/module2/status" QoS: 1
[DEBUG] ✅ [MQTTAutoManager] 模块 1 订阅主题: "belt_control/di/module2/status"
[DEBUG] ✅ [MQTTAutoManager] 模块 2 已连接
[DEBUG] ✅ [MQTTController] 模块 2 订阅主题: "belt_control/ai/module1/status" QoS: 1
[DEBUG] ✅ [MQTTAutoManager] 模块 2 订阅主题: "belt_control/ai/module1/status"
[DEBUG] ✅ [MQTTAutoManager] 模块 3 已连接
[DEBUG] ✅ [MQTTController] 模块 3 订阅主题: "belt_control/ai/module2/status" QoS: 1
[DEBUG] ✅ [MQTTAutoManager] 模块 3 订阅主题: "belt_control/ai/module2/status"
[DEBUG] ✅ [MQTTAutoManager] 模块 0 硬件数据到达，状态从 "已连接" → 正常
[DEBUG] ✅ [MQTTAutoManager] 模块 2 硬件数据到达，状态从 "已连接" → 正常
[DEBUG] 📥 收到响应: "{\"success\":true,\"message\":\"TTS engine initialized successfully. Sample rate: 8000Hz\"}"
[DEBUG] ✅ SherpaOnnxTTS初始化成功: "TTS engine initialized successfully. Sample rate: 8000Hz"
[DEBUG] ✅ Sherpa-ONNX TTS初始化成功
[DEBUG] 设置语速: 0.9
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
[DEBUG] ✅ [MqttProtectionMonitor] 设置AI模块 0 → 1 号皮带
[DEBUG] ✅ [MqttProtectionMonitor] 设置AI模块 1 → 1 号皮带
AI channel monitoring connected to MqttProtectionMonitor
[DEBUG] 🚀 AlarmPlaybackService: 启动报警播放服务
[DEBUG] 📝 [MqttProtectionMonitor] 设置皮带映射: 模块 0 → 1 号皮带
[DEBUG] 🚀 [MqttProtectionMonitor] 启动MQTT保护监控
[DEBUG] 📋 [MqttProtectionMonitor] 皮带映射:
[DEBUG]    模块 0 → 1 号皮带
[DEBUG]    模块 1 → 2 号皮带
MQTT Protection Monitor started
MQTT module offline voice alert connected
Protection trigger -> alarm history DB connection established
Analog protection trigger/restore -> alarm history DB connection established
Setting context properties...
Context properties set
Adding QML import path...
QML import path added
Loading QML from: qrc:/qt/qml/BeltControlQml/main.qml
[WARNING] QQmlApplicationEngine failed to load component
[WARNING] qrc:/qt/qml/BeltControlQml/main.qml:65:5: Type App unavailable
[WARNING] qrc:/qt/qml/BeltControlQml/App.qml:242:9: Type VoiceManagement unavailable
[WARNING] qrc:/qt/qml/BeltControlQml/pages/VoiceManagement.qml:434:21: BatchSynthesisContent is not a type
engine.load() completed
ERROR: No root objects loaded!
Available import paths:
  qrc:/qt/qml
  /app
  qrc:/qt-project.org/imports
  /app/qml
[DEBUG] 🛑 [MqttProtectionMonitor] 停止MQTT保护监控
[DEBUG] ✅ [MqttProtectionMonitor] MQTT保护监控器已销毁
[DEBUG] ✅ [MQTTController] 模块 0 取消订阅: "station/status/+"
[DEBUG] ✅ [MQTTController] 模块 0 取消订阅: "device/status/+"
[DEBUG] 📡 [DeviceRoleManager] 取消订阅所有主题
[DEBUG] 🛑 [DeviceRoleManager] MQTT 发布已停止
[DEBUG] 💾 [DeviceRoleManager] 配置已保存: "/root/.config/belt_control_system/device_role.json"
[DEBUG] 🛑 AlarmPlaybackService: 停止报警播放服务
[DEBUG] ✅ AlarmPlaybackService: 报警播放服务已销毁
[DEBUG] 🛑 SherpaOnnxTTS: 停止TTS服务进程
[DEBUG] ✅ SherpaOnnxTTS: TTS封装已销毁
[DEBUG] 📡 停止独立发送线程...
[DEBUG] ✅ 独立发送线程已停止
[DEBUG] 📡 停止所有服务
[DEBUG] ✅ AudioNetworkTcpSender 析构完成
[DEBUG] ✅ WebSocketClient 析构完成
[DEBUG] [AudioNetworkSender] 销毁音频网络发送器
[DEBUG] ✅ ProtectionMonitorService: 保护监控服务已销毁
[DEBUG] ✅ LocalControl: 就地模式控制已销毁
[DEBUG] ✅ MaintenanceControl: 检修模式控制已销毁
[DEBUG] ✅ CommonControl: 公共控制模块已销毁
[DEBUG] [AudioNetworkSender] 销毁音频网络发送器
[DEBUG] 📡 停止独立发送线程...
[DEBUG] ✅ 独立发送线程已停止
[DEBUG] 📡 停止所有服务
[DEBUG] ✅ AudioNetworkTcpSender 析构完成
[DEBUG] ✅ WebSocketClient 析构完成
[DEBUG] 🔴 [TTSEngineManager] 销毁
[DEBUG] 🔴 [PaddleSpeech] 适配器销毁
[DEBUG] ✅ NetworkTask: 网络任务已销毁
[DEBUG] ✅ ModbusTcpClient: Modbus TCP客户端已销毁
[DEBUG] ✅ [MQTTAutoManager] 销毁自动管理器
[DEBUG] 🛑 [MQTTAutoManager] 停止自动管理器
[DEBUG] ✅ [MQTTAutoManager] 停止重连检查定时器
[DEBUG] ✅ [MQTTAutoManager] 停止开关量采集定时器
[DEBUG] ✅ [MQTTAutoManager] 停止模拟量采集定时器
[DEBUG] ✅ [MQTTAutoManager] 停止健康检查定时器
[DEBUG] ✅ [MQTTAutoManager] 自动管理器已停止
[DEBUG] ✅ [MQTTController] 销毁 MQTT 控制器
[DEBUG] ✅ [MQTTController] 断开所有模块
[DEBUG] ✅ [DIDataManager] 模块 0 数据已重置（模块离线）
[DEBUG] ✅ [DIDataManager] 模块 1 数据已重置（模块离线）
corrupted double-linked list

Application exited with code: 133

========================================
检测到崩溃：内存错误（SIGTRAP - free() invalid pointer） (exit code 133)
自动分析 Core Dump
========================================
✓ 找到 Core Dump: /tmp/belt-control-cores/core.belt_control_sy.1.1773040957
  文件大小: 236M

正在分析崩溃原因（这需要几秒钟）...

warning: Can't open file /memfd:pulseaudio (deleted) during file-backed mapping note processing

warning: Can't open file /memfd:JSGCHeap:QtQml (deleted) during file-backed mapping note processing

warning: Can't open file /memfd:JSVMStack:QtQml (deleted) during file-backed mapping note processing

warning: Can't open file /usr/lib/aarch64-linux-gnu/libxcb-dri2.so.0 during file-backed mapping note processing

warning: Can't open file /opt/mali/libmali.so.1 during file-backed mapping note processing

warning: Can't open file /memfd:unknown-usage:QtQml (deleted) during file-backed mapping note processing
[New LWP 1]
[New LWP 46]
[New LWP 39]
[New LWP 36]
[New LWP 38]
[New LWP 47]
[New LWP 52]
[New LWP 51]
[New LWP 54]
[New LWP 56]

warning: Could not load shared library symbols for 2 libraries, e.g. /opt/mali/libmali.so.1.
Use the "info sharedlibrary" command to see the complete listing.
Do you need "set solib-search-path" or "set sysroot"?

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libv4l2.so.0

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libpulse.so.0

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libgbm.so.1

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libglib-2.0.so.0

warning: could not find '.gnu_debugaltlink' file for /app/lib/libzvbi.so.0

warning: could not find '.gnu_debugaltlink' file for /app/lib/libtheoraenc.so.1

warning: could not find '.gnu_debugaltlink' file for /app/lib/libtheoradec.so.1

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libbrotlidec.so.1

warning: could not find '.gnu_debugaltlink' file for /app/lib/libicui18n.so.67

warning: could not find '.gnu_debugaltlink' file for /app/lib/libicuuc.so.67

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libcap.so.2

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/pulseaudio/libpulsecommon-16.1.so

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libbrotlicommon.so.1

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libgstphotography-1.0.so.0

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libgstpbutils-1.0.so.0

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libgstapp-1.0.so.0

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libgstallocators-1.0.so.0

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libgstvideo-1.0.so.0

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libgstbase-1.0.so.0

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libgstreamer-1.0.so.0

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libgobject-2.0.so.0

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libgstaudio-1.0.so.0

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libgsttag-1.0.so.0

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libgmodule-2.0.so.0

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/gstreamer-1.0/libgstdecklink.so

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/gstreamer-1.0/libgstpulseaudio.so

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/gstreamer-1.0/libgstuvch264.so

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libgstbasecamerabinsrc-1.0.so.0

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/gstreamer-1.0/libgstvideo4linux2.so

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/gstreamer-1.0/libgstossaudio.so

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/gstreamer-1.0/libgstvulkan.so

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libgstvulkan-1.0.so.0

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libgstcodecs-1.0.so.0

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libgstcodecparsers-1.0.so.0

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libvulkan_nouveau.so

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libvulkan_broadcom.so

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libvulkan_freedreno.so

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libvulkan_lvp.so

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libtinfo.so.6

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libvulkan_gfxstream.so

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libvulkan_panfrost.so

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libvulkan_intel.so

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libvulkan_asahi.so

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libvulkan_radeon.so

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libvulkan_virtio.so

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/libVkLayer_MESA_device_select.so

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/gstreamer-1.0/libgstvideoconvertscale.so

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/gstreamer-1.0/libgstcoreelements.so

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/gstreamer-1.0/libgstplayback.so

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/gstreamer-1.0/libgstaudioconvert.so

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/gstreamer-1.0/libgstaudioresample.so

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/gstreamer-1.0/libgstvolume.so

warning: could not find '.gnu_debugaltlink' file for /usr/lib/aarch64-linux-gnu/gstreamer-1.0/libgstautodetect.so

warning: 107    ./stdlib/abort.c: No such file or directory
[Thread debugging using libthread_db enabled]
Using host libthread_db library "/usr/lib/aarch64-linux-gnu/libthread_db.so.1".
Core was generated by `/app/belt_control_system'.
Program terminated with signal SIGTRAP, Trace/breakpoint trap.
#0  __GI_abort () at ./stdlib/abort.c:107
[Current thread is 1 (Thread 0x7f9c061040 (LWP 1))]

========================================
崩溃分析报告
========================================

[1] 崩溃位置
#0  __GI_abort () at ./stdlib/abort.c:107
#1  0x0000007f965fabf4 in __libc_message_impl (fmt=fmt@entry=0x7f966e4c28 "%s\n") at ../sysdeps/posix/libc_fatal.c:134
#2  0x0000007f9661210c in malloc_printerr (str=str@entry=0x7f966dfc98 "corrupted double-linked list") at ./malloc/malloc.c:5775

[2] 寄存器状态

[3] Frame 2 详情（avcodec_open2）
Invalid register `rip'
warning: 5775   ./malloc/malloc.c: No such file or directory
#2  0x0000007f9661210c in malloc_printerr (str=str@entry=0x7f966dfc98 "corrupted double-linked list") at ./malloc/malloc.c:5775
No locals.

[4] Frame 3 详情（open_ffmpeg_codec）
#3  0x0000007f96612a9c in unlink_chunk (p=p@entry=0x55a4868bb0, av=0x7f96730a50 <main_arena>) at ./malloc/malloc.c:1617
1617    in ./malloc/malloc.c
fd = 0x5
bk = <optimized out>

========================================
分析完成
========================================

✓ 分析完成并保存到: /tmp/belt-control-cores/core.belt_control_sy.1.1773040957.analysis.txt

========================================
崩溃原因摘要
========================================
[1] 崩溃位置
#0  __GI_abort () at ./stdlib/abort.c:107
#1  0x0000007f965fabf4 in __libc_message_impl (fmt=fmt@entry=0x7f966e4c28 "%s\n") at ../sysdeps/posix/libc_fatal.c:134
#2  0x0000007f9661210c in malloc_printerr (str=str@entry=0x7f966dfc98 "corrupted double-linked list") at ./malloc/malloc.c:5775

完整分析: /tmp/belt-control-cores/core.belt_control_sy.1.1773040957.analysis.txt

========================================
参考文档
========================================
  Core Dump 分析: docs/2026-01-09/72-Core-Dump分析-编码器初始化崩溃根因.md
  解决方案: docs/2026-01-09/73-Fix100.12-硬件编码器解决DRM_PRIME问题.md

linaro@enc:~$
