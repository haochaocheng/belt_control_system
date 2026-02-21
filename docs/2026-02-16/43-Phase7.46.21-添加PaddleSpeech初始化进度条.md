# Phase7.46.21 - 添加PaddleSpeech初始化进度条

**日期**: 2026-02-16
**阶段**: Phase 7.46.21
**状态**: ✅ 已完成

---

## 📋 问题描述

### 现象

**用户反馈**：
```
添加倒计时进度条，这样能看到进度，否则以为死机状态
```

**症状**：
- ✅ PaddleSpeech 初始化超时已修复（Phase 7.46.20）
- ✅ 超时时间增加到 10 分钟
- ❌ 用户在等待 5-10 分钟时，看不到任何进度
- ❌ 用户以为程序死机或卡住

---

## 🔍 根本原因

### 问题分析

**PaddleSpeech 初始化流程**：
1. 启动 Python 服务进程
2. 发送初始化命令
3. Python 加载 PaddleSpeech 模型（**5-10 分钟**）
4. 返回初始化结果

**用户体验问题**：
- 在步骤 3 期间，界面没有任何反馈
- 用户不知道程序是在工作还是死机
- 只能等待，无法判断进度

**现有日志**（修复前）：
```
[DEBUG] 🔧 [PaddleSpeech] 初始化 - 模型: "/home/pi/belt-control-data/models/tts_models/paddlespeech/fastspeech2_csmsc"
[DEBUG] 🚀 [PaddleSpeech] 启动服务: "/app/tts_engines/paddlespeech/paddle_tts_service.py"
[DEBUG] ✅ [PaddleSpeech] 服务启动成功
[DEBUG] 📤 [PaddleSpeech] 发送命令: "initialize"
... （等待 5-10 分钟，没有任何输出）...
[DEBUG] ✅ [PaddleSpeech] 初始化成功
```

---

## 🛠️ 修复方案

### 策略：添加定时器更新进度

在 `initialize()` 方法中添加 QTimer，每 10 秒更新一次进度信息。

### 修改：PaddleSpeechAdapter.cpp

**文件**: `src/control/tts/PaddleSpeechAdapter.cpp`

**位置**: `initialize()` 方法（第 71-105 行）

**修改内容**：

```cpp
bool PaddleSpeechAdapter::initialize(const QString &modelPath)
{
    // ... 启动服务 ...

    // 发送初始化命令
    QJsonObject command;
    command["command"] = "initialize";
    command["model"] = modelPath;

    emit initializationProgress("正在加载 PaddleSpeech 模型...");

    // ✅ 2026-02-16 06:20: 添加进度更新定时器
    // 原因：初始化需要 5-10 分钟，用户需要看到进度避免以为死机
    // 效果：每 10 秒更新一次进度百分比
    QTimer progressTimer;
    int elapsedSeconds = 0;
    const int totalSeconds = 600;  // 10 分钟

    connect(&progressTimer, &QTimer::timeout, [&]() {
        elapsedSeconds += 10;
        int progress = (elapsedSeconds * 100) / totalSeconds;
        if (progress > 95) progress = 95;  // 最多显示 95%，等待实际完成

        QString progressMsg = QString("正在加载 PaddleSpeech 模型... %1% (%2/%3 秒)")
                                .arg(progress)
                                .arg(elapsedSeconds)
                                .arg(totalSeconds);
        emit initializationProgress(progressMsg);
        qDebug() << "⏳ [PaddleSpeech]" << progressMsg;
    });

    progressTimer.start(10000);  // 每 10 秒触发一次

    QJsonObject response;
    if (!sendCommand(command, response, 600000)) {  // 10分钟超时
        progressTimer.stop();
        qWarning() << "❌ [PaddleSpeech] 初始化命令失败";
        emit errorOccurred("初始化命令失败");
        stopService();
        return false;
    }

    progressTimer.stop();

    if (response["status"].toString() != "success") {
        QString error = response["error"].toString();
        qWarning() << "❌ [PaddleSpeech] 初始化失败:" << error;
        emit errorOccurred(error);
        stopService();
        return false;
    }

    m_isInitialized = true;
    qDebug() << "✅ [PaddleSpeech] 初始化成功";
    emit initializationProgress("PaddleSpeech 初始化完成");

    return true;
}
```

**说明**：
1. **QTimer 定时器**：每 10 秒触发一次
2. **进度计算**：`(已用时间 / 总时间) * 100`
3. **进度上限**：最多显示 95%，等待实际完成后显示 100%
4. **进度消息**：格式为 "正在加载 PaddleSpeech 模型... 16% (160/600 秒)"
5. **信号发射**：通过 `initializationProgress` 信号通知 QML 界面
6. **日志输出**：同时输出到控制台日志
7. **定时器停止**：初始化完成或失败后停止定时器

