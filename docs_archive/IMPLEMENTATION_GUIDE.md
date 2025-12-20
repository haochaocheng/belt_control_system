# SIP 功能实现指南

## ✅ 已完成的修复

### 1. PJSIP IOCP 后端修复
- 修改 `os-auto.mak` 使用 `ioqueue_winnt.o`
- Windows上使用IOCP而非select()
- 成功接收401 Unauthorized响应
- 完整注册流程正常工作

### 2. UI修复
- 修正注册状态检测(使用RisipAccount::SignedIn枚举)
- 修复QML属性赋值TypeError
- 修复拨号键盘功能

### 3. 右上角按钮布局优化
- 移除SipMainPage重复标题
- 缩小状态栏高度(60px→45px)
- 添加服务器状态显示
- 解决与Window关闭按钮的视觉冲突

---

## 📋 待实现功能

### 任务2: 实现配置保存功能

#### 问题分析
日志显示: `Configs files cannot be found nor be read!!`

这是因为Risip SDK期望配置文件,但当前SipPhoneManager没有实现配置持久化。

#### 实现方案

**步骤1: 添加配置管理类**

创建 `src/sip_phone/SipAccountConfig.h`:

```cpp
#ifndef SIPACCOUNTCONFIG_H
#define SIPACCOUNTCONFIG_H

#include <QObject>
#include <QSettings>
#include <QVariantList>

struct SipAccount {
    QString name;          // 账号名称(如"办公室")
    QString server;        // 服务器地址
    QString username;      // 用户名
    QString password;      // 密码(加密存储)
    int port;             // 端口
    bool isDefault;       // 是否默认账号
    bool autoRegister;    // 自动注册
};

class SipAccountConfig : public QObject {
    Q_OBJECT
public:
    explicit SipAccountConfig(QObject *parent = nullptr);

    // 保存/加载账号列表
    void saveAccounts(const QList<SipAccount> &accounts);
    QList<SipAccount> loadAccounts();

    // 单个账号操作
    void addAccount(const SipAccount &account);
    void removeAccount(const QString &name);
    void updateAccount(const SipAccount &account);

    // 获取默认账号
    SipAccount getDefaultAccount();

private:
    QSettings settings;
    QString encryptPassword(const QString &password);
    QString decryptPassword(const QString &encrypted);
};

#endif
```

**步骤2: 修改SipPhoneManager添加账号管理**

在 `src/sip_phone/SipPhoneManager.h` 添加:

```cpp
public slots:
    // 账号管理
    QVariantList getAccountList();
    void saveAccount(const QString &name, const QString &server,
                    const QString &username, const QString &password, int port);
    void deleteAccount(const QString &name);
    bool registerSavedAccount(const QString &name);

signals:
    void accountListChanged();
```

在 `src/sip_phone/SipPhoneManager.cpp` 实现:

```cpp
#include "SipAccountConfig.h"

SipPhoneManager::SipPhoneManager(QObject *parent) {
    // ...
    d->accountConfig = new SipAccountConfig(this);

    // 启动时加载默认账号
    SipAccount defaultAccount = d->accountConfig->getDefaultAccount();
    if (defaultAccount.autoRegister && !defaultAccount.username.isEmpty()) {
        registerAccount(defaultAccount.server, defaultAccount.username,
                       defaultAccount.password, defaultAccount.port);
    }
}

void SipPhoneManager::saveAccount(const QString &name, const QString &server,
                                  const QString &username, const QString &password, int port) {
    SipAccount account;
    account.name = name;
    account.server = server;
    account.username = username;
    account.password = password;
    account.port = port;
    account.isDefault = false;
    account.autoRegister = false;

    d->accountConfig->addAccount(account);
    emit accountListChanged();
}

QVariantList SipPhoneManager::getAccountList() {
    QVariantList result;
    QList<SipAccount> accounts = d->accountConfig->loadAccounts();
    for (const SipAccount &acc : accounts) {
        QVariantMap map;
        map["name"] = acc.name;
        map["server"] = acc.server;
        map["username"] = acc.username;
        map["port"] = acc.port;
        map["isDefault"] = acc.isDefault;
        map["autoRegister"] = acc.autoRegister;
        result.append(map);
    }
    return result;
}
```

**步骤3: 更新设置页面UI**

在 `src/qml/components/sip_phone/pages/SipSettingsPage.qml` 添加账号列表:

