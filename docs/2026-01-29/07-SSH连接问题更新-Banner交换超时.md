# SSH 连接问题更新 - Banner 交换超时

**更新时间**: 2026-01-29
**新发现**: SSH 服务正在运行，但 banner 交换超时

---

## 问题更新

### SSH 服务状态
```
✅ SSH 服务运行中
Service: ssh.service - OpenBSD Secure Shell server
Status: ACTIVE (running)
Main PID: [运行中]
Tasks: 1
CGroup: [正常]
```

### 连接诊断
```
✅ TCP 连接建立成功 (Connection established)
❌ Banner 交换超时 (Connection timed out during banner exchange)
```

这说明：
- 网络层连接正常
- SSH 服务在监听
- 但 SSH 协议握手失败

---

## 可能原因

### 1. SSH 服务负载过高
SSH 服务可能正在处理大量连接或卡住了。

**在设备上检查**:
```bash
# 查看 SSH 进程
ps aux | grep sshd

# 查看 SSH 连接数
sudo netstat -tnpa | grep :22 | grep ESTABLISHED

# 查看系统负载
uptime
top -bn1 | head -20
```

### 2. 网络问题
可能存在网络延迟或丢包。

**在设备上检查**:
```bash
# 检查网络接口
ip addr show

# 检查网络统计
netstat -i

# 检查 SSH 监听
sudo ss -tlnp | grep :22
```

### 3. SSH 配置问题
SSH 配置可能有问题。

**在设备上检查**:
```bash
# 查看 SSH 配置
sudo cat /etc/ssh/sshd_config | grep -v "^#" | grep -v "^$"

# 查看 SSH 日志
sudo journalctl -u ssh -n 50 --no-pager

# 测试 SSH 配置
sudo sshd -t
```

### 4. DNS 反向解析慢
SSH 可能在等待 DNS 反向解析。

**在设备上检查**:
```bash
# 查看 SSH 配置中的 DNS 设置
grep -i "UseDNS" /etc/ssh/sshd_config
```

---

## 立即解决方案

### 方案一：重启 SSH 服务

在设备上执行：
```bash
# 重启 SSH 服务
sudo systemctl restart ssh

# 或强制重启
sudo systemctl restart sshd

# 检查状态
sudo systemctl status ssh

# 查看最新日志
sudo journalctl -u ssh -n 20 --no-pager
```

### 方案二：禁用 DNS 反向解析

在设备上执行：
```bash
# 编辑 SSH 配置
sudo nano /etc/ssh/sshd_config

# 添加或修改以下行
UseDNS no

# 保存并退出（Ctrl+X, Y, Enter）

# 重启 SSH 服务
sudo systemctl restart ssh
```

### 方案三：增加 SSH 超时时间

在设备上执行：
```bash
# 编辑 SSH 配置
sudo nano /etc/ssh/sshd_config

# 添加或修改以下行
ClientAliveInterval 60
ClientAliveCountMax 3
LoginGraceTime 120

# 保存并退出

# 重启 SSH 服务
sudo systemctl restart ssh
```

### 方案四：检查并清理僵尸连接

在设备上执行：
```bash
# 查看所有 SSH 连接
sudo netstat -tnpa | grep :22

# 如果有大量 CLOSE_WAIT 或 TIME_WAIT 连接，重启 SSH
sudo systemctl restart ssh

# 或者杀死所有 SSH 进程（谨慎使用！）
# sudo pkill -9 sshd
# sudo systemctl start ssh
```

---

## 临时解决方案（从 Windows 端）

### 增加 SSH 客户端超时

在 Windows PowerShell 中：
```powershell
# 使用更长的超时时间
ssh -o ConnectTimeout=30 -o ServerAliveInterval=10 linaro@192.168.10.185

# 或者使用密码登录（跳过密钥）
ssh -o PreferredAuthentications=password linaro@192.168.10.185
```

### 使用不同的 SSH 客户端

```powershell
# 使用 PuTTY
# 下载 PuTTY 并尝试连接

# 或使用 Windows 内置的 SSH（如果不同）
C:\Windows\System32\OpenSSH\ssh.exe linaro@192.168.10.185
```

---

## 诊断命令汇总

在设备上运行以下命令：

```bash
#!/bin/bash
echo "=== SSH 诊断信息 ==="
echo ""

echo "[1] SSH 服务状态"
sudo systemctl status ssh --no-pager
echo ""

echo "[2] SSH 进程"
ps aux | grep sshd | grep -v grep
echo ""

echo "[3] SSH 监听端口"
sudo ss -tlnp | grep :22
echo ""

echo "[4] SSH 连接"
sudo netstat -tnpa | grep :22
echo ""

echo "[5] 系统负载"
uptime
echo ""

echo "[6] 内存使用"
free -h
echo ""

echo "[7] SSH 配置（关键部分）"
sudo grep -E "^(Port|ListenAddress|UseDNS|LoginGraceTime|ClientAlive)" /etc/ssh/sshd_config
echo ""

echo "[8] SSH 最近日志"
sudo journalctl -u ssh -n 20 --no-pager
echo ""

echo "[9] 网络接口"
ip addr show
echo ""

echo "[10] 防火墙状态"
sudo ufw status
echo ""
```

---

## 推荐操作顺序

1. **重启 SSH 服务**（最简单）
   ```bash
   sudo systemctl restart ssh
   ```

2. **禁用 DNS 反向解析**（常见问题）
   ```bash
   echo "UseDNS no" | sudo tee -a /etc/ssh/sshd_config
   sudo systemctl restart ssh
   ```

3. **从 Windows 测试**
   ```powershell
   ssh -o ConnectTimeout=30 linaro@192.168.10.185
   ```

4. **如果仍然失败，收集诊断信息**
   运行上面的诊断命令脚本

---

## 下一步

1. 在设备上执行推荐操作
2. 测试 SSH 连接
3. 如果问题持续，收集诊断信息

---

**文档更新时间**: 2026-01-29
**状态**: 诊断中 - Banner 交换超时
