# SIP 注册问题诊断

## 当前状态
- ✅ PJSIP 能发送 REGISTER 请求
- ✅ FreeSWITCH 返回 401 Unauthorized (Wireshark 可见)
- ❌ PJSIP 没有收到 401 响应 (日志中无 RX 记录)
- ❌ PJSIP 一直重传原始 REGISTER

## 问题分析
**根本原因**: PJSIP 的 UDP socket 没有正确接收数据

**可能原因**:
1. Worker 线程未正确创建/运行
2. UDP socket 绑定到错误的接口
3. Windows select() 实现问题
4. 端口冲突或防火墙(已排除,PortSIP 可用)

## 需要确认的信息
请运行以下命令并发送输出:

```cmd
netstat -ano | findstr :53161
```

(替换 53161 为您实际使用的端口)

这将显示:
- UDP 0.0.0.0:53161 -> socket 是否监听
- 进程 PID

如果没有输出,说明 socket 根本没有绑定!
