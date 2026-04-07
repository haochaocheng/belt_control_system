// S7ServerController.cpp
// 西门子 S7 服务器（从站）控制器实现
// 创建日期: 2026-02-08
// ✅ 2026-02-08 [Phase 7.42]: TCP控制功能实现 - 基于 Snap7 库
// ✅ 2026-02-08 [Phase 7.42.7]: 集成 Snap7 库实现

#include "S7ServerController.h"
#include <QDebug>
#include <cstring>  // ✅ 2026-04-07 [Phase 7.48.88.83]: memcpy用于数据缓冲区操作

S7ServerController::S7ServerController(QObject *parent)
    : QObject(parent)
    , m_port(102)
    , m_bindIP("0.0.0.0")
    , m_maxConnections(8)
    , m_dbCount(10)
    , m_dbSize(1024)
    , m_merkerSize(256)
    , m_inputSize(128)
    , m_outputSize(128)
    , m_isRunning(false)
    , m_statusText("未运行")
{
#ifdef ENABLE_SNAP7
    // ✅ 2026-02-08 [Phase 7.42.7]: 初始化 Snap7 服务器
    m_s7Server = new TS7Server();
    qDebug() << "✅ [S7ServerController] 初始化完成（Snap7支持已启用）";
#else
    qDebug() << "⚠️ [S7ServerController] 初始化完成（Snap7未启用，S7服务器功能不可用）";
#endif
}

S7ServerController::~S7ServerController()
{
    stopServer();
#ifdef ENABLE_SNAP7
    // ✅ 2026-02-08 [Phase 7.42.7]: 释放 Snap7 服务器资源
    delete m_s7Server;
#endif
}

// ========== S7配置 ==========
void S7ServerController::setPort(int port)
{
    if (m_port != port) {
        m_port = port;
        emit portChanged();
    }
}

void S7ServerController::setBindIP(const QString &ip)
{
    if (m_bindIP != ip) {
        m_bindIP = ip;
        emit bindIPChanged();
    }
}

void S7ServerController::setMaxConnections(int max)
{
    if (m_maxConnections != max) {
        m_maxConnections = max;
        emit maxConnectionsChanged();
    }
}

// ========== 数据区配置 ==========
void S7ServerController::setDbCount(int count)
{
    if (m_dbCount != count) {
        m_dbCount = count;
        emit dbCountChanged();
    }
}

void S7ServerController::setDbSize(int size)
{
    if (m_dbSize != size) {
        m_dbSize = size;
        emit dbSizeChanged();
    }
}

void S7ServerController::setMerkerSize(int size)
{
    if (m_merkerSize != size) {
        m_merkerSize = size;
        emit merkerSizeChanged();
    }
}

void S7ServerController::setInputSize(int size)
{
    if (m_inputSize != size) {
        m_inputSize = size;
        emit inputSizeChanged();
    }
}

void S7ServerController::setOutputSize(int size)
{
    if (m_outputSize != size) {
        m_outputSize = size;
        emit outputSizeChanged();
    }
}

// ========== 服务器操作 ==========
bool S7ServerController::startServer()
{
#ifdef ENABLE_SNAP7
    if (!m_s7Server) {
        qWarning() << "❌ [S7ServerController] S7服务器未初始化";
        return false;
    }

    if (m_isRunning) {
        qWarning() << "⚠️ [S7ServerController] 服务器已在运行";
        return true;
    }

    qDebug() << "🚀 [S7ServerController] 启动S7服务器...";
    qDebug() << "  绑定IP:" << m_bindIP;
    qDebug() << "  端口:" << m_port;

    // 启动服务器（简化实现）
    int result = m_s7Server->Start();

    if (result == 0) {
        m_isRunning = true;
        updateStatusText();
        emit isRunningChanged();
        qDebug() << "✅ [S7ServerController] 服务器启动成功";
        return true;
    } else {
        QString errorMsg = QString("服务器启动失败 (错误码: %1)").arg(result);
        qWarning() << "❌ [S7ServerController]" << errorMsg;
        emit errorOccurred(errorMsg);
        return false;
    }
#else
    qWarning() << "⚠️ [S7ServerController] Snap7未启用，无法启动服务器";
    emit errorOccurred("Snap7库未启用");
    return false;
#endif
}

