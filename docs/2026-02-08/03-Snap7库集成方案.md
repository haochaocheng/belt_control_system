# Snap7库集成方案

**创建日期**: 2026-02-08
**阶段**: Phase 7.42 - TCP控制功能
**目标**: 集成Snap7库以实现西门子S7协议支持

## 1. Snap7库概述

### 1.1 什么是Snap7
- **开源库**: 用于与西门子S7 PLC通信的以太网通信库
- **多平台**: 支持Windows、Linux、ARM等平台
- **协议支持**: 实现S7协议（ISO-TCP、RFC1006）
- **功能完整**: 支持客户端（主站）和服务器（从站）模式

### 1.2 官方资源
- **GitHub**: https://github.com/snap7/snap7
- **SourceForge**: https://snap7.sourceforge.net
- **文档**: http://snap7.sourceforge.net/snap7_client.html

## 2. 下载和编译

### 2.1 下载源码
```powershell
# 方式1：使用Git克隆
git clone https://github.com/snap7/snap7.git libs/snap7

# 方式2：下载发布版本
# 访问 https://github.com/snap7/snap7/releases
# 下载最新版本的源码包
```

### 2.2 Windows编译（MinGW）
```powershell
cd libs/snap7/build/mingw
mingw32-make clean
mingw32-make
```

生成文件：
- `snap7.dll` - 动态链接库
- `libsnap7.a` - 静态链接库

### 2.3 Linux交叉编译（RK3588）
```bash
# 在Docker交叉编译环境中
cd /workspace/libs/snap7/build/unix
make -f arm_v7_linux.mk clean
make -f arm_v7_linux.mk

# 或使用通用Makefile
make clean
make
```

生成文件：
- `libsnap7.so` - 共享库
- `libsnap7.a` - 静态库

## 3. 项目集成

### 3.1 目录结构
```
libs/
├── snap7/                      # Snap7源码
│   ├── src/                    # 源代码
│   ├── build/                  # 编译脚本
│   └── examples/               # 示例代码
├── snap7-windows/              # Windows编译产物
│   ├── include/
│   │   └── snap7.h
│   └── lib/
│       ├── snap7.dll
│       └── libsnap7.a
└── snap7-rk3588/               # RK3588编译产物
    ├── include/
    │   └── snap7.h
    └── lib/
        ├── libsnap7.so
        └── libsnap7.a
```

### 3.2 CMakeLists.txt配置

在 `src/control/CMakeLists.txt` 中添加：

```cmake
# ========== Snap7 库集成（可选） ==========
option(ENABLE_SNAP7 "Enable Snap7 S7 protocol support" OFF)

if(ENABLE_SNAP7)
    message(STATUS "🔧 Snap7 S7 protocol support: ENABLED")

    # 定义平台相关的库路径
    if(WIN32)
        set(SNAP7_ROOT "${CMAKE_SOURCE_DIR}/libs/snap7-windows")
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64" OR CMAKE_SYSTEM_PROCESSOR MATCHES "arm64")
        # 检查是否在RK3588交叉编译环境中
        if(EXISTS "/opt/rk3588-libs/lib")
            set(SNAP7_ROOT "/opt/rk3588-libs")
            message(STATUS "  🎯 Using RK3588 cross-compile environment")
        else()
            set(SNAP7_ROOT "${CMAKE_SOURCE_DIR}/libs/snap7-rk3588")
        endif()
    else()
        set(SNAP7_ROOT "${CMAKE_SOURCE_DIR}/libs/snap7-linux")
    endif()

    message(STATUS "  Looking for Snap7 in: ${SNAP7_ROOT}")

    # 查找Snap7库
    find_library(SNAP7_LIB
        NAMES snap7 libsnap7
        PATHS "${SNAP7_ROOT}/lib"
        NO_DEFAULT_PATH
    )

    if(SNAP7_LIB)
        message(STATUS "  ✅ Found Snap7: ${SNAP7_LIB}")
        set(SNAP7_FOUND TRUE)
    else()
        message(WARNING "❌ Snap7 library not found in ${SNAP7_ROOT}, S7 protocol will not be available")
        message(WARNING "   To enable Snap7:")
        message(WARNING "   1. Download: https://github.com/snap7/snap7")
        message(WARNING "   2. Compile and install to: ${SNAP7_ROOT}")
        set(ENABLE_SNAP7 OFF)
    endif()
else()
    message(STATUS "🔧 Snap7 S7 protocol support: DISABLED")
    message(STATUS "   To enable: cmake -DENABLE_SNAP7=ON ..")
endif()

# ========== 创建控制模块库 ==========
add_library(control_module STATIC
    ${CONTROL_SOURCES}
    ${CONTROL_HEADERS}
)

# ... 其他配置 ...

# ========== Snap7 后处理（链接库和包含目录）==========
if(ENABLE_SNAP7 AND SNAP7_FOUND)
    # 添加头文件路径
    target_include_directories(control_module PRIVATE
        "${SNAP7_ROOT}/include"
    )

    # 链接Snap7库
    target_link_libraries(control_module
        ${SNAP7_LIB}
    )

    # 添加编译定义
    target_compile_definitions(control_module PUBLIC
        ENABLE_SNAP7
    )

    # Windows: 复制DLL到输出目录
    if(WIN32)
        file(GLOB SNAP7_DLLS "${SNAP7_ROOT}/lib/*.dll")
        foreach(dll ${SNAP7_DLLS})
            add_custom_command(TARGET control_module POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    "${dll}"
                    "$<TARGET_FILE_DIR:belt_control_system>"
                COMMENT "Copying ${dll} to output directory"
            )
        endforeach()
    endif()
endif()
```

