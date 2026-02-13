/**
 * @file MQTTController.cpp
 * @brief MQTT 通讯控制器实现
 * @date 2026-02-08
 * @phase 7.43
 */

#include "MQTTController.h"
#include <QDebug>
#include <QDateTime>
#include <QSettings>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>

MQTTController::MQTTController(QObject *parent)
    : QObject(parent)
    , m_currentModuleIndex(0)
    , m_maxReceivedMessages(100)
{
    qDebug() << "✅ [MQTTController] 初始化 MQTT 控制器";

    // 初始化 8 个模块配置
    initializeModules();

#ifdef MQTT_ENABLED
    // 初始化客户端和订阅容器
    m_clients.resize(8);
    m_subscriptions.resize(8);
    // ✅ 2026-02-13 [Phase 7.45.33 修复]: 移除 m_lastStates 初始化
    // ✅ 2026-02-13 [Phase 7.45.34]: 初始化错误状态跟踪
    m_lastErrors.resize(8, QMqttClient::NoError);

    for (int i = 0; i < 8; ++i) {
        m_clients[i] = nullptr;
    }

    qDebug() << "✅ [MQTTController] Qt MQTT 已启用";
#else
    qWarning() << "⚠️ [MQTTController] Qt MQTT 未启用，MQTT 功能不可用";
#endif
}

MQTTController::~MQTTController()
{
    qDebug() << "✅ [MQTTController] 销毁 MQTT 控制器";
    disconnectAll();

#ifdef MQTT_ENABLED
    for (int i = 0; i < m_clients.size(); ++i) {
        if (m_clients[i]) {
            delete m_clients[i];
            m_clients[i] = nullptr;
        }
    }
#endif
}

void MQTTController::initializeModules()
{
    m_configs.resize(8);

    for (int i = 0; i < 8; ++i) {
        m_configs[i].name = QString("模块%1").arg(i + 1);
        m_configs[i].brokerHost = "192.168.10.142";  // ✅ 2026-02-09 [Phase 7.44.14]: EMQX在开发电脑的Docker中
        m_configs[i].brokerPort = 1883;
        m_configs[i].clientId = QString("belt_control_module_%1").arg(i + 1);
        m_configs[i].keepAlive = 60;
        m_configs[i].cleanSession = true;
        m_configs[i].defaultQos = 1;

        // 默认订阅主题
        m_configs[i].subscribeTopics << QString("belt_control/module%1/status").arg(i + 1);

        // 默认发布主题
        m_configs[i].publishTopics << QString("belt_control/module%1/control").arg(i + 1);
    }

    qDebug() << "✅ [MQTTController] 初始化 8 个模块配置完成";
}

QVariantList MQTTController::modules() const
{
    QVariantList list;
    for (int i = 0; i < m_configs.size(); ++i) {
        QVariantMap module;
        module["index"] = i;
        module["name"] = m_configs[i].name;
        module["brokerHost"] = m_configs[i].brokerHost;
        module["brokerPort"] = m_configs[i].brokerPort;
        module["connected"] = isModuleConnected(i);
        module["connectionState"] = getModuleConnectionState(i);
        list.append(module);
    }
    return list;
}

void MQTTController::setCurrentModuleIndex(int index)
{
    if (index < 0 || index >= 8) {
        qWarning() << "⚠️ [MQTTController] 无效的模块索引:" << index;
        return;
    }

    if (m_currentModuleIndex != index) {
        m_currentModuleIndex = index;
        qDebug() << "✅ [MQTTController] 切换到模块:" << index << m_configs[index].name;
        emit currentModuleIndexChanged();
        emit connectionStateChanged();
        emit brokerHostChanged();
        emit brokerPortChanged();
        emit clientIdChanged();
        emit usernameChanged();
        emit passwordChanged();
        emit keepAliveChanged();
        emit cleanSessionChanged();
        emit defaultQosChanged();
        emit subscriptionsChanged();
    }
}

int MQTTController::getValidModuleIndex(int moduleIndex) const
{
    if (moduleIndex < 0 || moduleIndex >= 8) {
        return m_currentModuleIndex;
    }
    return moduleIndex;
}

// ========== 连接状态 ==========

