# Phase 7.48.88.64 - 通道冲突释放时机修复

## 修改日期
2026-03-29

## 问题描述
2号电机配置界面修改输出通道为3（被3号电机��用），系统立即将3号电机通道释放为-1并保存到数据库。但如果2号电机最终放弃修改，3号电机的通道已经被错误释放了。

**期望行为**：修改通道时只提示冲突，等实际保存时才释放被占用通道。放弃修改则不影响其他电机。

## 根因分析
原实现在 `onValueChanged`（SpinBox值变化时）就立即执行通道冲突释放：
1. BasicConfigTab `onValueChanged` → 触发 `requestOutputChannelConflictCheck` 信号
2. MotorControlPage `handleOutputChannelConflict` 直接修改数据库，将被占用电机通道设为-1
3. 用户还没保存，其他电机的通道就已经被改了

## 修复方案

| 时机 | 旧行为 | 新行为 |
|------|--------|--------|
| 修改通道值时 | 立即释放被占用通道并保存DB | 仅显示提示"保存后将自动释放" |
| 保存配置时 | 无特殊处理 | 调用 `releaseConflictingChannels` 释放冲突通道 |
| 放弃修改时 | 被占用通道已被错误释放 | 不影响其他电机 |

## 修改的文件

### 1. `src/qml/components/device_info/pages/BasicConfigTab.qml`
- `onValueChanged`：添加注释说明只提示不释放

### 2. `src/qml/components/device_info/pages/MotorControlPage.qml`
- `handleOutputChannelConflict()`：移除数据库写入，改为仅显示提示信息
- 新增 `releaseConflictingChannels(savedMotorIdx, savedChannel)`：保存时释放冲突通道
- `saveMotorConfig()`：保存成功后调用 `releaseConflictingChannels`
- 修复 `root.focusTabIndex === 0` 判断改为 `actualTabIndex === 0`（延续 Phase 7.48.88.63 修复）

## 测试要点
1. 修改2号电机通道为3（被3号占用）→ 显示提示"保存后将自动释放"
2. 不保存，切换到3号电机 → 3号电机通道仍为3（未被释放）
3. 返回2号电机，保存 → 3号电机通道变为-1
4. 修改通道后放弃 → 其他电机通道不受影响
