#include "utils/config_reader.h"

ConfigReader::ConfigReader(const QString &filename)
    : m_settings(new QSettings(filename, QSettings::IniFormat)) {
}

QString ConfigReader::getValue(const QString &key, const QString &defaultValue) const {
    return m_settings->value(key, defaultValue).toString();
}

int ConfigReader::getIntValue(const QString &key, int defaultValue) const {
    return m_settings->value(key, defaultValue).toInt();
}

double ConfigReader::getDoubleValue(const QString &key, double defaultValue) const {
    return m_settings->value(key, defaultValue).toDouble();
}
