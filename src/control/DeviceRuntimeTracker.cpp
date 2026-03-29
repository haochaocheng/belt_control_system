#include "DeviceRuntimeTracker.h"
#include <QDebug>

DeviceRuntimeTracker::DeviceRuntimeTracker(QObject *parent)
    : QObject(parent)
    , m_currentStatus("停止")
    , m_detailedStatus("允许启动")
    , m_isRunning(false)
    , m_isFault(false)
    , m_dailySeconds(0)
    , m_weeklySeconds(0)
    , m_monthlySeconds(0)
    , m_dailyRuntime("00:00:00")
    , m_weeklyRuntime("00:00:00")
    , m_monthlyRuntime("00:00:00")
    , m_dailyUptime(0.0)
    , m_weeklyUptime(0.0)
    , m_monthlyUptime(0.0)
    , m_currentDate(QDate::currentDate())
{
    // 初始化持久化存储
    m_settings = new QSettings("BeltControl", "RuntimeTracker", this);

    // 加载历史统计数据
    loadStatistics();

    // 创建运行时间更新定时器（每秒）
    m_updateTimer = new QTimer(this);
    connect(m_updateTimer, &QTimer::timeout, this, &DeviceRuntimeTracker::updateRuntime);
    m_updateTimer->start(1000);  // 1秒更新一次

    // 检查日期变更
    QTimer *dayCheckTimer = new QTimer(this);
    connect(dayCheckTimer, &QTimer::timeout, this, &DeviceRuntimeTracker::checkDayChange);
    dayCheckTimer->start(60000);  // 每分钟检查一次日期变更

    qDebug() << "✅ DeviceRuntimeTracker 初始化完成";
}

DeviceRuntimeTracker::~DeviceRuntimeTracker()
{
    saveStatistics();
}

void DeviceRuntimeTracker::onStartWarning()
{
    updateStatus("启动中", "起车预警");
    qDebug() << "📢 DeviceRuntimeTracker: 起车预警";
}

void DeviceRuntimeTracker::onBrakeReleasing()
{
    updateStatus("启动中", "正在松闸");
    qDebug() << "🔓 DeviceRuntimeTracker: 正在松闸";
}

void DeviceRuntimeTracker::onMotor1Starting()
{
    updateStatus("启动中", "1号电机启动");
    startRunning();  // 电机1启动即认为设备开机
    qDebug() << "⚡ DeviceRuntimeTracker: 1号电机启动（开始计时）";
}

void DeviceRuntimeTracker::onMotor2Starting()
{
    // ✅ 2026-03-29 [Phase 7.48.88.55]: 2号电机启动也触发计时
    // 原因：某些皮带无1号电机，仅有2号电机，需要在此启动计时
    startRunning();  // 内部有 m_isRunning 检查，已在运行则跳过
    updateStatus("运行", "2号电机启动");
    qDebug() << "⚡ DeviceRuntimeTracker: 2号电机启动（开始计时）";
}

void DeviceRuntimeTracker::onRunning()
{
    // ✅ 2026-03-29 [Phase 7.48.88.55]: 进入运行状态时确保计时启动
    // 原因：某些皮带启动序列无1号电机（如"张紧→制动器→2号电机"），
    //       onMotor1Starting() 不会被调用，导致 startRunning() 从未执行
    startRunning();  // 内部有 m_isRunning 检查，已在运行则跳过
    updateStatus("运行", "正在运行");
    qDebug() << "✅ DeviceRuntimeTracker: 正在运行";
}

void DeviceRuntimeTracker::onStopWarning()
{
    updateStatus("停止中", "停车预警");
    qDebug() << "📢 DeviceRuntimeTracker: 停车预警";
}

void DeviceRuntimeTracker::onMotor1Stopping()
{
    updateStatus("停止中", "停止1号电机");
    stopRunning();  // 电机1停止即认为设备停机
    qDebug() << "⏹ DeviceRuntimeTracker: 停止1号电机（停止计时）";
}

void DeviceRuntimeTracker::onMotor2Stopping()
{
    updateStatus("停止中", "停止2号电机");
    qDebug() << "⏹ DeviceRuntimeTracker: 停止2号电机";
}

