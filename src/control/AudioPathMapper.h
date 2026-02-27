/**
 * @file AudioPathMapper.h
 * @brief 音频文件路径映射器
 * @date 2026-02-27
 * @phase 7.47.35
 *
 * 功能：
 * - 根据引擎、模型、说话人、皮带编号、保护名称生成音频文件路径
 * - 支持多种TTS引擎和模型
 * - 路径格式：{engine}-{model}-spk{id}/{belt}#PD/{protection}.wav
 *
 * 参考：docs/2026-02-26/08-音频文件路径映射设计方案.md
 */

#ifndef AUDIOPATHMAPPER_H
#define AUDIOPATHMAPPER_H

#include <QString>
#include <QMap>

/**
 * @brief 音频文件路径映射器
 *
 * 根据TTS配置和保护信息生成音频文件路径
 */
class AudioPathMapper
{
public:
    /**
     * @brief 构造函数
     * @param baseDir 音频文件基础目录（默认：/app/audio）
     */
    explicit AudioPathMapper(const QString &baseDir = "/app/audio");

    /**
     * @brief 设置基础目录
     * @param baseDir 音频文件基础目录
     */
    void setBaseDirectory(const QString &baseDir);

    /**
     * @brief 获取基础目录
     * @return 音频文件基础目录
     */
    QString baseDirectory() const { return m_baseDir; }

    /**
     * @brief 生成音频文件路径
     * @param engineName 引擎名称（例如：paddlespeech）
     * @param modelName 模型名称（例如：fastspeech2_csmsc）
     * @param speakerId 说话人ID
     * @param beltNumber 皮带编号（1-8）
     * @param protectionName 保护名称（例如：急停保护）
     * @return 完整的音频文件路径
     *
     * 示例：
     * - 输入：paddlespeech, fastspeech2_csmsc, 0, 1, "急停保护"
     * - 输出：/app/audio/paddlespeech-fastspeech2_csmsc-spk0/1#PD/急停保护.wav
     */
    QString getAudioPath(const QString &engineName,
                         const QString &modelName,
                         int speakerId,
                         int beltNumber,
                         const QString &protectionName) const;

    /**
     * @brief 生成音频文件路径（使用当前TTS配置）
     * @param beltNumber 皮带编号（1-8）
     * @param protectionName 保护名称（例如：急停保护）
     * @return 完整的音频文件路径
     *
     * 说明：从TTSConfigManager读取当前测试场景的TTS配置
     */
    QString getAudioPath(int beltNumber, const QString &protectionName) const;

    /**
     * @brief 根据DI位索引获取保护名称
     * @param bitIndex DI位索引（0-7）
     * @return 保护名称（例如：急停保护）
     *
     * 说明：
     * - 位索引0对应第一个保护项（急停保护）
     * - 位索引1对应第二个保护项（拉绳保护）
     * - 以此类推
     */
    QString getProtectionName(int bitIndex) const;

    /**
     * @brief 生成文件夹路径
     * @param engineName 引擎名称
     * @param modelName 模型名称
     * @param speakerId 说话人ID
     * @param beltNumber 皮带编号
     * @return 文件夹路径（不含文件名）
     *
     * 示例：/app/audio/paddlespeech-fastspeech2_csmsc-spk0/1#PD
     */
    QString getFolderPath(const QString &engineName,
                          const QString &modelName,
                          int speakerId,
                          int beltNumber) const;

private:
    QString m_baseDir;  ///< 音频文件基础目录

    /**
     * @brief 保护名称映射表（位索引 → 保护名称）
     *
     * 说明：
     * - 索引0-32对应VoiceFileList.h中的SwitchInputVoice::PROTECTION_ITEMS
     * - 去掉了模板中的"%1号皮带"前缀，只保留保护类型
     */
    static const QMap<int, QString> PROTECTION_NAME_MAP;

    /**
     * @brief 初始化保护名称映射表
     * @return 保护名称映射表
     */
    static QMap<int, QString> initProtectionNameMap();
};

#endif // AUDIOPATHMAPPER_H
