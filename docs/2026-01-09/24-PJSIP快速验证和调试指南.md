# PJSIP 开发快速验证和调试指南

**日期**：2026-01-09 11:15
**目的**：缩短 PJSIP 代码修改后的验证时间，提供容器内调试能力
**适用**：仅修改 PJSIP 源码（ffmpeg_vid_codecs.c）时使用

---

## 🚀 快速验证流程（2-3分钟）

### 使用场景
- ✅ 仅修改 PJSIP 源码（`cross-compile/src/pjproject-2.16/pjmedia/src/pjmedia-codec/ffmpeg_vid_codecs.c`）
- ✅ 需要快速验证代码是否生效
- ❌ 不适用于修改 CMakeLists.txt、Dockerfile、应用代码

### 使用方法

```powershell
# 修改 ffmpeg_vid_codecs.c 后执行
.\scripts\2026-01-09\03-quick-verify-pjsip.ps1 188
```

### 脚本功能
1. ✅ 自动更新源文件时间戳（解决 Edit 工具不更新时间戳问题）
2. ✅ 增量编译 PJSIP 静态库（16核并行，约1分钟）
3. ✅ 重新链接应用程序（约30秒）
4. ✅ 直接上传二进制到容器（跳过 Docker 镜像构建）
5. ✅ 重启容器
6. ✅ 自动查看启动日志验证版本号

### 时间对比

| 流程 | 完整编译 | 快速验证 | 节省时间 |
|------|---------|---------|---------|
| PJSIP 编译 | 1-2分钟 | 1分钟 | 50% |
| 应用链接 | 30秒 | 30秒 | 0% |
| Docker 镜像构建 | 2-3分钟 | **跳过** | 100% |
| 上传部署 | 2-3分钟 | 30秒 | 80% |
| **总计** | **10分钟** | **2-3分钟** | **70%** |

---

## 🐛 容器内 GDB 调试（崩溃定位）

### 使用场景
- ✅ 程序崩溃（exit code 139 段错误）
- ✅ 需要定位崩溃的精确位置
- ✅ 容器已部署在设备上

### 使用方法

```powershell
# 启动 GDB 调试会话
.\scripts\2026-01-09\02-gdb-debug-in-container.ps1 188
```

### 脚本功能
1. ✅ 检查容器状态
2. ✅ 自动安装 GDB（如果未安装）
3. ✅ 配置 core dump
4. ✅ 启动交互式 GDB 会话
5. ✅ 显示 GDB 使用指南

### GDB 调试步骤

```gdb
# 1. 运行程序
(gdb) run

# 2. [等待程序崩溃]
# Program received signal SIGSEGV, Segmentation fault.

# 3. 查看崩溃堆栈
(gdb) bt
#0  0x00007f... in some_function() at file.c:123
#1  0x00007f... in caller_function() at file.c:456
...

# 4. 切换到崩溃位置
(gdb) frame 0

# 5. 查看局部变量
(gdb) info locals
avframe = { ... }
sw_frame = 0x7f...

# 6. 检查关键变量
(gdb) p avframe
(gdb) p avframe.data[0]
(gdb) p sw_frame

# 7. 查看源码（如果有）
(gdb) list

# 8. 退出
(gdb) quit
```

### 常见崩溃原因和检查方法

| 崩溃原因 | GDB 检查命令 | 预期结果 |
|---------|------------|---------|
| 空指针访问 | `p pointer` | pointer = 0x0 |
| 悬空指针 | `p pointer` | pointer = 0x7f... (已释放地址) |
| 栈溢出 | `bt` | 堆栈非常深（>100帧） |
| 内存损坏 | `info locals` | 变量值异常 |
| 未初始化变量 | `p variable` | 垃圾值 |

---

## 📋 完整开发流程

### 1. 首次设置（10分钟）
```powershell
# 完整编译和部署
.\build-ubuntu24-apt.ps1 188
```

### 2. 日常开发（2-3分钟/次）

#### 步骤 A：修改代码
```powershell
# 使用你喜欢的编辑器修改
code cross-compile\src\pjproject-2.16\pjmedia\src\pjmedia-codec\ffmpeg_vid_codecs.c

# 或使用 Claude Code 的 Edit 工具修改
```

#### 步骤 B：快速验证
```powershell
# 自动编译、部署、验证
.\scripts\2026-01-09\03-quick-verify-pjsip.ps1 188
```

