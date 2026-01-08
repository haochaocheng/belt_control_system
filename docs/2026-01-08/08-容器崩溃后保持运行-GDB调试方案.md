# 容器崩溃后保持运行 - GDB 调试方案

**日期**: 2026-01-08 17:10
**问题**: 程序崩溃导致容器自动停止，GDB 无法附加

---

## 🎯 问题分析

**当前流程**：
```
1. 容器启动 → CMD ["/app/belt_control_system"]
2. 程序运行 → 初始化视频编解码器
3. 程序崩溃 (exit 139) → 容器主进程退出
4. 容器自动停止 → GDB 无法附加 ❌
```

**需要**：
- ✅ 程序崩溃后容器保持运行
- ✅ 保留 core dump 或允许 GDB 附加

---

## ⚡ 方案 1：设备上直接修改运行命令（最快，无需重新构建）⭐

### 优势
- ✅ **无需重新编译镜像**
- ✅ **立即生效**（1分钟）
- ✅ 容器崩溃后保持运行

### 实施步骤

```bash
# 1. SSH 连接到设备
ssh root@192.168.10.188

# 2. 停止当前容器
docker stop belt-control-latest
docker rm belt-control-latest

# 3. 使用新命令启动容器（保持容器运行）
docker run -d \
  --name belt-control-latest \
  --privileged \
  --network host \
  -v /dev:/dev \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -e DISPLAY=$DISPLAY \
  belt-control-v3.5-latest \
  /bin/bash -c "/app/belt_control_system || sleep infinity"
#                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#                程序崩溃后进入无限等待，容器保持运行
```

### 使用方法

```bash
# 等待程序崩溃后，容器仍在运行
docker ps | grep belt-control-latest  # ✅ 容器仍然运行

# 进入容器使用 GDB 分析 core dump 或重启程序
docker exec -it belt-control-latest bash

# 查看日志
docker logs belt-control-latest

# 使用 GDB 重新运行程序
gdb /app/belt_control_system
(gdb) run
# ... 崩溃时停止
(gdb) bt full
```

---

## 🔬 方案 2：GDB 直接启动程序（最详细）⭐⭐

### 优势
- ✅ 无需重新构建镜像
- ✅ 直接在 GDB 控制下运行程序
- ✅ 崩溃时自动停止并保留现场

### 实施步骤

```bash
# 1. SSH 连接到设备
ssh root@192.168.10.188

# 2. 停止当前容器
docker stop belt-control-latest
docker rm belt-control-latest

# 3. 使用 GDB 启动容器
docker run -it \
  --name belt-control-latest \
  --privileged \
  --network host \
  -v /dev:/dev \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -e DISPLAY=$DISPLAY \
  belt-control-v3.5-latest \
  /bin/bash
#  ^^^^^^^^^
#  交互式 shell

# 4. 在容器内启动 GDB
root@enc:/app# gdb /app/belt_control_system

# 5. GDB 命令
(gdb) set logging on                    # 启用日志
(gdb) set logging file /tmp/gdb.log     # 日志文件
(gdb) run                               # 运行程序

# 6. 等待崩溃，崩溃时自动停止

# 7. 查看崩溃信息
(gdb) bt full                           # 完整堆栈
(gdb) info registers                    # 寄存器
(gdb) info locals                       # 局部变量
(gdb) frame 0                           # 切换到崩溃帧
(gdb) list                              # 查看崩溃位置代码
(gdb) print ctx                         # 打印变量
```

---

## 🛠️ 方案 3：启用 Core Dump（离线分析）

### 优势
- ✅ 无需交互式调试
- ✅ 崩溃后保留完整内存快照
- ✅ 可以在开发机上分析

### 实施步骤

```bash
# 1. 启动容器并启用 core dump
ssh root@192.168.10.188

docker run -d \
  --name belt-control-latest \
  --privileged \
  --network host \
  -v /dev:/dev \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -e DISPLAY=$DISPLAY \
  belt-control-v3.5-latest \
  /bin/bash -c "ulimit -c unlimited && /app/belt_control_system || sleep infinity"
#              ^^^^^^^^^^^^^^^^^^^^
#              启用 core dump

# 2. 设置 core dump 文件位置
docker exec belt-control-latest bash -c 'echo "/tmp/core.%e.%p" > /proc/sys/kernel/core_pattern'

# 3. 等待程序崩溃

# 4. 查找 core 文件
docker exec belt-control-latest ls -lh /tmp/core.*

# 5. 分析 core dump
docker exec -it belt-control-latest bash
gdb /app/belt_control_system /tmp/core.belt_control_system.123

(gdb) bt full              # 崩溃堆栈
(gdb) info registers       # 寄存器状态
(gdb) info threads         # 所有线程
```

