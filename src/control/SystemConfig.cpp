#include "SystemConfig.h"
#include "DataPathConfig.h"
#include <QDebug>
#include <QCoreApplication>

SystemConfig::SystemConfig(QObject *parent)
    : QObject(parent), m_machineNumber(DEFAULT_MACHINE_NUMBER), m_warningTimeSeconds(DEFAULT_WARNING_TIME), m_warningPlayCount(DEFAULT_WARNING_COUNT), m_warningMode(DEFAULT_WARNING_MODE), m_startupSequence(getDefaultStartupSequence()), m_stopSequence(getDefaultStopSequence()), m_startupDelays(getDefaultStartupDelays()), m_stopDelays(getDefaultStopDelays()), m_defaultDelay(DEFAULT_DELAY), m_modbusServerIp("192.168.10.243"), m_modbusGateway("192.168.10.1"), m_modbusSubnetMask("255.255.255.0"), m_modbusPollInterval(100), m_workMode(DEFAULT_WORK_MODE), m_localDeviceName("1号皮带")
{
    // 使用统一数据目录配置
    QString configPath = DataPathConfig::getConfigFilePath();
    m_settings = new QSettings(configPath, QSettings::IniFormat, this);

    qDebug() << "✅ SystemConfig: 配置管理器已创建";
    qDebug() << "   配置文件路径:" << configPath;

    // 自动加载配置
    loadConfig();
}

SystemConfig::~SystemConfig()
{
    qDebug() << "✅ SystemConfig: 配置管理器已销毁";
}

void SystemConfig::setMachineNumber(int number)
{
    if (m_machineNumber != number && number >= 1 && number <= 8)
    {
        m_machineNumber = number;
        emit machineNumberChanged();
        qDebug() << "📝 SystemConfig: 本机编号已设置为:" << number;
    }
}

void SystemConfig::setWarningTimeSeconds(int seconds)
{
    if (m_warningTimeSeconds != seconds && seconds > 0)
    {
        m_warningTimeSeconds = seconds;
        emit warningTimeSecondsChanged();
        qDebug() << "📝 SystemConfig: 起车预警时间已设置为:" << seconds << "秒";
    }
}

void SystemConfig::setWarningPlayCount(int count)
{
    if (m_warningPlayCount != count && count > 0)
    {
        m_warningPlayCount = count;
        emit warningPlayCountChanged();
        qDebug() << "📝 SystemConfig: 起车预警播放次数已设置为:" << count << "次";
    }
}

void SystemConfig::setWarningMode(WarningMode mode)
{
    if (m_warningMode != mode)
    {
        m_warningMode = mode;
        emit warningModeChanged();
        qDebug() << "📝 SystemConfig: 播放模式已设置为:" << (mode == ByTime ? "按时间" : "按次数");
    }
}

void SystemConfig::setStartupSequence(const QStringList &sequence)
{
    if (m_startupSequence != sequence)
    {
        // Validate maximum 10 devices
        if (sequence.size() > 10)
        {
            qWarning() << "❌ SystemConfig: 启动顺序最多支持10个设备，当前:" << sequence.size();
            return;
        }
        m_startupSequence = sequence;
        emit startupSequenceChanged();
        qDebug() << "📝 SystemConfig: 启动顺序已设置为:" << sequence.join(" -> ");
    }
}

void SystemConfig::setStopSequence(const QStringList &sequence)
{
    if (m_stopSequence != sequence)
    {
        // Validate maximum 10 devices
        if (sequence.size() > 10)
        {
            qWarning() << "❌ SystemConfig: 停止顺序最多支持10个设备，当前:" << sequence.size();
            return;
        }
        m_stopSequence = sequence;
        emit stopSequenceChanged();
        qDebug() << "📝 SystemConfig: 停止顺序已设置为:" << sequence.join(" -> ");
    }
}

// ✅ 2026-03-20 [Phase 7.48.57]: 逻辑控制延时 Setters
void SystemConfig::setStartupDelays(const QVariantList &delays)
{
    if (m_startupDelays != delays)
    {
        m_startupDelays = delays;
        emit startupDelaysChanged();
        qDebug() << "📝 SystemConfig: 启动延时已设置，共" << delays.size() << "项";
    }
}