void DeviceRuntimeTracker::onBrakeEngaging()
{
    updateStatus("停止中", "抱闸开启");
    qDebug() << "🔒 DeviceRuntimeTracker: 抱闸开启";
}

void DeviceRuntimeTracker::onStopped()
{
    // 如果有故障，显示"故障停车"，不自动恢复为"允许启动"
    if (m_isFault) {
        updateStatus("故障", "故障停车");
        qDebug() << "⏸ DeviceRuntimeTracker: 停止（故障停车，需要复位）";
    } else {
        updateStatus("停止", "允许启动");
        qDebug() << "⏸ DeviceRuntimeTracker: 停止（允许启动）";
    }
}

void DeviceRuntimeTracker::onFault(const QString &faultReason)
{
    stopRunning();  // 故障时停止计时
    m_isFault = true;
    updateStatus("故障", "故障停止");
    emit isFaultChanged();
    qDebug() << "❌ DeviceRuntimeTracker: 故障停止 -" << faultReason;
}

void DeviceRuntimeTracker::onDeviceFault(const QString &deviceName)
{
    // 记录故障设备（避免重复）
    if (!m_faultDevices.contains(deviceName)) {
        m_faultDevices.append(deviceName);
        emit faultDevicesChanged();
        qDebug() << "📝 DeviceRuntimeTracker: 记录故障设备 -" << deviceName;
    }

    // 更新总故障标识
    if (!m_isFault) {
        m_isFault = true;
        emit isFaultChanged();
    }
}

void DeviceRuntimeTracker::resetFault()
{
    qDebug() << "🔄 DeviceRuntimeTracker: 故障复位（F键）";

    // 清除故障设备列表
    if (!m_faultDevices.isEmpty()) {
        m_faultDevices.clear();
        emit faultDevicesChanged();
    }

    // 清除总故障标识
    if (m_isFault) {
        m_isFault = false;
        emit isFaultChanged();
    }

    // 恢复到允许启动状态
    if (m_currentStatus == "故障") {
        updateStatus("停止", "允许启动");
        qDebug() << "✅ DeviceRuntimeTracker: 故障已复位，恢复到允许启动";
    }
}

void DeviceRuntimeTracker::setFault()
{
    qDebug() << "🚨 DeviceRuntimeTracker: 设置总故障标识（保护触发）";

    // 设置总故障标识
    if (!m_isFault) {
        m_isFault = true;
        emit isFaultChanged();
        qDebug() << "  总故障标识已设置";
    }

    // 更新状态为故障（如果当前在运行）
    if (m_currentStatus == "运行") {
        updateStatus("故障", "保护触发");
        qDebug() << "  系统状态已更新为故障";
    }
}

void DeviceRuntimeTracker::onDeviceStatusChanged(const QString &deviceName, bool isRunning)
{
    // ✅ 2026-03-29 [Phase 7.48.88.55]: 监听所有电机的状态变化（原只监听电机1）
    // 原因：某些皮带无1号电机，仅有2号电机
    if (deviceName.contains("电机1") || deviceName.contains("1号电机")) {
        if (isRunning && !m_isRunning) {
            onMotor1Starting();
        } else if (!isRunning && m_isRunning) {
            onMotor1Stopping();
        }
    }
    // ✅ 2026-03-29 [Phase 7.48.88.55]: 新增2号电机监听
    if (deviceName.contains("电机2") || deviceName.contains("2号电机")) {
        if (isRunning && !m_isRunning) {
            onMotor2Starting();
        } else if (!isRunning && m_isRunning) {
            onMotor2Stopping();
        }
    }
}

void DeviceRuntimeTracker::updateStatus(const QString &status, const QString &detailedStatus)
{
    bool statusChanged = (m_currentStatus != status);
    bool detailChanged = (m_detailedStatus != detailedStatus);

    m_currentStatus = status;
    m_detailedStatus = detailedStatus;

    if (statusChanged) {
        emit currentStatusChanged();
    }
    if (detailChanged) {
        emit detailedStatusChanged();
    }
}

