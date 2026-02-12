# Phase 7.45.24 - 注册 com.belt.control 模块修复 VoiceManagement 启动失败

## 修改时间
2026-02-11

## 问题描述

这是**第四次修复**启动失败问题。

### 错误信息

```
[WARNING] qrc:/qt/qml/BeltControlQml/App.qml:227:9: Type VoiceManagement unavailable
[WARNING] qrc:/qt/qml/BeltControlQml/pages/VoiceManagement.qml:5:1: module "com.belt.control" is not installed
ERROR: No root objects loaded!
```

## 问题原因

VoiceManagement.qml 第 5 行导入了 `com.belt.control` 模块：

```qml
import com.belt.control 1.0  // ✅ 2026-01-23 11:00 [FIX 100.299] 导入 TTSConfig 单例
```

但是：
1. ❌ `com.belt.control` 模块没有在 main.cpp 中注册
2. ❌ TTSConfigManager 单例没有暴露给 QML

### 为什么会出现这个问题？

**VoiceManagement 页面是后来添加的**（2026-01-23），但：
- 开发时可能在测试环境中手动注册了模块
- 或者使用了其他方式访问 TTSConfig
- 部署时忘记在 main.cpp 中添加注册代码

---

## 修复内容

### 1. 添加 TTSConfigManager 头文件

**文件**: `src/main/main.cpp`

**修改位置**: 第 28-30 行

**修改前**:
```cpp
#include "control/DeviceRoleManager.h"  // ✅ 2026-02-10 [Phase 7.45]: 添加设备角色管理器头文件
#include "control/SerialPortController.h"  // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.1]: 添加串口控制器头文件
```

**修改后**:
```cpp
#include "control/DeviceRoleManager.h"  // ✅ 2026-02-10 [Phase 7.45]: 添加设备角色管理器头文件
#include "control/TTSConfigManager.h"  // ✅ 2026-02-11 [Phase 7.45.24]: 添加TTS配置管理器头文件
#include "control/SerialPortController.h"  // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.1]: 添加串口控制器头文件
```

---

### 2. 注册 TTSConfigManager 单例到 QML

**文件**: `src/main/main.cpp`

**修改位置**: 第 109-117 行（在 SipPhoneManager 注册之后）

**添加代码**:
```cpp
// ✅ 2026-02-11 [Phase 7.45.24]: 注册 TTSConfigManager 单例到 QML
logMessage("Registering TTSConfigManager...");
qmlRegisterSingletonType<TTSConfigManager>("com.belt.control", 1, 0, "TTSConfig",
    [](QQmlEngine *engine, QJSEngine *scriptEngine) -> QObject * {
        Q_UNUSED(engine)
        Q_UNUSED(scriptEngine)
        return TTSConfigManager::instance();
    });
logMessage("TTSConfigManager registered to QML");
```

**说明**:
- 注册为单例类型（qmlRegisterSingletonType）
- 模块名称: `com.belt.control`
- 版本: 1.0
- QML 中的名称: `TTSConfig`
- 使用 lambda 函数返回单例实例

---

## TTSConfigManager 详细信息

### 类定义

**文件**: `src/control/TTSConfigManager.h`

**主要功能**:
```cpp
class TTSConfigManager : public QObject
{
    Q_OBJECT

public:
    // 场景枚举
    enum Scene {
        StartupWarning = 0,  // 起车预警
        FaultAlarm = 1,      // 故障报警
        Test = 2             // 测试
    };
    Q_ENUM(Scene)

    // 单例模式
    static TTSConfigManager* instance();

    // 配置管理
    int modelIndex(Scene scene) const;
    void setModelIndex(Scene scene, int index);
    QString modelPath(Scene scene) const;
    void setModelPath(Scene scene, const QString &path);
    int speakerId(Scene scene) const;
    void setSpeakerId(Scene scene, int id);
    double rate(Scene scene) const;
    void setRate(Scene scene, double rate);
    double volume(Scene scene) const;
    void setVolume(Scene scene, double volume);

signals:
    void configChanged(Scene scene);
};
```

---

### 在 QML 中的使用

**VoiceManagement.qml** (第 5 行):
```qml
import com.belt.control 1.0  // 导入模块

// 使用 TTSConfig 单例
Text {
    text: "当前模型: " + TTSConfig.modelPath(TTSConfig.Test)
}

Button {
    onClicked: {
        TTSConfig.setModelIndex(TTSConfig.Test, 2)
    }
}
```

**TTSConfigSection.qml**:
```qml
import com.belt.control 1.0

ComboBox {
    currentIndex: TTSConfig.modelIndex(TTSConfig.Test)
    onCurrentIndexChanged: {
        TTSConfig.setModelIndex(TTSConfig.Test, currentIndex)
    }
}
```

