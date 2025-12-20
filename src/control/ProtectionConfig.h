#ifndef PROTECTIONCONFIG_H
#define PROTECTIONCONFIG_H

#include <QString>
#include <QMetaType>

/**
 * @brief 保护配置数据结构 - 存储单个保护的所有配置参数
 *
 * 包含保护的基本信息、硬件配置、报警参数等
 */
struct ProtectionConfig {
    // 基本信息
    QString name;                   // 保护名称（如"急停"、"速度"等）
    QString type;                   // 保护类型："analog" 或 "digital"

    // 硬件配置
    QString moduleType;             // 模块类型（如"输入模块1"、"模拟量模块1"）
    int registerAddress;            // 寄存器地址
    int channelNumber;              // 通道编号（开关量使用0-7）
    int relayAddress;               // 继电器地址

    // 模拟量参数
    double upperLimit;              // 上限值
    double lowerLimit;              // 下限值
    double range;                   // 量程
    double ratedValue;              // 额定值（仅速度保护使用）
    QString unit;                   // 单位（如"m/s"、"℃"等）

    // 报警参数
    double protectionDelay;         // 保护延时（秒）
    QString playMode;               // 播放模式："count"(按次数) 或 "duration"(按时长)
    int playCount;                  // 播放次数（默认2遍）
    double playDuration;            // 播放时长（秒）

    // 语音报警配置
    bool useTextToSpeech;           // 是否使用文字转语音
    QString ttsText;                // TTS 文字内容
    QString audioFile;              // 音频文件路径

    // UI 配置
    bool enablePopupAnimation;      // 是否启用弹窗动画

    // 默认构造函数
    ProtectionConfig()
        : type("analog")
        , moduleType("模拟量模块1")
        , registerAddress(5)
        , channelNumber(0)
        , relayAddress(50)
        , upperLimit(100.0)
        , lowerLimit(0.0)
        , range(100.0)
        , ratedValue(50.0)
        , unit("m/s")
        , protectionDelay(1.0)
        , playMode("count")           // 默认按次数播放
        , playCount(2)                // 默认2遍
        , playDuration(5.0)
        , useTextToSpeech(true)
        , enablePopupAnimation(true)
    {}

    // 带参数的构造函数
    ProtectionConfig(const QString &n, const QString &t)
        : name(n)
        , type(t)
        , moduleType(t == "analog" ? "模拟量模块1" : "输入模块1")
        , registerAddress(t == "analog" ? 5 : 2)
        , channelNumber(0)
        , relayAddress(50)
        , upperLimit(100.0)
        , lowerLimit(0.0)
        , range(100.0)
        , ratedValue(50.0)
        , unit("m/s")
        , protectionDelay(1.0)
        , playMode("count")           // 默认按次数播放
        , playCount(2)                // 默认2遍
        , playDuration(5.0)
        , useTextToSpeech(true)
        , ttsText(n + "保护报警")
        , audioFile("alarm_high.wav")
        , enablePopupAnimation(true)
    {}
};

// 注册为 Qt 元类型，以便在 QML 中使用
Q_DECLARE_METATYPE(ProtectionConfig)

#endif // PROTECTIONCONFIG_H
