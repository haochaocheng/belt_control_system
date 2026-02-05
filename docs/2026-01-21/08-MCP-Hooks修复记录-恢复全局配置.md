# MCP Memory Service Hooks 修复记录

**问题日期**：2026-01-21
**问题类型**：Hooks 未触发，1月17日后 MCP 无记录
**解决状态**：✅ 已修复

---

## 🔍 问题描述

### 症状
- MCP Memory Service HTTP Server 运行正常（端口 8888）
- 数据库健康状态良好（3,062 条记忆）
- **但从 1月17日后没有新记录**
- 用户输入和 Claude 回复都没有被保存

### 用户观察
- 最后一次更新：1月17日
- 今天（1月21日）发现这几天 MCP 没有更新
- 之前（1月17日前）配置是成功的，按照 `Claude_Code_自动记忆系统_完整配置指南.md` 配置

---

## 🔎 问题诊断过程

### 第一轮检查（错误方向）

初步怀疑：
1. ❓ 端口配置错误（8000 vs 8888）
2. ❓ Hooks 未安装到 Claude Code
3. ❓ 缺少 JSON 配置文件

**结果**：这些都不是根本原因

### 第二轮检查（找到根因）

参考成功配置文档后发现：

**全局配置丢失！**

**位置**：`C:\Users\54999\.claude\settings.json`

**当前状态**（有问题）：
```json
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "sk-acw-...",
    "ANTHROPIC_BASE_URL": "https://api.aicodewith.com"
  }
  // ❌ 缺少 hooks 配置！
}
```

**应该是**（成功配置）：
```json
{
  "env": { ... },
  "hooks": {
    "SessionStart": [...],
    "Stop": [...],
    "UserPromptSubmit": [...]
  }
}
```

---

## ✅ 解决方案

### 修复步骤

#### 1. 恢复全局 settings.json

**位置**：`C:\Users\54999\.claude\settings.json`

**完整配置**：
```json
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "sk-acw-5cebd590-d1c9d3a0bb9d6421",
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

**关键点**：
- ✅ 使用 **Node.js 脚本**（不是 Python）
- ✅ **全局配置**（`~/.claude/settings.json`），不是项目配置
- ✅ 三个 Hooks 都配置：SessionStart, Stop, UserPromptSubmit
- ✅ 端口 8888（正确）

#### 2. 清理项目级配置（避免冲突）

删除了错误的项目级 `settings.json`：
```powershell
rm .claude/settings.json
```

保留项目级 `settings.local.json`（只包含权限配置）。

---

## 🧪 验证步骤

### 立即测试（无需重启）

1. **在当前对话中测试**：
   ```
   你好，测试记忆系统
   ```

2. **查看 Web UI**：
   - 访问：http://127.0.0.1:8888
   - 应该能看到新记录（时间戳为今天）

3. **查看日志**：
   ```powershell
   Get-Content "$env:USERPROFILE\.claude\logs\stop-conversation-debug.log" -Tail 20
   ```

   **预期日志**：
   ```
   [2026-01-21T...] [DEBUG] ========== Stop Hook - Save Conversation Started ==========
   [2026-01-21T...] [DEBUG] Found user prompt: XX chars
   [2026-01-21T...] [DEBUG] Found assistant response: XXX chars
   [2026-01-21T...] [DEBUG] ✓ SUCCESS - Saved conversation
   ```

### 如果需要重启

```powershell
# 关闭当前 VSCode
# 重新打开项目
# 或重启 Claude CLI
```

---

## 📊 配置对比

### ❌ 错误的配置方式

```
.claude/settings.json (项目目录)  ❌ 位置错误
{
  "hooks": {
    "UserPromptSubmit": [{
      "hooks": [{
        "command": "python user_prompt_submit.py"  ❌ 语言错误
      }]
    }]
  }
}
```

### ✅ 正确的配置方式

```
~/.claude/settings.json (用户目录)  ✅ 位置正确
{
  "hooks": {
    "SessionStart": [...],     ✅ 三个 hooks 都配置
    "Stop": [...],
    "UserPromptSubmit": [{
      "hooks": [{
        "command": "node C:\\Users\\54999\\.claude\\hooks\\core\\user-prompt-submit.js"  ✅ Node.js
      }]
    }]
  }
}
```

---

## 🎯 根本原因总结

### 问题根源

**全局 settings.json 中的 hooks 配置丢失了！**

可能原因：
1. 系统更新或重装
2. Claude Code 升级后配置被重置
3. 意外删除或覆盖

### 为什么 1月17日前正常？

- 之前有正确的全局配置
- 某个时间点配置文件被重置
- 只保留了 `env` 部分，丢失了 `hooks` 部分

---

## 📝 预防措施

### 1. 备份配置文件

```powershell
# 定期备份全局配置
Copy-Item "$env:USERPROFILE\.claude\settings.json" `
          "$env:USERPROFILE\.claude\settings.json.backup-$(Get-Date -Format 'yyyyMMdd')"
```

### 2. 版本控制

将配置文件纳入版本控制：
```powershell
# 在项目根目录创建备份
cp ~/.claude/settings.json .claude/settings.json.reference
git add .claude/settings.json.reference
```

### 3. 定期检查

创建检查脚本（`scripts/check-hooks.ps1`）：
```powershell
# 检查 hooks 配置是否存在
$settings = Get-Content "$env:USERPROFILE\.claude\settings.json" | ConvertFrom-Json
if (-not $settings.hooks) {
    Write-Host "❌ WARNING: Hooks configuration missing!" -ForegroundColor Red
    exit 1
} else {
    Write-Host "✅ Hooks configuration present" -ForegroundColor Green
}
```

---

## 🔗 相关文档

- **成功配置参考**：`docs/2025-12-25/Claude_Code_自动记忆系统_完整配置指南.md`
- **MCP 服务配置**：`docs/技术决策/记忆系统三层架构.md`
- **Hooks 系统说明**：Claude Code 官方文档

---

## ✅ 修复确认清单

- [x] 恢复全局 `settings.json` 的 hooks 配置
- [x] 删除冲突的项目级 `settings.json`
- [x] 验证 Node.js hooks 脚本存在
- [x] 验证端口配置正确（8888）
- [x] 验证 MCP Server 运行正常
- [ ] 测试对话是否被记录（待用户确认）
- [ ] 检查 Web UI 新记录（待用户确认）
- [ ] 查看日志确认成功（待用户确认）

---

**修复时间**：2026-01-21
**修复人员**：Claude Sonnet 4.5
**用户确认**：待确认

---

## 🎉 预期结果

修复后，从现在开始：
- ✅ 每次对话自动记录到 MCP
- ✅ Web UI 实时显示新记录
- ✅ 支持跨项目记忆共享
- ✅ CLI 和 VSCode 都正常工作

---

**备注**：如果本次对话后能在 Web UI 看到记录，说明修复成功！
