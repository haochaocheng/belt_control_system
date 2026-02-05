# Keil 网络阻止工具使用说明

**目的**: 阻止 Keil 所有应用程序访问外网
**版本**: v2.0（改进版）
**日期**: 2026-01-27

## 📦 文件清单

| 文件 | 用途 | 风险 |
|------|------|------|
| `block-keil-network.ps1` | 原始版本 | 🟡 中等 |
| `block-keil-network-v2.ps1` | 改进版本（推荐） | 🟢 低 |
| `unblock-keil-network.ps1` | 撤销脚本 | 🟢 低 |

## 🆚 版本对比

### 原始版本 (v1.0)
```
❌ 无确认提示
❌ 无白名单
❌ 无日志记录
❌ 阻止所有 .exe
```

### 改进版本 (v2.0) ✅ 推荐
```
✅ 添加确认提示（需输入 YES）
✅ 白名单支持（不阻止工具链）
✅ 日志记录（保存操作记录）
✅ 管理员权限检查
✅ 详细的执行反馈
```

## 🚀 使用方法

### 步骤 1: 阻止网络访问

```powershell
# 右键点击 block-keil-network-v2.ps1
# 选择"以管理员身份运行"

# 或在管理员 PowerShell 中运行
.\block-keil-network-v2.ps1
```

**执行流程**:
1. 检查管理员权限
2. 扫描 Keil 目录
3. 显示将阻止的程序数量
4. 要求输入 YES 确认
5. 创建防火墙规则
6. 生成日志文件

### 步骤 2: 撤销阻止（如需要）

```powershell
# 右键点击 unblock-keil-network.ps1
# 选择"以管理员身份运行"

# 或在管理员 PowerShell 中运行
.\unblock-keil-network.ps1
```

**执行流程**:
1. 检查管理员权限
2. 查找所有 Keil 阻止规则
3. 显示规则列表
4. 要求输入 YES 确认
5. 删除所有规则
6. 验证删除结果

## ⚙️ 配置选项

### 修改 Keil 路径

编辑 `block-keil-network-v2.ps1` 第 6 行：
```powershell
$keilPath = "C:\Keil_v5"  # 修改为您的 Keil 安装路径
```

### 修改白名单

编辑 `block-keil-network-v2.ps1` 第 10-17 行：
```powershell
$whitelist = @(
    "armcc.exe",      # ARM C 编译器
    "armlink.exe",    # ARM 链接器
    "fromelf.exe",    # ELF 转换工具
    "armar.exe",      # ARM 归档工具
    "ULink2.exe",     # ULink2 调试器
    "JLink.exe"       # J-Link 调试器
)
```

**添加更多程序到白名单**:
```powershell
$whitelist = @(
    "armcc.exe",
    "armlink.exe",
    "fromelf.exe",
    "armar.exe",
    "ULink2.exe",
    "JLink.exe",
    "YourProgram.exe"  # 添加您的程序
)
```

## 📊 执行示例

### 阻止网络访问

```
========================================
Keil 网络访问阻止工具 v2.0
========================================

正在扫描 Keil 目录...
找到 45 个 .exe 文件

将阻止: 39 个程序
白名单跳过: 6 个程序

白名单程序（不会阻止）:
  - armcc.exe
  - armlink.exe
  - fromelf.exe
  - armar.exe
  - ULink2.exe
  - JLink.exe

警告: 此操作将阻止以下类型的程序访问网络:
  - Keil µVision (UV4.exe, UV5.exe)
  - Pack 安装器 (PackInstaller.exe)
  - 其他辅助工具

影响:
  ❌ 无法检查更新
  ❌ 无法下载 Pack
  ⚠️  可能影响许可证验证

是否继续？(输入 YES 确认): YES

开始添加防火墙规则...
[1/39] ✅ 已阻止: UV4.exe
[2/39] ✅ 已阻止: UV5.exe
[3/39] ✅ 已阻止: PackInstaller.exe
...

========================================
执行完成！
========================================
✅ 成功添加: 39 条阻止规则
⏭️  已存在跳过: 0 条规则
📝 日志文件: keil-block-log-20260127-223000.txt
========================================

如需撤销，请运行: unblock-keil-network.ps1
```

### 撤销阻止

