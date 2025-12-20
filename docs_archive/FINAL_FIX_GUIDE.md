# SIP 注册问题 - 最终修复指南

## 🎯 问题根本原因

经过深入诊断,发现了真正的问题:

**PJSIP 使用了错误的 I/O 后端!**

您的日志显示:
```
11:25:31.079  pjlib  .select() I/O Queue created  ← 错误!
```

应该显示:
```
pjlib  WinNT IOCP I/O Queue created  ← 正确!
```

## 📋 已完成的配置修改

### 1. 修改了 os-win32.mak ✅

**文件:** `F:\0\pjproject-2.15.1\pjproject-2.15.1\pjlib\build\os-win32.mak`

**第 16-19 行:**
```makefile
# 使用 Windows IOCP 而不是 select()
# IOCP 在 Windows 上更可靠,特别是接收 UDP 数据
export PJLIB_OBJS +=	ioqueue_winnt.o    ← 已启用
#export PJLIB_OBJS +=	ioqueue_select.o  ← 已禁用
```

### 2. 修改了 config_site.h ✅

**文件:** `F:\0\pjproject-2.15.1\pjproject-2.15.1\pjlib\include\pj\config_site.h`

- 修复了 `PJ_IOQUEUE_MAX_HANDLES = 256` (解决 FD_SET 大小问题)
- 添加了 `PJ_WIN32_WINNT = 0x0501` (启用 Windows IOCP 支持)

## 🔧 需要执行的步骤

### 方法 A: 使用批处理脚本 (推荐)

我已经创建了自动化脚本:

```cmd
F:\0\pjproject-2.15.1\pjproject-2.15.1\rebuild_with_iocp.bat
```

**双击运行此脚本**,它会:
1. 清理并重新编译所有 PJSIP 模块
2. 自动复制新库到您的项目
3. 显示编译结果

### 方法 B: 手动执行

如果批处理脚本有问题,请手动执行:

#### 步骤 1: 编译 pjlib

```cmd
cd /d F:\0\pjproject-2.15.1\pjproject-2.15.1\pjlib\build
C:\Qt\Tools\mingw1120_64\bin\mingw32-make.exe clean
C:\Qt\Tools\mingw1120_64\bin\mingw32-make.exe
```

**关键验证:** 查看编译输出,应该看到:
```
Compiling src/pj/ioqueue_winnt.c
```

如果看到 `ioqueue_select.c`,说明配置有问题!

#### 步骤 2: 编译其他模块

```cmd
cd /d F:\0\pjproject-2.15.1\pjproject-2.15.1\pjlib-util\build
C:\Qt\Tools\mingw1120_64\bin\mingw32-make.exe clean && C:\Qt\Tools\mingw1120_64\bin\mingw32-make.exe

cd /d F:\0\pjproject-2.15.1\pjproject-2.15.1\pjnath\build
C:\Qt\Tools\mingw1120_64\bin\mingw32-make.exe clean && C:\Qt\Tools\mingw1120_64\bin\mingw32-make.exe

cd /d F:\0\pjproject-2.15.1\pjproject-2.15.1\pjmedia\build
C:\Qt\Tools\mingw1120_64\bin\mingw32-make.exe clean && C:\Qt\Tools\mingw1120_64\bin\mingw32-make.exe

cd /d F:\0\pjproject-2.15.1\pjproject-2.15.1\pjsip\build
C:\Qt\Tools\mingw1120_64\bin\mingw32-make.exe clean && C:\Qt\Tools\mingw1120_64\bin\mingw32-make.exe
```

#### 步骤 3: 复制库文件

```cmd
copy /Y F:\0\pjproject-2.15.1\pjproject-2.15.1\pjlib\lib\*.a e:\2025\3_gongkongji\belt_control_system\libs\pjsip\
copy /Y F:\0\pjproject-2.15.1\pjproject-2.15.1\pjsip\lib\*.a e:\2025\3_gongkongji\belt_control_system\libs\pjsip\
copy /Y F:\0\pjproject-2.15.1\pjproject-2.15.1\pjmedia\lib\*.a e:\2025\3_gongkongji\belt_control_system\libs\pjsip\
copy /Y F:\0\pjproject-2.15.1\pjproject-2.15.1\pjnath\lib\*.a e:\2025\3_gongkongji\belt_control_system\libs\pjsip\
```

