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
#include "control/DeviceDatabase.h"
#include "control/MaintenanceControl.h"
#include "control/LocalControl.h"
#include "control/ProtectionConfigManager.h"
#include "control/ProtectionMonitorService.h"
#include "control/AlarmPlaybackService.h"
#include "control/AlarmHistoryDatabase.h"
#include "control/DataPathConfig.h"
#include "control/DeviceConfigManager.h"  // ✅ 2026-02-02 [FIX 100.300.112.8.20]: 添加设备配置管理器头文件
#include "control/SerialPortController.h"  // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.1]: 添加串口控制器头文件
#include "control/ModbusController.h"  // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.4]: 添加MODBUS控制器头文件
#include "control/ModbusSlaveController.h"  // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.40]: 添加MODBUS从站控制器头文件
#include "control/CANController.h"  // ✅ 2026-02-07 [Phase 7.39.1]: 添加CAN控制器头文件
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

        NetworkTask networkTask;

        CommonControl commonControl;
        commonControl.setSystemConfig(&systemConfig);
        commonControl.setNetworkTask(&networkTask);
        commonControl.setOperationLogDB(&operationLogDB);
        commonControl.setRuntimeTracker(&runtimeTracker);

        MaintenanceControl maintenanceControl(hal);
        LocalControl localControl(hal);

        ProtectionMonitorService protectionMonitor;
        protectionMonitor.setProtectionConfigManager(&protectionConfigMgr);
        protectionMonitor.setNetworkTask(&networkTask);

        AlarmPlaybackService alarmPlayback;
        logMessage("All control modules created");

        // 将C++对象注册到QML（QML中可直接访问其属性和信号）
        logMessage("Setting context properties...");
        engine.rootContext()->setContextProperty("controller", &controller);
        engine.rootContext()->setContextProperty("logger", Logger::instance());
        engine.rootContext()->setContextProperty("systemConfig", &systemConfig);
        engine.rootContext()->setContextProperty("deviceDatabase", &deviceDatabase);
        engine.rootContext()->setContextProperty("runtimeTracker", &runtimeTracker);
        engine.rootContext()->setContextProperty("operationLogDB", &operationLogDB);
        engine.rootContext()->setContextProperty("alarmHistoryDB", &alarmHistoryDB);
        engine.rootContext()->setContextProperty("protectionConfigMgr", &protectionConfigMgr);
        engine.rootContext()->setContextProperty("deviceConfigMgr", &deviceConfigMgr);  // ✅ 2026-02-02 [FIX 100.300.112.8.20]: 注册设备配置管理器到QML
        engine.rootContext()->setContextProperty("serialPortController", &serialPortController);  // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.1]: 注册串口控制器到QML
        engine.rootContext()->setContextProperty("modbusController", &modbusController);  // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.4]: 注册MODBUS控制器到QML
        engine.rootContext()->setContextProperty("canController", &canController);  // ✅ 2026-02-07 [Phase 7.39.1]: 注册CAN控制器到QML
        // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.40]: 注册MODBUS从站控制器到QML（6个串口，每个串口一个从站）
        engine.rootContext()->setContextProperty("modbusSlaveController1", &modbusSlaveController1);
        engine.rootContext()->setContextProperty("modbusSlaveController2", &modbusSlaveController2);
        engine.rootContext()->setContextProperty("modbusSlaveController3", &modbusSlaveController3);
        engine.rootContext()->setContextProperty("modbusSlaveController4", &modbusSlaveController4);
        engine.rootContext()->setContextProperty("modbusSlaveController5", &modbusSlaveController5);
        engine.rootContext()->setContextProperty("modbusSlaveController6", &modbusSlaveController6);
        engine.rootContext()->setContextProperty("commonControl", &commonControl);
        engine.rootContext()->setContextProperty("maintenanceControl", &maintenanceControl);
        engine.rootContext()->setContextProperty("localControl", &localControl);
        engine.rootContext()->setContextProperty("networkTask", &networkTask);
        engine.rootContext()->setContextProperty("protectionMonitor", &protectionMonitor);
        engine.rootContext()->setContextProperty("alarmPlayback", &alarmPlayback);
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
