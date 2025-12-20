#include "ProtectionMonitorService.h"
#include "ProtectionConfigManager.h"
#include <QDebug>

// Forward declaration - NetworkTask feature temporarily disabled
class NetworkTask;

ProtectionMonitorService::ProtectionMonitorService(QObject *parent)
    : QObject(parent)
    , m_configManager(nullptr)
    , m_networkTask(nullptr)
    , m_isRunning(false)
{
    qDebug() << "✅ ProtectionMonitorService: 保护监控服务已创建";
}

ProtectionMonitorService::~ProtectionMonitorService()
{
    stop();

    // 清理延时定时器
    for (auto timer : m_delayTimers.values()) {
        timer->stop();
        delete timer;
    }
    m_delayTimers.clear();

    qDebug() << "✅ ProtectionMonitorService: 保护监控服务已销毁";
}

void ProtectionMonitorService::setProtectionConfigManager(ProtectionConfigManager *manager)
{
    m_configManager = manager;
    qDebug() << "🔗 ProtectionMonitorService: ProtectionConfigManager 已连接";
}

void ProtectionMonitorService::setNetworkTask(NetworkTask *task)
{
    m_networkTask = task;

    // ⚠️ TEMPORARILY DISABLED: NetworkTask feature requires Qt SerialBus
    // Qt SerialBus not available in ARM cross-compilation environment
    // TODO: Re-enable when cross-compile environment supports SerialBus
    /*
    // 连接寄存器值接收信号
    connect(m_networkTask, &NetworkTask::registerValueReceived,
            this, &ProtectionMonitorService::onRegisterValueReceived);
    */

    qDebug() << "🔗 ProtectionMonitorService: NetworkTask 已连接（功能暂时禁用）";
}

void ProtectionMonitorService::start()
{
    if (m_isRunning) {
        qDebug() << "⚠️  ProtectionMonitorService: 监控服务已经在运行中";
        return;
    }

    if (!m_configManager) {
        qWarning() << "❌ ProtectionMonitorService: ProtectionConfigManager 未设置，无法启动";
        return;
    }

    if (!m_networkTask) {
        qWarning() << "❌ ProtectionMonitorService: NetworkTask 未设置，无法启动";
        return;
    }

    qDebug() << "🚀 ProtectionMonitorService: 启动保护监控服务";
    m_isRunning = true;

    // 加载所有保护配置
    loadProtectionConfigs();
}

void ProtectionMonitorService::stop()
{
    if (!m_isRunning) {
        return;
    }

    qDebug() << "🛑 ProtectionMonitorService: 停止保护监控服务";
    m_isRunning = false;

    // 停止所有延时定时器
    for (auto timer : m_delayTimers.values()) {
        timer->stop();
    }

    // 清空所有状态
    m_protectionTriggered.clear();
    m_pendingChecks.clear();
    m_lastRegisterValues.clear();
}

void ProtectionMonitorService::loadProtectionConfigs()
{
    qDebug() << "📖 ProtectionMonitorService: 加载保护配置...";

    m_protectionConfigs.clear();
    m_digitalProtectionMap.clear();
    m_analogProtectionMap.clear();

    QStringList protectionNames = m_configManager->getAllProtectionNames();
    qDebug() << "📊 ProtectionMonitorService: 找到" << protectionNames.size() << "个保护配置";

    for (const QString &name : protectionNames) {
        ProtectionConfig config = m_configManager->loadConfig(name);
        if (config.name.isEmpty()) {
            qWarning() << "⚠️  ProtectionMonitorService: 加载配置失败:" << name;
            continue;
        }

        m_protectionConfigs[name] = config;

        // 构建快速查找映射
        if (config.type == "digital") {
            // 数字保护：寄存器地址 -> 通道号 -> 保护名称
            m_digitalProtectionMap[config.registerAddress][config.channelNumber] = name;
            qDebug() << "  数字保护:" << name
                     << "- 寄存器:" << config.registerAddress
                     << "通道:" << config.channelNumber;
        } else if (config.type == "analog") {
            // 模拟量保护：寄存器地址 -> 保护名称
            m_analogProtectionMap[config.registerAddress] = name;
            qDebug() << "  模拟量保护:" << name
                     << "- 寄存器:" << config.registerAddress
                     << "上限:" << config.upperLimit
                     << "下限:" << config.lowerLimit;
        }

        // 初始化触发状态
        m_protectionTriggered[name] = false;
    }

    qDebug() << "✅ ProtectionMonitorService: 保护配置加载完成";
    qDebug() << "  数字保护:" << m_digitalProtectionMap.size() << "个寄存器";
    qDebug() << "  模拟量保护:" << m_analogProtectionMap.size() << "个寄存器";
}

