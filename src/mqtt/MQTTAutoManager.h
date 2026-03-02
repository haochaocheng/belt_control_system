/**
 * @file MQTTAutoManager.h
 * @brief MQTT 自动管理器 - 管理8个模块的自动连接、数据采集和监控
 * @date 2026-02-09
 * @phase 7.44.1
 *
 * 功能：
 * - 自动连接和断线重连
 * - 周期性数据采集
 * - 数据解析和分发
 * - 模块健康监控
 */

#ifndef MQTTAUTOMANAGER_H
#define MQTTAUTOMANAGER_H

#include <QObject>
#include <QTimer>
#include <QVector>
#include <QVariantMap>
#include <QDateTime>

// 前向声明
class MQTTController;

/**
 * @brief 模块健康状态
 */
struct ModuleHealthStatus
{
    bool connected;              // 连接状态
    qint64 lastDataTime;         // 最后数据时间（秒）
    int dataTimeoutCount;        // 数据超时次数
    int reconnectCount;          // 重连次数
    QString status;              // 状态描述

    ModuleHealthStatus()
        : connected(false)
        , lastDataTime(0)
        , dataTimeoutCount(0)
        , reconnectCount(0)
        , status("未连接")
    {}
};

/**
 * @brief MQTT 自动管理器
 *
 * 管理8个MQTT模块的自动化操作：
 * - 启动时自动连接前4个模块（开关量×2 + 模拟量×2）
 * - 断线自动重连（5秒检查周期）
 * - 周期性数据采集（开关量100ms，模拟量500ms）
 * - 健康状态监控
 */
class MQTTAutoManager : public QObject
{
    Q_OBJECT

    // ========== 属性 ==========
    Q_PROPERTY(bool autoConnectEnabled READ autoConnectEnabled
               WRITE setAutoConnectEnabled NOTIFY autoConnectEnabledChanged)
    Q_PROPERTY(bool pollingEnabled READ pollingEnabled
               WRITE setPollingEnabled NOTIFY pollingEnabledChanged)
    Q_PROPERTY(int diPollingInterval READ diPollingInterval
               WRITE setDIPollingInterval NOTIFY diPollingIntervalChanged)
    Q_PROPERTY(int aiPollingInterval READ aiPollingInterval
               WRITE setAIPollingInterval NOTIFY aiPollingIntervalChanged)
    Q_PROPERTY(QVariantList healthStatus READ healthStatus NOTIFY healthStatusChanged)

public:
    explicit MQTTAutoManager(MQTTController *mqttController, QObject *parent = nullptr);
    ~MQTTAutoManager();

    // ========== 属性访问器 ==========
    bool autoConnectEnabled() const { return m_autoConnectEnabled; }
    void setAutoConnectEnabled(bool enabled);

    bool pollingEnabled() const { return m_pollingEnabled; }
    void setPollingEnabled(bool enabled);

    int diPollingInterval() const { return m_diPollingInterval; }
    void setDIPollingInterval(int interval);

    int aiPollingInterval() const { return m_aiPollingInterval; }
    void setAIPollingInterval(int interval);

    QVariantList healthStatus() const;

    // ========== 公共方法 ==========
    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void connectAllModules();
    Q_INVOKABLE void disconnectAllModules();
    Q_INVOKABLE void reconnectModule(int moduleIndex);
    Q_INVOKABLE QVariantMap getModuleHealth(int moduleIndex) const;

signals:
    // 属性变化信号
    void autoConnectEnabledChanged();
    void pollingEnabledChanged();
    void diPollingIntervalChanged();
    void aiPollingIntervalChanged();
    void healthStatusChanged();

    // 健康状态信号
    void moduleHealthWarning(int moduleIndex, const QString &message);
    void moduleHealthRecovered(int moduleIndex);

    // 数据信号（转发给数据管理器）
    void moduleDataReceived(int moduleIndex, const QString &topic, const QByteArray &payload);

private slots:
    // 定时器槽函数
    void onReconnectTimerTimeout();
    void onDIPollingTimerTimeout();
    void onAIPollingTimerTimeout();
    void onHealthCheckTimerTimeout();

    // MQTT 控制器信号槽
    void onModuleConnected(int moduleIndex, bool connected);
    void onModuleMessageReceived(int moduleIndex, const QString &topic, const QByteArray &payload);

private:
    // 初始化
    void initializeTimers();
    void initializeHealthStatus();

    // 连接管理
    void connectModule(int moduleIndex);
    void startReconnectTimer();
    void stopReconnectTimer();

    // 数据采集
    void startPolling();
    void stopPolling();
    void pollDIModules();
    void pollAIModules();

    // 健康监控
    void startHealthCheck();
    void stopHealthCheck();
    void checkModuleHealth(int moduleIndex);
    void updateLastDataTime(int moduleIndex);

private:
    MQTTController *m_mqttController;

    // 配置
    bool m_autoConnectEnabled;
    bool m_pollingEnabled;
    int m_diPollingInterval;    // 开关量采集间隔（毫秒）
    int m_aiPollingInterval;    // 模拟量采集间隔（毫秒）

    // 定时器
    QTimer *m_reconnectTimer;   // 重连检查定时器（5秒）
    QTimer *m_diPollingTimer;   // 开关量采集定时器（100ms）
    QTimer *m_aiPollingTimer;   // 模拟量采集定时器（500ms）
    QTimer *m_healthCheckTimer; // 健康检查定时器（1秒）

    // 健康状态
    QVector<ModuleHealthStatus> m_healthStatus;  // 8个模块的健康状态

    // ✅ 2026-02-12 [Phase 7.45.33]: 添加连接状态跟踪，避免重复输出调试信息
    QVector<bool> m_lastConnectedStates;  // 记录每个模块的上次连接状态

    // ✅ 2026-03-01 [Phase 7.47.64]: 健康检查日志计数器（每10次输出一次详细状态）
    QVector<int> m_healthCheckLogCounter;  // 每个模块独立计数

    // 常量
    static const int RECONNECT_CHECK_INTERVAL = 5000;  // 5秒
    static const int HEALTH_CHECK_INTERVAL = 1000;     // 1秒
    static const int DATA_TIMEOUT_THRESHOLD = 5;       // 5秒无数据视为超时
    static const int MAX_TIMEOUT_COUNT = 3;            // 最大超时次数
};

#endif // MQTTAUTOMANAGER_H
