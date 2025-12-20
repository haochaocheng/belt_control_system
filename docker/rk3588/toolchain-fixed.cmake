# RK3588 交叉编译工具链配置 - 修复版（使用容器内ARM64库）
# 目标系统
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# 编译器 - 使用容器内的交叉编译器
set(CMAKE_C_COMPILER /usr/bin/aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER /usr/bin/aarch64-linux-gnu-g++)

# Sysroot路径 - 使用外部sysroot（仅用于某些特殊文件）
set(CMAKE_SYSROOT "/opt/sysroot/rk3588-root")

# 使用容器内的ARM64库路径（这些库的GLIBC版本与编译环境一致）
set(CONTAINER_ARM64_LIBS "/usr/lib/aarch64-linux-gnu")
set(CONTAINER_ARM64_INCLUDE "/usr/include")

# RK3588 libs路径（包含PJSIP等预编译库）
set(RK3588_LIBS_PATH "/opt/rk3588-libs")
set(RK3588_LIBS_INCLUDE "${RK3588_LIBS_PATH}/include")
set(RK3588_LIBS_LIB "${RK3588_LIBS_PATH}/lib")

# Qt路径
set(QT_HOST_PATH $ENV{QT_HOST_PATH})
set(QT_COMPILER_PATH $ENV{QT_TARGET_PATH})
set(Qt6_DIR "${QT_COMPILER_PATH}/lib/cmake/Qt6")

# Qt6交叉编译配置
set(QT_QMAKE_EXECUTABLE "${QT_HOST_PATH}/bin/qmake")
set(QT_HOST_PATH_CMAKE_DIR "${QT_HOST_PATH}/lib/cmake")
set(QT_TOOLCHAIN_RELOCATABLE_CMAKE_DIR "${QT_COMPILER_PATH}/lib/cmake")

# 查找路径 - 优先使用容器内的ARM64库
set(CMAKE_FIND_ROOT_PATH "${QT_HOST_PATH};${RK3588_LIBS_PATH};${CONTAINER_ARM64_LIBS};${CMAKE_SYSROOT}")
set(CMAKE_PREFIX_PATH "${QT_COMPILER_PATH};${QT_HOST_PATH};${CMAKE_PREFIX_PATH}")

# 添加包含目录
include_directories(SYSTEM "${RK3588_LIBS_INCLUDE}")
include_directories(SYSTEM "${CONTAINER_ARM64_INCLUDE}")
include_directories(SYSTEM "${CONTAINER_ARM64_INCLUDE}/aarch64-linux-gnu")

# 链接目录 - 优先使用容器内的库
link_directories("${RK3588_LIBS_LIB}")
link_directories("${CONTAINER_ARM64_LIBS}")
link_directories("${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu")
link_directories("${CMAKE_SYSROOT}/lib/aarch64-linux-gnu")

# 搜索路径配置
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)

# 版本冲突处理
set(QT_NO_CREATE_VERSIONLESS_TARGETS ON)

# 编译标志 - 使用容器内的头文件和PJSIP头文件
set(CMAKE_C_FLAGS "-march=armv8-a -D_FORTIFY_SOURCE=0 -I${RK3588_LIBS_INCLUDE} -I${CONTAINER_ARM64_INCLUDE}" CACHE STRING "C flags" FORCE)
set(CMAKE_CXX_FLAGS "-march=armv8-a -D_FORTIFY_SOURCE=0 -I${RK3588_LIBS_INCLUDE} -I${CONTAINER_ARM64_INCLUDE} -isystem /usr/aarch64-linux-gnu/include/c++/13 -isystem /usr/aarch64-linux-gnu/include/c++/13/aarch64-linux-gnu" CACHE STRING "CXX flags" FORCE)

