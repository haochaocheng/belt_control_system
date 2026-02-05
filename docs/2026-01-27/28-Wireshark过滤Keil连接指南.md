# Wireshark 过滤 Keil 访问连接指南

**日期**: 2026-01-27 22:25
**目的**: 过滤和分析 Keil IDE 的网络连接
**工具**: Wireshark

## 🎯 常见场景

### 1. Keil 许可证验证
- 连接到许可证服务器
- 端口：通常是 8080, 443

### 2. Keil 更新检查
- 连接到 ARM/Keil 服务器
- 域名：`www.keil.com`, `developer.arm.com`

### 3. Pack 下载
- 下载软件包和库
- 域名：`www.keil.com/pack`

## 🔍 基本过滤方法

### 方法 1: 按进程名过滤

**Windows 进程名**：
- `UV4.exe` - Keil µVision 4
- `UV5.exe` - Keil µVision 5
- `MDK.exe` - MDK-ARM

**Wireshark 过滤器**：
```
# 过滤 Keil µVision 5
tcp.stream and (frame contains "UV5.exe")

# 或使用进程 ID（需要先找到 PID）
tcp.stream and (tcp.srcport == <Keil_PID> or tcp.dstport == <Keil_PID>)
```

### 方法 2: 按目标域名过滤

```
# 过滤所有 Keil 相关域名
http.host contains "keil.com" or dns.qry.name contains "keil.com"

# 过滤 ARM 相关域名
http.host contains "arm.com" or dns.qry.name contains "arm.com"

# 组合过滤
(http.host contains "keil.com" or http.host contains "arm.com") or
(dns.qry.name contains "keil.com" or dns.qry.name contains "arm.com")
```

### 方法 3: 按 IP 地址过滤

**先查找 Keil 服务器 IP**：
```powershell
# PowerShell 查询
nslookup www.keil.com
nslookup developer.arm.com
```

**Wireshark 过滤器**：
```
# 假设 Keil 服务器 IP 是 104.18.32.68
ip.addr == 104.18.32.68

# 过滤多个 IP
ip.addr == 104.18.32.68 or ip.addr == 104.18.33.68
```

### 方法 4: 按端口过滤

```
# HTTP 流量
tcp.port == 80

# HTTPS 流量
tcp.port == 443

# 许可证服务器（常见端口）
tcp.port == 8080 or tcp.port == 27000

# 组合过滤
(tcp.port == 80 or tcp.port == 443 or tcp.port == 8080) and
(http.host contains "keil.com" or http.host contains "arm.com")
```

## 🎨 高级过滤技巧

### 1. 过滤 HTTP 请求

```
# 所有 HTTP GET 请求到 Keil
http.request.method == "GET" and http.host contains "keil.com"

# 所有 HTTP POST 请求
http.request.method == "POST" and http.host contains "keil.com"

# 特定 URL 路径
http.request.uri contains "/pack/" or http.request.uri contains "/download/"
```

### 2. 过滤 HTTPS/TLS 连接

```
# TLS 握手
ssl.handshake.type == 1 and (ssl.handshake.extensions_server_name contains "keil.com")

# 或使用 SNI (Server Name Indication)
tls.handshake.extensions_server_name contains "keil.com"
```

### 3. 过滤 DNS 查询

```
# DNS 查询 Keil 域名
dns.qry.name contains "keil.com"

# DNS 响应
dns.flags.response == 1 and dns.qry.name contains "keil.com"
```

### 4. 组合过滤器（推荐）

```
# 完整的 Keil 流量过滤
(http.host contains "keil.com" or http.host contains "arm.com" or
 dns.qry.name contains "keil.com" or dns.qry.name contains "arm.com" or
 tls.handshake.extensions_server_name contains "keil.com" or
 tls.handshake.extensions_server_name contains "arm.com")
```

## 📋 实战步骤

### 步骤 1: 启动 Wireshark

```powershell
# 以管理员权限运行 Wireshark
# 选择网络接口（通常是 Wi-Fi 或以太网）
```

### 步骤 2: 开始捕获

1. 点击 "Capture" → "Start"
2. 或按 `Ctrl+E`

### 步骤 3: 启动 Keil

1. 打开 Keil µVision
2. 执行需要网络的操作：
   - 检查更新
   - 下载 Pack
   - 许可证验证

### 步骤 4: 应用过滤器

在 Wireshark 顶部的过滤器栏输入：
```
http.host contains "keil.com" or dns.qry.name contains "keil.com"
```

### 步骤 5: 分析结果

- 查看 DNS 查询：找到 Keil 服务器 IP
- 查看 HTTP 请求：分析访问的 URL
- 查看 TLS 握手：确认 HTTPS 连接

## 🔧 使用 Process Monitor 辅助

**更精确的方法**：结合 Process Monitor

### 1. 下载 Process Monitor
```
https://docs.microsoft.com/en-us/sysinternals/downloads/procmon
```

