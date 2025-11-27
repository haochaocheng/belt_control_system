# Risip SDK 集成文件结构

## 概览

本文档详细说明了 Risip VoIP SDK 在皮带控制系统中的完整文件结构。

## 目录树

```
belt_control_system/
├── src/
│   ├── risip/                          # Risip SDK 主模块 ⭐ 新增
│   │   ├── core/                       # 核心功能代码
│   │   │   ├── risip.h/cpp            # Risip 主类,单例模式
│   │   │   ├── risipendpoint.h/cpp    # SIP endpoint 生命周期管理
│   │   │   ├── risipaccount.h/cpp     # SIP 账户注册/管理
│   │   │   ├── risipcall.h/cpp        # 通话控制
│   │   │   ├── risipbuddy.h/cpp       # 联系人管理
│   │   │   ├── risipmedia.h/cpp       # 音视频媒体控制
│   │   │   ├── risipmessage.h/cpp     # SIP 消息
│   │   │   ├── risipglobals.h/cpp     # 全局定义和工具
│   │   │   ├── risipphonecontact.h/cpp # 电话联系人
│   │   │   ├── risipphonenumber.h/cpp  # 电话号码
│   │   │   ├── risipratemanager.h/cpp  # 费率管理
│   │   │   ├── risipcontactimageprovider.h/cpp
│   │   │   ├── risipcountryflagimageprovider.h/cpp
│   │   │   ├── risipaccountconfiguration.h/cpp
│   │   │   ├── risipcallmanager.h/cpp
│   │   │   ├── risipcontactmanager.h/cpp
│   │   │   ├── risipsdkglobal.h       # SDK 导出宏
│   │   │   ├── models/                # 数据模型头文件
│   │   │   │   ├── risipmodels.h
│   │   │   │   ├── risipabstractbuddymodel.h
│   │   │   │   ├── risipaccountlistmodel.h
│   │   │   │   ├── risipcallhistorymodel.h
│   │   │   │   ├── risipcountryratesmodel.h
│   │   │   │   ├── risipphonecontactsmodel.h
│   │   │   │   └── risipphonenumbersmodel.h
│   │   │   ├── apploader/             # 应用加载器头文件
│   │   │   │   ├── risipapplicationsettings.h
│   │   │   │   └── risipuiloader.h
│   │   │   └── utils/                 # 工具类头文件
│   │   │       ├── qqmlsortfilterproxymodel.h
│   │   │       ├── filter.h
│   │   │       ├── sorter.h
│   │   │       └── stopwatch.h
│   │   ├── pjsipwrapper/              # PJSIP 底层封装
│   │   │   ├── pjsipendpoint.h/cpp    # Endpoint 封装
│   │   │   ├── pjsipaccount.h/cpp     # Account 封装
│   │   │   ├── pjsipcall.h/cpp        # Call 封装
│   │   │   └── pjsipbuddy.h/cpp       # Buddy 封装
│   │   ├── models/                    # 数据模型实现
│   │   │   ├── risipmodels.cpp
│   │   │   ├── risipabstractbuddymodel.cpp
│   │   │   ├── risipaccountlistmodel.cpp
│   │   │   ├── risipcallhistorymodel.cpp
│   │   │   ├── risipcountryratesmodel.cpp
│   │   │   ├── risipphonecontactsmodel.cpp
│   │   │   └── risipphonenumbersmodel.cpp
│   │   ├── utils/                     # 工具类实现
│   │   │   ├── qqmlsortfilterproxymodel.cpp
│   │   │   ├── filter.cpp
│   │   │   ├── sorter.cpp
│   │   │   └── stopwatch.cpp
│   │   ├── CMakeLists.txt            # Risip 构建配置 ⭐
│   │   ├── README.md                 # 技术文档 ⭐
│   │   └── QUICK_START.md            # 快速开始指南 ⭐
│   │
│   ├── sip_phone/                     # SIP 电话桥接层
│   │   ├── SipPhoneManager.h         # 管理器接口
│   │   ├── SipPhoneManager.cpp       # 实现 (已更新使用 Risip) ⭐
│   │   └── CMakeLists.txt            # 更新链接 risip_sdk ⭐
│   │
│   ├── qml/                           # QML UI 组件
│   │   └── components/
│   │       └── sip_phone/            # SIP 电话 UI
│   │           ├── SipPhoneWindow.qml
│   │           ├── SipMainPage.qml
│   │           ├── pages/
│   │           │   ├── SipSettingsPage.qml
│   │           │   ├── SipDialPage.qml
│   │           │   ├── SipHistoryPage.qml
│   │           │   └── SipContactsPage.qml
│   │           └── components/
│   │               ├── RisipButton.qml
│   │               └── RisipLineEdit.qml
│   │
│   ├── control/                       # 控制模块 (原有)
│   ├── hardware/                      # 硬件抽象层 (原有)
│   ├── utils/                         # 工具类 (原有)
│   └── main/                          # 主程序入口
│
├── docs/                              # 文档目录
│   └── RISIP_STRUCTURE.md            # 本文档 ⭐
│
├── CMakeLists.txt                     # 主构建配置 (已更新) ⭐
├── RISIP_INTEGRATION.md              # 集成报告 ⭐
└── README.md                          # 项目 README

⭐ = 新增或修改的文件
```

