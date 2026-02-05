# Pencil MCP 与 Claude Code 配合使用指南

**日期**：2026-01-25
**版本**：v1.0
**目的**：使用 Pencil MCP 工具重新设计设备参数配置界面，实现工业科技感美学

---

## 📋 Pencil 工具概述

### 什么是 Pencil？

**Pencil** 是一个 **AI 驱动的 MCP 画布工具**，专为开发者设计，将设计能力直接集成到编码环境中。

**官网**：https://www.pencil.dev/

**核心理念**：
> "Design on canvas. Land in code."
> 在画布上设计，直接落地到代码

---

## 🎯 核心功能特性

### 1. **AI 驱动的设计生成**
- **AI 多人协作设计**：并行创建多个屏幕
- **Vibe 设计**：通过精确提示词生成设计
- **像素完美的矢量转代码**：自动生成 QML/React/Vue 代码

### 2. **开发者友好**
- **开放格式**：使用 JSON 格式的 `.pen` 文件存储在代码库中
- **Git 集成**：支持版本控制和分支管理
- **组件化设计系统**：支持设计系统和组件库
- **双向 MCP 画布**：完整的读写访问权限

### 3. **高性能渲染**
- **无限 WebGL 画布**：高性能渲染
- **Figma 导入**：通过复制粘贴导入 Figma 设计

### 4. **集成能力**
- ✅ Cursor IDE
- ✅ VSCode
- ✅ Claude Code
- ✅ OpenAI Codex
- ✅ Figma
- ✅ Git 仓库
- ✅ 测试工具（Playwright, Puppeteer）

---

## 🔧 安装和配置

### 1. 安装 Pencil

**支持平台**：
- Mac
- Linux
- Cursor 扩展

**安装方式**：
```bash
# 方式1：从官网下载
https://www.pencil.dev/

# 方式2：VSCode 扩展市场搜索 "Pencil"
```

### 2. 配置 MCP 服务器

Pencil 使用 **Model Context Protocol (MCP)** 与 Claude Code 通信。

**配置文件位置**：
- Windows: `%APPDATA%\.claude\settings.json`
- Linux/Mac: `~/.claude/settings.json`

**添加 Pencil MCP 服务器**：
```json
{
  "mcpServers": {
    "pencil": {
      "command": "pencil-mcp-server",
      "args": [],
      "env": {}
    }
  }
}
```

### 3. 验证连接

在 Claude Code 中运行：
```bash
/mcp
```

应该能看到 Pencil MCP 服务器已连接。

---

## 🎨 使用 Pencil 设计界面

### 工作流程

#### 1. **启动 Pencil 画布**

在 Claude Code 中，告诉 Claude：
```
使用 Pencil MCP 创建一个工业科技感的设备参数配置界面
```

Claude 会自动调用 Pencil MCP 工具，打开设计画布。

#### 2. **AI 生成设计**

**提示词示例**：
```
创建一个工业控制系统的参数配置界面，包含：
- 左侧：保护项列表（240px宽，深色背景）
- 右侧：参数编辑区域（自适应宽度）
- 配色：深蓝色主题（#1a1f2e背景，#2196F3强调色）
- 字体：等宽字体，清晰易读
- 风格：扁平化，带有科技感的线条和图标
```

#### 3. **迭代优化**

Pencil 支持实时迭代：
```
调整左侧列表的间距，增加悬停效果
添加激活状态的高亮边框
优化输入框的对比度
```

#### 4. **导出代码**

Pencil 可以直接生成 QML 代码：
```
将设计导出为 QML 代码
```

生成的代码会保存为 `.pen` 文件在项目中。

---

## 📐 工业科技感设计规范

### 配色方案

**主色调**：
- 背景色：`#1a1f2e`（深蓝灰）
- 卡片背景：`#252b3d`（中蓝灰）
- 强调色：`#2196F3`（科技蓝）
- 成功色：`#4CAF50`（绿色）
- 警告色：`#FF9800`（橙色）
- 错误色：`#F44336`（红色）

**文字颜色**：
- 主文字：`#E0E0E0`（浅灰）
- 次要文字：`#9E9E9E`（中灰）
- 禁用文字：`#616161`（深灰）

### 字体规范

**字体家族**：
- 主字体：`"Roboto Mono", "Consolas", "Monaco", monospace`
- 标题字体：`"Roboto", "Microsoft YaHei", sans-serif`

**字体大小**：
- 标题：18px
- 正文：14px
- 小字：12px
- 标签：10px

### 间距规范

**内边距**：
- 小：8px
- 中：16px
- 大：24px

**外边距**：
- 小：4px
- 中：8px
- 大：16px

### 圆角规范

- 卡片：4px
- 按钮：2px
- 输入框：2px

### 阴影效果

**卡片阴影**：
```css
box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
```

**悬停阴影**：
```css
box-shadow: 0 4px 16px rgba(33, 150, 243, 0.3);
```

---

## 🔄 Pencil 与 Claude Code 协作流程

### 完整工作流

```mermaid
graph LR
    A[用户需求] --> B[Claude Code]
    B --> C[Pencil MCP]
    C --> D[AI 生成设计]
    D --> E[用户反馈]
    E --> F{满意?}
    F -->|否| D
    F -->|是| G[导出 QML 代码]
    G --> H[集成到项目]
```

