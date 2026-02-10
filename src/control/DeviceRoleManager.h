// DeviceRoleManager.h
// 设备角色管理器 - 管理主站/分站角色和权限控制
// 创建日期: 2026-02-10
// Phase 7.45.1

#ifndef DEVICEROLEMANAGER_H
#define DEVICEROLEMANAGER_H

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QDateTime>
#include <QMap>

// 设备类型枚举
enum class DeviceType {
    Belt,           // 皮带（1-8号）
    Loader,         // 转载机
    Crusher,        // 破碎机
    FrontScraper,   // 前刮板
    RearScraper     // 后刮板
};

// 设备信息结构
struct DeviceInfo {
    int deviceId;           // 设备ID（1-12）
    QString deviceName;     // 设备名称
    DeviceType deviceType;  // 设备类型
    bool isLocal;           // 是否为本机
    bool isOnline;          // 是否在线
    QString status;         // 状态文本（运行中/停止/故障）
    QDateTime lastUpdate;   // 最后更新时间

    // 转换为 QVariantMap（用于 QML）
    QVariantMap toVariantMap() const;
};

// 集控设备信息结构
struct StationInfo {
    int stationId;          // 集控ID
    QString stationRole;    // "master" 或 "sub"
    QString stationName;    // "主站" 或 "分站1"
    QString controlDevice;  // 控制的设备名称
    int controlDeviceId;    // 控制的设备ID
    QString ip;             // IP地址
    bool isOnline;          // 是否在线
    QString status;         // 运行状态
    QDateTime lastUpdate;   // 最后更新时间

    // 转换为 QVariantMap（用于 QML）
    QVariantMap toVariantMap() const;
};

class DeviceRoleManager : public QObject
{
    Q_OBJECT

    // QML 属性
    Q_PROPERTY(int localDeviceId READ localDeviceId WRITE setLocalDeviceId NOTIFY localDeviceIdChanged)
    Q_PROPERTY(QString localDeviceName READ localDeviceName NOTIFY localDeviceNameChanged)
    Q_PROPERTY(QString stationRole READ stationRole WRITE setStationRole NOTIFY stationRoleChanged)
    Q_PROPERTY(QString stationName READ stationName NOTIFY stationNameChanged)
    Q_PROPERTY(int stationId READ stationId NOTIFY stationIdChanged)
    Q_PROPERTY(QVariantList allDevices READ allDevices NOTIFY allDevicesChanged)
    Q_PROPERTY(QVariantList allStations READ allStations NOTIFY allStationsChanged)

public:
    explicit DeviceRoleManager(QObject *parent = nullptr);
    ~DeviceRoleManager();

    // 属性访问器
    int localDeviceId() const { return m_localDeviceId; }
    QString localDeviceName() const;
    QString stationRole() const { return m_stationRole; }
    QString stationName() const;
    int stationId() const { return m_stationId; }
    QVariantList allDevices() const;
    QVariantList allStations() const;

    // 属性设置器
    void setLocalDeviceId(int deviceId);
    void setStationRole(const QString &role);

    // QML 可调用方法
    Q_INVOKABLE bool isLocalDevice(int deviceId) const;
    Q_INVOKABLE bool hasPermission(int deviceId) const;
    Q_INVOKABLE void updateDeviceStatus(int deviceId, bool isOnline, const QString &status);
    Q_INVOKABLE void updateStationStatus(int stationId, bool isOnline, const QString &status);

    // 配置文件操作
    void saveToConfig();
    void loadFromConfig();

signals:
    void localDeviceIdChanged();
    void localDeviceNameChanged();
    void stationRoleChanged();
    void stationNameChanged();
    void stationIdChanged();
    void allDevicesChanged();
    void allStationsChanged();
    void deviceRoleChanged(int deviceId, bool isLocal);
    void deviceStatusChanged(int deviceId, bool isOnline, const QString &status);
    void stationStatusChanged(int stationId, bool isOnline, const QString &status);

private:
    // 初始化设备列表
    void initializeDevices();

    // 初始化集控设备列表
    void initializeStations();

    // 更新设备的本机状态
    void updateDeviceLocalStatus();

    // 获取设备名称
    QString getDeviceName(int deviceId) const;

    // 获取设备类型
    DeviceType getDeviceType(int deviceId) const;

private:
    int m_localDeviceId;                    // 本机设备ID（1-8）
    QString m_stationRole;                  // 本机角色（"master" 或 "sub"）
    int m_stationId;                        // 本机集控ID
    QMap<int, DeviceInfo> m_devices;        // 所有设备信息（12个设备）
    QMap<int, StationInfo> m_stations;      // 所有集控设备信息
    QString m_configFilePath;               // 配置文件路径
};

#endif // DEVICEROLEMANAGER_H