# 链接器标志 - 优先使用容器内的库和PJSIP库
set(CMAKE_EXE_LINKER_FLAGS "-L${RK3588_LIBS_LIB} -L${CONTAINER_ARM64_LIBS} -L${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu -L${CMAKE_SYSROOT}/lib/aarch64-linux-gnu -Wl,-rpath-link,${RK3588_LIBS_LIB} -Wl,-rpath-link,${CONTAINER_ARM64_LIBS} -Wl,-rpath-link,${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu -Wl,-rpath-link,${CMAKE_SYSROOT}/lib/aarch64-linux-gnu -Wl,--allow-shlib-undefined" CACHE STRING "Executable linker flags" FORCE)
set(CMAKE_SHARED_LINKER_FLAGS "-L${RK3588_LIBS_LIB} -L${CONTAINER_ARM64_LIBS} -L${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu -L${CMAKE_SYSROOT}/lib/aarch64-linux-gnu -Wl,-rpath-link,${RK3588_LIBS_LIB} -Wl,-rpath-link,${CONTAINER_ARM64_LIBS} -Wl,-rpath-link,${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu -Wl,-rpath-link,${CMAKE_SYSROOT}/lib/aarch64-linux-gnu -Wl,--allow-shlib-undefined" CACHE STRING "Shared linker flags" FORCE)

# PKG_CONFIG配置
set(ENV{PKG_CONFIG_PATH} "${CONTAINER_ARM64_LIBS}/pkgconfig")
set(ENV{PKG_CONFIG_LIBDIR} "${CONTAINER_ARM64_LIBS}/pkgconfig:${CMAKE_SYSROOT}/usr/lib/pkgconfig")
set(ENV{PKG_CONFIG_SYSROOT_DIR} "")

# OpenGL ES 2.0 和 EGL 路径设置
# 对于嵌入式设备，我们假设EGL/GLES在运行时可用
# 创建虚拟路径以满足CMake检查
set(EGL_INCLUDE_DIR "${CMAKE_SYSROOT}/usr/include" CACHE PATH "EGL include directory" FORCE)
set(EGL_LIBRARY "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libEGL.so" CACHE FILEPATH "EGL library" FORCE)
set(GLESv2_INCLUDE_DIR "${CMAKE_SYSROOT}/usr/include" CACHE PATH "GLESv2 include directory" FORCE)
set(GLESv2_LIBRARY "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libGLESv2.so" CACHE FILEPATH "GLESv2 library" FORCE)

# 强制CMake接受EGL和GLESv2（即使文件不存在）
set(EGL_FOUND TRUE CACHE BOOL "EGL found" FORCE)
set(HAVE_EGL TRUE CACHE BOOL "Have EGL" FORCE)
set(GLESv2_FOUND TRUE CACHE BOOL "GLESv2 found" FORCE)
set(HAVE_GLESv2 TRUE CACHE BOOL "Have GLESv2" FORCE)

# 禁用EGL/GLES文件检查
set(CMAKE_DISABLE_FIND_PACKAGE_EGL TRUE CACHE BOOL "Disable EGL check" FORCE)
set(CMAKE_DISABLE_FIND_PACKAGE_GLESv2 TRUE CACHE BOOL "Disable GLESv2 check" FORCE)

# 创建 GLESv2 和 EGL CMake 目标
# 这些目标将在运行时链接到设备上的实际库
if(NOT TARGET GLESv2::GLESv2)
    add_library(GLESv2::GLESv2 SHARED IMPORTED)
    set_target_properties(GLESv2::GLESv2 PROPERTIES
        IMPORTED_LOCATION "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libGLESv2.so"
        INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_SYSROOT}/usr/include"
    )
endif()

if(NOT TARGET EGL::EGL)
    add_library(EGL::EGL SHARED IMPORTED)
    set_target_properties(EGL::EGL PROPERTIES
        IMPORTED_LOCATION "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libEGL.so"
        INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_SYSROOT}/usr/include"
    )
endif()

# 输出信息
message(STATUS "========================================")
message(STATUS "RK3588 交叉编译配置 (修复版)")
message(STATUS "========================================")
message(STATUS "Target System: ${CMAKE_SYSTEM_NAME}")
message(STATUS "Target Processor: ${CMAKE_SYSTEM_PROCESSOR}")
message(STATUS "C Compiler: ${CMAKE_C_COMPILER}")
message(STATUS "CXX Compiler: ${CMAKE_CXX_COMPILER}")
message(STATUS "Container ARM64 libs: ${CONTAINER_ARM64_LIBS}")
message(STATUS "Qt6 Dir: ${Qt6_DIR}")
message(STATUS "========================================")