#ifndef BELT_CONTROLLER_H
#define BELT_CONTROLLER_H

#include <QObject>
#include <QTimer>
#include "hardware/hal/hardware_hal.h"

class BeltController : public QObject {
    Q_OBJECT
    // QML可访问的属性（自动更新UI）
    Q_PROPERTY(float currentSpeed READ currentSpeed NOTIFY currentSpeedChanged)
    Q_PROPERTY(bool isMotorRunning READ isMotorRunning NOTIFY isMotorRunningChanged)
    Q_PROPERTY(QString alarmInfo READ alarmInfo NOTIFY alarmInfoChanged)

public:
    explicit BeltController(HardwareHAL* hal, QObject *parent = nullptr)
        : QObject(parent), m_hal(hal), m_isRunning(false), m_currentSpeed(0) {
        // 定时采集数据（100ms一次）
        m_timer.setInterval(100);
        connect(&m_timer, &QTimer::timeout, this, &BeltController::updateStatus);
    }

    // 控制接口（供QML调用）
    Q_INVOKABLE void startMotor();
    Q_INVOKABLE void stopMotor();
    Q_INVOKABLE void setTargetSpeed(float speed);

    // 属性getter
    float currentSpeed() const { return m_currentSpeed; }
    bool isMotorRunning() const { return m_isRunning; }
    QString alarmInfo() const { return m_alarmInfo; }

signals:
    void currentSpeedChanged();
    void isMotorRunningChanged();
    void alarmInfoChanged();
    void alarmTriggered(const QString &info);  // 供QML监听的报警信号

private slots:
    void updateStatus();  // 定时更新状态（从硬件读取数据）

private:
    HardwareHAL* m_hal;    // 硬件抽象层实例
    QTimer m_timer;        // 定时采集定时器
    bool m_isRunning;      // 电机运行状态
    float m_currentSpeed;  // 当前速度
    QString m_alarmInfo;   // 报警信息
};

#endif // BELT_CONTROLLER_H