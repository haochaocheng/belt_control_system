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
#include "DataPathConfig.h"

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

    // ✅ 2026-02-28 [Phase 7.47.49]: 新增 - 默认音频路径（预置MP3，不走TTS）
    /**
     * @brief 获取默认音频文件路径（使用1#PD预置MP3文件）
     * @param beltNumber 皮带编号（1-8）
     * @param channelNumber DI通道号（0-7）
     * @return 路径：{baseDir}/{belt}#PD/{filename}.mp3
     *
     * 文件来源：AUDIO/1#PD/ 目录（同步到设备 /home/{user}/belt-control-data/audio/{belt}#PD/）
     */
    QString getDefaultAudioPath(int beltNumber, int channelNumber) const;

    /**
     * @brief 根据DI位索引获取保护短名称（用于DB查询，与UI保护名称一致）
     * @param bitIndex DI位索引（0-7）
     * @return 短名称（例如："急停"），与 digitalProtectionModel 的 name 字段一致
     */
    QString getShortProtectionName(int bitIndex) const;

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

    // ✅ 2026-03-02 [Phase 7.47.69]: 模块在线状态 - 静态路径方法（用于离线语音提示）

    /**
     * @brief 获取"连接服务器失败"语音文件路径
     * @return 路径：{audioBaseDir}/Status/连接服务器失败.wav
     *
     * 触发时机：程序连接 EMQX broker 超时（brokerConnectTimeout秒无法连接）
     */
    static QString getBrokerConnectionFailedPath();

    /**
     * @brief 获取模块离线语音文件路径
     * @param moduleIndex 模块索引（0=开关量模块一, 1=开关量模块二, 2=模拟量模块一, 3=模拟量模块二）
     * @return 路径：{audioBaseDir}/Status/{模块名称}.wav
     *         例：Status/开关量模块一离线.wav
     *
     * 触发时机：硬件模块数据超时（MQTTAutoManager.status == "数据超时"）
     */
    static QString getModuleOfflinePath(int moduleIndex);

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

    // ✅ 2026-02-28 [Phase 7.47.49]: 新增 - 默认音频文件名映射（通道号 → 1#PD文件名）
    // 对应 AUDIO/1#PD/ 中实际存在的文件名（.mp3）
    static const QMap<int, QString> DEFAULT_AUDIO_FILE_MAP;

    // ✅ 2026-02-28 [Phase 7.47.49]: 新增 - 保护短名称映射（通道号 → UI显示名/DB名）
    // 与 SwitchInputPage.qml digitalProtectionModel 的 name 字段一致
    static const QMap<int, QString> SHORT_NAME_MAP;

    /**
     * @brief 初始化保护名称映射表
     * @return 保护名称映射表
     */
    static QMap<int, QString> initProtectionNameMap();

    // ✅ 2026-02-28 [Phase 7.47.49]: 新增初始化函数
    static QMap<int, QString> initDefaultAudioFileMap();
    static QMap<int, QString> initShortNameMap();
};

#endif // AUDIOPATHMAPPER_H
