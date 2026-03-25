# Phase 7.48.88.22 - 多皮带并行序列执行（去除序列互斥）

## 日期
2026-03-25

## 问题描述

Phase 7.48.88.21 实现了数字键1-8独立启停设备，但采用**全局单一序列互斥**（`m_isSequenceRunning` 布尔值），导致：
- 1号皮带序列执行中按2 → 被`startBelt`防重入忽略
- 无法同时为多条皮带执行启停序列

**用户反馈**：
1. 8个设备各有独立的启动逻辑，不应共享一个序列状态
2. 多条皮带应能同时执行各自的启停序列
3. 暂无连锁限制，可自由启动任意皮带

## 核心问题

旧架构用5个全局变量管理序列，只能同时跑一个序列：
- `m_isSequenceRunning` (bool) — 全局互斥
- `m_currentSequence` (QStringList) — 单一设备列表
- `m_currentSequenceIndex` (int) — 单一进度
- `m_isStartupSequence` (bool) — 单一模式
- `m_deviceSequenceTimer` (QTimer*) — 单一定时器

## 修复方案

### 设计原则
1. **设备序列并行**：每条皮带有独立的 BeltSequenceState（序列、索引、定时器），互不干扰
2. **音频串行**：音频播放器只有一个，预警/停车音频排队播放
3. **待处理队列**：音频忙时，新的启停请求入 `m_pendingBeltOps` 队列，音频空闲后自动处理

### 关键修改

1. **BeltSequenceState 结构体**：封装per-belt序列状态（设备列表、进度、定时器、运行标志）
2. **QMap<int, BeltSequenceState*> m_beltSequences**：按皮带号管理活跃序列
3. **startBelt() 防重入改为per-belt**：仅检查本皮带是否有活跃序列，不阻止其他皮带
4. **音频忙排队**：预警/停车音频播放中时，新请求入待处理队列
5. **per-belt QTimer + lambda**：每条皮带独立定时器，lambda捕获皮带号
6. **processPendingBeltOps()**：音频空闲后自动处理队列中的下一个操作
7. **配置加载修复**：`loadMotorConfig`/`loadBrakeConfig`/`loadTensionConfig` 使用实际皮带号替代硬编码1

## 修改文件

| 文件 | 修改内容 |
|------|---------|
| `src/control/CommonControl.h` | 新增 BeltSequenceState 结构体 + m_beltSequences QMap + m_pendingBeltOps 队列 + 函数签名修改 + 新方法声明 |
| `src/control/CommonControl.cpp` | 重构序列执行为per-belt状态 + startBelt/stopBelt防重入改per-belt + 音频忙排队 + readDeviceDelay提取 + emergencyStopBelt适配 |

## 验证方法
1. 单皮带启停：按1 → 1号完整启动序列 → 按1 → 1号停止
2. 并行启动：1号预警中按2 → 2号排队 → 1号预警结束后2号预警开始 → 两条皮带各自执行序列
3. 并行序列：1号和2号序列同时运行，各有独立定时器
4. 独立停止：按1仅停1号，2号继续运行
5. 故障保护：故障状态按数字键 → 弹出故障提示
6. 紧急停车：emergencyStopBelt(N) → 仅停指定皮带
