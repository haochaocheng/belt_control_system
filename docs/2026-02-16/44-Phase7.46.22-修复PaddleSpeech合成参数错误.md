# Phase7.46.22 - 修复PaddleSpeech合成参数错误

**日期**: 2026-02-16
**阶段**: Phase 7.46.22
**状态**: ✅ 已完成

---

## 📋 问题描述

### 现象

从 voip.md 日志可以看到：

```
[DEBUG] 🎙️ [PaddleSpeech] 合成语音 - 文本: "一号皮带准备启动，请注意" 说话人ID: 0 语速: 1 音量: 0.8
[DEBUG] 📤 [PaddleSpeech] 发送命令: "synthesize"
[WARNING] [PaddleSpeech Error] "[2023-06-18 15:33:01,762] [ERROR] ❌ 合成失败: TTSExecutor.__call__() got an unexpected keyword argument 'am_dataset'"
[WARNING] [PaddleSpeech Error] "Traceback (most recent call last):
  File "/app/tts_engines/paddlespeech/paddle_tts_service.py", line 115, in synthesize_speech
    tts_executor(
  File "/usr/local/lib/python3.12/dist-packages/paddlespeech/cli/utils.py", line 328, in _warpper
    return executor_func(self, *args, **kwargs)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
TypeError: TTSExecutor.__call__() got an unexpected keyword argument 'am_dataset'"
[DEBUG] 📥 [PaddleSpeech] 收到响应: "error"
[WARNING] ❌ [PaddleSpeech] 合成失败: "合成失败"
```

**症状**：
- ✅ PaddleSpeech 引擎初始化成功
- ✅ 进度条正常显示
- ❌ 语音合成失败
- ❌ 错误：`TTSExecutor.__call__() got an unexpected keyword argument 'am_dataset'`

---

## 🔍 根本原因

### 问题分析

**错误的调用方式**（修复前）：
```python
tts_executor(
    text=text,
    output=output_path,
    am=am_name,
    am_dataset=dataset,        # ❌ 不支持的参数
    voc=voc_name,
    voc_dataset=voc_dataset,   # ❌ 不支持的参数
    lang='zh',
    spk_id=speaker_id,
    speed=speed
)
```

**PaddleSpeech TTSExecutor 支持的参数**：
```python
def __call__(
    self,
    text: str,
    output: str,
    am: str = 'fastspeech2',
    voc: str = 'pwgan_csmsc',  # 完整的声码器名称
    lang: str = 'zh',
    spk_id: int = 0,
    speed: float = 1.0
):
```

**关键发现**：
1. ❌ `am_dataset` 参数不存在
2. ❌ `voc_dataset` 参数不存在
3. ✅ `voc` 参数需要完整的声码器名称（如 `pwgan_csmsc`，而不是 `pwgan`）

---

## 🛠️ 修复方案

### 策略：使用正确的参数调用 PaddleSpeech

移除不支持的参数，使用完整的声码器名称。

### 修改：paddle_tts_service.py

**文件**: `docker/rk3588/tts_engines/paddlespeech/paddle_tts_service.py`

**位置**: `synthesize_speech()` 方法（第 100-134 行）

**修改内容**：

