# PJSIP 2.15.1 重新编译指南

## 问题回顾

**错误**: `Assertion failed: sizeof(pj_fd_set_t)-sizeof(pj_sock_t) >= sizeof(fd_set), file ../src/pj/sock_select.c, line 45`

**根本原因**: PJSIP 的 `PJ_FD_SETSIZE` 配置与 Windows 系统的 `FD_SETSIZE` 不匹配

## 编译环境

- **操作系统**: Windows 10/11
- **编译器**: MinGW GCC 11.2.0 (已安装在 `C:\Qt\Tools\mingw1120_64`)
- **PJSIP 版本**: 2.15.1
- **PJSIP 源码位置**: 待下载

## 步骤一：下载 PJSIP 2.15.1 源码

1. 访问 PJSIP 官方下载页面：https://www.pjsip.org/download.htm
2. 下载 pjproject-2.15.1.tar.gz
3. 解压到：`e:\2025\3_gongkongji\pjproject-2.15.1`

或使用命令行：
```bash
cd e:\2025\3_gongkongji
wget https://github.com/pjsip/pjproject/archive/refs/tags/2.15.1.tar.gz
tar -xzf 2.15.1.tar.gz
```

## 步骤二：创建配置文件

创建 `pjlib/include/pj/config_site.h` 文件：

```c
/*
 * config_site.h - PJSIP Configuration for Windows 10/11
 *
 * 修复 sizeof(pj_fd_set_t) 断言失败问题
 */

#ifndef __PJ_CONFIG_SITE_H__
#define __PJ_CONFIG_SITE_H__

/*
 * 关键修复：设置 FD_SETSIZE 为较小的值以匹配 Windows
 * Windows 默认 FD_SETSIZE = 64
 */
#define PJ_IOQUEUE_MAX_HANDLES    64
#define FD_SETSIZE                64

/*
 * 禁用视频支持（与原编译选项一致）
 */
#define PJMEDIA_HAS_VIDEO         0

/*
 * 使用 Windows 优化的 I/O 机制
 * 注意：可以考虑使用 IOCP 代替 select()，性能更好
 */
// #define PJ_WIN32_WINCE            0

/*
 * 音频配置
 */
#define PJMEDIA_AUDIO_DEV_HAS_PORTAUDIO   0
#define PJMEDIA_AUDIO_DEV_HAS_WMME        1  // Windows Multimedia Extensions

/*
 * 日志级别
 */
#define PJ_LOG_MAX_LEVEL          5

/*
 * 内存池优化
 */
#define PJ_POOL_DEBUG             0

#endif /* __PJ_CONFIG_SITE_H__ */
```

## 步骤三：配置编译环境

打开 MinGW 命令行：

```bash
# 设置环境变量
set PATH=C:\Qt\Tools\mingw1120_64\bin;%PATH%

# 进入 PJSIP 目录
cd e:\2025\3_gongkongji\pjproject-2.15.1

# 验证编译器
gcc --version
g++ --version
```

## 步骤四：配置 PJSIP

```bash
# 配置（关键参数）
./configure \
    --prefix=e:/2025/3_gongkongji/pjsip-install \
    --disable-video \
    --disable-openh264 \
    --disable-ffmpeg \
    --disable-v4l2 \
    CFLAGS="-DFD_SETSIZE=64 -DPJ_IOQUEUE_MAX_HANDLES=64" \
    CXXFLAGS="-DFD_SETSIZE=64 -DPJ_IOQUEUE_MAX_HANDLES=64"
```

**重要参数说明**:
- `--disable-video`: 禁用视频（与原配置一致）
- `CFLAGS`: 设置 FD_SETSIZE=64，修复断言失败
- `--prefix`: 安装路径

## 步骤五：编译和安装

```bash
# 清理之前的编译（如果有）
make distclean

# 生成依赖
make dep

# 编译（使用多核加速）
make -j4

# 安装
make install
```

编译时间约 10-20 分钟，取决于 CPU 性能。

## 步骤六：验证编译结果

检查安装目录：
```bash
ls e:/2025/3_gongkongji/pjsip-install/lib
```

应该看到以下库文件（`.a` 格式）：
- libpj.a
- libpjlib-util.a
- libpjmedia.a
- libpjmedia-audiodev.a
- libpjmedia-codec.a
- libpjnath.a
- libpjsip.a
- libpjsip-simple.a
- libpjsip-ua.a
- libpjsua.a
- libpjsua2.a
- 等等

## 步骤七：更新项目配置

