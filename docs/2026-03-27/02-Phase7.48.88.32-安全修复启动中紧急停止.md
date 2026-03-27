# Phase 7.48.88.32 - 安全修复：启动过程中允许紧急停止

## 修改时间
2026-03-27

## 安全隐患描述

**问题**：在 Input1 界面按数字键2启动2号皮带后，在启动过程中（起车预警播放中或设备启动序列执行中）再按2号键无法停止。

**根因分析**：

1. QML 数字键 toggle 逻辑使用 `isBeltRunning(keyNumber)` 判断启停方向
2. `m_beltRunning[beltNumber] = true` 只在启动序列**全部完成后**才设置
3. 启动过程中（预警播放 + 松闸 + 电机启动）：
   - `isBeltRunning()` → false
   - QML toggle → 走 `startBelt()` 路径
   - `startBelt()` 的防重入 → "序列正在执行，忽略启动请求"
4. **结果：启动过程中完全无法停止，必须等到全部启动完毕**

**安全风险**：
- 起车预警期间（通常 10-15 秒）人员发现异常无法紧急停止
- 设备启动序列期间（松闸→电机启动）出现问题无法中断
- 违反工业控制安全原则：**任何时候都必须能立即停止设备**

## 修复方案

### 1. 新增 `isBeltStarting()` 方法（CommonControl.h/cpp）

检查三种启动中状态：
- 该皮带的起车预警正在播放 (`m_isWarningPlaying && m_currentBeltNumber == beltNumber`)
- 该皮带的启动序列正在执行 (`state->isRunning && state->isStartup`)
- 待处理队列中有该皮带的启动操作

### 2. 修改 QML toggle 逻辑（App.qml）

```qml
// 旧：只检查运行状态
if (commonControl.isBeltRunning(keyNumber)) { stopBelt() }

// 新：运行中 或 启动中 都走停止
if (commonControl.isBeltRunning(keyNumber) || commonControl.isBeltStarting(keyNumber)) { stopBelt() }
```

### 3. 修改 `stopBelt()` 支持启动中紧急停止（CommonControl.cpp）

新增两个启动中断分支（在排队等待之前执行）：

**分支A：起车预警中 → 立即中断预警**
- 清除待处理队列中该皮带的所有操作
- `stopWarningPlayback()` 停止预警音频和定时器
- 直接标记 `m_beltRunning[beltNumber] = false`
- 不执行停止序列（因为设备尚未激活）

**分支B：启动序列执行中 → 中断序列，紧急停止**
- 停止启动序列定时器
- 清除待处理操作
- 调用 `emergencyStopBelt(beltNumber)` 执行紧急停止序列

## 修改文件
- `src/control/CommonControl.h` - 新增 `isBeltStarting()` 声明
- `src/control/CommonControl.cpp` - 实现 `isBeltStarting()` + 修改 `stopBelt()`
- `src/qml/App.qml` - 数字键 toggle 增加启动中检测

## 状态机变化

```
旧逻辑：
  停止 --[按键]--> 启动中 --[等待完成]--> 运行 --[按键]--> 停止
                    ↑ 无法停止！

新逻辑：
  停止 --[按键]--> 启动中 --[等待完成]--> 运行 --[按键]--> 停止
                    ↓ [按键]
                  紧急停止 → 停止
```
