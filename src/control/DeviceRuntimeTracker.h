#ifndef DEVICERUNTIMETRACKER_H
#define DEVICERUNTIMETRACKER_H

#include <QObject>
#include <QTimer>
#include <QDateTime>
#include <QSettings>

/**
 * @brief 设备运行时间跟踪器
 *
 * 功能：
 * - 跟踪设备运行状态（停止/预警/松闸/启动电机1/启动电机2/运行/故障）
 * - 统计开机时间（日/周/月累计）
 * - 计算开机率（日/周/月）
 * - 以电机1运行为开机标准
 */
class DeviceRuntimeTracker : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString currentStatus READ currentStatus NOTIFY currentStatusChanged)
    Q_PROPERTY(QString detailedStatus READ detailedStatus NOTIFY detailedStatusChanged)
    Q_PROPERTY(bool isRunning READ isRunning NOTIFY isRunningChanged)
    Q_PROPERTY(bool isFault READ isFault NOTIFY isFaultChanged)
    Q_PROPERTY(QStringList faultDevices READ faultDevices NOTIFY faultDevicesChanged)

    // 运行时间统计
    Q_PROPERTY(QString dailyRuntime READ dailyRuntime NOTIFY dailyRuntimeChanged)
    Q_PROPERTY(QString weeklyRuntime READ weeklyRuntime NOTIFY weeklyRuntimeChanged)
    Q_PROPERTY(QString monthlyRuntime READ monthlyRuntime NOTIFY monthlyRuntimeChanged)

    // 开机率统计
    Q_PROPERTY(double dailyUptime READ dailyUptime NOTIFY dailyUptimeChanged)
    Q_PROPERTY(double weeklyUptime READ weeklyUptime NOTIFY weeklyUptimeChanged)
    Q_PROPERTY(double monthlyUptime READ monthlyUptime NOTIFY monthlyUptimeChanged)

public:
    explicit DeviceRuntimeTracker(QObject *parent = nullptr);
    ~DeviceRuntimeTracker();

    // 状态获取
    QString currentStatus() const { return m_currentStatus; }
    QString detailedStatus() const { return m_detailedStatus; }
    bool isRunning() const { return m_isRunning; }
    bool isFault() const { return m_isFault; }
    QStringList faultDevices() const { return m_faultDevices; }

    // 运行时间获取
    QString dailyRuntime() const { return m_dailyRuntime; }
    QString weeklyRuntime() const { return m_weeklyRuntime; }
    QString monthlyRuntime() const { return m_monthlyRuntime; }

    // 开机率获取
    double dailyUptime() const { return m_dailyUptime; }
    double weeklyUptime() const { return m_weeklyUptime; }
    double monthlyUptime() const { return m_monthlyUptime; }

signals:
    void currentStatusChanged();
    void detailedStatusChanged();
    void isRunningChanged();
    void isFaultChanged();
    void faultDevicesChanged();
    void dailyRuntimeChanged();
    void weeklyRuntimeChanged();
    void monthlyRuntimeChanged();
    void dailyUptimeChanged();
    void weeklyUptimeChanged();
    void monthlyUptimeChanged();

public slots:
    // 启动流程状态更新
    void onStartWarning();           // 起车预警
    void onBrakeReleasing();         // 松闸/启动抱闸
    void onMotor1Starting();         // 启动1号电机
    void onMotor2Starting();         // 启动2号电机
    void onRunning();                // 运行中

    // 停止流程状态更新
    void onStopWarning();            // 停车预警
    void onMotor1Stopping();         // 停止电机1
    void onMotor2Stopping();         // 停止电机2
    void onBrakeEngaging();          // 抱闸开启
    void onStopped();                // 停车

    // 故障状态
    void onFault(const QString &faultReason);  // 故障
    void onDeviceFault(const QString &deviceName);  // 设备故障（记录故障设备）

    // 故障复位（F键）
    Q_INVOKABLE void resetFault();  // 复位所有故障
    Q_INVOKABLE void setFault();    // 设置总故障（用于保护触发）

    // 通用设备状态更新（从CommonControl调用）
    void onDeviceStatusChanged(const QString &deviceName, bool isRunning);

private slots:
    void updateRuntime();            // 定时更新运行时间
    void checkDayChange();           // 检查日期变更

private:
    // 状态变量
    QString m_currentStatus;         // 当前状态：停止/运行/故障
    QString m_detailedStatus;        // 详细状态：起车预警/启动抱闸/启动1号电机等
    bool m_isRunning;                // 是否运行（电机1运行）
    bool m_isFault;                  // 是否故障（总故障标识）
    QStringList m_faultDevices;      // 故障设备列表

    // 运行时间跟踪
    QDateTime m_runStartTime;        // 本次运行开始时间
    qint64 m_dailySeconds;           // 日累计运行秒数
    qint64 m_weeklySeconds;          // 周累计运行秒数
    qint64 m_monthlySeconds;         // 月累计运行秒数

    // 格式化的运行时间字符串
    QString m_dailyRuntime;
    QString m_weeklyRuntime;
    QString m_monthlyRuntime;

    // 开机率
    double m_dailyUptime;
    double m_weeklyUptime;
    double m_monthlyUptime;

    // 日期跟踪
    QDate m_currentDate;
    QDate m_weekStartDate;
    QDate m_monthStartDate;

    // 定时器
    QTimer *m_updateTimer;           // 运行时间更新定时器（1秒）

    // 持久化存储
    QSettings *m_settings;

    // 辅助方法
    void updateStatus(const QString &status, const QString &detailedStatus);
    void startRunning();
    void stopRunning();
    void calculateUptime();
    QString formatSeconds(qint64 seconds) const;
    void saveStatistics();
    void loadStatistics();
    void resetDailyStatistics();
    void resetWeeklyStatistics();
    void resetMonthlyStatistics();
};

#endif // DEVICERUNTIMETRACKER_H
