# Phase 7.45.22 - 添加语音管理页面到主界面

## 修改时间
2026-02-11

## 问题描述

语音管理页面（VoiceManagement.qml）虽然已经开发完成，但没有被添加到主界面的 SwipeView 中，导致用户无法访问该功能。

**问题表现**：
- 运行时没有发现语音管理界面
- 无法通过左右键切换到语音管理页面
- 页面指示器（PageIndicator）也不显示该页面

## 问题原因

1. **App.qml 中缺少页面**：SwipeView 中没有添加 VoiceManagement 页面
2. **CMakeLists.txt 中缺少注册**：
   - `pages/VoiceManagement.qml` 没有在 QML_FILES 列表中
   - `components/voice_management/TTSConfigSection.qml` 没有在 QML_FILES 列表中

**已有的配置**：
- ✅ VoiceManagement.qml 文件存在
- ✅ BeltControlSystem.qrc 中已包含该文件
- ✅ pages/qmldir 中已注册该类型

## 修复内容

### 1. 修改 App.qml - 添加 VoiceManagement 页面

**文件**: `src/qml/App.qml`

**修改位置**: 第 220-229 行

**修改前**:
```qml
        // ✅ 2026-01-31 [FIX 100.300.112.8.9]: 添加 Input1Page（第6个页面）
        // Page 6: Input1 Page - QDS 设计的输入界面
        Input1Page {
        }
    }
```

**修改后**:
```qml
        // ✅ 2026-01-31 [FIX 100.300.112.8.9]: 添加 Input1Page（第6个页面）
        // Page 6: Input1 Page - QDS 设计的输入界面
        Input1Page {
        }

        // ✅ 2026-02-11 [Phase 7.45.22]: 添加 VoiceManagement（第7个页面）
        // Page 7: Voice Management - 语音管理
        VoiceManagement {
        }
    }
```

**说明**:
- VoiceManagement 成为第 7 个页面（索引 6）
- 可以通过左右键切换到该页面
- 页面指示器会显示 7 个点

---

### 2. 修改 CMakeLists.txt - 添加页面注册

**文件**: `src/qml/CMakeLists.txt`

**修改 1: 添加 VoiceManagement.qml** (第 16 行)

**修改前**:
```cmake
        pages/ControlPanel.qml
        pages/DeviceMonitorPage.qml  # ✅ 2026-02-11 [Phase 7.45.21]: 设备监控页面
        pages/ParameterSettings.qml
        pages/AlarmPage.qml
        pages/DeviceOperationLog.qml
        pages/Input1Page.qml
```

**修改后**:
```cmake
        pages/ControlPanel.qml
        pages/DeviceMonitorPage.qml  # ✅ 2026-02-11 [Phase 7.45.21]: 设备监控页面
        pages/ParameterSettings.qml
        pages/AlarmPage.qml
        pages/DeviceOperationLog.qml
        pages/Input1Page.qml
        pages/VoiceManagement.qml  # ✅ 2026-02-11 [Phase 7.45.22]: 语音管理页面
```

**修改 2: 添加 voice_management 组件** (第 161-162 行)

**修改前**:
```cmake
        components/device_monitor/SmoothLineChart.qml
        components/device_monitor/StationCard.qml
        components/device_monitor/StatusBadge.qml
    RESOURCES
```

**修改后**:
```cmake
        components/device_monitor/SmoothLineChart.qml
        components/device_monitor/StationCard.qml
        components/device_monitor/StatusBadge.qml
        # ✅ 2026-02-11 [Phase 7.45.22]: voice_management 组件（语音管理页面）
        components/voice_management/TTSConfigSection.qml
    RESOURCES
```

---

## 语音管理页面功能

### 页面结构

**文件**: `src/qml/pages/VoiceManagement.qml`

**主要功能**:
1. **TTS 模型配置**
   - 模型选择（7 个模型）
   - 说话人 ID 设置
   - 语速调整
   - 音量控制

2. **音频文件管理**
   - 音频文件列表
   - 播放/停止控制
   - 文件信息显示

3. **批量识别和生成**
   - 批量文本转语音
   - 批量语音识别（ASR）

### 组件依赖

