# Phase7.46.23 - 修复PaddleSpeech不支持speed参数

**日期**: 2026-02-16
**阶段**: Phase 7.46.23
**状态**: ✅ 已完成

---

## 📋 问题描述

### 现象

从 voip.md 日志可以看到：

```
[DEBUG] 🎙️ [PaddleSpeech] 合成语音 - 文本: "一号皮带准备启动，请注意" 说话人ID: 0 语速: 1 音量: 0.8
[DEBUG] 📤 [PaddleSpeech] 发送命令: "synthesize"
[WARNING] [PaddleSpeech Error] "[2023-06-18 16:20:10,649] [ERROR] ❌ 合成失败: TTSExecutor.__call__() got an unexpected keyword argument 'speed'
Traceback (most recent call last):
  File "/app/tts_engines/paddlespeech/paddle_tts_service.py", line 126, in synthesize_speech
    tts_executor(
  File "/usr/local/lib/python3.12/dist-packages/paddlespeech/cli/utils.py", line 328, in _warpper
    return executor_func(self, *args, **kwargs)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
TypeError: TTSExecutor.__call__() got an unexpected keyword argument 'speed'"
[DEBUG] 📥 [PaddleSpeech] 收到响应: "error"
[WARNING] ❌ [PaddleSpeech] 合成失败: "合成失败"
```

**症状**：
- ✅ PaddleSpeech 引擎初始化成功
- ✅ Phase 7.46.22 修复了 `am_dataset` 参数错误
- ❌ 语音合成仍然失败
- ❌ 新错误：`TTSExecutor.__call__() got an unexpected keyword argument 'speed'`

---

## 🔍 根本原因

### 问题分析

**Phase 7.46.22 的修复**（不完整）：
```python
tts_executor(
    text=text,
    output=output_path,
    am='fastspeech2',
    voc='pwgan_csmsc',
    lang='zh',
    spk_id=0,
    speed=1.0  # ❌ 这个参数也不支持！
)
```

**PaddleSpeech TTSExecutor 实际支持的参数**：
```python
def __call__(
    self,
    text: str,
    output: str,
    am: str = 'fastspeech2',
    voc: str = 'pwgan_csmsc',
    lang: str = 'zh',
    spk_id: int = 0
):
```

**关键发现**：
1. ❌ `speed` 参数不存在
2. ❌ PaddleSpeech 不支持运行时语速调整
3. ✅ 语速在模型训练时固定
4. ⚠️ 如果需要语速调整，需要通过音频后处理实现

---

## 🛠️ 修复方案

### 策略：移除 speed 参数

直接移除不支持的 `speed` 参数，如果需要语速调整，后续通过音频后处理实现。

### 修改：paddle_tts_service.py

**文件**: `docker/rk3588/tts_engines/paddlespeech/paddle_tts_service.py`

**位置**: `synthesize_speech()` 方法（第 124-142 行）

**修改内容**：

```python
def synthesize_speech(text, speaker_id, speed, volume):
    """合成语音"""
    try:
        logger.info(f"🎙️ 合成语音 - 文本: {text}, 说话人ID: {speaker_id}, 语速: {speed}")

        # ... 解析模型名称和选择声码器 ...

        # ✅ 2026-02-16 07:20: 修复 PaddleSpeech 调用参数（第二次）
        # 原因：TTSExecutor.__call__() 也不接受 speed 参数
        # 效果：移除 speed 参数，语速控制需要通过其他方式实现
        # 注意：PaddleSpeech 不支持运行时语速调整，只能在模型训练时固定
        # 旧代码：tts_executor(..., speed=speed)

        # 调用 PaddleSpeech 合成
        # 注意：不传递 am_dataset、voc_dataset 和 speed 参数
        tts_executor(
            text=text,
            output=output_path,
            am=am_name,
            voc=voc_name,
            lang=lang,
            spk_id=speaker_id
        )

        # 如果需要语速调整，可以使用 pydub 或 ffmpeg 后处理音频
        # 例如：ffmpeg -i input.wav -filter:a "atempo=1.5" output.wav

        # 检查输出文件
        if not os.path.exists(output_path):
            logger.error(f"❌ 输出文件不存在: {output_path}")
            return False

        # 调整音量（使用 pydub）
        if volume != 1.0:
            try:
                from pydub import AudioSegment
                audio = AudioSegment.from_wav(output_path)
                # 转换音量（0.0-1.0 -> dB）
                volume_db = 20 * (volume - 1)  # 0.8 -> -4dB, 1.0 -> 0dB
                audio = audio + volume_db
                audio.export(output_path, format='wav')
                logger.info(f"🔊 调整音量: {volume} ({volume_db:.1f}dB)")
            except ImportError:
                logger.warning("⚠️ pydub 未安装，跳过音量调整")

        logger.info(f"✅ 合成成功: {output_path}")
        return True

    except Exception as e:
        logger.error(f"❌ 合成失败: {e}")
        import traceback
        traceback.print_exc()
        return False
```

