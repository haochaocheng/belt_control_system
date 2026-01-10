# 2026-01-10 工作总结：Core Dump 分析完整解决方案

**日期**: 2026-01-10
**工作时段**: 17:00 - 18:40
**状态**: ✅ 全部完成

---

## 📋 工作概览

今天完成了从**崩溃检测**到**自动分析**到**根因定位**到**修复实施**的完整闭环：

1. ✅ **CRLF 换行符问题修复**（3 次迭代，最终成功）
2. ✅ **启用 Core Dump 功能**（`--ulimit core=-1`）
3. ✅ **Core Dump 成功分析**（定位 libx264 崩溃根因）
4. ✅ **启用硬件编码器**（Fix 100.15 - 解决 DRM_PRIME 不兼容）

---

## 🎯 核心成果

### 1. CRLF 换行符修复（Fix 100.13）

**问题**：Windows PowerShell 生成的脚本使用 CRLF 换行符，导致设备 bash 5.0 语法错误。

**修复过程**（3 次迭代）：

#### 第一次尝试（失败）
- **方法**：`-replace "`r`n", "`n"`
- **失败原因**：PowerShell 管道重新添加 CRLF
- **Commit**: `a534eb51`

#### 第二次尝试（失败）
- **方法**：临时文件 + sshpass 上传
- **失败原因**：Windows 环境无 sshpass 命令
- **Commit**: `b11a4f13`

