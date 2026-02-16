#ifndef TTSENGINEMANAGER_H
#define TTSENGINEMANAGER_H

#include <QObject>
#include <QString>
#include <QMap>
#include <QStringList>
#include "TTSEngineAdapter.h"

/**
 * @brief TTS 引擎管理器
 *
 * 管理多个 TTS 引擎，提供统一的接口
 *
 * ✅ 2026-02-13 [Phase 7.46.1]: 创建 TTS 引擎管理器
 */
class TTSEngineManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString currentEngine READ currentEngine WRITE setCurrentEngine NOTIFY currentEngineChanged)
    Q_PROPERTY(QStringList engineList READ engineList NOTIFY engineListChanged)

public:
    explicit TTSEngineManager(QObject *parent = nullptr);
    ~TTSEngineManager();

    /**
     * @brief 注册 TTS 引擎
     * @param adapter 引擎适配器
     * @return 是否成功
     */
    bool registerEngine(TTSEngineAdapter *adapter);

    /**
     * @brief 切换 TTS 引擎
     * @param engineName 引擎名称
     * @return 是否成功
     */
    bool setCurrentEngine(const QString &engineName);

    /**
     * @brief 获取当前引擎名称
     */
    QString currentEngine() const { return m_currentEngineName; }

    /**
     * @brief 初始化当前引擎
     * @param modelPath 模型路径
     * @return 是否成功
     *
     * ✅ 2026-02-15 22:40: 添加引擎初始化方法
     */
    bool initialize(const QString &modelPath);

    /**
     * @brief 获取引擎列表
     */
    QStringList engineList() const;

    /**
     * @brief 获取当前引擎的模型列表
     */
    QStringList getModelList() const;

    /**
     * @brief 获取指定模型的最大说话人ID
     * @param modelIndex 模型索引
     * @return 最大说话人ID
     */
    int getMaxSpeakerId(int modelIndex) const;

    /**
     * @brief 合成语音
     * @param text 要合成的文本
     * @param outputPath 输出文件路径
     * @param params TTS 参数
     * @return 是否成功
     */
    bool synthesize(const QString &text, const QString &outputPath, const TTSParameters &params);

    /**
     * @brief 停止当前合成
     */
    void stop();

signals:
    /**
     * @brief 当前引擎变化信号
     */
    void currentEngineChanged();

    /**
     * @brief 引擎列表变化信号
     */
    void engineListChanged();

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

private:
    QMap<QString, TTSEngineAdapter*> m_engines;     // 引擎映射
    QString m_currentEngineName;                    // 当前引擎名称
    TTSEngineAdapter *m_currentEngine;              // 当前引擎指针
};

#endif // TTSENGINEMANAGER_H
