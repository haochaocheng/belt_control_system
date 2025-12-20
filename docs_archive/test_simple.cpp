#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QDebug>
#include <QDir>

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    
    qDebug() << "=== Application Starting ===";
    qDebug() << "Current directory:" << QDir::currentPath();
    
    QQmlApplicationEngine engine;
    
    qDebug() << "Import paths:";
    for (const QString &path : engine.importPathList()) {
        qDebug() << "  " << path;
    }
    
    const QUrl url(QStringLiteral("qrc:/qt/qml/BeltControlQml/main.qml"));
    qDebug() << "Loading from:" << url;
    
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
        &app, [url](QObject *obj, const QUrl &objUrl) {
            if (!obj && url == objUrl) {
                qCritical() << "!!! Failed to create object for" << objUrl;
                QCoreApplication::exit(-1);
            } else {
                qDebug() << "Successfully created object for" << objUrl;
            }
        }, Qt::QueuedConnection);
    
    engine.load(url);
    
    if (engine.rootObjects().isEmpty()) {
        qCritical() << "!!! No root objects created!";
        return -1;
    }
    
    qDebug() << "Root objects count:" << engine.rootObjects().count();
    qDebug() << "Starting event loop...";
    
    return app.exec();
}
