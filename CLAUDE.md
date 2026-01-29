# Belt Control System - 简化版工作指南

## 基本规则
1. 请始终使用简体中文与我对话，并在回答时保持专业、简洁
2. 创建一个文件记录所有的我输入的提示词信息
3. 二次确认
4. 所有生成的.md文件都不放在本目录，放在docs文件夹里，按照日期存放（格式：docs/YYYY-MM-DD/），没有日期，就新建日期文件夹，.md文件名需要加上序号，序号按照文件日期，依次编号
5. 所有生成的.ps1脚本文件都不放在本目录，放在scripts文件夹里，按照日期存放（格式：scripts/YYYY-MM-DD/），没有日期，就新建日期文件夹
6. 修改文件里面内容时，旧代码不用删除，直接注释掉，然后说明原因，加上日期时间，以北京时间为准
   - **时区配置（2026-01-11 新增）**：
     - 使用北京时间（UTC+8）
     - 所有时间戳、日志时间、文档日期均使用北京时间
     - 确保系统时区设置正确
7. **编码规则（2025-12-27 更新）**：
   - PowerShell 已升级到 PowerShell 7
   - **所有脚本必须使用 UTF-8 with BOM 编码**
   - 每个脚本开头必须包含 UTF-8 强制配置
   - 不再使用 GBK 编码
8. **Git 提交规则（2026-01-08 新增，2026-01-29 更新）**：
   - 每次完成修改总结和代码修改后，必须进行 Git 提交
   - **⚠️ 重要：每次提交后必须推送到 GitHub 和 GitLab 两个远程仓库**
   - 推送命令：
     ```powershell
     git push origin feature/hardware-video-codec  # 推送到 GitHub
     git push gitlab feature/hardware-video-codec  # 推送到 GitLab
     ```
   - 当用户提示"下班"时，将当天所有工作内容提交到 Git
   - 提交信息要清晰描述修改内容，便于在其他电脑上查看工作进度
9. **平台和环境规则（2026-01-09 新增）**：
   - **开发平台**：Windows 10/11
   - **脚本执行环境**：PowerShell 7（不是 Bash）
   - **脚本语法**：所有自动化脚本使用 PowerShell，不使用 Bash/Shell 语法
   - **路径格式**：Windows 路径（`\` 或 `\\`），不使用 Unix 路径（`/`）
   - **命令选择**：优先使用 PowerShell cmdlet（如 `Get-ChildItem`），避免 Linux 命令（如 `find`、`grep`）
10. **设备信息（2026-01-09 更新）**：
    - **设备 IP**：192.168.10.188
    - **用户名**：linaro
    - **密码**：linaro
    - **SSH 连接**：`ssh linaro@192.168.10.188`
## 记忆系统（2025-12-25）

### 三层记忆架构
```
PROJECT_MEMORY.md → Node.js Hooks + HTTP Server → Python Hook
(手动维护)         (自动记忆，端口8888)          (本地备份)
```

### 核心组件
1. **PROJECT_MEMORY.md** - 主记忆（每次启动自动加载）
2. **HTTP Server (8888)** - 自动记忆系统
   - SessionStart: 加载历史记忆
   - Stop: 保存完整对话
   - UserPromptSubmit: 实时保存
3. **Python Hook** - 本地JSON备份

### 关键信息
- **HTTP Server 启动**: `.\start-mcp-http-server.ps1`
- **存储位置**: G:\claude-memory
- **claude-mem Worker**: ❌ 已禁用（连接泄漏问题）

### 详细文档
- 记忆系统详细配置：[docs/技术决策/记忆系统三层架构.md](docs/技术决策/记忆系统三层架构.md)
- 历史问题归档：[docs/历史问题/](docs/历史问题/)
- 完整工作日志：[docs/工作日志/](docs/工作日志/)


## 💡 简单工作流程

### 每天开始工作
1. 我会自动读取 PROJECT_MEMORY.md
2. 您直接开始工作，正常提问即可

### 工作过程中
- 遇到问题？直接告诉我
- 解决问题？告诉我结果
- 我会自动更新 PROJECT_MEMORY.md

### 工作结束
告诉我：
```
今天做了什么
遇到了什么问题
解决了什么
明天计划做什么
```

我会帮您更新工作日志。

## 📋 就这么简单！

不需要：
- ❌ 启动任何脚本
- ❌ 手动编辑文件
- ❌ 担心 Worker 是否运行

只需要：
- ✅ 正常和我对话
- ✅ 我自动记录一切

---

## 快速参考

### 关键文件位置
- 硬件解码器：`src/pjmedia-codec/rkmpp_h264_codec.c`
- 硬件编码器：`cross-compile/src/pjproject-2.16/pjmedia/src/pjmedia-codec/ffmpeg_vid_codecs.c`
- SIP 配置：`docker/rk3588/pjsip_config_site.h`
- 视频管理：`src/sip_phone/RemoteVideoManager.cpp`

### 🎬 视频编解码器配置（2026-01-09 新增）

**编码器选择**（发送本地视频）:
```bash
# 默认：软件编码器 libx264（稳定可靠）
USE_HARDWARE_ENCODER=0  # 或不设置