bool MQTTController::isConnected() const
{
    return isModuleConnected(m_currentModuleIndex);
}

bool MQTTController::isModuleConnected(int moduleIndex) const
{
#ifdef MQTT_ENABLED
    int idx = getValidModuleIndex(moduleIndex);
    if (idx >= 0 && idx < m_clients.size() && m_clients[idx]) {
        return m_clients[idx]->state() == QMqttClient::Connected;
    }
#else
    Q_UNUSED(moduleIndex)
#endif
    return false;
}

QString MQTTController::connectionState() const
{
    return getModuleConnectionState(m_currentModuleIndex);
}

QString MQTTController::getModuleConnectionState(int moduleIndex) const
{
#ifdef MQTT_ENABLED
    int idx = getValidModuleIndex(moduleIndex);
    if (idx >= 0 && idx < m_clients.size() && m_clients[idx]) {
        switch (m_clients[idx]->state()) {
        case QMqttClient::Disconnected:
            return "未连接";
        case QMqttClient::Connecting:
            return "连接中...";
        case QMqttClient::Connected:
            return "已连接";
        }
    }
#else
    Q_UNUSED(moduleIndex)
#endif
    return "未连接";
}

QVariantList MQTTController::subscriptions() const
{
    QVariantList list;
#ifdef MQTT_ENABLED
    int idx = m_currentModuleIndex;
    if (idx >= 0 && idx < m_subscriptions.size()) {
        for (auto it = m_subscriptions[idx].constBegin();
             it != m_subscriptions[idx].constEnd(); ++it) {
            QVariantMap sub;
            sub["topic"] = it.key();
            sub["qos"] = it.value() ? it.value()->qos() : 0;
            list.append(sub);
        }
    }
#endif
    return list;
}

// ========== 当前模块配置访问器 ==========

QString MQTTController::brokerHost() const
{
    return m_configs[m_currentModuleIndex].brokerHost;
}

void MQTTController::setBrokerHost(const QString &host)
{
    if (m_configs[m_currentModuleIndex].brokerHost != host) {
        m_configs[m_currentModuleIndex].brokerHost = host;
        emit brokerHostChanged();
    }
}

int MQTTController::brokerPort() const
{
    return m_configs[m_currentModuleIndex].brokerPort;
}

void MQTTController::setBrokerPort(int port)
{
    if (m_configs[m_currentModuleIndex].brokerPort != port) {
        m_configs[m_currentModuleIndex].brokerPort = port;
        emit brokerPortChanged();
    }
}

QString MQTTController::clientId() const
{
    return m_configs[m_currentModuleIndex].clientId;
}

void MQTTController::setClientId(const QString &id)
{
    if (m_configs[m_currentModuleIndex].clientId != id) {
        m_configs[m_currentModuleIndex].clientId = id;
        emit clientIdChanged();
    }
}

QString MQTTController::username() const
{
    return m_configs[m_currentModuleIndex].username;
}

void MQTTController::setUsername(const QString &user)
{
    if (m_configs[m_currentModuleIndex].username != user) {
        m_configs[m_currentModuleIndex].username = user;
        emit usernameChanged();
    }
}

QString MQTTController::password() const
{
    return m_configs[m_currentModuleIndex].password;
}

void MQTTController::setPassword(const QString &pass)
{
    if (m_configs[m_currentModuleIndex].password != pass) {
        m_configs[m_currentModuleIndex].password = pass;
        emit passwordChanged();
    }
}

int MQTTController::keepAlive() const
{
    return m_configs[m_currentModuleIndex].keepAlive;
}

void MQTTController::setKeepAlive(int seconds)
{
    if (m_configs[m_currentModuleIndex].keepAlive != seconds) {
        m_configs[m_currentModuleIndex].keepAlive = seconds;
        emit keepAliveChanged();
    }
}

bool MQTTController::cleanSession() const
{
    return m_configs[m_currentModuleIndex].cleanSession;
}

void MQTTController::setCleanSession(bool clean)
{
    if (m_configs[m_currentModuleIndex].cleanSession != clean) {
        m_configs[m_currentModuleIndex].cleanSession = clean;
        emit cleanSessionChanged();
    }
}

