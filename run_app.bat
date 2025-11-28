@echo off
cd /d %~dp0\build\bin_windows
start belt_control_system.exe
timeout /t 3
tasklist | findstr belt_control_system
