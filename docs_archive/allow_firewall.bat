@echo off
echo 正在添加 Windows 防火墙规则允许 belt_control_system.exe...
netsh advfirewall firewall delete rule name="Belt Control System SIP" 2>nul
netsh advfirewall firewall add rule name="Belt Control System SIP" dir=in action=allow program="%~dp0build\bin_windows\belt_control_system.exe" enable=yes protocol=UDP localport=5062
netsh advfirewall firewall add rule name="Belt Control System SIP OUT" dir=out action=allow program="%~dp0build\bin_windows\belt_control_system.exe" enable=yes protocol=UDP localport=5062
echo.
echo 防火墙规则已添加!
echo.
pause
