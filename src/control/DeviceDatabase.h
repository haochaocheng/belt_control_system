#ifndef DEVICEDATABASE_H
#define DEVICEDATABASE_H

#include <QObject>
#include <QString>
#include <QVector>
#include <QSettings>
#include <QVariant>

/**
 * @brief 设备信息结构体
 *
 * 存储单个输出设备的所有参数
 */
struct DeviceInfo {
    QString name;           // 设备名称
    int channel;            // 通道号 (0-15)
    QString moduleType;     // 模块类型: "output"(输出模块), "main"(主模块), "feedback"(反馈模块)
    int registerAddress;    // 寄存器地址: 10(输出), 5(主模块), 0(反馈)
    QString relayType;      // 继电器类型: "常开" 或 "常闭"
    bool isActive;          // 设备是否启用

    DeviceInfo()
        : channel(0)
        , moduleType("output")
        , registerAddress(10)
        , relayType("常开")
        , isActive(true)
    {}

    DeviceInfo(const QString& deviceName, int ch, const QString& modType, int regAddr)
        : name(deviceName)
        , channel(ch)
        , moduleType(modType)
        , registerAddress(regAddr)
        , relayType("常开")
        , isActive(true)
    {}
};

/**
 * @brief 设备数据库类
 *
 * 管理所有输出设备的参数，支持保存到配置文件和从配置文件加载
 */
class DeviceDatabase : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int deviceCount READ deviceCount NOTIFY deviceCountChanged)

public:
    explicit DeviceDatabase(QObject *parent = nullptr);
    ~DeviceDatabase();

    // 设备操作
    Q_INVOKABLE void addDevice(const QString& name, int channel, const QString& moduleType, int registerAddress);
    Q_INVOKABLE void removeDevice(const QString& name);
    Q_INVOKABLE void updateDevice(const QString& name, int channel, const QString& moduleType, int registerAddress);
    Q_INVOKABLE bool deviceExists(const QString& name) const;

    // 查询设备信息
    Q_INVOKABLE int getDeviceChannel(const QString& name) const;
    Q_INVOKABLE QString getDeviceModuleType(const QString& name) const;
    Q_INVOKABLE int getDeviceRegisterAddress(const QString& name) const;
    Q_INVOKABLE QString getDeviceRelayType(const QString& name) const;
    Q_INVOKABLE bool isDeviceActive(const QString& name) const;

    // 设置设备属性
    Q_INVOKABLE void setDeviceChannel(const QString& name, int channel);
    Q_INVOKABLE void setDeviceModuleType(const QString& name, const QString& moduleType);
    Q_INVOKABLE void setDeviceRelayType(const QString& name, const QString& relayType);
    Q_INVOKABLE void setDeviceActive(const QString& name, bool active);

    // 获取设备列表
    Q_INVOKABLE QStringList getAllDeviceNames() const;
    int deviceCount() const { return m_devices.size(); }

    // 保存和加载
    Q_INVOKABLE void saveToConfig();
    Q_INVOKABLE void loadFromConfig();
    Q_INVOKABLE void resetToDefaults();

    // 获取设备信息（供C++使用）
    const DeviceInfo* getDeviceInfo(const QString& name) const;
    const QVector<DeviceInfo>& getAllDevices() const { return m_devices; }

signals:
    void deviceCountChanged();
    void deviceAdded(const QString& name);
    void deviceRemoved(const QString& name);
    void deviceUpdated(const QString& name);

private:
    QVector<DeviceInfo> m_devices;
    QSettings* m_settings;

    // 初始化默认设备列表
    void initializeDefaultDevices();

    // 辅助函数：根据模块类型获取寄存器地址
    int getRegisterForModuleType(const QString& moduleType) const;

    // 查找设备索引
    int findDeviceIndex(const QString& name) const;
};

#endif // DEVICEDATABASE_H