void ProtectionMonitorService::onRegisterValueReceived(int address, quint16 value)
{
    if (!m_isRunning) {
        return;
    }

    // 检查是否是数字保护寄存器
    if (m_digitalProtectionMap.contains(address)) {
        checkDigitalProtection(address, value);
    }

    // 检查是否是模拟量保护寄存器
    if (m_analogProtectionMap.contains(address)) {
        checkAnalogProtection(address, value);
    }

    // 更新上次值
    m_lastRegisterValues[address] = value;
}

void ProtectionMonitorService::checkDigitalProtection(int registerAddress, quint16 value)
{
    // 获取上次的值
    quint16 lastValue = m_lastRegisterValues.value(registerAddress, 0);

    // 获取该寄存器的所有通道保护
    const QMap<int, QString> &channelMap = m_digitalProtectionMap[registerAddress];

    for (auto it = channelMap.constBegin(); it != channelMap.constEnd(); ++it) {
        int channel = it.key();
        QString protectionName = it.value();

        // 提取通道位
        bool currentBit = (value >> channel) & 0x01;
        bool lastBit = (lastValue >> channel) & 0x01;

        // 检测从 0 到 1 的跳变（保护触发）
        if (currentBit && !lastBit) {
            qDebug() << "🔴 ProtectionMonitorService: 数字保护触发 -" << protectionName
                     << "寄存器:" << registerAddress << "通道:" << channel;

            // 检查是否应该触发（考虑延时）
            if (shouldTrigger(protectionName, true)) {
                triggerProtection(protectionName, 1.0);  // 数字保护值固定为 1.0
            }
        }
        // 检测从 1 到 0 的跳变（保护恢复）
        else if (!currentBit && lastBit) {
            qDebug() << "🟢 ProtectionMonitorService: 数字保护恢复 -" << protectionName;
            restoreProtection(protectionName);
        }
    }
}

void ProtectionMonitorService::checkAnalogProtection(int registerAddress, quint16 rawValue)
{
    QString protectionName = m_analogProtectionMap[registerAddress];
    if (!m_protectionConfigs.contains(protectionName)) {
        return;
    }

    const ProtectionConfig &config = m_protectionConfigs[protectionName];

    // 转换原始值为物理值
    double physicalValue = convertRawToPhysical(rawValue, config.range, config.lowerLimit);

    // 检查是否超限
    bool isFault = false;
    QString faultType;

    if (physicalValue > config.upperLimit) {
        isFault = true;
        faultType = "超上限";
    } else if (physicalValue < config.lowerLimit) {
        isFault = true;
        faultType = "低于下限";
    }

    if (isFault) {
        qDebug() << "🔴 ProtectionMonitorService: 模拟量保护触发 -" << protectionName
                 << faultType << "值:" << physicalValue << config.unit
                 << "(上限:" << config.upperLimit << "下限:" << config.lowerLimit << ")";

        // 检查是否应该触发（考虑延时）
        if (shouldTrigger(protectionName, true)) {
            triggerProtection(protectionName, physicalValue);
        }
    } else {
        // 值在正常范围内，检查是否需要恢复
        if (m_protectionTriggered.value(protectionName, false)) {
            qDebug() << "🟢 ProtectionMonitorService: 模拟量保护恢复 -" << protectionName
                     << "值:" << physicalValue << config.unit;
            restoreProtection(protectionName);
        }
    }
}

