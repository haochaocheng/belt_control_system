# Phase 7.48.88.21 - 数字键1-8独立启停设备（Input1页前提条件）

## 日期
2026-03-25

## 需求描述

设备配置共12个设备（皮带），前8个需要支持按数字键1-8独立启停。本机作为主站，其他7个全部是下位机（无自己的逻辑控制和传感器处理，只有采集信号和输出继电器），所有控制由本机完成。

**问题**：直接按数字键8可能误触发
**方案**：增加前提条件 — 界面必须在 Input1Page 时，数字键1-8才生效

## 实现方案

### 交互设计
- **前提条件**：swipeView 必须在 Input1Page（索引5），否则数字键无效
- **Toggle模式**：按一次启动，再按一次停止（同一数字键）
- **多皮带并行**：1号启动完成后，可以继续启动2号，多条皮带同时运行
- **序列互斥**：同时只能执行一个启停序列（startBelt内部防重入保护）

### 技术实现

#### 1. CommonControl 新增按皮带运行状态跟踪
- `QMap<int, bool> m_beltRunning`：按皮带号跟踪运行状态
- `Q_INVOKABLE bool isBeltRunning(int beltNumber)`：QML查询接口
- `startBelt`/`stopBelt` 添加 `Q_INVOKABLE`：QML可直接调用
- `beltRunningChanged(int beltNumber, bool running)` 信号

#### 2. 序列完成时更新状态
- 启动序列完成：`m_beltRunning[beltNumber] = true`
- 停止序列完成：`m_beltRunning[beltNumber] = false`

#### 3. App.qml 数字键处理
- `Qt.Key_1` ~ `Qt.Key_8` 映射到皮带号1-8
- 检查 `swipeView.currentIndex === 5`（Input1页前提）
- 检查 `runtimeTracker.isFault`（故障保护）
- 调用 `commonControl.isBeltRunning(N)` 判断toggle方向

## 修改文件

| 文件 | 修改内容 |
|------|---------|
| `src/control/CommonControl.h` | startBelt/stopBelt加Q_INVOKABLE + m_beltRunning + isBeltRunning() + beltRunningChanged信号 |
| `src/control/CommonControl.cpp` | isBeltRunning()实现 + 序列完成时更新m_beltRunning |
| `src/qml/App.qml` | 数字键1-8处理逻辑（Input1页前提+toggle启停） |

## 验证方法
1. 非Input1页按数字键 → 无反应
2. Input1页按1 → 1号皮带完整启动序列
3. 1号运行中按1 → 1号停止
4. 1号序列完成后按2 → 2号启动，两条皮带同时运行
5. 故障状态按数字键 → 弹出故障提示
