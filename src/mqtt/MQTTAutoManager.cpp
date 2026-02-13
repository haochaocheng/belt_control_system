/**
 * @file MQTTAutoManager.cpp
 * @brief MQTT 自动管理器实现
 * @date 2026-02-09
 * @phase 7.44.1
 */

#include "MQTTAutoManager.h"
#include "MQTTController.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>

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

    // 检查连接状态
    health.connected = m_mqttController->isModuleConnected(moduleIndex);

    if (!health.connected) {
        health.status = "未连接";
        return;
    }

    // 检查数据超时（5秒无数据）
    if (health.lastDataTime > 0) {
        qint64 timeSinceLastData = now - health.lastDataTime;

        if (timeSinceLastData > DATA_TIMEOUT_THRESHOLD) {
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
    }
}

void MQTTAutoManager::updateLastDataTime(int moduleIndex)
{
    if (moduleIndex >= 0 && moduleIndex < m_healthStatus.size()) {
        m_healthStatus[moduleIndex].lastDataTime = QDateTime::currentSecsSinceEpoch();
        m_healthStatus[moduleIndex].dataTimeoutCount = 0;
        m_healthStatus[moduleIndex].status = "正常";
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
    // 检查前4个模块的健康状态
    for (int i = 0; i < 4; ++i) {
        checkModuleHealth(i);
    }

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
            // ✅ 2026-02-12 [Phase 7.45.33]: 只在状态变化时输出
            if (m_lastConnectedStates[moduleIndex]) {
                qDebug() << "⚠️ [MQTTAutoManager] 模块" << moduleIndex << "已断开";
                m_lastConnectedStates[moduleIndex] = false;
            }
        }

        emit healthStatusChanged();
    }
}

void MQTTAutoManager::onModuleMessageReceived(int moduleIndex, const QString &topic, const QByteArray &payload)
{
    // 更新最后数据时间
    updateLastDataTime(moduleIndex);

    // 转发给数据管理器
    emit moduleDataReceived(moduleIndex, topic, payload);

    qDebug() << "📩 [MQTTAutoManager] 模块" << moduleIndex << "收到数据 - 主题:" << topic;
}
