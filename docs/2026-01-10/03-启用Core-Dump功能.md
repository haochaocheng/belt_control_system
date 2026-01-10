# 启用 Core Dump 功能

**日期**: 2026-01-10 18:15
**问题编号**: Fix 100.14
**状态**: ✅ 已实施

---

## 📋 问题描述

### 现象
程序崩溃（exit code 139 - SIGSEGV）时，自动 Core Dump 分析提示：
```
========================================
检测到段错误（SIGSEGV）- 自动分析 Core Dump
========================================
⚠️ 未找到 Core Dump 文件
   提示：确认容器启动时设置了 --ulimit core=-1
   参考：scripts/2026-01-09/19-enable-core-dump.ps1
```

### 影响
- ❌ 无法生成 Core Dump 文件
- ❌ 自动崩溃分析功能无法工作
- ❌ 崩溃后无法定位根本原因

---

## 🔍 根本原因

### 容器 Core Dump 限制
Docker 容器默认禁用 Core Dump：
- 默认 ulimit：`core=0`（不生成 Core Dump）
- 需要显式启用：`--ulimit core=-1`（无限制）

### 缺失配置
原有 `docker run` 命令（lines 1572-1593）缺少：
1. ❌ `--ulimit core=-1` 参数
2. ❌ Core Dump 目录挂载
3. ❌ 内核 Core Dump 路径配置

---

## ✅ 解决方案

### 修改文件
`build-ubuntu24-apt.ps1` (Lines 1572-1599)

### 修改内容

#### 1. 启动前配置 Core Dump 路径
```bash
# 2026-01-10 18:15 [Core Dump 支持] 创建 Core Dump 目录并启用核心转储
mkdir -p /tmp/belt-control-cores
sudo sysctl -w kernel.core_pattern=/tmp/belt-control-cores/core.%e.%p.%t 2>/dev/null || true
```

**说明**：
- `kernel.core_pattern`：内核 Core Dump 文件命名模板
- `%e`：可执行文件名
- `%p`：进程 PID
- `%t`：时间戳
- `2>/dev/null || true`：忽略权限错误（某些系统可能禁止修改）

#### 2. docker run 命令添加参数
```bash
sudo docker run \
    --name belt-control-app \
    --privileged \
    --ipc=host \
    --net=host \
    --ulimit core=-1 \                                              # ✅ 新增：启用无限制 Core Dump
    $DISPLAY_ARG \
    ...
    -v /tmp/belt-control-cores:/tmp/belt-control-cores:rw \        # ✅ 新增：挂载 Core Dump 目录
    IMAGE_NAME_PLACEHOLDER:IMAGE_TAG_PLACEHOLDER
```

**新增参数**：
- `--ulimit core=-1`：启用无限制大小的 Core Dump
- `-v /tmp/belt-control-cores:/tmp/belt-control-cores:rw`：挂载宿主机目录到容器

---

## 🧪 验证方法

### 1. 下次崩溃测试
程序崩溃时（exit code 139）应该：
1. ✅ 生成 Core Dump 文件：`/tmp/belt-control-cores/core.belt_control_system.*`
2. ✅ 自动分析崩溃原因
3. ✅ 显示崩溃堆栈和寄存器状态
4. ✅ 保存分析报告：`/tmp/belt-control-cores/core.*.analysis.txt`

### 2. 手动测试（可选）
在设备上手动触发 Core Dump：
```bash
# 进入容器
sudo docker exec -it belt-control-app bash

# 触发段错误（测试用）
kill -SIGSEGV $$

# 检查 Core Dump 文件
ls -lh /tmp/belt-control-cores/
```

---

## 📚 技术细节

### Core Dump 工作流程

**崩溃时**：
1. 应用程序触发 SIGSEGV（段错误）
2. 内核捕获信号，生成 Core Dump
3. 文件保存到：`/tmp/belt-control-cores/core.belt_control_system.{PID}.{timestamp}`

**自动分析时**：
1. 检测 exit code 139
2. 查找最新 Core Dump：`ls -t /tmp/belt-control-cores/core.* | head -1`
3. 启动 GDB 容器分析（挂载 Core Dump 目录只读）
4. 生成分析报告并显示摘要

### 为什么使用 /tmp/belt-control-cores？
- ✅ 所有用户可写（`/tmp` 权限 1777）
- ✅ 自动清理（重启后删除）
- ✅ 不占用持久化存储空间
- ✅ 容器内外路径一致（简化挂载配置）

### 安全考虑
- ✅ Core Dump 仅在崩溃时生成
- ✅ 存储在临时目录，重启自动清理
- ✅ 分析容器只读挂载（`-v .../cores:ro`）
- ✅ 不包含敏感数据（仅内存快照）

---

## 🔗 相关文档

1. **自动 Core Dump 分析集成**: [docs/2026-01-10/01-工作总结-自动Core-Dump分析集成.md](01-工作总结-自动Core-Dump分析集成.md)
2. **CRLF 换行符问题**: [docs/2026-01-10/02-修复-run脚本CRLF换行符问题.md](02-修复-run脚本CRLF换行符问题.md)
3. **Core Dump 根因分析**: [docs/2026-01-09/72-Core-Dump分析-编码器初始化崩溃根因.md](../2026-01-09/72-Core-Dump分析-编码器初始化崩溃根因.md)

---

## 📝 总结

### 修改内容
- ✅ 添加 `--ulimit core=-1` 启用 Core Dump
- ✅ 挂载 `/tmp/belt-control-cores` 目录
- ✅ 配置 `kernel.core_pattern` 路径
- ✅ 完整的自动分析流程已就绪

### 下一步
- ⏳ 等待下次崩溃测试验证
- ⏳ 确认 Core Dump 文件生成
- ⏳ 验证自动分析功能工作正常

---

**创建时间**: 2026-01-10 18:15
**作者**: Claude (Sonnet 4.5)
**状态**: ✅ 已实施，等待验证