```qml
ColumnLayout {
    // ...现有的服务器设置输入框...

    // 保存账号按钮
    RisipButton {
        text: "保存账号配置"
        Layout.fillWidth: true
        onClicked: {
            SipPhoneManager.saveAccount(
                "账号" + (SipPhoneManager.getAccountList().length + 1),
                serverInput.text,
                usernameInput.text,
                passwordInput.text,
                portSpinBox.value
            )
        }
    }

    // 已保存账号列表
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 300
        color: "#0f3460"
        radius: 10

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 15

            Text {
                text: "已保存的账号"
                font.pixelSize: 16
                font.bold: true
                color: "#00d4ff"
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: SipPhoneManager.getAccountList()
                delegate: Rectangle {
                    width: parent.width
                    height: 60
                    color: "#16213e"
                    radius: 8

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            Text {
                                text: modelData.name
                                font.pixelSize: 14
                                font.bold: true
                                color: "white"
                            }
                            Text {
                                text: modelData.username + "@" + modelData.server
                                font.pixelSize: 12
                                color: "#7f8c8d"
                            }
                        }

                        RisipButton {
                            text: "使用"
                            onClicked: {
                                SipPhoneManager.registerSavedAccount(modelData.name)
                            }
                        }

                        RisipButton {
                            text: "删除"
                            onClicked: {
                                SipPhoneManager.deleteAccount(modelData.name)
                            }
                        }
                    }
                }
            }
        }
    }
}
```

---

### 任务3: 添加历史记录功能

#### 实现方案

**步骤1: 在SipPhoneManager中集成RisipCallHistoryModel**

在 `src/sip_phone/SipPhoneManager.h`:

```cpp
Q_PROPERTY(QObject* callHistoryModel READ callHistoryModel CONSTANT)

public:
    QObject* callHistoryModel() const;

private:
    risip::RisipCallHistoryModel *m_callHistoryModel;
```

在 `src/sip_phone/SipPhoneManager.cpp`:

```cpp
SipPhoneManager::SipPhoneManager(QObject *parent) {
    // ...
    d->callHistoryModel = new risip::RisipCallHistoryModel(this);
}

QObject* SipPhoneManager::callHistoryModel() const {
    return d->callHistoryModel;
}

// 在makeCall()中记录呼出
void SipPhoneManager::makeCall(const QString &number) {
    // ...拨号代码...

    // 记录到历史
    if (d->currentCall) {
        d->callHistoryModel->addCallRecord(d->currentCall);
    }
}

// 连接通话信号,在通话结束时自动记录
connect(callManager, &risip::RisipCallManager::callEnded, this, [this](risip::RisipCall *call) {
    if (call) {
        d->callHistoryModel->addCallRecord(call);
    }
});
```

**步骤2: 更新历史页面显示历史记录**

在 `src/qml/components/sip_phone/pages/SipHistoryPage.qml`:

```qml
ListView {
    anchors.fill: parent
    model: SipPhoneManager.callHistoryModel

    delegate: Rectangle {
        width: parent.width
        height: 80
        color: index % 2 === 0 ? "#16213e" : "#1a1a2e"

        RowLayout {
            anchors.fill: parent
            anchors.margins: 15

            // 方向图标
            Text {
                text: model.callDirection === 0 ? "📞→" : "📞←"
                font.pixelSize: 24
            }

            ColumnLayout {
                Layout.fillWidth: true

                Text {
                    text: model.callContact || "未知号码"
                    font.pixelSize: 16
                    font.bold: true
                    color: "white"
                }

                Text {
                    text: new Date(model.callTimestamp).toLocaleString()
                    font.pixelSize: 12
                    color: "#7f8c8d"
                }

                Text {
                    text: "时长: " + Math.floor(model.callDuration / 60) + ":" +
                          (model.callDuration % 60).toString().padStart(2, '0')
                    font.pixelSize: 12
                    color: "#95a5a6"
                }
            }

            RisipButton {
                text: "回拨"
                onClicked: {
                    callNumber(model.callContact)
                }
            }
        }
    }
}
```

---

### 任务4: 添加视频通话功能

这是最复杂的任务,需要重新编译PJSIP并大量UI/C++修改。

#### 步骤1: 启用PJSIP视频支持

编辑 `F:\0\pjproject-2.15.1\pjproject-2.15.1\pjlib\include\pj\config_site.h`:

```c
// 启用视频
#define PJMEDIA_HAS_VIDEO 1

// Windows DirectShow支持
#define PJMEDIA_VIDEO_DEV_HAS_DSHOW 1

// SDL视频渲染(可选)
#define PJMEDIA_VIDEO_DEV_HAS_SDL 1

// 视频编解码器
#define PJMEDIA_HAS_OPENH264_CODEC 1  // 需要OpenH264库
#define PJMEDIA_HAS_VPX_CODEC 1       // 需要libvpx
```

