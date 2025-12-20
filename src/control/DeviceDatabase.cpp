#include "DeviceDatabase.h"
#include <QDebug>

DeviceDatabase::DeviceDatabase(QObject *parent)
    : QObject(parent)
    , m_settings(new QSettings("config.ini", QSettings::IniFormat, this))
{
    qDebug() << "✅ DeviceDatabase: 设备数据库已创建";
    loadFromConfig();
}

DeviceDatabase::~DeviceDatabase()
{
    qDebug() << "✅ DeviceDatabase: 设备数据库已销毁";
}

void DeviceDatabase::initializeDefaultDevices()
{
    m_devices.clear();

    // 初始化默认设备列表（与OutputDevicePanel保持一致）
    // 通道号从0-15，默认使用输出模块（寄存器10）
    QStringList defaultDevices = {
        "张紧", "抱闸", "洒水", "1号电机", "2号电机",
        "破碎机", "转载机", "前刮板", "后刮板",
        "1号乳化液泵", "2号乳化液泵", "3号乳化液泵", "4号乳化液泵",
        "1号喷雾泵", "2号喷雾泵", "3号喷雾泵", "4号喷雾泵"
    };

    for (int i = 0; i < defaultDevices.size() && i < 16; ++i) {
        DeviceInfo device;
        device.name = defaultDevices[i];
        device.channel = i;
        device.moduleType = "output";
        device.registerAddress = 10;
        device.relayType = "常开";
        device.isActive = true;
        m_devices.append(device);
    }

    qDebug() << "✅ DeviceDatabase: 初始化了" << m_devices.size() << "个默认设备";
    emit deviceCountChanged();
}

int DeviceDatabase::getRegisterForModuleType(const QString& moduleType) const
{
    if (moduleType == "output") return 10;      // 输出模块
    else if (moduleType == "main") return 5;    // 主模块
    else if (moduleType == "feedback") return 0; // 反馈模块
    return 10; // 默认输出模块
}

int DeviceDatabase::findDeviceIndex(const QString& name) const
{
    for (int i = 0; i < m_devices.size(); ++i) {
        if (m_devices[i].name == name) {
            return i;
        }
    }
    return -1;
}

// ========== 设备操作 ==========

void DeviceDatabase::addDevice(const QString& name, int channel, const QString& moduleType, int registerAddress)
{
    if (deviceExists(name)) {
        qWarning() << "❌ DeviceDatabase: 设备已存在:" << name;
        return;
    }

    if (channel < 0 || channel > 15) {
        qWarning() << "❌ DeviceDatabase: 通道号超出范围 (0-15):" << channel;
        return;
    }

    DeviceInfo device(name, channel, moduleType, registerAddress);
    m_devices.append(device);

    qDebug() << "✅ DeviceDatabase: 添加设备:" << name
             << "通道:" << channel
             << "模块:" << moduleType
             << "寄存器:" << registerAddress;

    emit deviceAdded(name);
    emit deviceCountChanged();
}

void DeviceDatabase::removeDevice(const QString& name)
{
    int index = findDeviceIndex(name);
    if (index == -1) {
        qWarning() << "❌ DeviceDatabase: 设备不存在:" << name;
        return;
    }

    m_devices.remove(index);
    qDebug() << "✅ DeviceDatabase: 删除设备:" << name;

    emit deviceRemoved(name);
    emit deviceCountChanged();
}

void DeviceDatabase::updateDevice(const QString& name, int channel, const QString& moduleType, int registerAddress)
{
    int index = findDeviceIndex(name);
    if (index == -1) {
        qWarning() << "❌ DeviceDatabase: 设备不存在:" << name;
        return;
    }

    m_devices[index].channel = channel;
    m_devices[index].moduleType = moduleType;
    m_devices[index].registerAddress = registerAddress;

    qDebug() << "✅ DeviceDatabase: 更新设备:" << name
             << "通道:" << channel
             << "模块:" << moduleType
             << "寄存器:" << registerAddress;

    emit deviceUpdated(name);
}

bool DeviceDatabase::deviceExists(const QString& name) const
{
    return findDeviceIndex(name) != -1;
}

// ========== 查询设备信息 ==========

int DeviceDatabase::getDeviceChannel(const QString& name) const
{
    int index = findDeviceIndex(name);
    return (index != -1) ? m_devices[index].channel : -1;
}

QString DeviceDatabase::getDeviceModuleType(const QString& name) const
{
    int index = findDeviceIndex(name);
    return (index != -1) ? m_devices[index].moduleType : QString();
}