---

## 📝 方案 4：修改 Dockerfile（需要重新构建）

如果经常需要调试，可以修改 Dockerfile：

```dockerfile
# ✅ 2026-01-08 17:10 [调试模式] 程序崩溃后保持容器运行
CMD ["/bin/bash", "-c", "/app/belt_control_system || sleep infinity"]
```

然后重新构建镜像：
```powershell
.\build-ubuntu24-apt.ps1 188
```

---

## 📊 方案对比

| 方案 | 速度 | 详细度 | 是否需要重新构建 | 推荐度 |
|------|------|--------|----------------|--------|
| **方案 1: 修改运行命令** | ⚡⚡⚡⚡⚡ 1分钟 | ⭐⭐⭐ | ❌ 否 | ⭐⭐⭐⭐⭐ |
| **方案 2: GDB 启动** | ⚡⚡⚡⚡ 2分钟 | ⭐⭐⭐⭐⭐ | ❌ 否 | ⭐⭐⭐⭐⭐ |
| **方案 3: Core Dump** | ⚡⚡⚡⚡ 2分钟 | ⭐⭐⭐⭐⭐ | ❌ 否 | ⭐⭐⭐⭐ |
| **方案 4: 修改 Dockerfile** | ⚡ 10分钟 | ⭐⭐⭐ | ✅ 是 | ⭐⭐ |

---

## 🎯 推荐操作流程

### 立即执行（方案 1 + 方案 2 结合）

```bash
# 1. 连接设备
ssh root@192.168.10.188

# 2. 重启容器（保持运行）
docker stop belt-control-latest && docker rm belt-control-latest

docker run -it \
  --name belt-control-latest \
  --privileged \
  --network host \
  -v /dev:/dev \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -e DISPLAY=$DISPLAY \
  belt-control-v3.5-latest \
  /bin/bash

# 3. 在容器内启动 GDB
gdb /app/belt_control_system

# 4. GDB 调试命令
(gdb) set logging on
(gdb) set pagination off
(gdb) run

# 5. 等待崩溃（用 miniSIP 拨打视频通话）

# 6. 崩溃时自动停止，查看信息
(gdb) bt full
(gdb) info registers
(gdb) frame 0
(gdb) list
(gdb) info locals
```

---

## ✅ 预期结果

### 成功情况

GDB 会显示精确的崩溃位置：

```
Program received signal SIGSEGV, Segmentation fault.
0x00007f8c12345678 in avcodec_open2 () from /app/lib/libavcodec.so.60

(gdb) bt full
#0  0x00007f8c12345678 in avcodec_open2 () from /app/lib/libavcodec.so.60
#1  0x00000055a1234567 in open_ffmpeg_codec () at ffmpeg_vid_codecs.c:2107
    ff = 0x7f8c004000
    dec_err = 0
    ctx = 0x7f8c004800
    ...

(gdb) info registers
rax            0x0      0
rbx            0x7f8c004000     ...
rip            0x7f8c12345678   ...

(gdb) frame 1
#1  0x00000055a1234567 in open_ffmpeg_codec () at ffmpeg_vid_codecs.c:2107
2107                dec_err = avcodec_open2(ff->dec_ctx, ff->dec, NULL);

(gdb) print ff->dec->name
$1 = "h264_rkmpp"

(gdb) print ff->dec_ctx->hw_device_ctx
$2 = (AVBufferRef *) 0x7f8c008000
```

这样我们就能准确知道：
- ✅ 崩溃在哪个函数（`avcodec_open2`）
- ✅ 崩溃在哪一行（`ffmpeg_vid_codecs.c:2107`）
- ✅ 所有变量的值
- ✅ 完整的调用链

---

**文档版本**: v1.0
**创建时间**: 2026-01-08 17:10
**推荐**: 立即使用方案 1 或方案 2，无需重新构建镜像
