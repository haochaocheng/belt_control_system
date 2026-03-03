/**
 * @file MQTTAutoManager.cpp
 * @brief MQTT 自动管理器实现
 * @date 2026-02-09
 * @phase 7.44.1
 */

#include "MQTTAutoManager.h"
#include "MQTTController.h"
#include "../control/AudioPathMapper.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSettings>

MQTTAutoManager::MQTTAutoManager(MQTTController *mqttController, QObject *parent)
    : QObject(parent)
    , m_mqttController(mqttController)
    , m_autoConnectEnabled(true)
    , m_pollingEnabled(true)
    , m_diPollingInterval(100)
    , m_aiPollingInterval(500)
    , m_reconnectTimer(nullptr)
    , m_diPollingTimer(nullptr)
    , m_aiPollingTimer(nullptr)
    , m_healthCheckTimer(nullptr)
    // ✅ 2026-03-02 [Phase 7.47.67]: 从 QSettings 加载超时阈值，默认2秒
    , m_dataTimeoutThreshold(QSettings("BeltControl", "MQTTAutoManager").value("dataTimeoutThreshold", 2).toInt())
    // ✅ 2026-03-02 [Phase 7.47.68]: 从 QSettings 加载 broker 连接超时，默认30秒
    , m_brokerConnectTimeout(QSettings("BeltControl", "MQTTAutoManager").value("brokerConnectTimeout", 30).toInt())
    , m_lastBrokerAlertTime(0)
{
    qDebug() << "✅ [MQTTAutoManager] 初始化自动管理器";

    // 初始化健康状态
    initializeHealthStatus();

    // 初始化定时器
    initializeTimers();

    // 连接 MQTT 控制器信号
    connect(m_mqttController, &MQTTController::connectedChanged,
            this, &MQTTAutoManager::onModuleConnected);
    connect(m_mqttController, &MQTTController::messageReceived,
            this, &MQTTAutoManager::onModuleMessageReceived);

    qDebug() << "✅ [MQTTAutoManager] 自动管理器初始化完成";
}

MQTTAutoManager::~MQTTAutoManager()
{
    qDebug() << "✅ [MQTTAutoManager] 销毁自动管理器";
    stop();
}

// ========== 初始化 ==========

void MQTTAutoManager::initializeHealthStatus()
{
    m_healthStatus.resize(8);
    // ✅ 2026-02-12 [Phase 7.45.33]: 初始化连接状态跟踪
    m_lastConnectedStates.resize(8, false);
    // ✅ 2026-03-01 [Phase 7.47.64]: 初始化健康检查日志计数器
    m_healthCheckLogCounter.resize(8, 0);

    for (int i = 0; i < 8; ++i) {
        m_healthStatus[i] = ModuleHealthStatus();
    }
    qDebug() << "✅ [MQTTAutoManager] 初始化健康状态";
}

void MQTTAutoManager::initializeTimers()
{
    // 重连检查定时器
    m_reconnectTimer = new QTimer(this);
    m_reconnectTimer->setInterval(RECONNECT_CHECK_INTERVAL);
    connect(m_reconnectTimer, &QTimer::timeout,
            this, &MQTTAutoManager::onReconnectTimerTimeout);

    // 开关量采集定时器
    m_diPollingTimer = new QTimer(this);
    m_diPollingTimer->setInterval(m_diPollingInterval);
    connect(m_diPollingTimer, &QTimer::timeout,
            this, &MQTTAutoManager::onDIPollingTimerTimeout);

    // 模拟量采集定时器
    m_aiPollingTimer = new QTimer(this);
    m_aiPollingTimer->setInterval(m_aiPollingInterval);
    connect(m_aiPollingTimer, &QTimer::timeout,
            this, &MQTTAutoManager::onAIPollingTimerTimeout);

    // 健康检查定时器
    m_healthCheckTimer = new QTimer(this);
    m_healthCheckTimer->setInterval(HEALTH_CHECK_INTERVAL);
    connect(m_healthCheckTimer, &QTimer::timeout,
            this, &MQTTAutoManager::onHealthCheckTimerTimeout);

    qDebug() << "✅ [MQTTAutoManager] 初始化定时器";
}

// ========== 属性设置 ==========

