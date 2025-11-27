#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QDebug>
#include <iostream>

int main(int argc, char *argv[]) {
    std::cout << "=== Starting test ===" << std::endl;
    
    QGuiApplication app(argc, argv);
    std::cout << "QGuiApplication created" << std::endl;
    
    QQmlApplicationEngine engine;
    std::cout << "QQmlApplicationEngine created" << std::endl;
    
    // 创建一个最简单的QML
    const char* qmlCode = R"(
        import QtQuick
        import QtQuick.Window
        
        Window {
            visible: true
            width: 400
            height: 300
            title: "Test Window"
            
            Rectangle {
                anchors.fill: parent
                color: "lightblue"
                
                Text {
                    anchors.centerIn: parent
                    text: "Hello World!"
                    font.pixelSize: 32
                }
            }
        }
    )";
    
    engine.loadData(qmlCode);
    std::cout << "QML loaded" << std::endl;
    
    if (engine.rootObjects().isEmpty()) {
        std::cerr << "ERROR: No root objects!" << std::endl;
        return -1;
    }
    
    std::cout << "Starting event loop..." << std::endl;
    return app.exec();
}