---

## Qt QML 模块注册机制

### qmlRegisterSingletonType 详解

**语法**:
```cpp
qmlRegisterSingletonType<T>(
    const char *uri,           // 模块URI
    int versionMajor,          // 主版本号
    int versionMinor,          // 次版本号
    const char *qmlName,       // QML中的类型名
    QObject* (*callback)(...)  // 创建实例的回调函数
);
```

**示例**:
```cpp
qmlRegisterSingletonType<TTSConfigManager>(
    "com.belt.control",  // URI
    1,                   // 主版本
    0,                   // 次版本
    "TTSConfig",         // QML名称
    [](QQmlEngine *engine, QJSEngine *scriptEngine) -> QObject * {
        return TTSConfigManager::instance();  // 返回单例实例
    }
);
```

**QML 中使用**:
```qml
import com.belt.control 1.0  // 导入模块

Item {
    Component.onCompleted: {
        console.log(TTSConfig.modelPath(TTSConfig.Test))  // 直接使用，无需实例化
    }
}
```

---

### 单例 vs 普通类型

| 特性 | 单例 (Singleton) | 普通类型 (Type) |
|------|-----------------|----------------|
| **注册函数** | qmlRegisterSingletonType | qmlRegisterType |
| **实例化** | 自动，全局唯一 | 手动，可多个实例 |
| **QML 使用** | 直接使用类名 | 需要创建实例 |
| **内存** | 单一实例 | 每次创建新实例 |
| **适用场景** | 配置管理、全局状态 | UI 组件、数据模型 |

**单例示例**:
```qml
import com.belt.control 1.0

Text {
    text: TTSConfig.modelPath(TTSConfig.Test)  // 直接使用
}
```

**普通类型示例**:
```qml
import com.belt.control 1.0

MyType {  // 需要实例化
    id: myInstance
    property string value: "test"
}
```

---

## 完整的错误修复历史

### Phase 7.45.21 - device_monitor 组件缺失
**错误**: `"../components/device_monitor": no such directory`
**修复**: 添加 10 个 device_monitor 组件到 CMakeLists.txt

### Phase 7.45.22 - VoiceManagement 页面缺失
**错误**: `Type VoiceManagement unavailable`
**修复**: 添加 VoiceManagement 到 App.qml 和 CMakeLists.txt

### Phase 7.45.23 - theme 模块缺失
**错误**: `AnimatedCounter is not a type`
**修复**:
- DeviceMonitorPage.qml 添加 `import "../theme"`
- CMakeLists.txt 添加 3 个 theme 组件

### Phase 7.45.24 - com.belt.control 模块未注册（本次）
**错误**: `module "com.belt.control" is not installed`
**修复**:
- main.cpp 添加 TTSConfigManager 头文件
- main.cpp 注册 TTSConfigManager 单例到 QML

---

## 根本原因分析

### 为什么会连续出现四次错误？

**问题根源**: **增量开发 + 不完整的依赖检查 + 缺少自动化验证**

1. **DeviceMonitorPage 创建时**（2026-02-10）:
   - 使用了多个模块的组件
   - 没有完整检查所有依赖
   - 没有验证所有 import 语句

2. **VoiceManagement 创建时**（2026-01-23）:
   - 使用了 C++ 单例 TTSConfig
   - 可能在测试环境中手动注册
   - 部署时忘记添加注册代码

3. **修复过程中**:
   - 只修复当前错误
   - 没有检查相关文件的完整依赖
   - 没有运行完整的启动测试

---

### 如何彻底避免类似问题？

#### 1. 创建依赖检查清单

**新建 QML 页面时**:
- [ ] 列出所有 import 语句
- [ ] 检查每个 import 的模块是否在 CMakeLists.txt 中
- [ ] 检查每个使用的组件是否在 qmldir 中
- [ ] 检查 C++ 类型是否在 main.cpp 中注册
- [ ] 运行完整的启动测试

**新建 C++ 单例时**:
- [ ] 在 main.cpp 中添加头文件
- [ ] 使用 qmlRegisterSingletonType 注册
- [ ] 在 QML 中测试导入和使用
- [ ] 添加日志输出确认注册成功

#### 2. 创建自动化检查脚本

**scripts/check-qml-dependencies.ps1**:
```powershell
# 检查所有 QML 文件的 import 语句
# 验证所有导入的模块都在 CMakeLists.txt 中
# 检查所有 C++ 类型是否注册

$qmlFiles = Get-ChildItem -Path "src/qml" -Filter "*.qml" -Recurse

foreach ($file in $qmlFiles) {
    $content = Get-Content $file.FullName
    $imports = $content | Select-String -Pattern "^import\s+(.+)"

    foreach ($import in $imports) {
        # 检查模块是否存在
        # 检查是否在 CMakeLists.txt 中
        # 检查 C++ 模块是否在 main.cpp 中注册
    }
}
```

