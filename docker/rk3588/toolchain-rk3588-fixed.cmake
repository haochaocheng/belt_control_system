# RK3588 交叉编译工具链配置 - 修复版本
# 优先使用sysroot中的库，避免GLIBC版本冲突
# 目标系统
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# 编译器 - 使用 gcc-13 交叉编译器
set(CMAKE_C_COMPILER /usr/bin/aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER /usr/bin/aarch64-linux-gnu-g++)

# Sysroot路径
set(CMAKE_SYSROOT "/opt/sysroot/rk3588-root")
set(RK3588_LIBS_PATH "/opt/rk3588-libs")

# Qt路径
set(QT_HOST_PATH $ENV{QT_HOST_PATH})
set(QT_COMPILER_PATH $ENV{QT_TARGET_PATH})
set(Qt6_DIR "${QT_COMPILER_PATH}/lib/cmake/Qt6")

# Qt6交叉编译配置
set(QT_QMAKE_EXECUTABLE "${QT_HOST_PATH}/bin/qmake")
set(QT_HOST_PATH_CMAKE_DIR "${QT_HOST_PATH}/lib/cmake")
set(QT_TOOLCHAIN_RELOCATABLE_CMAKE_DIR "${QT_COMPILER_PATH}/lib/cmake")

# 重要：优先使用sysroot中的库，而不是rk3588-libs
# 这避免了GLIBC版本冲突问题
set(CMAKE_FIND_ROOT_PATH "${CMAKE_SYSROOT};${QT_HOST_PATH};${QT_COMPILER_PATH};${RK3588_LIBS_PATH}")
set(CMAKE_PREFIX_PATH "${CMAKE_SYSROOT};${QT_COMPILER_PATH};${QT_HOST_PATH};${RK3588_LIBS_PATH}")

# 包含路径 - sysroot优先
include_directories(
    "${CMAKE_SYSROOT}/usr/include"
    "${CMAKE_SYSROOT}/usr/include/aarch64-linux-gnu"
    "${RK3588_LIBS_PATH}/include"
)

# 库路径 - sysroot优先，避免使用有GLIBC 2.34+依赖的库
link_directories(
    "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu"
    "${CMAKE_SYSROOT}/lib/aarch64-linux-gnu"
    "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/mali"
)

# 注意：不再添加 ${RK3588_LIBS_PATH}/lib 到link_directories
# 只在需要特定库时才使用

# 搜索路径配置
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)

# 编译标志
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -march=armv8-a --sysroot=${CMAKE_SYSROOT}" CACHE STRING "C flags" FORCE)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -march=armv8-a --sysroot=${CMAKE_SYSROOT} -isystem /usr/aarch64-linux-gnu/include/c++/13 -isystem /usr/aarch64-linux-gnu/include/c++/13/aarch64-linux-gnu" CACHE STRING "CXX flags" FORCE)

# 链接器标志 - 优先使用sysroot中的库
set(CMAKE_EXE_LINKER_FLAGS "-L${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu -L${CMAKE_SYSROOT}/lib/aarch64-linux-gnu -Wl,-rpath-link,${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu -Wl,-rpath-link,${CMAKE_SYSROOT}/lib/aarch64-linux-gnu -Wl,-rpath-link,${QT_COMPILER_PATH}/lib" CACHE STRING "Executable linker flags" FORCE)
set(CMAKE_SHARED_LINKER_FLAGS "-L${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu -L${CMAKE_SYSROOT}/lib/aarch64-linux-gnu -Wl,-rpath-link,${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu -Wl,-rpath-link,${CMAKE_SYSROOT}/lib/aarch64-linux-gnu -Wl,-rpath-link,${QT_COMPILER_PATH}/lib" CACHE STRING "Shared linker flags" FORCE)

# 显式链接缺失的库
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -lX11 -lzstd -lbrotlidec -lbrotlicommon" CACHE STRING "Executable linker flags" FORCE)

# PKG_CONFIG配置
set(ENV{PKG_CONFIG_PATH} "${CMAKE_SYSROOT}/usr/lib/pkgconfig:${CMAKE_SYSROOT}/usr/share/pkgconfig")
set(ENV{PKG_CONFIG_LIBDIR} "${CMAKE_SYSROOT}/usr/lib/pkgconfig:${CMAKE_SYSROOT}/usr/share/pkgconfig")
set(ENV{PKG_CONFIG_SYSROOT_DIR} "${CMAKE_SYSROOT}")

# OpenGL ES 2.0 和 EGL 路径设置
set(EGL_INCLUDE_DIR "${CMAKE_SYSROOT}/usr/include" CACHE PATH "EGL include directory")
set(EGL_LIBRARY "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libmali.so.1.9.0" CACHE FILEPATH "EGL library")
set(GLESv2_INCLUDE_DIR "${CMAKE_SYSROOT}/usr/include" CACHE PATH "GLESv2 include directory")
set(GLESv2_LIBRARY "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libmali.so.1.9.0" CACHE FILEPATH "GLESv2 library")

# 强制接受EGL和GLESv2
set(EGL_FOUND TRUE CACHE BOOL "EGL found")
set(HAVE_EGL TRUE CACHE BOOL "Have EGL")
set(GLESv2_FOUND TRUE CACHE BOOL "GLESv2 found")
set(HAVE_GLESv2 TRUE CACHE BOOL "Have GLESv2")

# 输出信息
message(STATUS "========================================")
message(STATUS "RK3588 交叉编译配置 (Fixed)")
message(STATUS "========================================")
message(STATUS "Target System: ${CMAKE_SYSTEM_NAME}")
message(STATUS "Target Processor: ${CMAKE_SYSTEM_PROCESSOR}")
message(STATUS "C Compiler: ${CMAKE_C_COMPILER}")
message(STATUS "CXX Compiler: ${CMAKE_CXX_COMPILER}")
message(STATUS "Sysroot: ${CMAKE_SYSROOT}")
message(STATUS "Qt6 Dir: ${Qt6_DIR}")
message(STATUS "Using sysroot libraries (GLIBC compatible)")
message(STATUS "========================================")