#ifndef REAL_HAL_H
#define REAL_HAL_H

#include "hardware/hal/hardware_hal.h"
#include <QtSerialPort/QSerialPort>

class RealHAL : public HardwareHAL {
    Q_OBJECT

public:
    explicit RealHAL(QObject *parent = nullptr);
    ~RealHAL() override;

    bool initialize() override;
    void setMotorSpeed(float speed) override;
    float getMotorSpeed() const override;
    bool isMotorRunning() const override;
    void startMotor() override;
    void stopMotor() override;

private:
    QSerialPort *m_serialPort;
    float m_speed;
    bool m_running;
};

#endif // REAL_HAL_H
