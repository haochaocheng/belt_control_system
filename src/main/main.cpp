#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDebug>
#include <QDir>
#include <iostream>
#include <fstream>
#include <QtPlugin>
#include "hardware/hal/hardware_hal.h"
#include "hardware/simulated/simulated_hal.h"
#include "hardware/real/real_hal.h"
#include "control/belt_controller.h"
#include "utils/logger.h"
#include "sip_phone/SipPhoneManager.h"
#include "control/CommonControl.h"
#include "control/SystemConfig.h"
#include "control/DeviceRuntimeTracker.h"
#include "control/OperationLogDatabase.h"
// ✅ 2026-02-26 08:40 [Phase 7.47.3]: 添加批量音频生成器
#include "control/BatchAudioGenerator.h"
#include "control/DeviceDatabase.h"
#include "control/MaintenanceControl.h"
#include "control/LocalControl.h"
#include "control/ProtectionConfigManager.h"
#include "control/ProtectionMonitorService.h"
#include "control/AlarmPlaybackService.h"
#include "control/AlarmHistoryDatabase.h"
#include "control/DataPathConfig.h"
#include "control/DeviceConfigManager.h"  // ✅ 2026-02-02 [FIX 100.300.112.8.20]: 添加设备配置管理器头文件
#include "control/DeviceRoleManager.h"  // ✅ 2026-02-10 [Phase 7.45]: 添加设备角色管理器头文件
#include "control/TTSConfigManager.h"  // ✅ 2026-02-11 [Phase 7.45.24]: 添加TTS配置管理器头文件
#include "control/SerialPortController.h"  // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.1]: 添加串口控制器头文件
#include "control/ModbusController.h"  // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.4]: 添加MODBUS控制器头文件
#include "control/ModbusSlaveController.h"  // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.40]: 添加MODBUS从站控制器头文件
#include "control/CANController.h"  // ✅ 2026-02-07 [Phase 7.39.1]: 添加CAN控制器头文件
#include "control/ModbusTCPMasterController.h"  // ✅ 2026-02-08 [Phase 7.42]: 添加Modbus TCP主站控制器头文件
#include "control/ModbusTCPSlaveController.h"  // ✅ 2026-02-08 [Phase 7.42]: 添加Modbus TCP从站控制器头文件
#include "control/S7ClientController.h"  // ✅ 2026-02-08 [Phase 7.42]: 添加S7客户端控制器头文件
#include "control/S7ServerController.h"  // ✅ 2026-02-08 [Phase 7.42]: 添加S7服务器控制器头文件
#ifdef MQTT_ENABLED
#include "mqtt/MQTTController.h"  // ✅ 2026-02-08 [Phase 7.43]: 添加MQTT控制器头文件
#include "mqtt/MQTTAutoManager.h"  // ✅ 2026-02-09 [Phase 7.44.1]: 添加MQTT自动管理器头文件
#include "mqtt/DIDataManager.h"  // ✅ 2026-02-09 [Phase 7.44.3]: 添加开关量数据管理器头文件
#include "mqtt/AIDataManager.h"  // ✅ 2026-02-09 [Phase 7.44.4]: 添加模拟量数据管理器头文件
#include "mqtt/DODataManager.h"  // ✅ 2026-03-10 [Phase 7.48.36]: 添加DO模块数据管理器头文件
#include "control/MqttProtectionMonitor.h"  // ✅ 2026-02-27 [Phase 7.47.35]: 添加MQTT保护监控器头文件
#endif
#include "network/NetworkTask.h"

// 全局日志文件
std::ofstream g_logFile;

void logMessage(const QString &msg) {
    if (g_logFile.is_open()) {
        g_logFile << msg.toStdString() << std::endl;
        g_logFile.flush();  // 立即刷新到磁盘
    }
    std::cout << msg.toStdString() << std::endl;
}