void DeviceRuntimeTracker::startRunning()
{
    if (m_isRunning) {
        return;  // 已经在运行
    }

    m_isRunning = true;
    m_isFault = false;
    m_runStartTime = QDateTime::currentDateTime();

    emit isRunningChanged();
    emit isFaultChanged();

    qDebug() << "▶️ DeviceRuntimeTracker: 开始运行计时 -" << m_runStartTime.toString("yyyy-MM-dd hh:mm:ss");
}

void DeviceRuntimeTracker::stopRunning()
{
    if (!m_isRunning) {
        return;  // 没有在运行
    }

    // 计算本次运行时长并累加
    qint64 runSeconds = m_runStartTime.secsTo(QDateTime::currentDateTime());
    m_dailySeconds += runSeconds;
    m_weeklySeconds += runSeconds;
    m_monthlySeconds += runSeconds;

    m_isRunning = false;
    emit isRunningChanged();

    // 更新运行时间显示
    m_dailyRuntime = formatSeconds(m_dailySeconds);
    m_weeklyRuntime = formatSeconds(m_weeklySeconds);
    m_monthlyRuntime = formatSeconds(m_monthlySeconds);

    emit dailyRuntimeChanged();
    emit weeklyRuntimeChanged();
    emit monthlyRuntimeChanged();

    // 计算开机率
    calculateUptime();

    // 保存统计数据
    saveStatistics();

    qDebug() << "⏹ DeviceRuntimeTracker: 停止运行计时，本次运行" << runSeconds << "秒";
}

void DeviceRuntimeTracker::updateRuntime()
{
    if (!m_isRunning) {
        return;
    }

    // 计算当前运行时长（不累加到总时长，只用于显示）
    qint64 currentRunSeconds = m_runStartTime.secsTo(QDateTime::currentDateTime());

    // 更新运行时间显示（包含当前运行时长）
    m_dailyRuntime = formatSeconds(m_dailySeconds + currentRunSeconds);
    m_weeklyRuntime = formatSeconds(m_weeklySeconds + currentRunSeconds);
    m_monthlyRuntime = formatSeconds(m_monthlySeconds + currentRunSeconds);

    emit dailyRuntimeChanged();
    emit weeklyRuntimeChanged();
    emit monthlyRuntimeChanged();

    // 计算开机率
    calculateUptime();
}

void DeviceRuntimeTracker::checkDayChange()
{
    QDate today = QDate::currentDate();

    if (today != m_currentDate) {
        // 日期变更
        qDebug() << "📅 DeviceRuntimeTracker: 日期变更 -" << m_currentDate.toString() << "→" << today.toString();

        // 重置日统计
        resetDailyStatistics();
        m_currentDate = today;

        // 检查是否需要重置周统计
        if (today.dayOfWeek() == 1) {  // 周一
            resetWeeklyStatistics();
            m_weekStartDate = today;
        }

        // 检查是否需要重置月统计
        if (today.day() == 1) {  // 每月1号
            resetMonthlyStatistics();
            m_monthStartDate = today;
        }

        saveStatistics();
    }
}

void DeviceRuntimeTracker::calculateUptime()
{
    QDateTime now = QDateTime::currentDateTime();

    // 计算今天已过去的时间（秒）
    QDateTime todayStart = QDateTime(QDate::currentDate(), QTime(0, 0, 0));
    qint64 todayElapsedSeconds = todayStart.secsTo(now);

    // 计算本周已过去的时间（秒）
    int dayOfWeek = now.date().dayOfWeek();  // 1=周一, 7=周日
    QDateTime weekStart = now.addDays(-(dayOfWeek - 1));
    weekStart.setTime(QTime(0, 0, 0));
    qint64 weekElapsedSeconds = weekStart.secsTo(now);

    // 计算本月已过去的时间（秒）
    QDateTime monthStart = QDateTime(QDate(now.date().year(), now.date().month(), 1), QTime(0, 0, 0));
    qint64 monthElapsedSeconds = monthStart.secsTo(now);

    // 计算当前运行时长
    qint64 currentRunSeconds = m_isRunning ? m_runStartTime.secsTo(now) : 0;

    // 计算开机率
    if (todayElapsedSeconds > 0) {
        m_dailyUptime = (double)(m_dailySeconds + currentRunSeconds) / todayElapsedSeconds * 100.0;
    } else {
        m_dailyUptime = 0.0;
    }

    if (weekElapsedSeconds > 0) {
        m_weeklyUptime = (double)(m_weeklySeconds + currentRunSeconds) / weekElapsedSeconds * 100.0;
    } else {
        m_weeklyUptime = 0.0;
    }

    if (monthElapsedSeconds > 0) {
        m_monthlyUptime = (double)(m_monthlySeconds + currentRunSeconds) / monthElapsedSeconds * 100.0;
    } else {
        m_monthlyUptime = 0.0;
    }

    emit dailyUptimeChanged();
    emit weeklyUptimeChanged();
    emit monthlyUptimeChanged();
}

