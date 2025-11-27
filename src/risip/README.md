# Risip VoIP SDK 集成文档

## 概述

本模块集成了 Risip VoIP SDK,这是一个基于 PJSIP 的 Qt/C++ SIP 电话库。

### 源码来源
- 原始仓库: F:\0\risip-master\risip-master
- 许可证: GPLv3
- 官网: http://risip.io

## 目录结构

```
src/risip/
├── core/                      # 核心功能代码
│   ├── risip.h/cpp           # Risip 主类
│   ├── risipendpoint.h/cpp   # SIP endpoint 管理
│   ├── risipaccount.h/cpp    # SIP 账户管理
│   ├── risipcall.h/cpp       # 通话管理
│   ├── risipbuddy.h/cpp      # 联系人管理
│   ├── risipmedia.h/cpp      # 媒体处理
│   ├── risipmessage.h/cpp    # 消息管理
│   ├── models/               # 数据模型
│   ├── apploader/            # 应用加载器
│   └── utils/                # 工具类
├── pjsipwrapper/             # PJSIP 封装层
│   ├── pjsipendpoint.h/cpp
│   ├── pjsipaccount.h/cpp
│   ├── pjsipcall.h/cpp
│   └── pjsipbuddy.h/cpp
├── models/                   # 数据模型实现
├── utils/                    # 工具类实现
└── CMakeLists.txt           # CMake 构建配置
```

## PJSIP 依赖配置

### Windows 平台

Risip SDK 依赖 PJSIP 库。您需要:

1. **下载 PJSIP**
   - 访问 https://www.pjsip.org/
   - 下载 PJSIP 2.x 版本
   - 推荐版本: 2.13 或更高

2. **编译 PJSIP (Windows)**
   ```batch
   # 使用 Visual Studio Developer Command Prompt
   cd pjproject-2.x

   # 配置
   .\configure-win32.bat

   # 使用 Visual Studio 打开解决方案并编译
   # 或使用 nmake
   nmake /f pjproject-vs14.mak
   ```

3. **配置 CMake 路径**

   在 [src/risip/CMakeLists.txt](CMakeLists.txt:164) 中设置 PJSIP_ROOT:

   ```cmake
   set(PJSIP_ROOT "F:/path/to/pjproject" CACHE PATH "PJSIP root directory")
   ```

   PJSIP 目录结构应该是:
   ```
   pjproject/
   ├── include/           # 头文件
   │   ├── pjsua2.hpp
   │   └── ...
   └── lib/              # 编译后的库文件
       ├── pjproject.lib
       ├── pjsua2-lib.lib
       └── ...
   ```

### aarch64 交叉编译

对于 ARM64 部署:

1. **交叉编译 PJSIP**
   ```bash
   # 配置交叉编译
   ./configure --host=aarch64-linux-gnu
   make dep
   make
   ```

2. **安装交叉编译工具链**
   ```bash
   sudo apt install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu
   ```

3. **更新 CMake 配置**
   ```cmake
   if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64")
       set(PJSIP_ROOT "/path/to/aarch64/pjproject")
   endif()
   ```

## 功能特性

### 已集成功能

- ✅ SIP Endpoint 初始化
- ✅ SIP 账户注册/注销
- ✅ 呼出电话
- ✅ 接听来电
- ✅ 挂断电话
- ✅ 通话保持/恢复
- ✅ 呼叫转移
- ✅ DTMF 发送
- ✅ 麦克风/扬声器音量控制
- ✅ 静音功能

### 使用示例

```cpp
// 在 SipPhoneManager 中使用
#include "SipPhoneManager.h"

// 初始化 SIP 引擎
SipPhoneManager::instance()->initializeEndpoint();

// 注册账户
SipPhoneManager::instance()->registerAccount(
    "192.168.1.100",  // SIP 服务器
    "1001",           // 用户名
    "password",       // 密码
    5060              // 端口
);

// 拨打电话
SipPhoneManager::instance()->makeCall("1002");

// 挂断
SipPhoneManager::instance()->hangupCall();
```

### QML 集成

```qml
import BeltControl.SipPhone 1.0

Item {
    Component.onCompleted: {
        // 初始化
        SipPhoneManager.initializeEndpoint()
    }

    Button {
        text: "注册"
        onClicked: {
            SipPhoneManager.registerAccount(
                "192.168.1.100",
                "1001",
                "password",
                5060
            )
        }
    }

    Button {
        text: "拨号"
        onClicked: {
            SipPhoneManager.makeCall("1002")
        }
    }

    Text {
        text: "状态: " + SipPhoneManager.callStatus
    }

    Text {
        text: "通话时长: " + SipPhoneManager.callDuration + "秒"
    }
}
```

## 编译说明

### 先决条件

1. Qt 6.5 或更高版本
2. CMake 3.21 或更高版本
3. C++17 编译器
4. PJSIP 库 (已编译)

### 编译步骤

```bash
# 1. 配置 CMake
cmake -B build -S . -DPJSIP_ROOT=/path/to/pjsip

# 2. 编译
cmake --build build

# 3. 运行
./build/bin_windows/belt_control_system.exe
```

### 常见问题

#### 1. PJSIP 库未找到

```
错误: PJSIP not found at ...
```

**解决方案**: 在 CMakeLists.txt 中正确设置 PJSIP_ROOT 路径。

#### 2. 链接错误

```
错误: undefined reference to `pj::Endpoint::...`
```

**解决方案**: 确保 PJSIP 已正确编译,并且库文件在 lib/ 目录中。

#### 3. 头文件未找到

```
错误: pjsua2.hpp: No such file or directory
```

**解决方案**:
- 检查 PJSIP include 路径
- 确保 PJSIP 已完全编译

## 测试

### 基本测试流程

1. **测试 Endpoint 初始化**
   ```cpp
   ASSERT_TRUE(SipPhoneManager::instance()->initializeEndpoint());
   ASSERT_TRUE(SipPhoneManager::instance()->isInitialized());
   ```

2. **测试账户注册**
   ```cpp
   bool success = SipPhoneManager::instance()->registerAccount(
       "test.server.com", "testuser", "testpass", 5060
   );
   ASSERT_TRUE(success);
   ```

3. **测试呼叫**
   ```cpp
   SipPhoneManager::instance()->makeCall("1002");
   // 等待连接信号
   QSignalSpy spy(SipPhoneManager::instance(),
                  &SipPhoneManager::callConnected);
   ASSERT_TRUE(spy.wait(5000));
   ```

## 维护和更新

### 更新 Risip SDK

如果需要更新到新版本的 Risip:

1. 备份当前代码
2. 从源仓库复制新文件到 src/risip/
3. 检查 CMakeLists.txt 是否需要更新
4. 重新编译和测试

### 自定义修改

如需修改 Risip 核心代码,建议:

1. 在修改处添加注释标记
   ```cpp
   // CUSTOM MODIFICATION: [描述修改原因]
   ```

2. 保持与原始 API 的兼容性
3. 记录修改在此文档中

## 许可证

- Risip SDK: GPLv3
- PJSIP: GPLv2 或商业许可证
- 本项目: [您的许可证]

## 参考资料

- Risip 官网: http://risip.io
- PJSIP 官网: https://www.pjsip.org/
- PJSIP 文档: https://www.pjsip.org/docs/latest/pjsip/docs/html/
- Qt 文档: https://doc.qt.io/

## 联系支持

如有问题,请参考:
- PJSIP 邮件列表: https://www.pjsip.org/lists.htm
- Risip GitHub Issues