void MQTTAutoManager::setAutoConnectEnabled(bool enabled)
{
    if (m_autoConnectEnabled != enabled) {
        m_autoConnectEnabled = enabled;
        qDebug() << "✅ [MQTTAutoManager] 自动连接:" << (enabled ? "启用" : "禁用");
        emit autoConnectEnabledChanged();

        if (enabled) {
            startReconnectTimer();
        } else {
            stopReconnectTimer();
        }
    }
}

void MQTTAutoManager::setPollingEnabled(bool enabled)
{
    if (m_pollingEnabled != enabled) {
        m_pollingEnabled = enabled;
        qDebug() << "✅ [MQTTAutoManager] 数据采集:" << (enabled ? "启用" : "禁用");
        emit pollingEnabledChanged();

        if (enabled) {
            startPolling();
        } else {
            stopPolling();
        }
    }
}

void MQTTAutoManager::setDIPollingInterval(int interval)
{
    if (interval < 50 || interval > 1000) {
        qWarning() << "⚠️ [MQTTAutoManager] 无效的开关量采集间隔:" << interval;
        return;
    }

    if (m_diPollingInterval != interval) {
        m_diPollingInterval = interval;
        qDebug() << "✅ [MQTTAutoManager] 开关量采集间隔:" << interval << "ms";
        emit diPollingIntervalChanged();

        if (m_diPollingTimer && m_diPollingTimer->isActive()) {
            m_diPollingTimer->setInterval(interval);
        }
    }
}

void MQTTAutoManager::setAIPollingInterval(int interval)
{
    if (interval < 100 || interval > 5000) {
        qWarning() << "⚠️ [MQTTAutoManager] 无效的模拟量采集间隔:" << interval;
        return;
    }

    if (m_aiPollingInterval != interval) {
        m_aiPollingInterval = interval;
        qDebug() << "✅ [MQTTAutoManager] 模拟量采集间隔:" << interval << "ms";
        emit aiPollingIntervalChanged();

        if (m_aiPollingTimer && m_aiPollingTimer->isActive()) {
            m_aiPollingTimer->setInterval(interval);
        }
    }
}

QVariantList MQTTAutoManager::healthStatus() const
{
    QVariantList list;
    for (int i = 0; i < m_healthStatus.size(); ++i) {
        QVariantMap status;
        status["moduleIndex"] = i;
        status["connected"] = m_healthStatus[i].connected;
        status["lastDataTime"] = m_healthStatus[i].lastDataTime;
        status["dataTimeoutCount"] = m_healthStatus[i].dataTimeoutCount;
        status["reconnectCount"] = m_healthStatus[i].reconnectCount;
        status["status"] = m_healthStatus[i].status;
        list.append(status);
    }
    return list;
}

QVariantMap MQTTAutoManager::getModuleHealth(int moduleIndex) const
{
    QVariantMap status;
    if (moduleIndex >= 0 && moduleIndex < m_healthStatus.size()) {
        status["moduleIndex"] = moduleIndex;
        status["connected"] = m_healthStatus[moduleIndex].connected;
        status["lastDataTime"] = m_healthStatus[moduleIndex].lastDataTime;
        status["dataTimeoutCount"] = m_healthStatus[moduleIndex].dataTimeoutCount;
        status["reconnectCount"] = m_healthStatus[moduleIndex].reconnectCount;
        status["status"] = m_healthStatus[moduleIndex].status;
    }
    return status;
}

// ✅ 2026-03-02 [Phase 7.47.67]: 设置数据超时阈值并持久化
void MQTTAutoManager::setDataTimeoutThreshold(int seconds)
{
    int clamped = qBound(1, seconds, 60);  // 限制在 1~60 秒
    if (m_dataTimeoutThreshold == clamped) return;
    m_dataTimeoutThreshold = clamped;
    QSettings("BeltControl", "MQTTAutoManager").setValue("dataTimeoutThreshold", clamped);
    qDebug() << "✅ [MQTTAutoManager] 模块超时阈值已设置:" << clamped << "秒";
    emit dataTimeoutThresholdChanged();
}

// ✅ 2026-03-02 [Phase 7.47.68]: 设置 broker 连接超时阈值并持久化
void MQTTAutoManager::setBrokerConnectTimeout(int seconds)
{
    int clamped = qBound(1, seconds, 120);  // 限制在 1~120 秒（最小1秒，原为5秒，2026-03-03改）
    if (m_brokerConnectTimeout == clamped) return;
    m_brokerConnectTimeout = clamped;
    QSettings("BeltControl", "MQTTAutoManager").setValue("brokerConnectTimeout", clamped);
    qDebug() << "✅ [MQTTAutoManager] broker 连接超时已设置:" << clamped << "秒";
    emit brokerConnectTimeoutChanged();
}

