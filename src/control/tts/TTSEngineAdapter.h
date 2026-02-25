#ifndef TTSENGINEADAPTER_H
#define TTSENGINEADAPTER_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QMap>

/**
 * @brief TTS 引擎类型枚举
 *
 * ✅ 2026-02-13 [Phase 7.46.1]: 创建 TTS 引擎类型枚举
 */
enum class TTSEngineType {
    PaddleSpeech,   // PaddleSpeech 引擎（优先）
    // ❌ 2026-02-24 23:00 [禁用]: MeloTTS,        // MeloTTS 引擎
    PiperTTS,       // Piper TTS 引擎
    CoquiTTS,       // Coqui TTS 引擎
    SherpaOnnx      // Sherpa-ONNX 引擎（保留兼容）
};

/**
 * @brief TTS 参数结构
 *
 * ✅ 2026-02-13 [Phase 7.46.1]: 创建 TTS 参数结构
 */
struct TTSParameters {
    int speakerId = 0;          // 说话人ID
    double rate = 1.0;          // 语速（0.5-2.0）
    double volume = 0.8;        // 音量（0.0-1.0）
    double pitch = 1.0;         // 音调（0.5-2.0，部分引擎支持）
    QString modelPath;          // 模型路径
    int modelIndex = 0;         // 模型索引
};

/**
 * @brief TTS 引擎适配器基类
 *
 * 为所有 TTS 引擎提供统一的接口
 *
 * ✅ 2026-02-13 [Phase 7.46.1]: 创建 TTS 引擎适配器基类
 */
class TTSEngineAdapter : public QObject
{
    Q_OBJECT

public:
    explicit TTSEngineAdapter(QObject *parent = nullptr);
    virtual ~TTSEngineAdapter();

    /**
     * @brief 获取引擎名称
     */
    QString engineName() const { return m_engineName; }

    /**
     * @brief 获取引擎类型
     */
    TTSEngineType engineType() const { return m_engineType; }

    /**
     * @brief 是否已初始化
     */
    bool isInitialized() const { return m_isInitialized; }

    /**
     * @brief 初始化引擎
     * @param modelPath 模型路径
     * @return 是否成功
     */
    virtual bool initialize(const QString &modelPath) = 0;

    /**
     * @brief 合成语音
     * @param text 要合成的文本
     * @param outputPath 输出文件路径
     * @param params TTS 参数
     * @return 是否成功
     */
    virtual bool synthesize(const QString &text, const QString &outputPath, const TTSParameters &params) = 0;

    /**
     * @brief 获取可用模型列表
     * @return 模型名称列表
     */
    virtual QStringList getModelList() const = 0;

    /**
     * @brief 获取指定模型的最大说话人ID
     * @param modelIndex 模型索引
     * @return 最大说话人ID
     */
    virtual int getMaxSpeakerId(int modelIndex) const = 0;

    /**
     * @brief 设置参数
     * @param params TTS 参数
     */
    virtual void setParameters(const TTSParameters &params);

    /**
     * @brief 停止当前合成
     */
    virtual void stop() = 0;

signals:
    /**
     * @brief 初始化进度信号
     * @param message 进度消息
     */
    void initializationProgress(const QString &message);

    /**
     * @brief 合成进度信号
     * @param progress 进度（0-100）
     */
    void synthesisProgress(int progress);

    /**
     * @brief 错误信号
     * @param error 错误消息
     */
    void errorOccurred(const QString &error);

protected:
    QString m_engineName;           // 引擎名称
    TTSEngineType m_engineType;     // 引擎类型
    bool m_isInitialized;           // 是否已初始化
    TTSParameters m_currentParams;  // 当前参数
};

#endif // TTSENGINEADAPTER_H
