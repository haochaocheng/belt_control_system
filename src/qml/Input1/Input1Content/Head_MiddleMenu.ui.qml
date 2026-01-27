import QtQuick

// ✅ 2026-01-20 [FIX 100.255] 菜单组件 - 支持文字和高亮状态切换
// ✅ 2026-01-20 [FIX 100.269]: 修正选中逻辑 - 改变 root 的图片，而不是 backgroundImage
// ✅ 2026-01-20 [FIX 100.270]: 移除 JavaScript 代码块以兼容 QDS
Image {
    id: root
    // ✅ 根据 isActive 切换 root 的图片
    source: isActive ? "images/head_menuOK.png" : "images/head_MiddleMenu1.png"
    fillMode: Image.PreserveAspectFit

    // 可配置属性
    property string menuText: "首页" // 菜单文字
    property bool isActive: false // 是否是当前页面

    // 背景图片（固定不变）
    // ✅ 2026-01-20 [FIX 100.267/100.269]: 位置调整为用户测试后的值
    Image {
        id: backgroundImage
        x: -3  // 用户调整后的位置
        y: 8   // 用户调整后的位置
        source: "images/head_MiddleMenu2.png"  // ✅ 固定不变
        fillMode: Image.PreserveAspectFit
    }

    // 菜单文字 - ✅ 2026-01-20 [FIX 100.257]: 居中对齐
    Text {
        id: menuLabel
        anchors.centerIn: parent
        color: "#ffffff"
        text: root.menuText
        font.pixelSize: 21
        font.family: "Verdana"
    }
}