void qtMessageHandler(QtMsgType type, const QMessageLogContext &context, const QString &msg)
{
    QString formattedMsg;
    switch (type) {
    case QtDebugMsg:
        formattedMsg = QString("[DEBUG] %1").arg(msg);
        break;
    case QtInfoMsg:
        formattedMsg = QString("[INFO] %1").arg(msg);
        break;
    case QtWarningMsg:
        formattedMsg = QString("[WARNING] %1").arg(msg);
        break;
    case QtCriticalMsg:
        formattedMsg = QString("[CRITICAL] %1").arg(msg);
        break;
    case QtFatalMsg:
        formattedMsg = QString("[FATAL] %1").arg(msg);
        break;
    }

    logMessage(formattedMsg);
}

int main(int argc, char *argv[]) {
    // 打开日志文件
    g_logFile.open("startup_debug.log", std::ios::out | std::ios::trunc);

    logMessage("=== Application starting ===");

    try {
        // 安装Qt消息处理器
        qInstallMessageHandler(qtMessageHandler);

        // Enable Qt Virtual Keyboard
        qputenv("QT_IM_MODULE", QByteArray("qtvirtualkeyboard"));

        QGuiApplication app(argc, argv);
        logMessage("QGuiApplication created");

        QQmlApplicationEngine engine;
        logMessage("QQmlApplicationEngine created");

        // 初始化日志工具
        Logger::init("belt_control_log.txt");
        logMessage("Logger initialized");

        // 注册 SIP Phone Manager 到 QML
        logMessage("Registering SipPhoneManager...");
        SipPhoneManager::registerToQml();
        logMessage("SipPhoneManager registered to QML");

        // ✅ 2026-02-11 [Phase 7.45.24]: 注册 TTSConfigManager 单例到 QML
        logMessage("Registering TTSConfigManager...");
        qmlRegisterSingletonType<TTSConfigManager>("com.belt.control", 1, 0, "TTSConfig",
            [](QQmlEngine *engine, QJSEngine *scriptEngine) -> QObject * {
                Q_UNUSED(engine)
                Q_UNUSED(scriptEngine)
                return TTSConfigManager::instance();
            });
        logMessage("TTSConfigManager registered to QML");

        // 根据平台选择硬件抽象层（Windows用模拟，Linux用真实）
        logMessage("Creating hardware HAL...");
#ifdef Q_OS_WIN
        HardwareHAL* hal = new SimulatedHAL();
        logMessage("Using SimulatedHAL");
#else
        HardwareHAL* hal = new RealHAL();
        logMessage("Using RealHAL");
#endif

        // 初始化控制逻辑（依赖硬件抽象层）
        logMessage("Creating BeltController...");
        BeltController controller(hal);
        logMessage("BeltController initialized");

        // 初始化所有控制模块
        logMessage("Creating control modules...");

        // 输出所有数据文件路径
        DataPathConfig::printAllPaths();

        SystemConfig systemConfig;
        DeviceDatabase deviceDatabase;
        DeviceRuntimeTracker runtimeTracker(&deviceDatabase);

        OperationLogDatabase operationLogDB;
        operationLogDB.initialize();  // 使用统一数据路径

        AlarmHistoryDatabase alarmHistoryDB;
        alarmHistoryDB.initialize(DataPathConfig::getAlarmHistoryDbPath());

        ProtectionConfigManager protectionConfigMgr;
        protectionConfigMgr.initialize(DataPathConfig::getProtectionConfigDbPath());

        // ✅ 2026-02-02 [FIX 100.300.112.8.20]: 初始化设备配置管理器
        DeviceConfigManager deviceConfigMgr;
        deviceConfigMgr.initDatabase(DataPathConfig::getDeviceConfigDbPath());

        // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.1]: 初始化串口控制器
        SerialPortController serialPortController;

        // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.4]: 初始化MODBUS控制器
        ModbusController modbusController;

        // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.40]: 初始化MODBUS从站控制器（6个串口，每个串口一个从站）
        ModbusSlaveController modbusSlaveController1;
        ModbusSlaveController modbusSlaveController2;
        ModbusSlaveController modbusSlaveController3;
        ModbusSlaveController modbusSlaveController4;
        ModbusSlaveController modbusSlaveController5;
        ModbusSlaveController modbusSlaveController6;

        // ✅ 2026-02-07 [Phase 7.39.1]: 初始化CAN控制器
        CANController canController;

        // ✅ 2026-02-08 [Phase 7.42]: 初始化TCP控制器（8个端口，每个端口一组控制器）
        ModbusTCPMasterController modbusTcpMaster1;
        ModbusTCPMasterController modbusTcpMaster2;
        ModbusTCPMasterController modbusTcpMaster3;
        ModbusTCPMasterController modbusTcpMaster4;
        ModbusTCPMasterController modbusTcpMaster5;
        ModbusTCPMasterController modbusTcpMaster6;
        ModbusTCPMasterController modbusTcpMaster7;
        ModbusTCPMasterController modbusTcpMaster8;

        ModbusTCPSlaveController modbusTcpSlave1;
        ModbusTCPSlaveController modbusTcpSlave2;
        ModbusTCPSlaveController modbusTcpSlave3;
        ModbusTCPSlaveController modbusTcpSlave4;
        ModbusTCPSlaveController modbusTcpSlave5;
        ModbusTCPSlaveController modbusTcpSlave6;
        ModbusTCPSlaveController modbusTcpSlave7;
        ModbusTCPSlaveController modbusTcpSlave8;

        S7ClientController s7Client1;
        S7ClientController s7Client2;
        S7ClientController s7Client3;
        S7ClientController s7Client4;
        S7ClientController s7Client5;
        S7ClientController s7Client6;
        S7ClientController s7Client7;
        S7ClientController s7Client8;

        S7ServerController s7Server1;
        S7ServerController s7Server2;
        S7ServerController s7Server3;
        S7ServerController s7Server4;
        S7ServerController s7Server5;
        S7ServerController s7Server6;
        S7ServerController s7Server7;
        S7ServerController s7Server8;

#ifdef MQTT_ENABLED
        // ✅ 2026-02-08 [Phase 7.43]: 初始化MQTT控制器
        MQTTController mqttController;
        logMessage("MQTTController initialized");

        // ✅ 2026-02-09 [Phase 7.44]: 初始化MQTT自动管理器和数据管理器
        MQTTAutoManager mqttAutoManager(&mqttController);
        DIDataManager diDataManager;
        AIDataManager aiDataManager;
        DODataManager doDataManager;  // ✅ 2026-03-10 [Phase 7.48.36]: DO模块数据管理器

        // 连接信号：自动管理器 → 数据管理器
        QObject::connect(&mqttAutoManager, &MQTTAutoManager::moduleDataReceived,
                        [&diDataManager, &aiDataManager, &doDataManager](int moduleIndex, const QString &topic, const QByteArray &payload) {
            if (moduleIndex < 2) {
                // 开关量模块（0, 1）
                diDataManager.parseData(moduleIndex, payload);
            } else if (moduleIndex < 4) {
                // 模拟量模块（2, 3）
                aiDataManager.parseData(moduleIndex, payload);
            } else if (moduleIndex == 4) {
                // ✅ 2026-03-10 [Phase 7.48.36]: DO模块（4）
                doDataManager.parseData(payload);
            }
        });

        // ✅ 2026-03-01 [Phase 7.47.61]: 模块断开时重置DI数据
        // 原因：模块断开后 DIDataManager 保持最后值不清零，导致通道状态冻结
        // 效果：模块离线 → 对应DI模块数据立即清零 → QML通道状态LED熄灭
        QObject::connect(&mqttController, &MQTTController::connectedChanged,
                        [&diDataManager, &doDataManager](int moduleIndex, bool connected) {
            if (!connected && moduleIndex < 2) {
                diDataManager.resetModule(moduleIndex);
            }
            // ✅ 2026-03-10 [Phase 7.48.36]: DO模块断开时重置数据
            if (!connected && moduleIndex == 4) {
                doDataManager.reset();
            }
        });

        // 启动自动管理器
        mqttAutoManager.start();
        logMessage("MQTT Auto Manager started");

        // ✅ 2026-02-27 11:30 [Phase 7.47.36]: 移除此处的MqttProtectionMonitor创建，因为commonControl尚未声明
        // 移动到commonControl声明之后（见下方#ifdef MQTT_ENABLED块）
#endif

        NetworkTask networkTask;

        CommonControl commonControl;
        commonControl.setSystemConfig(&systemConfig);
        commonControl.setNetworkTask(&networkTask);
        commonControl.setOperationLogDB(&operationLogDB);
        commonControl.setRuntimeTracker(&runtimeTracker);

        // ✅ 2026-02-26 08:40 [Phase 7.47.3]: 创建批量音频生成器
        // 注意：需要传入 CommonControl 的 TTS 引擎管理器
        BatchAudioGenerator batchAudioGenerator(commonControl.getTTSEngineManager());
        logMessage("BatchAudioGenerator created");

        MaintenanceControl maintenanceControl(hal);
        LocalControl localControl(hal);

        ProtectionMonitorService protectionMonitor;
        protectionMonitor.setProtectionConfigManager(&protectionConfigMgr);
        protectionMonitor.setNetworkTask(&networkTask);

        AlarmPlaybackService alarmPlayback;
        logMessage("All control modules created");

        // ✅ 2026-02-10 [Phase 7.45]: 初始化设备角色管理器
        DeviceRoleManager deviceRoleManager;
        deviceRoleManager.loadFromConfig();  // 从配置文件加载
        logMessage("DeviceRoleManager initialized");

#ifdef MQTT_ENABLED
        // ✅ 2026-02-10 [Phase 7.45.6]: 设置 MQTT 控制器并启动发布
        deviceRoleManager.setMQTTController(&mqttController);
        deviceRoleManager.startMQTTPublishing();
        logMessage("DeviceRoleManager MQTT publishing started");

        // ✅ 2026-02-27 11:30 [Phase 7.47.36]: 移到此处，确保commonControl已声明
        MqttProtectionMonitor mqttProtectionMonitor(&diDataManager, &commonControl);
        // ✅ 2026-02-28 [Phase 7.47.49]: 注入DeviceConfigManager，用于查询每个保护的use_text_to_speech
        mqttProtectionMonitor.setDeviceConfigManager(&deviceConfigMgr);
        // ✅ 2026-03-04 [Phase 7.47.95]: 注入AlarmPlaybackService，用于按次数/按时长播放
        mqttProtectionMonitor.setAlarmPlaybackService(&alarmPlayback);
        // ✅ 2026-03-05 [Phase 7.48.5]: 注入AIDataManager，用于模拟量保护监控
        mqttProtectionMonitor.setAIDataManager(&aiDataManager);
        // ✅ 2026-03-09 [Phase 7.48.26]: 注入MQTTController，用于洒水控制MQTT发布
        mqttProtectionMonitor.setMQTTController(&mqttController);
        mqttProtectionMonitor.setAIBeltMapping(0, systemConfig.machineNumber());  // AI模块0(模拟量模块1) → 当前皮带
        // ✅ 2026-03-07 [Phase 7.48.19]: 补充模拟量模块2的皮带映射（旧代码遗漏，导致模块2保护查询默认皮带1）
        mqttProtectionMonitor.setAIBeltMapping(1, systemConfig.machineNumber());  // AI模块1(模拟量模块2) → 当前皮带
        // 连接AIDataManager的channelChanged信号到MqttProtectionMonitor
        QObject::connect(&aiDataManager, &AIDataManager::channelChanged,
                         &mqttProtectionMonitor, &MqttProtectionMonitor::onAIChannelChanged);
        logMessage("AI channel monitoring connected to MqttProtectionMonitor");
        // ✅ 2026-03-10 [Phase 7.48.37]: 注入TTSEngineManager到AlarmPlaybackService
        // 原因：AlarmPlaybackService内部使用SherpaOnnxTTS，应改用PaddleSpeech（通过TTSEngineManager）
        alarmPlayback.setTTSEngineManager(commonControl.getTTSEngineManager());
        // ✅ 2026-03-04 [Phase 7.47.97]: 启动报警播放服务（设置m_isRunning=true，否则playAlarm拒绝播放）
        alarmPlayback.start();
        // ✅ 2026-02-28 [Phase 7.47.53]: 用systemConfig.machineNumber()覆盖硬编码的模块0→1号皮带映射
        // 旧值：构造函数内 m_beltMapping[0] = 1（硬编码）
        // 原因：非1号皮带设备，loadDigitalProtection(1, ...) 查不到配置，导致useTTS回退true，
        //       getDefaultAudioPath(1, ...) 生成错误路径 1#PD/ 而非实际皮带号文件夹
        mqttProtectionMonitor.setBeltMapping(0, systemConfig.machineNumber());
        mqttProtectionMonitor.start();
        logMessage("MQTT Protection Monitor started");

        // ✅ 2026-03-02 [Phase 7.47.69]: 连接 MQTTAutoManager 语音提醒信号到 CommonControl 播放
        // 触发场景：①模块离线（数据超时）②程序连接EMQX服务器超时
        QObject::connect(&mqttAutoManager, &MQTTAutoManager::voiceAlertRequested,
                         &commonControl, &CommonControl::playAudio);
        logMessage("MQTT module offline voice alert connected");

        // ✅ 2026-02-28 [Phase 7.47.46]: 连接保护触发信号到报警历史数据库
        // 当DI位从0→1（保护触发）时，自动记录到报警历史数据库
        // protectionTriggered(moduleIndex, bitIndex, beltNumber, protectionName, audioPath)
        QObject::connect(&mqttProtectionMonitor, &MqttProtectionMonitor::protectionTriggered,
            [&alarmHistoryDB](int /*moduleIndex*/, int /*bitIndex*/, int beltNumber,
                              const QString &protectionName, const QString &/*audioPath*/) {
                // protectionType: "X号皮带" 标识是哪条皮带触发的保护
                QString protectionType = QString("%1号皮带").arg(beltNumber);
                alarmHistoryDB.saveAlarmTriggered(protectionName, protectionType, 0.0);
                qDebug() << "📝 [Main] 保护触发已记录到报警历史 -"
                         << protectionName << "皮带:" << beltNumber;
            });
        logMessage("Protection trigger -> alarm history DB connection established");

        // ✅ 2026-03-09 [Phase 7.48.24]: 连接模拟量保护触发/恢复信号到报警历史数据库
        // AI保护触发记录（边沿触发，每次超限只记录一次）
        QObject::connect(&mqttProtectionMonitor, &MqttProtectionMonitor::analogProtectionTriggered,
            [&alarmHistoryDB](int beltNumber, const QString &protectionName,
                              double engineeringValue, const QString &limitType) {
                QString protectionType = QString("%1号皮带").arg(beltNumber);
                alarmHistoryDB.saveAlarmTriggered(protectionName + "(" + limitType + ")",
                                                  protectionType, engineeringValue);
                qDebug() << "📝 [Main] 模拟量保护触发已记录 -" << protectionName
                         << limitType << "值:" << engineeringValue << "皮带:" << beltNumber;
            });

        // AI保护恢复记录
        QObject::connect(&mqttProtectionMonitor, &MqttProtectionMonitor::analogProtectionRestored,
            [&alarmHistoryDB](int beltNumber, const QString &protectionName,
                              double engineeringValue) {
                alarmHistoryDB.saveAlarmRestored(protectionName);
                qDebug() << "📝 [Main] 模拟量保护恢复已记录 -" << protectionName
                         << "值:" << engineeringValue << "皮带:" << beltNumber;
            });
        logMessage("Analog protection trigger/restore -> alarm history DB connection established");
#endif

        // 将C++对象注册到QML（QML中可直接访问其属性和信号）
        logMessage("Setting context properties...");
        // ✅ 2026-03-01 [Phase 7.47.55]: 注入音频基础目录到QML，兼容linaro和pi设备
        // 旧方式：QML用process.env.BELT_CONTROL_USER（Node.js API，QML不支持），永远回退linaro
        // 新方式：C++读取环境变量后直接注入字符串，QML直接使用
        engine.rootContext()->setContextProperty("audioBaseDir", DataPathConfig::getAudioBaseDirectory());
        engine.rootContext()->setContextProperty("controller", &controller);
        engine.rootContext()->setContextProperty("logger", Logger::instance());
        engine.rootContext()->setContextProperty("systemConfig", &systemConfig);
        engine.rootContext()->setContextProperty("deviceDatabase", &deviceDatabase);
        engine.rootContext()->setContextProperty("runtimeTracker", &runtimeTracker);
        engine.rootContext()->setContextProperty("operationLogDB", &operationLogDB);
        engine.rootContext()->setContextProperty("alarmHistoryDB", &alarmHistoryDB);
        engine.rootContext()->setContextProperty("protectionConfigMgr", &protectionConfigMgr);
        engine.rootContext()->setContextProperty("deviceConfigMgr", &deviceConfigMgr);  // ✅ 2026-02-02 [FIX 100.300.112.8.20]: 注册设备配置管理器到QML
        engine.rootContext()->setContextProperty("deviceRoleManager", &deviceRoleManager);  // ✅ 2026-02-10 [Phase 7.45]: 注册设备角色管理器到QML
        engine.rootContext()->setContextProperty("serialPortController", &serialPortController);  // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.1]: 注册串口控制器到QML
        engine.rootContext()->setContextProperty("modbusController", &modbusController);  // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.4]: 注册MODBUS控制器到QML
        engine.rootContext()->setContextProperty("canController", &canController);  // ✅ 2026-02-07 [Phase 7.39.1]: 注册CAN控制器到QML
        // ✅ 2026-02-08 [Phase 7.42]: 注册TCP控制器到QML（8个端口，每个端口一组控制器）
        engine.rootContext()->setContextProperty("modbusTcpMaster1", &modbusTcpMaster1);
        engine.rootContext()->setContextProperty("modbusTcpMaster2", &modbusTcpMaster2);
        engine.rootContext()->setContextProperty("modbusTcpMaster3", &modbusTcpMaster3);
        engine.rootContext()->setContextProperty("modbusTcpMaster4", &modbusTcpMaster4);
        engine.rootContext()->setContextProperty("modbusTcpMaster5", &modbusTcpMaster5);
        engine.rootContext()->setContextProperty("modbusTcpMaster6", &modbusTcpMaster6);
        engine.rootContext()->setContextProperty("modbusTcpMaster7", &modbusTcpMaster7);
        engine.rootContext()->setContextProperty("modbusTcpMaster8", &modbusTcpMaster8);
        engine.rootContext()->setContextProperty("modbusTcpSlave1", &modbusTcpSlave1);
        engine.rootContext()->setContextProperty("modbusTcpSlave2", &modbusTcpSlave2);
        engine.rootContext()->setContextProperty("modbusTcpSlave3", &modbusTcpSlave3);
        engine.rootContext()->setContextProperty("modbusTcpSlave4", &modbusTcpSlave4);
        engine.rootContext()->setContextProperty("modbusTcpSlave5", &modbusTcpSlave5);
        engine.rootContext()->setContextProperty("modbusTcpSlave6", &modbusTcpSlave6);
        engine.rootContext()->setContextProperty("modbusTcpSlave7", &modbusTcpSlave7);
        engine.rootContext()->setContextProperty("modbusTcpSlave8", &modbusTcpSlave8);
        engine.rootContext()->setContextProperty("s7Client1", &s7Client1);
        engine.rootContext()->setContextProperty("s7Client2", &s7Client2);
        engine.rootContext()->setContextProperty("s7Client3", &s7Client3);
        engine.rootContext()->setContextProperty("s7Client4", &s7Client4);
        engine.rootContext()->setContextProperty("s7Client5", &s7Client5);
        engine.rootContext()->setContextProperty("s7Client6", &s7Client6);
        engine.rootContext()->setContextProperty("s7Client7", &s7Client7);
        engine.rootContext()->setContextProperty("s7Client8", &s7Client8);
        engine.rootContext()->setContextProperty("s7Server1", &s7Server1);
        engine.rootContext()->setContextProperty("s7Server2", &s7Server2);
        engine.rootContext()->setContextProperty("s7Server3", &s7Server3);
        engine.rootContext()->setContextProperty("s7Server4", &s7Server4);
        engine.rootContext()->setContextProperty("s7Server5", &s7Server5);
        engine.rootContext()->setContextProperty("s7Server6", &s7Server6);
        engine.rootContext()->setContextProperty("s7Server7", &s7Server7);
        engine.rootContext()->setContextProperty("s7Server8", &s7Server8);
#ifdef MQTT_ENABLED
        // ✅ 2026-02-08 [Phase 7.43]: 注册MQTT控制器到QML
        engine.rootContext()->setContextProperty("mqttController", &mqttController);
        // ✅ 2026-02-09 [Phase 7.44]: 注册MQTT自动管理器和数据管理器到QML
        engine.rootContext()->setContextProperty("mqttAutoManager", &mqttAutoManager);
        engine.rootContext()->setContextProperty("diDataManager", &diDataManager);
        engine.rootContext()->setContextProperty("aiDataManager", &aiDataManager);
        engine.rootContext()->setContextProperty("doDataManager", &doDataManager);  // ✅ 2026-03-10 [Phase 7.48.36]
#endif
        // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.40]: 注册MODBUS从站控制器到QML（6个串口，每个串口一个从站）
        engine.rootContext()->setContextProperty("modbusSlaveController1", &modbusSlaveController1);
        engine.rootContext()->setContextProperty("modbusSlaveController2", &modbusSlaveController2);
        engine.rootContext()->setContextProperty("modbusSlaveController3", &modbusSlaveController3);
        engine.rootContext()->setContextProperty("modbusSlaveController4", &modbusSlaveController4);
        engine.rootContext()->setContextProperty("modbusSlaveController5", &modbusSlaveController5);
        engine.rootContext()->setContextProperty("modbusSlaveController6", &modbusSlaveController6);
        engine.rootContext()->setContextProperty("commonControl", &commonControl);
        // ✅ 2026-02-26 08:45 [Phase 7.47.3]: 注册批量音频生成器到QML
        engine.rootContext()->setContextProperty("batchGeneratorController", &batchAudioGenerator);
        engine.rootContext()->setContextProperty("maintenanceControl", &maintenanceControl);
        engine.rootContext()->setContextProperty("localControl", &localControl);
        engine.rootContext()->setContextProperty("networkTask", &networkTask);
        engine.rootContext()->setContextProperty("protectionMonitor", &protectionMonitor);
        engine.rootContext()->setContextProperty("alarmPlayback", &alarmPlayback);
        // ✅ 2026-03-10 [Phase 7.48.31]: 注册MQTT保护监控器到QML（用于电机控制命令发布）
        engine.rootContext()->setContextProperty("mqttProtectionMonitor", &mqttProtectionMonitor);
        logMessage("Context properties set");

        // 添加QML导入路径
        logMessage("Adding QML import path...");
        engine.addImportPath("qrc:/qt/qml");
        logMessage("QML import path added");

        // 加载QML主界面
        const QUrl url(QStringLiteral("qrc:/qt/qml/BeltControlQml/main.qml"));
        logMessage("Loading QML from: " + url.toString());

        QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
            &app, [url](QObject *obj, const QUrl &objUrl) {
                QString msg = QString("Object created callback: obj=%1").arg((qulonglong)obj, 0, 16);
                logMessage(msg);
                if (!obj && url == objUrl) {
                    logMessage("CRITICAL: Failed to load QML file!");
                    QCoreApplication::exit(-1);
                }
            }, Qt::QueuedConnection);

        engine.load(url);
        logMessage("engine.load() completed");

        if (engine.rootObjects().isEmpty()) {
            logMessage("ERROR: No root objects loaded!");
            logMessage("Available import paths:");
            for (const QString &path : engine.importPathList()) {
                logMessage("  " + path);
            }
            g_logFile.close();
            return -1;
        }

        logMessage("QML loaded successfully, starting event loop");
        int result = app.exec();
        logMessage(QString("Application exited with code: %1").arg(result));
        g_logFile.close();
        return result;

    } catch (const std::exception& e) {
        logMessage(QString("EXCEPTION CAUGHT: %1").arg(e.what()));
        g_logFile.close();
        return -1;
    } catch (...) {
        logMessage("UNKNOWN EXCEPTION CAUGHT!");
        g_logFile.close();
        return -1;
    }
}
