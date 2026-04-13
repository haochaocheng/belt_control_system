# Phase 7.48.88.116 修复编译错误——MQTTController.h 路径错误

**日期**：2026-04-14  
**分支**：feature/hardware-video-codec  
**类型**：fix（编译修复）

---

## 错误现象

```
/workspace/src/control/CentralizedControlManager.cpp:13:10:
fatal error: MQTTController.h: No such file or directory
   13 | #include "MQTTController.h"
      |          ^~~~~~~~~~~~~~~~~~
compilation terminated.
```

## 根本原因

`MQTTController.h` 位于 `src/mqtt/` 目录，而非 `src/control/`。

编译器 include 路径包含 `-I/workspace/src`，因此正确的相对路径是 `"mqtt/MQTTController.h"`。

其他在 `src/control/` 中使用该头文件的源文件（`DeviceRoleManager.cpp`）已使用 `"mqtt/MQTTController.h"`，本次属于笔误。

## 修复

**文件**：`src/control/CentralizedControlManager.cpp` 第 13 行

```cpp
// 修复前（错误）
#include "MQTTController.h"

// 修复后（2026-04-14）
#include "mqtt/MQTTController.h"
```

## 验证

参考 `DeviceRoleManager.cpp` 第 8 行相同写法：
```cpp
#include "mqtt/MQTTController.h"
```