int MQTTController::defaultQos() const
{
    return m_configs[m_currentModuleIndex].defaultQos;
}

void MQTTController::setDefaultQos(int qos)
{
    if (qos < 0 || qos > 2) {
        qWarning() << "⚠️ [MQTTController] 无效的 QoS 值:" << qos;
        return;
    }
    if (m_configs[m_currentModuleIndex].defaultQos != qos) {
        m_configs[m_currentModuleIndex].defaultQos = qos;
        emit defaultQosChanged();
    }
}

// ========== 连接管理 ==========

#ifdef MQTT_ENABLED
void MQTTController::createClient(int moduleIndex)
{
    if (moduleIndex < 0 || moduleIndex >= 8) return;

    if (m_clients[moduleIndex]) {
        // 已存在，先断开
        m_clients[moduleIndex]->disconnectFromHost();
        delete m_clients[moduleIndex];
    }

    m_clients[moduleIndex] = new QMqttClient(this);
    connectClientSignals(moduleIndex);

    qDebug() << "✅ [MQTTController] 创建客户端:" << moduleIndex;
}

void MQTTController::connectClientSignals(int moduleIndex)
{
    if (moduleIndex < 0 || moduleIndex >= m_clients.size()) return;

    QMqttClient *client = m_clients[moduleIndex];
    if (!client) return;

    // 使用 lambda 捕获模块索引
    connect(client, &QMqttClient::connected, this, [this, moduleIndex]() {
        // ✅ 2026-02-13 [Phase 7.45.33 修复]: 移除日志，状态变化在 MQTTAutoManager 中输出
        emit connectedChanged(moduleIndex, true);
        if (moduleIndex == m_currentModuleIndex) {
            emit connectionStateChanged();
        }
        emit modulesChanged();
    });

    connect(client, &QMqttClient::disconnected, this, [this, moduleIndex]() {
        // ✅ 2026-02-13 [Phase 7.45.33 修复]: 移除日志，状态变化在 MQTTAutoManager 中输出
        emit connectedChanged(moduleIndex, false);
        if (moduleIndex == m_currentModuleIndex) {
            emit connectionStateChanged();
        }
        emit modulesChanged();
    });

    connect(client, &QMqttClient::stateChanged, this, [this, moduleIndex](QMqttClient::ClientState state) {
        Q_UNUSED(state)
        if (moduleIndex == m_currentModuleIndex) {
            emit connectionStateChanged();
        }
    });

    connect(client, &QMqttClient::errorChanged, this, [this, moduleIndex](QMqttClient::ClientError error) {
        // ✅ 2026-02-13 [Phase 7.45.34]: 只在错误状态变化时输出日志
        if (error == m_lastErrors[moduleIndex]) {
            return;  // 错误状态未变化，不输出日志
        }
        m_lastErrors[moduleIndex] = error;

        QString errorStr;
        switch (error) {
        case QMqttClient::NoError:
            return;
        case QMqttClient::InvalidProtocolVersion:
            errorStr = "无效的协议版本";
            break;
        case QMqttClient::IdRejected:
            errorStr = "客户端 ID 被拒绝";
            break;
        case QMqttClient::ServerUnavailable:
            errorStr = "服务器不可用";
            break;
        case QMqttClient::BadUsernameOrPassword:
            errorStr = "用户名或密码错误";
            break;
        case QMqttClient::NotAuthorized:
            errorStr = "未授权";
            break;
        case QMqttClient::TransportInvalid:
            errorStr = "传输层无效";
            break;
        case QMqttClient::ProtocolViolation:
            errorStr = "协议违规";
            break;
        case QMqttClient::UnknownError:
        default:
            errorStr = "未知错误";
            break;
        }

        m_lastError = QString("模块%1: %2").arg(moduleIndex + 1).arg(errorStr);
        qWarning() << "⚠️ [MQTTController]" << m_lastError;
        emit lastErrorChanged();
    });

    connect(client, &QMqttClient::messageReceived, this,
            [this, moduleIndex](const QByteArray &message, const QMqttTopicName &topic) {
        qDebug() << "✅ [MQTTController] 模块" << moduleIndex
                 << "收到消息 - 主题:" << topic.name()
                 << "内容:" << message.left(100);
        addReceivedMessage(moduleIndex, topic.name(), message);
        emit messageReceived(moduleIndex, topic.name(), message);
    });
}
#endif

