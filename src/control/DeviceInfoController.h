// ✅ 2026-01-24 [设备信息界面重构] 设备信息控制器
// 管理设备数据，提供QML接口

#ifndef DEVICEINFOCONTROLLER_H
#define DEVICEINFOCONTROLLER_H

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QString>

class DeviceInfoController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList deviceList READ deviceList NOTIFY deviceListChanged)

public:
    explicit DeviceInfoController(QObject *parent = nullptr);
    ~DeviceInfoController();

    // 获取设备列表
    QVariantList deviceList() const;

    // QML可调用方法
    Q_INVOKABLE void openDeviceSettings(int deviceId);
    Q_INVOKABLE void updateDeviceStatus(int deviceId, const QString& status);
    Q_INVOKABLE void updateDeviceName(int deviceId, const QString& name);

signals:
    void deviceListChanged();
    void deviceStatusChanged(int deviceId, const QString& status);

private:
    void initializeDevices();
    QVariantMap createDevice(int id, const QString& name, const QString& status = "停止");

    QVariantList m_deviceList;
};

#endif // DEVICEINFOCONTROLLER_H
