#ifndef SIMULATED_HAL_H
#define SIMULATED_HAL_H

#include "hardware/hal/hardware_hal.h"

class SimulatedHAL : public HardwareHAL {
    Q_OBJECT

public:
    explicit SimulatedHAL(QObject *parent = nullptr);
    ~SimulatedHAL() override = default;

    bool initialize() override;
    void setMotorSpeed(float speed) override;
    float getMotorSpeed() const override;
    bool isMotorRunning() const override;
    void startMotor() override;
    void stopMotor() override;

private:
    float m_speed;
    bool m_running;
};

#endif // SIMULATED_HAL_H