## 4. S7ClientController实现

### 4.1 头文件修改
在 `S7ClientController.h` 中添加：

```cpp
#ifdef ENABLE_SNAP7
#include "snap7.h"
#endif

class S7ClientController : public QObject
{
    // ...

private:
#ifdef ENABLE_SNAP7
    TS7Client *m_s7Client;  // Snap7客户端
#endif
    // ...
};
```

### 4.2 实现文件修改
在 `S7ClientController.cpp` 中：

```cpp
#ifdef ENABLE_SNAP7

S7ClientController::S7ClientController(QObject *parent)
    : QObject(parent)
    , m_s7Client(new TS7Client())
{
    qDebug() << "✅ [S7ClientController] 初始化完成（Snap7支持）";
}

bool S7ClientController::connectToServer()
{
    if (!m_s7Client) {
        return false;
    }

    int result = m_s7Client->ConnectTo(
        m_targetIP.toStdString().c_str(),
        m_rack,
        m_slot
    );

    if (result == 0) {
        qDebug() << "✅ [S7ClientController] 连接成功";
        emit isConnectedChanged();
        return true;
    } else {
        qWarning() << "❌ [S7ClientController] 连接失败:" << result;
        return false;
    }
}

#else

// 无Snap7支持的占位实现
S7ClientController::S7ClientController(QObject *parent)
    : QObject(parent)
{
    qWarning() << "⚠️ [S7ClientController] Snap7未启用，S7功能不可用";
}

bool S7ClientController::connectToServer()
{
    qWarning() << "⚠️ [S7ClientController] Snap7未启用";
    return false;
}

#endif
```

## 5. 实施步骤

### 5.1 下载Snap7库
```powershell
# 创建目录
New-Item -ItemType Directory -Force -Path libs

# 克隆Snap7仓库
cd libs
git clone https://github.com/snap7/snap7.git
```

### 5.2 编译Windows版本
```powershell
cd snap7/build/mingw
mingw32-make clean
mingw32-make

# 创建Windows库目录
New-Item -ItemType Directory -Force -Path ../../../snap7-windows/include
New-Item -ItemType Directory -Force -Path ../../../snap7-windows/lib

# 复制文件
Copy-Item ../../src/core/snap7.h ../../../snap7-windows/include/
Copy-Item snap7.dll ../../../snap7-windows/lib/
Copy-Item libsnap7.a ../../../snap7-windows/lib/
```

### 5.3 编译RK3588版本
在Docker交叉编译环境中：
```bash
cd /workspace/libs/snap7/build/unix
make clean
make

# 创建RK3588库目录
mkdir -p /workspace/libs/snap7-rk3588/include
mkdir -p /workspace/libs/snap7-rk3588/lib

# 复制文件
cp ../../src/core/snap7.h /workspace/libs/snap7-rk3588/include/
cp libsnap7.so /workspace/libs/snap7-rk3588/lib/
cp libsnap7.a /workspace/libs/snap7-rk3588/lib/
```

### 5.4 启用Snap7支持
```powershell
# 重新配置CMake
cmake -DENABLE_SNAP7=ON ..

# 编译
cmake --build .
```

## 6. 测试验证

### 6.1 基本连接测试
```cpp
// 在QML中测试
s7Client1.targetIP = "192.168.0.1"
s7Client1.rack = 0
s7Client1.slot = 2
s7Client1.connectToServer()
```

### 6.2 读写测试
```cpp
// 读取DB块
s7Client1.readDB(1, 0, 10)  // DB1, 起始0, 长度10

// 写入DB块
s7Client1.writeDB(1, 0, data)
```

## 7. 注意事项

### 7.1 许可证
- Snap7使用LGPL v3许可证
- 可以在商业项目中使用，但需要遵守LGPL条款

### 7.2 性能考虑
- S7协议比Modbus TCP复杂，连接建立较慢
- 建议使用连接池和重连机制
- 大数据块读写需要分片处理

### 7.3 兼容性
- 支持S7-200、S7-300、S7-400、S7-1200、S7-1500
- 不同型号PLC的TSAP配置可能不同
- 需要根据实际PLC型号调整参数

## 8. 备选方案

如果Snap7集成遇到问题，可以考虑：

1. **仅实现Modbus TCP**
   - 先完成Modbus TCP功能
   - S7协议作为可选功能

2. **使用其他S7库**
   - LibNoDave（较老，但稳定）
   - Sharp7（C#实现，可参考）

3. **自行实现S7协议**
   - 基于RFC1006和ISO-TCP
   - 工作量较大，不推荐

## 9. 参考资源

- Snap7官方文档: http://snap7.sourceforge.net
- S7协议规范: ISO 8073 (RFC1006)
- 西门子S7通信手册: 各PLC型号手册

---

**状态**: 待实施
**优先级**: 中（Modbus TCP已完成，S7为增强功能）
**预计工作量**: 2-4小时（下载、编译、集成、测试）
