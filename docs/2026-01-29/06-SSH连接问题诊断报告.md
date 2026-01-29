# SSH 连接问题诊断报告

**时间**: 2026-01-29
**设备**: 192.168.10.185
**问题**: SSH 连接超时

---

## 问题描述

在 Docker 安装过程后，SSH 连接无法建立。

**症状**:
```
Connection timed out during banner exchange
Connection to 192.168.10.185 port 22 timed out
```

**网络状态**:
- ✅ Ping 正常（延迟 <1ms）
- ❌ SSH 端口 22 无响应

---

## 可能原因

### 1. SSH 服务停止
Docker 安装过程中可能触发了系统更新或服务重启，导致 SSH 服务停止。

### 2. 系统重启
设备可能在安装过程中重启，但 SSH 服务没有自动启动。

### 3. 防火墙规则变更
Docker 安装可能修改了防火墙规则，阻止了 SSH 连接。

### 4. 网络配置变更
Docker 网络配置可能影响了主机网络。

---

## 解决方案

### 方案一：物理访问设备（推荐）

**步骤 1: 连接显示器和键盘**
- 将显示器连接到设备的 HDMI 接口
- 连接 USB 键盘

**步骤 2: 登录设备**
```
用户名: linaro
密码: linaro
```

**步骤 3: 检查 SSH 服务状态**
```bash
# 检查 SSH 服务状态
sudo systemctl status sshd
# 或
sudo systemctl status ssh

# 如果服务未运行，查看日志
sudo journalctl -u sshd -n 50
# 或
sudo journalctl -u ssh -n 50
```

**步骤 4: 启动 SSH 服务**
```bash
# 启动 SSH 服务
sudo systemctl start sshd
# 或
sudo systemctl start ssh

# 设置开机自启
sudo systemctl enable sshd
# 或
sudo systemctl enable ssh

# 验证服务状态
sudo systemctl status sshd
```

**步骤 5: 检查防火墙**
```bash
# 检查防火墙状态
sudo ufw status

# 如果防火墙启用，允许 SSH
sudo ufw allow 22/tcp

# 重新加载防火墙
sudo ufw reload
```

**步骤 6: 检查网络配置**
```bash
# 检查网络接口
ip addr show

# 检查路由
ip route show

# 检查 SSH 监听端口
sudo netstat -tlnp | grep :22
# 或
sudo ss -tlnp | grep :22
```

**步骤 7: 重启网络服务（如果需要）**
```bash
# 重启网络服务
sudo systemctl restart networking

# 或重启 NetworkManager
sudo systemctl restart NetworkManager
```

**步骤 8: 测试 SSH 连接**
```bash
# 在设备上测试本地 SSH
ssh localhost

# 从 Windows 测试
# 在 PowerShell 中运行
ssh linaro@192.168.10.185
```

---

### 方案二：远程重启（如果有其他访问方式）

如果设备有其他远程访问方式（如串口、IPMI、远程电源管理），可以尝试：

1. 远程重启设备
2. 等待设备启动完成（约 1-2 分钟）
3. 测试 SSH 连接

---

### 方案三：检查 Docker 影响

Docker 安装可能影响了网络配置。在物理访问设备后：

```bash
# 检查 Docker 服务状态
sudo systemctl status docker

# 临时停止 Docker 服务测试
sudo systemctl stop docker

# 测试 SSH 连接是否恢复
# 从另一台机器测试: ssh linaro@192.168.10.185

# 如果 SSH 恢复，检查 Docker 网络配置
sudo docker network ls
sudo docker network inspect bridge

# 检查 iptables 规则
sudo iptables -L -n -v
```

---

## 预防措施

### 1. 配置 SSH 服务自动重启

```bash
# 编辑 SSH 服务配置
sudo systemctl edit sshd

# 添加以下内容
[Service]
Restart=always
RestartSec=5

# 保存并退出
# 重新加载配置
sudo systemctl daemon-reload
```

### 2. 配置看门狗（Watchdog）

```bash
# 安装 watchdog
sudo apt install watchdog

# 配置 watchdog 监控 SSH 服务
sudo nano /etc/watchdog.conf

# 添加
pidfile = /var/run/sshd.pid

# 启动 watchdog
sudo systemctl enable watchdog
sudo systemctl start watchdog
```

### 3. 配置串口访问（备用访问方式）

```bash
# 启用串口控制台
sudo systemctl enable serial-getty@ttyS0.service
sudo systemctl start serial-getty@ttyS0.service
```

---

## 诊断命令汇总

在设备上运行以下命令收集诊断信息：

```bash
# 系统信息
uname -a
uptime

# SSH 服务状态
sudo systemctl status sshd
sudo systemctl status ssh
sudo journalctl -u sshd -n 50

# 网络状态
ip addr show
ip route show
sudo netstat -tlnp | grep :22
sudo ss -tlnp | grep :22

# 防火墙状态
sudo ufw status verbose
sudo iptables -L -n -v

# Docker 状态
sudo systemctl status docker
sudo docker ps
sudo docker network ls

# 系统日志
sudo journalctl -n 100
sudo dmesg | tail -50
```

---

## 下一步

1. **立即操作**: 物理访问设备，按照方案一的步骤操作
2. **收集信息**: 运行诊断命令，收集系统状态信息
3. **报告问题**: 如果问题持续，提供诊断信息以便进一步分析

---

## 相关脚本

- `scripts/2026-01-29/09-diagnose-ssh.ps1` - SSH 诊断脚本（待修复）

---

**文档创建时间**: 2026-01-29
**状态**: 待解决
