# Phase 7.48.88.36 - 统一运行失败音频文件名

## 修改时间
2026-03-27

## 问题描述

张紧控制反馈超时后，播放"运行失败"语音提示时，找不到音频文件。

**日志**：
```
⏰ CommonControl: 反馈超时 - "张紧控制"
❌ CommonControl: 反馈失败 - "张紧控制" 通道 0 仍为0
⚠️ CommonControl: TTS路径未找到运行失败音频，回退到默认路径
⚠️ CommonControl: 在以下位置均未找到运行失败音频
   尝试的文件名: "张紧控制运行失败.mp3, 张紧控制运行失败.wav"
```

## 根因

`CommonControl::getDeviceFailureAudioPath()` 用 `deviceName + "运行失败"` 构造文件名，
但 `BatchAudioGenerator` 用不同的短名模板生成文件，两边命名规则不一致：

| 设备 | CommonControl 查找 | BatchAudioGenerator 生成 |
|-----|-------------------|------------------------|
| 张紧控制 | `张紧控制运行失败.wav` | `1号张紧运行失败.wav` |
| 1号电机 | `1号电机运行失败.wav` | `电机1失败.wav` |
| 1号制动器 | `1号制动器运行失败.wav` | `制动器1松闸失败.wav` |

## 修复方案

### 统一标准：`{deviceName}运行失败.wav`

以 CommonControl 的 `deviceName + "运行失败"` 为标准命名规则。

### BatchAudioGenerator.cpp 修改

| 设备类型 | 旧文件名模板 | 新文件名模板 |
|---------|------------|------------|
| 电机 | `电机%1失败.wav` | `%1号电机运行失败.wav` |
| 制动器 | 无通用运行失败 | 新增 `%1号制动器运行失败.wav` |
| 张紧 | `%2号张紧运行失败.wav` | `张紧控制运行失败.wav` |

### CommonControl.cpp 修改

移除旧的"抱闸"特殊处理，所有设备统一使用 `deviceName + "运行失败"` 格式。
同时添加旧文件名的向后兼容搜索，确保设备上已存在的旧文件仍可被找到。

## 修改文件

| 文件 | 修改内容 |
|------|---------|
| `src/control/BatchAudioGenerator.cpp` | 电机/制动器/张紧运行失败文件名模板统一 |
| `src/control/CommonControl.cpp` | getDeviceFailureAudioPath() 统一命名 + 旧文件名兼容 |

## 注意事项

修改后需要在设备上**重新执行批量TTS生成**，才能生成新命名的音频文件。
在重新生成之前，CommonControl 会尝试兼容搜索旧文件名。
