# PJSIP 初始化失败问题报告

## 问题概述

**日期**: 2025-11-27
**状态**: 已诊断，待修复
**严重程度**: 严重（阻止 SIP 电话功能使用）

## 症状

点击右上角绿色电话图标 📞 后，整个应用程序崩溃退出。

## 错误信息

```
qml: SIP button clicked, opening SIP popup...
Initializing SIP endpoint with Risip SDK...
Starting Risip endpoint...
13:59:04.181        os_core_win32.c !pjlib 2.15.1 for win32 initialized
13:59:04.191         sip_endpoint.c  .Creating endpoint instance...
Assertion failed: sizeof(pj_fd_set_t)-sizeof(pj_sock_t) >= sizeof(fd_set),
    file ../src/pj/sock_select.c, line 45
```

## 根本原因

PJSIP 2.15.1 库编译时的配置与当前 Windows 系统的 socket 结构不匹配。

### 技术细节

1. **断言失败位置**: `pjlib/src/pj/sock_select.c:45`
2. **断言内容**: `sizeof(pj_fd_set_t) - sizeof(pj_sock_t) >= sizeof(fd_set)`
3. **原因**: PJSIP 内部的 `pj_fd_set_t` 结构体大小配置与 Windows SDK 的 `fd_set` 不匹配

这是一个**编译时配置问题**，不是运行时可以修复的问题。

## 环境信息

- **操作系统**: Windows 10/11
- **编译器**: MinGW GCC 11.2.0
- **PJSIP 版本**: 2.15.1
- **Qt 版本**: 6.5
- **编译配置**: 使用 `--disable-video` 选项编译

## 已尝试的修复方案

### 1. 音频设备配置调整 ❌
- 尝试使用 `pjsua_set_null_snd_dev()`
- 尝试使用 `pjsua_set_no_snd_dev()`
- 尝试在不同阶段禁用音频设备
- **结果**: 崩溃发生在音频初始化之前，这些方法无效

### 2. MediaConfig 参数调整 ❌
- 禁用回声消除 (`ecTailLen = 0`)
- 禁用 VAD (`noVad = true`)
- 设置时钟频率为 0
- **结果**: 无效，断言失败发生在 libCreate() 阶段

### 3. 异常捕获 ❌
- 添加 try-catch 包裹所有初始化步骤
- **结果**: 断言失败直接终止进程，无法捕获

## 临时解决方案

**当前状态**: PJSIP 初始化已完全禁用

修改文件：`src/sip_phone/SipPhoneManager.cpp`

```cpp
bool SipPhoneManager::initializeEndpoint()
{
    // PJSIP初始化已禁用
    // 原因：sizeof(pj_fd_set_t) 配置不匹配

    d->initialized = true;
    emit isInitializedChanged(true);
    updateServerStatus("SIP引擎配置错误（需要重新编译PJSIP）");

    return true;
}
```

**影响**:
- ✅ SIP 界面可以正常打开和显示
- ❌ SIP 电话功能完全不可用（无法拨打/接听电话）
- ✅ 应用程序其他功能正常运行

## 永久修复方案

### 选项 1: 重新编译 PJSIP（推荐）

需要使用正确的配置重新编译 PJSIP 2.15.1：

1. **修改 `pjlib/include/pj/config_site.h`**:
   ```c
   #define PJ_IOQUEUE_MAX_HANDLES 64  // 减小此值以匹配Windows
   #define PJ_FD_SETSIZE 64           // 与上面保持一致
   ```

2. **或者使用 IOCP（Windows I/O Completion Ports）**:
   ```c
   #define PJ_HAS_TCP 1
   #define PJ_IOQUEUE_HAS_SAFE_UNREG 1
   // 使用 Windows IOCP 代替 select()
   ```

3. **重新编译**:
   ```bash
   cd pjproject-2.15.1
   ./configure --prefix=/path/to/install \\
               --disable-video \\
               CFLAGS="-DPJ_FD_SETSIZE=64"
   make dep && make clean && make
   make install
   ```

4. **重新链接项目**

### 选项 2: 使用预编译的 PJSIP 二进制包

从 PJSIP 官方网站下载为 Windows 10/11 预编译的二进制包。

### 选项 3: 替换 SIP 库

考虑使用其他 SIP 库，如：
- **Sofia-SIP**: 更轻量级
- **PJSUA2 官方预编译包**: 确保与当前系统兼容
- **Linphone SDK**: 完整的 VoIP 解决方案

## 相关文件

- `/src/sip_phone/SipPhoneManager.cpp` - 已禁用初始化
- `/src/risip/core/risipendpoint.cpp` - 包含初始化逻辑
- `/PJSIP_COMPILE_SUCCESS.md` - PJSIP 编译记录
- `/run_debug_keepopen.bat` - 调试批处理文件

## 下一步行动

1. **短期**（已完成）:
   - ✅ 禁用 PJSIP 初始化，确保应用不崩溃
   - ✅ 更新状态显示，告知用户 SIP 功能不可用
   - ✅ 提交代码到 Git

2. **中期**（待完成）:
   - ⏳ 研究正确的 PJSIP Windows 配置参数
   - ⏳ 重新编译 PJSIP 库
   - ⏳ 测试新编译的库

3. **长期**（可选）:
   - 考虑切换到更现代的 VoIP 库
   - 或使用 PJSIP 官方预编译包

## 参考资料

- [PJSIP Documentation](https://docs.pjsip.org/)
- [PJSIP Windows Configuration Guide](https://docs.pjsip.org/en/latest/specific-guides/windows/index.html)
- [fd_set size configuration](https://trac.pjsip.org/repos/wiki/FAQ#fd_set)

## 联系信息

如需协助，请联系开发团队或提交 issue 到项目仓库。