// ========== 公共方法 ==========

void MQTTAutoManager::start()
{
    qDebug() << "🚀 [MQTTAutoManager] 启动自动管理器";

    // 自动连接前4个模块
    if (m_autoConnectEnabled) {
        connectAllModules();
        startReconnectTimer();
    }

    // 启动数据采集
    if (m_pollingEnabled) {
        startPolling();
    }

    // 启动健康检查
    startHealthCheck();

    qDebug() << "✅ [MQTTAutoManager] 自动管理器已启动";
}

void MQTTAutoManager::stop()
{
    qDebug() << "🛑 [MQTTAutoManager] 停止自动管理器";

    stopReconnectTimer();
    stopPolling();
    stopHealthCheck();

    qDebug() << "✅ [MQTTAutoManager] 自动管理器已停止";
}

void MQTTAutoManager::connectAllModules()
{
    qDebug() << "🔌 [MQTTAutoManager] 连接所有模块（前4个）";

    // 连接前4个模块：开关量×2 + 模拟量×2
    for (int i = 0; i < 4; ++i) {
        connectModule(i);
    }
}

void MQTTAutoManager::disconnectAllModules()
{
    qDebug() << "🔌 [MQTTAutoManager] 断开所有模块";
    m_mqttController->disconnectAll();
}

void MQTTAutoManager::reconnectModule(int moduleIndex)
{
    if (moduleIndex < 0 || moduleIndex >= 8) {
        qWarning() << "⚠️ [MQTTAutoManager] 无效的模块索引:" << moduleIndex;
        return;
    }

    // ✅ 2026-02-12 [Phase 7.45.33]: 移除重复日志，状态变化已在 onReconnectTimerTimeout 中输出
    // qDebug() << "🔄 [MQTTAutoManager] 重连模块:" << moduleIndex;

    // 先断开
    m_mqttController->disconnectFromModule(moduleIndex);

    // 等待100ms后重连
    QTimer::singleShot(100, this, [this, moduleIndex]() {
        connectModule(moduleIndex);
        m_healthStatus[moduleIndex].reconnectCount++;
        emit healthStatusChanged();
    });
}

// ========== 连接管理 ==========

void MQTTAutoManager::connectModule(int moduleIndex)
{
    if (moduleIndex < 0 || moduleIndex >= 8) {
        return;
    }

    // ✅ 2026-02-12 [Phase 7.45.33]: 移除重复日志，连接状态变化会在 MQTTController 中输出
    // qDebug() << "🔌 [MQTTAutoManager] 连接模块:" << moduleIndex;

    // 连接到 Broker
    // ✅ 2026-02-09 [Phase 7.44.20]: 订阅逻辑移到 onModuleConnected() 中
    // 原因：连接是异步的，固定延迟500ms可能不够，应该在连接成功信号中订阅
    m_mqttController->connectToModule(moduleIndex);
}

void MQTTAutoManager::startReconnectTimer()
{
    if (m_reconnectTimer && !m_reconnectTimer->isActive()) {
        m_reconnectTimer->start();
        qDebug() << "✅ [MQTTAutoManager] 启动重连检查定时器";
    }
}

void MQTTAutoManager::stopReconnectTimer()
{
    if (m_reconnectTimer && m_reconnectTimer->isActive()) {
        m_reconnectTimer->stop();
        qDebug() << "✅ [MQTTAutoManager] 停止重连检查定时器";
    }
}

// ========== 数据采集 ==========

void MQTTAutoManager::startPolling()
{
    if (m_diPollingTimer && !m_diPollingTimer->isActive()) {
        m_diPollingTimer->start();
        qDebug() << "✅ [MQTTAutoManager] 启动开关量采集定时器";
    }

    if (m_aiPollingTimer && !m_aiPollingTimer->isActive()) {
        m_aiPollingTimer->start();
        qDebug() << "✅ [MQTTAutoManager] 启动模拟量采集定时器";
    }
}