int DeviceDatabase::getDeviceRegisterAddress(const QString& name) const
{
    int index = findDeviceIndex(name);
    return (index != -1) ? m_devices[index].registerAddress : -1;
}

QString DeviceDatabase::getDeviceRelayType(const QString& name) const
{
    int index = findDeviceIndex(name);
    return (index != -1) ? m_devices[index].relayType : QString("常开");
}

bool DeviceDatabase::isDeviceActive(const QString& name) const
{
    int index = findDeviceIndex(name);
    return (index != -1) ? m_devices[index].isActive : false;
}

// ========== 设置设备属性 ==========

void DeviceDatabase::setDeviceChannel(const QString& name, int channel)
{
    int index = findDeviceIndex(name);
    if (index != -1 && channel >= 0 && channel <= 15) {
        m_devices[index].channel = channel;
        emit deviceUpdated(name);
    }
}

void DeviceDatabase::setDeviceModuleType(const QString& name, const QString& moduleType)
{
    int index = findDeviceIndex(name);
    if (index != -1) {
        m_devices[index].moduleType = moduleType;
        m_devices[index].registerAddress = getRegisterForModuleType(moduleType);
        emit deviceUpdated(name);
    }
}

void DeviceDatabase::setDeviceRelayType(const QString& name, const QString& relayType)
{
    int index = findDeviceIndex(name);
    if (index != -1) {
        m_devices[index].relayType = relayType;
        emit deviceUpdated(name);
    }
}

void DeviceDatabase::setDeviceActive(const QString& name, bool active)
{
    int index = findDeviceIndex(name);
    if (index != -1) {
        m_devices[index].isActive = active;
        emit deviceUpdated(name);
    }
}

// ========== 获取设备列表 ==========

QStringList DeviceDatabase::getAllDeviceNames() const
{
    QStringList names;
    for (const auto& device : m_devices) {
        names.append(device.name);
    }
    return names;
}

const DeviceInfo* DeviceDatabase::getDeviceInfo(const QString& name) const
{
    int index = findDeviceIndex(name);
    return (index != -1) ? &m_devices[index] : nullptr;
}

// ========== 保存和加载 ==========

void DeviceDatabase::saveToConfig()
{
    m_settings->beginGroup("DeviceDatabase");
    m_settings->setValue("deviceCount", m_devices.size());

    for (int i = 0; i < m_devices.size(); ++i) {
        const DeviceInfo& device = m_devices[i];
        QString prefix = QString("device_%1_").arg(i);

        m_settings->setValue(prefix + "name", device.name);
        m_settings->setValue(prefix + "channel", device.channel);
        m_settings->setValue(prefix + "moduleType", device.moduleType);
        m_settings->setValue(prefix + "registerAddress", device.registerAddress);
        m_settings->setValue(prefix + "relayType", device.relayType);
        m_settings->setValue(prefix + "isActive", device.isActive);
    }

    m_settings->endGroup();
    m_settings->sync();

    qDebug() << "✅ DeviceDatabase: 已保存" << m_devices.size() << "个设备到配置文件";
}

void DeviceDatabase::loadFromConfig()
{
    m_settings->beginGroup("DeviceDatabase");
    int count = m_settings->value("deviceCount", 0).toInt();

    if (count == 0) {
        // 首次使用，初始化默认设备
        m_settings->endGroup();
        initializeDefaultDevices();
        saveToConfig(); // 保存默认配置
        return;
    }

    m_devices.clear();

    for (int i = 0; i < count; ++i) {
        QString prefix = QString("device_%1_").arg(i);

        DeviceInfo device;
        device.name = m_settings->value(prefix + "name", "未知设备").toString();
        device.channel = m_settings->value(prefix + "channel", 0).toInt();
        device.moduleType = m_settings->value(prefix + "moduleType", "output").toString();
        device.registerAddress = m_settings->value(prefix + "registerAddress", 10).toInt();
        device.relayType = m_settings->value(prefix + "relayType", "常开").toString();
        device.isActive = m_settings->value(prefix + "isActive", true).toBool();

        m_devices.append(device);
    }

    m_settings->endGroup();

    qDebug() << "✅ DeviceDatabase: 从配置文件加载了" << m_devices.size() << "个设备";
    emit deviceCountChanged();
}

void DeviceDatabase::resetToDefaults()
{
    initializeDefaultDevices();
    saveToConfig();
    qDebug() << "✅ DeviceDatabase: 已恢复默认设备配置";
}