# 可选：硬件编码器 h264_rkmpp（性能更好，可能不稳定）
USE_HARDWARE_ENCODER=1
```

**解码器配置**（接收对方视频）:
- ✅ 硬件解码器 `h264_rkmpp` 已启用（稳定工作）

**详细文档**: [docs/2026-01-09/43-Fix97-添加硬件编码器开关.md](docs/2026-01-09/43-Fix97-添加硬件编码器开关.md)

### ⚠️ PJSIP 库路径（重要！2025-12-26）
**编译时库路径**（交叉编译容器内）：
- 挂载：`docker/rk3588/rk3588-libs → /opt/rk3588-libs`
- CMake使用：`/opt/rk3588-libs/lib/*.a`

**运行时库路径**（Docker容器内）：
- 复制：`docker/rk3588/lib/*.so → /app/lib/`
- 环境变量：`LD_LIBRARY_PATH=/app/lib`

**⚠️ 更新 PJSIP 库时**：
```powershell
# 从设备188下载后，复制到两个位置
cp docker/rk3588/lib/*.a docker/rk3588/rk3588-libs/lib/  # 编译用
# docker/rk3588/lib/*.so 自动用于运行时
```

### 构建和部署
```powershell
# 完整编译和部署（首次或重大变更）
.\build-ubuntu24-apt.ps1 188

# 快速验证（仅修改 PJSIP 源码，2-3分钟）
.\scripts\2026-01-09\03-quick-verify-pjsip.ps1 188

# GDB 调试（程序崩溃时）
.\scripts\2026-01-09\02-gdb-debug-in-container.ps1 188
```

**详细文档**：[docs/2026-01-09/24-PJSIP快速验证和调试指南.md](docs/2026-01-09/24-PJSIP快速验证和调试指南.md)

### 调试流程规范（2026-01-09 新增）

**原则**：所有调试和验证工作由 Claude 自动完成，无需用户手动输入命令

**调试工具链**：
1. **快速验证**：修改代码后 2-3 分钟验证 → `03-quick-verify-pjsip.ps1`
2. **交互式 GDB**：需要手动输入命令调试 → `02-gdb-debug-in-container.ps1`
3. **自动 GDB**：全自动崩溃分析（推荐）→ `04-auto-gdb-crash-analysis.ps1`
4. **Core Dump 分析**：崩溃后事后分析（最可靠）⭐ → `06-setup-core-dump.ps1` + `07-analyze-core-dump.ps1`
5. **Strace 追踪**：系统调用序列分析 → `08-setup-strace.ps1` + `09-download-strace-log.ps1`

**使用场景**：
- 修改 PJSIP 代码后：使用快速验证脚本
- 程序崩溃需要定位：**优先使用 Core Dump 分析**（最可靠）
- 需要深入调试：使用交互式 GDB
- 需要系统调用信息：使用 Strace 追踪

**限制**：
- GDB 调试需要容器在设备上运行
- 自动 GDB 分析超时 30 秒，适合快速崩溃场景
- 视频通话相关崩溃需要实际通话测试触发
- **✅ Core Dump 不受容器停止影响**（推荐）

**完整调试方案**：[docs/2026-01-09/27-崩溃后GDB调试完整方案.md](docs/2026-01-09/27-崩溃后GDB调试完整方案.md)

## 📦 统一构建脚本（2025-12-29 更新）

### ⚠️ **重要规则：只使用 build-ubuntu24-apt.ps1**

**所有源码修改或外部依赖库的编译部署，只准使用 `build-ubuntu24-apt.ps1`！**

### 自动化流程
```powershell
# 一键完成所有操作（推荐）
.\build-ubuntu24-apt.ps1 188

# 脚本自动完成：
# ✅ 检测 PJSIP 源码变化
# ✅ 自动重新编译 PJSIP 静态库（如需要）
# ✅ 检测 PJSIP 库变化
# ✅ 自动清除应用缓存（如库更新）
# ✅ 交叉编译应用程序
# ✅ 构建 Docker 镜像
# ✅ 部署到设备
```

### 工作原理
脚本内置智能检测：
1. **Step -1**: 比较 PJSIP 源码和静态库时间戳
   - 源码更新 → 自动 Docker 编译 PJSIP → 更新静态库
2. **Step -0.5**: 监控 PJSIP 静态库哈希
   - 库文件变化 → 清除应用缓存 → 强制重新链接
3. **Step 1**: 检查应用源码变化
   - 源码更新 → 交叉编译应用
4. **Step 2-6**: Docker 镜像构建和部署

### 关键路径
- **PJSIP 源码**：`cross-compile\src\pjproject-2.16\`
- **PJSIP 静态库**：`docker\rk3588\rk3588-libs\lib\*.a`（自动编译）
- **应用二进制**：`build_rk3588\bin_arm64\belt_control_system`
- **配置文件**：`docker\rk3588\pjsip_config_site.h`

### 新建脚本规则
如需新建辅助脚本，**必须被 build-ubuntu24-apt.ps1 引用调用**，不可独立使用。

## 📤 Git 双重备份系统（2026-01-28 新增）

### 双重备份架构
```
本地代码 → GitHub（远程备份）
         → GitLab（本地备份，http://localhost:8080）
```

### 远程仓库配置
```powershell
# 查看当前远程仓库
git remote -v

# 应该看到：
# origin    https://github.com/your-repo.git (GitHub)
# gitlab    http://localhost:8080/root/belt-control-system.git (GitLab)
```

### 日常推送命令

**推送到当前分支（最常用）**：
```powershell
# 推送到 GitHub
git push origin feature/hardware-video-codec

# 推送到 GitLab
git push gitlab feature/hardware-video-codec
```

**推送所有分支**：
```powershell
# 推送所有分支到 GitHub
git push origin --all

# 推送所有分支到 GitLab
git push gitlab --all
```

**推送标签**：
```powershell
# 推送标签到 GitHub
git push origin --tags

# 推送标签到 GitLab
git push gitlab --tags
```

### 快捷脚本

**推送所有内容到 GitLab**：
```powershell
.\scripts\2026-01-28\10-push-all-to-gitlab.ps1
```

**配置 GitLab 远程仓库**（首次使用）：
```powershell
.\scripts\2026-01-28\09-setup-gitlab-remote.ps1
```

**修复 Git HTTP 连接问题**（如遇到 HTTP 不允许错误）：
```powershell
.\scripts\2026-01-28\11-fix-git-http.ps1
```

### GitLab 管理

**访问 GitLab**：
- 地址：http://localhost:8080
- 用户名：root
- 密码：[您设置的密码]

**GitLab 管理脚本**：
```powershell
.\scripts\2026-01-28\06-gitlab-manager.ps1
```

**修改 GitLab 密码**：
```powershell
.\scripts\2026-01-28\08-change-gitlab-password.ps1
```

### 自动提交规则

**Claude 会自动处理 Git 提交**：
- ✅ 每次完成修改总结和代码修改后，自动提交
- ✅ 提交信息清晰描述修改内容
- ✅ 自动推送到 GitHub 和 GitLab
- ✅ 您无需记住这些命令

**您只需要**：
- 正常工作和提问
- 告诉我"下班"时，我会提交当天所有工作

### 详细文档
- GitLab 部署流程：[docs/2026-01-28/21-GitLab部署完整流程总结.md](docs/2026-01-28/21-GitLab部署完整流程总结.md)
- GitLab 日常使用：[docs/2026-01-28/17-GitLab日常使用指南.md](docs/2026-01-28/17-GitLab日常使用指南.md)