double ProtectionMonitorService::convertRawToPhysical(quint16 rawValue, double range, double lowerLimit)
{
    // 假设原始值范围是 0-65535，线性映射到物理值范围
    // 物理值 = 下限 + (原始值 / 65535) * 量程
    return lowerLimit + (static_cast<double>(rawValue) / 65535.0) * range;
}

bool ProtectionMonitorService::shouldTrigger(const QString &protectionName, bool isFault)
{
    if (!m_protectionConfigs.contains(protectionName)) {
        return false;
    }

    const ProtectionConfig &config = m_protectionConfigs[protectionName];

    // 如果没有延时，立即触发
    if (config.protectionDelay <= 0.0) {
        return isFault;
    }

    // 如果故障状态，启动延时定时器
    if (isFault) {
        m_pendingChecks[protectionName] = true;

        // 如果定时器已经在运行，不重复启动
        if (m_delayTimers.contains(protectionName) && m_delayTimers[protectionName]->isActive()) {
            return false;
        }

        // 创建延时定时器
        QTimer *timer = m_delayTimers.value(protectionName);
        if (!timer) {
            timer = new QTimer(this);
            timer->setSingleShot(true);
            connect(timer, &QTimer::timeout, this, &ProtectionMonitorService::onDelayedCheckTimeout);
            m_delayTimers[protectionName] = timer;
        }

        timer->start(static_cast<int>(config.protectionDelay * 1000));
        qDebug() << "⏱️  ProtectionMonitorService:" << protectionName
                 << "延时" << config.protectionDelay << "秒后检查";
        return false;
    } else {
        // 故障已消除，取消延时定时器
        m_pendingChecks.remove(protectionName);
        if (m_delayTimers.contains(protectionName)) {
            m_delayTimers[protectionName]->stop();
        }
        return false;
    }
}

void ProtectionMonitorService::onDelayedCheckTimeout()
{
    QTimer *timer = qobject_cast<QTimer*>(sender());
    if (!timer) {
        return;
    }

    // 找到触发定时器的保护名称
    QString protectionName;
    for (auto it = m_delayTimers.constBegin(); it != m_delayTimers.constEnd(); ++it) {
        if (it.value() == timer) {
            protectionName = it.key();
            break;
        }
    }

    if (protectionName.isEmpty()) {
        return;
    }

    // 检查保护是否仍然处于故障状态
    if (m_pendingChecks.value(protectionName, false)) {
        qDebug() << "⏰ ProtectionMonitorService: 延时到期，触发保护 -" << protectionName;
        // 触发保护时不再需要检查 shouldTrigger，直接触发
        // 需要获取当前值，但我们在这里没有，所以使用一个特殊值
        // 实际应用中，应该在 onRegisterValueReceived 中再次检查
        triggerProtection(protectionName, 0.0);  // 使用 0.0 作为占位值
        m_pendingChecks.remove(protectionName);
    }
}

void ProtectionMonitorService::triggerProtection(const QString &protectionName, double value)
{
    if (!m_protectionConfigs.contains(protectionName)) {
        return;
    }

    // 检查是否已经触发，避免重复触发
    if (m_protectionTriggered.value(protectionName, false)) {
        return;
    }

    const ProtectionConfig &config = m_protectionConfigs[protectionName];

    qDebug() << "🚨 ProtectionMonitorService: 触发保护 -" << protectionName << "值:" << value;

    // 标记为已触发
    m_protectionTriggered[protectionName] = true;

    // 发射触发信号
    emit protectionTriggered(protectionName, config.type, value);

    // 发射报警信号（用于播放语音）
    emit alarmTriggered(protectionName, config.ttsText, config.audioFile,
                       config.useTextToSpeech, config.playMode, config.playCount, config.playDuration);
}

