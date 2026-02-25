#include "TTSEngineAdapter.h"
#include <QDebug>

// ✅ 2026-02-13 [Phase 7.46.1]: 实现 TTS 引擎适配器基类

TTSEngineAdapter::TTSEngineAdapter(QObject *parent)
    : QObject(parent)
    , m_isInitialized(false)
{
}

TTSEngineAdapter::~TTSEngineAdapter()
{
}

void TTSEngineAdapter::setParameters(const TTSParameters &params)
{
    m_currentParams = params;
    qDebug() << "🔧 [TTSEngineAdapter]" << m_engineName << "参数更新:"
             << "说话人ID:" << params.speakerId
             << "语速:" << params.rate
             << "音量:" << params.volume;
}