修改 `CMakeLists.txt` 中的 PJSIP 路径：

```cmake
# 更新为新编译的 PJSIP 路径
set(PJSIP_ROOT "e:/2025/3_gongkongji/pjsip-install")
set(PJSIP_INCLUDE_DIRS "${PJSIP_ROOT}/include")
set(PJSIP_LIBRARY_DIRS "${PJSIP_ROOT}/lib")
```

## 步骤八：重新编译项目

```bash
cd e:\2025\3_gongkongji\belt_control_system

# 清理旧的构建
rm -rf build
mkdir build
cd build

# 重新配置
cmake -G "MinGW Makefiles" \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_PREFIX_PATH=C:/Qt/6.5.0/mingw_64 \
      ..

# 编译
cmake --build . --target belt_control_system
```

## 步骤九：启用 PJSIP 初始化

修改 `src/sip_phone/SipPhoneManager.cpp`，恢复正常的初始化代码：

```cpp
bool SipPhoneManager::initializeEndpoint()
{
    qDebug() << "Initializing SIP endpoint with Risip SDK...";

    if (d->initialized) {
        qDebug() << "Endpoint already initialized";
        return true;
    }

    // Get the SIP endpoint from Risip singleton
    risip::RisipEndpoint *endpoint = d->risipInstance->sipEndpoint();
    if (!endpoint) {
        qCritical() << "Failed to get SIP endpoint from Risip instance";
        updateServerStatus("无法获取 SIP 引擎");
        return false;
    }

    // Initialize Risip endpoint (with fixed PJSIP)
    qDebug() << "Starting Risip endpoint...";
    int status = endpoint->start();

    if (status != 1) {  // 1 means Started
        QString errorMsg = endpoint->errorMessage();
        QString errorInfo = endpoint->errorInfo();
        qCritical() << "SIP引擎启动失败:" << errorMsg;
        qCritical() << "Error info:" << errorInfo;
        qCritical() << "Endpoint status:" << status;
        updateServerStatus("SIP引擎启动失败: " + errorMsg);
        return false;
    }

    qDebug() << "SIP endpoint started successfully";
    d->initialized = true;
    emit isInitializedChanged(true);
    updateServerStatus("已初始化");

    return true;
}
```

## 步骤十：测试

1. 运行程序：`run_debug_keepopen.bat`
2. 点击绿色电话图标 📞
3. 检查控制台输出，应该看到：
   ```
   Initializing SIP endpoint with Risip SDK...
   Starting Risip endpoint...
   13:59:04.181   os_core_win32.c !pjlib 2.15.1 for win32 initialized
   13:59:04.191   sip_endpoint.c  .Creating endpoint instance...
   libCreate() completed successfully
   libInit() completed successfully
   libStart() completed successfully
   SIP endpoint started successfully
   ```

4. 如果成功，不应该再有断言失败

## 常见问题排查

### 问题 1: configure 脚本找不到

```bash
# 确保在 MinGW 环境下运行
# 或者使用 Git Bash
```

### 问题 2: 编译错误 - 找不到头文件

```bash
# 检查 config_site.h 是否正确创建
ls pjlib/include/pj/config_site.h
```

### 问题 3: 仍然有断言失败

- 检查 `config_site.h` 中的 `FD_SETSIZE` 值
- 尝试更小的值，如 32：
  ```c
  #define FD_SETSIZE                32
  #define PJ_IOQUEUE_MAX_HANDLES    32
  ```

### 问题 4: 音频设备错误

- 在 `config_site.h` 中添加：
  ```c
  #define PJMEDIA_AUDIO_DEV_HAS_WMME  1
  #define PJMEDIA_HAS_SRTP            0
  ```

## 备用方案：使用 IOCP (高级)

如果 select() 仍有问题，可以尝试使用 Windows IOCP：

在 `config_site.h` 中添加：
```c
#define PJ_HAS_TCP                  1
#define PJ_IOQUEUE_HAS_SAFE_UNREG   1
// IOCP 配置待测试
```

## 完成后

- 删除旧的 PJSIP 库文件
- 提交新配置到 Git
- 更新 PJSIP_ISSUE_REPORT.md 状态为"已解决"

## 参考资料

- [PJSIP Windows Build Instructions](https://docs.pjsip.org/en/2.15.1/get-started/windows/build_instructions.html)
- [PJSIP Configuration Guide](https://docs.pjsip.org/en/latest/api/pjlib/config.html)
- [FD_SETSIZE FAQ](https://trac.pjsip.org/repos/wiki/FAQ#fd_set)
