@echo off
echo ==============================================
echo 正在重新编译应用程序...
echo ==============================================
cd /d e:\2025\3_gongkongji\belt_control_system
taskkill /F /IM belt_control_system.exe 2>nul

C:\Qt\Tools\CMake_64\bin\cmake.exe --build build --target belt_control_system
if %ERRORLEVEL% NEQ 0 (
    echo 编译失败!
    pause
    exit /b 1
)

echo.
echo ==============================================
echo 编译成功!正在启动应用程序...
echo ==============================================
timeout /t 2 >nul
start build\bin_windows\belt_control_system.exe

echo.
echo ==============================================
echo 应用程序已启动!
echo 请测试 SIP 功能:
echo 1. 点击右上角的 VoIP 按钮 (📞)
echo 2. 打开 SIP 设置页面
echo 3. 尝试注册 SIP 账号
echo
echo 如果出现 FD_SETSIZE 断言错误,请告诉我!
echo ==============================================