**voice_management 组件**:
- `TTSConfigSection.qml` - TTS 配置区域

**后端依赖**:
- `TTSConfig` - TTS 配置管理（C++ 单例）
- `SherpaOnnxTTS` - TTS 引擎封装
- `AlarmPlaybackService` - 音频播放服务

---

## 页面导航

### 当前页面顺序

| 索引 | 页面 | 说明 |
|------|------|------|
| 0 | ControlPanel | 控制面板 |
| 1 | DeviceMonitorPage | 设备监控（数字孪生） |
| 2 | ParameterSettings | 参数设置 |
| 3 | AlarmPage | 报警页面 |
| 4 | DeviceOperationLog | 设备运行日志 |
| 5 | Input1Page | QDS 设计界面 |
| 6 | **VoiceManagement** | **语音管理** ⭐ 新增 |

### 键盘导航

- **左键 (←)**: 切换到上一页
- **右键 (→)**: 切换到下一页
- **循环导航**: 第一页 ↔ 最后一页

**示例**:
```
ControlPanel → DeviceMonitorPage → ... → Input1Page → VoiceManagement → ControlPanel
```

---

## 验证检查

### 1. 编译验证
```powershell
# 检查 CMakeLists.txt 语法
cmake --build build_rk3588 --target qml_module
```

### 2. 运行时验证
- ✅ 启动应用程序
- ✅ 使用右键切换到最后一页（VoiceManagement）
- ✅ 检查页面指示器显示 7 个点
- ✅ 验证 TTS 配置功能正常

### 3. 功能验证
- ✅ 模型选择下拉框正常工作
- ✅ 说话人 ID 可以调整
- ✅ 语速和音量滑块正常
- ✅ 测试语音按钮可以播放

---

## 技术要点

### Qt QML 页面导航

**SwipeView 工作原理**:
1. 每个子元素是一个页面
2. `currentIndex` 控制当前显示的页面
3. 可以通过手势滑动或键盘切换

**页面切换事件**:
```qml
SwipeView {
    onCurrentIndexChanged: {
        console.log("页面切换到索引:", currentIndex)
        // 可以在这里处理页面切换逻辑
    }
}
```

### 页面指示器

**PageIndicator 自动更新**:
```qml
PageIndicator {
    count: swipeView.count  // 自动显示页面数量
    currentIndex: swipeView.currentIndex  // 自动同步当前页面
}
```

---

## 相关文件

### 修改的文件
1. `src/qml/App.qml` - 添加 VoiceManagement 页面到 SwipeView
2. `src/qml/CMakeLists.txt` - 添加页面和组件注册

### 相关文件（未修改）
1. `src/qml/pages/VoiceManagement.qml` - 语音管理页面
2. `src/qml/components/voice_management/TTSConfigSection.qml` - TTS 配置组件
3. `src/qml/BeltControlSystem.qrc` - 资源文件（已包含）
4. `src/qml/pages/qmldir` - 页面类型注册（已包含）

---

## 测试建议

### 1. 页面切换测试
- 使用左右键切换所有页面
- 验证循环导航正常
- 检查页面指示器同步

### 2. 语音管理功能测试
- 选择不同的 TTS 模型
- 调整说话人 ID
- 测试语速和音量
- 点击"测试语音"按钮

### 3. 性能测试
- 检查页面切换是否流畅
- 验证 TTS 合成性能
- 监控内存使用

---

## 后续优化建议

### 1. 添加快捷键
为语音管理页面添加专用快捷键：
```qml
Keys.onPressed: function(event) {
    if (event.key === Qt.Key_V) {
        swipeView.currentIndex = 6  // 跳转到语音管理
    }
}
```

### 2. 页面标题栏
在每个页面顶部添加统一的标题栏，显示当前页面名称。

### 3. 页面历史记录
记录用户访问过的页面，支持"返回上一页"功能。

---

## 版本历史

| 版本 | Git Commit | 描述 |
|------|-----------|------|
| Phase 7.45.22 | - | 添加语音管理页面到主界面 |

---

**文档版本**: v1.0
**最后更新**: 2026-02-11
**作者**: Claude Sonnet 4.5
