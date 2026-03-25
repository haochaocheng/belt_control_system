import QtQuick
import QtQuick.VirtualKeyboard
import QtQuick.VirtualKeyboard.Settings

QtObject {
    Component.onCompleted: {
        // Configure virtual keyboard settings
        console.log("[VirtualKeyboard] Configuring settings...")

        // ✅ 2026-03-25 [Phase 7.48.88.15]: 中文拼音输入法通过 main.cpp 环境变量配置
        // QT_VIRTUALKEYBOARD_LOCALE=zh_CN（默认中文拼音）
        // 旧代码注释：Note: VirtualKeyboardSettings is read-only in Qt 6
        // 实际上 activeLocales 和 locale 在 Qt 6.5 中可写，但环境变量方式更可靠
        console.log("[VirtualKeyboard] Current locale:", VirtualKeyboardSettings.locale)

        console.log("[VirtualKeyboard] Settings configured")
    }
}