### 示例对话

**用户**：
```
使用 Pencil 重新设计 SwitchInputPage.qml，要求工业科技感
```

**Claude Code**：
```
我将使用 Pencil MCP 为您设计界面...
[调用 Pencil MCP 工具]
[生成设计预览]
请查看设计，有什么需要调整的吗？
```

**用户**：
```
左侧列表的字体太小，增加到 14px
```

**Claude Code**：
```
[调用 Pencil MCP 更新设计]
已更新字体大小，请查看新版本
```

**用户**：
```
满意，导出代码
```

**Claude Code**：
```
[导出 QML 代码]
已生成 SwitchInputPage.qml，是否替换现有文件？
```

---

## 📂 项目集成

### 1. 设计文件管理

**存储位置**：
```
belt_control_system/
├── design/
│   ├── SwitchInputPage.pen
│   ├── AnalogInputPage.pen
│   └── DeviceSettingsDialog.pen
```

**Git 版本控制**：
```bash
git add design/*.pen
git commit -m "feat: 添加 Pencil 设计文件"
```

### 2. 代码生成

Pencil 生成的 QML 代码会保存到：
```
src/qml/components/device_info/pages/
```

### 3. 设计迭代

**修改设计**：
```bash
# 打开 Pencil 编辑器
pencil design/SwitchInputPage.pen
```

**重新生成代码**：
```bash
# Claude Code 会自动检测 .pen 文件变化
# 并提示重新生成代码
```

---

## 🎯 当前项目应用

### 需要重新设计的界面

1. **SwitchInputPage.qml**（开关量输入页面）
   - 左侧：8个保护项列表
   - 右侧：参数编辑区域

2. **AnalogInputPage.qml**（模拟量输入页面）
   - 左侧：19个保护项列表
   - 右侧：参数编辑区域（包含上下限、量程等）

3. **DeviceSettingsDialog.qml**（设备设置对话框）
   - 顶部：类别选择（基本配置、开关量、模拟量等）
   - 中间：动态加载的页面内容

### 设计目标

**工业科技感特征**：
- ✅ 深色主题（深蓝灰背景）
- ✅ 科技蓝强调色（#2196F3）
- ✅ 等宽字体（Roboto Mono）
- ✅ 扁平化设计
- ✅ 清晰的层次结构
- ✅ 精确的数据展示
- ✅ 高对比度（易读性）

---

## 📚 参考资源

### 官方文档
- [Pencil 官网](https://www.pencil.dev/)
- [Pencil 工具介绍](https://www.everydev.ai/tools/pencil)
- [Pencil 功能评测](https://www.banani.co/blog/pencil-dev-review)

### MCP 协议
- [MCP 完整设置指南](https://mcp-hunt.com/blog/mcp-in-ai-agents)
- [如何扩展 Claude Code 与 MCP](https://skywork.ai/blog/how-to-extend-claude-code-mcp-secure-project-files-guide/)
- [MCP 服务器指南](https://www.viberank.app/blog/mcp-servers-guide)

### VSCode 集成
- [vscode-mcp-server](https://github.com/juehang/vscode-mcp-server)
- [VSCode MCP 扩展](https://marketplace.visualstudio.com/items?itemName=JuehangQin.vscode-mcp-server)

---

## ⚠️ 注意事项

### 1. **平台兼容性**
- Pencil 目前主要支持 Mac 和 Linux
- Windows 用户可能需要使用 WSL 或等待官方支持

### 2. **MCP 服务器状态**
- 确保 Pencil MCP 服务器正在运行
- 使用 `/mcp` 命令检查连接状态

### 3. **设计文件版本控制**
- `.pen` 文件是 JSON 格式，适合 Git 管理
- 建议每次设计迭代都提交到 Git

### 4. **代码生成质量**
- Pencil 生成的代码可能需要手动调整
- 建议先生成基础结构，再手动优化细节

---

## 🚀 下一步操作

### 立即开始

1. **安装 Pencil**：
   ```bash
   # 从官网下载或安装 VSCode 扩展
   ```

2. **配置 MCP 服务器**：
   ```bash
   # 编辑 ~/.claude/settings.json
   ```

3. **启动设计**：
   ```
   使用 Pencil MCP 创建 SwitchInputPage 的工业科技感设计
   ```

4. **迭代优化**：
   ```
   根据反馈调整设计
   ```

5. **导出代码**：
   ```
   导出 QML 代码并集成到项目
   ```

---

## 📝 总结

**Pencil MCP 的优势**：
- ✅ AI 驱动，快速生成设计
- ✅ 开发者友好，直接生成代码
- ✅ Git 集成，版本控制方便
- ✅ 与 Claude Code 无缝协作

**适用场景**：
- 快速原型设计
- 界面重构
- 设计迭代优化
- 团队协作设计

**当前项目应用**：
- 重新设计设备参数配置界面
- 实现工业科技感美学
- 提升用户体验

---

**创建时间**：2026-01-25
**创建人员**：Claude Sonnet 4.5
**文档版本**：v1.0