## 核心模块说明

### 1. Risip Core (`src/risip/core/`)

**职责**: 提供 SIP 功能的高级 C++/Qt 接口

**关键类**:

| 类名 | 文件 | 功能 |
|------|------|------|
| Risip | risip.h/cpp | 主入口,单例模式,管理所有子系统 |
| RisipEndpoint | risipendpoint.h/cpp | SIP endpoint 生命周期,传输管理 |
| RisipAccount | risipaccount.h/cpp | SIP 账户注册,认证,状态 |
| RisipCall | risipcall.h/cpp | 呼叫控制,状态机,DTMF |
| RisipCallManager | risipcallmanager.h/cpp | 管理多个呼叫 |
| RisipMedia | risipmedia.h/cpp | 音频设备,音量,编解码器 |
| RisipBuddy | risipbuddy.h/cpp | 联系人在线状态 |
| RisipMessage | risipmessage.h/cpp | 即时消息 (SIP MESSAGE) |

**Qt 集成特性**:
- 所有类继承自 QObject
- 使用 Q_PROPERTY 暴露属性给 QML
- 使用信号/槽机制通知状态变化
- 线程安全的异步操作

### 2. PJSIP Wrapper (`src/risip/pjsipwrapper/`)

**职责**: 封装 PJSIP C++ API,隔离底层细节

**架构**:
```
Qt/QML Layer (QObject)
        ↓
Risip Core (risip::RisipXxx)
        ↓
PJSIP Wrapper (risip::PjsipXxx)
        ↓
PJSIP Library (pj::Xxx)
```

**关键类**:

| Wrapper 类 | 继承自 PJSIP | 功能 |
|-----------|--------------|------|
| PjsipEndpoint | pj::Endpoint | 引擎初始化,事件分发 |
| PjsipAccount | pj::Account | 账户回调处理 |
| PjsipCall | pj::Call | 呼叫回调处理 |
| PjsipBuddy | pj::Buddy | 联系人回调处理 |

### 3. Models (`src/risip/models/`)

**职责**: 为 QML 提供数据模型

| 模型 | 继承 | 用途 |
|------|------|------|
| RisipAccountListModel | QAbstractListModel | 账户列表 |
| RisipCallHistoryModel | QAbstractListModel | 通话记录 |
| RisipPhoneContactsModel | QAbstractListModel | 联系人列表 |
| RisipPhoneNumbersModel | QAbstractListModel | 号码列表 |
| RisipAbstractBuddyModel | QAbstractListModel | Buddy 基类 |

### 4. SIP Phone Manager (`src/sip_phone/`)

**职责**: 应用层业务逻辑,连接 Risip SDK 和 QML UI

**架构模式**: PIMPL (Pointer to Implementation)

```cpp
// 公开接口 (SipPhoneManager.h)
class SipPhoneManager : public QObject {
    Q_PROPERTY(bool isRegistered ...)
    Q_INVOKABLE void makeCall(QString number);
signals:
    void callConnected();
private:
    class Private;  // 隐藏实现细节
    Private *d;
};

// 私有实现 (SipPhoneManager.cpp)
class SipPhoneManager::Private {
    risip::Risip *risipInstance;
    risip::RisipAccount *currentAccount;
    risip::RisipCall *currentCall;
};
```

**优势**:
- 头文件不暴露 Risip SDK 依赖
- 编译隔离,修改实现不需要重新编译依赖者
- 便于单元测试和模拟

## 数据流

### 呼出流程

```
QML UI
  ↓ SipPhoneManager.makeCall("1002")
SipPhoneManager
  ↓ d->risipInstance->callManager()->call(account, "1002")
RisipCallManager
  ↓ new RisipCall() → call->invite()
RisipCall
  ↓ m_pjsipCall->makeCall()
PjsipCall
  ↓ pj::Call::makeCall()
PJSIP Library
  ↓ SIP INVITE →
SIP Server
```

### 状态通知流程

```
PJSIP Library
  ↓ onCallState() callback
PjsipCall
  ↓ emit RisipCall::statusChanged()
SipPhoneManager (connected slot)
  ↓ emit callConnected()
QML UI
  ↓ Connections { onCallConnected }
显示"通话中"
```

