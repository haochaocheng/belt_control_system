# Phase 7.48.88.33 - 停车预警与故障弹窗修复

## 修改时间
2026-03-27

## 修复内容

### 问题1：起车预警中按停止无停车预警音频

**现象**：按2号键启动皮带，在起车预警播放期间再按2号键停止，只是静默取消预警，没有播放停车预警音频。

**根因**：Phase 7.48.88.32 的 Branch A（起车预警中断）直接调用 `stopWarningPlayback()` 后 return，未播放停车音频。

**修复**：
- Branch A 中断起车预警后，获取停车音频路径并播放
- 设置 `m_isStopAudioPlaying = true`，让 UI 显示"停车预警"阶段
- 在 `onPlaybackFinished` 中增加判断：如果 `m_beltRunning` 为 false（设备未激活），跳过 `stopDeviceSequence`
- 停车音频播放完成后直接标记为"停止"状态

### 问题2：设备故障警告显示默认名称

**现象**：故障弹窗显示"2号皮带 跑偏"，但设备已在基本配置中更名为"1108顺槽皮带"。

**根因**：`ProtectionLogicController::executeProtectionAction` 中硬编码 `QString("%1号皮带 %2").arg(beltNumber).arg(protectionName)`。

**修复**：改用 `m_deviceRoleManager->localDeviceName()` 获取自定义设备名称，回退到默认名称格式。

### 问题3：故障弹窗只显示第一个故障

**现象**：实际有跑偏和急停两个故障，但弹窗只显示跑偏。

**根因**：
1. 跑偏先触发 → 设置 `m_beltStopped[beltNumber] = true` → 记录故障 "跑偏"
2. 急停后触发 → `m_beltStopped` 已为 true → 直接 `return` → **跳过了 `onDeviceFault()` 调用**

**修复**：在 `m_beltStopped` 检查的 `return` 前，仍然调用 `m_runtimeTracker->onDeviceFault()` 记录故障。停车命令可以忽略重复，但故障记录不能忽略。

## 修改文件

| 文件 | 修改内容 |
|------|----------|
| `src/control/CommonControl.cpp` | stopBelt Branch A 增加播放停车音频；onPlaybackFinished 增加设备未激活判断 |
| `src/control/ProtectionLogicController.cpp` | 故障描述使用自定义名称；重复停车仍记录故障 |

## 状态机变化

```
旧：起车预警 → [按停止] → 静默取消 → 停止（无音频反馈）
新：起车预警 → [按停止] → 中断预警 → 播放停车预警音频 → 停止

旧：跑偏触发 → 记录"2号皮带 跑偏" → 急停触发 → 忽略（不记录）
新：跑偏触发 → 记录"1108顺槽皮带 跑偏" → 急停触发 → 忽略停车但记录"1108顺槽皮带 急停"
```