bool MQTTController::connectToModule(int moduleIndex)
{
#ifdef MQTT_ENABLED
    int idx = getValidModuleIndex(moduleIndex);

    // ✅ 2026-02-13 [Phase 7.45.33 修复]: 移除状态检查日志
    // 原因：connectToHost() 会改变状态，导致每次调用都输出日志
    // 状态变化会通过 QMqttClient 的信号触发，在信号处理中输出更合适

    // 创建客户端（如果不存在）
    QMqttClient *client = m_clients[idx];
    if (!client) {
        qDebug() << "✅ [MQTTController] 创建客户端:" << idx;
        createClient(idx);
        client = m_clients[idx];
    }

    if (!client) {
        m_lastError = "创建客户端失败";
        emit lastErrorChanged();
        return false;
    }

    // 配置客户端
    const MQTTModuleConfig &config = m_configs[idx];
    client->setHostname(config.brokerHost);
    client->setPort(config.brokerPort);
    client->setClientId(config.clientId);
    client->setKeepAlive(config.keepAlive);
    client->setCleanSession(config.cleanSession);

    if (!config.username.isEmpty()) {
        client->setUsername(config.username);
        client->setPassword(config.password);
    }

    // 连接
    client->connectToHost();
    return true;
#else
    Q_UNUSED(moduleIndex)
    m_lastError = "MQTT 功能未启用";
    emit lastErrorChanged();
    return false;
#endif
}

void MQTTController::disconnectFromModule(int moduleIndex)
{
#ifdef MQTT_ENABLED
    int idx = getValidModuleIndex(moduleIndex);

    // ✅ 2026-02-13 [Phase 7.45.33 修复]: 移除状态检查日志
    // 原因：状态变化会通过 QMqttClient 的信号触发，在 MQTTAutoManager 中输出

    if (idx >= 0 && idx < m_clients.size() && m_clients[idx]) {
        m_clients[idx]->disconnectFromHost();
    }
#else
    Q_UNUSED(moduleIndex)
#endif
}

void MQTTController::disconnectAll()
{
#ifdef MQTT_ENABLED
    qDebug() << "✅ [MQTTController] 断开所有模块";
    for (int i = 0; i < m_clients.size(); ++i) {
        if (m_clients[i] && m_clients[i]->state() != QMqttClient::Disconnected) {
            m_clients[i]->disconnectFromHost();
        }
    }
#endif
}

// ========== 订阅管理 ==========

bool MQTTController::subscribe(const QString &topic, int qos, int moduleIndex)
{
#ifdef MQTT_ENABLED
    int idx = getValidModuleIndex(moduleIndex);

    if (idx < 0 || idx >= m_clients.size() || !m_clients[idx]) {
        m_lastError = "客户端未初始化";
        emit lastErrorChanged();
        return false;
    }

    if (m_clients[idx]->state() != QMqttClient::Connected) {
        m_lastError = "未连接到 Broker";
        emit lastErrorChanged();
        return false;
    }

    qDebug() << "✅ [MQTTController] 模块" << idx << "订阅主题:" << topic << "QoS:" << qos;

    QMqttSubscription *sub = m_clients[idx]->subscribe(topic, qos);
    if (sub) {
        m_subscriptions[idx][topic] = sub;
        emit subscriptionsChanged();
        return true;
    }

    m_lastError = "订阅失败";
    emit lastErrorChanged();
    return false;
#else
    Q_UNUSED(topic)
    Q_UNUSED(qos)
    Q_UNUSED(moduleIndex)
    m_lastError = "MQTT 功能未启用";
    emit lastErrorChanged();
    return false;
#endif
}

void MQTTController::unsubscribe(const QString &topic, int moduleIndex)
{
#ifdef MQTT_ENABLED
    int idx = getValidModuleIndex(moduleIndex);

    if (idx >= 0 && idx < m_clients.size() && m_clients[idx]) {
        qDebug() << "✅ [MQTTController] 模块" << idx << "取消订阅:" << topic;
        m_clients[idx]->unsubscribe(topic);
        m_subscriptions[idx].remove(topic);
        emit subscriptionsChanged();
    }
#else
    Q_UNUSED(topic)
    Q_UNUSED(moduleIndex)
#endif
}