#### 步骤2: 重新编译PJSIP

修改 `F:\0\pjproject-2.15.1\rebuild_pjsip_iocp.ps1`,添加视频模块:

```powershell
$modules = @(
    "pjlib",
    "pjlib-util",
    "pjnath",
    "pjmedia",
    "pjsip",
    "third_party/build/srtp",      # SRTP for secure video
    "third_party/build/yuv"        # YUV video processing
)
```

运行重新编译:
```powershell
powershell -ExecutionPolicy Bypass -File F:\0\pjproject-2.15.1\rebuild_pjsip_iocp.ps1
```

#### 步骤3: C++ 视频支持

在 `src/sip_phone/SipPhoneManager.h`:

```cpp
Q_PROPERTY(bool videoCallEnabled READ videoCallEnabled WRITE setVideoCallEnabled NOTIFY videoCallEnabledChanged)
Q_PROPERTY(QObject* localVideoSurface READ localVideoSurface CONSTANT)
Q_PROPERTY(QObject* remoteVideoSurface READ remoteVideoSurface CONSTANT)

public slots:
    void startVideo();
    void stopVideo();
    void toggleCamera();

signals:
    void videoCallEnabledChanged(bool enabled);
```

#### 步骤4: QML视频窗口

创建 `src/qml/components/sip_phone/VideoCallWindow.qml`:

```qml
import QtQuick 6.5
import QtMultimedia 6.5

Rectangle {
    width: 640
    height: 480
    color: "black"

    // 远程视频(全屏)
    VideoOutput {
        id: remoteVideo
        anchors.fill: parent
        source: SipPhoneManager.remoteVideoSurface
    }

    // 本地预览(小窗口)
    VideoOutput {
        id: localVideo
        width: 160
        height: 120
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        source: SipPhoneManager.localVideoSurface
    }

    // 控制按钮
    RowLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 30

        RisipButton {
            text: "关闭摄像头"
            onClicked: SipPhoneManager.toggleCamera()
        }

        RisipButton {
            text: "挂断"
            onClicked: SipPhoneManager.hangupCall()
        }
    }
}
```

---

## 🌍 跨平台编译配置

### ARM64 Linux编译

在ARM64设备上:

```bash
cd /path/to/pjproject-2.15.1
./configure --host=aarch64-linux-gnu
make dep && make -j4

# 复制库文件
mkdir -p /path/to/project/libs/pjsip/linux-aarch64
cp */lib/*.a /path/to/project/libs/pjsip/linux-aarch64/
```

### CMake跨平台配置

修改 `src/risip/CMakeLists.txt`:

```cmake
# 根据平台选择库路径
if(WIN32)
    if(CMAKE_SIZEOF_VOID_P EQUAL 8)
        set(PJSIP_LIB_SUBDIR "windows-x64")
    endif()
elseif(UNIX AND NOT APPLE)
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64")
        set(PJSIP_LIB_SUBDIR "linux-aarch64")
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64")
        set(PJSIP_LIB_SUBDIR "linux-x64")
    endif()
endif()

set(PROJECT_LIBS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../libs/pjsip/${PJSIP_LIB_SUBDIR}")

if(NOT EXISTS ${PROJECT_LIBS_DIR})
    message(FATAL_ERROR "PJSIP libraries not found for platform: ${PJSIP_LIB_SUBDIR}")
endif()
```

---

## 📝 测试检查清单

### 配置保存功能
- [ ] 保存账号后重启应用,账号列表依然存在
- [ ] 选择默认账号,下次启动自动使用
- [ ] 删除账号正常工作
- [ ] 密码加密存储,不是明文

### 历史记录功能
- [ ] 拨出电话后,历史记录中出现
- [ ] 接听电话后,历史记录中出现
- [ ] 显示正确的通话时长
- [ ] 回拨功能正常

### 视频通话功能
- [ ] 视频通话界面正常显示
- [ ] 本地摄像头预览正常
- [ ] 远程视频接收正常
- [ ] 开关摄像头功能正常

---

## 🐛 已知问题

1. **Git推送需要认证** - 需要配置凭据后手动推送
2. **Risip配置文件警告** - 实现配置保存后解决

---

## 📚 参考资料

- PJSIP文档: https://www.pjsip.org/docs/latest/pjsip/docs/html/
- Qt QSettings: https://doc.qt.io/qt-6/qsettings.html
- Qt Multimedia: https://doc.qt.io/qt-6/qtmultimedia-index.html