void ProtectionMonitorService::restoreProtection(const QString &protectionName)
{
    // 检查是否已经触发
    if (!m_protectionTriggered.value(protectionName, false)) {
        return;
    }

    qDebug() << "✅ ProtectionMonitorService: 恢复保护 -" << protectionName;

    // 标记为未触发
    m_protectionTriggered[protectionName] = false;

    // 取消待检查状态
    m_pendingChecks.remove(protectionName);

    // 停止延时定时器
    if (m_delayTimers.contains(protectionName)) {
        m_delayTimers[protectionName]->stop();
    }

    // 发射恢复信号
    emit protectionRestored(protectionName);
}

void ProtectionMonitorService::testProtection(const QString &protectionName)
{
    qDebug() << "🧪 ProtectionMonitorService: 测试保护 -" << protectionName;

    if (!m_protectionConfigs.contains(protectionName)) {
        qWarning() << "❌ ProtectionMonitorService: 保护不存在:" << protectionName;
        return;
    }

    // 模拟触发保护
    triggerProtection(protectionName, 999.0);

    // 3秒后自动恢复
    QTimer::singleShot(3000, this, [this, protectionName]() {
        restoreProtection(protectionName);
    });
}

void ProtectionMonitorService::manualReset()
{
    qDebug() << "🔄 ProtectionMonitorService: 手动复位（F键） - 检查所有保护的外部信号";

    // 遍历所有已触发的保护
    QStringList triggeredProtections;
    for (auto it = m_protectionTriggered.constBegin(); it != m_protectionTriggered.constEnd(); ++it) {
        if (it.value()) {
            triggeredProtections.append(it.key());
        }
    }

    if (triggeredProtections.isEmpty()) {
        qDebug() << "  没有已触发的保护，无需复位";
        return;
    }

    qDebug() << "  已触发的保护数量:" << triggeredProtections.size();

    // 检查每个已触发的保护的外部信号
    for (const QString &protectionName : triggeredProtections) {
        if (!m_protectionConfigs.contains(protectionName)) {
            continue;
        }

        const ProtectionConfig &config = m_protectionConfigs[protectionName];
        int registerAddress = config.registerAddress;

        // 检查是否有该寄存器的最新值
        if (!m_lastRegisterValues.contains(registerAddress)) {
            qDebug() << "  ⚠️ " << protectionName << ": 寄存器" << registerAddress << "无最新值，保持保护状态";
            continue;
        }

        quint16 currentValue = m_lastRegisterValues[registerAddress];

        // 根据保护类型检查外部信号是否已恢复
        bool canReset = false;

        if (config.type == "digital") {
            // 数字保护：检查特定通道的位是否为0
            int channel = config.channelNumber;
            bool bitValue = (currentValue >> channel) & 0x01;

            if (bitValue == 0) {
                canReset = true;
                qDebug() << "  ✅" << protectionName << ": 外部信号已恢复（寄存器" << registerAddress
                         << "通道" << channel << "= 0），允许复位";
            } else {
                qDebug() << "  ❌" << protectionName << ": 外部信号仍为1（寄存器" << registerAddress
                         << "通道" << channel << "），保持RED状态";
            }

        } else if (config.type == "analog") {
            // 模拟量保护：检查值是否回到正常范围
            double physicalValue = convertRawToPhysical(currentValue, config.range, config.lowerLimit);

            // 检查是否在安全范围内
            bool inSafeRange = (physicalValue >= config.lowerLimit && physicalValue <= config.upperLimit);

            if (inSafeRange) {
                canReset = true;
                qDebug() << "  ✅" << protectionName << ": 外部信号已恢复（当前值"
                         << physicalValue << config.unit << "在安全范围内），允许复位";
            } else {
                qDebug() << "  ❌" << protectionName << ": 外部信号仍超限（当前值"
                         << physicalValue << config.unit << "），保持RED状态";
            }
        }

        // 如果外部信号已恢复，则恢复保护
        if (canReset) {
            restoreProtection(protectionName);
        }
    }
}