void SystemConfig::setStopDelays(const QVariantList &delays)
{
    if (m_stopDelays != delays)
    {
        m_stopDelays = delays;
        emit stopDelaysChanged();
        qDebug() << "📝 SystemConfig: 停止延时已设置，共" << delays.size() << "项";
    }
}

void SystemConfig::setDefaultDelay(double delay)
{
    if (!qFuzzyCompare(m_defaultDelay, delay) && delay >= 0.5 && delay <= 30.0)
    {
        m_defaultDelay = delay;
        emit defaultDelayChanged();
        qDebug() << "📝 SystemConfig: 默认延时已设置为:" << delay << "秒";
    }
}

void SystemConfig::setModbusServerIp(const QString &ip)
{
    if (m_modbusServerIp != ip)
    {
        m_modbusServerIp = ip;
        emit modbusServerIpChanged();
        qDebug() << "📝 SystemConfig: Modbus服务器IP已设置为:" << ip;
    }
}

void SystemConfig::setModbusGateway(const QString &gateway)
{
    if (m_modbusGateway != gateway)
    {
        m_modbusGateway = gateway;
        emit modbusGatewayChanged();
        qDebug() << "📝 SystemConfig: 网关已设置为:" << gateway;
    }
}

void SystemConfig::setModbusSubnetMask(const QString &subnetMask)
{
    if (m_modbusSubnetMask != subnetMask)
    {
        m_modbusSubnetMask = subnetMask;
        emit modbusSubnetMaskChanged();
        qDebug() << "📝 SystemConfig: 子网掩码已设置为:" << subnetMask;
    }
}

void SystemConfig::setModbusPollInterval(int interval)
{
    if (m_modbusPollInterval != interval && interval >= 10)
    {
        m_modbusPollInterval = interval;
        emit modbusPollIntervalChanged();
        qDebug() << "📝 SystemConfig: Modbus轮询间隔已设置为:" << interval << "ms";
    }
}

void SystemConfig::setWorkMode(WorkMode mode)
{
    if (m_workMode != mode)
    {
        m_workMode = mode;
        emit workModeChanged();
        QString modeName;
        switch (mode)
        {
        case Maintenance:
            modeName = "检修";
            break;
        case Local:
            modeName = "就地";
            break;
        case Jog:
            modeName = "点动";
            break;
        case Centralized:
            modeName = "集控";
            break;
        }
        qDebug() << "📝 SystemConfig: 工作模式已设置为:" << modeName;
    }
}

void SystemConfig::setLocalDeviceName(const QString &name)
{
    if (m_localDeviceName != name)
    {
        m_localDeviceName = name;
        emit localDeviceNameChanged();
        qDebug() << "📝 SystemConfig: 本机名称已设置为:" << name;
    }
}

