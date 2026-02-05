# block-keil-network.ps1 脚本风险评估报告

**脚本路径**: `block-keil-network.ps1`
**评估日期**: 2026-01-27
**目的**: 阻止 Keil_v5 目录下所有 .exe 文件访问外网

## 📋 脚本功能概述

### 主要功能
1. 扫描 `C:\Keil_v5` 目录下所有 `.exe` 文件
2. 为每个 .exe 文件创建 Windows 防火墙出站阻止规则
3. 阻止这些程序访问互联网

### 技术实现
- 使用 `netsh advfirewall` 命令
- 创建出站（Outbound）阻止规则
- 使用 MD5 哈希生成唯一规则名称

## ⚠️ 风险评估

### 🟢 低风险项

| 项目 | 说明 | 风险等级 |
|------|------|----------|
| 只读操作 | 扫描文件不修改文件系统 | 🟢 低 |
| 可逆操作 | 防火墙规则可以删除 | 🟢 低 |
| 明确目标 | 只针对 Keil_v5 目录 | 🟢 低 |
| 错误处理 | 使用 `-ErrorAction SilentlyContinue` | 🟢 低 |
| 重复检查 | 检查规则是否已存在 | 🟢 低 |

### 🟡 中等风险项

| 项目 | 说明 | 风险等级 | 影响 |
|------|------|----------|------|
| 需要管理员权限 | 修改防火墙需要管理员 | 🟡 中 | 普通用户无法运行 |
| 影响所有 .exe | 包括工具链和辅助程序 | 🟡 中 | 可能影响正常功能 |
| 批量操作 | 一次性创建大量规则 | 🟡 中 | 防火墙规则列表变长 |
| 无确认提示 | 直接执行，无二次确认 | 🟡 中 | 误操作风险 |

### 🔴 高风险项

| 项目 | 说明 | 风险等级 | 后果 |
|------|------|----------|------|
| 阻止许可证验证 | 可能导致许可证失效 | 🔴 高 | Keil 无法使用 |
| 阻止更新检查 | 无法获取安全更新 | 🔴 高 | 安全漏洞 |
| 阻止 Pack 下载 | 无法下载软件包 | 🔴 高 | 功能受限 |
| 影响调试器 | 可能影响在线调试功能 | 🔴 高 | 开发受阻 |

## 🔍 详细代码分析

### 第 4 行：目标路径
```powershell
$keilPath = "C:\Keil_v5"
```
**风险**: 🟢 低
- 硬编码路径，只影响 Keil_v5
- 不会影响其他软件

### 第 5 行：扫描 .exe 文件
```powershell
$exeFiles = Get-ChildItem -Path $keilPath -Filter "*.exe" -Recurse -ErrorAction SilentlyContinue
```
**风险**: 🟢 低
- 只读操作，不修改文件
- `-ErrorAction SilentlyContinue` 避免权限错误

**影响范围**:
- 包括所有子目录
- 可能包含数十到上百个 .exe 文件

### 第 14 行：生成规则名称
```powershell
$pathHash = [System.BitConverter]::ToString([System.Security.Cryptography.MD5]::Create().ComputeHash([System.Text.Encoding]UTF8.GetBytes($exe.FullName))).Replace("-", "").Substring(0, 8)
$ruleName = "Keil_Block_$pathHash"
```
**风险**: 🟢 低
- 使用 MD5 哈希确保唯一性
- 规则名称格式：`Keil_Block_12345678`

**优点**:
- 避免规则名称冲突
- 可以通过名称识别 Keil 相关规则

### 第 18-22 行：创建防火墙规则
```powershell
$existing = netsh advfirewall firewall show rule name="$ruleName" 2>&1
if ($LASTEXITCODE -ne 0) {
    $result = netsh advfirewall firewall add rule name="$ruleName" dir=out action=block program="$($exe.FullName)" enable=yes profile=any description="阻止 $($exe.Name) 访问网络" 2>&1
```
**风险**: 🔴 高
- **需要管理员权限**
- **不可逆操作**（需要手动删除规则）
- **立即生效**

**参数说明**:
- `dir=out`: 出站规则（阻止程序访问外网）
- `action=block`: 阻止连接
- `enable=yes`: 立即启用
- `profile=any`: 所有网络配置文件（域、专用、公用）

## 🎯 影响的 Keil 程序

### 核心程序
| 程序 | 路径 | 影响 |
|------|------|------|
| UV4.exe | C:\Keil_v5\UV4\ | ❌ 无法检查更新、下载 Pack |
| UV5.exe | C:\Keil_v5\UV4\ | ❌ 无法检查更新、下载 Pack |
| PackInstaller.exe | C:\Keil_v5\ARM\Pack\ | ❌ 无法下载软件包 |

### 工具链程序
| 程序 | 路径 | 影响 |
|------|------|------|
| armcc.exe | C:\Keil_v5\ARM\ARMCC\ | ⚠️ 可能影响许可证验证 |
| armlink.exe | C:\Keil_v5\ARM\ARMCC\ | ⚠️ 可能影响许可证验证 |
| fromelf.exe | C:\Keil_v5\ARM\ARMCC\ | ⚠️ 可能影响许可证验证 |

### 调试器程序
| 程序 | 路径 | 影响 |
|------|------|------|
| ULink2.exe | C:\Keil_v5\ARM\ULink2\ | ⚠️ 可能影响在线调试 |
| JLink.exe | C:\Keil_v5\ARM\Segger\ | ⚠️ 可能影响在线调试 |

## 🚨 潜在问题

### 1. 许可证验证失败

**问题**: Keil 可能无法验证许可证