#### 步骤 4: 重新编译应用程序

```cmd
cd /d e:\2025\3_gongkongji\belt_control_system
taskkill /F /IM belt_control_system.exe 2>nul
rmdir /S /Q build\src\risip
C:\Qt\Tools\CMake_64\bin\cmake.exe --build build --target belt_control_system
```

#### 步骤 5: 测试

```cmd
start e:\2025\3_gongkongji\belt_control_system\build\bin_windows\belt_control_system.exe
```

## ✅ 验证成功的标志

启动应用后,控制台日志应该显示:

```
11:XX:XX.XXX  pjlib  WinNT IOCP I/O Queue created (0x...)  ← 关键!
```

然后尝试注册,应该看到:

```
TX ... REGISTER ...          ← 发送注册请求
RX ... 401 Unauthorized ...  ← 接收 401 响应 (之前看不到!)
TX ... REGISTER ... Authorization ...  ← 发送带认证的请求
RX ... 200 OK ...            ← 注册成功!
```

## 🔍 如果仍然显示 "select() I/O Queue"

这说明新库没有被正确链接。请检查:

1. **库文件时间戳是否更新:**
   ```cmd
   dir /O-D e:\2025\3_gongkongji\belt_control_system\libs\pjsip\libpj*.a
   ```
   应该显示最新的编译时间

2. **是否删除了 risip 模块缓存:**
   ```cmd
   rmdir /S /Q e:\2025\3_gongkongji\belt_control_system\build\src\risip
   ```

3. **CMake 缓存可能需要清理:**
   ```cmd
   cd /d e:\2025\3_gongkongji\belt_control_system
   rmdir /S /Q build
   mkdir build
   cd build
   C:\Qt\Tools\CMake_64\bin\cmake.exe ..
   C:\Qt\Tools\CMake_64\bin\cmake.exe --build . --target belt_control_system
   ```

## 📊 问题解析

### 为什么 select() 无法工作?

1. **Windows select() 的限制:**
   - 在某些网络环境下不可靠
   - UDP 数据包接收容易丢失
   - 防火墙/NAT 可能干扰

2. **IOCP (I/O Completion Ports) 的优势:**
   - Windows 原生高性能异步 I/O
   - 可靠的 UDP 数据接收
   - 正确处理完成通知
   - FreeSWITCH 的 401 响应会被正确接收!

### 之前的尝试为什么失败?

1. ✅ 修复了 FD_SETSIZE 断言 - 解决了内存问题
2. ✅ 添加了 worker 线程 - 但 select() 仍不工作
3. ❌ **关键遗漏:** 没有切换到 IOCP 后端!

## 📝 相关文件

- PJSIP Makefile: [os-win32.mak](F:\0\pjproject-2.15.1\pjproject-2.15.1\pjlib\build\os-win32.mak)
- PJSIP 配置: [config_site.h](F:\0\pjproject-2.15.1\pjproject-2.15.1\pjlib\include\pj\config_site.h)
- 重编译脚本: [rebuild_with_iocp.bat](F:\0\pjproject-2.15.1\pjproject-2.15.1\rebuild_with_iocp.bat)
- 应用程序: [e:\2025\3_gongkongji\belt_control_system](e:\2025\3_gongkongji\belt_control_system)

## 🎉 预期结果

使用 IOCP 后端后,SIP 注册应该能够:

1. ✅ 发送 REGISTER 请求
2. ✅ **接收 FreeSWITCH 的 401 Unauthorized** (关键!)
3. ✅ 自动发送带 Authorization 头的第二次 REGISTER
4. ✅ 接收 200 OK 并完成注册
5. ✅ 成功进行 SIP 呼叫

---

如有问题,请提供日志中的 "I/O Queue created" 那一行,以便诊断。

修复日期: 2025-11-28
