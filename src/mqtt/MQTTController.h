/**
 * @file MQTTController.h
 * @brief MQTT 通讯控制器
 * @date 2026-02-08
 * @phase 7.43
 *
 * 功能：
 * - 管理 8 个 MQTT 模块的独立连接
 * - 支持订阅和发布主题
 * - 支持 QoS 0/1/2
 * - 支持用户名/密码认证
 * - 暴露给 QML 使用
 */

#ifndef MQTTCONTROLLER_H
#define MQTTCONTROLLER_H

#include <QObject>
#include <QVector>
#include <QVariantList>
#include <QVariantMap>
#include <QString>
#include <QByteArray>
#include <QTimer>

#ifdef MQTT_ENABLED
#include <QtMqtt/QMqttClient>
#include <QtMqtt/QMqttSubscription>
#include <QtMqtt/QMqttMessage>
#endif

/**
 * @brief MQTT 模块配置结构
 */
struct MQTTModuleConfig
{
    QString name;           // 模块名称（模块1-模块8）
    QString brokerHost;     // Broker 地址
    int brokerPort;         // Broker 端口（默认 1883）
    QString clientId;       // 客户端 ID
    QString username;       // 用户名
    QString password;       // 密码
    int keepAlive;          // 心跳间隔（秒）
    bool cleanSession;      // 清除会话
    int defaultQos;         // 默认 QoS

    // 订阅主题列表
    QStringList subscribeTopics;

    // 发布主题列表
    QStringList publishTopics;

    MQTTModuleConfig()
        : brokerPort(1883)
        , keepAlive(60)
        , cleanSession(true)
        , defaultQos(1)
    {}
};

/**
 * @brief MQTT 通讯控制器
 *
 * 管理 8 个 MQTT 客户端实例，提供连接、订阅、发布功能
 */
class MQTTController : public QObject
{
    Q_OBJECT

    // ========== 模块配置属性 ==========
    Q_PROPERTY(QVariantList modules READ modules NOTIFY modulesChanged)
    Q_PROPERTY(int currentModuleIndex READ currentModuleIndex
               WRITE setCurrentModuleIndex NOTIFY currentModuleIndexChanged)
    Q_PROPERTY(int moduleCount READ moduleCount CONSTANT)