---

## 📊 修复前后对比

### 修复前

**用户体验**：
```
[DEBUG] 📤 [PaddleSpeech] 发送命令: "initialize"
... （等待 5-10 分钟，界面无响应）...
[DEBUG] ✅ [PaddleSpeech] 初始化成功
```

**问题**：
- ❌ 用户看不到任何进度
- ❌ 不知道程序是否在工作
- ❌ 以为程序死机

### 修复后

**预期用户体验**：
```
[DEBUG] 📤 [PaddleSpeech] 发送命令: "initialize"
[DEBUG] ⏳ [PaddleSpeech] 正在加载 PaddleSpeech 模型... 1% (10/600 秒)
[DEBUG] ⏳ [PaddleSpeech] 正在加载 PaddleSpeech 模型... 3% (20/600 秒)
[DEBUG] ⏳ [PaddleSpeech] 正在加载 PaddleSpeech 模型... 5% (30/600 秒)
...
[DEBUG] ⏳ [PaddleSpeech] 正在加载 PaddleSpeech 模型... 26% (160/600 秒)
...
[DEBUG] ⏳ [PaddleSpeech] 正在加载 PaddleSpeech 模型... 95% (570/600 秒)
[DEBUG] ✅ [PaddleSpeech] 初始化成功
[DEBUG] PaddleSpeech 初始化完成
```

**效果**：
- ✅ 用户每 10 秒看到一次进度更新
- ✅ 知道程序正在工作
- ✅ 可以估算剩余时间
- ✅ 不会以为程序死机

---

## 🎯 进度显示示例

### 时间线

| 时间 | 进度 | 显示消息 |
|------|------|----------|
| 0 秒 | 0% | 正在加载 PaddleSpeech 模型... |
| 10 秒 | 1% | 正在加载 PaddleSpeech 模型... 1% (10/600 秒) |
| 20 秒 | 3% | 正在加载 PaddleSpeech 模型... 3% (20/600 秒) |
| 30 秒 | 5% | 正在加载 PaddleSpeech 模型... 5% (30/600 秒) |
| 60 秒 | 10% | 正在加载 PaddleSpeech 模型... 10% (60/600 秒) |
| 120 秒 | 20% | 正在加载 PaddleSpeech 模型... 20% (120/600 秒) |
| 180 秒 | 30% | 正在加载 PaddleSpeech 模型... 30% (180/600 秒) |
| 300 秒 | 50% | 正在加载 PaddleSpeech 模型... 50% (300/600 秒) |
| 420 秒 | 70% | 正在加载 PaddleSpeech 模型... 70% (420/600 秒) |
| 540 秒 | 90% | 正在加载 PaddleSpeech 模型... 90% (540/600 秒) |
| 570 秒 | 95% | 正在加载 PaddleSpeech 模型... 95% (570/600 秒) |
| 完成 | 100% | PaddleSpeech 初始化完成 |

---

## 🚀 部署流程

### 步骤1：重新构建应用镜像

```powershell
.\build-ubuntu24-apt.ps1 186
```

**预计时间**：~3 分钟（基础镜像已构建）

### 步骤2：测试 PaddleSpeech 引擎

**操作**：
1. 启动应用程序
2. 打开 TTS 配置界面
3. 切换到 PaddleSpeech 引擎
4. 选择模型
5. 点击"测试"按钮

**观察进度**：
- ✅ 界面显示进度条或进度文本
- ✅ 每 10 秒更新一次进度
- ✅ 显示百分比和已用时间
- ✅ 初始化完成后显示"初始化完成"

**查看日志**：
```bash
ssh pi@192.168.10.186 "docker logs -f belt-control-app | grep -E 'PaddleSpeech|⏳'"
```

**预期日志**：
```
[DEBUG] 🔧 [PaddleSpeech] 初始化 - 模型: "/home/pi/belt-control-data/models/tts_models/paddlespeech/fastspeech2_csmsc"
[DEBUG] 🚀 [PaddleSpeech] 启动服务: "/app/tts_engines/paddlespeech/paddle_tts_service.py"
[DEBUG] ✅ [PaddleSpeech] 服务启动成功
[DEBUG] 📤 [PaddleSpeech] 发送命令: "initialize"
[DEBUG] ⏳ [PaddleSpeech] 正在加载 PaddleSpeech 模型... 1% (10/600 秒)
[DEBUG] ⏳ [PaddleSpeech] 正在加载 PaddleSpeech 模型... 3% (20/600 秒)
...
[DEBUG] ✅ [PaddleSpeech] 初始化成功
```

---

## 📝 相关文档

