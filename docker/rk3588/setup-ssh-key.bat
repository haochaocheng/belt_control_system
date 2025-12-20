@echo off
chcp 65001 >nul
echo ========================================
echo 配置SSH免密登录
echo ========================================
echo.
echo 这将配置SSH密钥,之后不需要输入密码
echo.
pause

echo.
echo 1. 生成SSH密钥...
if not exist "%USERPROFILE%\.ssh\id_rsa" (
    ssh-keygen -t rsa -b 2048 -f "%USERPROFILE%\.ssh\id_rsa" -N ""
    echo ✓ SSH密钥已生成
) else (
    echo ✓ SSH密钥已存在
)

echo.
echo 2. 上传公钥到工控机...
echo 请输入工控机密码(pi):
type "%USERPROFILE%\.ssh\id_rsa.pub" | ssh pi@192.168.10.170 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && chmod 700 ~/.ssh"

echo.
echo 3. 测试免密登录...
ssh pi@192.168.10.170 "echo '✓ 免密登录成功!'"

echo.
echo ========================================
echo 配置完成!
echo ========================================
echo.
echo 现在可以运行部署脚本,不再需要输入密码
echo.
pause