void MQTTAutoManager::stopPolling()
{
    if (m_diPollingTimer && m_diPollingTimer->isActive()) {
        m_diPollingTimer->stop();
        qDebug() << "✅ [MQTTAutoManager] 停止开关量采集定时器";
    }

    if (m_aiPollingTimer && m_aiPollingTimer->isActive()) {
        m_aiPollingTimer->stop();
        qDebug() << "✅ [MQTTAutoManager] 停止模拟量采集定时器";
    }
}

void MQTTAutoManager::pollDIModules()
{
    // 轮询开关量模块（模块0和模块1）
    for (int i = 0; i < 2; ++i) {
        if (!m_mqttController->isModuleConnected(i)) {
            continue;
        }

        QString controlTopic = QString("belt_control/di/module%1/control").arg(i + 1);

        // 构造读取命令
        QJsonObject cmd;
        cmd["cmd"] = "read";
        cmd["timestamp"] = QDateTime::currentSecsSinceEpoch();

        QByteArray payload = QJsonDocument(cmd).toJson(QJsonDocument::Compact);

        // 发布命令
        m_mqttController->publishBytes(controlTopic, payload, 1, false, i);
    }
}

void MQTTAutoManager::pollAIModules()
{
    // 轮询模拟量模块（模块2和模块3）
    for (int i = 2; i < 4; ++i) {
        if (!m_mqttController->isModuleConnected(i)) {
            continue;
        }

        QString controlTopic = QString("belt_control/ai/module%1/control").arg(i + 1);

        // 构造读取命令
        QJsonObject cmd;
        cmd["cmd"] = "read";
        cmd["timestamp"] = QDateTime::currentSecsSinceEpoch();

        QByteArray payload = QJsonDocument(cmd).toJson(QJsonDocument::Compact);

        // 发布命令
        m_mqttController->publishBytes(controlTopic, payload, 1, false, i);
    }
}

// ========== 健康监控 ==========

void MQTTAutoManager::startHealthCheck()
{
    if (m_healthCheckTimer && !m_healthCheckTimer->isActive()) {
        m_healthCheckTimer->start();
        qDebug() << "✅ [MQTTAutoManager] 启动健康检查定时器";
    }
}

void MQTTAutoManager::stopHealthCheck()
{
    if (m_healthCheckTimer && m_healthCheckTimer->isActive()) {
        m_healthCheckTimer->stop();
        qDebug() << "✅ [MQTTAutoManager] 停止健康检查定时器";
    }
}

void MQTTAutoManager::checkModuleHealth(int moduleIndex)
{
    if (moduleIndex < 0 || moduleIndex >= 4) {
        return;  // 只检查前4个模块
    }

    ModuleHealthStatus &health = m_healthStatus[moduleIndex];
    qint64 now = QDateTime::currentSecsSinceEpoch();

    // ✅ 2026-03-01 [Phase 7.47.64]: 周期性详细状态日志（每10秒输出一次）
    // 原因：帮助诊断"模块状态停留在正常/青色"的问题，暴露 lastDataTime 和 timeSinceLastData 真实值
    m_healthCheckLogCounter[moduleIndex]++;
    if (m_healthCheckLogCounter[moduleIndex] >= 10) {
        m_healthCheckLogCounter[moduleIndex] = 0;
        qint64 tSince = (health.lastDataTime > 0) ? (now - health.lastDataTime) : -1;
        qDebug() << "[MQTTAutoManager] 模块" << moduleIndex
                 << "健康检查 | connected:" << health.connected
                 << "| lastDataTime:" << health.lastDataTime
                 << "| timeSinceLastData:" << tSince << "s"
                 << "| status:" << health.status
                 << "| timeoutCount:" << health.dataTimeoutCount;
    }

    // 检查连接状态
    health.connected = m_mqttController->isModuleConnected(moduleIndex);

    if (!health.connected) {
        health.status = "未连接";
        return;
    }

    // 检查数据超时（5秒无数据）
    // ✅ 2026-03-01 [Phase 7.47.62]: 修复 lastDataTime=0 时跳过超时检查的问题
    // 旧逻辑：if (lastDataTime > 0) — 从未收到数据时不检查，status停留在"已连接"
    // 新逻辑：lastDataTime=0 表示连上broker但从未收到硬件数据，也视为"等待数据"
    if (health.lastDataTime == 0) {
        // 连上broker但从未收到数据 → 不算"正常"
        health.status = "等待数据";
        return;
    }

    qint64 timeSinceLastData = now - health.lastDataTime;

    if (timeSinceLastData > m_dataTimeoutThreshold) {
        // ✅ 2026-03-01 [Phase 7.47.63]: 超过阈值立即降级 "正常" → "等待数据"
        // 旧逻辑：超时计数达到3次才改 status，导致数据停止后 6~8 秒仍显示青色
        // 新逻辑：超过阈值的第一次检查立即降级，用户断开测试工具后 5 秒内即可看到变化
        if (health.status == "正常") {
            health.status = "等待数据";
            qDebug() << "⚠️ [MQTTAutoManager] 模块" << moduleIndex
                     << "数据中断，等待恢复 | timeSinceLastData:" << timeSinceLastData << "s";
        }
        health.dataTimeoutCount++;

        if (health.dataTimeoutCount >= MAX_TIMEOUT_COUNT) {
            health.status = "数据超时";
            emit moduleHealthWarning(moduleIndex, "数据超时");
            qWarning() << "⚠️ [MQTTAutoManager] 模块" << moduleIndex << "数据超时";
        }
    } else {
        // 恢复正常
        if (health.dataTimeoutCount > 0) {
            health.dataTimeoutCount = 0;
            health.status = "正常";
            emit moduleHealthRecovered(moduleIndex);
            qDebug() << "✅ [MQTTAutoManager] 模块" << moduleIndex << "恢复正常";
        }
    }

    // ✅ 2026-03-02 [Phase 7.47.69]: 模块离线语音提示（只播放一次，恢复后重置）
    if (health.status == "数据超时" && !health.offlineAlertSent) {
        health.offlineAlertSent = true;
        QString alertPath = AudioPathMapper::getModuleOfflinePath(moduleIndex);
        if (!alertPath.isEmpty()) {
            qDebug() << "🔊 [MQTTAutoManager] 模块" << moduleIndex << "触发离线语音:" << alertPath;
            emit voiceAlertRequested(alertPath);
        }
    }
    // 模块恢复正常时重置语音标志，下次离线可再次触发
    if (health.status == "正常") {
        health.offlineAlertSent = false;
    }
}