QStringList MQTTController::getSubscribedTopics(int moduleIndex) const
{
#ifdef MQTT_ENABLED
    int idx = getValidModuleIndex(moduleIndex);
    if (idx >= 0 && idx < m_subscriptions.size()) {
        return m_subscriptions[idx].keys();
    }
#else
    Q_UNUSED(moduleIndex)
#endif
    return QStringList();
}

// ========== 发布消息 ==========

bool MQTTController::publish(const QString &topic, const QString &message,
                             int qos, bool retain, int moduleIndex)
{
    return publishBytes(topic, message.toUtf8(), qos, retain, moduleIndex);
}

bool MQTTController::publishBytes(const QString &topic, const QByteArray &data,
                                  int qos, bool retain, int moduleIndex)
{
#ifdef MQTT_ENABLED
    int idx = getValidModuleIndex(moduleIndex);

    if (idx < 0 || idx >= m_clients.size() || !m_clients[idx]) {
        m_lastError = "客户端未初始化";
        emit lastErrorChanged();
        return false;
    }

    if (m_clients[idx]->state() != QMqttClient::Connected) {
        m_lastError = "未连接到 Broker";
        emit lastErrorChanged();
        return false;
    }

    qDebug() << "✅ [MQTTController] 模块" << idx << "发布消息 - 主题:" << topic
             << "QoS:" << qos << "Retain:" << retain << "长度:" << data.size();

    qint32 result = m_clients[idx]->publish(topic, data, qos, retain);
    return result != -1;
#else
    Q_UNUSED(topic)
    Q_UNUSED(data)
    Q_UNUSED(qos)
    Q_UNUSED(retain)
    Q_UNUSED(moduleIndex)
    m_lastError = "MQTT 功能未启用";
    emit lastErrorChanged();
    return false;
#endif
}

// ========== 配置管理 ==========

void MQTTController::saveModuleConfig(int moduleIndex)
{
    int idx = getValidModuleIndex(moduleIndex);
    qDebug() << "✅ [MQTTController] 保存模块配置:" << idx;

    QSettings settings("BeltControl", "MQTT");
    settings.beginGroup(QString("Module%1").arg(idx));

    const MQTTModuleConfig &config = m_configs[idx];
    settings.setValue("name", config.name);
    settings.setValue("brokerHost", config.brokerHost);
    settings.setValue("brokerPort", config.brokerPort);
    settings.setValue("clientId", config.clientId);
    settings.setValue("username", config.username);
    settings.setValue("password", config.password);  // 注意：实际应用中应加密
    settings.setValue("keepAlive", config.keepAlive);
    settings.setValue("cleanSession", config.cleanSession);
    settings.setValue("defaultQos", config.defaultQos);
    settings.setValue("subscribeTopics", config.subscribeTopics);
    settings.setValue("publishTopics", config.publishTopics);

    settings.endGroup();
}

void MQTTController::loadModuleConfig(int moduleIndex)
{
    int idx = getValidModuleIndex(moduleIndex);
    qDebug() << "✅ [MQTTController] 加载模块配置:" << idx;

    QSettings settings("BeltControl", "MQTT");
    settings.beginGroup(QString("Module%1").arg(idx));

    MQTTModuleConfig &config = m_configs[idx];

    if (settings.contains("name")) {
        config.name = settings.value("name").toString();
        config.brokerHost = settings.value("brokerHost", "192.168.10.142").toString();  // ✅ 2026-02-09 [Phase 7.44.14]: EMQX在开发电脑的Docker中
        config.brokerPort = settings.value("brokerPort", 1883).toInt();
        config.clientId = settings.value("clientId").toString();
        config.username = settings.value("username").toString();
        config.password = settings.value("password").toString();
        config.keepAlive = settings.value("keepAlive", 60).toInt();
        config.cleanSession = settings.value("cleanSession", true).toBool();
        config.defaultQos = settings.value("defaultQos", 1).toInt();
        config.subscribeTopics = settings.value("subscribeTopics").toStringList();
        config.publishTopics = settings.value("publishTopics").toStringList();
    }

    settings.endGroup();

    // 通知属性变化
    if (idx == m_currentModuleIndex) {
        emit brokerHostChanged();
        emit brokerPortChanged();
        emit clientIdChanged();
        emit usernameChanged();
        emit passwordChanged();
        emit keepAliveChanged();
        emit cleanSessionChanged();
        emit defaultQosChanged();
    }
}

