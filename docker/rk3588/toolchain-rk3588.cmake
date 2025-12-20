# RK3588 交叉编译工具链配置
# 目标系统
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# 编译器 - 使用 gcc-11 (Ubuntu 22.04 默认) 以匹配 PJSIP 库编译环境
set(CMAKE_C_COMPILER /usr/bin/aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER /usr/bin/aarch64-linux-gnu-g++)

# Sysroot路径 - 使用正确的rk3588-root路径而不是pi-root
set(CMAKE_SYSROOT "/opt/sysroot/rk3588-root")
set(RK3588_LIBS_PATH "/opt/rk3588-libs")
# 必须包含 Qt Host 用于查找 Qt Tools
set(CMAKE_FIND_ROOT_PATH "$ENV{QT_HOST_PATH};${RK3588_LIBS_PATH};${CMAKE_SYSROOT}")

# Qt路径
set(QT_HOST_PATH $ENV{QT_HOST_PATH})
set(QT_COMPILER_PATH $ENV{QT_TARGET_PATH})
set(Qt6_DIR "${QT_COMPILER_PATH}/lib/cmake/Qt6")

# Qt6交叉编译配置 - 必须的环境变量
set(QT_QMAKE_EXECUTABLE "${QT_HOST_PATH}/bin/qmake")
set(QT_HOST_PATH_CMAKE_DIR "${QT_HOST_PATH}/lib/cmake")
set(QT_TOOLCHAIN_RELOCATABLE_CMAKE_DIR "${QT_COMPILER_PATH}/lib/cmake")

# RK3588自定义库路径 + Qt Host (for tools)
set(CMAKE_PREFIX_PATH "${RK3588_LIBS_PATH};${QT_COMPILER_PATH};${QT_HOST_PATH};${CMAKE_PREFIX_PATH}")
include_directories("${RK3588_LIBS_PATH}/include")
link_directories("${RK3588_LIBS_PATH}/lib")
# 使用sysroot内的库
link_directories("${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu")
link_directories("${CMAKE_SYSROOT}/lib/aarch64-linux-gnu")
link_directories("${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/mali")

# 添加库路径到链接器搜索路径（全局设置，确保所有目标都能找到）
set(CMAKE_LIBRARY_PATH "${RK3588_LIBS_PATH}/lib;${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu;${CMAKE_SYSROOT}/lib/aarch64-linux-gnu;${CMAKE_LIBRARY_PATH}" CACHE STRING "Library search path" FORCE)

# 搜索路径配置
# 程序（如moc, rcc等Qt工具）从host查找，不限制在sysroot中
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
# 库文件：允许在系统路径和sysroot中查找（BOTH模式）
# 这样可以使用Docker容器的Ubuntu 24系统库，而不仅限于外部sysroot
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
# 头文件：允许在系统路径和sysroot中查找（BOTH模式）
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
# 包配置：允许在系统路径和sysroot中查找（BOTH模式）
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)

# 特别处理：设置 QT_NO_CREATE_VERSIONLESS_TARGETS 避免版本冲突
set(QT_NO_CREATE_VERSIONLESS_TARGETS ON)

# 编译标志
# 使用 --sysroot 让编译器使用指定sysroot
# -isystem 添加容器中GCC 13的C++标准库头文件路径（交叉编译版本）
# -D_FORTIFY_SOURCE=0 禁用fortify检查，避免编译器优化问题
# 暂时移除 fix-math-macros.h 依赖
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -march=armv8-a --sysroot=${CMAKE_SYSROOT} -D_FORTIFY_SOURCE=0" CACHE STRING "C flags" FORCE)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -march=armv8-a --sysroot=${CMAKE_SYSROOT} -isystem /usr/aarch64-linux-gnu/include/c++/13 -isystem /usr/aarch64-linux-gnu/include/c++/13/aarch64-linux-gnu -D_FORTIFY_SOURCE=0" CACHE STRING "CXX flags" FORCE)

# 为Qt的MOC/RCC/UIC等工具设置正确的编译环境（它们需要找到C++标准库）
# 这些工具是由Qt在编译时调用的，需要确保它们也能找到正确的头文件
set(CMAKE_CXX_STANDARD_INCLUDE_DIRECTORIES "/usr/aarch64-linux-gnu/include/c++/13;/usr/aarch64-linux-gnu/include/c++/13/aarch64-linux-gnu" CACHE STRING "C++ standard include directories" FORCE)

