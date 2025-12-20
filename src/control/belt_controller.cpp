#include "belt_controller.h"
#include <QDebug>

void BeltController::startMotor() {
    if (m_hal) {
        m_hal->startMotor();
        m_isRunning = true;
        m_timer.start();
        emit isMotorRunningChanged();
        qDebug() << "BeltController: Motor started";
    }
}

void BeltController::stopMotor() {
    if (m_hal) {
        m_hal->stopMotor();
        m_isRunning = false;
        m_currentSpeed = 0.0f;
        m_timer.stop();
        emit isMotorRunningChanged();
        emit currentSpeedChanged();
        qDebug() << "BeltController: Motor stopped";
    }
}

void BeltController::setTargetSpeed(float speed) {
    if (m_hal) {
        m_hal->setMotorSpeed(speed);
        qDebug() << "BeltController: Target speed set to" << speed;
    }
}

void BeltController::updateStatus() {
    if (m_hal) {
        float newSpeed = m_hal->getMotorSpeed();
        if (qAbs(newSpeed - m_currentSpeed) > 0.01f) {
            m_currentSpeed = newSpeed;
            emit currentSpeedChanged();
        }
        
        bool running = m_hal->isMotorRunning();
        if (running != m_isRunning) {
            m_isRunning = running;
            emit isMotorRunningChanged();
        }
    }
}
