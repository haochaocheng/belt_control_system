# Phase 7.48.88.8 - 修复逻辑控制时间轴未同步已启动状态

## 日期
2026-03-24

## 问题描述
用户在电机控制页面按R键启动皮带，等完全启动后切换到逻辑控制页面，启动顺序/启动流程时间轴仍然显示默认状态（空闲），没有反映皮带已运行的事实。

## 根因分析
`LogicControlPanel.qml` 通过连接 `commonControl` 的信号（`warningStarted`、`warningPlaybackFinished`、`deviceStatusChanged`）来实时跟踪启动过程。但这些信号是**一次性事件**：

1. 用户在电机控制页面 → `LogicControlPanel` **未加载**（QML Loader 按需加载）
2. 按R键启动 → `commonControl` 依次发出信号
3. 信号发出时 `LogicControlPanel` 不存在 → **所有信号丢失**
4. 启动完成后切换到逻辑控制页面 → `LogicControlPanel` 被创建
5. `Component.onCompleted` 只调用 `loadFromConfig()` → 时间轴是默认空闲状态

## 修复方案
在 `Component.onCompleted` 中新增 `syncStateFromTracker()` 函数，查询 `runtimeTracker` 的当前状态：

- **`runtimeTracker.isRunning === true`**：皮带已在运行，设置时间轴为"启动完成"状态
  - `rtPhase = 2`（启动序列运行中）
  - `rtActivatedCount = startupSeq.length`（所有设备已激活）
  - 3秒后自动清除（与正常启动完成逻辑一致）

- **`runtimeTracker.isFault === true`**：皮带故障状态
  - `rtPhase = 3`（故障）
  - 显示故障设备名

- **都不是**：停止状态，保持默认

## 修改文件
| 文件 | 修改内容 |
|------|---------|
| `src/qml/components/device_info/pages/LogicControlPanel.qml` | Component.onCompleted增加syncStateFromTracker() + 新增syncStateFromTracker函数 |

## 验证方法
1. 在电机控制页面按R键启动皮带
2. 等待启动完成（所有设备运行）
3. 切换到逻辑控制页面
4. 时间轴应显示"启动完成"状态（所有设备节点绿色填充）
5. 3秒后自动恢复默认状态