void MQTTController::resetModuleConfig(int moduleIndex)
{
    int idx = getValidModuleIndex(moduleIndex);
    qDebug() << "✅ [MQTTController] 重置模块配置:" << idx;

    MQTTModuleConfig &config = m_configs[idx];
    config.name = QString("模块%1").arg(idx + 1);
    config.brokerHost = "192.168.10.142";  // ✅ 2026-02-09 [Phase 7.44.14]: EMQX在开发电脑的Docker中
    config.brokerPort = 1883;
    config.clientId = QString("belt_control_module_%1").arg(idx + 1);
    config.username.clear();
    config.password.clear();
    config.keepAlive = 60;
    config.cleanSession = true;
    config.defaultQos = 1;
    config.subscribeTopics.clear();
    config.subscribeTopics << QString("belt_control/module%1/status").arg(idx + 1);
    config.publishTopics.clear();
    config.publishTopics << QString("belt_control/module%1/control").arg(idx + 1);

    // 通知属性变化
    if (idx == m_currentModuleIndex) {
        emit brokerHostChanged();
        emit brokerPortChanged();
        emit clientIdChanged();
        emit usernameChanged();
        emit passwordChanged();
        emit keepAliveChanged();
        emit cleanSessionChanged();
        emit defaultQosChanged();
    }

    emit modulesChanged();
}

void MQTTController::saveAllConfigs()
{
    qDebug() << "✅ [MQTTController] 保存所有模块配置";
    for (int i = 0; i < 8; ++i) {
        saveModuleConfig(i);
    }
}

void MQTTController::loadAllConfigs()
{
    qDebug() << "✅ [MQTTController] 加载所有模块配置";
    for (int i = 0; i < 8; ++i) {
        loadModuleConfig(i);
    }
    emit modulesChanged();
}

// ========== 消息管理 ==========

void MQTTController::clearReceivedMessages()
{
    m_receivedMessages.clear();
    emit receivedMessagesChanged();
}

void MQTTController::addReceivedMessage(int moduleIndex, const QString &topic, const QByteArray &payload)
{
    QVariantMap msg;
    msg["moduleIndex"] = moduleIndex;
    msg["moduleName"] = m_configs[moduleIndex].name;
    msg["topic"] = topic;
    msg["payload"] = QString::fromUtf8(payload);
    msg["timestamp"] = QDateTime::currentDateTime().toString("yyyy-MM-dd hh:mm:ss.zzz");
    msg["size"] = payload.size();

    m_receivedMessages.prepend(msg);

    // 限制消息数量
    while (m_receivedMessages.size() > m_maxReceivedMessages) {
        m_receivedMessages.removeLast();
    }

    emit receivedMessagesChanged();
}

QVariantMap MQTTController::getModuleInfo(int moduleIndex) const
{
    int idx = getValidModuleIndex(moduleIndex);
    QVariantMap info;

    if (idx >= 0 && idx < m_configs.size()) {
        const MQTTModuleConfig &config = m_configs[idx];
        info["index"] = idx;
        info["name"] = config.name;
        info["brokerHost"] = config.brokerHost;
        info["brokerPort"] = config.brokerPort;
        info["clientId"] = config.clientId;
        info["username"] = config.username;
        info["keepAlive"] = config.keepAlive;
        info["cleanSession"] = config.cleanSession;
        info["defaultQos"] = config.defaultQos;
        info["connected"] = isModuleConnected(idx);
        info["connectionState"] = getModuleConnectionState(idx);
        info["subscribeTopics"] = config.subscribeTopics;
        info["publishTopics"] = config.publishTopics;
    }

    return info;
}
