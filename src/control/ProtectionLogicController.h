#ifndef PROTECTIONLOGICCONTROLLER_H
#define PROTECTIONLOGICCONTROLLER_H

#include <QObject>
#include <QMap>
#include <QDateTime>
#include <QVariantList>

// 前向声明
class CommonControl;
class DeviceConfigManager;
class DeviceRoleManager;
class DeviceRuntimeTracker;
class MqttProtectionMonitor;

/**
 * @file ProtectionLogicController.h
 * @brief 保护逻辑控制器 — 将保护触发与皮带停车控制关联
 * @date 2026-03-23
 * @phase 7.48.85
 *
 * 功能：
 * - 接收各类保护触发信号（开关量、模拟量、电机、CS沿线、张紧等）
 * - 根据 protection_level 执行相应控制动作：
 *   - 0 = 紧急停车（跳过停车音频，直接停止序列）
 *   - 1 = 正常停车（播放停车音频 + 停止序列）
 *   - 2 = 仅预警（仅报警，不停车 — 由 AlarmPlaybackService 处理）
 *   - 3 = 不处理
 * - 防重复停车（同一皮带多个保护同时触发，只执行一次停车）
 * - 记录活跃保护状态（供QML显示）
 * - 支持主站通讯失败、主站紧急停车等外部停车源
 * - 预留4个未来扩展占位
 */
class ProtectionLogicController : public QObject
{
    Q_OBJECT

public:
    /**
     * @brief 停车源枚举 — 标识触发停车的来源
     */
    enum StopSource {
        Source_ManualKey = 0,          ///< R/S键手动控制
        Source_DigitalProtection = 1,  ///< 开关量保护（急停、跑偏、撕裂等）
        Source_AnalogProtection = 2,   ///< 模拟量保护（速度、张力、温度等）
        Source_MotorProtection = 3,    ///< 电机保护（电流、轴承温度、振动等）
        Source_CSProtection = 4,       ///< CS沿线点位保护（沿线急停/跑偏/撕裂）
        Source_TensionProtection = 5,  ///< 张紧控制保护（张力超限）
        Source_MasterCommLost = 6,     ///< 主站通讯失败（MQTT连接断开超时）
        Source_MasterEmergency = 7,    ///< 主站紧急停车命令（MQTT主题接收）
        Source_Reserved1 = 8,          ///< 预留停车源1
        Source_Reserved2 = 9,          ///< 预留停车源2
        Source_Reserved3 = 10,         ///< 预留停车源3
        Source_Reserved4 = 11          ///< 预留停车源4
    };
    Q_ENUM(StopSource)

    explicit ProtectionLogicController(QObject *parent = nullptr);
    ~ProtectionLogicController();

    void setCommonControl(CommonControl *ctrl);
    void setDeviceConfigManager(DeviceConfigManager *mgr);
    void setDeviceRoleManager(DeviceRoleManager *mgr);
    // ✅ 2026-03-23 [Phase 7.48.86]: 注入 DeviceRuntimeTracker
    // 原因：保护停车时需要设置故障状态，阻止R键直接重启
    void setDeviceRuntimeTracker(DeviceRuntimeTracker *tracker);
    // ✅ 2026-03-23 [Phase 7.48.86.1]: 注入 MqttProtectionMonitor
    // 原因：F键复位时需要清除速度保护报警状态
    void setMqttProtectionMonitor(MqttProtectionMonitor *monitor);

    /**
     * @brief 获取当前所有活跃的保护（供QML显示）
     * @return 活跃保护列表，每项包含 beltNumber, protectionName, protectionLevel, source, triggeredAt
     */
    Q_INVOKABLE QVariantList activeProtections() const;

    /**
     * @brief 手动复位所有保护状态
     * 说明：当保护条件已恢复正常后，手动清除所有活跃保护记录和停车标志
     */
    Q_INVOKABLE void resetAllProtections();

    /**
     * @brief 获取停车源名称（供日志和QML显示）
     */
    Q_INVOKABLE static QString stopSourceName(int source);

public slots:
    /**
     * @brief 保护触发入口（统一接口）
     * @param beltNumber 皮带编号（1-12）
     * @param protectionName 保护名称（如"急停"、"速度"、"电流"等）
     * @param protectionLevel 保护级别（0=紧急停车, 1=正常停车, 2=仅预警, 3=不处理）
     * @param source 停车源（StopSource枚举值，以int传递兼容信号槽）
     */
    void onProtectionTriggered(int beltNumber, const QString &protectionName,
                                int protectionLevel, int source);

    /**
     * @brief 保护恢复入口
     * @param beltNumber 皮带编号
     * @param protectionName 保护名称
     * @param source 停车源
     */
    void onProtectionRestored(int beltNumber, const QString &protectionName,
                               int source);

    /**
     * @brief 主站通讯状态变化
     * @param connected true=连接正常, false=连接断开
     * 说明：通讯失败时触发紧急停车（Source_MasterCommLost）
     */
    void onMasterCommStatusChanged(bool connected);

    /**
     * @brief 主站紧急停车命令
     * @param beltNumber 皮带编号（0=所有皮带）
     */
    void onMasterEmergencyStop(int beltNumber);

signals:
    /**
     * @brief 保护停车触发信号（供QML和日志使用）
     */
    void protectionStopTriggered(int beltNumber, const QString &protectionName,
                                  int protectionLevel, int source);

    /**
     * @brief 保护恢复信号
     */
    void protectionCleared(int beltNumber, const QString &protectionName);

    /**
     * @brief 状态消息（供QML显示）
     */
    void statusMessage(const QString &msg);

private:
    CommonControl *m_commonControl;
    DeviceConfigManager *m_deviceConfigMgr;
    DeviceRoleManager *m_deviceRoleManager;
    // ✅ 2026-03-23 [Phase 7.48.86]: 保护停车时设置故障状态
    DeviceRuntimeTracker *m_runtimeTracker;
    // ✅ 2026-03-23 [Phase 7.48.86.1]: F键复位时清除速度保护报警
    MqttProtectionMonitor *m_mqttProtectionMonitor;

    /**
     * @brief 活跃保护记录
     */
    struct ActiveProtection {
        int beltNumber;
        QString protectionName;
        int protectionLevel;
        StopSource source;
        QDateTime triggeredAt;
    };

    /// 活跃保护表 key="beltNumber:protectionName"
    QMap<QString, ActiveProtection> m_activeProtections;

    /// 已因保护触发停车的皮带（防止同一皮带多个保护重复停车）key=beltNumber
    QMap<int, bool> m_beltStopped;

    /**
     * @brief 执行保护控制动作
     * @param beltNumber 皮带编号
     * @param protectionName 保护名称
     * @param protectionLevel 保护级别
     * @param source 停车源
     */
    void executeProtectionAction(int beltNumber, const QString &protectionName,
                                  int protectionLevel, StopSource source);
};

#endif // PROTECTIONLOGICCONTROLLER_H
