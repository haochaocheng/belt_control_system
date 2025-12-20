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

        // 将C++对象注册到QML（QML中可直接访问其属性和信号）
        logMessage("Setting context properties...");
        engine.rootContext()->setContextProperty("controller", &controller);
        engine.rootContext()->setContextProperty("logger", Logger::instance());
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