## 编译依赖关系

```
belt_control_system (exe)
    ↓ links
┌──────────────────────────┐
│ main_module              │
└──────────────────────────┘
    ↓ links
┌──────────────────────────┐
│ sip_phone_module (lib)   │
└──────────────────────────┘
    ↓ links
┌──────────────────────────┐
│ risip_sdk (static lib)   │ ⭐
└──────────────────────────┘
    ↓ links
┌──────────────────────────┐
│ PJSIP (external)         │
│ - libpjsua2.a            │
│ - libpjsua.a             │
│ - libpjsip.a             │
│ - libpjmedia.a           │
│ - ...                    │
└──────────────────────────┘
    ↓ links
┌──────────────────────────┐
│ System Libraries         │
│ - ws2_32 (Windows)       │
│ - winmm                  │
│ - ole32                  │
└──────────────────────────┘
```

## CMake 构建流程

```cmake
# 1. 主 CMakeLists.txt
add_subdirectory(src/risip)          # 构建 risip_sdk
add_subdirectory(src/sip_phone)      # 构建 sip_phone_module
add_subdirectory(src/main)           # 构建主程序

# 2. src/risip/CMakeLists.txt
add_library(risip_sdk STATIC ...)
target_include_directories(risip_sdk PUBLIC
    ${PJSIP_ROOT}/pjsip/include
    ...
)
target_link_libraries(risip_sdk PUBLIC
    Qt6::Core Qt6::Network
    # PJSIP libs
)

# 3. src/sip_phone/CMakeLists.txt
add_library(sip_phone_module STATIC ...)
target_link_libraries(sip_phone_module PUBLIC
    risip_sdk                       # 依赖 Risip
)

# 4. src/main/CMakeLists.txt
add_executable(belt_control_system ...)
target_link_libraries(belt_control_system PRIVATE
    sip_phone_module               # 间接依赖 Risip
    ...
)
```

## 文件统计

| 类别 | 数量 | 说明 |
|------|------|------|
| 头文件 (.h) | 31 | Risip 核心接口 |
| 源文件 (.cpp) | 32 | Risip 实现 |
| CMake 配置 | 3 | 构建脚本 |
| 文档 | 4 | README, 快速指南等 |
| **总计** | **70** | **新增/修改文件** |

## 代码行数估算

| 模块 | 行数 (估算) |
|------|-------------|
| Risip Core | ~3000 |
| PJSIP Wrapper | ~800 |
| Models | ~600 |
| Utils | ~400 |
| SipPhoneManager | ~600 |
| CMake 配置 | ~200 |
| 文档 | ~1000 |
| **总计** | **~6600** |

## 许可证信息

```
src/risip/          GPLv3 (Risip 原始许可)
PJSIP Library       GPLv2 或商业许可
其他项目代码        [您的项目许可证]
```

**注意**: 由于使用了 GPLv3 的 Risip SDK,整个项目可能需要遵守 GPL 许可证,除非获得商业许可。

## 平台支持

| 平台 | 状态 | 说明 |
|------|------|------|
| Windows (MinGW) | ✅ 已配置 | 主要开发平台 |
| Windows (MSVC) | ⚠️ 需调整 | 库名可能不同 |
| aarch64 Linux | 🔄 待测试 | 需交叉编译 PJSIP |
| Android | ❌ 未配置 | 源码支持,需配置 |
| iOS | ❌ 未配置 | 源码支持,需配置 |

## 下一步扩展

### 可选功能 (已有源码,未启用)

1. **应用加载器** (`apploader/`)
   - RisipApplicationSettings - 配置管理
   - RisipUiLoader - UI 动态加载

2. **高级功能**
   - 视频通话支持
   - 会议通话
   - 录音功能
   - 加密传输 (SRTP)

3. **平台特定功能**
   - Android 联系人集成
   - iOS CallKit 集成
   - Linux PulseAudio 支持

### 性能优化

- [ ] 启用 PJSIP 编解码器优化
- [ ] 配置 PJMEDIA 缓冲区大小
- [ ] 优化网络参数 (STUN/TURN)
- [ ] 实现连接池管理

## 参考资料

- **本项目文档**:
  - [RISIP_INTEGRATION.md](../RISIP_INTEGRATION.md) - 集成报告
  - [src/risip/README.md](../src/risip/README.md) - 技术文档
  - [src/risip/QUICK_START.md](../src/risip/QUICK_START.md) - 快速指南

- **外部资源**:
  - PJSIP 官网: https://www.pjsip.org/
  - Risip GitHub: (原始仓库 F:\0\risip-master)
  - Qt 文档: https://doc.qt.io/

---

**最后更新**: 2025-11-27
**维护者**: [您的名字]
**版本**: 1.0
