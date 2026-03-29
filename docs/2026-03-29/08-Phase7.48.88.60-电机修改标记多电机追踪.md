# Phase 7.48.88.60 - 电机修改标记改为多电机追踪

## 修改日期
2026-03-29

## 问题描述
在5号电机配置界面修改了运行状态后，电机列表5号电机左侧会出现黄色●标记，表示配置已修改未保存。但当切换到4号电机时，5号电机的●标记消失了。

**期望行为**：类似 VSCode / 文本编辑器的多文件修改标记机制——修改某个文件后文件名旁会出现圆点标记，即使切换到其他文件，标记也不会消失，直到保存后才清除。

## 根因分析
原实现使用单个 `modifiedMotorIndex: -1`（int类型）追踪修改状态，同一时间只能记录一个电机的修改。切换电机时 `onMotorListIndexChanged` 直接将其设为 -1，导致所有修改标记丢失。

## 修改方案
将单值追踪改为数组追踪，支持多电机同时显示修改标记。

| 对比项 | 旧实现 | 新实现 |
|--------|--------|--------|
| 数据结构 | `property int modifiedMotorIndex: -1` | `property var modifiedMotorIndices: []` |
| 切换电机 | 清除标记 (`= -1`) | 不清除，保留所有已修改电机标记 |
| 修改参数 | 直接覆盖 `= currentMotorIndex` | 数组 `push(idx)` |
| 保存配置 | 全部清零 `= -1` | 仅 `splice` 移除当前已保存电机 |
| 显示判断 | `modifiedMotorIndex === index` | `modifiedMotorIndices.indexOf(index) >= 0` |

## 修改的文件

### 1. `src/qml/components/device_info/pages/MotorControlPage.qml`
- 属性声明：`modifiedMotorIndex`(int) → `modifiedMotorIndices`(var数组)
- `onMotorListIndexChanged`：移除 `modifiedMotorIndex = -1`，切换电机不清除标记
- `configModifiedStateChanged` 信号处理：改为数组 add/remove 操作
- `saveMotorConfig` 保存成功后：改为从数组中移除当前电机索引
- MyMotorListPanel 绑定：`modifiedMotorIndex` → `modifiedMotorIndices`

### 2. `src/qml/components/device_info/pages/MyMotorListPanel.qml`
- 属性声明：`modifiedMotorIndex`(int) → `modifiedMotorIndices`(var数组)
- 黄色●标记 visible 判断：`=== index` → `indexOf(index) >= 0`

## 测试要点
1. 修改5号电机参数 → 5号出现黄色●
2. 切换到4号电机 → 5号黄色●仍然存在
3. 修改4号电机参数 → 4号也出现黄色●，5号●仍在
4. 保存4号电机 → 4号●消失，5号●仍在
5. 切换回5号并保存 → 5号●消失
