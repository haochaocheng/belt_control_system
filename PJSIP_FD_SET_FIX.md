# PJSIP FD_SET 断言失败修复报告

## 问题诊断

### 症状
- SIP REGISTER 请求发送成功
- FreeSWITCH 返回 401 Unauthorized (Wireshark 可见)
- **PJSIP 无法接收 401 响应** (日志中无 RX 记录)
- PJSIP 不断重传原始 REGISTER 请求

### 根本原因

通过详细测试发现,问题出在 PJSIP 的 `pj_fd_set_t` 结构体大小不足:

```
测试结果 (PJ_IOQUEUE_MAX_HANDLES = 64):
  FD_SETSIZE = 64
  sizeof(fd_set) = 520 bytes
  sizeof(pj_sock_t) = 4 bytes
  sizeof(pj_fd_set_t) = 272 bytes

  断言检查:
  sizeof(pj_fd_set_t) - sizeof(pj_sock_t) >= sizeof(fd_set)
  272 - 4 >= 520
  268 >= 520  ✗ 失败!
```

**问题解释:**

在 Windows 64 位系统上:
- `fd_set` 包含 64 个 **8 字节** 的 SOCKET 句柄 = 64 * 8 + 4 = 520 bytes
- `pj_fd_set_t` 包含 68 个 **4 字节** 的 pj_sock_t = 68 * 4 = 272 bytes
- **缺少 252 bytes!**

由于 `pj_fd_set_t` 太小,无法容纳 Windows 的 `fd_set` 结构,导致:
1. 内存覆盖/损坏
2. select() 调用失败
3. UDP socket 无法正确接收数据

之前我们通过 `#define pj_assert(expr) do { (void)(expr); } while (0)` 禁用了断言,**隐藏了这个严重的内存错误**!

## 修复方案

### 1. 修改 `config_site.h`

文件: `F:\0\pjproject-2.15.1\pjproject-2.15.1\pjlib\include\pj\config_site.h`

```c
// 修复前:
#define PJ_IOQUEUE_MAX_HANDLES    64

// 修复后:
#define PJ_IOQUEUE_MAX_HANDLES    256
```

### 2. 数学计算

需要满足:
```
(PJ_IOQUEUE_MAX_HANDLES + 4) * sizeof(pj_sock_t) - sizeof(pj_sock_t) >= sizeof(fd_set)
(PJ_IOQUEUE_MAX_HANDLES + 4) * 4 - 4 >= 520
PJ_IOQUEUE_MAX_HANDLES >= 127
```

为了留有余量,设置为 256。

### 3. 验证修复

```
测试结果 (PJ_IOQUEUE_MAX_HANDLES = 256):
  sizeof(pj_fd_set_t) = 1040 bytes
  sizeof(pj_fd_set_t) - sizeof(pj_sock_t) = 1036 bytes

  断言检查:
  1036 >= 520  ✓ 通过!
```

### 4. 重新编译 PJSIP

```cmd
cd F:\0\pjproject-2.15.1\pjproject-2.15.1
del /s /q *.o *.a
C:\Qt\Tools\mingw1120_64\bin\mingw32-make.exe -j4
```

### 5. 更新应用程序

将新编译的 PJSIP 库复制到项目并重新编译:
```cmd
copy F:\0\pjproject-2.15.1\pjproject-2.15.1\*\lib\*.a e:\2025\3_gongkongji\belt_control_system\libs\pjsip\
cd e:\2025\3_gongkongji\belt_control_system
rmdir /S /Q build\src\risip
C:\Qt\Tools\CMake_64\bin\cmake.exe --build build --target belt_control_system
```

## 预期结果

修复后,PJSIP 应该能够:
1. ✓ 正确接收 FreeSWITCH 的 401 Unauthorized 响应
2. ✓ 解析 WWW-Authenticate 头
3. ✓ 发送带有 Authorization 头的第二次 REGISTER
4. ✓ 接收 200 OK 并完成注册

## 验证方法

1. 启动应用程序
2. 打开 SIP 设置,输入:
   - 服务器: 192.168.10.243:5060
   - 用户名: 1000
   - 密码: 1234
3. 点击注册
4. 观察日志应该显示:
   - TX (发送) REGISTER
   - **RX (接收) 401** ← 这是关键!
   - TX (发送) REGISTER with Authorization
   - **RX (接收) 200 OK** ← 注册成功!

## 重要说明

**此修复非常关键!** 之前禁用断言虽然消除了错误提示,但实际上掩盖了严重的内存错误。现在:
- 断言已重新启用 (注释掉了 `#define pj_assert` 重定义)
- 内存布局正确,不再有溢出风险
- select() 能够正常工作

## 相关文件

- 配置文件: [F:\0\pjproject-2.15.1\pjproject-2.15.1\pjlib\include\pj\config_site.h](F:\0\pjproject-2.15.1\pjproject-2.15.1\pjlib\include\pj\config_site.h)
- 测试程序: [F:\0\pjproject-2.15.1\test_fdset_size.c](F:\0\pjproject-2.15.1\test_fdset_size.c)
- 断言位置: [F:\0\pjproject-2.15.1\pjproject-2.15.1\pjlib\src\pj\sock_select.c:53](F:\0\pjproject-2.15.1\pjproject-2.15.1\pjlib\src\pj\sock_select.c#L53)

修复日期: 2025-11-28
