#include "TTSEngineManager.h"
#include <QDebug>

// ✅ 2026-02-13 [Phase 7.46.1]: 实现 TTS 引擎管理器

TTSEngineManager::TTSEngineManager(QObject *parent)
    : QObject(parent)
    , m_currentEngine(nullptr)
{
    qDebug() << "✅ [TTSEngineManager] 创建";
}

TTSEngineManager::~TTSEngineManager()
{
    qDebug() << "🔴 [TTSEngineManager] 销毁";
}

bool TTSEngineManager::registerEngine(TTSEngineAdapter *adapter)
{
    if (!adapter) {
        qWarning() << "⚠️ [TTSEngineManager] 引擎适配器为空";
        return false;
    }

    QString engineName = adapter->engineName();
    if (m_engines.contains(engineName)) {
        qWarning() << "⚠️ [TTSEngineManager] 引擎已注册:" << engineName;
        return false;
    }

    m_engines[engineName] = adapter;
    qDebug() << "✅ [TTSEngineManager] 注册引擎:" << engineName;

    // 连接信号
    connect(adapter, &TTSEngineAdapter::initializationProgress,
            this, &TTSEngineManager::initializationProgress);
    connect(adapter, &TTSEngineAdapter::synthesisProgress,
            this, &TTSEngineManager::synthesisProgress);
    connect(adapter, &TTSEngineAdapter::errorOccurred,
            this, &TTSEngineManager::errorOccurred);

    emit engineListChanged();
    return true;
}

bool TTSEngineManager::setCurrentEngine(const QString &engineName)
{
    if (!m_engines.contains(engineName)) {
        qWarning() << "⚠️ [TTSEngineManager] 引擎未注册:" << engineName;
        return false;
    }

    m_currentEngineName = engineName;
    m_currentEngine = m_engines[engineName];

    qDebug() << "🔄 [TTSEngineManager] 切换引擎:" << engineName;
    emit currentEngineChanged();

    return true;
}

// ✅ 2026-02-15 22:40: 实现引擎初始化方法
bool TTSEngineManager::initialize(const QString &modelPath)
{
    if (!m_currentEngine) {
        qWarning() << "⚠️ [TTSEngineManager] 当前引擎为空";
        return false;
    }

    qDebug() << "🔧 [TTSEngineManager] 初始化引擎:" << m_currentEngineName
             << "模型:" << modelPath;

    return m_currentEngine->initialize(modelPath);
}

QStringList TTSEngineManager::engineList() const
{
    return m_engines.keys();
}

QStringList TTSEngineManager::getModelList() const
{
    if (!m_currentEngine) {
        qWarning() << "⚠️ [TTSEngineManager] 当前引擎为空";
        return QStringList();
    }

    return m_currentEngine->getModelList();
}

int TTSEngineManager::getMaxSpeakerId(int modelIndex) const
{
    if (!m_currentEngine) {
        qWarning() << "⚠️ [TTSEngineManager] 当前引擎为空";
        return 0;
    }

    return m_currentEngine->getMaxSpeakerId(modelIndex);
}

bool TTSEngineManager::synthesize(const QString &text, const QString &outputPath, const TTSParameters &params)
{
    if (!m_currentEngine) {
        qWarning() << "⚠️ [TTSEngineManager] 当前引擎为空";
        return false;
    }

    qDebug() << "🎙️ [TTSEngineManager] 合成语音 - 引擎:" << m_currentEngineName
             << "文本:" << text;

    return m_currentEngine->synthesize(text, outputPath, params);
}

void TTSEngineManager::stop()
{
    if (!m_currentEngine) {
        qWarning() << "⚠️ [TTSEngineManager] 当前引擎为空";
        return;
    }

    qDebug() << "🛑 [TTSEngineManager] 停止合成";
    m_currentEngine->stop();
}
