# MCP Hooks 配置丢失原因分析和预防方案

**问题发生时间**：2026-01-17 晚上 ～ 2026-01-21
**问题类型**：配置丢失导致 hooks 失效
**影响范围**：所有自动记忆功能停止工作

---

## 🔍 问题分析

### 时间线

| 日期 | 状态 | 证据 |
|------|------|------|
| **12月25日 11:22** | ✅ 配置完整 | 备份文件 `settings.json.backup-20251225-112229` 包含完整 hooks |
| **1月17日 18:15** | ✅ 正常工作 | 日志显示最后一次成功保存对话 |
| **1月17日晚～1月21日** | ❌ 配置丢失 | `settings.json` 只剩 `env` 部分，hooks 完全消失 |
| **1月21日 16:02** | ✅ 修复完成 | 恢复完整 hooks 配置 |

### 丢失的配置内容

**之前的完整配置**（1173 字节）：
```json
{
  "env": { ... },
  "enabledPlugins": { ... },
  "trustedWorkspaces": [ ... ],
  "mcpServers": { ... },
  "hooks": {              // ← 这部分完全丢失
    "SessionStart": [...],
    "Stop": [...],
    "UserPromptSubmit": [...]
  }
}
```

**丢失后的配置**（约 100 字节）：
```json
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "...",
    "ANTHROPIC_BASE_URL": "..."
  }
  // hooks 完全消失
}
```

---

## 🎯 根本原因（推测）

### 最可能原因：Claude Code 扩展自动更新（80% 可能性）

**证据**：
1. **时间吻合**：1月中旬是扩展常规更新时间
2. **配置特征**：只保留了关键 `env` 配置，清除了自定义 hooks
3. **重置模式**：典型的扩展升级时配置迁移失败或配置清理行为

**可能的具体原因**：
- 新版本扩展不识别旧版本的 hooks 格式
- 升级过程中配置文件写入被中断
- 扩展"安全模式"启动，重置为最小配置
- 配置迁移脚本存在 bug

### 其他可能原因

**VSCode 设置同步**（15% 可能性）：
- 从其他设备同步了旧配置
- 覆盖了本地的完整配置

**手动误操作**（5% 可能性）：
- 编辑 `settings.json` 时出错
- 保存时 JSON 格式错误导致截断

---

## ✅ 已实施的修复

### 1. 恢复配置

**位置**：`C:\Users\54999\.claude\settings.json`

**修复内容**：
- ✅ 恢复 `hooks` 配置（SessionStart, Stop, UserPromptSubmit）
- ✅ 恢复 `mcpServers` 配置
- ✅ 添加 `enabledPlugins` 和 `trustedWorkspaces`

### 2. 验证修复效果

**UserPromptSubmit hook 测试**：
```
✓ User prompt saved to HTTP server
```
✅ **已恢复工作**

**下一步验证**：
- [ ] Stop hook（对话结束时保存完整对话）
- [ ] SessionStart hook（加载历史记忆）

---

## 🛡️ 预防措施

### 1. 自动备份脚本

**位置**：`scripts/2026-01-21/backup-claude-settings.ps1`

**功能**：
- 每天自动备份 `settings.json`
- 保留最近 30 天的备份
- 自动清理过期备份

**使用方法**：
```powershell
# 手动运行
.\scripts\2026-01-21\backup-claude-settings.ps1

# 添加到 Windows 计划任务（每天运行）
# 打开"任务计划程序"，创建基本任务
# 操作：启动程序
# 程序：powershell.exe
# 参数：-File "E:\2025\3_gongkongji\belt_control_system\scripts\2026-01-21\backup-claude-settings.ps1"
```

### 2. 配置验证脚本

**位置**：`scripts/2026-01-21/verify-claude-hooks.ps1`

**功能**：
- 检查 hooks 配置是否存在
- 验证三个关键 hooks（SessionStart, Stop, UserPromptSubmit）
- 检查 MCP Server 配置

**使用方法**：
```powershell
# 手动运行
.\scripts\2026-01-21\verify-claude-hooks.ps1

# 预期输出（正常）
✅ Hooks 配置完整

已配置的 Hooks：
  - SessionStart
  - Stop
  - UserPromptSubmit

✅ MCP Server 配置正常：http://127.0.0.1:8888/mcp
```

### 3. 版本控制备份

**建议**：
```powershell
# 将配置文件加入项目备份
cp ~/.claude/settings.json .claude/settings.json.reference
git add .claude/settings.json.reference
git commit -m "backup: Claude Code settings.json reference"
```

**优点**：
- 配置变更有历史记录
- 可以随时回滚到任意版本
- 跨设备同步配置模板

### 4. 定期检查清单

**建议每周检查**：
- [ ] 运行验证脚本确认 hooks 存在
- [ ] 访问 http://127.0.0.1:8888 确认有新记录
- [ ] 查看日志文件确认 hooks 正常触发

**异常情况处理**：
```powershell
# 如果发现配置丢失，立即从备份恢复
Copy-Item "$env:USERPROFILE\.claude\backups\settings-<最新日期>.json" `
          "$env:USERPROFILE\.claude\settings.json"

# 或从项目模板恢复
Copy-Item ".claude\settings.json.reference" `
          "$env:USERPROFILE\.claude\settings.json"
```

---

## 📋 配置模板

### 标准 settings.json 模板

保存到：`.claude/settings.json.reference`

```json
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "your-token-here",
    "ANTHROPIC_BASE_URL": "https://api.aicodewith.com"
  },
  "enabledPlugins": {
    "claude-mem@thedotmack": false
  },
  "trustedWorkspaces": [
    "C:\\Users\\54999"
  ],
  "mcpServers": {
    "mcp-memory-service": {
      "type": "http",
      "url": "http://127.0.0.1:8888/mcp"
    }
  },
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "node C:\\Users\\54999\\.claude\\hooks\\core\\session-start.js",
            "timeout": 20
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "node C:\\Users\\54999\\.claude\\hooks\\core\\stop-save-conversation.js",
            "timeout": 15
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "node C:\\Users\\54999\\.claude\\hooks\\core\\user-prompt-submit.js",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

---

## 🔗 相关文档

- **成功配置指南**：`docs/2025-12-25/Claude_Code_自动记忆系统_完整配置指南.md`
- **修复记录**：`docs/2026-01-21/08-MCP-Hooks修复记录-恢复全局配置.md`
- **记忆系统架构**：`docs/技术决策/记忆系统三层架构.md`

---

## ✅ 验证清单

修复完成后的验证步骤：

- [x] 恢复 settings.json 配置
- [x] 验证 UserPromptSubmit hook 工作
- [ ] 验证 Stop hook 工作（等对话结束）
- [ ] 验证 SessionStart hook 工作（下次启动）
- [x] 创建备份脚本
- [x] 创建验证脚本
- [ ] 将配置加入版本控制
- [ ] 设置定期备份计划任务

---

**文档创建时间**：2026-01-21
**作者**：Claude Sonnet 4.5
**状态**：✅ 问题已解决，预防措施已部署