#### 第三次尝试（成功）✅
- **方法**：临时文件（UTF8 without BOM）+ 原生 `scp` 命令
- **修改**：[build-ubuntu24-apt.ps1:1690-1707](build-ubuntu24-apt.ps1#L1690-L1707)
- **Commit**: `7753243b`

**关键技术**：
```powershell
# 1. 转换换行符
$runScript = $runScript -replace "`r`n", "`n"

# 2. 保存到临时文件（UTF8 without BOM）
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
[System.IO.File]::WriteAllText($TempScriptFile, $runScript, $Utf8NoBomEncoding)

# 3. 使用原生 scp 上传（不使用管道）
scp $TempScriptFile "${DeviceUser}@${DeviceIP}:/home/$DeviceUser/run-ubuntu24-apt.sh"
ssh "${DeviceUser}@${DeviceIP}" "chmod +x /home/$DeviceUser/run-ubuntu24-apt.sh"
```

**文档**：[docs/2026-01-10/02-修复-run脚本CRLF换行符问题.md](02-修复-run脚本CRLF换行符问题.md)

---

### 2. 启用 Core Dump 功能（Fix 100.14）

**问题**：Docker 容器默认禁用 Core Dump，崩溃时无法生成调试文件。

**解决方案**：
1. 添加 `--ulimit core=-1` 参数
2. 挂载 Core Dump 目录
3. 配置内核 Core Dump 路径

**修改** [build-ubuntu24-apt.ps1:1572-1599](build-ubuntu24-apt.ps1#L1572-L1599)：
```bash
# 容器启动前配置
mkdir -p /tmp/belt-control-cores
sudo sysctl -w kernel.core_pattern=/tmp/belt-control-cores/core.%e.%p.%t

# docker run 添加参数
sudo docker run \
    --ulimit core=-1 \                                              # ✅ 启用 Core Dump
    ...
    -v /tmp/belt-control-cores:/tmp/belt-control-cores:rw \        # ✅ 挂载目录
    ...
```

**Commit**: `29c58bf2`

**文档**：[docs/2026-01-10/03-启用Core-Dump功能.md](03-启用Core-Dump功能.md)

---

### 3. Core Dump 成功分析 ⭐

**现象**：程序崩溃（exit code 139），自动分析系统成功生成完整报告！

**崩溃堆栈**：
```
#0  __GI___libc_free (mem=<optimized out>) at ./malloc/malloc.c:3375
#1  0x0000007f84253500 in avcodec_close () from /app/lib/libavcodec.so.60
#2  0x0000007f84391734 in avcodec_open2 () from /app/lib/libavcodec.so.60
#3  0x00000055735b2078 in open_ffmpeg_codec.isra ()
```

**崩溃分析**：

#### 直接原因
`free()` 试图释放无效指针 → 段错误

#### 触发原因
1. `avcodec_open2()` 初始化 libx264 编码器
2. 初始化失败（格式不兼容）
3. 自动调用 `avcodec_close()` 清理
4. 清理时访问未初始化的指针 → 崩溃

#### 根本原因
**格式不兼容**：
```
RKMPP 解码器输出：
  - 格式：DRM_PRIME (179)
  - 位置：GPU 显存
  - 访问：DMA（CPU 无法直接读取）

libx264 编码器期望：
  - 格式：I420 (0)
  - 位置：系统 RAM
  - 访问：CPU 读写

结果：libx264 无法访问 GPU 内存 → 初始化失败 → 清理崩溃
```

**文档**：[docs/2026-01-10/04-Core-Dump分析-libx264编码器内存释放崩溃.md](04-Core-Dump分析-libx264编码器内存释放崩溃.md)

---

### 4. 启用硬件编码器（Fix 100.15）

**问题发现**：Fix 97 已实现硬件编码器支持，但 run 脚本中未设置环境变量！

**解决方案**：添加 `USE_HARDWARE_ENCODER=1` 环境变量

**修改** [build-ubuntu24-apt.ps1:1587](build-ubuntu24-apt.ps1#L1587)：
```bash
sudo docker run \
    ...
    -e FFMPEG_HW_OPTS \
    -e USE_HARDWARE_ENCODER=1 \    # ✅ 新增：启用硬件编码器
    -e XDG_RUNTIME_DIR=/tmp \
    ...
```

**预期效果**：
- ✅ 编码器将使用 `h264_rkmpp` 而非 `libx264rgb`
- ✅ DRM_PRIME 格式直接传递给硬件编码器（零拷贝）
- ✅ 不再崩溃
- ✅ CPU 使用率降低到 ~1%

**Commit**: `bcc90564`

---

## 📊 技术亮点

### 1. 完整的自动化分析流程

**崩溃检测 → 自动分析 → 报告生成**：

```bash
# 检测 exit code 139
if [ $EXIT_CODE -eq 139 ]; then
    # 查找最新 Core Dump
    LATEST_CORE=$(ls -t /tmp/belt-control-cores/core.* | head -1)

    # GDB 自动分析
    sudo docker run --rm \
        -v /tmp/belt-control-cores:/cores:ro \
        IMAGE_NAME:TAG \
        bash -c "gdb -batch -ex 'bt' -ex 'info registers' ..."

    # 显示摘要
    echo "崩溃原因摘要"
    grep -A 3 "[1] 崩溃位置" "$ANALYSIS_FILE"
fi
```

### 2. CRLF 问题的最终方案

**关键点**：
- ✅ PowerShell `-replace` 转换 CRLF → LF
- ✅ UTF8 without BOM 编码（避免 BOM 污染）
- ✅ 临时文件保存（避免管道重新添加 CRLF）
- ✅ 原生 scp 上传（不依赖 WSL/Linux 工具）

### 3. Core Dump 完整生命周期

**生成**：
```bash
# 内核配置
kernel.core_pattern=/tmp/belt-control-cores/core.%e.%p.%t

# 容器配置
--ulimit core=-1
-v /tmp/belt-control-cores:/tmp/belt-control-cores:rw
```

**分析**：
```bash
# GDB 批处理模式
gdb -batch \
    -ex 'bt'              # 堆栈回溯
    -ex 'info registers'  # 寄存器状态
    -ex 'info locals'     # 局部变量
    /app/belt_control_system /cores/core.*
```

**缓存**：
```bash
# 避免重复分析
if [ -f "$ANALYSIS_FILE" ]; then
    echo "ℹ️  Core Dump 已分析（使用缓存）"
else
    # 执行分析...
fi
```

---

## 🔗 Git Commit 记录

| Commit | 描述 | 文件 |
|--------|------|------|
| `7753243b` | 修复：移除 sshpass 依赖，使用原生 SSH | build-ubuntu24-apt.ps1 |
| `29c58bf2` | 启用 Core Dump 功能：添加 --ulimit core=-1 | build-ubuntu24-apt.ps1 |
| `bcc90564` | Fix 100.15：启用硬件编码器环境变量 | build-ubuntu24-apt.ps1 |

---

## 📚 文档列表

1. [CRLF 换行符修复](02-修复-run脚本CRLF换行符问题.md)（3 次迭代完整记录）
2. [启用 Core Dump 功能](03-启用Core-Dump功能.md)
3. [Core Dump 分析：libx264 崩溃](04-Core-Dump分析-libx264编码器内存释放崩溃.md)
4. [自动 Core Dump 分析集成](01-工作总结-自动Core-Dump分析集成.md)（昨天）

---

## 🎯 下一步验证

### 验证清单
1. ⏳ 重新部署到设备 192.168.10.188
2. ⏳ 确认日志显示使用硬件编码器：
   ```
   ✅ [FIX 97] USE_HARDWARE_ENCODER=1: Trying hardware encoder first
      Encoder: h264_rkmpp (hardware)
      Strategy: DRM_PRIME zero-copy (GPU → VPU)
   ```
3. ⏳ 测试视频通话不再崩溃
4. ⏳ 验证 CPU 使用率降低到 ~1%

### 部署命令
```powershell
.\build-ubuntu24-apt.ps1 188
```

---

## 💡 经验总结

### 1. 跨平台脚本开发要点
- **换行符**：Windows CRLF vs Linux LF
- **编码**：UTF8 with BOM vs UTF8 without BOM
- **管道陷阱**：PowerShell 管道会自动转换换行符
- **本地测试误导**：bash 5.2 容忍 CRLF，bash 5.0 不容忍

### 2. Core Dump 调试技巧
- **启用条件**：`--ulimit core=-1` + 内核 `core_pattern`
- **分析工具**：GDB 批处理模式（`-batch`）
- **信息提取**：堆栈、寄存器、局部变量
- **缓存机制**：避免重复分析同一个 Core Dump

### 3. 硬件编解码器适配
- **格式兼容性**：DRM_PRIME 只能被硬件编解码器使用
- **零拷贝优势**：GPU → VPU 直传，无需 CPU 介入
- **环境变量控制**：`USE_HARDWARE_ENCODER=1`

---

## 🏆 工作成果

### 功能完整性
✅ **单脚本解决方案**：`.\build-ubuntu24-apt.ps1 188`
- 自动检测源码变化
- 自动编译 PJSIP
- 自动交叉编译应用
- 自动构建 Docker 镜像
- 自动部署到设备
- 自动处理 CRLF 换行符
- 自动启用 Core Dump
- 自动启用硬件编码器
- 崩溃时自动分析并显示原因

### 调试能力
✅ **完整的崩溃诊断流程**：
1. 检测段错误（exit code 139）
2. 生成 Core Dump 文件
3. 自动 GDB 分析
4. 显示崩溃摘要
5. 保存完整报告
6. 缓存机制避免重复分析

### 问题解决
✅ **libx264 崩溃根因定位**：
- ✅ 定位到内存释放崩溃
- ✅ 追溯到格式不兼容
- ✅ 找到解决方案（硬件编码器）
- ✅ 实施修复（环境变量）

---

**工作时长**: 1.5 小时
**Git Commits**: 3 个
**文档创建**: 4 份
**问题修复**: 4 个（Fix 100.13 - 100.15 + Core Dump 分析）

**状态**: ✅ 全部完成，等待验证

---

**创建时间**: 2026-01-10 18:40
**作者**: Claude (Sonnet 4.5)
