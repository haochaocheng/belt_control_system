#include "hardware/simulated/simulated_hal.h"
#include <QDebug>

SimulatedHAL::SimulatedHAL(QObject *parent)
    : HardwareHAL(parent), m_speed(0.0f), m_running(false) {
}

bool SimulatedHAL::initialize() {
    qDebug() << "SimulatedHAL: Initialized";
    return true;
}

void SimulatedHAL::setMotorSpeed(float speed) {
    m_speed = speed;
    qDebug() << "SimulatedHAL: Motor speed set to" << speed;
}

float SimulatedHAL::getMotorSpeed() const {
    return m_speed;
}

bool SimulatedHAL::isMotorRunning() const {
    return m_running;
}

void SimulatedHAL::startMotor() {
    m_running = true;
    qDebug() << "SimulatedHAL: Motor started";
}

void SimulatedHAL::stopMotor() {
    m_running = false;
    m_speed = 0.0f;
    qDebug() << "SimulatedHAL: Motor stopped";
}
