# Phase 7.48.88.27 - 保护停车防重入与卡片状态修复

## 修改时间
2026-03-26 17:00 (北京时间)

## 修改文件
1. `src/control/CommonControl.cpp` - emergencyStopBelt()防重入
2. `src/control/ProtectionLogicController.cpp` - 停车标志不随保护恢复清除
3. `src/qml/Input1/Input1Content/Screen01.qml` - 卡片停止序列状态显示修复

---

## 问题1：卡片显示"启动中"应为"停止中"

### 现象
设备运行中触发保护停车，卡片左上角显示"启动中"，实际应该显示"停止中"

### 根因
Screen01.qml `onBeltSequenceProgress` 中判断是否为停止序列的逻辑有误：
```javascript
// 旧代码
item.deviceStatus = current > 0 ? (phase.indexOf("停") >= 0 ? "停止中" : "启动中") : item.deviceStatus
```
停止序列中的phase是设备名如"3号电机"、"2号电机"等，不含"停"字 → `indexOf("停")` 返回 -1 → 错误显示"启动中"

### 修复
改为根据之前的 `deviceStatus` 判断：
```javascript
var isStopSequence = (item.deviceStatus === "停车预警" || item.deviceStatus === "停止中")
item.deviceStatus = current > 0 ? (isStopSequence ? "停止中" : "启动中") : item.deviceStatus
```
逻辑：停止序列开始前会先发出"停车预警"阶段，`deviceStatus` 已设为"停车预警"，后续设备步骤判断到这个状态就正确显示"停止中"

---

## 问题2：保护重复触发导致停止序列无限重启

### 现象
设备启动后，触发急停保护开始停车过程，停车过程中触发跑偏保护，停止序列被取消并重新开始。只要保护不断触发，停止永远无法完成。

### 根因（双层问题）

#### 层1：emergencyStopBelt()无条件取消序列
```cpp
// 旧代码
BeltSequenceState *state = m_beltSequences.value(beltNumber, nullptr);
if (state && state->isRunning) {
    state->isRunning = false;  // 无条件取消，包括正在执行的停止序列！
    state->timer->stop();
}
m_isFaultStop = true;
stopBelt(beltNumber);  // 从头开始新的停止序列
```

#### 层2：m_beltStopped标志过早清除
```
1. 急停触发 → m_beltStopped[2] = true → emergencyStopBelt(2) → 停止序列开始
2. 急停恢复（DI位0→1→0） → onProtectionRestored → m_beltStopped[2] = false
3. 跑偏触发 → m_beltStopped[2]为false → 通过检查 → 再次emergencyStopBelt(2)
4. 取消正在执行的停止序列 → 从头重新开始 → 循环
```

### 日志证据
```
2766: 执行正常停车（跳过停车预警）- 皮带 2 保护: "急停"
2778: 2号皮带执行停止顺序: 3号电机→2号电机→1号制动器→张紧控制
2871: [1/4] 2号皮带 停止设备: 3号电机
2882: [2/4] 2号皮带 等待5000ms后停止设备: 2号电机
...
2836: 保护恢复 皮带: 2 保护: "急停"          ← 急停恢复
2837: 皮带 2 所有保护已恢复，停车标志已清除    ← m_beltStopped清除！
...
3007: 保护名称: "沿线跑偏"                    ← 跑偏触发
3032: 紧急停车 2号皮带（跳过停车音频）          ← 再次停车
3033: ⏹️ 取消 2号皮带正在执行的序列            ← 取消了正在执行的停止！
3044: 2号皮带执行停止顺序: 3号电机→2号电机...   ← 从头重新开始
```

### 修复（双层保护）

#### 修复1：emergencyStopBelt()停止序列防重入
```cpp
BeltSequenceState *state = m_beltSequences.value(beltNumber, nullptr);
// 如果停止序列已在执行（isRunning && !isStartup），不中断不重启
if (state && state->isRunning && !state->isStartup) {
    return;  // 忽略重复紧急停车
}
// 只取消启动序列
if (state && state->isRunning && state->isStartup) {
    state->isRunning = false;
    state->timer->stop();
}
```

#### 修复2：保护恢复时不清除停车标志
```cpp
// 旧代码：
m_beltStopped.remove(beltNumber);

// 新代码：保留停车标志，仅在F键复位时清除
// m_beltStopped.remove(beltNumber);  // 注释掉
```
`resetAllProtections()`（F键复位）中已有 `m_beltStopped.clear()`，不受影响。

---

## 正确的保护停车流程

```
保护触发 → ProtectionLogicController检查m_beltStopped
  ├─ m_beltStopped[belt]=true → 忽略（已在停车中）
  └─ m_beltStopped[belt]=false → 设true → emergencyStopBelt()
       ├─ 停止序列已在执行 → 忽略（CommonControl防重入）
       └─ 启动序列在执行 → 取消启动 → 开始停止
            → 停止序列执行完成
            → F键复位 → m_beltStopped清除 → 可再次启动
```
