// ✅ 2026-01-25 [QDS后端模拟] C++ 后端类型模拟
// 用途：在 QDS 中模拟 C++ 注册的 QML 类型，使 QDS 能够运行应用程序
// 注意：这只是模拟，实际运行时会使用真实的 C++ 后端

import QtQuick 2.15

QtObject {
    id: mockBackend

    // ========== 模拟 CommonControl ==========
    property QtObject commonControl: QtObject {
        // 设备信息
        property int deviceId: 1
        property string deviceName: "1号皮带"
        property string deviceIp: "192.168.1.100"
        property int devicePort: 8080

        // 运行状态
        property bool isRunning: true
        property double currentSpeed: 1.5
        property double targetSpeed: 2.0
        property int direction: 1  // 1: 正转, -1: 反转

        // ✅ 2026-01-28 [FIX 100.300.61]: 添加缺失的信号
        signal deviceStatusChanged(string deviceName, bool isRunning)
        signal protectionTriggered(string protectionType)
        signal protectionRestored(string protectionType)

        // 模拟方法
        function startDevice() {
            console.log("模拟：启动设备")
            isRunning = true
        }

        function stopDevice() {
            console.log("模拟：停止设备")
            isRunning = false
        }

        function setSpeed(speed) {
            console.log("模拟：设置速度", speed)
            targetSpeed = speed
        }

        function setDirection(dir) {
            console.log("模拟：设置方向", dir)
            direction = dir
        }

        // ✅ 2026-01-28 [FIX 100.300.61]: 添加缺失的方法
        function setDeviceFeedbackConfig(deviceName, useFeedback, feedbackChannel, feedbackDelay) {
            console.log("模拟：设置设备反馈配置", deviceName, useFeedback, feedbackChannel, feedbackDelay)
        }
    }

    // ========== 模拟 DeviceInfoController ==========
    property QtObject deviceInfoController: QtObject {
        property var motorList: [
            { id: 1, name: "1号电机", status: "运行中", speed: 1500, temperature: 45 },
            { id: 2, name: "2号电机", status: "运行中", speed: 1500, temperature: 42 },
            { id: 3, name: "3号电机", status: "停止", speed: 0, temperature: 25 },
            { id: 4, name: "4号电机", status: "运行中", speed: 1500, temperature: 48 },
            { id: 5, name: "5号电机", status: "运行中", speed: 1500, temperature: 43 },
            { id: 6, name: "6号电机", status: "运行中", speed: 1500, temperature: 46 },
            { id: 7, name: "7号电机", status: "停止", speed: 0, temperature: 26 },
            { id: 8, name: "8号电机", status: "运行中", speed: 1500, temperature: 44 }
        ]

        function getMotorInfo(motorId) {
            console.log("模拟：获取电机信息", motorId)
            return motorList[motorId]
        }

        function setMotorConfig(motorId, config) {
            console.log("模拟：设置电机配置", motorId, JSON.stringify(config))
        }
    }

    // ========== 模拟 SipPhoneManager ==========
    property QtObject sipPhoneManager: QtObject {
        property bool isRegistered: false
        property bool isInCall: false
        property string currentCallNumber: ""

        function makeCall(number) {
            console.log("模拟：拨打电话", number)
            isInCall = true
            currentCallNumber = number
        }

        function hangup() {
            console.log("模拟：挂断电话")
            isInCall = false
            currentCallNumber = ""
        }

        function answer() {
            console.log("模拟：接听电话")
            isInCall = true
        }
    }

    // ========== 模拟 AudioManagementController ==========
    property QtObject audioManagementController: QtObject {
        property var ttsModels: [
            { id: "vits-zh-hf-theresa", name: "Theresa（女声）", language: "zh_CN" },
            { id: "vits-zh-hf-eula", name: "Eula（女声）", language: "zh_CN" },
            { id: "vits-zh-hf-fanchen-C", name: "Fanchen-C（男声）", language: "zh_CN" }
        ]

        property string currentModel: "vits-zh-hf-theresa"
        property int currentSpeakerId: 0
        property double speechRate: 1.0

        function setTTSModel(modelId) {
            console.log("模拟：设置TTS模型", modelId)
            currentModel = modelId
        }

        function setSpeakerId(speakerId) {
            console.log("模拟：设置说话人ID", speakerId)
            currentSpeakerId = speakerId
        }

        function setSpeechRate(rate) {
            console.log("模拟：设置语速", rate)
            speechRate = rate
        }

        function testVoice(text) {
            console.log("模拟：测试语音", text)
        }
    }

    // ========== 模拟报警数据 ==========
    property var alarmList: [
        { id: 1, time: "2026-01-25 10:30:15", level: "严重", device: "1号电机", message: "电流过载" },
        { id: 2, time: "2026-01-25 10:25:42", level: "警告", device: "2号电机", message: "温度偏高" },
        { id: 3, time: "2026-01-25 10:20:18", level: "提示", device: "3号电机", message: "速度波动" }
    ]

    // ========== 模拟开关量输入 ==========
    property var switchInputs: [
        { id: 0, name: "急停按钮", status: false },
        { id: 1, name: "启动按钮", status: true },
        { id: 2, name: "停止按钮", status: false },
        { id: 3, name: "前进限位", status: false },
        { id: 4, name: "后退限位", status: false },
        { id: 5, name: "门禁开关", status: true },
        { id: 6, name: "光电传感器1", status: true },
        { id: 7, name: "光电传感器2", status: false }
    ]

    // ========== 模拟模拟量输入 ==========
    property var analogInputs: [
        { id: 0, name: "速度反馈", value: 1.5, unit: "m/s", min: 0, max: 5 },
        { id: 1, name: "电流反馈", value: 12.3, unit: "A", min: 0, max: 50 },
        { id: 2, name: "温度传感器1", value: 45.2, unit: "℃", min: -20, max: 100 },
        { id: 3, name: "温度传感器2", value: 42.8, unit: "℃", min: -20, max: 100 }
    ]

    // ✅ 2026-01-28 [FIX 100.300.61]: 添加缺失的对象
    // ✅ 2026-01-28 [FIX 100.300.64]: 添加 workMode 和 warningMode 属性
    property QtObject systemConfig: QtObject {
        property string deviceName: "模拟设备"
        property int baudRate: 9600
        property string ipAddress: "192.168.1.100"
        property int port: 8080

        // ✅ 2026-01-28 [FIX 100.300.64]: 添加工作模式和预警模式
        property int workMode: 0  // 0=检修, 1=就地, 2=点动, 3=集控
        property int warningMode: 0  // 0=按时间, 1=按次数
        property int warningTimeSeconds: 10  // 起车预警时间（秒）
        property int warningPlayCount: 3  // 起车预警次数
        property string localDeviceName: "1号皮带"  // 本机名称
    }

    property QtObject operationLogDB: QtObject {
        signal logAdded(string message)

        function getRecentLogs(count) {
            return []
        }

        function addLog(message) {
            console.log("模拟：添加日志", message)
            logAdded(message)
        }
    }

    // ========== 初始化日志 ==========
    Component.onCompleted: {
        console.log("✅ QDS 后端模拟已加载")
        console.log("   - CommonControl: 已模拟")
        console.log("   - DeviceInfoController: 已模拟")
        console.log("   - SipPhoneManager: 已模拟")
        console.log("   - AudioManagementController: 已模拟")
        console.log("   - 报警数据: 已模拟")
        console.log("   - 开关量输入: 已模拟")
        console.log("   - 模拟量输入: 已模拟")
    }
}