void S7ServerController::stopServer()
{
    if (m_isRunning) {
#ifdef ENABLE_SNAP7
        if (m_s7Server) {
            m_s7Server->Stop();
        }
#endif
        m_isRunning = false;
        updateStatusText();
        emit isRunningChanged();
        qDebug() << "✅ [S7ServerController] 服务器已停止";
    }
}

// ========== 数据区操作 ==========
bool S7ServerController::registerDB(int dbNumber, int size)
{
    // ✅ 2026-04-07 [Phase 7.48.88.83]: 实现数据区注册（分配内存缓冲区）
    // 旧代码：仅打印日志，无实际内存分配
    // 原因：TCPDataAdapter需要实际的数据缓冲区来存储同步数据
    if (size <= 0 || size > 65536) {
        qWarning() << "❌ [S7ServerController] 无效的DB大小:" << size;
        return false;
    }

    m_dbBuffers[dbNumber] = QByteArray(size, 0);

#ifdef ENABLE_SNAP7
    if (m_s7Server) {
        // Snap7 RegisterArea: srvAreaDB=0x84, DB编号, 缓冲区指针, 大小
        int result = m_s7Server->RegisterArea(srvAreaDB, dbNumber,
            m_dbBuffers[dbNumber].data(), size);
        if (result != 0) {
            qWarning() << "⚠️ [S7ServerController] Snap7注册DB" << dbNumber << "失败, 错误码:" << result;
        }
    }
#endif

    qDebug() << "✅ [S7ServerController] 注册DB" << dbNumber << "大小:" << size << "bytes";
    return true;
}

bool S7ServerController::setDBData(int dbNumber, int start, const QByteArray &data)
{
    // ✅ 2026-04-07 [Phase 7.48.88.83]: 实现数据写入缓冲区
    // 旧代码：仅打印日志，未写入实际数据
    if (!m_dbBuffers.contains(dbNumber)) {
        qWarning() << "❌ [S7ServerController] DB" << dbNumber << "未注册";
        return false;
    }

    QByteArray &buffer = m_dbBuffers[dbNumber];
    if (start < 0 || start + data.size() > buffer.size()) {
        qWarning() << "❌ [S7ServerController] DB" << dbNumber << "写入越界:"
                   << "start=" << start << "dataSize=" << data.size() << "bufSize=" << buffer.size();
        return false;
    }

    memcpy(buffer.data() + start, data.constData(), data.size());

    // Snap7服务器使用共享内存指针（RegisterArea时已注册），PLC客户端直接读取缓冲区
    // 无需额外操作，数据已在缓冲区中
    return true;
}

QByteArray S7ServerController::getDBData(int dbNumber, int start, int size)
{
    // ✅ 2026-04-07 [Phase 7.48.88.83]: 实现数据读取
    // 旧代码：返回全零数组
    if (!m_dbBuffers.contains(dbNumber)) {
        qWarning() << "❌ [S7ServerController] DB" << dbNumber << "未注册";
        return QByteArray();
    }

    const QByteArray &buffer = m_dbBuffers[dbNumber];
    if (start < 0 || start + size > buffer.size()) {
        qWarning() << "❌ [S7ServerController] DB" << dbNumber << "读取越界:"
                   << "start=" << start << "size=" << size << "bufSize=" << buffer.size();
        return QByteArray();
    }

    return buffer.mid(start, size);
}

// ========== 辅助函数 ==========
void S7ServerController::updateStatusText()
{
    QString newStatus;
    if (m_isRunning) {
        newStatus = QString("运行中 (端口:%1)").arg(m_port);
    } else {
        newStatus = "未启动";
    }

    if (m_statusText != newStatus) {
        m_statusText = newStatus;
        emit statusTextChanged();
    }
}