    // ========== 当前模块状态 ==========
    Q_PROPERTY(bool connected READ isConnected NOTIFY connectedChanged)
    Q_PROPERTY(QString connectionState READ connectionState NOTIFY connectionStateChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(QVariantList receivedMessages READ receivedMessages NOTIFY receivedMessagesChanged)
    Q_PROPERTY(QVariantList subscriptions READ subscriptions NOTIFY subscriptionsChanged)

    // ========== 当前模块配置 ==========
    Q_PROPERTY(QString brokerHost READ brokerHost WRITE setBrokerHost NOTIFY brokerHostChanged)
    Q_PROPERTY(int brokerPort READ brokerPort WRITE setBrokerPort NOTIFY brokerPortChanged)
    Q_PROPERTY(QString clientId READ clientId WRITE setClientId NOTIFY clientIdChanged)
    Q_PROPERTY(QString username READ username WRITE setUsername NOTIFY usernameChanged)
    Q_PROPERTY(QString password READ password WRITE setPassword NOTIFY passwordChanged)
    Q_PROPERTY(int keepAlive READ keepAlive WRITE setKeepAlive NOTIFY keepAliveChanged)
    Q_PROPERTY(bool cleanSession READ cleanSession WRITE setCleanSession NOTIFY cleanSessionChanged)
    Q_PROPERTY(int defaultQos READ defaultQos WRITE setDefaultQos NOTIFY defaultQosChanged)

public:
    explicit MQTTController(QObject *parent = nullptr);
    ~MQTTController();

    // ========== 模块管理 ==========
    QVariantList modules() const;
    int currentModuleIndex() const { return m_currentModuleIndex; }
    void setCurrentModuleIndex(int index);
    int moduleCount() const { return 8; }

    // ========== 连接状态 ==========
    bool isConnected() const;
    QString connectionState() const;
    QString lastError() const { return m_lastError; }
    QVariantList receivedMessages() const { return m_receivedMessages; }
    QVariantList subscriptions() const;

    // ========== 当前模块配置访问器 ==========
    QString brokerHost() const;
    void setBrokerHost(const QString &host);
    int brokerPort() const;
    void setBrokerPort(int port);
    QString clientId() const;
    void setClientId(const QString &id);
    QString username() const;
    void setUsername(const QString &user);
    QString password() const;
    void setPassword(const QString &pass);
    int keepAlive() const;
    void setKeepAlive(int seconds);
    bool cleanSession() const;
    void setCleanSession(bool clean);
    int defaultQos() const;
    void setDefaultQos(int qos);

    // ========== 连接管理（Q_INVOKABLE）==========
    Q_INVOKABLE bool connectToModule(int moduleIndex = -1);
    Q_INVOKABLE void disconnectFromModule(int moduleIndex = -1);
    Q_INVOKABLE void disconnectAll();
    Q_INVOKABLE bool isModuleConnected(int moduleIndex) const;
    Q_INVOKABLE QString getModuleConnectionState(int moduleIndex) const;

    // ========== 订阅管理（Q_INVOKABLE）==========
    Q_INVOKABLE bool subscribe(const QString &topic, int qos = 1, int moduleIndex = -1);
    Q_INVOKABLE void unsubscribe(const QString &topic, int moduleIndex = -1);
    Q_INVOKABLE QStringList getSubscribedTopics(int moduleIndex = -1) const;

    // ========== 发布消息（Q_INVOKABLE）==========
    Q_INVOKABLE bool publish(const QString &topic, const QString &message,
                             int qos = 1, bool retain = false, int moduleIndex = -1);
    Q_INVOKABLE bool publishBytes(const QString &topic, const QByteArray &data,
                                  int qos = 1, bool retain = false, int moduleIndex = -1);

    // ========== 配置管理（Q_INVOKABLE）==========
    Q_INVOKABLE void saveModuleConfig(int moduleIndex = -1);
    Q_INVOKABLE void loadModuleConfig(int moduleIndex = -1);
    Q_INVOKABLE void resetModuleConfig(int moduleIndex = -1);
    Q_INVOKABLE void saveAllConfigs();
    Q_INVOKABLE void loadAllConfigs();

    // ========== 消息管理（Q_INVOKABLE）==========
    Q_INVOKABLE void clearReceivedMessages();
    Q_INVOKABLE QVariantMap getModuleInfo(int moduleIndex) const;

signals:
    // 模块变化信号
    void modulesChanged();
    void currentModuleIndexChanged();

    // 连接状态信号
    void connectedChanged(int moduleIndex, bool connected);
    void connectionStateChanged();
    void lastErrorChanged();

    // 消息信号
    void receivedMessagesChanged();
    void messageReceived(int moduleIndex, const QString &topic, const QByteArray &payload);
    void subscriptionsChanged();

    // 配置变化信号
    void brokerHostChanged();
    void brokerPortChanged();
    void clientIdChanged();
    void usernameChanged();
    void passwordChanged();
    void keepAliveChanged();
    void cleanSessionChanged();
    void defaultQosChanged();

// ✅ 2026-02-08 [Phase 7.43.15]: 移除未使用的槽函数声明
// 信号连接使用lambda表达式实现，不需要单独的槽函数

private:
    // 获取有效的模块索引
    int getValidModuleIndex(int moduleIndex) const;

    // 初始化模块配置
    void initializeModules();

    // 创建 MQTT 客户端
    void createClient(int moduleIndex);

    // 连接信号槽
    void connectClientSignals(int moduleIndex);

    // 更新连接状态字符串
    void updateConnectionState(int moduleIndex);

    // 添加接收消息到列表
    void addReceivedMessage(int moduleIndex, const QString &topic, const QByteArray &payload);

private:
    int m_currentModuleIndex;
    QString m_lastError;
    QVariantList m_receivedMessages;
    int m_maxReceivedMessages;

    // 8 个模块的配置
    QVector<MQTTModuleConfig> m_configs;

#ifdef MQTT_ENABLED
    // 8 个 MQTT 客户端实例
    QVector<QMqttClient*> m_clients;

    // 订阅管理
    QVector<QMap<QString, QMqttSubscription*>> m_subscriptions;

    // ✅ 2026-02-13 [Phase 7.45.33 修复]: 移除 m_lastStates
    // 原因：connectToHost() 会改变状态，导致状态跟踪失效
    // 状态变化通过信号在 MQTTAutoManager 中处理更合适
#endif
};

#endif // MQTTCONTROLLER_H