QString DeviceRuntimeTracker::formatSeconds(qint64 seconds) const
{
    int hours = seconds / 3600;
    int minutes = (seconds % 3600) / 60;
    int secs = seconds % 60;
    return QString("%1:%2:%3")
        .arg(hours, 2, 10, QChar('0'))
        .arg(minutes, 2, 10, QChar('0'))
        .arg(secs, 2, 10, QChar('0'));
}

void DeviceRuntimeTracker::saveStatistics()
{
    m_settings->setValue("dailySeconds", m_dailySeconds);
    m_settings->setValue("weeklySeconds", m_weeklySeconds);
    m_settings->setValue("monthlySeconds", m_monthlySeconds);
    m_settings->setValue("currentDate", m_currentDate);
    m_settings->setValue("weekStartDate", m_weekStartDate);
    m_settings->setValue("monthStartDate", m_monthStartDate);
    m_settings->sync();
}

void DeviceRuntimeTracker::loadStatistics()
{
    QDate savedDate = m_settings->value("currentDate", QDate::currentDate()).toDate();
    QDate today = QDate::currentDate();

    // 如果保存的日期与今天不同，重置统计
    if (savedDate != today) {
        qDebug() << "📊 DeviceRuntimeTracker: 检测到日期变更，重置统计数据";
        resetDailyStatistics();

        if (today.dayOfWeek() == 1) {
            resetWeeklyStatistics();
        }
        if (today.day() == 1) {
            resetMonthlyStatistics();
        }

        m_currentDate = today;
        saveStatistics();
        return;
    }

    // 加载统计数据
    m_dailySeconds = m_settings->value("dailySeconds", 0).toLongLong();
    m_weeklySeconds = m_settings->value("weeklySeconds", 0).toLongLong();
    m_monthlySeconds = m_settings->value("monthlySeconds", 0).toLongLong();
    m_currentDate = savedDate;
    m_weekStartDate = m_settings->value("weekStartDate", today).toDate();
    m_monthStartDate = m_settings->value("monthStartDate", today).toDate();

    // 更新显示
    m_dailyRuntime = formatSeconds(m_dailySeconds);
    m_weeklyRuntime = formatSeconds(m_weeklySeconds);
    m_monthlyRuntime = formatSeconds(m_monthlySeconds);

    calculateUptime();

    qDebug() << "📊 DeviceRuntimeTracker: 加载统计数据 - 日:" << m_dailyRuntime
             << "周:" << m_weeklyRuntime << "月:" << m_monthlyRuntime;
}

void DeviceRuntimeTracker::resetDailyStatistics()
{
    m_dailySeconds = 0;
    m_dailyRuntime = "00:00:00";
    m_dailyUptime = 0.0;
    emit dailyRuntimeChanged();
    emit dailyUptimeChanged();
}

void DeviceRuntimeTracker::resetWeeklyStatistics()
{
    m_weeklySeconds = 0;
    m_weeklyRuntime = "00:00:00";
    m_weeklyUptime = 0.0;
    m_weekStartDate = QDate::currentDate();
    emit weeklyRuntimeChanged();
    emit weeklyUptimeChanged();
}

void DeviceRuntimeTracker::resetMonthlyStatistics()
{
    m_monthlySeconds = 0;
    m_monthlyRuntime = "00:00:00";
    m_monthlyUptime = 0.0;
    m_monthStartDate = QDate::currentDate();
    emit monthlyRuntimeChanged();
    emit monthlyUptimeChanged();
}