### 2. 过滤 Keil 进程

```
Process Name is UV5.exe
Operation is TCP Connect
Operation is TCP Send
Operation is TCP Receive
```

### 3. 查看连接信息

- 目标 IP 地址
- 目标端口
- 连接时间

### 4. 在 Wireshark 中使用

```
# 使用 Process Monitor 找到的 IP
ip.addr == <从 Process Monitor 获取的 IP>
```

## 📊 常见 Keil 连接

| 服务 | 域名 | IP 示例 | 端口 | 用途 |
|------|------|---------|------|------|
| 主站 | www.keil.com | 104.18.32.68 | 80, 443 | 网站访问 |
| Pack 下载 | www.keil.com/pack | 104.18.32.68 | 443 | 软件包下载 |
| 许可证 | license.keil.com | 变化 | 8080, 443 | 许可证验证 |
| ARM 开发者 | developer.arm.com | 变化 | 443 | 文档和资源 |

## 🎯 实用过滤器模板

### 模板 1: 基础过滤
```
http.host contains "keil" or dns.qry.name contains "keil"
```

### 模板 2: 完整过滤
```
(http.host contains "keil.com" or http.host contains "arm.com") or
(dns.qry.name contains "keil.com" or dns.qry.name contains "arm.com") or
(tls.handshake.extensions_server_name contains "keil.com" or
 tls.handshake.extensions_server_name contains "arm.com")
```

### 模板 3: 许可证服务器
```
tcp.port == 8080 or tcp.port == 27000 or
(http.host contains "license" and http.host contains "keil")
```

### 模板 4: Pack 下载
```
http.request.uri contains "/pack/" or
http.request.uri contains ".pack" or
http.host contains "www.keil.com/pack"
```

## 🚫 阻止 Keil 连接（可选）

### 方法 1: 修改 hosts 文件

```
# Windows: C:\Windows\System32\drivers\etc\hosts
127.0.0.1 www.keil.com
127.0.0.1 license.keil.com
127.0.0.1 developer.arm.com
```

### 方法 2: 防火墙规则

```powershell
# PowerShell - 阻止 Keil 出站连接
New-NetFirewallRule -DisplayName "Block Keil" `
    -Direction Outbound `
    -Program "C:\Keil_v5\UV4\UV4.exe" `
    -Action Block
```

## 📝 导出和分析

### 导出过滤后的数据

1. 应用过滤器
2. File → Export Specified Packets
3. 选择 "Displayed" 只导出过滤后的包

### 统计分析

```
Statistics → Conversations → TCP
# 查看 Keil 的连接统计

Statistics → HTTP → Requests
# 查看 HTTP 请求统计
```

## 🐛 故障排查

### 问题 1: 看不到任何流量

**原因**:
- Keil 使用系统代理
- 流量被加密（HTTPS）

**解决**:
```
# 检查系统代理设置
netsh winhttp show proxy

# 如果使用代理，过滤代理服务器
ip.addr == <代理服务器 IP>
```

### 问题 2: 过滤器不工作

**检查**:
- 语法是否正确
- 是否在捕获期间应用过滤器
- 尝试简化过滤器

### 问题 3: 无法解密 HTTPS

**说明**: HTTPS 流量是加密的，无法直接查看内容

**替代方案**:
- 使用 Fiddler（支持 HTTPS 解密）
- 配置 SSL/TLS 密钥日志

## 🔗 相关工具

| 工具 | 用途 | 下载 |
|------|------|------|
| Wireshark | 网络抓包 | https://www.wireshark.org/ |
| Process Monitor | 进程监控 | https://docs.microsoft.com/sysinternals |
| Fiddler | HTTP/HTTPS 代理 | https://www.telerik.com/fiddler |
| TCPView | TCP 连接查看 | https://docs.microsoft.com/sysinternals |

## 💡 最佳实践

1. **先用简单过滤器**: 从 `http.host contains "keil"` 开始
2. **结合 DNS 查询**: 找到实际 IP 地址
3. **使用 Process Monitor**: 确认进程和连接
4. **保存过滤器**: 常用过滤器保存为配置文件
5. **导出数据**: 保存过滤后的包供后续分析

## 📚 参考资料

- Wireshark 官方文档: https://www.wireshark.org/docs/
- Wireshark 过滤器语法: https://wiki.wireshark.org/DisplayFilters
- Keil 官方支持: https://www.keil.com/support/

## ✅ 快速参考

**最常用的过滤器**：
```
# 基础过滤
http.host contains "keil" or dns.qry.name contains "keil"

# 完整过滤（推荐）
(http.host contains "keil.com" or dns.qry.name contains "keil.com" or
 tls.handshake.extensions_server_name contains "keil.com")
```

**快捷键**：
- `Ctrl+E`: 开始/停止捕获
- `Ctrl+F`: 查找
- `Ctrl+Shift+F`: 应用过滤器
