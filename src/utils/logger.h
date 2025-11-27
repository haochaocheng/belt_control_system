#ifndef LOGGER_H
#define LOGGER_H

#include <QObject>
#include <QString>
#include <QFile>
#include <QTextStream>
#include <QDateTime>
#include <QMutex>
#include <QDebug>

class Logger : public QObject {
    Q_OBJECT

public:
    static Logger* instance() {
        static Logger instance;
        return &instance;
    }

    static void init(const QString& filename) {
        instance()->m_logFile.setFileName(filename);
        instance()->m_logFile.open(QIODevice::Append | QIODevice::Text);
    }

    Q_INVOKABLE void log(const QString& message) {
        QMutexLocker locker(&m_mutex);
        QString timestamp = QDateTime::currentDateTime().toString("yyyy-MM-dd hh:mm:ss");
        QString logMessage = QString("[%1] %2").arg(timestamp, message);

        if (m_logFile.isOpen()) {
            QTextStream stream(&m_logFile);
            stream << logMessage << Qt::endl;
        }

        qDebug() << logMessage;
    }

private:
    Logger() = default;
    ~Logger() {
        if (m_logFile.isOpen()) {
            m_logFile.close();
        }
    }

    QFile m_logFile;
    QMutex m_mutex;
};

#endif // LOGGER_H
