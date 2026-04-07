// S7ServerController.h
// 西门子 S7 服务器（从站）控制器类
// 创建日期: 2026-02-08
// ✅ 2026-02-08 [Phase 7.42]: TCP控制功能实现 - 基于 Snap7 库
// ✅ 2026-02-08 [Phase 7.42.7]: 集成 Snap7 库实现

#ifndef S7SERVERCONTROLLER_H
#define S7SERVERCONTROLLER_H

#include <QObject>
#include <QMap>  // ✅ 2026-04-07 [Phase 7.48.88.83]: 数据区缓冲用

#ifdef ENABLE_SNAP7
#include "snap7.h"
#endif

class S7ServerController : public QObject
{
    Q_OBJECT

    // ========== 连接状态 ==========
    Q_PROPERTY(bool isRunning READ isRunning NOTIFY isRunningChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY statusTextChanged)

    // ========== S7配置 ==========
    Q_PROPERTY(int port READ port WRITE setPort NOTIFY portChanged)
    Q_PROPERTY(QString bindIP READ bindIP WRITE setBindIP NOTIFY bindIPChanged)
    Q_PROPERTY(int maxConnections READ maxConnections WRITE setMaxConnections NOTIFY maxConnectionsChanged)

    // ========== 数据区配置 ==========
    Q_PROPERTY(int dbCount READ dbCount WRITE setDbCount NOTIFY dbCountChanged)
    Q_PROPERTY(int dbSize READ dbSize WRITE setDbSize NOTIFY dbSizeChanged)
    Q_PROPERTY(int merkerSize READ merkerSize WRITE setMerkerSize NOTIFY merkerSizeChanged)
    Q_PROPERTY(int inputSize READ inputSize WRITE setInputSize NOTIFY inputSizeChanged)
    Q_PROPERTY(int outputSize READ outputSize WRITE setOutputSize NOTIFY outputSizeChanged)

public:
    explicit S7ServerController(QObject *parent = nullptr);
    ~S7ServerController();

    // ========== 连接状态 ==========
    bool isRunning() const { return m_isRunning; }
    QString statusText() const { return m_statusText; }

    // ========== S7配置 ==========
    int port() const { return m_port; }
    void setPort(int port);

    QString bindIP() const { return m_bindIP; }
    void setBindIP(const QString &ip);

    int maxConnections() const { return m_maxConnections; }
    void setMaxConnections(int max);

    // ========== 数据区配置 ==========
    int dbCount() const { return m_dbCount; }
    void setDbCount(int count);

    int dbSize() const { return m_dbSize; }
    void setDbSize(int size);

    int merkerSize() const { return m_merkerSize; }
    void setMerkerSize(int size);

    int inputSize() const { return m_inputSize; }
    void setInputSize(int size);

    int outputSize() const { return m_outputSize; }
    void setOutputSize(int size);

    // ========== 服务器操作 ==========
    Q_INVOKABLE bool startServer();
    Q_INVOKABLE void stopServer();

    // ========== 数据区操作 ==========
    Q_INVOKABLE bool registerDB(int dbNumber, int size);
    Q_INVOKABLE bool setDBData(int dbNumber, int start, const QByteArray &data);
    Q_INVOKABLE QByteArray getDBData(int dbNumber, int start, int size);

signals:
    // ========== 属性变化信号 ==========
    void isRunningChanged();
    void statusTextChanged();
    void portChanged();
    void bindIPChanged();
    void maxConnectionsChanged();
    void dbCountChanged();
    void dbSizeChanged();
    void merkerSizeChanged();
    void inputSizeChanged();
    void outputSizeChanged();

    // ========== 数据访问信号 ==========
    void dataRead(int area, int dbNumber, int start, int size);
    void dataWritten(int area, int dbNumber, int start, int size);

    // ========== 错误信号 ==========
    void errorOccurred(const QString &error);

private:
#ifdef ENABLE_SNAP7
    TS7Server *m_s7Server;  // ✅ 2026-02-08 [Phase 7.42.7]: Snap7服务器
#endif

    // ✅ 2026-04-07 [Phase 7.48.88.83]: 数据区内存缓冲（无论Snap7是否启用都需要）
    // key=DB编号, value=数据缓冲区
    QMap<int, QByteArray> m_dbBuffers;

    // ========== S7配置 ==========
    int m_port;
    QString m_bindIP;
    int m_maxConnections;

    // ========== 数据区配置 ==========
    int m_dbCount;
    int m_dbSize;
    int m_merkerSize;
    int m_inputSize;
    int m_outputSize;

    // ========== 状态 ==========
    bool m_isRunning;
    QString m_statusText;

    // ========== 辅助函数 ==========
    void updateStatusText();
};

#endif // S7SERVERCONTROLLER_H