void SystemConfig::saveConfig()
{
    m_settings->beginGroup("SystemSettings");
    m_settings->setValue("machineNumber", m_machineNumber);
    m_settings->setValue("warningTimeSeconds", m_warningTimeSeconds);
    m_settings->setValue("warningPlayCount", m_warningPlayCount);
    m_settings->setValue("warningMode", static_cast<int>(m_warningMode));
    m_settings->setValue("workMode", static_cast<int>(m_workMode));
    m_settings->setValue("localDeviceName", m_localDeviceName);
    m_settings->setValue("startupSequence", m_startupSequence);
    m_settings->setValue("stopSequence", m_stopSequence);
    // ✅ 2026-03-20 [Phase 7.48.57]: 保存延时配置
    // QVariantList需要转为QStringList存储
    QStringList startupDelayStrs, stopDelayStrs;
    for (const QVariant &v : m_startupDelays) startupDelayStrs << QString::number(v.toDouble());
    for (const QVariant &v : m_stopDelays) stopDelayStrs << QString::number(v.toDouble());
    m_settings->setValue("startupDelays", startupDelayStrs);
    m_settings->setValue("stopDelays", stopDelayStrs);
    m_settings->setValue("defaultDelay", m_defaultDelay);
    m_settings->endGroup();

    m_settings->beginGroup("NetworkSettings");
    m_settings->setValue("modbusServerIp", m_modbusServerIp);
    m_settings->setValue("modbusGateway", m_modbusGateway);
    m_settings->setValue("modbusSubnetMask", m_modbusSubnetMask);
    m_settings->setValue("modbusPollInterval", m_modbusPollInterval);
    m_settings->endGroup();

    m_settings->sync();

    QString workModeName;
    switch (m_workMode)
    {
    case Maintenance:
        workModeName = "检修";
        break;
    case Local:
        workModeName = "就地";
        break;
    case Jog:
        workModeName = "点动";
        break;
    case Centralized:
        workModeName = "集控";
        break;
    }

    qDebug() << "💾 SystemConfig: 配置已保存";
    qDebug() << "   本机编号:" << m_machineNumber;
    qDebug() << "   工作模式:" << workModeName;
    qDebug() << "   起车预警时间:" << m_warningTimeSeconds << "秒";
    qDebug() << "   起车预警播放次数:" << m_warningPlayCount << "次";
    qDebug() << "   播放模式:" << (m_warningMode == ByTime ? "按时间" : "按次数");
    qDebug() << "   启动顺序:" << m_startupSequence.join(" -> ");
    qDebug() << "   停止顺序:" << m_stopSequence.join(" -> ");
    qDebug() << "   Modbus服务器IP:" << m_modbusServerIp;
    qDebug() << "   网关:" << m_modbusGateway;
    qDebug() << "   子网掩码:" << m_modbusSubnetMask;
    qDebug() << "   轮询间隔:" << m_modbusPollInterval << "ms";

    emit configSaved();
}

