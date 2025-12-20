# RK3588 交叉编译工具链配置 - 使用容器内的系统库
# 目标系统
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# 编译器 - 使用容器内的 gcc-13 交叉编译器
set(CMAKE_C_COMPILER /usr/bin/aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER /usr/bin/aarch64-linux-gnu-g++)

# RK3588 自定义库路径（包含预编译的库）
set(RK3588_LIBS_PATH "/opt/rk3588-libs")

# Qt路径
set(QT_HOST_PATH $ENV{QT_HOST_PATH})
set(QT_COMPILER_PATH $ENV{QT_TARGET_PATH})
set(Qt6_DIR "${QT_COMPILER_PATH}/lib/cmake/Qt6")

# Qt6交叉编译配置
set(QT_QMAKE_EXECUTABLE "${QT_HOST_PATH}/bin/qmake")
set(QT_HOST_PATH_CMAKE_DIR "${QT_HOST_PATH}/lib/cmake")
set(QT_TOOLCHAIN_RELOCATABLE_CMAKE_DIR "${QT_COMPILER_PATH}/lib/cmake")

# 搜索路径配置 - 优先使用容器内的系统库
set(CMAKE_FIND_ROOT_PATH "${QT_HOST_PATH};${RK3588_LIBS_PATH}")
set(CMAKE_PREFIX_PATH "${RK3588_LIBS_PATH};${QT_COMPILER_PATH};${QT_HOST_PATH};${CMAKE_PREFIX_PATH}")

# 包含目录
include_directories("${RK3588_LIBS_PATH}/include")
link_directories("${RK3588_LIBS_PATH}/lib")
# 使用容器内的系统库
link_directories("/usr/lib/aarch64-linux-gnu")
link_directories("/lib/aarch64-linux-gnu")

# 搜索路径模式 - 允许使用系统库
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)

# 编译标志 - 不使用 sysroot
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -march=armv8-a" CACHE STRING "C flags" FORCE)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -march=armv8-a" CACHE STRING "CXX flags" FORCE)

# 链接器标志 - 优先使用RK3588自定义库，然后是系统库
set(CMAKE_EXE_LINKER_FLAGS "-L${RK3588_LIBS_PATH}/lib -L/usr/lib/aarch64-linux-gnu -L/lib/aarch64-linux-gnu -Wl,-rpath-link,${RK3588_LIBS_PATH}/lib -Wl,-rpath-link,/usr/lib/aarch64-linux-gnu -Wl,-rpath-link,/lib/aarch64-linux-gnu" CACHE STRING "Executable linker flags" FORCE)
set(CMAKE_SHARED_LINKER_FLAGS "-L${RK3588_LIBS_PATH}/lib -L/usr/lib/aarch64-linux-gnu -L/lib/aarch64-linux-gnu -Wl,-rpath-link,${RK3588_LIBS_PATH}/lib -Wl,-rpath-link,/usr/lib/aarch64-linux-gnu -Wl,-rpath-link,/lib/aarch64-linux-gnu" CACHE STRING "Shared linker flags" FORCE)

# PKG_CONFIG配置
set(ENV{PKG_CONFIG_PATH} "${RK3588_LIBS_PATH}/lib/pkgconfig:/usr/lib/aarch64-linux-gnu/pkgconfig")
set(ENV{PKG_CONFIG_LIBDIR} "${RK3588_LIBS_PATH}/lib/pkgconfig:/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/share/pkgconfig")

# OpenGL ES 2.0 和 EGL 路径设置 - 使用容器内的 Mali 库
set(EGL_INCLUDE_DIR "/usr/include" CACHE PATH "EGL include directory")
set(EGL_LIBRARY "/usr/lib/aarch64-linux-gnu/libEGL.so" CACHE FILEPATH "EGL library")
set(GLESv2_INCLUDE_DIR "/usr/include" CACHE PATH "GLESv2 include directory")
set(GLESv2_LIBRARY "/usr/lib/aarch64-linux-gnu/libGLESv2.so" CACHE FILEPATH "GLESv2 library")

# 强制CMake接受EGL和GLESv2
set(EGL_FOUND TRUE CACHE BOOL "EGL found")
set(HAVE_EGL TRUE CACHE BOOL "Have EGL")
set(GLESv2_FOUND TRUE CACHE BOOL "GLESv2 found")
set(HAVE_GLESv2 TRUE CACHE BOOL "Have GLESv2")

# 禁用CREATE_VERSIONLESS_TARGETS避免版本冲突
set(QT_NO_CREATE_VERSIONLESS_TARGETS ON)

# 输出信息
message(STATUS "========================================")
message(STATUS "RK3588 Native Libraries 交叉编译配置")
message(STATUS "========================================")
message(STATUS "Target System: ${CMAKE_SYSTEM_NAME}")
message(STATUS "Target Processor: ${CMAKE_SYSTEM_PROCESSOR}")
message(STATUS "C Compiler: ${CMAKE_C_COMPILER}")
message(STATUS "CXX Compiler: ${CMAKE_CXX_COMPILER}")
message(STATUS "Qt6 Dir: ${Qt6_DIR}")
message(STATUS "使用容器内的Ubuntu 24.04系统库")
message(STATUS "========================================")