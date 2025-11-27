#include "hardware/real/real_hal.h"
#include <QDebug>

RealHAL::RealHAL(QObject *parent)
    : HardwareHAL(parent), m_serialPort(new QSerialPort(this)), 
      m_speed(0.0f), m_running(false) {
}

RealHAL::~RealHAL() {
    if (m_serialPort->isOpen()) {
        m_serialPort->close();
    }
}

bool RealHAL::initialize() {
    // TODO: Configure serial port
    qDebug() << "RealHAL: Initialized (serial port not configured)";
    return true;
}

void RealHAL::setMotorSpeed(float speed) {
    m_speed = speed;
    // TODO: Send command to hardware
    qDebug() << "RealHAL: Motor speed set to" << speed;
}

float RealHAL::getMotorSpeed() const {
    return m_speed;
}

bool RealHAL::isMotorRunning() const {
    return m_running;
}

void RealHAL::startMotor() {
    m_running = true;
    // TODO: Send start command to hardware
    qDebug() << "RealHAL: Motor started";
}

void RealHAL::stopMotor() {
    m_running = false;
    m_speed = 0.0f;
    // TODO: Send stop command to hardware
    qDebug() << "RealHAL: Motor stopped";
}
