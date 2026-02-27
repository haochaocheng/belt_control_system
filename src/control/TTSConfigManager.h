#ifndef TTSCONFIGMANAGER_H
#define TTSCONFIGMANAGER_H

#include <QObject>
#include <QSettings>
#include <QString>
#include <QMap>

/**
 * @brief TTS配置管理器（场景配置模式）
 *
 * 支持三种场景的独立配置：
 * 1. startup_warning - 起车预警
 * 2. fault_alarm - 故障报警
 * 3. test - 测试（参数设置界面）
 *
 * ✅ 2026-01-23 09:30 [FIX 100.299] TTS模型动态配置
 */
class TTSConfigManager : public QObject
{
    Q_OBJECT

public:
    // 场景枚举
    enum Scene {
        StartupWarning = 0,  // 起车预警
        FaultAlarm = 1,      // 故障报警
        Test = 2             // 测试
    };
    Q_ENUM(Scene)

    // 单例模式
    static TTSConfigManager* instance();

    // 加载/保存配置
    void loadConfig();
    void saveConfig();

    // 获取/设置配置（指定场景）
    int modelIndex(Scene scene) const;
    void setModelIndex(Scene scene, int index);

    QString modelPath(Scene scene) const;
    void setModelPath(Scene scene, const QString &path);

    int speakerId(Scene scene) const;
    void setSpeakerId(Scene scene, int id);

    double rate(Scene scene) const;
    void setRate(Scene scene, double rate);

    double volume(Scene scene) const;
    void setVolume(Scene scene, double volume);

    // ✅ 2026-02-26 [Phase 7.47.19]: 添加采样率配置
    int sampleRate(Scene scene) const;
    void setSampleRate(Scene scene, int rate);

    // 获取模型信息
    QString modelName(int index) const;
    int maxSpeakerId(int modelIndex) const;
    QStringList modelNames() const;

    // ✅ 2026-02-27 02:10 [Phase 7.47.28]: 通用键值存储（供QML批量合成参数持久化）
    Q_INVOKABLE void setValue(const QString &key, const QVariant &value);
    Q_INVOKABLE QVariant getValue(const QString &key, const QVariant &defaultValue = QVariant()) const;

signals:
    void configChanged(Scene scene);

private:
    explicit TTSConfigManager(QObject *parent = nullptr);

    QString sceneKey(Scene scene) const;

    QSettings *m_settings;

    // 场景配置缓存
    struct SceneConfig {
        int modelIndex;
        QString modelPath;
        int speakerId;
        double rate;
        double volume;
        int sampleRate;  // ✅ 2026-02-26 [Phase 7.47.19]: 采样率
    };

    QMap<Scene, SceneConfig> m_configs;
};

#endif // TTSCONFIGMANAGER_H
