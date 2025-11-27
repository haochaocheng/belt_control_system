#ifndef CONFIG_READER_H
#define CONFIG_READER_H

#include <QString>
#include <QSettings>

class ConfigReader {
public:
    explicit ConfigReader(const QString &filename);
    
    QString getValue(const QString &key, const QString &defaultValue = QString()) const;
    int getIntValue(const QString &key, int defaultValue = 0) const;
    double getDoubleValue(const QString &key, double defaultValue = 0.0) const;

private:
    QSettings *m_settings;
};

#endif // CONFIG_READER_H
