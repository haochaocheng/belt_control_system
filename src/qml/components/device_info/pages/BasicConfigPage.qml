import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// ✅ 2026-01-24 [设备信息界面重构] Phase 2: 基本配置页面
// 复用现有的 BasicParametersSection 和 NetworkParametersSection 组件
Rectangle {
    id: root
    // ✅ 2026-01-26 [FIX 100.300.25.12]: 明确设置尺寸，确保运行时正确显示
    implicitWidth: 800
    implicitHeight: 600
    color: "transparent"

    // ========== 公开属性 ==========
    property int deviceId: 1
    property string deviceName: ""

    // ========== 内容区域 ==========
    ScrollView {
        id: scrollView
        anchors.fill: parent
        clip: true

        // 滚动条样式
        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: scrollView.width
            spacing: 20

            // 页面标题
            Text {
                text: "基本配置 - " + root.deviceName
                font.pixelSize: 22
                font.bold: true
                color: "#00d4ff"
                Layout.fillWidth: true
                Layout.topMargin: 10
                Layout.leftMargin: 10
            }

            // ✅ 复用基本参数组件
            Loader {
                id: basicParamsLoader
                Layout.fillWidth: true
                Layout.preferredHeight: 400
                Layout.leftMargin: 10
                Layout.rightMargin: 10

                source: "qrc:/qt/qml/BeltControlQml/components/parameter_settings/BasicParametersSection.qml"

                onLoaded: {
                    console.log("✅ [BasicConfigPage] BasicParametersSection 加载成功")
                    // TODO: 绑定设备配置数据
                    // if (item && deviceConfigManager) {
                    //     item.systemConfig = deviceConfigManager.getDeviceConfig(root.deviceId)
                    // }
                }

                onStatusChanged: {
                    if (basicParamsLoader.status === Loader.Error) {
                        console.error("❌ [BasicConfigPage] BasicParametersSection 加载失败")
                    }
                }
            }

            // ✅ 复用网络参数组件
            Loader {
                id: networkParamsLoader
                Layout.fillWidth: true
                Layout.preferredHeight: 200
                Layout.leftMargin: 10
                Layout.rightMargin: 10

                source: "qrc:/qt/qml/BeltControlQml/components/parameter_settings/NetworkParametersSection.qml"

                onLoaded: {
                    console.log("✅ [BasicConfigPage] NetworkParametersSection 加载成功")
                    // TODO: 绑定设备配置数据
                    // if (item && deviceConfigManager) {
                    //     var config = deviceConfigManager.getDeviceConfig(root.deviceId)
                    //     item.ipAddress = config.networkParams.ipAddress
                    //     item.subnetMask = config.networkParams.subnetMask
                    //     item.gateway = config.networkParams.gateway
                    // }
                }

                onStatusChanged: {
                    if (networkParamsLoader.status === Loader.Error) {
                        console.error("❌ [BasicConfigPage] NetworkParametersSection 加载失败")
                    }
                }
            }

            // 底部填充空间
            Item {
                Layout.fillHeight: true
                Layout.preferredHeight: 20
            }
        }
    }
}