1. [42-Phase7.46.19-修复PaddleSpeech响应读取冲突问题.md](42-Phase7.46.19-修复PaddleSpeech响应读取冲突问题.md) - 响应读取修复
2. [41-Phase7.46.18-将Python依赖移到基础镜像并修复numpy版本问题.md](41-Phase7.46.18-将Python依赖移到基础镜像并修复numpy版本问题.md) - Python 依赖优化
3. [40-Phase7.46.17-修复MeloTTS依赖安装失败问题.md](40-Phase7.46.17-修复MeloTTS依赖安装失败问题.md) - MeloTTS 问题

---

## ✅ Git提交记录

**提交**: Phase 7.46.21 - 添加PaddleSpeech初始化进度条

**修改文件**：
- `src/control/tts/PaddleSpeechAdapter.cpp` - 添加进度定时器
- `docs/2026-02-16/43-Phase7.46.21-添加PaddleSpeech初始化进度条.md` - 修复总结文档

**提交信息**：
```
feat: Phase 7.46.21 - 添加PaddleSpeech初始化进度条

- 添加QTimer每10秒更新一次进度
- 显示百分比和已用时间/总时间
- 避免用户以为程序死机
- 进度最多显示95%，等待实际完成
```

---

## 🎯 TTS 引擎状态

### 当前可用性

| 引擎名称 | 注册状态 | 依赖安装 | 响应读取 | 超时时间 | 进度显示 | 可用性 |
|---------|---------|---------|---------|---------|---------|--------|
| Sherpa-ONNX | ✅ 已注册 | ✅ C++实现 | ✅ 正常 | N/A | N/A | ✅ 可用 |
| PaddleSpeech | ✅ 已注册 | ✅ 已安装 | ✅ 已修复 | ✅ 10分钟 | ✅ 已添加 | ⏳ 待测试 |
| MeloTTS | ✅ 已注册 | ❌ 未安装 | ✅ 正常 | N/A | N/A | ❌ 不可用 |
| Coqui TTS | ❌ 未注册 | ❌ 未安装 | ❌ 未实现 | N/A | N/A | ❌ 不可用 |
| Piper TTS | ❌ 未注册 | ❌ 未安装 | ❌ 未实现 | N/A | N/A | ❌ 不可用 |

---

## 💡 设计亮点

### 1. 用户体验优化

**问题**：长时间等待无反馈
**解决**：实时进度更新

**效果**：
- 用户知道程序在工作
- 可以估算剩余时间
- 不会误以为死机

### 2. 进度上限设计

**为什么限制在 95%？**
- 避免进度条到 100% 后还在等待
- 实际完成时才显示 100%
- 更符合用户预期

### 3. 更新频率选择

**为什么选择 10 秒？**
- 太快（如 1 秒）：日志刷屏，影响性能
- 太慢（如 30 秒）：用户等待焦虑
- 10 秒：平衡用户体验和系统开销

### 4. 信号机制

**为什么使用信号？**
- 解耦 C++ 后端和 QML 前端
- 支持异步更新
- 便于扩展（如进度条、通知等）

---

## 🔍 技术细节

### QTimer 使用

**创建定时器**：
```cpp
QTimer progressTimer;
```

**连接槽函数**：
```cpp
connect(&progressTimer, &QTimer::timeout, [&]() {
    // 更新进度
});
```

**启动定时器**：
```cpp
progressTimer.start(10000);  // 10 秒
```

**停止定时器**：
```cpp
progressTimer.stop();
```

### Lambda 捕获

**捕获外部变量**：
```cpp
int elapsedSeconds = 0;
const int totalSeconds = 600;

connect(&progressTimer, &QTimer::timeout, [&]() {
    elapsedSeconds += 10;  // 修改外部变量
    // ...
});
```

**注意**：使用 `[&]` 捕获所有外部变量的引用

### 信号发射

**发射进度信号**：
```cpp
emit initializationProgress(progressMsg);
```

**QML 接收**：
```qml
Connections {
    target: ttsEngineManager
    onInitializationProgress: {
        progressText.text = message
    }
}
```

---

## ⚠️ 注意事项

### 1. 定时器生命周期

**问题**：定时器必须在 `sendCommand()` 返回前停止
**原因**：定时器是栈变量，函数返回后会销毁
**解决**：在所有返回路径前调用 `progressTimer.stop()`

### 2. 进度准确性

**问题**：进度是估算的，不是实际进度
**原因**：无法获取 Python 模型加载的真实进度
**解决**：使用时间估算，并限制最大进度为 95%

### 3. 多次初始化

**问题**：如果用户多次点击"测试"按钮
**原因**：每次都会创建新的定时器
**解决**：在 `initialize()` 开始时检查 `m_isInitialized`

---

**完成时间**: 2026-02-16 06:30
**下次测试**: 重新构建镜像后测试进度显示

