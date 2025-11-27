#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDebug>
#include <QDir>
#include <iostream>
#include <QtPlugin>
#include "hardware/hal/hardware_hal.h"
#include "hardware/simulated/simulated_hal.h"
#include "hardware/real/real_hal.h"
#include "control/belt_controller.h"
#include "utils/logger.h"
#include "sip_phone/SipPhoneManager.h"

Q_IMPORT_PLUGIN(BeltControlQmlPlugin)

int main(int argc, char *argv[]) {
    // 强制输出到控制台
    freopen("CON", "w", stdout);
    freopen("CON", "w", stderr);

    std::cout << "=== Application starting ===" << std::endl;

    // Enable Qt Virtual Keyboard
    qputenv("QT_IM_MODULE", QByteArray("qtvirtualkeyboard"));

    QGuiApplication app(argc, argv);

    std::cout << "QGuiApplication created" << std::endl;
    qDebug() << "Application starting...";

    QQmlApplicationEngine engine;

    // 初始化日志工具
    Logger::init("belt_control_log.txt");
    qDebug() << "Logger initialized";

    // 注册 SIP Phone Manager 到 QML
    SipPhoneManager::registerToQml();
    qDebug() << "SipPhoneManager registered to QML";

    // 根据平台选择硬件抽象层（Windows用模拟，Linux用真实）
#ifdef Q_OS_WIN
    HardwareHAL* hal = new SimulatedHAL();
    qDebug() << "Using SimulatedHAL";
#else
    HardwareHAL* hal = new RealHAL();
    qDebug() << "Using RealHAL";
#endif

    // 初始化控制逻辑（依赖硬件抽象层）
    BeltController controller(hal);
    qDebug() << "BeltController initialized";

    // 将C++对象注册到QML（QML中可直接访问其属性和信号）
    engine.rootContext()->setContextProperty("controller", &controller);
    engine.rootContext()->setContextProperty("logger", Logger::instance());
    qDebug() << "Context properties set";

    // 添加QML导入路径
    engine.addImportPath("qrc:/qt/qml");

    // 加载QML主界面
    const QUrl url(QStringLiteral("qrc:/qt/qml/BeltControlQml/main.qml"));
    qDebug() << "Loading QML from:" << url;
    qDebug() << "Import paths:" << engine.importPathList();

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
        &app, [url](QObject *obj, const QUrl &objUrl) {
            qDebug() << "Object created:" << obj << "for URL:" << objUrl;
            if (!obj && url == objUrl) {
                qCritical() << "Failed to load QML file!";
                QCoreApplication::exit(-1);
            }
        }, Qt::QueuedConnection);

    engine.load(url);

    if (engine.rootObjects().isEmpty()) {
        qCritical() << "No root objects loaded!";
        qCritical() << "Available import paths:";
        for (const QString &path : engine.importPathList()) {
            qCritical() << "  " << path;
        }
        return -1;
    }

    qDebug() << "QML loaded successfully, starting event loop";
    return app.exec();
}