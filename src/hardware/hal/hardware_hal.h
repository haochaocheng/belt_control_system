#ifndef HARDWARE_HAL_H
#define HARDWARE_HAL_H

#include <QObject>

class HardwareHAL : public QObject {
    Q_OBJECT

public:
    explicit HardwareHAL(QObject *parent = nullptr) : QObject(parent) {}
    virtual ~HardwareHAL() = default;

    // 硬件接口
    virtual bool initialize() = 0;
    virtual void setMotorSpeed(float speed) = 0;
    virtual float getMotorSpeed() const = 0;
    virtual bool isMotorRunning() const = 0;
    virtual void startMotor() = 0;
    virtual void stopMotor() = 0;

signals:
    void errorOccurred(const QString &error);
};

#endif // HARDWARE_HAL_H
