# Risip SDK 快速开始指南

## 5 分钟快速配置

### 步骤 1: 编译 PJSIP (必须)

```bash
# 进入 PJSIP 目录
cd F:\0\pjproject-2.15.1\pjproject-2.15.1

# MinGW 编译 (推荐)
./configure --prefix=/mingw64
make dep
make

# 或者 Visual Studio 编译
.\configure-win32.bat
msbuild pjproject-vs14.sln /p:Configuration=Release
```

### 步骤 2: 构建项目

```bash
# 回到项目根目录
cd e:\2025\3_gongkongji\belt_control_system

# 配置并构建
cmake -B build -S .
cmake --build build
```

### 步骤 3: 运行程序

```bash
./build/bin_windows/belt_control_system.exe
```

## 快速测试

### 测试 1: 初始化

在 QML 中:
```qml
Component.onCompleted: {
    SipPhoneManager.initializeEndpoint()
}
```

### 测试 2: 注册

```qml
Button {
    text: "注册"
    onClicked: {
        SipPhoneManager.registerAccount(
            "你的SIP服务器IP",
            "用户名",
            "密码",
            5060
        )
    }
}
```

### 测试 3: 拨号

```qml
Button {
    text: "呼叫 1002"
    onClicked: {
        SipPhoneManager.makeCall("1002")
    }
}
```

## 故障排除

### 问题: PJSIP 头文件未找到

**错误信息:**
```
fatal error: pjsua2.hpp: No such file or directory
```

**解决方案:**
1. 确认 PJSIP 已安装在 `F:\0\pjproject-2.15.1\pjproject-2.15.1`
2. 检查 [CMakeLists.txt](CMakeLists.txt:160) 中的 `PJSIP_ROOT` 路径
3. 确保 PJSIP 源码已下载完整

### 问题: 链接错误

**错误信息:**
```
undefined reference to `pj::Endpoint::...`
```

**解决方案:**
1. 确认 PJSIP 已编译 (`make` 命令执行成功)
2. 检查 `pjsip/lib/` 目录中是否有 `.a` 或 `.lib` 文件
3. 更新 CMakeLists.txt 中的库文件路径

### 问题: 注册失败

**错误信息:**
```
Registration failed: 408 Request Timeout
```

**解决方案:**
1. 检查 SIP 服务器是否运行
2. 确认服务器 IP 地址和端口正确
3. 检查网络连接
4. 验证用户名密码

## API 速查

### 初始化
```cpp
SipPhoneManager::instance()->initializeEndpoint();
```

### 注册
```cpp
SipPhoneManager::instance()->registerAccount(
    "192.168.1.100",  // 服务器
    "1001",           // 用户名
    "password",       // 密码
    5060              // 端口
);
```

### 拨号
```cpp
SipPhoneManager::instance()->makeCall("1002");
```

### 挂断
```cpp
SipPhoneManager::instance()->hangupCall();
```

### 音量控制
```cpp
SipPhoneManager::instance()->setMicrophoneVolume(80);  // 0-100
SipPhoneManager::instance()->setSpeakerVolume(70);     // 0-100
```

## 信号监听

```qml
Connections {
    target: SipPhoneManager

    function onRegistrationSuccess() {
        console.log("✅ 注册成功")
    }

    function onRegistrationFailed(reason) {
        console.log("❌ 注册失败:", reason)
    }

    function onCallConnected() {
        console.log("📞 通话接通")
    }

    function onCallDisconnected() {
        console.log("📞 通话结束")
    }

    function onIncomingCall(number, name) {
        console.log("📲 来电:", number, name)
    }

    function onErrorOccurred(error) {
        console.log("⚠️ 错误:", error)
    }
}
```

## 属性绑定

```qml
// 显示状态
Text {
    text: SipPhoneManager.isRegistered ? "已注册" : "未注册"
}

Text {
    text: "状态: " + SipPhoneManager.callStatus
}

Text {
    text: "通话时长: " + SipPhoneManager.callDuration + "秒"
    visible: SipPhoneManager.isInCall
}

// 按钮启用状态
Button {
    text: "拨号"
    enabled: SipPhoneManager.isRegistered && !SipPhoneManager.isInCall
}

Button {
    text: "挂断"
    enabled: SipPhoneManager.isInCall
}
```

## 完整示例

```qml
import QtQuick
import QtQuick.Controls
import BeltControl.SipPhone 1.0

ApplicationWindow {
    width: 400
    height: 600
    visible: true

    Component.onCompleted: {
        SipPhoneManager.initializeEndpoint()
    }

    Column {
        anchors.centerIn: parent
        spacing: 20

        // 状态显示
        Text {
            text: "服务器: " + SipPhoneManager.serverStatus
        }

        Text {
            text: "通话状态: " + SipPhoneManager.callStatus
        }

        Text {
            text: "通话时长: " + SipPhoneManager.callDuration + "秒"
            visible: SipPhoneManager.isInCall
        }

        // 注册按钮
        Button {
            text: SipPhoneManager.isRegistered ? "已注册" : "注册"
            enabled: !SipPhoneManager.isRegistered
            onClicked: {
                SipPhoneManager.registerAccount(
                    "192.168.1.100",
                    "1001",
                    "password",
                    5060
                )
            }
        }

        // 输入号码
        TextField {
            id: numberInput
            placeholderText: "输入号码"
            enabled: SipPhoneManager.isRegistered
        }

        // 拨号按钮
        Button {
            text: "呼叫"
            enabled: SipPhoneManager.isRegistered &&
                     !SipPhoneManager.isInCall &&
                     numberInput.text.length > 0
            onClicked: {
                SipPhoneManager.makeCall(numberInput.text)
            }
        }

        // 挂断按钮
        Button {
            text: "挂断"
            enabled: SipPhoneManager.isInCall
            onClicked: {
                SipPhoneManager.hangupCall()
            }
        }

        // 音量控制
        Slider {
            from: 0
            to: 100
            value: 80
            onValueChanged: {
                SipPhoneManager.setSpeakerVolume(value)
            }
        }
    }

    // 监听事件
    Connections {
        target: SipPhoneManager

        function onRegistrationSuccess() {
            console.log("注册成功")
        }

        function onCallConnected() {
            console.log("通话接通")
        }

        function onIncomingCall(number) {
            console.log("来电:", number)
            // 自动接听
            SipPhoneManager.answerCall()
        }

        function onErrorOccurred(error) {
            console.log("错误:", error)
        }
    }
}
```

## 下一步

- 阅读 [README.md](README.md) 了解详细技术文档
- 查看 [RISIP_INTEGRATION.md](../../RISIP_INTEGRATION.md) 了解集成详情
- 参考现有 UI: [src/qml/components/sip_phone/](../../qml/components/sip_phone/)

## 获取帮助

如遇问题:
1. 检查本文档的"故障排除"部分
2. 查看 PJSIP 官方文档: https://www.pjsip.org/docs/
3. 检查 CMake 构建输出的错误信息
