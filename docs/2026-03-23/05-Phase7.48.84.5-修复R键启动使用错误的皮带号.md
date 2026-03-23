# Phase 7.48.84.5 - 修复R键启动使用错误的皮带号

## 修改时间
2026-03-23 03:30 (北京时间)

## 问题描述
用户已将本机设备设置为2号皮带（DeviceRoleManager中localDeviceId=2），但按R键启动时，系统仍然播放"1号皮带启动"的语音。

## 根因分析
`MaintenanceControl::handleStart()` 和 `LocalControl::handleStart()` 获取皮带号的代码为：
```cpp
int beltNumber = m_systemConfig->machineNumber();  // 从config.ini读取，固定为1
```

用户在设备弹窗中修改"本机设备"时，更新的是 `DeviceRoleManager::localDeviceId`（存储在device_role.json），而非 `SystemConfig::machineNumber()`（存储在config.ini）。两个控制模块没有引用 `DeviceRoleManager`，因此始终使用旧的config.ini值（1）。

### 数据流对比
```
用户设置"2号皮带" → DeviceRoleManager.localDeviceId = 2  ✅ 正确保存
R键按下 → MaintenanceControl.handleStart()
        → m_systemConfig->machineNumber()  = 1  ❌ 读取了错误的源
        → CommonControl.startBelt(1)
        → 播放"1号皮带启动.mp3"
```

## 修改内容

### MaintenanceControl.h / LocalControl.h
- 添加 `DeviceRoleManager` 前向声明
- 添加 `setDeviceRoleManager()` 方法
- 添加 `m_deviceRoleManager` 成员变量

### MaintenanceControl.cpp / LocalControl.cpp
- 添加 `#include "DeviceRoleManager.h"`
- 初始化 `m_deviceRoleManager(nullptr)`
- 实现 `setDeviceRoleManager()` 方法
- `handleStart()` 和 `handleStop()` 中：
  ```cpp
  // 旧：int beltNumber = m_systemConfig->machineNumber();
  // 新：优先使用DeviceRoleManager，回退到SystemConfig
  int beltNumber = m_deviceRoleManager ? m_deviceRoleManager->localDeviceId() : m_systemConfig->machineNumber();
  ```

### main.cpp
- 在 `DeviceRoleManager` 初始化后，连接到两个控制模块：
  ```cpp
  maintenanceControl.setDeviceRoleManager(&deviceRoleManager);
  localControl.setDeviceRoleManager(&deviceRoleManager);
  ```

## 修改文件清单

| 文件 | 修改内容 |
|------|---------|
| `src/control/MaintenanceControl.h` | 添加DeviceRoleManager引用 |
| `src/control/MaintenanceControl.cpp` | handleStart/handleStop使用DeviceRoleManager |
| `src/control/LocalControl.h` | 添加DeviceRoleManager引用 |
| `src/control/LocalControl.cpp` | handleStart/handleStop使用DeviceRoleManager |
| `src/main/main.cpp` | 连接DeviceRoleManager到两个控制模块 |

## 修复后数据流
```
用户设置"2号皮带" → DeviceRoleManager.localDeviceId = 2
R键按下 → MaintenanceControl.handleStart()
        → m_deviceRoleManager->localDeviceId()  = 2  ✅
        → CommonControl.startBelt(2)
        → 播放"2号皮带启动.mp3"
```
