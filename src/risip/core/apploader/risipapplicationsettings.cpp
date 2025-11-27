/***********************************************************************************
**    Copyright (C) 2016  Petref Saraci
**
**    This program is free software: you can redistribute it and/or modify
**    it under the terms of the GNU General Public License as published by
**    the Free Software Foundation, either version 3 of the License, or
**    (at your option) any later version.
**
**    This program is distributed in the hope that it will be useful,
**    but WITHOUT ANY WARRANTY; without even the implied warranty of
**    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
**    GNU General Public License for more details.
**
**    You have received a copy of the GNU General Public License
**    along with this program. See LICENSE.GPLv3
**    A copy of the license can be found also here <http://www.gnu.org/licenses/>.
**
************************************************************************************/

#include "risipapplicationsettings.h"
#include <QCoreApplication>
#include <QDebug>

namespace risip {

// Qt6: Use Meyer's Singleton pattern to avoid static member DLL export issues
RisipApplicationSettings* RisipApplicationSettings::instance()
{
    static RisipApplicationSettings* m_applicationSettingsInstance = nullptr;
    if (!m_applicationSettingsInstance) {
        m_applicationSettingsInstance = new RisipApplicationSettings();
    }
    return m_applicationSettingsInstance;
}

RisipApplicationSettings::RisipApplicationSettings(QObject *parent)
    : QObject(parent)
    , m_platform(Windows_Desktop)  // Default to Windows Desktop
    , m_settings("Risip", "BeltControlSystem")
{
    // Read existing settings
    read();
}

RisipApplicationSettings::~RisipApplicationSettings()
{
    save();
}

QString RisipApplicationSettings::organizationName() const
{
    return QCoreApplication::organizationName();
}

void RisipApplicationSettings::setOrganizationName(QString orgName)
{
    if (organizationName() != orgName) {
        QCoreApplication::setOrganizationName(orgName);
        m_settings.sync();
        emit organizationNameChanged(orgName);
    }
}

QString RisipApplicationSettings::applicationName() const
{
    return QCoreApplication::applicationName();
}

void RisipApplicationSettings::setApplicationName(QString name)
{
    if (applicationName() != name) {
        QCoreApplication::setApplicationName(name);
        m_settings.sync();
        emit applicationNameChanged(name);
    }
}

QString RisipApplicationSettings::organizationDomain() const
{
    return QCoreApplication::organizationDomain();
}

void RisipApplicationSettings::setOrganizationDomain(QString name)
{
    if (organizationDomain() != name) {
        QCoreApplication::setOrganizationDomain(name);
        m_settings.sync();
        emit organizationDomainChanged(name);
    }
}

int RisipApplicationSettings::platform() const
{
    return m_platform;
}

bool RisipApplicationSettings::firstRun() const
{
    return m_settings.value("general/firstRun", true).toBool();
}

bool RisipApplicationSettings::save()
{
    m_settings.setValue("general/firstRun", false);
    m_settings.setValue("general/organizationName", organizationName());
    m_settings.setValue("general/applicationName", applicationName());
    m_settings.setValue("general/organizationDomain", organizationDomain());
    m_settings.sync();
    return m_settings.status() == QSettings::NoError;
}

bool RisipApplicationSettings::reset()
{
    m_settings.clear();
    m_settings.sync();
    emit firstRunChanged(true);
    return m_settings.status() == QSettings::NoError;
}

bool RisipApplicationSettings::read()
{
    bool first = firstRun();
    if (!first) {
        QString orgName = m_settings.value("general/organizationName").toString();
        QString appName = m_settings.value("general/applicationName").toString();
        QString orgDomain = m_settings.value("general/organizationDomain").toString();

        if (!orgName.isEmpty())
            QCoreApplication::setOrganizationName(orgName);
        if (!appName.isEmpty())
            QCoreApplication::setApplicationName(appName);
        if (!orgDomain.isEmpty())
            QCoreApplication::setOrganizationDomain(orgDomain);
    }
    return m_settings.status() == QSettings::NoError;
}

} // end of risip namespace