void MQTTAutoManager::updateLastDataTime(int moduleIndex)
{
    if (moduleIndex >= 0 && moduleIndex < m_healthStatus.size()) {
        qint64 now = QDateTime::currentSecsSinceEpoch();
        // ✅ 2026-03-01 [Phase 7.47.65]: 只在首次变"正常"或状态恢复时打印（减少日志量）
        if (m_healthStatus[moduleIndex].status != "正常") {
            qDebug() << "✅ [MQTTAutoManager] 模块" << moduleIndex
                     << "硬件数据到达，状态从"
                     << m_healthStatus[moduleIndex].status << "→ 正常";
        }
        m_healthStatus[moduleIndex].lastDataTime = now;
        m_healthStatus[moduleIndex].dataTimeoutCount = 0;
        m_healthStatus[moduleIndex].status = "正常";
    }
}

// ✅ 2026-03-02 [Phase 7.47.68]: 检查所有8个模块的 broker 连接超时
// 触发条件1（初始连接超时）：任意模块 Connecting 超过 m_brokerConnectTimeout 秒
// 触发条件2（运行中断开）：任意模块曾连接成功，断开后 5 秒内未恢复
// 去重策略：5分钟内只触发一次"连接服务器失败"语音
void MQTTAutoManager::checkBrokerConnections()
{
    qint64 now = QDateTime::currentSecsSinceEpoch();
    for (int i = 0; i < 8; ++i) {
        ModuleHealthStatus &health = m_healthStatus[i];
        bool isConnecting = m_mqttController->isModuleConnecting(i);
        bool isConnected  = m_mqttController->isModuleConnected(i);

        // ✅ 2026-03-02 [Phase 7.47.72]: 检测运行中服务器中断（已连接 → 断开）
        // ✅ 2026-03-03 [Phase 7.47.74 修复]: 宽限期从硬编码 5s 改为 m_brokerConnectTimeout
        //    根因：旧代码 lostSeconds >= 5 与用户设置的"连接超时"无关
        //    服务器断开后 5 秒必触发语音，30 秒设置形同虚设
        //    修复后：用户设置 N 秒连接超时，服务器断开后等待 N 秒再播报
        if (!isConnected && health.serverLostTime > 0) {
            qint64 lostSeconds = now - health.serverLostTime;
            if (lostSeconds >= m_brokerConnectTimeout) {  // 使用用户配置的连接超时，不再硬编码 5 秒
                if ((now - m_lastBrokerAlertTime) > 300) {
                    m_lastBrokerAlertTime = now;
                    QString alertPath = AudioPathMapper::getBrokerConnectionFailedPath();
                    qWarning() << "🔊 [MQTTAutoManager] 模块" << i
                               << "服务器连接中断 (" << lostSeconds << "s)，触发语音:" << alertPath;
                    emit voiceAlertRequested(alertPath);
                }
            }
        }

        if (isConnecting) {
            // 记录开始连接时间
            if (health.connectingStartTime == 0) {
                health.connectingStartTime = now;
            } else {
                qint64 waited = now - health.connectingStartTime;
                if (waited > m_brokerConnectTimeout) {
                    // 5分钟去重
                    if ((now - m_lastBrokerAlertTime) > 300) {
                        m_lastBrokerAlertTime = now;
                        QString alertPath = AudioPathMapper::getBrokerConnectionFailedPath();
                        qWarning() << "🔊 [MQTTAutoManager] 模块" << i
                                   << "连接超时 (" << waited << "s)，触发语音:" << alertPath;
                        emit voiceAlertRequested(alertPath);
                    }
                }
            }
        } else {
            // 已连接或断开，重置 Connecting 追踪
            health.connectingStartTime = 0;
        }
    }
}

