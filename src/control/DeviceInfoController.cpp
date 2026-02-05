// ✅ 2026-01-24 [设备信息界面重构] 设备信息控制器实现

#include "DeviceInfoController.h"
#include <QDebug>

DeviceInfoController::DeviceInfoController(QObject *parent)
    : QObject(parent)
{
    qDebug() << "[DeviceInfoController] 初始化设备信息控制器";
    initializeDevices();
}

DeviceInfoController::~DeviceInfoController()
{
    qDebug() << "[DeviceInfoController] 析构";
}

QVariantList DeviceInfoController::deviceList() const
{
    return m_deviceList;
}

void DeviceInfoController::openDeviceSettings(int deviceId)
{
    qDebug() << "[DeviceInfoController] 打开设备设置 - ID:" << deviceId;
    // TODO: 触发参数设置弹窗
}

void DeviceInfoController::updateDeviceStatus(int deviceId, const QString& status)
{
    qDebug() << "[DeviceInfoController] 更新设备状态 - ID:" << deviceId << "状态:" << status;

    // 查找并更新设备状态
    for (int i = 0; i < m_deviceList.size(); ++i) {
        QVariantMap device = m_deviceList[i].toMap();
        if (device["id"].toInt() == deviceId) {
            device["status"] = status;
            device["isRunning"] = (status == "运行中");
            m_deviceList[i] = device;
            emit deviceListChanged();
            emit deviceStatusChanged(deviceId, status);
            break;
        }
    }
}

void DeviceInfoController::updateDeviceName(int deviceId, const QString& name)
{
    qDebug() << "[DeviceInfoController] 更新设备名称 - ID:" << deviceId << "名称:" << name;

    // 查找并更新设备名称
    for (int i = 0; i < m_deviceList.size(); ++i) {
        QVariantMap device = m_deviceList[i].toMap();
        if (device["id"].toInt() == deviceId) {
            device["name"] = name;
            m_deviceList[i] = device;
            emit deviceListChanged();
            break;
        }
    }
}

void DeviceInfoController::initializeDevices()
{
    qDebug() << "[DeviceInfoController] 初始化12个设备";

    // 默认设备名称
    QStringList defaultNames = {
        "1号皮带", "2号皮带", "3号皮带", "4号皮带",
        "5号皮带", "6号皮带", "7号皮带", "8号皮带",
        "破碎机", "转载机", "前刮板机", "后刮板机"
    };

    m_deviceList.clear();
    for (int i = 0; i < 12; ++i) {
        m_deviceList.append(createDevice(i + 1, defaultNames[i]));
    }

    emit deviceListChanged();
}

QVariantMap DeviceInfoController::createDevice(int id, const QString& name, const QString& status)
{
    QVariantMap device;
    device["id"] = id;
    device["name"] = name;
    device["status"] = status;
    device["isRunning"] = false;
    device["speed"] = 0.0;
    device["imagePath"] = "";  // 用户后续提供图片

    return device;
}