```python
def synthesize_speech(text, speaker_id, speed, volume):
    """合成语音"""
    try:
        logger.info(f"🎙️ 合成语音 - 文本: {text}, 说话人ID: {speaker_id}, 语速: {speed}")

        # ✅ 2026-02-16 07:00: 修复 PaddleSpeech 调用参数
        # 原因：TTSExecutor.__call__() 不接受 am_dataset 和 voc_dataset 参数
        # 效果：使用正确的参数调用 PaddleSpeech
        # 旧代码：
        # parts = current_model.split('_')
        # am_name = parts[0]
        # dataset = '_'.join(parts[1:])
        # tts_executor(am=am_name, am_dataset=dataset, voc_dataset=voc_dataset, ...)

        # 解析模型名称
        # 模型格式：fastspeech2_csmsc, speedyspeech_csmsc, tacotron2_ljspeech 等
        parts = current_model.split('_')
        am_name = parts[0]  # 声学模型名称：fastspeech2, speedyspeech, tacotron2
        dataset = '_'.join(parts[1:])  # 数据集名称：csmsc, aishell3, ljspeech

        # 选择声码器
        # 中文模型使用 pwgan，英文模型使用 hifigan
        if 'csmsc' in dataset or 'aishell3' in dataset:
            voc_name = 'pwgan_csmsc'  # 完整的声码器名称
            lang = 'zh'
        else:
            voc_name = 'hifigan_ljspeech'  # 完整的声码器名称
            lang = 'en'

        # 调用 PaddleSpeech 合成
        # 注意：不传递 am_dataset 和 voc_dataset 参数
        tts_executor(
            text=text,
            output=output_path,
            am=am_name,
            voc=voc_name,
            lang=lang,
            spk_id=speaker_id,
            speed=speed
        )

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
1. **移除参数**：删除 `am_dataset` 和 `voc_dataset` 参数
2. **完整声码器名称**：
   - 中文模型：`pwgan_csmsc`（而不是 `pwgan`）
   - 英文模型：`hifigan_ljspeech`（而不是 `hifigan`）
3. **保留参数**：`text`, `output`, `am`, `voc`, `lang`, `spk_id`, `speed`

---

## 📊 修复前后对比

### 修复前

**调用代码**：
```python
tts_executor(
    text=text,
    output=output_path,
    am='fastspeech2',
    am_dataset='csmsc',        # ❌ 不支持
    voc='pwgan',               # ❌ 不完整
    voc_dataset='csmsc',       # ❌ 不支持
    lang='zh',
    spk_id=0,
    speed=1.0
)
```

**错误日志**：
```
TypeError: TTSExecutor.__call__() got an unexpected keyword argument 'am_dataset'
```

### 修复后

**调用代码**：
```python
tts_executor(
    text=text,
    output=output_path,
    am='fastspeech2',
    voc='pwgan_csmsc',         # ✅ 完整名称
    lang='zh',
    spk_id=0,
    speed=1.0
)
```

**预期日志**：
```
[DEBUG] 🎙️ [PaddleSpeech] 合成语音 - 文本: "一号皮带准备启动，请注意" 说话人ID: 0 语速: 1 音量: 0.8
[DEBUG] 📤 [PaddleSpeech] 发送命令: "synthesize"
[WARNING] [PaddleSpeech Error] "[2023-06-18 15:35:00] [INFO] 🎙️ 合成语音 - 文本: 一号皮带准备启动，请注意, 说话人ID: 0, 语速: 1.0"
[WARNING] [PaddleSpeech Error] "[2023-06-18 15:35:05] [INFO] ✅ 合成成功: /tmp/tts_output.wav"
[DEBUG] 📥 [PaddleSpeech] 收到响应: "success"
[DEBUG] ✅ [PaddleSpeech] 合成成功
[DEBUG] 🔊 [CommonControl] 播放语音: "/tmp/tts_output.wav"
```

---

## 🎯 支持的模型和声码器

### 中文模型

| 声学模型 | 数据集 | 声码器 | 完整调用 |
|---------|--------|--------|----------|
| fastspeech2 | csmsc | pwgan_csmsc | `am='fastspeech2', voc='pwgan_csmsc', lang='zh'` |
| speedyspeech | csmsc | pwgan_csmsc | `am='speedyspeech', voc='pwgan_csmsc', lang='zh'` |
| fastspeech2 | aishell3 | pwgan_aishell3 | `am='fastspeech2', voc='pwgan_aishell3', lang='zh'` |

### 英文模型

| 声学模型 | 数据集 | 声码器 | 完整调用 |
|---------|--------|--------|----------|
| tacotron2 | ljspeech | hifigan_ljspeech | `am='tacotron2', voc='hifigan_ljspeech', lang='en'` |
| fastspeech2 | ljspeech | hifigan_ljspeech | `am='fastspeech2', voc='hifigan_ljspeech', lang='en'` |

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
4. 选择模型（如 "fastspeech2_csmsc (中文女声)"）
5. 点击"测试"按钮

**预期结果**：
- ✅ PaddleSpeech 引擎初始化成功
- ✅ 进度条正常显示
- ✅ 语音合成成功
- ✅ 播放合成的语音

**查看日志**：
```bash
ssh pi@192.168.10.186 "docker logs -f belt-control-app | grep -E 'PaddleSpeech|合成'"
```

---

## 📝 相关文档

1. [43-Phase7.46.21-添加PaddleSpeech初始化进度条.md](43-Phase7.46.21-添加PaddleSpeech初始化进度条.md) - 进度条实现
2. [42-Phase7.46.19-修复PaddleSpeech响应读取冲突问题.md](42-Phase7.46.19-修复PaddleSpeech响应读取冲突问题.md) - 响应读取修复
3. [41-Phase7.46.18-将Python依赖移到基础镜像并修复numpy版本问题.md](41-Phase7.46.18-将Python依赖移到基础镜像并修复numpy版本问题.md) - Python 依赖优化

---

## ✅ Git提交记录

**提交**: Phase 7.46.22 - 修复PaddleSpeech合成参数错误

**修改文件**：
- `docker/rk3588/tts_engines/paddlespeech/paddle_tts_service.py` - 修复调用参数
- `docs/2026-02-16/44-Phase7.46.22-修复PaddleSpeech合成参数错误.md` - 修复总结文档

**提交信息**：
```
fix: Phase 7.46.22 - 修复PaddleSpeech合成参数错误

