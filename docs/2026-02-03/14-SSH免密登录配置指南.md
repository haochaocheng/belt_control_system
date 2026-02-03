# SSH 免密登录配置指南

**日期**: 2026-02-03
**目标设备**: 192.168.10.185（15寸屏）
**用户名**: linaro
**密码**: linaro

---

## 🎯 目标

为新设备 192.168.10.185 配置 SSH 免密登录，使其像 188 设备一样不需要每次输入密码。

---

## 📋 方法一：使用自动化脚本（推荐）

### 步骤1：运行配置脚本

```powershell
.\scripts\2026-02-03\setup-ssh-key-simple.ps1 -DeviceIP "192.168.10.185"
```

### 步骤2：按提示操作

1. 脚本会检查本地是否有 SSH 密钥
2. 如果没有，会自动生成（按3次回车使用默认设置）
3. 按任意键继续后，输入密码 `linaro`
4. 脚本会自动配置远程设备
5. 测试免密登录

---

## 📋 方法二：手动配置（如果脚本失败）

### 步骤1：生成 SSH 密钥（如果还没有）

```powershell
# 检查是否已有密钥
ls $env:USERPROFILE\.ssh\id_rsa.pub

# 如果没有，生成新密钥
ssh-keygen -t rsa -b 4096 -C "$env:USERNAME@$env:COMPUTERNAME"
# 按3次回车使用默认设置（不设置密码）
```

### 步骤2：查看公钥内容

```powershell
cat $env:USERPROFILE\.ssh\id_rsa.pub
```

复制输出的公钥内容（以 `ssh-rsa` 开头的整行）。

### 步骤3：连接到远程设备

```powershell
ssh linaro@192.168.10.185
# 输入密码：linaro
```

### 步骤4：在远程设备上配置公钥

```bash
# 创建 .ssh 目录
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# 添加公钥到 authorized_keys
echo '你的公钥内容' >> ~/.ssh/authorized_keys

# 去重（如果公钥已存在）
sort -u ~/.ssh/authorized_keys -o ~/.ssh/authorized_keys

# 设置正确的权限
chmod 600 ~/.ssh/authorized_keys

# 退出远程设备
exit
```

### 步骤5：测试免密登录

```powershell
ssh linaro@192.168.10.185
# 应该不需要输入密码，直接登录
```

---

## 📋 方法三：使用 ssh-copy-id（如果可用）

如果您的系统有 `ssh-copy-id` 命令（Git Bash 或 WSL），可以使用：

```bash
ssh-copy-id linaro@192.168.10.185
# 输入密码：linaro
```

这是最简单的方法，会自动完成所有配置。

---

## 🔧 故障排查

### 问题1：仍然需要输入密码

**可能原因**：
1. 远程设备的 SSH 配置不允许公钥认证
2. 权限设置不正确

**解决方案**：

1. **检查远程设备的 SSH 配置**：

```bash
ssh linaro@192.168.10.185
cat /etc/ssh/sshd_config | grep -E "PubkeyAuthentication|AuthorizedKeysFile"
```

确保以下配置：
```
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
```

如果配置不正确，修改后重启 SSH 服务：
```bash
sudo systemctl restart sshd
```

2. **检查权限**：

```bash
ssh linaro@192.168.10.185
ls -la ~/.ssh
```

应该看到：
```
drwx------  2 linaro linaro 4096 ... .ssh
-rw-------  1 linaro linaro  xxx ... authorized_keys
```

如果权限不正确，修复：
```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

### 问题2：公钥文件不存在

**解决方案**：

重新生成 SSH 密钥：
```powershell
ssh-keygen -t rsa -b 4096 -C "$env:USERNAME@$env:COMPUTERNAME"
```

### 问题3：连接超时或拒绝

**可能原因**：
1. 网络连接问题
2. 设备 IP 地址错误
3. SSH 服务未运行

**解决方案**：

1. **检查网络连接**：
```powershell
ping 192.168.10.185
```

2. **检查 SSH 服务**：
```bash
ssh linaro@192.168.10.185
sudo systemctl status sshd
```

---

## 📝 验证配置

### 1. 测试免密登录

```powershell
ssh linaro@192.168.10.185 "echo '✅ 免密登录成功'"
```

应该不需要输入密码，直接输出 "✅ 免密登录成功"。

### 2. 测试构建脚本

```powershell
.\build-ubuntu24-apt.ps1 192.168.10.185
```

应该不需要输入密码，直接开始构建和部署。

---

## 🔑 SSH 密钥位置

- **私钥**：`C:\Users\你的用户名\.ssh\id_rsa`
- **公钥**：`C:\Users\你的用户名\.ssh\id_rsa.pub`

**⚠️ 重要**：
- 私钥文件 (`id_rsa`) 必须保密，不要分享给任何人
- 公钥文件 (`id_rsa.pub`) 可以安全地复制到远程设备

---

## 📚 相关文档

- [SSH 密钥认证原理](https://www.ssh.com/academy/ssh/public-key-authentication)
- [OpenSSH 配置指南](https://www.openssh.com/manual.html)

---

## 💡 提示

1. **一次配置，多设备使用**：
   - 同一个公钥可以添加到多个设备
   - 不需要为每个设备生成新的密钥对

2. **安全建议**：
   - 定期更换 SSH 密钥（建议每年一次）
   - 使用强密码保护私钥（可选）
   - 不要在不安全的网络上使用 SSH

3. **备份密钥**：
   - 建议备份 `~/.ssh` 目录
   - 如果丢失私钥，需要重新生成并配置所有设备

---

**创建日期**: 2026-02-03
**状态**: ✅ 配置指南
**编写人员**: Claude Sonnet 4.5