void SystemConfig::loadConfig()
{
    m_settings->beginGroup("SystemSettings");

    m_machineNumber = m_settings->value("machineNumber", DEFAULT_MACHINE_NUMBER).toInt();
    m_warningTimeSeconds = m_settings->value("warningTimeSeconds", DEFAULT_WARNING_TIME).toInt();
    m_warningPlayCount = m_settings->value("warningPlayCount", DEFAULT_WARNING_COUNT).toInt();
    m_warningMode = static_cast<WarningMode>(m_settings->value("warningMode", static_cast<int>(DEFAULT_WARNING_MODE)).toInt());
    m_workMode = static_cast<WorkMode>(m_settings->value("workMode", static_cast<int>(DEFAULT_WORK_MODE)).toInt());
    m_localDeviceName = m_settings->value("localDeviceName", "1号皮带").toString();
    m_startupSequence = m_settings->value("startupSequence", getDefaultStartupSequence()).toStringList();
    m_stopSequence = m_settings->value("stopSequence", getDefaultStopSequence()).toStringList();

    // ✅ 2026-03-20 [Phase 7.48.57]: 加载延时配置
    QStringList startupDelayStrs = m_settings->value("startupDelays").toStringList();
    QStringList stopDelayStrs = m_settings->value("stopDelays").toStringList();
    m_defaultDelay = m_settings->value("defaultDelay", DEFAULT_DELAY).toDouble();

    m_startupDelays.clear();
    if (startupDelayStrs.isEmpty()) {
        m_startupDelays = getDefaultStartupDelays();
    } else {
        for (const QString &s : startupDelayStrs) m_startupDelays << s.toDouble();
    }
    // 确保延时列表与序列长度一致
    while (m_startupDelays.size() < m_startupSequence.size()) m_startupDelays << m_defaultDelay;
    while (m_startupDelays.size() > m_startupSequence.size()) m_startupDelays.removeLast();

    m_stopDelays.clear();
    if (stopDelayStrs.isEmpty()) {
        m_stopDelays = getDefaultStopDelays();
    } else {
        for (const QString &s : stopDelayStrs) m_stopDelays << s.toDouble();
    }
    while (m_stopDelays.size() < m_stopSequence.size()) m_stopDelays << m_defaultDelay;
    while (m_stopDelays.size() > m_stopSequence.size()) m_stopDelays.removeLast();

    m_settings->endGroup();

    m_settings->beginGroup("NetworkSettings");
    m_modbusServerIp = m_settings->value("modbusServerIp", "192.168.10.243").toString();
    m_modbusGateway = m_settings->value("modbusGateway", "192.168.1.10").toString();
    m_modbusSubnetMask = m_settings->value("modbusSubnetMask", "255.255.255.0").toString();
    m_modbusPollInterval = m_settings->value("modbusPollInterval", 100).toInt();
    m_settings->endGroup();

    QString workModeName;
    switch (m_workMode)
    {
    case Maintenance:
        workModeName = "检修";
        break;
    case Local:
        workModeName = "就地";
        break;
    case Jog:
        workModeName = "点动";
        break;
    case Centralized:
        workModeName = "集控";
        break;
    }

    qDebug() << "📂 SystemConfig: 配置已加载";
    qDebug() << "   本机编号:" << m_machineNumber;
    qDebug() << "   工作模式:" << workModeName;
    qDebug() << "   起车预警时间:" << m_warningTimeSeconds << "秒";
    qDebug() << "   起车预警播放次数:" << m_warningPlayCount << "次";
    qDebug() << "   播放模式:" << (m_warningMode == ByTime ? "按时间" : "按次数");
    qDebug() << "   启动顺序:" << m_startupSequence.join(" -> ");
    qDebug() << "   停止顺序:" << m_stopSequence.join(" -> ");
    qDebug() << "   Modbus服务器IP:" << m_modbusServerIp;
    qDebug() << "   网关:" << m_modbusGateway;
    qDebug() << "   子网掩码:" << m_modbusSubnetMask;
    qDebug() << "   轮询间隔:" << m_modbusPollInterval << "ms";

    emit machineNumberChanged();
    emit warningTimeSecondsChanged();
    emit warningPlayCountChanged();
    emit warningModeChanged();
    emit workModeChanged();
    emit startupSequenceChanged();
    emit stopSequenceChanged();
    emit modbusServerIpChanged();
    emit modbusGatewayChanged();
    emit modbusSubnetMaskChanged();
    emit modbusPollIntervalChanged();
    emit configLoaded();
}

void SystemConfig::resetToDefaults()
{
    setMachineNumber(DEFAULT_MACHINE_NUMBER);
    setWarningTimeSeconds(DEFAULT_WARNING_TIME);
    setWarningPlayCount(DEFAULT_WARNING_COUNT);
    setWarningMode(DEFAULT_WARNING_MODE);
    setWorkMode(DEFAULT_WORK_MODE);
    setLocalDeviceName("1号皮带");
    setStartupSequence(getDefaultStartupSequence());
    setStopSequence(getDefaultStopSequence());
    // ✅ 2026-03-20 [Phase 7.48.57]: 重置延时
    setStartupDelays(getDefaultStartupDelays());
    setStopDelays(getDefaultStopDelays());
    setDefaultDelay(DEFAULT_DELAY);
    setModbusServerIp("192.168.10.243");
    setModbusGateway("192.168.10.1");
    setModbusSubnetMask("255.255.255.0");
    setModbusPollInterval(100);

    saveConfig();

    qDebug() << "🔄 SystemConfig: 配置已重置为默认值";
}

QStringList SystemConfig::getDefaultStartupSequence()
{
    return {"张紧", "抱闸", "1号电机", "2号电机"};
}

QStringList SystemConfig::getDefaultStopSequence()
{
    return {"2号电机", "1号电机", "抱闸", "张紧"};
}

// ✅ 2026-03-20 [Phase 7.48.57]: 默认延时列表（每个设备1秒）
QVariantList SystemConfig::getDefaultStartupDelays()
{
    return {1.0, 1.0, 1.0, 1.0};
}

QVariantList SystemConfig::getDefaultStopDelays()
{
    return {1.0, 1.0, 1.0, 1.0};
}
