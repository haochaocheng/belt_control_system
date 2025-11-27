@echo off
echo ========================================
echo 运行皮带控制系统
echo ========================================
echo.

REM 设置Qt路径 - 请修改为你的Qt安装路径
set QT_PATH=C:\Qt\6.5.0\mingw_64

if not exist "build\bin_windows\belt_control_system.exe" (
    echo 错误: 找不到可执行文件
    echo 请先运行 build.bat 编译项目
    pause
    exit /b 1
)

REM 添加Qt DLL到PATH
set PATH=%QT_PATH%\bin;%PATH%

REM 设置QML导入路径
set QML_IMPORT_PATH=%CD%\src\qml
set QML2_IMPORT_PATH=%CD%\src\qml

echo 启动应用程序...
echo.
build\bin_windows\belt_control_system.exe

pause