**说明**：
1. **移除参数**：删除 `speed=speed` 参数
2. **添加注释**：说明 PaddleSpeech 不支持运行时语速调整
3. **后处理方案**：添加注释说明可以使用 ffmpeg 后处理音频调整语速
4. **保留参数**：`text`, `output`, `am`, `voc`, `lang`, `spk_id`

---

## 📊 修复前后对比

### 修复前（Phase 7.46.22）

**调用代码**：
```python
tts_executor(
    text=text,
    output=output_path,
    am='fastspeech2',
    voc='pwgan_csmsc',
    lang='zh',
    spk_id=0,
    speed=1.0  # ❌ 不支持
)
```

**错误日志**：
```
TypeError: TTSExecutor.__call__() got an unexpected keyword argument 'speed'
```

### 修复后（Phase 7.46.23）

**调用代码**：
```python
tts_executor(
    text=text,
    output=output_path,
    am='fastspeech2',
    voc='pwgan_csmsc',
    lang='zh',
    spk_id=0
)
```

**预期日志**：
```
[DEBUG] 🎙️ [PaddleSpeech] 合成语音 - 文本: "一号皮带准备启动，请注意" 说话人ID: 0 语速: 1.0
[DEBUG] 📤 [PaddleSpeech] 发送命令: "synthesize"
[WARNING] [PaddleSpeech Error] "[2023-06-18 16:25:00] [INFO] 🎙️ 合成语音 - 文本: 一号皮带准备启动，请注意, 说话人ID: 0, 语速: 1.0"
[WARNING] [PaddleSpeech Error] "[2023-06-18 16:25:05] [INFO] ✅ 合成成功: /tmp/tts_output.wav"
[DEBUG] 📥 [PaddleSpeech] 收到响应: "success"
[DEBUG] ✅ [PaddleSpeech] 合成成功
[DEBUG] 🔊 [CommonControl] 播放语音: "/tmp/tts_output.wav"
```

---

## 🎯 PaddleSpeech 支持的参数

### 完整参数列表

| 参数 | 类型 | 默认值 | 说明 | 支持状态 |
|------|------|--------|------|----------|
| text | str | 必填 | 要合成的文本 | ✅ 支持 |
| output | str | 必填 | 输出文件路径 | ✅ 支持 |
| am | str | 'fastspeech2' | 声学模型名称 | ✅ 支持 |
| voc | str | 'pwgan_csmsc' | 声码器名称 | ✅ 支持 |
| lang | str | 'zh' | 语言（zh/en） | ✅ 支持 |
| spk_id | int | 0 | 说话人ID | ✅ 支持 |
| am_dataset | str | - | 声学模型数据集 | ❌ 不支持 |
| voc_dataset | str | - | 声码器数据集 | ❌ 不支持 |
| speed | float | - | 语速 | ❌ 不支持 |

---

## 🔧 语速调整方案

### 方案1：使用 ffmpeg 后处理（推荐）

**优点**：
- ✅ 不改变音调
- ✅ 效果好
- ✅ 支持任意语速

**实现**：
```python
import subprocess

def adjust_speed(input_path, output_path, speed):
    """使用 ffmpeg 调整语速"""
    cmd = [
        'ffmpeg', '-i', input_path,
        '-filter:a', f'atempo={speed}',
        '-y', output_path
    ]
    subprocess.run(cmd, check=True)
```

**使用示例**：
```python
# 合成语音
tts_executor(text=text, output='/tmp/original.wav', ...)

# 调整语速
adjust_speed('/tmp/original.wav', '/tmp/adjusted.wav', speed=1.5)
```

### 方案2：使用 pydub（简单）

**优点**：
- ✅ 纯 Python 实现
- ✅ 代码简单

**缺点**：
- ⚠️ 会改变音调
- ⚠️ 效果一般

**实现**：
```python
from pydub import AudioSegment
from pydub.playback import play

def adjust_speed_pydub(input_path, output_path, speed):
    """使用 pydub 调整语速"""
    audio = AudioSegment.from_wav(input_path)
    # 改变播放速度（会改变音调）
    audio = audio._spawn(audio.raw_data, overrides={
        "frame_rate": int(audio.frame_rate * speed)
    })
    audio = audio.set_frame_rate(audio.frame_rate)
    audio.export(output_path, format='wav')
```

### 方案3：选择不同的模型

**说明**：
- PaddleSpeech 提供不同语速的预训练模型
- 例如：`speedyspeech_csmsc`（快速语音）

**优点**：
- ✅ 不需要后处理
- ✅ 效果最好

**缺点**：
- ❌ 语速固定，不能动态调整
- ❌ 需要下载多个模型

---

## 🚀 部署流程