// ========== 定时器槽函数 ==========

void MQTTAutoManager::onReconnectTimerTimeout()
{
    // ✅ 2026-02-12 [Phase 7.45.33]: 只在连接状态变化时输出调试信息
    // 检查前4个模块的连接状态，断线自动重连
    for (int i = 0; i < 4; ++i) {
        bool isConnected = m_mqttController->isModuleConnected(i);

        // 只在状态变化时输出
        if (isConnected != m_lastConnectedStates[i]) {
            if (!isConnected) {
                qDebug() << "🔄 [MQTTAutoManager] 模块" << i << "断线，尝试重连";
            }
            m_lastConnectedStates[i] = isConnected;
        }

        // 断线时重连
        if (!isConnected) {
            reconnectModule(i);
        }
    }
}

void MQTTAutoManager::onDIPollingTimerTimeout()
{
    if (m_pollingEnabled) {
        pollDIModules();
    }
}

void MQTTAutoManager::onAIPollingTimerTimeout()
{
    if (m_pollingEnabled) {
        pollAIModules();
    }
}

void MQTTAutoManager::onHealthCheckTimerTimeout()
{
    // 检查前4个模块的健康状态（硬件数据超时）
    for (int i = 0; i < 4; ++i) {
        checkModuleHealth(i);
    }
    // ✅ 2026-03-02 [Phase 7.47.68]: 检查全部8个模块的 broker 连接超时
    checkBrokerConnections();

    emit healthStatusChanged();
}

// ========== MQTT 控制器信号槽 ==========