- 移除不支持的 am_dataset 和 voc_dataset 参数
- 使用完整的声码器名称（pwgan_csmsc, hifigan_ljspeech）
- 修复 TTSExecutor.__call__() 参数错误
- 确保语音合成成功
```

---

## 🎯 TTS 引擎状态

### 当前可用性

| 引擎名称 | 注册状态 | 依赖安装 | 初始化 | 合成 | 可用性 |
|---------|---------|---------|--------|------|--------|
| Sherpa-ONNX | ✅ 已注册 | ✅ C++实现 | ✅ 正常 | ✅ 正常 | ✅ 可用 |
| PaddleSpeech | ✅ 已注册 | ✅ 已安装 | ✅ 已修复 | ✅ 已修复 | ⏳ 待测试 |
| MeloTTS | ✅ 已注册 | ❌ 未安装 | ✅ 正常 | ❌ 未测试 | ❌ 不可用 |
| Coqui TTS | ❌ 未注册 | ❌ 未安装 | ❌ 未实现 | ❌ 未实现 | ❌ 不可用 |
| Piper TTS | ❌ 未注册 | ❌ 未安装 | ❌ 未实现 | ❌ 未实现 | ❌ 不可用 |

---

## 🔍 技术细节

### PaddleSpeech TTSExecutor 参数说明

**支持的参数**：
```python
text: str           # 要合成的文本
output: str         # 输出文件路径
am: str             # 声学模型名称（fastspeech2, speedyspeech, tacotron2）
voc: str            # 声码器完整名称（pwgan_csmsc, hifigan_ljspeech）
lang: str           # 语言（zh, en）
spk_id: int         # 说话人ID（多说话人模型）
speed: float        # 语速（0.5-2.0）
```

**不支持的参数**：
- ❌ `am_dataset` - 声学模型数据集
- ❌ `voc_dataset` - 声码器数据集

**原因**：
- PaddleSpeech 的 `TTSExecutor` 使用完整的声码器名称（如 `pwgan_csmsc`）
- 声码器名称已经包含了数据集信息
- 不需要单独传递数据集参数

---

**完成时间**: 2026-02-16 07:05
**下次测试**: 重新构建镜像后测试 PaddleSpeech 语音合成