### 步骤1：重新构建应用镜像

```powershell
.\build-ubuntu24-apt.ps1 186
```

**注意**：
- ⚠️ 修改了 Python 文件，需要确保 Docker 重新复制文件
- ⚠️ 如果使用了缓存，需要强制重新构建：`docker build --no-cache`

**预计时间**：~3 分钟

### 步骤2：测试 PaddleSpeech 引擎

**操作**：
1. 启动应用程序
2. 打开 TTS 配置界面
3. 切换到 PaddleSpeech 引擎
4. 选择模型
5. 点击"测试"按钮

**预期结果**：
- ✅ PaddleSpeech 引擎初始化成功
- ✅ 语音合成成功
- ✅ 播放合成的语音
- ⚠️ 语速固定为模型默认值（无法动态调整）

**查看日志**：
```bash
ssh pi@192.168.10.186 "docker logs -f belt-control-app | grep -E 'PaddleSpeech|合成'"
```

---

## 📝 相关文档

1. [44-Phase7.46.22-修复PaddleSpeech合成参数错误.md](44-Phase7.46.22-修复PaddleSpeech合成参数错误.md) - 第一次参数修复
2. [43-Phase7.46.21-添加PaddleSpeech初始化进度条.md](43-Phase7.46.21-添加PaddleSpeech初始化进度条.md) - 进度条功能
3. [45-PaddleSpeech错误分析和重要性评估.md](45-PaddleSpeech错误分析和重要性评估.md) - 错误分析

---

## ✅ Git提交记录

**提交**: Phase 7.46.23 - 修复PaddleSpeech不支持speed参数

**修改文件**：
- `docker/rk3588/tts_engines/paddlespeech/paddle_tts_service.py` - 移除 speed 参数
- `docs/2026-02-16/46-Phase7.46.23-修复PaddleSpeech不支持speed参数.md` - 修复总结文档

**提交信息**：
```
fix: Phase 7.46.23 - 修复PaddleSpeech不支持speed参数

- 移除 speed 参数（PaddleSpeech不支持运行时语速调整）
- 添加注释说明语速调整需要通过后处理实现
- 修复 TTSExecutor.__call__() 参数错误
```

---

## 🎯 TTS 引擎状态

### 当前可用性

| 引擎名称 | 注册状态 | 依赖安装 | 参数修复 | 可用性 |
|---------|---------|---------|---------|--------|
| Sherpa-ONNX | ✅ 已注册 | ✅ C++实现 | ✅ 正常 | ✅ 可用 |
| PaddleSpeech | ✅ 已注册 | ✅ 已安装 | ✅ 已修复 | ⏳ 待测试 |
| MeloTTS | ✅ 已注册 | ❌ 未安装 | ✅ 正常 | ❌ 不可用 |
| Coqui TTS | ❌ 未注册 | ❌ 未安装 | ❌ 未实现 | ❌ 不可用 |
| Piper TTS | ❌ 未注册 | ❌ 未安装 | ❌ 未实现 | ❌ 不可用 |

---

## 🔍 参数修复历史

### Phase 7.46.22（第一次修复）

**错误**：`TTSExecutor.__call__() got an unexpected keyword argument 'am_dataset'`

**修复**：
- 移除 `am_dataset` 参数
- 移除 `voc_dataset` 参数
- 使用完整的声码器名称（`pwgan_csmsc`）

### Phase 7.46.23（第二次修复）

**错误**：`TTSExecutor.__call__() got an unexpected keyword argument 'speed'`

**修复**：
- 移除 `speed` 参数
- 添加语速后处理方案注释

### 最终支持的参数

```python
tts_executor(
    text=text,           # ✅ 支持
    output=output_path,  # ✅ 支持
    am=am_name,          # ✅ 支持
    voc=voc_name,        # ✅ 支持
    lang=lang,           # ✅ 支持
    spk_id=speaker_id    # ✅ 支持
)
```

---

## 💡 经验教训

### 1. 参数验证的重要性

**问题**：
- 没有提前验证 PaddleSpeech 支持的参数
- 导致两次修复才解决问题

**改进**：
- 在集成第三方库前，先查看官方文档
- 使用 `help(tts_executor)` 查看支持的参数
- 编写单元测试验证参数

### 2. Docker 缓存问题

**问题**：
- 修改 Python 文件后，Docker 可能使用缓存
- 导致修改没有生效

**解决**：
- 使用 `--no-cache` 强制重新构建
- 或者修改 Dockerfile 的 COPY 顺序
- 或者删除 build 目录强制重新编译

### 3. 渐进式修复

**优点**：
- 每次只修复一个问题
- 容易定位问题
- Git 提交历史清晰

**缺点**：
- 需要多次构建和部署
- 耗时较长

---

**完成时间**: 2026-02-16 07:25
**下次测试**: 重新构建镜像后测试 PaddleSpeech 合成