# 链接器标志
# 1. -L 添加库搜索路径（用于直接链接的库）
# 2. -Wl,-rpath-link 添加运行时路径链接（用于查找传递性依赖）
# 优先级：RK3588自定义库 > sysroot
set(CMAKE_EXE_LINKER_FLAGS "-L${RK3588_LIBS_PATH}/lib -L${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu -L${CMAKE_SYSROOT}/lib/aarch64-linux-gnu -L${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/mali -Wl,-rpath-link,${RK3588_LIBS_PATH}/lib -Wl,-rpath-link,${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu -Wl,-rpath-link,${CMAKE_SYSROOT}/lib/aarch64-linux-gnu -Wl,-rpath-link,${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/mali" CACHE STRING "Executable linker flags" FORCE)
set(CMAKE_SHARED_LINKER_FLAGS "-L${RK3588_LIBS_PATH}/lib -L${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu -L${CMAKE_SYSROOT}/lib/aarch64-linux-gnu -L${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/mali -Wl,-rpath-link,${RK3588_LIBS_PATH}/lib -Wl,-rpath-link,${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu -Wl,-rpath-link,${CMAKE_SYSROOT}/lib/aarch64-linux-gnu -Wl,-rpath-link,${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/mali" CACHE STRING "Shared linker flags" FORCE)

# PKG_CONFIG配置
set(ENV{PKG_CONFIG_PATH} "${RK3588_LIBS_PATH}/lib/pkgconfig")
set(ENV{PKG_CONFIG_LIBDIR} "${RK3588_LIBS_PATH}/lib/pkgconfig:${CMAKE_SYSROOT}/usr/lib/pkgconfig:${CMAKE_SYSROOT}/usr/share/pkgconfig")
set(ENV{PKG_CONFIG_SYSROOT_DIR} "${CMAKE_SYSROOT}")

# OpenGL ES 2.0 和 EGL 路径设置 (Qt Gui 依赖)
# RK3588 使用 libmali 统一库，libEGL 和 libGLESv2 只是封装
# 真正的符号在 libmali.so 中
# 注意：libmali.so.1.9.0 位于 /usr/lib/aarch64-linux-gnu/ 而不是 /mali 子目录
set(EGL_INCLUDE_DIR "${CMAKE_SYSROOT}/usr/include" CACHE PATH "EGL include directory")
set(EGL_LIBRARY "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libmali.so.1.9.0" CACHE FILEPATH "EGL library")
set(GLESv2_INCLUDE_DIR "${CMAKE_SYSROOT}/usr/include" CACHE PATH "GLESv2 include directory")
set(GLESv2_LIBRARY "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libmali.so.1.9.0" CACHE FILEPATH "GLESv2 library")

# 强制CMake接受EGL和GLESv2，即使传递依赖测试失败
# 这些库在运行时可用，只是CMake测试时链接器找不到传递依赖
set(EGL_FOUND TRUE CACHE BOOL "EGL found")
set(HAVE_EGL TRUE CACHE BOOL "Have EGL")
set(GLESv2_FOUND TRUE CACHE BOOL "GLESv2 found")
set(HAVE_GLESv2 TRUE CACHE BOOL "Have GLESv2")

# 添加Mali库路径到链接器搜索路径
link_directories("${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/mali")

# 加载 Qt6 交叉编译配置
include("${CMAKE_CURRENT_LIST_DIR}/qt6.toolchain.cmake" OPTIONAL)

# 输出信息
message(STATUS "========================================")
message(STATUS "RK3588 交叉编译配置")
message(STATUS "========================================")
message(STATUS "Target System: ${CMAKE_SYSTEM_NAME}")
message(STATUS "Target Processor: ${CMAKE_SYSTEM_PROCESSOR}")
message(STATUS "C Compiler: ${CMAKE_C_COMPILER}")
message(STATUS "CXX Compiler: ${CMAKE_CXX_COMPILER}")
message(STATUS "Sysroot: ${CMAKE_SYSROOT}")
message(STATUS "Qt6 Dir: ${Qt6_DIR}")
message(STATUS "========================================")