void MQTTAutoManager::onModuleConnected(int moduleIndex, bool connected)
{
    if (moduleIndex >= 0 && moduleIndex < m_healthStatus.size()) {
        m_healthStatus[moduleIndex].connected = connected;

        if (connected) {
            m_healthStatus[moduleIndex].status = "已连接";
            // ✅ 2026-02-12 [Phase 7.45.33]: 只在状态变化时输出
            if (!m_lastConnectedStates[moduleIndex]) {
                qDebug() << "✅ [MQTTAutoManager] 模块" << moduleIndex << "已连接";
                m_lastConnectedStates[moduleIndex] = true;
            }
            // ✅ 2026-03-02 [Phase 7.47.72]: 重连成功后清除服务器中断记录
            m_healthStatus[moduleIndex].serverLostTime = 0;

            // ✅ 2026-02-09 [Phase 7.44.20]: 连接成功后立即订阅主题
            // 原因：修复订阅失败问题，之前使用固定延迟500ms可能不够
            QString statusTopic;
            if (moduleIndex < 2) {
                // 开关量模块
                statusTopic = QString("belt_control/di/module%1/status").arg(moduleIndex + 1);
            } else if (moduleIndex < 4) {
                // 模拟量模块
                // ✅ 2026-02-09 [Phase 7.44.20]: 修复模拟量模块主题计算错误
                // 原因：模块2应该是ai/module1，模块3应该是ai/module2
                statusTopic = QString("belt_control/ai/module%1/status").arg(moduleIndex - 1);
            } else {
                // 其他模块（暂未实施）
                emit healthStatusChanged();
                return;
            }

            // 订阅状态主题
            bool success = m_mqttController->subscribe(statusTopic, 1, moduleIndex);
            if (success) {
                qDebug() << "✅ [MQTTAutoManager] 模块" << moduleIndex << "订阅主题:" << statusTopic;
            } else {
                qWarning() << "⚠️ [MQTTAutoManager] 模块" << moduleIndex << "订阅失败:" << statusTopic;
            }
        } else {
            m_healthStatus[moduleIndex].status = "未连接";
            // ✅ 2026-03-01 [Phase 7.47.63]: 断开时重置数据状态
            // 原因：重连后 lastDataTime 会保留旧值，若 EMQX 有 retained 消息重发
            //       会刷新 lastDataTime，导致重连后误显示"正常"（青色）
            //       重置为 0 后重连进入"等待数据"，只有新鲜数据才能进入"正常"
            m_healthStatus[moduleIndex].lastDataTime = 0;
            m_healthStatus[moduleIndex].dataTimeoutCount = 0;
            // ✅ 2026-02-12 [Phase 7.45.33]: 只在状态变化时输出
            if (m_lastConnectedStates[moduleIndex]) {
                qDebug() << "⚠️ [MQTTAutoManager] 模块" << moduleIndex << "已断开";
                m_lastConnectedStates[moduleIndex] = false;
                // ✅ 2026-03-02 [Phase 7.47.72]: 记录服务器中断时刻（仅首次断开记录）
                // 条件：模块之前是已连接状态（m_lastConnectedStates[moduleIndex] 为 true）
                // 触发：EMQX宕机或网络中断导致运行中的模块断开
                if (m_healthStatus[moduleIndex].serverLostTime == 0) {
                    m_healthStatus[moduleIndex].serverLostTime = QDateTime::currentSecsSinceEpoch();
                    qDebug() << "🔌 [MQTTAutoManager] 模块" << moduleIndex
                             << "服务器连接中断，记录时刻:" << m_healthStatus[moduleIndex].serverLostTime;
                }
            }
        }

        emit healthStatusChanged();
    }
}

void MQTTAutoManager::onModuleMessageReceived(int moduleIndex, const QString &topic, const QByteArray &payload)
{
    // ✅ 2026-03-01 [Phase 7.47.65]: 只有来自硬件模块状态主题的消息才更新健康状态
    // 根因（voip.md 日志揭露）：
    //   模块0 同时订阅了 belt_control/di/module1/status（硬件模块）
    //   + station/status/+（VoIP控制站心跳，持续不断）
    //   + device/status/+（VoIP设备心跳，持续不断）
    //   VoIP 心跳消息不断触发 updateLastDataTime → lastDataTime 一直刷新
    //   → status 永远是"正常" → LED 永远青色，即使硬件模块断电也不变
    // 修复：仅硬件模块专属状态主题触发健康状态更新
    QString expectedHardwareTopic;
    if (moduleIndex < 2) {
        // 开关量模块
        expectedHardwareTopic = QString("belt_control/di/module%1/status").arg(moduleIndex + 1);
    } else if (moduleIndex < 4) {
        // 模拟量模块
        expectedHardwareTopic = QString("belt_control/ai/module%1/status").arg(moduleIndex - 1);
    }

    bool isHardwareTopic = (!expectedHardwareTopic.isEmpty() && topic == expectedHardwareTopic);
    if (isHardwareTopic) {
        updateLastDataTime(moduleIndex);
    }

    // 转发给数据管理器（无论什么主题都转发，各模块按 topic 自行处理）
    emit moduleDataReceived(moduleIndex, topic, payload);

    // ✅ 2026-03-01 [Phase 7.47.64]: 数据接收日志（调试用，诊断后可注释）
    // ✅ 2026-03-02 [Phase 7.47.70]: 删除高频日志（每条消息都打印，包含VoIP心跳，日志量极大）
    // qDebug() << "📩 [MQTTAutoManager] 模块" << moduleIndex
    //          << "消息到达 | 主题:" << topic
    //          << "| 大小:" << payload.size() << "bytes"
    //          << "| 更新健康状态:" << (isHardwareTopic ? "✅是" : "❌否(VoIP/其他)");
}
