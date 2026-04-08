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

// ✅ 2026-03-20 [Phase 7.48.60]: 皮带音频来源 Setter
void SystemConfig::setBeltAudioSource(int source)
{
    if (m_beltAudioSource != source && (source == 0 || source == 1))
    {
        m_beltAudioSource = source;
        emit beltAudioSourceChanged();
        qDebug() << "📝 SystemConfig: 皮带音频来源已设置为:" << (source == 0 ? "默认(/app/AUDIO/)" : "TTS合成");
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
    // ✅ 2026-03-20 [Phase 7.48.60]: 保存皮带音频来源
    m_settings->setValue("beltAudioSource", m_beltAudioSource);
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
    // ✅ 2026-03-20 [Phase 7.48.60]: 加载皮带音频来源
    m_beltAudioSource = m_settings->value("beltAudioSource", 0).toInt();
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
    // ✅ 2026-03-20 [Phase 7.48.60]: 通知皮带音频来源
    emit beltAudioSourceChanged();
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

// ✅ 2026-04-08 [Phase 7.48.88.97]: 模拟量保护值 Setters（完整版）
// 旧：Phase 7.48.88.96 仅有速度/张力 + 18个电机独立setter
// 新：18个环境setter + 8电机×14Tab数组 + 16个兼容setter
// 原因：MqttProtectionMonitor计算出工程量后需要写入SystemConfig，
//       TCPDataAdapter读取这些值同步到Modbus从站/S7从站映射表
// 注意：qFuzzyCompare(0.0, 0.0)返回false，加1.0修正零值比较

// ========== 环境模拟量 Setters ==========
void SystemConfig::setSpeedValue(double value) {
    if (qFuzzyCompare(1.0 + m_speedValue, 1.0 + value)) return;
    m_speedValue = value;
    emit speedValueChanged();
}

void SystemConfig::setTensionValue(double value) {
    if (qFuzzyCompare(1.0 + m_tensionValue, 1.0 + value)) return;
    m_tensionValue = value;
    emit tensionValueChanged();
}

void SystemConfig::setTemperature1Value(double value) {
    if (qFuzzyCompare(1.0 + m_temperature1Value, 1.0 + value)) return;
    m_temperature1Value = value;
    emit temperature1ValueChanged();
}

void SystemConfig::setTemperature2Value(double value) {
    if (qFuzzyCompare(1.0 + m_temperature2Value, 1.0 + value)) return;
    m_temperature2Value = value;
    emit temperature2ValueChanged();
}

void SystemConfig::setTemperatureValue(double value) {
    if (qFuzzyCompare(1.0 + m_temperatureValue_env, 1.0 + value)) return;
    m_temperatureValue_env = value;
    emit temperatureValueChanged();
}

void SystemConfig::setHumidityValue(double value) {
    if (qFuzzyCompare(1.0 + m_humidityValue, 1.0 + value)) return;
    m_humidityValue = value;
    emit humidityValueChanged();
}

void SystemConfig::setMethaneValue(double value) {
    if (qFuzzyCompare(1.0 + m_methaneValue, 1.0 + value)) return;
    m_methaneValue = value;
    emit methaneValueChanged();
}

void SystemConfig::setDustValue(double value) {
    if (qFuzzyCompare(1.0 + m_dustValue, 1.0 + value)) return;
    m_dustValue = value;
    emit dustValueChanged();
}

void SystemConfig::setCoalFlowValue(double value) {
    if (qFuzzyCompare(1.0 + m_coalFlowValue, 1.0 + value)) return;
    m_coalFlowValue = value;
    emit coalFlowValueChanged();
}

void SystemConfig::setSiloHeightValue(double value) {
    if (qFuzzyCompare(1.0 + m_siloHeightValue, 1.0 + value)) return;
    m_siloHeightValue = value;
    emit siloHeightValueChanged();
}

void SystemConfig::setVoltageValue(double value) {
    if (qFuzzyCompare(1.0 + m_voltageValue, 1.0 + value)) return;
    m_voltageValue = value;
    emit voltageValueChanged();
}

void SystemConfig::setSmokeValue(double value) {
    if (qFuzzyCompare(1.0 + m_smokeValue_env, 1.0 + value)) return;
    m_smokeValue_env = value;
    emit smokeValueChanged();
}

void SystemConfig::setPressureValue(double value) {
    if (qFuzzyCompare(1.0 + m_pressureValue, 1.0 + value)) return;
    m_pressureValue = value;
    emit pressureValueChanged();
}

void SystemConfig::setOxygenValue(double value) {
    if (qFuzzyCompare(1.0 + m_oxygenValue, 1.0 + value)) return;
    m_oxygenValue = value;
    emit oxygenValueChanged();
}

void SystemConfig::setCoValue(double value) {
    if (qFuzzyCompare(1.0 + m_coValue, 1.0 + value)) return;
    m_coValue = value;
    emit coValueChanged();
}

void SystemConfig::setH2sValue(double value) {
    if (qFuzzyCompare(1.0 + m_h2sValue, 1.0 + value)) return;
    m_h2sValue = value;
    emit h2sValueChanged();
}

void SystemConfig::setCo2Value(double value) {
    if (qFuzzyCompare(1.0 + m_co2Value, 1.0 + value)) return;
    m_co2Value = value;
    emit co2ValueChanged();
}

void SystemConfig::setWindSpeedValue(double value) {
    if (qFuzzyCompare(1.0 + m_windSpeedValue, 1.0 + value)) return;
    m_windSpeedValue = value;
    emit windSpeedValueChanged();
}

// ========== 通用电机保护值访问（8电机×14Tab）==========
double SystemConfig::motorProtectionValue(int motorIndex, int tabIndex) const
{
    if (motorIndex < 0 || motorIndex >= MOTOR_COUNT || tabIndex < 0 || tabIndex >= MOTOR_TAB_COUNT)
        return 0.0;
    return m_motorValues[motorIndex][tabIndex];
}

void SystemConfig::setMotorProtectionValue(int motorIndex, int tabIndex, double value)
{
    if (motorIndex < 0 || motorIndex >= MOTOR_COUNT || tabIndex < 0 || tabIndex >= MOTOR_TAB_COUNT)
        return;
    if (qFuzzyCompare(1.0 + m_motorValues[motorIndex][tabIndex], 1.0 + value))
        return;
    m_motorValues[motorIndex][tabIndex] = value;
    emit motorProtectionValueChanged(motorIndex, tabIndex, value);
    // 为motor1/2的旧Q_PROPERTY属性emit兼容信号
    emitMotorCompatSignal(motorIndex, tabIndex);
}

// ========== 电机保护值兼容信号发射 ==========
// 当m_motorValues[0或1][tabIndex]变化时，同时emit旧的motor1/2专用信号
// 这样绑定motor1CurrentValueChanged等旧信号的QML/C++代码无需修改
void SystemConfig::emitMotorCompatSignal(int motorIndex, int tabIndex)
{
    if (motorIndex == 0) {
        switch (tabIndex) {
        case TAB_CURRENT:     emit motor1CurrentValueChanged(); break;
        case TAB_WINDING_A:   emit motor1PhaseAWindingValueChanged(); break;
        case TAB_WINDING_B:   emit motor1PhaseBWindingValueChanged(); break;
        case TAB_WINDING_C:   emit motor1PhaseCWindingValueChanged(); break;
        case TAB_MOTOR_TEMP:  emit motor1TemperatureValueChanged(); break;
        case TAB_X_VIBRATION: emit motor1XVibrationValueChanged(); break;
        case TAB_Y_VIBRATION: emit motor1YVibrationValueChanged(); break;
        default: break;
        }
    } else if (motorIndex == 1) {
        switch (tabIndex) {
        case TAB_CURRENT:     emit motor2CurrentValueChanged(); break;
        case TAB_WINDING_A:   emit motor2PhaseAWindingValueChanged(); break;
        case TAB_WINDING_B:   emit motor2PhaseBWindingValueChanged(); break;
        case TAB_WINDING_C:   emit motor2PhaseCWindingValueChanged(); break;
        case TAB_MOTOR_TEMP:  emit motor2TemperatureValueChanged(); break;
        case TAB_X_VIBRATION: emit motor2XVibrationValueChanged(); break;
        case TAB_Y_VIBRATION: emit motor2YVibrationValueChanged(); break;
        default: break;
        }
    }
    // motorIndex >= 2 的电机没有旧Q_PROPERTY，不需要兼容信号
}

// ========== 电机保护值兼容 Setters（motor1/2 旧属性，委托到数组）==========
// 旧：void SystemConfig::setMotor1CurrentValue(double value) { m_motor1CurrentValue = value; }
// 新：委托到 setMotorProtectionValue(motorIndex, tabIndex, value)
void SystemConfig::setMotor1CurrentValue(double value)     { setMotorProtectionValue(0, TAB_CURRENT, value); }
void SystemConfig::setMotor2CurrentValue(double value)     { setMotorProtectionValue(1, TAB_CURRENT, value); }
void SystemConfig::setMotor1XVibrationValue(double value)  { setMotorProtectionValue(0, TAB_X_VIBRATION, value); }
void SystemConfig::setMotor1YVibrationValue(double value)  { setMotorProtectionValue(0, TAB_Y_VIBRATION, value); }
void SystemConfig::setMotor2XVibrationValue(double value)  { setMotorProtectionValue(1, TAB_X_VIBRATION, value); }
void SystemConfig::setMotor2YVibrationValue(double value)  { setMotorProtectionValue(1, TAB_Y_VIBRATION, value); }
void SystemConfig::setMotor1TemperatureValue(double value) { setMotorProtectionValue(0, TAB_MOTOR_TEMP, value); }
void SystemConfig::setMotor2TemperatureValue(double value) { setMotorProtectionValue(1, TAB_MOTOR_TEMP, value); }
void SystemConfig::setMotor1PhaseAWindingValue(double value) { setMotorProtectionValue(0, TAB_WINDING_A, value); }
void SystemConfig::setMotor1PhaseBWindingValue(double value) { setMotorProtectionValue(0, TAB_WINDING_B, value); }
void SystemConfig::setMotor1PhaseCWindingValue(double value) { setMotorProtectionValue(0, TAB_WINDING_C, value); }
void SystemConfig::setMotor2PhaseAWindingValue(double value) { setMotorProtectionValue(1, TAB_WINDING_A, value); }
void SystemConfig::setMotor2PhaseBWindingValue(double value) { setMotorProtectionValue(1, TAB_WINDING_B, value); }
void SystemConfig::setMotor2PhaseCWindingValue(double value) { setMotorProtectionValue(1, TAB_WINDING_C, value); }

// 电压保留独立变量（来自模拟量保护表，不属于电机Tab）
void SystemConfig::setMotor1VoltageValue(double value) {
    if (qFuzzyCompare(1.0 + m_motor1VoltageValue, 1.0 + value)) return;
    m_motor1VoltageValue = value;
    emit motor1VoltageValueChanged();
}

void SystemConfig::setMotor2VoltageValue(double value) {
    if (qFuzzyCompare(1.0 + m_motor2VoltageValue, 1.0 + value)) return;
    m_motor2VoltageValue = value;
    emit motor2VoltageValueChanged();
}