```
========================================
Keil 网络访问撤销工具 v1.0
========================================

正在查找 Keil 阻止规则...
找到 39 条 Keil 阻止规则

规则列表:
  [1] Keil_Block_12345678
  [2] Keil_Block_23456789
  ...

警告: 此操作将删除所有 Keil 网络阻止规则
删除后，Keil 程序将可以访问网络

是否继续？(输入 YES 确认): YES

开始删除防火墙规则...
[1/39] ✅ 已删除: Keil_Block_12345678
[2/39] ✅ 已删除: Keil_Block_23456789
...

========================================
执行完成！
========================================
✅ 成功删除: 39 条规则
========================================

验证: 检查是否还有残留规则...
✅ 所有规则已成功删除

Keil 程序现在可以访问网络了
```

## 🔍 验证方法

### 检查防火墙规则

```powershell
# 查看所有 Keil 阻止规则
Get-NetFirewallRule -DisplayName "Keil_Block_*"

# 查看规则详情
Get-NetFirewallRule -DisplayName "Keil_Block_*" | Format-List *

# 统计规则数量
(Get-NetFirewallRule -DisplayName "Keil_Block_*").Count
```

### 测试网络访问

1. 打开 Keil µVision
2. Help → Check for Updates
3. 如果显示"无法连接"，说明阻止成功

### 查看日志

```powershell
# 查看最新日志
Get-ChildItem keil-block-log-*.txt | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content
```

## ⚠️ 注意事项

### 1. 管理员权限

**必须以管理员身份运行**，否则会失败：
```
错误: 需要管理员权限运行此脚本
请右键点击脚本，选择'以管理员身份运行'
```

### 2. 许可证验证

如果 Keil 使用在线许可证验证，阻止后可能无法使用：
```
License verification failed
Unable to connect to license server
```

**解决**: 将许可证相关程序添加到白名单

### 3. Pack 下载

阻止后无法下载软件包：
```
Failed to download pack
Network connection error
```

**解决**: 临时撤销阻止，下载完成后重新阻止

### 4. 更新检查

阻止后无法检查更新：
```
Update check failed
Unable to connect to update server
```

**解决**: 这是预期行为，如需更新请撤销阻止

## 🛠️ 故障排查

### 问题 1: 脚本无法运行

**错误**: `无法加载文件，因为在此系统上禁止运行脚本`

**解决**:
```powershell
# 临时允许脚本执行
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# 然后运行脚本
.\block-keil-network-v2.ps1
```

### 问题 2: 规则创建失败

**错误**: `添加失败: UV4.exe`

**原因**:
- 权限不足
- 防火墙服务未运行
- 程序路径包含特殊字符

**解决**:
1. 确认以管理员身份运行
2. 检查防火墙服务：`Get-Service mpssvc`
3. 检查日志文件查看详细错误

### 问题 3: 撤销后仍无法访问网络

**原因**: 可能有其他防火墙规则或安全软件阻止

**检查**:
```powershell
# 检查所有出站阻止规则
Get-NetFirewallRule -Direction Outbound -Action Block | Where-Object {$_.DisplayName -like "*Keil*"}

# 检查 hosts 文件
Get-Content C:\Windows\System32\drivers\etc\hosts | Select-String "keil"
```

## 📚 相关文档

- [31-block-keil-network脚本风险评估.md](docs/2026-01-27/31-block-keil-network脚本风险评估.md) - 详细风险分析
- [28-Wireshark过滤Keil连接指南.md](docs/2026-01-27/28-Wireshark过滤Keil连接指南.md) - 网络监控

## ✅ 推荐使用流程

1. **首次使用**: 运行 `block-keil-network-v2.ps1`
2. **测试 Keil**: 确认基本功能正常
3. **如需下载 Pack**: 运行 `unblock-keil-network.ps1`
4. **下载完成**: 重新运行 `block-keil-network-v2.ps1`
5. **长期使用**: 保持阻止状态

## 🎯 总结

| 项目 | 说明 |
|------|------|
| **推荐版本** | block-keil-network-v2.ps1 |
| **风险等级** | 🟢 低（改进版） |
| **可逆性** | ✅ 完全可逆 |
| **影响范围** | 仅 Keil 程序 |
| **适用场景** | 离线开发环境 |
