// Theme.qml - 全局主题单例
// 基于 Tesla + industrial-controls 的最佳实践
// 创建日期: 2026-02-10
// Phase 7.45.13

pragma Singleton
import QtQuick 2.15

QtObject {
    // ========== 颜色定义 ==========

    // 主色调（Tesla 风格）
    readonly property color primary: "#17161c"          // 深黑背景
    readonly property color accent: "#439df3"           // 亮蓝强调
    readonly property color surface: "#1a1f2e"          // 表面灰
    readonly property color surfaceLight: "#2a3f5f"     // 浅表面灰

    // 状态色（工业标准）
    readonly property color success: "#2bbe6d"          // 绿色（正常）
    readonly property color warning: "#ffa300"          // 橙色（警告）
    readonly property color error: "#e40b0b"            // 红色（错误）
    readonly property color info: "#19d6c4"             // 青色（信息）

    // 文字色
    readonly property color textPrimary: "#ffffff"      // 主要文字
    readonly property color textSecondary: "#5a6f8f"    // 次要文字
    readonly property color textDisabled: "#3a4f6f"     // 禁用文字

    // 边框色
    readonly property color borderPrimary: "#00d4ff"    // 主要边框
    readonly property color borderSecondary: "#2a3f5f"  // 次要边框

    // ========== 尺寸定义 ==========

    readonly property int baseSize: 32                  // 基准尺寸
    readonly property int spacing: 16                   // 标准间距
    readonly property int spacingSmall: 8               // 小间距
    readonly property int spacingLarge: 24              // 大间距
    readonly property int radius: 8                     // 圆角半径
    readonly property int radiusSmall: 5                // 小圆角
    readonly property int radiusLarge: 12               // 大圆角
    readonly property int borderWidth: 2                // 边框宽度
    readonly property int borderWidthThin: 1            // 细边框

    // ========== 字体定义 ==========

    readonly property string fontFamily: "Microsoft YaHei"
    readonly property string fontFamilyMono: "Consolas"
    readonly property int fontSizeSmall: 10
    readonly property int fontSizeNormal: 12
    readonly property int fontSizeMedium: 14
    readonly property int fontSizeLarge: 16
    readonly property int fontSizeXLarge: 20
    readonly property int fontSizeXXLarge: 24

    // ========== 动画定义 ==========

    readonly property int animationDuration: 300        // 标准动画时长
    readonly property int animationDurationFast: 150    // 快速动画
    readonly property int animationDurationSlow: 500    // 慢速动画
    readonly property int animationEasing: Easing.OutCubic  // 缓动函数

    // ========== 阴影定义 ==========

    readonly property int shadowSize: 8                 // 阴影大小
    readonly property real shadowOpacity: 0.4           // 阴影透明度
    readonly property color shadowColor: "#000000"      // 阴影颜色

    // ========== 发光定义 ==========

    readonly property int glowRadius: 8                 // 发光半径
    readonly property int glowSamples: 10               // 发光采样数

    // ========== 辅助函数 ==========

    // 根据状态返回颜色
    function statusColor(status) {
        switch(status) {
            case "success":
            case "running":
            case "online":
                return success
            case "warning":
            case "pending":
                return warning
            case "error":
            case "fault":
            case "offline":
                return error
            case "info":
            case "idle":
                return info
            default:
                return textSecondary
        }
    }

    // 颜色加深
    function darker(color, factor) {
        return Qt.darker(color, factor || 1.2)
    }

    // 颜色变浅
    function lighter(color, factor) {
        return Qt.lighter(color, factor || 1.2)
    }
}