#### 步骤 C：查看日志
```powershell
# 查看实时日志
ssh linaro@192.168.10.188 "docker logs -f belt-control-latest"

# 或只看关键日志
ssh linaro@192.168.10.188 "docker logs -f belt-control-latest | grep 'STARTUP-VERSION\|CODE-VERSION\|FIX'"
```

#### 步骤 D：如果崩溃，使用 GDB
```powershell
# 启动 GDB 调试
.\scripts\2026-01-09\02-gdb-debug-in-container.ps1 188

# 在 GDB 中运行程序，等待崩溃，查看堆栈
(gdb) run
(gdb) bt
```

### 3. 重大变更（10分钟）
```powershell
# 修改 CMakeLists.txt、Dockerfile、添加新依赖时
.\build-ubuntu24-apt.ps1 188
```

---

## ⚙️ 平台和环境配置

### Windows 平台规范（2026-01-09 新增）
- **开发平台**：Windows 10/11
- **脚本环境**：PowerShell 7
- **路径格式**：Windows 路径（`\` 或 `\\`）
- **命令选择**：PowerShell cmdlet（不使用 Linux 命令）

### 设备信息（2026-01-09 更新）
- **设备 IP**：192.168.10.188
- **用户名**：linaro
- **密码**：linaro
- **SSH 连接**：`ssh linaro@192.168.10.188`

---

## 🔧 故障排除

### 问题 1：快速验证脚本报错 "PJSIP 编译容器不存在"
**原因**：从未运行过完整编译，编译容器不存在

**解决**：
```powershell
.\build-ubuntu24-apt.ps1 188
```

### 问题 2：上传二进制失败
**原因**：SSH 密钥未配置或网络问题

**解决**：
```powershell
# 测试 SSH 连接
ssh linaro@192.168.10.188 "echo 'SSH OK'"

# 如果需要输入密码，配置免密登录
ssh-copy-id linaro@192.168.10.188
```

### 问题 3：GDB 显示 "No debugging symbols found"
**原因**：二进制文件未包含调试符号

**解决**：
- 当前配置：Release 模式（不包含调试符号）
- 如需调试符号：修改 CMakeLists.txt 添加 `-g` 选项
- 或使用 GDB 的 `bt` 命令（即使没有符号也能看到堆栈地址）

### 问题 4：版本号日志没有出现
**原因**：源文件时间戳没有更新，PJSIP 没有重新编译

**解决**：
- 快速验证脚本已自动更新时间戳
- 或手动更新：
  ```powershell
  $file = "cross-compile\src\pjproject-2.16\pjmedia\src\pjmedia-codec\ffmpeg_vid_codecs.c"
  (Get-Item $file).LastWriteTime = Get-Date
  ```

---

## 📝 版本验证机制

### 启动版本日志（优先）
程序启动时自动打印，无需解码器被调用：
```
🔍 [STARTUP-VERSION] 92
   Fix 92: Correct memory management - use av_frame_move_ref instead of shallow copy
   Date: 2026-01-09 09:45
```

### 解码版本日志（备用）
解码器被调用时打印：
```
🔍 [CODE-VERSION] 92 - Fix 92: Correct memory management...
```

### 验证方法
```powershell
# 查看启动日志
ssh linaro@192.168.10.188 "docker logs belt-control-latest 2>&1 | grep 'STARTUP-VERSION'"

# 查看解码日志
ssh linaro@192.168.10.188 "docker logs belt-control-latest 2>&1 | grep 'CODE-VERSION'"
```

---

## 🎯 性能对比总结

| 操作 | 完整流程 | 快速验证 | GDB 调试 |
|------|---------|---------|---------|
| 时间 | 10分钟 | 2-3分钟 | 实时 |
| Docker 构建 | ✅ | ❌ | ❌ |
| 版本验证 | 手动 | ✅ 自动 | N/A |
| 崩溃定位 | ❌ | ❌ | ✅ |
| 适用场景 | 重大变更 | PJSIP 修改 | 崩溃调试 |

---

## 相关文档
- [20-PJSIP开发快速迭代优化方案.md](./20-PJSIP开发快速迭代优化方案.md)
- [23-Fix92测试结果分析.md](./23-Fix92测试结果分析.md)
- [CLAUDE.md](../../CLAUDE.md) - 平台和环境规范