**症状**:
```
License verification failed
Unable to connect to license server
```

**解决**: 需要允许许可证相关程序访问网络

### 2. Pack 下载失败

**问题**: 无法下载软件包和库

**症状**:
```
Failed to download pack
Network connection error
```

**解决**: 需要允许 PackInstaller.exe 访问网络

### 3. 更新检查失败

**问题**: 无法检查和安装更新

**症状**:
```
Update check failed
Unable to connect to update server
```

**解决**: 需要允许 UV4.exe/UV5.exe 访问网络

### 4. 在线调试功能受限

**问题**: 某些在线调试功能可能无法使用

**症状**:
- 无法下载调试固件
- 无法更新调试器驱动

**解决**: 需要允许调试器程序访问网络

## ✅ 安全建议

### 推荐方案：选择性阻止

**不要阻止所有 .exe**，只阻止特定程序：

```powershell
# 只阻止主程序和更新程序
$blockList = @(
    "C:\Keil_v5\UV4\UV4.exe",
    "C:\Keil_v5\UV4\UV5.exe",
    "C:\Keil_v5\ARM\Pack\PackInstaller.exe"
)

foreach ($program in $blockList) {
    if (Test-Path $program) {
        netsh advfirewall firewall add rule `
            name="Block_$(Split-Path $program -Leaf)" `
            dir=out action=block program="$program" enable=yes
    }
}
```

### 白名单方案：允许特定连接

**更安全的方法**：只允许访问特定域名

```powershell
# 使用 hosts 文件阻止特定域名
Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value @"
127.0.0.1 www.keil.com
127.0.0.1 license.keil.com
127.0.0.1 developer.arm.com
"@
```

### 最佳实践：分级阻止

```powershell
# 级别 1: 只阻止更新检查
Block: UV4.exe, UV5.exe

# 级别 2: 阻止更新和 Pack 下载
Block: UV4.exe, UV5.exe, PackInstaller.exe

# 级别 3: 阻止所有网络访问（当前脚本）
Block: 所有 .exe 文件
```

## 🔧 改进建议

### 1. 添加确认提示

```powershell
Write-Host "即将阻止 $($exeFiles.Count) 个程序访问网络" -ForegroundColor Yellow
$confirm = Read-Host "是否继续？(Y/N)"
if ($confirm -ne "Y") {
    Write-Host "操作已取消"
    exit
}
```

### 2. 添加白名单

```powershell
# 不阻止的程序列表
$whitelist = @(
    "armcc.exe",
    "armlink.exe",
    "fromelf.exe"
)

if ($whitelist -contains $exe.Name) {
    Write-Host "白名单跳过: $($exe.Name)" -ForegroundColor Green
    continue
}
```

### 3. 添加日志记录

```powershell
$logFile = "keil-block-log.txt"
"[$(Get-Date)] 阻止: $($exe.FullName)" | Out-File -Append $logFile
```

### 4. 添加撤销脚本

创建配套的 `unblock-keil-network.ps1`：

```powershell
# 删除所有 Keil 阻止规则
$rules = netsh advfirewall firewall show rule name=all | Select-String "Keil_Block_"
foreach ($rule in $rules) {
    $ruleName = $rule -replace ".*Rule Name:\s+", ""
    netsh advfirewall firewall delete rule name="$ruleName"
}
```

## 📊 风险评分

| 类别 | 评分 | 说明 |
|------|------|------|
| 系统安全 | 🟢 8/10 | 不会损坏系统 |
| 数据安全 | 🟢 10/10 | 不涉及数据修改 |
| 功能影响 | 🔴 3/10 | 严重影响 Keil 功能 |
| 可逆性 | 🟡 6/10 | 可以撤销但需要手动 |
| 误操作风险 | 🟡 5/10 | 无确认提示 |

**总体风险**: 🟡 **中等**

## 🎯 使用建议

### 适用场景
✅ 离线开发环境
✅ 已有有效许可证
✅ 不需要下载 Pack
✅ 不需要更新 Keil

### 不适用场景
❌ 需要在线许可证验证
❌ 需要下载软件包
❌ 需要更新 Keil
❌ 使用在线调试功能

## 🔐 执行前检查清单

- [ ] 已备份当前防火墙规则
- [ ] 确认 Keil 许可证不需要在线验证
- [ ] 确认不需要下载 Pack
- [ ] 确认不需要更新 Keil
- [ ] 已准备撤销脚本
- [ ] 以管理员身份运行
- [ ] 了解可能的影响

## 📝 撤销方法

### 方法 1: 手动删除规则

```powershell
# 查看所有 Keil 阻止规则
netsh advfirewall firewall show rule name=all | Select-String "Keil_Block_"

# 删除单个规则
netsh advfirewall firewall delete rule name="Keil_Block_12345678"

# 删除所有 Keil 规则
Get-NetFirewallRule -DisplayName "Keil_Block_*" | Remove-NetFirewallRule
```

### 方法 2: 使用撤销脚本

创建 `unblock-keil-network.ps1`（见上文）

### 方法 3: 防火墙 GUI

1. 打开 Windows Defender 防火墙
2. 高级设置 → 出站规则
3. 查找 "Keil_Block_" 开头的规则
4. 右键 → 删除

## ✅ 结论

**脚本本身**: 🟢 安全，不会损坏系统或数据

**功能影响**: 🔴 严重，会阻止 Keil 的网络功能

**推荐做法**:
1. 使用选择性阻止（只阻止主程序）
2. 添加确认提示
3. 准备撤销脚本
4. 测试后再正式使用

**风险等级**: 🟡 **中等** - 可以使用，但需要了解影响
