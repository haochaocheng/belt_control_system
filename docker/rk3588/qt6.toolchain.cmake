# Qt6 交叉编译专用 toolchain 文件
# 在 toolchain-rk3588.cmake 之后加载

# Qt6 交叉编译的关键配置
# 参考: https://doc.qt.io/qt-6/cmake-toolchain-files.html

# 设置 Qt6 paths
set(Qt6_DIR "${QT_COMPILER_PATH}/lib/cmake/Qt6" CACHE PATH "Qt6 CMake directory")

# 明确指定 Qt 工具目录（moc, rcc, uic等）
set(QT6_INSTALL_PREFIX "${QT_COMPILER_PATH}")
set(QT6_HOST_PREFIX "${QT_HOST_PATH}")

# 设置 Qt6 查找策略
list(PREPEND CMAKE_PREFIX_PATH
    "${QT_COMPILER_PATH}"
    "${QT_HOST_PATH}"
)

# 确保 Qt6CoreTools 能被找到
list(PREPEND CMAKE_FIND_ROOT_PATH
    "${QT_HOST_PATH}"
)

# Qt6 在交叉编译时需要知道 host 工具的位置
set(QT_HOST_PATH "${QT_HOST_PATH}" CACHE PATH "Qt host path for tools")
set(QT_HOST_PATH_CMAKE_DIR "${QT_HOST_PATH}/lib/cmake" CACHE PATH "Qt host CMake directory")

message(STATUS "===========================================")
message(STATUS "Qt6 交叉编译工具链配置")
message(STATUS "===========================================")
message(STATUS "Qt6_DIR: ${Qt6_DIR}")
message(STATUS "QT_HOST_PATH: ${QT_HOST_PATH}")
message(STATUS "QT6_INSTALL_PREFIX: ${QT6_INSTALL_PREFIX}")
message(STATUS "CMAKE_PREFIX_PATH: ${CMAKE_PREFIX_PATH}")
message(STATUS "CMAKE_FIND_ROOT_PATH: ${CMAKE_FIND_ROOT_PATH}")
message(STATUS "===========================================")