#### 3. 添加 CI/CD 检查

**.github/workflows/qml-check.yml**:
```yaml
name: QML Dependency Check

on: [push, pull_request]

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Check QML Dependencies
        run: .\scripts\check-qml-dependencies.ps1
      - name: Build and Test
        run: .\build-ubuntu24-apt.ps1 test
```

#### 4. 文档化 QML 模块结构

**docs/QML模块结构.md**:
```markdown
# QML 模块结构

## C++ 注册的模块

### com.belt.control
- **TTSConfig** (单例) - TTS配置管理
- 注册位置: src/main/main.cpp:111

### BeltControl.SipPhone
- **SipPhoneManager** - SIP电话管理
- 注册位置: src/sip_phone/SipPhoneManager.cpp

## QML 模块

### device_monitor
- 位置: src/qml/components/device_monitor/
- 组件: BeltConnectionDiagram, DeviceStatusCard, ...

### theme
- 位置: src/qml/theme/
- 组件: Theme (单例), AnimatedCounter, CircularProgress
```

---

## 验证检查

### 1. 编译验证
```bash
# 检查编译是否成功
cmake --build build_rk3588
```

### 2. 运行时验证
```bash
# 启动应用程序
docker logs -f belt-control-rk3588

# 检查日志中是否有：
# "Registering TTSConfigManager..."
# "TTSConfigManager registered to QML"
```

### 3. 功能验证
- ✅ 启动应用程序
- ✅ 切换到 VoiceManagement 页面（索引 6）
- ✅ 检查 TTS 配置功能正常
- ✅ 验证模型选择、说话人ID等功能

---

## 相关文件

### 修改的文件
1. `src/main/main.cpp` - 添加 TTSConfigManager 头文件和注册
2. `src/qml/App.qml` - 恢复 VoiceManagement 页面（之前被注释）

### 相关文件（未修改）
1. `src/control/TTSConfigManager.h` - TTS配置管理器头文件
2. `src/control/TTSConfigManager.cpp` - TTS配置管理器实现
3. `src/qml/pages/VoiceManagement.qml` - 语音管理页面
4. `src/qml/components/voice_management/TTSConfigSection.qml` - TTS配置组件

---

## 测试建议

### 1. 完整启动测试
```powershell
# 编译并部署
.\build-ubuntu24-apt.ps1 188

# 在设备上运行
ssh linaro@192.168.10.188
docker logs -f belt-control-rk3588
```

### 2. VoiceManagement 功能测试
- 切换到语音管理页面
- 选择不同的 TTS 模型
- 调整说话人 ID
- 测试语速和音量
- 点击"测试语音"按钮

### 3. TTSConfig 单例测试
```qml
// 在 QML 中测试
Component.onCompleted: {
    console.log("Model Index:", TTSConfig.modelIndex(TTSConfig.Test))
    console.log("Speaker ID:", TTSConfig.speakerId(TTSConfig.Test))
    console.log("Rate:", TTSConfig.rate(TTSConfig.Test))
}
```

---

## 后续优化建议

### 1. 统一模块注册位置
创建专门的模块注册函数：

**src/main/qml_registration.cpp**:
```cpp
void registerQmlTypes() {
    // 注册所有 C++ 类型到 QML
    qmlRegisterSingletonType<TTSConfigManager>("com.belt.control", 1, 0, "TTSConfig", ...);
    // 其他注册...
}
```

### 2. 添加注册验证
```cpp
void verifyQmlRegistration() {
    // 验证所有必需的类型都已注册
    QQmlEngine engine;
    QQmlComponent component(&engine);
    component.setData("import com.belt.control 1.0\nItem {}", QUrl());
    if (component.isError()) {
        qFatal("QML registration verification failed");
    }
}
```

### 3. 文档化注册流程
在开发文档中明确说明：
- 如何注册新的 C++ 类型到 QML
- 单例 vs 普通类型的选择
- 模块命名规范

---

## 版本历史

| 版本 | Git Commit | 描述 |
|------|-----------|------|
| Phase 7.45.21 | - | 修复 device_monitor 组件缺失 |
| Phase 7.45.22 | - | 添加 VoiceManagement 页面 |
| Phase 7.45.23 | - | 修复 theme 模块缺失 |
| Phase 7.45.24 | - | 注册 com.belt.control 模块 |

---

**文档版本**: v1.0
**最后更新**: 2026-02-11
**作者**: Claude Sonnet 4.5
