/***********************************************************************************
**    Belt Control System - Unified Data Path Configuration
**    Copyright (C) 2025
**
**    此文件定义了所有配置文件和数据库文件的统一存储路径，
**    防止文件分散存储导致的误删问题。
**
**    统一数据目录结构：
**    appdata/                    # 主数据目录
**      ├── config.ini           # 系统配置文件
**      ├── alarm_history.db     # 报警历史数据库
**      ├── protection_config.db # 保护配置数据库
**      ├── device_config.db     # 设备配置数据库（2026-02-02新增）
**      ├── operation_logs.db    # 操作日志数据库
**      ├── contacts.db          # SIP联系人数据库
**      └── call_history.db      # SIP通话记录数据库
**
************************************************************************************/
#ifndef DATA_PATH_CONFIG_H
#define DATA_PATH_CONFIG_H

#include <QString>
#include <QCoreApplication>
#include <QDir>
#include <QDebug>

class DataPathConfig
{
public:
    /**
     * @brief 获取统一数据目录路径
     * @return 数据目录的绝对路径 (例如: /app/appdata 或 E:/project/appdata)
     */
    static QString getDataDirectory()
    {
        QString appPath = QCoreApplication::applicationDirPath();
        QString dataDir = appPath + "/appdata";

        // 确保数据目录存在
        QDir dir;
        if (!dir.exists(dataDir)) {
            if (dir.mkpath(dataDir)) {
                qDebug() << "✅ [DATA PATH] 创建数据目录:" << dataDir;
            } else {
                qWarning() << "⚠️ [DATA PATH] 无法创建数据目录:" << dataDir;
            }
        }

        return dataDir;
    }

    /**
     * @brief 获取系统配置文件完整路径
     * @return config.ini 的绝对路径
     */
    static QString getConfigFilePath()
    {
        return getDataDirectory() + "/config.ini";
    }

    /**
     * @brief 获取报警历史数据库完整路径
     * @return alarm_history.db 的绝对路径
     */
    static QString getAlarmHistoryDbPath()
    {
        return getDataDirectory() + "/alarm_history.db";
    }

    /**
     * @brief 获取保护配置数据库完整路径
     * @return protection_config.db 的绝对路径
     */
    static QString getProtectionConfigDbPath()
    {
        return getDataDirectory() + "/protection_config.db";
    }

    /**
     * @brief 获取设备配置数据库完整路径
     * @return device_config.db 的绝对路径
     * @note 2026-02-02 [FIX 100.300.112.8.20]: 新增设备配置数据库路径
     */
    static QString getDeviceConfigDbPath()
    {
        return getDataDirectory() + "/device_config.db";
    }

    /**
     * @brief 获取操作日志数据库完整路径
     * @return operation_logs.db 的绝对路径
     */
    static QString getOperationLogDbPath()
    {
        return getDataDirectory() + "/operation_logs.db";
    }

    /**
     * @brief 获取SIP联系人数据库完整路径
     * @return contacts.db 的绝对路径
     */
    static QString getContactsDbPath()
    {
        return getDataDirectory() + "/contacts.db";
    }

    /**
     * @brief 获取SIP通话记录数据库完整路径
     * @return call_history.db 的绝对路径
     */
    static QString getCallHistoryDbPath()
    {
        return getDataDirectory() + "/call_history.db";
    }

    /**
     * @brief 获取SIP账户配置文件完整路径
     * @return sip_accounts.ini 的绝对路径
     */
    static QString getSipAccountsConfigPath()
    {
        return getDataDirectory() + "/sip_accounts.ini";
    }

    /**
     * @brief 获取TTS缓存目录完整路径
     * @return tts_cache 目录的绝对路径
     */
    static QString getTtsCacheDirectory()
    {
        QString cacheDir = getDataDirectory() + "/tts_cache";

        // 确保TTS缓存目录存在
        QDir dir;
        if (!dir.exists(cacheDir)) {
            if (dir.mkpath(cacheDir)) {
                qDebug() << "✅ [DATA PATH] 创建TTS缓存目录:" << cacheDir;
            } else {
                qWarning() << "⚠️ [DATA PATH] 无法创建TTS缓存目录:" << cacheDir;
            }
        }

        return cacheDir;
    }

    /**
     * @brief 获取音频文件基础目录
     * @return 音频文件目录的绝对路径
     *
     * ✅ 2026-02-28 [Phase 7.47.43]: 新增统一音频路径函数
     * 说明：
     *   - 路径通过环境变量 BELT_CONTROL_USER 决定（Docker启动时注入）
     *   - 与 Docker 挂载卷一致：/home/{user}/belt-control-data/audio
     *   - 与 QML getOutputBaseDir() 返回值保持一致
     *   - BatchAudioGenerator 生成到此目录，MqttProtectionMonitor 也从此目录读取
     *
     * Docker volume 挂载：
     *   -v /home/{user}/belt-control-data/audio:/home/{user}/belt-control-data/audio:rw
     */
    static QString getAudioBaseDirectory()
    {
        // 从环境变量获取用户名（由 Docker 启动脚本注入 BELT_CONTROL_USER=linaro/pi）
        // 2026-02-28 [Phase 7.47.43]: 默认值 linaro，与 QML getOutputBaseDir() 一致
        QString userName = qEnvironmentVariable("BELT_CONTROL_USER", "linaro");
        return QString("/home/%1/belt-control-data/audio").arg(userName);
    }

    /**
     * @brief 输出所有数据文件路径信息（用于调试）
     */
    static void printAllPaths()
    {
        qDebug() << "========== 数据文件路径配置 ==========";
        qDebug() << "数据目录:" << getDataDirectory();
        qDebug() << "配置文件:" << getConfigFilePath();
        qDebug() << "报警历史数据库:" << getAlarmHistoryDbPath();
        qDebug() << "保护配置数据库:" << getProtectionConfigDbPath();
        qDebug() << "设备配置数据库:" << getDeviceConfigDbPath();  // ✅ 2026-02-02 [FIX 100.300.112.8.20]: 新增
        qDebug() << "操作日志数据库:" << getOperationLogDbPath();
        qDebug() << "联系人数据库:" << getContactsDbPath();
        qDebug() << "通话记录数据库:" << getCallHistoryDbPath();
        qDebug() << "SIP账户配置:" << getSipAccountsConfigPath();
        qDebug() << "TTS缓存目录:" << getTtsCacheDirectory();
        qDebug() << "=====================================";
    }
};

#endif // DATA_PATH_CONFIG_H
