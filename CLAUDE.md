# Belt Control System - 简化版工作指南

## 基本规则
1. 请始终使用简体中文与我对话，并在回答时保持专业、简洁
2. 创建一个文件记录所有的我输入的提示词信息
3. 二次确认
4. 所有生成的.md文件都不放在本目录，放在docs文件夹里，按照日期存放（格式：docs/YYYY-MM-DD/），没有日期，就新建日期文件夹，.md文件名需要加上序号，序号按照文件日期，依次编号
5. 所有生成的.ps1脚本文件都不放在本目录，放在scripts文件夹里，按照日期存放（格式：scripts/YYYY-MM-DD/），没有日期，就新建日期文件夹
5.修改文件里面内容时，，旧代码不用删除，直接注释掉，然后说明原因，加上日期时间，以北京时间为准
6. **编码规则（2025-12-27 更新）**：
   - PowerShell 已升级到 PowerShell 7
   - **所有脚本必须使用 UTF-8 with BOM 编码**
   - 每个脚本开头必须包含 UTF-8 强制配置
   - 不再使用 GBK 编码
7. **Git 提交规则（2026-01-08 新增）**：
   - 每次完成修改总结和代码修改后，必须进行 Git 提交
   - 当用户提示"下班"时，将当天所有工作内容提交到 Git
   - 提交信息要清晰描述修改内容，便于在其他电脑上查看工作进度
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
- SIP 配置：`docker/rk3588/pjsip_config_site.h`
- 视频管理：`src/sip_phone/RemoteVideoManager.cpp`

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
.\build-ubuntu24-apt.ps1 192.168.10.188
```

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


---

### 当前主要任务
**SIP 通话无响应问题排查**（2025-12-27）

**最新状态**：
- ✅ 视频通话崩溃问题已修复（format.c:138 断言失败）
- ❌ SIP 通话完全无响应（1001↔1005 双向都无法接通）
- ⚠️ Wireshark 抓包显示：设备 188 没有发送任何 SIP 消息到网络
- ⚠️ CPU 占用率 100%+，大量音频 Underflow 错误

**下一步排查**：
1. 在设备 188 上抓包验证 SIP 消息是否发送
2. 检查 PJSIP 网络绑定配置
3. 排查音频处理导致高 CPU 问题

详细总结见：[docs/2025-12-26/session-summary-sip-no-response.md](docs/2025-12-26/session-summary-sip-no-response.md)

---

*每次对话开始，我会自动加载项目记忆，您无需做任何额外操作*
