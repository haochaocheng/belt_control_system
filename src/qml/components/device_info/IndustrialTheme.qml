// ✅ 2026-01-25 [工业科技感设计] 工业主题配置
pragma Singleton
import QtQuick 2.15

QtObject {
    // ========== 配色方案 ==========

    // 背景色
    readonly property color backgroundColor: "#1a1f2e"        // 深蓝灰（主背景）
    readonly property color cardBackground: "#252b3d"         // 中蓝灰（卡片背景）
    readonly property color inputBackground: "#2d3548"        // 输入框背景

    // 强调色
    readonly property color primaryColor: "#2196F3"           // 科技蓝（主要强调）
    readonly property color primaryHover: "#42A5F5"           // 科技蓝（悬停）
    readonly property color primaryActive: "#1976D2"          // 科技蓝（激活）

    // 状态色
    readonly property color successColor: "#4CAF50"           // 成功/激活
    readonly property color warningColor: "#FF9800"           // 警告
    readonly property color errorColor: "#F44336"             // 错误/危险
    readonly property color inactiveColor: "#616161"          // 未激活

    // 文字颜色
    readonly property color textPrimary: "#E0E0E0"            // 主文字（浅灰）
    readonly property color textSecondary: "#9E9E9E"          // 次要文字（中灰）
    readonly property color textDisabled: "#616161"           // 禁用文字（深灰）
    readonly property color textHighlight: "#FFFFFF"          // 高亮文字（白色）

    // 边框颜色
    readonly property color borderNormal: "#3d4556"           // 普通边框
    readonly property color borderHover: "#2196F3"            // 悬停边框
    readonly property color borderActive: "#42A5F5"           // 激活边框

    // ========== 字体规范 ==========

    // 字体家族
    readonly property string fontFamily: "Roboto Mono, Consolas, Monaco, monospace"
    readonly property string fontFamilyUI: "Roboto, Microsoft YaHei, sans-serif"

    // 字体大小
    readonly property int fontSizeTitle: 18      // 标题
    readonly property int fontSizeNormal: 14     // 正文
    readonly property int fontSizeSmall: 12      // 小字
    readonly property int fontSizeLabel: 10      // 标签

    // 字体粗细
    readonly property int fontWeightNormal: Font.Normal
    readonly property int fontWeightMedium: Font.Medium
    readonly property int fontWeightBold: Font.Bold

    // ========== 间距规范 ==========

    // 内边距
    readonly property int paddingSmall: 8
    readonly property int paddingMedium: 16
    readonly property int paddingLarge: 24

    // 外边距
    readonly property int marginSmall: 4
    readonly property int marginMedium: 8
    readonly property int marginLarge: 16

    // 行高
    readonly property int lineHeight: 24
    readonly property int lineHeightLarge: 32

    // ========== 圆角和阴影 ==========

    // 圆角
    readonly property int radiusSmall: 2
    readonly property int radiusMedium: 4
    readonly property int radiusLarge: 8

    // 阴影（注意：QML 不直接支持 box-shadow，需要使用 DropShadow 效果）
    readonly property int shadowRadius: 8
    readonly property int shadowSamples: 16
    readonly property color shadowColor: "#80000000"  // 50% 黑色

    // ========== 尺寸规范 ==========

    // 控件高度
    readonly property int controlHeightSmall: 28
    readonly property int controlHeightNormal: 36
    readonly property int controlHeightLarge: 48

    // 列表项高度
    readonly property int listItemHeight: 48

    // 左侧列表宽度
    readonly property int sidebarWidth: 240

    // ========== 动画时长 ==========

    readonly property int animationDurationFast: 150
    readonly property int animationDurationNormal: 250
    readonly property int animationDurationSlow: 350
}
